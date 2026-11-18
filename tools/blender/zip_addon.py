"""Packs the add-on folder as an extension .zip without Blender (fallback of build_extension.sh).

Usage: python tools/blender/zip_addon.py <addon_dir> <out.zip>
Skips what ``[build] paths_exclude_pattern`` skips: __pycache__, *.pyc and tests/.
"""

from __future__ import annotations

import os
import sys
import zipfile

SKIP_DIRS = {"__pycache__", "tests"}


def pack(source: str, target: str) -> int:
    count = 0
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for root, dirs, files in os.walk(source):
            dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
            for name in sorted(files):
                if name.endswith(".pyc"):
                    continue
                path = os.path.join(root, name)
                archive.write(path, os.path.relpath(path, source))
                count += 1
    return count


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    print(f"{pack(sys.argv[1], sys.argv[2])} arquivo(s) em {sys.argv[2]}")
