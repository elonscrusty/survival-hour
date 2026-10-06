"""Reject a place containing CLI-only requires or disabled Luau checks."""
import sys
import xml.etree.ElementTree as ET
from prepare_runtime import RELATIVE_REQUIRE

root = ET.parse(sys.argv[1]).getroot()
sources = [e.text or '' for e in root.iter() if e.get('name') == 'Source']
if not sources:
    raise SystemExit('Place contains no script sources')
for source in sources:
    if RELATIVE_REQUIRE.search(source):
        raise SystemExit('Place contains a relative string require')
    if not source.startswith('--!strict'):
        raise SystemExit('Place contains a script without strict checking')
print(f'place verification: {len(sources)} strict scripts, Roblox module requires')
