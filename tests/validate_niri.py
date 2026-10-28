"""Validate config and include behavior without launching a compositor."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "dots/niri"
NIRI = os.environ.get("NIRI", "niri")


class NiriConfig(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.config = Path(self.tmp.name) / "niri"
        shutil.copytree(SOURCE, self.config)

    def validate(self, expected):
        result = subprocess.run(
            [NIRI, "validate", "-c", str(self.config / "config.kdl")],
            text=True, capture_output=True,
        )
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)

    def test_missing_generated_files_are_optional(self):
        self.validate(0)

    def test_existing_generated_file_is_loaded(self):
        (self.config / "dms/colors.kdl").write_text(
            'layout { border { active-color "#abcdef"; }; }\n'
        )
        self.validate(0)

    def test_malformed_generated_file_still_fails(self):
        (self.config / "dms/colors.kdl").write_text('not-a-niri-option\n')
        self.validate(1)

    def test_missing_archway_binds_still_fails(self):
        (self.config / "dms/binds.kdl").unlink()
        self.validate(1)

    def test_missing_archway_windowrules_still_fails(self):
        (self.config / "dms/windowrules.kdl").unlink()
        self.validate(1)


if __name__ == "__main__":
    subprocess.run([NIRI, "--version"], check=True)
    unittest.main()
