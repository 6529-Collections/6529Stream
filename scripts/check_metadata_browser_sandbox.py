#!/usr/bin/env python3
"""Execute committed metadata animation fixtures in a browser sandbox."""

from __future__ import annotations

import argparse
import html as html_lib
import importlib.util
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


CHECKER_PATH = Path(__file__).with_name("check_metadata_fixtures.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_fixtures", CHECKER_PATH)
assert SPEC is not None and SPEC.loader is not None
fixture_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = fixture_checker
SPEC.loader.exec_module(fixture_checker)

EXPECTED_FINAL_HASH = "0x010f958c43f59a15d2a5049f5e0c64d04210483872fa85f816f1779036038114"
EXPECTED_FINAL_TOKEN_ID = 10_000_000_000
EXPECTED_FINAL_TOKEN_DATA_RAW = "1,2,3"
EXPECTED_FINAL_TOKEN_DATA = (1, 2, 3)

DEPENDENCY_STUB = """
(() => {
  window.__metadataSandboxDependencyLoaded = true;
  window.__metadataSandboxDependencyUrl = document.currentScript && document.currentScript.src;
})();
""".strip()


class BrowserSandboxError(ValueError):
    """Raised when the browser sandbox fixture check fails."""


@dataclass(frozen=True)
class AnimationFixture:
    """Decoded final animation fixture details needed by the browser harness."""

    animation_url: str
    animation_html: str
    external_script_url: str


@dataclass(frozen=True)
class ExpectedBootstrap:
    """Expected top-level animation bootstrap values for the committed fixture."""

    hash_value: str
    token_id: int
    token_data_raw: str
    token_data: tuple[int, ...]


@dataclass(frozen=True)
class SandboxResult:
    """Observed browser execution snapshot for the sandboxed metadata frame."""

    expected_script_requests: tuple[str, ...]
    unexpected_requests: tuple[str, ...]
    page_errors: tuple[str, ...]
    console_errors: tuple[str, ...]
    dependency_loaded: bool
    dependency_url: str | None
    script_count: int
    hash_value: str | None
    token_id: int | float | None
    token_data_raw: str | None
    token_data_is_array: bool
    token_data_values: tuple[Any, ...]
    draw_is_function: bool
    parent_access_blocked: bool
    parent_access_error_name: str | None


DEFAULT_EXPECTED_BOOTSTRAP = ExpectedBootstrap(
    hash_value=EXPECTED_FINAL_HASH,
    token_id=EXPECTED_FINAL_TOKEN_ID,
    token_data_raw=EXPECTED_FINAL_TOKEN_DATA_RAW,
    token_data=EXPECTED_FINAL_TOKEN_DATA,
)


def load_final_animation_fixture(fixtures_dir: Path) -> AnimationFixture:
    """Load, decode, and statically validate the committed final animation fixture."""

    token_uri = fixture_checker.read_fixture(fixtures_dir, fixture_checker.ONCHAIN_FINAL_FIXTURE)
    return load_animation_from_token_uri(token_uri, label="on-chain final tokenURI")


def load_animation_from_token_uri(token_uri: str, *, label: str) -> AnimationFixture:
    """Load, decode, and statically validate a final on-chain metadata tokenURI."""

    final_json = fixture_checker.decode_data_uri(
        token_uri,
        fixture_checker.JSON_DATA_URI_PREFIX,
        label,
    )
    final_metadata = fixture_checker.validate_metadata_json(
        final_json, expected_state=fixture_checker.STATE_FINAL
    )
    animation_url = final_metadata["animation_url"]
    if not isinstance(animation_url, str):
        raise BrowserSandboxError("final animation_url must be a string")

    animation_html = fixture_checker.decode_data_uri(
        animation_url,
        fixture_checker.HTML_DATA_URI_PREFIX,
        "final animation_url",
    )
    fixture_checker.validate_animation_html(animation_html)

    parser = fixture_checker.RenderSandboxParser()
    parser.feed(animation_html)
    parser.close()
    if len(parser.scripts) != 2:
        raise BrowserSandboxError(f"expected two animation scripts, found {len(parser.scripts)}")

    external_script_url = parser.scripts[0].attrs["src"]
    return AnimationFixture(
        animation_url=animation_url,
        animation_html=animation_html,
        external_script_url=external_script_url,
    )


def build_harness_document(animation_url: str) -> str:
    """Build a minimal parent page that executes the animation in a sandboxed iframe."""

    escaped_animation_url = html_lib.escape(animation_url, quote=True)
    return (
        "<!doctype html><html><head><meta charset=\"utf-8\"></head><body>"
        f"<iframe id=\"metadata-frame\" sandbox=\"allow-scripts\" src=\"{escaped_animation_url}\">"
        "</iframe></body></html>"
    )


def run_browser_sandbox(fixture: AnimationFixture, *, timeout_ms: int, headed: bool) -> SandboxResult:
    """Execute the animation fixture in Chromium and return the observed sandbox state."""

    try:
        from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
        from playwright.sync_api import sync_playwright
    except ModuleNotFoundError as exc:
        raise BrowserSandboxError(
            "playwright is not installed. Run `python -m pip install -r "
            "requirements-tools.txt` and `python -m playwright install chromium`, "
            "then retry this check."
        ) from exc

    expected_script_requests: list[str] = []
    unexpected_requests: list[str] = []
    page_errors: list[str] = []
    console_errors: list[str] = []
    snapshot: dict[str, Any] | None = None

    with sync_playwright() as playwright:
        try:
            browser = playwright.chromium.launch(headless=not headed)
        except Exception as exc:  # pragma: no cover - exercised only in local setup failures
            raise BrowserSandboxError(
                "chromium is not installed for Playwright. Run "
                "`python -m playwright install chromium`, then retry this check."
            ) from exc

        context = None
        try:
            context = browser.new_context(java_script_enabled=True)
            page = context.new_page()
            page.set_default_timeout(timeout_ms)

            def handle_route(route: Any, request: Any) -> None:
                url = request.url
                if url == fixture.external_script_url:
                    expected_script_requests.append(url)
                    route.fulfill(
                        status=200,
                        content_type="application/javascript; charset=utf-8",
                        body=DEPENDENCY_STUB,
                    )
                    return
                if url.startswith(("http://", "https://")):
                    unexpected_requests.append(url)
                    route.abort()
                    return
                route.continue_()

            page.route("**/*", handle_route)
            page.on("pageerror", lambda exc: page_errors.append(str(exc)))
            page.on(
                "console",
                lambda msg: console_errors.append(f"{msg.type}: {msg.text}")
                if msg.type == "error"
                else None,
            )

            page.set_content(
                build_harness_document(fixture.animation_url),
                wait_until="domcontentloaded",
                timeout=timeout_ms,
            )
            frame_element = page.wait_for_selector("#metadata-frame", timeout=timeout_ms)
            if frame_element is None:
                raise BrowserSandboxError("metadata sandbox iframe did not attach")

            frame = frame_element.content_frame()
            if frame is None:
                raise BrowserSandboxError("metadata sandbox iframe has no frame context")

            try:
                frame.wait_for_load_state("load", timeout=timeout_ms)
                frame.wait_for_function(
                    "window.__metadataSandboxDependencyLoaded === true "
                    "&& typeof draw === 'function'",
                    timeout=timeout_ms,
                )
            except PlaywrightTimeoutError as exc:
                page_errors.append(f"timed out waiting for animation bootstrap: {exc}")

            snapshot = frame.evaluate(
                """
() => {
  const read = (expression) => {
    try {
      return Function(`"use strict"; return (${expression});`)();
    } catch (error) {
      return null;
    }
  };
  let parentAccessBlocked = false;
  let parentAccessErrorName = null;
  try {
    void window.parent.document.body;
  } catch (error) {
    parentAccessBlocked = true;
    parentAccessErrorName = error && error.name ? error.name : String(error);
  }
  const tokenDataValue = read("typeof tokenData === 'undefined' ? null : tokenData");
  return {
    dependencyLoaded: window.__metadataSandboxDependencyLoaded === true,
    dependencyUrl: window.__metadataSandboxDependencyUrl || null,
    scriptCount: document.scripts.length,
    hashValue: read("typeof hash === 'undefined' ? null : hash"),
    tokenId: read("typeof tokenId === 'undefined' ? null : tokenId"),
    tokenDataRaw: read("typeof tokenDataRaw === 'undefined' ? null : tokenDataRaw"),
    tokenDataIsArray: Array.isArray(tokenDataValue),
    tokenDataValues: Array.isArray(tokenDataValue) ? tokenDataValue : [],
    drawIsFunction: typeof draw === "function",
    parentAccessBlocked,
    parentAccessErrorName,
  };
}
"""
            )
        finally:
            if context is not None:
                context.close()
            browser.close()

    if snapshot is None:
        raise BrowserSandboxError("metadata sandbox did not produce a browser snapshot")

    return SandboxResult(
        expected_script_requests=tuple(expected_script_requests),
        unexpected_requests=tuple(unexpected_requests),
        page_errors=tuple(page_errors),
        console_errors=tuple(console_errors),
        dependency_loaded=bool(snapshot["dependencyLoaded"]),
        dependency_url=snapshot["dependencyUrl"],
        script_count=int(snapshot["scriptCount"]),
        hash_value=snapshot["hashValue"],
        token_id=snapshot["tokenId"],
        token_data_raw=snapshot["tokenDataRaw"],
        token_data_is_array=bool(snapshot["tokenDataIsArray"]),
        token_data_values=tuple(snapshot["tokenDataValues"]),
        draw_is_function=bool(snapshot["drawIsFunction"]),
        parent_access_blocked=bool(snapshot["parentAccessBlocked"]),
        parent_access_error_name=snapshot["parentAccessErrorName"],
    )


def validate_sandbox_result(
    result: SandboxResult,
    *,
    expected_external_script_url: str,
    expected_bootstrap: ExpectedBootstrap = DEFAULT_EXPECTED_BOOTSTRAP,
) -> None:
    """Raise when the observed browser sandbox state violates the fixture policy."""

    if result.expected_script_requests != (expected_external_script_url,):
        raise BrowserSandboxError(
            "expected exactly one external dependency request to "
            f"{expected_external_script_url}, got {result.expected_script_requests}"
        )
    if result.unexpected_requests:
        raise BrowserSandboxError(
            "unexpected outbound browser requests: " + ", ".join(result.unexpected_requests)
        )
    if result.page_errors:
        raise BrowserSandboxError("browser page errors: " + " | ".join(result.page_errors))
    if result.console_errors:
        raise BrowserSandboxError("browser console errors: " + " | ".join(result.console_errors))
    if not result.dependency_loaded or result.dependency_url != expected_external_script_url:
        raise BrowserSandboxError("dependency stub did not execute inside the metadata frame")
    if result.script_count != 2:
        raise BrowserSandboxError(f"expected two scripts in metadata frame, got {result.script_count}")
    if result.hash_value != expected_bootstrap.hash_value:
        raise BrowserSandboxError(
            f"unexpected hash bootstrap value: {result.hash_value!r}"
        )
    if result.token_id != expected_bootstrap.token_id:
        raise BrowserSandboxError(
            f"unexpected tokenId bootstrap value: {result.token_id!r}"
        )
    if result.token_data_raw != expected_bootstrap.token_data_raw:
        raise BrowserSandboxError(
            f"unexpected tokenDataRaw bootstrap value: {result.token_data_raw!r}"
        )
    if not result.token_data_is_array or result.token_data_values != expected_bootstrap.token_data:
        raise BrowserSandboxError(
            f"unexpected tokenData bootstrap value: {result.token_data_values!r}"
        )
    if not result.draw_is_function:
        raise BrowserSandboxError("draw bootstrap function is unavailable in metadata frame")
    if not result.parent_access_blocked:
        raise BrowserSandboxError("sandboxed metadata frame can access the parent document")
    if result.parent_access_error_name != "SecurityError":
        raise BrowserSandboxError(
            "sandboxed metadata frame parent access failed with unexpected error "
            f"{result.parent_access_error_name!r}"
        )


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser for the browser sandbox checker."""

    parser = argparse.ArgumentParser(
        description="Execute committed final metadata animation fixtures in a browser sandbox."
    )
    parser.add_argument(
        "--fixtures-dir",
        type=Path,
        default=Path("test/fixtures/metadata"),
        help="Directory containing metadata golden fixture files.",
    )
    parser.add_argument(
        "--timeout-ms",
        type=int,
        default=10_000,
        help="Browser operation timeout in milliseconds.",
    )
    parser.add_argument(
        "--headed",
        action="store_true",
        help="Run Chromium with a visible browser window for local debugging.",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    """Run the metadata browser sandbox check from the command line."""

    args = build_parser().parse_args(argv)
    try:
        fixture = load_final_animation_fixture(args.fixtures_dir)
        result = run_browser_sandbox(fixture, timeout_ms=args.timeout_ms, headed=args.headed)
        validate_sandbox_result(
            result,
            expected_external_script_url=fixture.external_script_url,
        )
    except (BrowserSandboxError, fixture_checker.MetadataFixtureError) as exc:
        print(f"metadata browser sandbox check failed: {exc}", file=sys.stderr)
        return 1

    print(
        "Validated metadata browser sandbox fixture in "
        f"{args.fixtures_dir} with dependency {fixture.external_script_url}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
