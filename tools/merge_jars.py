#!/usr/bin/env python3
"""Merge the Minecraft client and server jars into a single jar.

This is a deliberately simplified stand-in for Fabric Loom's `JarMerger`.
Loom's real merger uses ASM to stamp each class with a
`net.fabricmc.api.Environment` annotation recording whether it came from the
client, the server, or both, so that (a) conflicting client/server-only
classes with the same name can coexist logically and (b) tooling can later
strip out classes that don't belong on the current side.

We don't need that here:
  - The 26.3-pre-3 snapshot targeted by this project ships unobfuscated
    classes, so we don't need mapping-aware tooling to merge it sanely.
  - We aren't shipping a runtime that needs to strip mismatched-side classes;
    we just need one jar with everything a mod might want to compile/run
    against.

So this script just unions the two jars' entries. On a name collision the
client's copy wins (matching Loom's default merge preference), except for
META-INF signature/manifest files, which are dropped entirely since the
resulting jar is no longer signed by either upstream jar.
"""

import argparse
import sys
import zipfile


def _is_signature_or_manifest(name: str) -> bool:
    upper = name.upper()
    if upper == "META-INF/MANIFEST.MF":
        return True
    if upper.startswith("META-INF/") and (
        upper.endswith(".SF") or upper.endswith(".RSA") or upper.endswith(".DSA")
    ):
        return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--client", required=True)
    parser.add_argument("--server", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    with zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as out:
        written = set()
        # Client wins on conflicts, so write it first and skip duplicates
        # when writing the server's entries.
        for path in (args.client, args.server):
            with zipfile.ZipFile(path, "r") as inp:
                for info in inp.infolist():
                    if info.is_dir():
                        continue
                    if _is_signature_or_manifest(info.filename):
                        continue
                    if info.filename in written:
                        continue
                    written.add(info.filename)
                    out.writestr(info, inp.read(info.filename))

    return 0


if __name__ == "__main__":
    sys.exit(main())
