"""Regression tests for the Windows local check wrapper."""

from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CHECK_SCRIPT = REPO_ROOT / "scripts" / "check.ps1"
HELPER_SCRIPT = REPO_ROOT / "scripts" / "windows-check-helpers.ps1"
RUNTIME_TEST_SCRIPT = REPO_ROOT / "scripts" / "test_windows_check_helpers.ps1"


class WindowsCheckWrapperTests(unittest.TestCase):
    """Policy checks for native-command failure handling in check.ps1."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.check_content = CHECK_SCRIPT.read_text(encoding="utf-8")
        cls.helper_content = HELPER_SCRIPT.read_text(encoding="utf-8")
        cls.runtime_test_content = RUNTIME_TEST_SCRIPT.read_text(encoding="utf-8")

    def test_native_commands_are_checked_for_nonzero_exit(self) -> None:
        self.assertIn("function Invoke-CheckedNative", self.helper_content)
        self.assertIn('$previousErrorActionPreference = $ErrorActionPreference', self.helper_content)
        self.assertIn('$ErrorActionPreference = "Continue"', self.helper_content)
        self.assertIn("& $FilePath @Arguments", self.helper_content)
        self.assertIn("$exitCode = $LASTEXITCODE", self.helper_content)
        self.assertIn("if ($exitCode -ne 0)", self.helper_content)
        self.assertIn('throw "$FilePath$displayArgs failed with exit code $exitCode."', self.helper_content)
        self.assertIn('. (Join-Path $PSScriptRoot "windows-check-helpers.ps1")', self.check_content)

    def test_forge_is_routed_through_checked_wrapper(self) -> None:
        self.assertIn(
            "$forgeCommand = Get-Command forge -CommandType Application -ErrorAction SilentlyContinue",
            self.check_content,
        )
        self.assertIn("$forgePath = $forgeCommand.Source", self.check_content)
        self.assertRegex(
            self.check_content,
            re.compile(
                r"function forge\s*\{.*?Invoke-CheckedNative -FilePath "
                r"\$script:forgePath -Arguments \$Arguments",
                re.DOTALL,
            ),
        )
        self.assertIn("forge build", self.check_content)
        self.assertIn(
            "forge script script/RehearseDeploymentSuite.s.sol:RehearseDeploymentSuite",
            self.check_content,
        )
        self.assertIn(
            "forge script script/RehearseDeployment.s.sol:RehearseDeployment", self.check_content
        )
        self.assertIn(
            "forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony",
            self.check_content,
        )
        self.assertIn(
            "forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment",
            self.check_content,
        )

    def test_selected_python_is_routed_through_checked_wrapper(self) -> None:
        self.assertIn("$pythonExecutable = $pythonPath", self.check_content)
        self.assertIn("$pythonBaseArgs = $pythonArgs", self.check_content)
        self.assertRegex(
            self.check_content,
            re.compile(
                r"function Invoke-CheckedPython\s*\{.*?Invoke-CheckedNative -FilePath "
                r"\$script:pythonExecutable -Arguments "
                r"\(\$script:pythonBaseArgs \+ \$Arguments\)",
                re.DOTALL,
            ),
        )
        self.assertIn('$pythonPath = "Invoke-CheckedPython"', self.check_content)
        self.assertIn("$pythonArgs = @()", self.check_content)
        self.assertIn('& $pythonPath @pythonArgs "scripts\\check_metadata_browser_sandbox.py"', self.check_content)
        self.assertIn('& $pythonPath @pythonArgs "scripts\\test_contract_size_budget.py"', self.check_content)
        self.assertIn('& $pythonPath @pythonArgs "scripts\\check_contract_size_budget.py"', self.check_content)
        self.assertIn(
            '& $pythonPath @pythonArgs "scripts\\test_release_build_artifacts.py"',
            self.check_content,
        )
        self.assertIn(
            '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py"',
            self.check_content,
        )
        self.assertIn(
            '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py" "--check"',
            self.check_content,
        )
        self.assertIn('& $pythonPath @pythonArgs "scripts\\test_deployment_rehearsal_gate.py"', self.check_content)
        self.assertIn('& $pythonPath @pythonArgs "scripts\\check_deployment_rehearsal_gate.py"', self.check_content)

    def test_runtime_harness_exercises_success_and_failure_paths(self) -> None:
        self.assertIn('. (Join-Path $PSScriptRoot "windows-check-helpers.ps1")', self.runtime_test_content)
        self.assertIn("Invoke-CheckedNative -FilePath $nativeHarness.FilePath", self.runtime_test_content)
        self.assertGreaterEqual(
            self.runtime_test_content.count(
                "Invoke-CheckedNative -FilePath $nativeHarness.FilePath -Arguments $nativeHarness.SuccessArguments"
            ),
            2,
        )
        self.assertIn("failed with exit code 7", self.runtime_test_content)
        self.assertIn("WarningArguments", self.runtime_test_content)
        self.assertIn('& (Join-Path $PSScriptRoot "test_windows_check_helpers.ps1")', self.check_content)


if __name__ == "__main__":
    unittest.main()
