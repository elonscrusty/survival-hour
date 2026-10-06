import tempfile
import unittest
from pathlib import Path
from prepare_runtime import transform

class RuntimeRequires(unittest.TestCase):
    def test_paths_and_init(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ['shared/Logic/Hatch.luau', 'shared/Config.luau', 'shared/Models/init.luau', 'shared/Models/Data.luau']:
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('')
            self.assertEqual(transform('require("../Config")', root/'shared/Logic/Hatch.luau', root), 'require(script.Parent.Parent["Config"])')
            self.assertEqual(transform('require("./Data")', root/'shared/Models/init.luau', root), 'require(script["Data"])')
            self.assertEqual(transform('require("./Models")', root/'shared/Config.luau', root), 'require(script.Parent["Models"])')
            self.assertEqual(transform('require(Shared.Config)', root/'shared/Config.luau', root), 'require(Shared.Config)')
    def test_missing_target_rejected(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with self.assertRaises(ValueError):
                transform('require("./Missing")', root/'shared/Test.luau', root)

if __name__ == '__main__': unittest.main()
