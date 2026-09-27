#!/usr/bin/env bash
# Keeps Localization/Localizable.xcstrings in step with the source.
#
#   Scripts/localize.sh            add new strings (English marked "new"), drop unused ones
#   Scripts/localize.sh --check    change nothing; fail when a string has no English
#                                  translation or the catalog lists unused strings (CI)
#
# The strings come from the compiler, not from a regex: a build with
# -emit-localized-strings writes every LocalizedStringKey / String(localized:)
# literal of the app modules to .stringsdata files. Keys are the German
# source text (development language de); build-app.sh compiles the catalog
# into de.lproj/en.lproj of the app bundle, where SwiftUI and
# String(localized:) look them up (Bundle.main).
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

SCRATCH=".build/localize"
OUT="$SCRATCH/stringsdata"
rm -rf "$OUT"; mkdir -p "$OUT"
swift build --scratch-path "$SCRATCH" \
    -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$PWD/$OUT" >/dev/null 2>&1 \
    || { echo "build failed — run swift build for details" >&2; exit 1; }

python3 - "$SCRATCH" "Localization/Localizable.xcstrings" "$CHECK" <<'PY'
import glob, json, os, sys
scratch, catalog_path, check = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
app_sources = os.path.abspath("Sources")
kit_free = ("/Sources/AppCore/", "/Sources/App/", "/Sources/HelperShared/")

# Depending on the build system the files land in the -emit path or next to
# the objects; collect both, keep only the app's own modules.
found = {}
for path in glob.glob(os.path.join(scratch, "**", "*.stringsdata"), recursive=True):
    data = json.load(open(path))
    source = data.get("source", "")
    if not source.startswith(app_sources) or not any(part in source for part in kit_free):
        continue
    for entries in data.get("tables", {}).values():
        for entry in entries:
            found.setdefault(entry["key"], entry.get("comment", ""))

catalog = json.load(open(catalog_path))
strings = catalog["strings"]
new = sorted(k for k in found if k not in strings)
unused = sorted(k for k in strings if k not in found)
untranslated = sorted(k for k, v in strings.items() if k in found and
                      v.get("localizations", {}).get("en", {}).get("stringUnit", {}).get("state") != "translated")

if check:
    problems = [("new, not in the catalog", new), ("no English translation", untranslated),
                ("in the catalog, unused in the source", unused)]
    failed = False
    for label, keys in problems:
        for key in keys:
            print(f"{label}: {key!r}"); failed = True
    if failed:
        sys.exit("localization incomplete — run Scripts/localize.sh and translate the new strings")
    print(f"localization complete: {len(found)} strings, de + en")
    sys.exit(0)

for key in new:
    strings[key] = {"localizations": {
        "de": {"stringUnit": {"state": "translated", "value": key}},
        "en": {"stringUnit": {"state": "new", "value": ""}},
    }}
for key in unused:
    del strings[key]
catalog["strings"] = dict(sorted(strings.items()))
with open(catalog_path, "w") as handle:
    json.dump(catalog, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
print(f"{len(found)} strings: {len(new)} new, {len(unused)} removed, "
      f"{len(untranslated) + len(new)} without English translation")
for key in new:
    print(f"  new: {key!r}")
PY
