"""Policy checks for the lightweight Windows PowerShell wrapper CI job."""

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

    def test_windows_powershell_wrapper_job_is_present(self) -> None:
        self.assertIn("windows-wrapper:", self.content)
        self.assertIn("name: Windows PowerShell wrapper", self.content)
        self.assertIn("runs-on: windows-latest", self.content)
        self.assertIn("timeout-minutes: 10", self.content)

    def test_windows_job_uses_windows_powershell(self) -> None:
        self.assertIn("shell: powershell", self.content)
        self.assertIn("scripts\\check.ps1", self.content)
        self.assertIn("scripts\\bootstrap-windows.ps1", self.content)
        self.assertIn("scripts\\windows-check-helpers.ps1", self.content)
        self.assertIn("scripts\\test_windows_check_helpers.ps1", self.content)

    def test_windows_job_runs_runtime_harness_with_bypass(self) -> None:
        self.assertIn(
            "powershell -NoProfile -ExecutionPolicy Bypass -File "
            "scripts\\test_windows_check_helpers.ps1",
            self.content,
        )


if __name__ == "__main__":
    unittest.main()
