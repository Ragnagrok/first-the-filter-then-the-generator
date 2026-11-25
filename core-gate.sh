#!/usr/bin/env bash
# The mechanical gate on the core, meant to run in CI on every change:
#   - giftcard-core declares no dependencies (dev-dependencies, used only by its tests, are fine);
#   - its lib.rs keeps #![no_std] and #![forbid(unsafe_code)];
#   - its sources don't bring std back. #![no_std] only drops the implicit `extern crate std`:
#     writing it by hand compiles, and std::fs is back. So `extern` may appear only as
#     `extern crate alloc;`, and include!/#[path] (code from files this scan doesn't read) not at all.
# Uses `cargo metadata`, which only reads the manifests: no network, no build.
set -euo pipefail
cd "${1:-$(dirname "$0")}"

cargo metadata --no-deps --format-version 1 | python3 -c '
import json, sys
meta = json.load(sys.stdin)
core = next(p for p in meta["packages"] if p["name"] == "giftcard-core")
deps = [d["name"] for d in core["dependencies"] if d["kind"] != "dev"]
if deps:
    sys.exit("gate: giftcard-core must not depend on anything, found: " + ", ".join(deps))
'

for attr in '#![no_std]' '#![forbid(unsafe_code)]'; do
  grep -qxF "$attr" core/src/lib.rs || { echo "gate: core/src/lib.rs lost $attr" >&2; exit 1; }
done
python3 - <<'PY'
import pathlib, re, sys
bad = []
for f in sorted(pathlib.Path("core/src").rglob("*.rs")):
    text = f.read_text()
    lines = text.splitlines()
    for m in re.finditer(r"\bextern\b|\binclude\s*!|\bpath\s*=", text):
        n = text.count("\n", 0, m.start())
        if lines[n].strip() != "extern crate alloc;":
            bad.append(f"{f}:{n + 1}: {lines[n].strip()}")
if bad:
    sys.exit("gate: core/src may bring in no crate but alloc and no other file, found " + "; ".join(bad))
PY
echo "gate: giftcard-core has no dependencies, no std and no unsafe"
