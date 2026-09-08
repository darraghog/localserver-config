#!/usr/bin/env python3
"""Report which container images this estate pins, and what has been published since.

Nothing here tells you a newer version exists: there is no Renovate, no Dependabot, and
the pinned tags in compose/ are only as current as the last person who looked. This is
that look, made repeatable. It reads; it never pulls, edits, or deploys.

Three things get reported:

  1. Pinned tags     — the newest published tag of the *same shape*, split by whether the
                       tag's leading number changed. That split is a sort, not a safety
                       verdict: python:3.12-slim → 3.14-slim and wordpress
                       7.1-php8.3-apache → 7.1-php8.5-apache both keep the leading number
                       and both change the runtime underneath. A changed leading number
                       on postgres or mariadb is the expensive case — it needs a
                       dump/restore, not a tag edit.
  2. Moving tags     — alpine, main-stable and friends. Ranking them is meaningless;
                       ./scripts/deploy.sh already refreshes them.
  3. Model drift     — where compose/ and architecture/model.yaml disagree about an
                       image. Advisory only: arch-validate.py is untouched, so nothing
                       here can block a commit or a deploy.

Usage:
  python3 scripts/check-updates.py               # everything, with registry lookups
  python3 scripts/check-updates.py --offline     # inventory and drift only, no network
  python3 scripts/check-updates.py --stack n8n   # one stack (repeatable)
  python3 scripts/check-updates.py --strict      # exit 1 if anything was found, 2 if a
                                                # registry could not be reached (for CI)
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required:  pip install pyyaml  (or apt install python3-yaml)")

ROOT = Path(__file__).resolve().parent.parent
COMPOSE_DIR = ROOT / "compose"
MODEL = ROOT / "architecture" / "model.yaml"

# model.yaml's image: field is prose for anything the registry doesn't serve.
NOT_A_REGISTRY_IMAGE = {"locally built", "distribution package"}

# podman search's default is 25 tags, which truncates every real repository. The largest
# this estate pulls from is docker.io/library/wordpress at ~5,800 tags.
TAG_LIMIT = 10000
TAG_TIMEOUT_S = 120


# --------------------------------------------------------------------- refs ---

def parse_image_ref(ref: str) -> tuple[str, str]:
    """Split "name:tag" into its parts. A colon inside a registry host is not a tag."""
    name, sep, tag = ref.rpartition(":")
    if not sep or "/" in tag:
        return ref, "latest"
    return name, tag


def short_ref(ref: str) -> str:
    """Normalise a Docker Hub reference to the form model.yaml writes it in."""
    if ref.startswith("docker.io/"):
        ref = ref[len("docker.io/"):]
        if ref.startswith("library/"):
            ref = ref[len("library/"):]
    return ref


def is_pinned(tag: str) -> bool:
    """A tag that starts with a digit names a version; anything else moves under you."""
    return tag[:1].isdigit()


def tag_shape(tag: str) -> re.Pattern:
    """A regex matching tags of the same family: every numeric run becomes a wildcard.

    "7.1-php8.3-apache" matches "7.2-php8.4-apache" but not "7.1-php8.3-fpm", which is
    what keeps a wordpress comparison inside its own variant instead of drowning in the
    900 tags that repository publishes.
    """
    parts = re.split(r"(\d+)", tag)
    body = "".join(r"\d+" if p.isdigit() else re.escape(p) for p in parts)
    return re.compile(f"^{body}$")


def version_key(tag: str) -> tuple[int, ...]:
    """Order tags by their numbers, so 2.10.0 sorts above 2.9.9."""
    return tuple(int(n) for n in re.findall(r"\d+", tag))


def newest_tags(current: str, tags: list[str]) -> tuple[str | None, str | None]:
    """Newest tag of the same shape, as (same-major bump, any bump). None where absent."""
    shape = tag_shape(current)
    cur = version_key(current)
    newer = [t for t in tags if shape.match(t) and version_key(t) > cur]
    if not newer:
        return None, None
    same_major = [t for t in newer if version_key(t)[:1] == cur[:1]]
    return (max(same_major, key=version_key) if same_major else None,
            max(newer, key=version_key))


# ------------------------------------------------------------------ sources ---

def collect_compose_images(stack_dir: Path) -> set[str]:
    """Every image: a stack's compose file and its overlays declare."""
    found: set[str] = set()
    for path in sorted(stack_dir.glob("compose*.y*ml")):
        try:
            doc = yaml.safe_load(path.read_text()) or {}
        except yaml.YAMLError:
            continue
        services = doc.get("services") if isinstance(doc, dict) else None
        for svc in (services or {}).values():
            image = svc.get("image") if isinstance(svc, dict) else None
            # An interpolated image can't be compared against anything without the env.
            if isinstance(image, str) and "$" not in image:
                found.add(image.strip())
    return found


def collect_dockerfile_images(stack_dir: Path) -> set[str]:
    """Base images a locally built stack pulls. These go stale silently: a plain build
    reuses the cached base, so only `build-stack.sh <stack> -- --pull` refreshes them."""
    found: set[str] = set()
    for path in sorted(stack_dir.glob("Dockerfile*")):
        stages: set[str] = set()
        for line in path.read_text().splitlines():
            m = re.match(r"\s*FROM\s+(\S+)(?:\s+AS\s+(\S+))?\s*$", line, re.IGNORECASE)
            if not m:
                continue
            ref, alias = m.group(1), m.group(2)
            if alias:
                stages.add(alias)
            # "FROM build" continues an earlier stage; it pulls nothing.
            if ref not in stages and "$" not in ref:
                found.add(ref)
    return found


def model_images(model: dict) -> dict[str, set[str]]:
    """{stack name: images architecture/model.yaml says it runs}, for compose stacks."""
    out: dict[str, set[str]] = {}
    for ent in model.get("ApplicationComponent") or []:
        stack = (ent.get("stack") or "").strip()
        if not stack.startswith("compose/"):
            continue
        name = stack[len("compose/"):]
        image = (ent.get("image") or "").strip()
        if image.lower() in NOT_A_REGISTRY_IMAGE:
            out[name] = set()
            continue
        out[name] = {tok.strip() for tok in image.split("+") if tok.strip()}
    return out


# -------------------------------------------------------------------- drift ---

@dataclass
class Drift:
    stack: str
    detail: str


def find_drift(compose_by_stack: dict[str, set[str]],
               model_by_stack: dict[str, set[str]]) -> list[Drift]:
    """Where compose/ and model.yaml disagree. Stacks the model doesn't claim (tls-proxy
    is infrastructure, not an ApplicationComponent) are not drift — that is arch-validate's
    territory, and duplicating it here would only produce noise."""
    drift: list[Drift] = []
    for stack in sorted(model_by_stack):
        in_compose = {short_ref(r) for r in compose_by_stack.get(stack, set())}
        in_model = {short_ref(r) for r in model_by_stack[stack]}
        only_compose = sorted(in_compose - in_model)
        only_model = sorted(in_model - in_compose)
        if not only_compose and not only_model:
            continue
        parts = []
        if only_compose:
            parts.append(f"compose has {', '.join(only_compose)}")
        if only_model:
            parts.append(f"model.yaml has {', '.join(only_model)}")
        drift.append(Drift(stack=stack, detail="; ".join(parts)))
    return drift


# ----------------------------------------------------------------- registry ---

def list_registry_tags(name: str) -> list[str] | None:
    """Published tags for an image, or None when the registry couldn't be asked."""
    try:
        proc = subprocess.run(
            ["podman", "search", "--list-tags", name, "--limit", str(TAG_LIMIT),
             "--format", "json"],
            capture_output=True, text=True, timeout=TAG_TIMEOUT_S)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    try:
        results = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError:
        return None
    for entry in results:
        if entry.get("Tags"):
            return list(entry["Tags"])
    return None


# ------------------------------------------------------------------- report ---

@dataclass
class ImageUse:
    stack: str
    ref: str
    origin: str


def inventory(stacks: list[str]) -> list[ImageUse]:
    uses: list[ImageUse] = []
    for name in stacks:
        stack_dir = COMPOSE_DIR / name
        for ref in sorted(collect_compose_images(stack_dir)):
            uses.append(ImageUse(name, ref, "compose"))
        for ref in sorted(collect_dockerfile_images(stack_dir)):
            uses.append(ImageUse(name, ref, "Dockerfile"))
    return uses


def stack_names(selected: list[str] | None) -> list[str]:
    available = sorted(d.name for d in COMPOSE_DIR.iterdir()
                       if d.is_dir() and any(d.glob("compose*.y*ml")))
    if not selected:
        return available
    unknown = [s for s in selected if s not in available]
    if unknown:
        sys.exit(f"unknown stack(s): {', '.join(unknown)}\nknown: {', '.join(available)}")
    return [s for s in available if s in selected]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--offline", action="store_true",
                    help="skip registry lookups; report inventory and drift only")
    ap.add_argument("--stack", action="append", metavar="NAME",
                    help="limit to one stack (repeatable)")
    ap.add_argument("--strict", action="store_true",
                    help="exit 1 if any update or drift was found, 2 if a registry "
                         "could not be reached")
    args = ap.parse_args(argv)

    stacks = stack_names(args.stack)
    uses = inventory(stacks)
    pinned = [u for u in uses if is_pinned(parse_image_ref(u.ref)[1])]
    moving = [u for u in uses if not is_pinned(parse_image_ref(u.ref)[1])]

    findings = 0
    unchecked = 0
    tag_cache: dict[str, list[str] | None] = {}

    print("== Pinned images ==")
    if not pinned:
        print("  (none)")
    rows = []
    for u in pinned:
        name, tag = parse_image_ref(u.ref)
        if args.offline:
            rows.append((u.stack, short_ref(u.ref), "—", "—", u.origin))
            continue
        if name not in tag_cache:
            tag_cache[name] = list_registry_tags(name)
        tags = tag_cache[name]
        if tags is None:
            unchecked += 1
            rows.append((u.stack, short_ref(u.ref), "?", "?", u.origin))
            print(f"  WARN: could not list tags for {name}", file=sys.stderr)
            continue
        in_major, overall = newest_tags(tag, tags)
        if in_major or (overall and overall != in_major):
            findings += 1
        major = overall if overall != in_major else None
        rows.append((u.stack, short_ref(u.ref), in_major or "up to date",
                     major or "—", u.origin))

    if rows:
        widths = [max(len(str(r[i])) for r in rows) for i in range(4)]
        header = ("stack", "image", "same-major bump", "MAJOR bump")
        widths = [max(w, len(h)) for w, h in zip(widths, header)]
        print("  " + "  ".join(h.ljust(w) for h, w in zip(header, widths)) + "  from")
        for r in rows:
            print("  " + "  ".join(str(c).ljust(w) for c, w in zip(r[:4], widths)) + f"  {r[4]}")
        print("\n  same-major means the leading number is unchanged — not that it is safe.")
        print("  A MAJOR bump on postgres/mariadb needs a dump/restore, not a tag edit.")
        print("  Back up first: ./scripts/backup.sh  (docs/BACKUP.md)")

    print("\n== Moving tags (refreshed by ./scripts/deploy.sh) ==")
    if not moving:
        print("  (none)")
    for u in moving:
        print(f"  {u.stack}: {short_ref(u.ref)}  ({u.origin})")
    if any(u.origin == "Dockerfile" for u in uses):
        print("\n  Dockerfile base images are NOT refreshed by a plain build — the cached")
        print("  base is reused. Force it: ./scripts/build-stack.sh <stack> -- --pull")

    print("\n== Model drift (advisory; arch-validate.py is unaffected) ==")
    compose_by_stack = {name: collect_compose_images(COMPOSE_DIR / name) for name in stacks}
    model = yaml.safe_load(MODEL.read_text()) if MODEL.exists() else {}
    by_model = {k: v for k, v in model_images(model or {}).items() if k in set(stacks)}
    drift = find_drift(compose_by_stack, by_model)
    if not drift:
        print("  none")
    for d in drift:
        print(f"  {d.stack}: {d.detail}")
    findings += len(drift)

    if args.strict:
        # An unreachable registry is an incomplete check, not a clean one.
        if unchecked:
            return 2
        if findings:
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
