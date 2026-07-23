#!/usr/bin/env python3
"""Focused tests for the external-call gas inventory checker."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("check_external_call_gas_inventory.py")
SPEC = importlib.util.spec_from_file_location("check_external_call_gas_inventory", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8", newline="\n")


def base_inventory(
    *,
    calls: list[dict[str, Any]] | None = None,
    probes: list[dict[str, Any]] | None = None,
    declarations: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    return {
        "schema_version": checker.SCHEMA_VERSION,
        "tracking_issue": checker.TRACKING_ISSUE,
        "status": "open-remediation-inventory",
        "note": "Open rows are temporary remediation inventory.",
        "open_call_gas_expressions": calls or [],
        "explicit_probe_call_gas_expressions": probes or [],
        "open_literal_gas_declarations": declarations or [],
    }


def open_call(
    expression: str,
    *,
    site: str = "f",
    kind: str = "call-option",
    operation: str = "external-call",
    count: int = 1,
) -> dict[str, Any]:
    return {
        "path": "smart-contracts/Fixture.sol",
        "site": site,
        "kind": kind,
        "operation": operation,
        "expression": expression,
        "expected_count": count,
        "path_class": "user-path",
        "lane": "minting",
        "issue": "#669",
        "disposition": "open-remediation-required",
    }


def literal_declaration(identifier: str, value: int) -> dict[str, Any]:
    return {
        "path": "smart-contracts/Fixture.sol",
        "identifier": identifier,
        "value": value,
        "expected_count": 1,
        "path_class": "user-path",
        "lane": "minting",
        "issue": "#669",
        "disposition": "open-remediation-required",
    }


def write_tree(root: Path, source: str, inventory: dict[str, Any]) -> None:
    source_path = root / "smart-contracts/Fixture.sol"
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(source, encoding="utf-8", newline="\n")
    write_json(root / checker.DEFAULT_INVENTORY, inventory)


class ExternalCallGasInventoryTests(unittest.TestCase):
    def test_available_gas_yul_calls_need_no_inventory_row(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target) external view {
                        target.staticcall{gas: gasleft()}("");
                        assembly {
                            pop(staticcall(gas(), target, 0, 0, 0, 0))
                            pop(staticcall(gasleft(), target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_comments_and_strings_do_not_create_findings(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    string private constant SAMPLE = "target.call{gas: 30000}()";
                    string private constant STIPEND = "payable(target).transfer(1)";
                    // target.call{gas: 30000}("");
                    // payable(target).send(1);
                    /* assembly { pop(staticcall(30000, 0, 0, 0, 0, 0)) } */
                    /* payable(target).transfer(1); */
                }
                """,
                base_inventory(),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_implicit_native_transfer_stipends_fail(self) -> None:
        for operation in ("transfer", "send"):
            with self.subTest(operation=operation), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                write_tree(
                    root,
                    (
                        "contract Fixture { function f(address target) external { "
                        f"payable(target).{operation}(1);"
                        " } }"
                    ),
                    base_inventory(),
                )

                with self.assertRaisesRegex(
                    checker.GasInventoryError, "implicit fixed-gas stipend"
                ):
                    checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_longer_member_names_do_not_match_implicit_stipends(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target) external {
                        target.transferFrom(address(this), target, 1);
                        target.sendValue(1);
                    }
                }
                """,
                base_inventory(),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_uninventoried_call_option_literal_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                (
                    "contract Fixture { function f(address a) external "
                    '{ a.call{gas: 30_000}(""); } }'
                ),
                base_inventory(),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError, "unexpected call-gas expression"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_uninventoried_yul_literal_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target) external view {
                        assembly { pop(staticcall(30000, target, 0, 0, 0, 0)) }
                    }
                }
                """,
                base_inventory(),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError, "unexpected call-gas expression"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_exact_call_inventory_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target, uint256 cap) external view {
                        assembly { pop(staticcall(cap, target, 0, 0, 0, 0)) }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "cap", kind="yul-call", operation="staticcall"
                        )
                    ]
                ),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_added_use_of_inventoried_expression_fails_count_check(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target, uint256 cap) external view {
                        assembly {
                            pop(staticcall(cap, target, 0, 0, 0, 0))
                            pop(staticcall(cap, target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "cap", kind="yul-call", operation="staticcall"
                        )
                    ]
                ),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError, "unexpected call-gas expression"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_missing_inventory_source_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, "contract Fixture {}", base_inventory(calls=[open_call("cap")]))

            with self.assertRaisesRegex(
                checker.GasInventoryError, "missing inventoried call-gas expression"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_literal_gas_declaration_requires_exact_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 private constant READ_GAS_LIMIT = 30_000;
                    function f(address target) external view {
                        assembly {
                            pop(staticcall(READ_GAS_LIMIT, target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "READ_GAS_LIMIT",
                            kind="yul-call",
                            operation="staticcall",
                        )
                    ],
                    declarations=[literal_declaration("READ_GAS_LIMIT", 30_000)],
                ),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_wrapped_literal_gas_declaration_requires_exact_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 private constant READ_GAS_LIMIT = uint32((3e4));
                    function f(address target) external view {
                        target.staticcall{gas: READ_GAS_LIMIT}("");
                    }
                }
                """,
                base_inventory(
                    calls=[open_call("READ_GAS_LIMIT")],
                    declarations=[literal_declaration("READ_GAS_LIMIT", 30_000)],
                ),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_arithmetic_literal_gas_declaration_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 private constant READ_GAS_LIMIT = 30_000 + 1;
                    function f(address target) external view {
                        target.staticcall{gas: READ_GAS_LIMIT}("");
                    }
                }
                """,
                base_inventory(calls=[open_call("READ_GAS_LIMIT")]),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "non-canonical literal gas declaration",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_literal_gas_declaration_value_drift_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 private immutable READ_GAS_LIMIT = 31_000;
                    function f(address target) external view {
                        assembly {
                            pop(staticcall(READ_GAS_LIMIT, target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "READ_GAS_LIMIT",
                            kind="yul-call",
                            operation="staticcall",
                        )
                    ],
                    declarations=[literal_declaration("READ_GAS_LIMIT", 30_000)],
                ),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError, "literal gas declaration"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_literal_alias_for_inventoried_call_expression_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target) external view {
                        uint256 forwardedGas = 30_000;
                        assembly {
                            pop(staticcall(forwardedGas, target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "forwardedGas",
                            kind="yul-call",
                            operation="staticcall",
                        )
                    ]
                ),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "literal assignment aliases call-gas expression",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_literal_member_assignment_for_call_expression_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    struct Call { uint256 gasLimit; }
                    function f(address target) external view {
                        Call memory gateCall;
                        gateCall.gasLimit = uint32(30_000);
                        target.staticcall{gas: gateCall.gasLimit}("");
                    }
                }
                """,
                base_inventory(calls=[open_call("gateCall.gasLimit")]),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "literal assignment aliases call-gas expression",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_literal_struct_field_for_call_expression_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    struct Call { uint256 gasLimit; }
                    function f(address target) external view {
                        Call memory gateCall = Call({gasLimit: (30_000)});
                        target.staticcall{gas: gateCall.gasLimit}("");
                    }
                }
                """,
                base_inventory(calls=[open_call("gateCall.gasLimit")]),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "literal assignment aliases call-gas expression",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_positional_struct_literal_for_member_call_expression_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    struct Call { uint256 gasLimit; }
                    function f(address target) external view {
                        Call memory gateCall = Call(uint32(30_000));
                        target.staticcall{gas: gateCall.gasLimit}("");
                    }
                }
                """,
                base_inventory(calls=[open_call("gateCall.gasLimit")]),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "literal assignment aliases call-gas expression",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_yul_literal_alias_with_scientific_notation_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    function f(address target) external view {
                        assembly {
                            let forwardedGas := 30e3
                            pop(staticcall(forwardedGas, target, 0, 0, 0, 0))
                        }
                    }
                }
                """,
                base_inventory(
                    calls=[
                        open_call(
                            "forwardedGas",
                            kind="yul-call",
                            operation="staticcall",
                        )
                    ]
                ),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "literal assignment aliases call-gas expression",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_constructor_assigned_immutable_requires_exact_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 public immutable READ_GAS_LIMIT;
                    constructor() { READ_GAS_LIMIT = uint256(30_000); }
                    function f(address target) external view {
                        target.staticcall{gas: READ_GAS_LIMIT}("");
                    }
                }
                """,
                base_inventory(
                    calls=[open_call("READ_GAS_LIMIT")],
                    declarations=[literal_declaration("READ_GAS_LIMIT", 30_000)],
                ),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_arithmetic_constructor_immutable_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 public immutable READ_GAS_LIMIT;
                    constructor() { READ_GAS_LIMIT = 30_000 + 1; }
                    function f(address target) external view {
                        target.staticcall{gas: READ_GAS_LIMIT}("");
                    }
                }
                """,
                base_inventory(calls=[open_call("READ_GAS_LIMIT")]),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError,
                "non-canonical literal gas declaration",
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_same_named_immutables_are_scoped_to_their_contracts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract First {
                    uint256 private immutable READ_GAS_LIMIT;
                    constructor() { READ_GAS_LIMIT = 30_000; }
                }
                contract Second {
                    uint256 private immutable READ_GAS_LIMIT;
                    constructor() { READ_GAS_LIMIT = 31_000; }
                }
                """,
                base_inventory(
                    declarations=[
                        literal_declaration("READ_GAS_LIMIT", 30_000),
                        literal_declaration("READ_GAS_LIMIT", 31_000),
                    ]
                ),
            )

            checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_override_modifier_literal_requires_inventory(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                """
                contract Fixture {
                    uint256 public constant override(IFoo) READ_GAS_LIMIT = 30e3;
                }
                """,
                base_inventory(),
            )

            with self.assertRaisesRegex(
                checker.GasInventoryError, "unexpected literal gas declaration"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)

    def test_open_row_cannot_be_labeled_as_accepted(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            row = open_call("cap")
            row["disposition"] = "accepted-risk"
            write_tree(root, "contract Fixture {}", base_inventory(calls=[row]))

            with self.assertRaisesRegex(
                checker.GasInventoryError, "open-remediation-required"
            ):
                checker.check_repository(root, checker.DEFAULT_INVENTORY)


if __name__ == "__main__":
    unittest.main()
