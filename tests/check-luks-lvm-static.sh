#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n modules/10-power.sh tools/apply-t14s-gen2-amd-profile.sh install.sh
python3 - <<'PY'
from pathlib import Path
s=Path('modules/10-power.sh').read_text()
assert 'crypt_ancestor "$root_source"' in s
assert 'crypt_ancestor "$name"' in s
assert 'part_kb >= ram_kb' in s
assert 'RESUME=UUID=%s' in s
assert 'resume_offset=$RESUME_OFFSET' in s
assert 'rm -f "$f"' not in s
assert 'Existing swap backup found' in s
pre=Path('modules/00-preflight.sh').read_text()
assert 'apply-t14s-gen2-amd-profile.sh" --prepare' in pre
assert 'apply-t14s-gen2-amd-profile.sh" --finalize' in s
print('LUKS/LVM static invariants OK')
PY
