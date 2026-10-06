"""Stage CLI-testable Luau modules with Roblox Instance requires for Rojo."""
import json
import re
import shutil
from pathlib import Path

RELATIVE_REQUIRE = re.compile(r'require\s*\(\s*([\"\'])(\.{1,2}/[^\"\']+)\1\s*\)')

def instance_path(path, src):
    parts = list(path.relative_to(src).parts)
    if parts[-1] == 'init.luau':
        parts.pop()
    else:
        parts[-1] = parts[-1].removesuffix('.luau').removesuffix('.server').removesuffix('.client')
    return parts

def transform(source, path, src):
    def replace(match):
        target = (path.parent / match.group(2)).resolve()
        if target.with_suffix('.luau').is_file():
            target = target.with_suffix('.luau')
        elif (target / 'init.luau').is_file():
            target /= 'init.luau'
        else:
            raise ValueError(f'{path}: missing module {match.group(2)}')
        origin_parts, target_parts = instance_path(path, src), instance_path(target, src)
        common = 0
        for left, right in zip(origin_parts, target_parts):
            if left != right: break
            common += 1
        expression = 'script' + '.Parent' * (len(origin_parts) - common)
        expression += ''.join('[' + json.dumps(part) + ']' for part in target_parts[common:])
        return 'require(' + expression + ')'
    return RELATIVE_REQUIRE.sub(replace, source)

def prepare(root):
    src = root / 'src'
    dest = root / 'build/runtime'
    shutil.rmtree(dest, ignore_errors=True)
    shutil.copytree(src, dest / 'src')
    for path in src.rglob('*.luau'):
        (dest / 'src' / path.relative_to(src)).write_text(transform(path.read_text(), path, src))
    project = json.loads((root / 'default.project.json').read_text())
    def remap(node):
        if isinstance(node, dict):
            for key, value in list(node.items()):
                if key == '$path': node[key] = str(dest / value)
                else: remap(value)
        elif isinstance(node, list):
            for value in node: remap(value)
    remap(project)
    (dest / 'runtime.project.json').write_text(json.dumps(project, indent=2))
    print(dest / 'runtime.project.json')

if __name__ == '__main__': prepare(Path(__file__).resolve().parent.parent)
