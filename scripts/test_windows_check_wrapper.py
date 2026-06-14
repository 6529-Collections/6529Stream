"""Regression tests for the Windows local check wrapper."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CHECK_SCRIPT = REPO_ROOT / "scripts" / "check.ps1"


class WindowsCheckWrapperTests(unittest.TestCase):
    """Policy checks for native-command failure handling in check.ps1."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.content = CHECK_SCRIPT.read_text(encoding="utf-8")

    def test_native_commands_are_checked_for_nonzero_exit(self) -> None:
        self.assertIn("function Invoke-CheckedNative", self.content)
        self.assertIn("& $FilePath @Arguments", self.content)
        self.assertIn("if ($LASTEXITCODE -ne 0)", self.content)
        self.assertIn('throw "$FilePath$displayArgs failed with exit code $LASTEXITCODE."', self.content)

    def test_forge_is_routed_through_checked_wrapper(self) -> None:
        self.assertIn(
            "$forgeCommand = Get-Command forge -CommandType Application -ErrorAction SilentlyContinue",
            self.content,
        )
        self.assertIn("$forgePath = $forgeCommand.Source", self.content)
        self.assertRegex(
            self.content,
            re.compile(
                r"function forge\s*\{.*?Invoke-CheckedNative -FilePath "
                r"\$script:forgePath -Arguments \$Arguments",
                re.DOTALL,
            ),
        )
        self.assertIn("forge build", self.content)
        self.assertIn("forge script script/RehearseDeployment.s.sol:RehearseDeployment", self.content)

    def test_selected_python_is_routed_through_checked_wrapper(self) -> None:
        self.assertIn("$pythonExecutable = $pythonPath", self.content)
        self.assertIn("$pythonBaseArgs = $pythonArgs", self.content)
        self.assertRegex(
            self.content,
            re.compile(
                r"function Invoke-CheckedPython\s*\{.*?Invoke-CheckedNative -FilePath "
                r"\$script:pythonExecutable -Arguments "
                r"\(\$script:pythonBaseArgs \+ \$Arguments\)",
                re.DOTALL,
            ),
        )
        self.assertIn('$pythonPath = "Invoke-CheckedPython"', self.content)
        self.assertIn("$pythonArgs = @()", self.content)
        self.assertIn('& $pythonPath @pythonArgs "scripts\\check_metadata_browser_sandbox.py"', self.content)


if __name__ == "__main__":
    unittest.main()
