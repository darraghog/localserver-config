"""scripts/lib/arch_unbundle.py (infra repo): safely unpack an `export --bundle` document.

Source of truth: homelab-arch deploy/infra/arch_unbundle.py. Run as
`python3 -I arch_unbundle.py BUNDLE_FILE ARCH_DIR`; stdlib only. The bundle came over the network
and is untrusted: the WHOLE bundle is validated before anything is written, and exactly the four
allowed names are written into ARCH_DIR (never a path taken from the bundle).

Refusals (exit 2, nothing written, no file content in messages): bundle over 8 MiB; not one JSON
object with exactly {format, files}; format != hla-export/1; duplicate JSON keys; file names not
exactly the four allowed; a value that is not a str, is over 4 MiB, or is not valid UTF-8;
export.json not a JSON object whose `files` sha256 values match the other three; ARCH_DIR missing
or a symlink; architecture/<name> or <name>.tmp existing as anything but a regular file / not
existing (a symlink or leftover is refused).

Each file is written to <name>.tmp with O_NOFOLLOW|O_EXCL relative to an O_NOFOLLOW directory fd,
then os.replace()d onto <name>. Exit 0 written.
"""

import hashlib
import json
import os
import stat
import sys

FORMAT = "hla-export/1"
NAMES = ("export.json", "metamodel.yaml", "model.yaml", "overview.html")
HASHED = ("metamodel.yaml", "model.yaml", "overview.html")
MAX_BUNDLE = 8 * 1024 * 1024
MAX_VALUE = 4 * 1024 * 1024


class Refused(Exception):
    pass


def _pairs(pairs):
    keys = [k for k, _ in pairs]
    if len(set(keys)) != len(keys):
        raise Refused("duplicate key in JSON")
    return dict(pairs)


def _load_bytes(path):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, "rb") as f:
            if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):
                raise Refused("the bundle is not a regular file")
            data = f.read(MAX_BUNDLE + 1)
    except OSError as e:
        raise Refused(f"cannot read the bundle: {e.strerror}") from None
    if len(data) > MAX_BUNDLE:
        raise Refused("bundle is larger than 8 MiB")
    return data


def validate(data):
    """Return {name: utf-8 bytes} for a fully valid bundle, else raise Refused."""
    try:
        doc = json.loads(data.decode("utf-8"), object_pairs_hook=_pairs)
    except Refused:
        raise
    except (UnicodeDecodeError, ValueError, RecursionError):
        raise Refused("bundle is not valid UTF-8 JSON") from None
    if not isinstance(doc, dict) or set(doc) != {"format", "files"}:
        raise Refused("bundle must be one object with exactly format and files")
    if doc["format"] != FORMAT:
        raise Refused("unsupported bundle format")
    files = doc["files"]
    if not isinstance(files, dict) or set(files) != set(NAMES):
        raise Refused("bundle must hold exactly: " + ", ".join(NAMES))
    out = {}
    for name in NAMES:
        value = files[name]
        if not isinstance(value, str):
            raise Refused(f"{name}: value is not a string")
        try:
            raw = value.encode("utf-8")
        except UnicodeEncodeError:
            raise Refused(f"{name}: not valid UTF-8") from None
        if len(raw) > MAX_VALUE:
            raise Refused(f"{name}: larger than 4 MiB")
        out[name] = raw
    try:
        manifest = json.loads(out["export.json"].decode("utf-8"), object_pairs_hook=_pairs)
    except (Refused, ValueError, RecursionError):
        raise Refused("export.json is not valid JSON") from None
    listed = manifest.get("files") if isinstance(manifest, dict) else None
    if not isinstance(listed, dict):
        raise Refused("export.json has no files table")
    for name in HASHED:
        if listed.get(name) != hashlib.sha256(out[name]).hexdigest():
            raise Refused(f"{name}: sha256 does not match export.json")
    return out


def _open_dir(path):
    try:
        return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError as e:
        raise Refused(f"architecture directory refused: {e.strerror}") from None


def _precheck(dfd):
    for name in NAMES:
        for target in (name, name + ".tmp"):
            try:
                st = os.lstat(target, dir_fd=dfd)
            except FileNotFoundError:
                continue
            if stat.S_ISLNK(st.st_mode):
                raise Refused(f"{target} is a symlink")
            if target.endswith(".tmp"):
                raise Refused(f"{target} exists (a leftover?); remove it first")
            if not stat.S_ISREG(st.st_mode):
                raise Refused(f"{target} is not a regular file")


def write_all(dfd, files):
    made = []
    try:
        for name in NAMES:
            fd = os.open(
                name + ".tmp",
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
                0o644,
                dir_fd=dfd,
            )
            made.append(name + ".tmp")
            os.fchmod(fd, 0o644)  # umask 077 in the caller must not narrow the mode
            with os.fdopen(fd, "wb") as f:
                f.write(files[name])
                f.flush()
                os.fsync(f.fileno())
        for name in NAMES:
            os.replace(name + ".tmp", name, src_dir_fd=dfd, dst_dir_fd=dfd)
            made.remove(name + ".tmp")
        os.fsync(dfd)
    except OSError as e:
        raise Refused(
            f"write failed ({e.strerror}); a PARTIAL write may have happened: "
            "check git status in architecture/"
        ) from None
    finally:
        for tmp in made:
            try:
                os.unlink(tmp, dir_fd=dfd)
            except OSError:
                pass


def main(argv):
    if len(argv) != 3:
        print("usage: arch_unbundle.py BUNDLE_FILE ARCH_DIR", file=sys.stderr)
        return 2
    try:
        files = validate(_load_bytes(argv[1]))
        dfd = _open_dir(argv[2])
        try:
            _precheck(dfd)
            write_all(dfd, files)
        finally:
            os.close(dfd)
    except Refused as e:
        print(f"arch-export: refused: {e}", file=sys.stderr)
        return 2
    print("arch-export: wrote " + ", ".join(NAMES))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
