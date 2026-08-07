"""Policy checks for the Windows PowerShell and release-builder CI authority."""

from __future__ import annotations

import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
CI_WORKFLOW = REPO_ROOT / ".github" / "workflows" / "ci.yml"


class WindowsCiWrapperTests(unittest.TestCase):
    """Keep the Windows PowerShell wrapper harness wired into CI."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.content = CI_WORKFLOW.read_text(encoding="utf-8")
        start = cls.content.index("  windows-wrapper:\n")
        end = cls.content.index("\n  slither-baseline:\n", start)
        cls.windows_job = cls.content[start:end]

    def test_windows_powershell_wrapper_job_is_present(self) -> None:
        self.assertIn("windows-wrapper:", self.windows_job)
        self.assertIn("name: Windows PowerShell wrapper", self.windows_job)
        self.assertIn("runs-on: windows-latest", self.windows_job)
        self.assertIn("timeout-minutes: 30", self.windows_job)

    def test_windows_job_uses_windows_powershell(self) -> None:
        self.assertIn("shell: powershell", self.windows_job)
        self.assertIn("scripts\\check.ps1", self.windows_job)
        self.assertIn("scripts\\bootstrap-windows.ps1", self.windows_job)
        self.assertIn("scripts\\windows-check-helpers.ps1", self.windows_job)
        self.assertIn("scripts\\test_windows_check_helpers.ps1", self.windows_job)

    def test_windows_job_runs_runtime_harness_with_bypass(self) -> None:
        self.assertIn(
            "powershell -NoProfile -ExecutionPolicy Bypass -File "
            "scripts\\test_windows_check_helpers.ps1",
            self.windows_job,
        )

    def test_windows_job_runs_and_retains_full_builder_authority(self) -> None:
        self.assertIn("name: Full release-builder test authority", self.windows_job)
        self.assertIn("timeout-minutes: 20", self.windows_job)
        self.assertIn(
            "python scripts/test_release_build_artifacts.py 2>&1 |",
            self.windows_job,
        )
        self.assertIn(
            "Tee-Object -FilePath ci-logs\\release-build-tests-windows.log",
            self.windows_job,
        )
        self.assertIn("name: Upload Windows release-builder log", self.windows_job)
        self.assertIn("if: always()", self.windows_job)
        self.assertIn("name: release-build-tests-windows", self.windows_job)
        self.assertIn(
            "path: ci-logs/release-build-tests-windows.log",
            self.windows_job,
        )


if __name__ == "__main__":
    unittest.main()
