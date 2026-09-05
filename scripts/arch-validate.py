#!/usr/bin/env python3
"""Validate architecture/model.yaml against architecture/metamodel.yaml.

An architecture description is only worth publishing if something checks it. This
enforces three things a prose document cannot:

  1. Referential integrity  — no relationship points at an entity that doesn't exist.
  2. Type discipline        — relationships only join the entity types the metamodel allows.
  3. The invariants         — including "every irreplaceable data entity reaches a store
                              that is actually backed up", which is the one whose violation
                              silently destroys the estate.

Exit code 0 = conformant, 1 = errors found. Safe to wire into CI or a pre-commit hook.

Usage: python3 scripts/arch-validate.py [--summary]
"""
from __future__ import annotations

import sys
from collections import defaultdict
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required:  pip install pyyaml  (or apt install python3-yaml)")

ROOT = Path(__file__).resolve().parent.parent
METAMODEL = ROOT / "architecture" / "metamodel.yaml"
MODEL = ROOT / "architecture" / "model.yaml"

# Layers whose entities must carry plain_language: the non-technical view is generated
# from these, so a missing one is a hole in the stakeholder-facing story.
PLAIN_LANGUAGE_REQUIRED = {"Driver", "Principle", "Capability", "BusinessService", "Actor"}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def load() -> tuple[dict, dict]:
    for p in (METAMODEL, MODEL):
        if not p.exists():
            sys.exit(f"missing {p}")
    return (yaml.safe_load(METAMODEL.read_text()),
            yaml.safe_load(MODEL.read_text()))


def entity_types(mm: dict) -> dict[str, dict]:
    """Flatten the metamodel's layered entity declarations into {type_name: spec}."""
    out: dict[str, dict] = {}
    for layer, types in mm["layers"].items():
        for tname, spec in types.items():
            spec = dict(spec)
            spec["_layer"] = layer
            out[tname] = spec
    return out


def main() -> int:
    mm, model = load()
    types = entity_types(mm)
    rel_specs = {r["name"]: r for r in mm["relationships"]}

    # ---- collect instances -------------------------------------------------
    instances: dict[str, str] = {}          # id -> type
    entity_data: dict[str, dict] = {}       # id -> attributes
    by_type: dict[str, list[str]] = defaultdict(list)

    for tname in types:
        for ent in model.get(tname, []) or []:
            eid = ent.get("id")
            if not eid:
                err(f"{tname}: an entry has no id: {ent.get('name', '<unnamed>')!r}")
                continue
            if eid in instances:
                err(f"duplicate id {eid!r} (used by {instances[eid]} and {tname})")
                continue
            instances[eid] = tname
            entity_data[eid] = ent
            by_type[tname].append(eid)

    # entity keys in the model that aren't declared types (catches typos//drift)
    known_keys = set(types) | {"model", "relationships"}
    for key in model:
        if key not in known_keys:
            err(f"model.yaml declares {key!r}, which is not an entity type in the metamodel")

    # ---- required attributes and enums ------------------------------------
    for eid, tname in instances.items():
        ent = entity_data[eid]
        for req in ("name", "description"):
            if not ent.get(req):
                err(f"{tname} {eid}: missing required attribute {req!r}")
        if tname in PLAIN_LANGUAGE_REQUIRED and not ent.get("plain_language"):
            err(f"{tname} {eid}: missing plain_language "
                f"(required on {'/'.join(sorted(PLAIN_LANGUAGE_REQUIRED))} "
                f"— the non-technical view is generated from it)")
        for attr, spec in (types[tname].get("attributes") or {}).items():
            if not isinstance(spec, dict):
                continue
            val = ent.get(attr)
            if spec.get("required") and val in (None, ""):
                err(f"{tname} {eid}: missing required attribute {attr!r}")
            if val is not None and spec.get("type") == "enum":
                allowed = spec.get("values", [])
                if val not in allowed:
                    err(f"{tname} {eid}: {attr}={val!r} not in {allowed}")

    # ---- relationships -----------------------------------------------------
    rels = model.get("relationships", []) or []
    outgoing: dict[tuple[str, str], list[str]] = defaultdict(list)  # (from_id, name) -> [to_id]

    for r in rels:
        f, name, t = r.get("from"), r.get("name"), r.get("to")
        if not all((f, name, t)):
            err(f"malformed relationship: {r}")
            continue
        if name not in rel_specs:
            err(f"relationship {name!r} is not defined in the metamodel ({f} -> {t})")
            continue
        if f not in instances:
            err(f"relationship {name}: source {f!r} does not exist")
            continue
        if t not in instances:
            err(f"relationship {name}: target {t!r} does not exist")
            continue
        spec = rel_specs[name]
        if instances[f] not in spec["from"]:
            err(f"relationship {name}: source {f} is a {instances[f]}, "
                f"but must be one of {spec['from']}")
        if instances[t] not in spec["to"]:
            err(f"relationship {name}: target {t} is a {instances[t]}, "
                f"but must be one of {spec['to']}")
        outgoing[(f, name)].append(t)

    # ---- invariants --------------------------------------------------------
    # every-service-has-a-tier
    for sid in by_type.get("ApplicationService", []):
        tiers = outgoing.get((sid, "exposed_via"), [])
        if len(tiers) != 1:
            err(f"[every-service-has-a-tier] ApplicationService {sid} has {len(tiers)} "
                f"exposure tiers, expected exactly 1 — an endpoint whose reachability "
                f"nobody stated is how things get accidentally published")

    # every-capability-is-realised
    for cid in by_type.get("Capability", []):
        if not outgoing.get((cid, "realised_by")):
            err(f"[every-capability-is-realised] Capability {cid} is realised by nothing "
                f"— it is an aspiration, and belongs in the Gap register instead")

    # irreplaceable-data-is-backed-up
    for did in by_type.get("DataEntity", []):
        ent = entity_data[did]
        if ent.get("recoverability") != "irreplaceable":
            continue
        stores = outgoing.get((did, "persisted_in"), [])
        if not stores:
            err(f"[irreplaceable-data-is-backed-up] DataEntity {did} is irreplaceable but "
                f"is persisted nowhere")
            continue
        unprotected = [s for s in stores
                       if (entity_data[s].get("backup_method") or "none") == "none"]
        if unprotected:
            err(f"[irreplaceable-data-is-backed-up] DataEntity {did} is irreplaceable but "
                f"reaches store(s) with no backup: {unprotected}")

    # every-vendored-component-names-its-source
    # A component this repo builds is owned by some other project. Recording that repo as
    # data is what lets the prose docs stay neutral to the estate's dependents.
    for aid in by_type.get("ApplicationComponent", []):
        ent = entity_data[aid]
        if (ent.get("image") or "").strip().lower() != "locally built":
            continue
        if not (ent.get("source") or "").strip():
            err(f"[every-vendored-component-names-its-source] ApplicationComponent {aid} is "
                f"'locally built' but names no source repo — the project that owns it is "
                f"unrecorded, so the dependency lives only in prose")

    # no-orphan-controls
    for cid in by_type.get("Control", []):
        if not outgoing.get((cid, "protects")):
            err(f"[no-orphan-controls] Control {cid} protects nothing")
        if not outgoing.get((cid, "implements")):
            err(f"[no-orphan-controls] Control {cid} implements no Principle "
                f"— an unexplained control")

    # Advisory: a principle nothing enforces is decoration, not architecture.
    implemented = {t for (f, n), ts in outgoing.items() if n == "implements" for t in ts}
    governing = {f for (f, n) in outgoing if n == "governs"}
    for pid in by_type.get("Principle", []):
        if pid not in implemented and pid not in governing:
            warn(f"Principle {pid} neither governs anything nor is implemented by a Control "
                 f"— it is currently decorative")

    # Advisory: orphan entities (nothing points at them, they point at nothing).
    connected = {f for (f, _) in outgoing} | {t for ts in outgoing.values() for t in ts}
    for eid, tname in instances.items():
        if eid not in connected:
            warn(f"{tname} {eid} participates in no relationship")

    # ---- report ------------------------------------------------------------
    if "--summary" in sys.argv:
        print(f"model: {model['model']['name']}  baseline {model['model']['baseline_date']}")
        print(f"metamodel: {mm['meta']['version']}  ({mm['meta']['basis']})\n")
        for layer in mm["layers"]:
            names = [t for t in types if types[t]["_layer"] == layer]
            counts = ", ".join(f"{t} {len(by_type.get(t, []))}" for t in names)
            print(f"  {layer:12} {counts}")
        print(f"\n  {len(instances)} entities, {len(rels)} relationships")

    for w in warnings:
        print(f"WARN  {w}", file=sys.stderr)
    for e in errors:
        print(f"ERROR {e}", file=sys.stderr)

    if errors:
        print(f"\n{len(errors)} error(s) — model does not conform.", file=sys.stderr)
        return 1
    print(f"\nConformant: {len(instances)} entities, {len(rels)} relationships"
          f"{f', {len(warnings)} warning(s)' if warnings else ''}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
