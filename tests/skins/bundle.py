"""Bundle the Roblox mock, fake library and game model modules into one Luau
chunk (the Luau CLI sandboxes each required module's globals, so modules could
not see the mock otherwise) and run it.

    python tests/skins/bundle.py            (needs `luau` on PATH, or LUAU=/path/to/luau)
"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MODELS = os.path.join(ROOT, "src", "shared", "Models")
ORDER = ["Build", "Skins", "Nature", "Flora", "Camp", "Structures", "ItemModels", "LootModels", "Animals", "Decor", "Landmarks"]


def read(p):
    with open(p) as f:
        return f.read()


def modularize(name, src):
    src = re.sub(r'^--!\w+\s*\n', '', src)
    src = re.sub(r'require\("\./(\w+)"\)', r'__m_\1', src)
    src = re.sub(r'require\("\.\./\.\./src/shared/Models/(\w+)"\)', r'__m_\1', src)
    return f"local __m_{name} = (function()\n{src}\nend)()\n"


def main():
    mock = re.sub(r'^--!\w+\s*\n', '', read(os.path.join(HERE, "RobloxMock.luau")))
    mock = mock.replace("\nreturn M\n", "\n")
    data = read(os.path.join(HERE, "LibraryData.luau")).replace("return {", "local __LibraryData = {", 1)
    parts = ["do\n" + mock + "\nend\n" if False else mock, data]
    runner = re.sub(r'^--!\w+\s*\n', '', read(os.path.join(HERE, "run_skins.luau")))
    runner = runner.replace('local Mock = require("./RobloxMock")', "local Mock = M")
    runner = runner.replace('local Data = require("./LibraryData")', "local Data = __LibraryData")
    # modules must be defined after the runner's fake library exists, so split the runner
    head, tail = runner.split('local Skins = require(', 1)
    tail = 'local Skins = require(' + tail
    mods = "".join(modularize(n, read(os.path.join(MODELS, n + ".luau"))) for n in ORDER)
    tail = re.sub(r'require\("\.\./\.\./src/shared/Models/(\w+)"\)', r'__m_\1', tail)
    src = "\n".join(parts) + "\n" + head + "\n" + mods + "\n" + tail
    out = os.path.join(HERE, "_bundle.luau")
    with open(out, "w") as f:
        f.write(src)
    luau = os.environ.get("LUAU", "luau")
    r = subprocess.run([luau, out], capture_output=True, text=True)
    print(r.stdout[-4000:], r.stderr[-4000:])
    os.remove(out)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
