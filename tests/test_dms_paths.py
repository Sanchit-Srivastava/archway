"""Read-only DMS discovery tests; never source or run deployment scripts."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "infra/lib/dms.sh"


class DmsPaths(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.config = self.home / "custom config"
        self.config.mkdir()

    def resolve(self, xdg=True):
        env = {"PATH": os.defpath, "HOME": str(self.home)}
        if xdg:
            env["XDG_CONFIG_HOME"] = str(self.config)
        result = subprocess.run(
            ["bash", "--noprofile", "--norc", "-eu", "-c",
             '. "$1"; dms_config_dir', "test", str(HELPER)],
            env=env, text=True, capture_output=True, check=True,
        )
        return Path(result.stdout.strip())

    def test_fresh_v2_without_legacy_alias(self):
        (self.config / "dms").mkdir()
        self.assertEqual(self.resolve(), self.config / "dms")
        self.assertFalse((self.config / "DankMaterialShell").exists())

    def test_legacy_only(self):
        (self.config / "DankMaterialShell").mkdir()
        self.assertEqual(self.resolve(), self.config / "DankMaterialShell")
        self.assertFalse((self.config / "dms").exists())

    def test_new_directory_wins_when_both_exist(self):
        (self.config / "dms").mkdir()
        (self.config / "DankMaterialShell").mkdir()
        self.assertEqual(self.resolve(), self.config / "dms")

    def test_upstream_migration_symlink(self):
        (self.config / "dms").mkdir()
        (self.config / "DankMaterialShell").symlink_to("dms")
        self.assertEqual(self.resolve(), self.config / "dms")
        self.assertTrue((self.config / "DankMaterialShell").is_symlink())

    def test_persisted_legacy_directory_symlink(self):
        (self.config / "DankMaterialShell").mkdir()
        (self.config / "dms").symlink_to("DankMaterialShell")
        self.assertEqual(self.resolve(), self.config / "dms")

    def test_uninitialized_does_not_create_directories(self):
        self.assertEqual(self.resolve(), self.config / "dms")
        self.assertEqual(list(self.config.iterdir()), [])

    def test_broken_legacy_symlink_is_not_initialized(self):
        (self.config / "DankMaterialShell").symlink_to("missing")
        self.assertEqual(self.resolve(), self.config / "dms")
        self.assertFalse((self.config / "dms").exists())

    def test_unset_xdg_uses_home(self):
        target = self.home / ".config/dms"
        target.mkdir(parents=True)
        self.assertEqual(self.resolve(xdg=False), target)

    def test_empty_xdg_uses_home(self):
        self.config = Path("")
        env = {"PATH": os.defpath, "HOME": str(self.home), "XDG_CONFIG_HOME": ""}
        output = subprocess.check_output(
            ["bash", "--noprofile", "--norc", "-eu", "-c",
             '. "$1"; dms_config_dir', "test", str(HELPER)],
            env=env, text=True,
        )
        self.assertEqual(Path(output.strip()), self.home / ".config/dms")


if __name__ == "__main__":
    unittest.main()
