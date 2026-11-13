"""Scene Builder - list the MPFB2 assets installed in this Blender.

    blender -b --python list_assets.py -- output.json

Writes {"hair": [...], "clothes": [...], "skins": [...], "eyebrows": [...]}
where each entry is {"name", "path"}. Used by Avatar Studio's lists.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_avatar  # noqa: E402  (same folder; its main() only runs when run directly)

FOLDERS = {"hair": ".mhclo", "clothes": ".mhclo", "skins": ".mhmat", "eyebrows": ".mhclo", "eyes": ".mhclo"}


def main():
    output = sys.argv[sys.argv.index("--") + 1]
    package = build_avatar.find_mpfb()
    if package is None:
        build_avatar.log("ERROR: MPFB2 is not installed or not enabled in this Blender.")
        sys.exit(3)
    roots = build_avatar.asset_roots(package)
    result = {}
    for folder, extension in FOLDERS.items():
        seen = {}
        for root in roots:
            base = os.path.join(root, folder)
            if not os.path.isdir(base):
                continue
            for directory, _dirs, files in os.walk(base):
                for file_name in sorted(files):
                    if file_name.lower().endswith(extension):
                        name = os.path.splitext(file_name)[0]
                        seen.setdefault(name, os.path.join(directory, file_name))
        entries = []
        for name, path in sorted(seen.items()):
            thumb = ""
            for candidate in (os.path.splitext(path)[0] + ".thumb", os.path.splitext(path)[0] + ".png", os.path.splitext(path)[0] + ".jpg"):
                if os.path.exists(candidate):
                    thumb = candidate
                    break
            entries.append({"name": name, "path": path, "thumb": thumb})
        result[folder] = entries
        build_avatar.log("%s: %d" % (folder, len(result[folder])))
    with open(output, "w", encoding="utf-8") as handle:
        json.dump(result, handle, indent=1)
    build_avatar.log("DONE " + output)


main()
