#!/usr/bin/env python3
"""Reject unreviewed external-call gas expressions and literal cap declarations."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any, NamedTuple, Sequence


SCHEMA_VERSION = "6529stream.external-call-gas-inventory.v1"
TRACKING_ISSUE = "https://github.com/6529-Collections/6529Stream/issues/669"
DEFAULT_INVENTORY = Path("ops/EXTERNAL_CALL_GAS_INVENTORY.json")
SOLIDITY_ROOT = Path("smart-contracts")
INVENTORY_NOTE = (
    "Open rows are exact temporary inventory, not accepted risk or permanent "
    "exceptions. Remove or govern them through #669 follow-up slices."
)
OPEN_LANES = {"finality", "minting", "revenue"}
PATH_CLASSES = {
    "deployment-constructor",
    "live-control-plane",
    "user-path",
    "observability-diagnostic",
    "mixed-deployment-and-user-path",
    "mixed-control-plane-and-user-path",
    "mixed-user-and-observability",
}
YUL_AVAILABLE_GAS_EXPRESSION = "gas()"
IJSON_MAX_SAFE_INTEGER = (1 << 53) - 1
TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "tracking_issue",
        "status",
        "note",
        "open_call_gas_expressions",
        "explicit_probe_call_gas_expressions",
        "open_literal_gas_declarations",
    }
)
OPEN_CALL_FIELDS = frozenset(
    {
        "path",
        "site",
        "kind",
        "operation",
        "expression",
        "expected_count",
        "path_class",
        "lane",
        "issue",
        "disposition",
    }
)
LITERAL_DECLARATION_FIELDS = frozenset(
    {
        "path",
        "identifier",
        "value",
        "expected_count",
        "path_class",
        "lane",
        "issue",
        "disposition",
    }
)
NUMERIC_LITERAL_BODY = (
    r"(?:0x[0-9A-Fa-f](?:_?[0-9A-Fa-f])*|"
    r"[0-9](?:_?[0-9])*(?:\.[0-9](?:_?[0-9])*)?"
    r"(?:[eE][+-]?[0-9](?:_?[0-9])*)?)"
)
NUMERIC_LITERAL_RE = re.compile(
    rf"(?<![_A-Za-z0-9])(?P<value>{NUMERIC_LITERAL_BODY})(?![_A-Za-z0-9])"
)
STATE_MODIFIER = (
    r"(?:public|private|internal|external|constant|immutable|"
    r"override(?:\s*\([^)]*\))?)"
)
CALL_OPTION_GAS_RE = re.compile(r"\bgas\s*:")
YUL_CALL_RE = re.compile(
    r"(?<![\w.])(?P<operation>staticcall|delegatecall|callcode|call)\s*\("
)
IMPLICIT_STIPEND_RE = re.compile(r"\.\s*(?P<operation>transfer|send)\s*\(")
CALLABLE_RE = re.compile(
    r"\b(?:function\s+(?P<function>[_A-Za-z][_A-Za-z0-9]*)|"
    r"(?P<special>constructor|fallback|receive))\s*\("
)
ASSEMBLY_BLOCK_RE = re.compile(r"\bassembly(?:\s*\([^)]*\))?\s*\{")
INITIALIZED_INTEGER_DECL_RE = re.compile(
    rf"""
    \b(?:uint|int)(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|
       136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)?
    \s+
    (?P<modifiers>(?:{STATE_MODIFIER}\s+)+)
    (?P<identifier>[_A-Za-z][_A-Za-z0-9]*)
    \s*=\s*
    """,
    re.VERBOSE,
)
UNINITIALIZED_IMMUTABLE_RE = re.compile(
    rf"""
    \b(?:uint|int)(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|
       136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)?
    \s+
    (?P<modifiers>(?:{STATE_MODIFIER}\s+)+)
    (?P<identifier>[_A-Za-z][_A-Za-z0-9]*)
    \s*;
    """,
    re.VERBOSE,
)
ASSIGNMENT_HEAD_TEMPLATE = (
    r"(?<![\w.]){identifier}\b\s*"
    r"(?P<operator>:=|(?<![=!<>])=(?!=|>))"
)
FIELD_HEAD_TEMPLATE = r"(?<![\w.]){identifier}\b\s*(?P<operator>:)"


class GasInventoryError(RuntimeError):
    """Raised when the inventory or Solidity source cannot be validated."""


class CallUse(NamedTuple):
    path: str
    site: str
    kind: str
    operation: str
    expression: str


class LiteralDeclaration(NamedTuple):
    path: str
    identifier: str
    value: int


class LiteralAlias(NamedTuple):
    path: str
    identifier: str
    value: str
    line: int


class ImplicitStipendUse(NamedTuple):
    path: str
    site: str
    operation: str
    line: int


class NonCanonicalLiteralDeclaration(NamedTuple):
    path: str
    identifier: str
    expression: str
    line: int


class ScanResult(NamedTuple):
    calls: Counter[CallUse]
    declarations: Counter[LiteralDeclaration]
    call_lines: dict[CallUse, list[int]]
    declaration_lines: dict[LiteralDeclaration, list[int]]
    literal_aliases: list[LiteralAlias]
    implicit_stipends: list[ImplicitStipendUse]
    noncanonical_declarations: list[NonCanonicalLiteralDeclaration]


def require_dict(value: Any, location: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise GasInventoryError(f"{location} must be an object")
    return value


def require_list(value: Any, location: str) -> list[Any]:
    if not isinstance(value, list):
        raise GasInventoryError(f"{location} must be a list")
    return value


def require_string(value: Any, location: str) -> str:
    if not isinstance(value, str) or value == "":
        raise GasInventoryError(f"{location} must be a non-empty string")
    return value


def require_positive_int(value: Any, location: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise GasInventoryError(f"{location} must be a positive integer")
    return value


def require_exact_keys(
    value: dict[str, Any], expected: frozenset[str], location: str
) -> None:
    actual = set(value)
    if actual == expected:
        return
    missing = sorted(expected - actual)
    unexpected = sorted(actual - expected)
    details: list[str] = []
    if missing:
        details.append(f"missing {', '.join(missing)}")
    if unexpected:
        details.append(f"unexpected {', '.join(unexpected)}")
    raise GasInventoryError(f"{location} fields drifted: {'; '.join(details)}")


def ijson_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise GasInventoryError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def ijson_integer(raw: str) -> int:
    value = int(raw)
    if abs(value) > IJSON_MAX_SAFE_INTEGER:
        raise GasInventoryError(
            f"JSON integer is outside the I-JSON interoperable range: {raw}"
        )
    return value


def reject_ijson_float(raw: str) -> Any:
    raise GasInventoryError(f"floating-point JSON numbers are prohibited: {raw}")


def reject_ijson_constant(raw: str) -> Any:
    raise GasInventoryError(f"non-finite JSON number is prohibited: {raw}")


def validate_ijson_unicode(value: Any, location: str = "$") -> None:
    if isinstance(value, str):
        if any(0xD800 <= ord(character) <= 0xDFFF for character in value):
            raise GasInventoryError(
                f"{location} contains a Unicode surrogate and is not valid I-JSON"
            )
        return
    if isinstance(value, list):
        for index, item in enumerate(value):
            validate_ijson_unicode(item, f"{location}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            validate_ijson_unicode(key, f"{location}.<member>")
            validate_ijson_unicode(item, f"{location}.{key}")


def mask_comments_and_strings(source: str) -> str:
    """Replace comments and string contents with spaces while preserving offsets."""

    masked = list(source)
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""

        if state == "code":
            if current == "/" and following == "/":
                masked[index] = masked[index + 1] = " "
                state = "line-comment"
                index += 2
                continue
            if current == "/" and following == "*":
                masked[index] = masked[index + 1] = " "
                state = "block-comment"
                index += 2
                continue
            if current in {'"', "'"}:
                quote = current
                masked[index] = " "
                state = "string"
                index += 1
                continue
            index += 1
            continue

        if state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                masked[index] = " "
            index += 1
            continue

        if state == "block-comment":
            if current == "*" and following == "/":
                masked[index] = masked[index + 1] = " "
                state = "code"
                index += 2
            else:
                if current not in "\r\n":
                    masked[index] = " "
                index += 1
            continue

        if current == "\\":
            masked[index] = " "
            if index + 1 < len(source):
                if source[index + 1] not in "\r\n":
                    masked[index + 1] = " "
                index += 2
            else:
                index += 1
            continue
        masked[index] = " " if current not in "\r\n" else current
        if current == quote:
            state = "code"
        index += 1

    return "".join(masked)


def normalize_expression(expression: str) -> str:
    return re.sub(r"\s+", "", expression)


def expression_end(source: str, start: int) -> int:
    round_depth = 0
    square_depth = 0
    curly_depth = 0
    index = start
    while index < len(source):
        current = source[index]
        if current == "(":
            round_depth += 1
        elif current == ")":
            if round_depth == 0:
                return index
            round_depth -= 1
        elif current == "[":
            square_depth += 1
        elif current == "]":
            square_depth = max(0, square_depth - 1)
        elif current == "{":
            curly_depth += 1
        elif current == "}":
            if round_depth == 0 and square_depth == 0 and curly_depth == 0:
                return index
            curly_depth = max(0, curly_depth - 1)
        elif (
            current == ","
            and round_depth == 0
            and square_depth == 0
            and curly_depth == 0
        ):
            return index
        index += 1
    return index


def source_line(source: str, offset: int) -> int:
    return source.count("\n", 0, offset) + 1


def matching_closing_brace(source: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def inside_assembly_block(source: str, offset: int) -> bool:
    for match in ASSEMBLY_BLOCK_RE.finditer(source, 0, offset):
        opening = source.rfind("{", match.start(), match.end())
        closing = matching_closing_brace(source, opening)
        if closing is None or offset < closing:
            return True
    return False


def enclosing_callable(source: str, offset: int) -> str:
    callable_name = "<contract-scope>"
    for match in CALLABLE_RE.finditer(source, 0, offset):
        if inside_assembly_block(source, match.start()):
            continue
        callable_name = match.group("function") or match.group("special")
    return callable_name


def is_literal_gas_declaration(identifier: str) -> bool:
    upper = identifier.upper()
    return upper.endswith(
        (
            "_GAS",
            "_GAS_LIMIT",
            "_GAS_CAP",
            "_GAS_CEILING",
            "_GAS_RESERVE",
            "_GAS_MIN",
            "_MIN_GAS",
            "_GAS_BUDGET",
        )
    )


def parse_integer(raw: str) -> int:
    normalized = raw.replace("_", "")
    if normalized.lower().startswith("0x"):
        return int(normalized, 16)
    try:
        value = Decimal(normalized)
    except InvalidOperation as exc:
        raise GasInventoryError(f"invalid integer literal: {raw}") from exc
    integral = value.to_integral_value()
    if value != integral:
        raise GasInventoryError(f"gas literal must resolve to an integer: {raw}")
    return int(integral)


def matching_closing_parenthesis(expression: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(expression)):
        if expression[index] == "(":
            depth += 1
        elif expression[index] == ")":
            depth -= 1
            if depth == 0:
                return index
    return None


def wrapped_integer_literal(expression: str) -> int | None:
    """Return a literal's value through parentheses/integer casts only."""

    remaining = normalize_expression(expression)
    integer_cast = re.compile(
        r"^(?:uint|int)(?:8|16|24|32|40|48|56|64|72|80|88|96|104|112|120|128|"
        r"136|144|152|160|168|176|184|192|200|208|216|224|232|240|248|256)?\("
    )
    while remaining:
        literal = NUMERIC_LITERAL_RE.fullmatch(remaining)
        if literal is not None:
            return parse_integer(literal.group("value"))

        opening = 0
        cast = integer_cast.match(remaining)
        if cast is not None:
            opening = cast.end() - 1
        elif not remaining.startswith("("):
            return None

        closing = matching_closing_parenthesis(remaining, opening)
        if closing != len(remaining) - 1:
            return None
        remaining = remaining[opening + 1 : closing]
    return None


def enclosing_scope_end(source: str, offset: int) -> int:
    """Return the closing brace of the block containing a declaration."""

    depth = source.count("{", 0, offset) - source.count("}", 0, offset)
    if depth <= 0:
        return len(source)
    initial_depth = depth
    for index in range(offset, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth < initial_depth:
                return index
    return len(source)


def assignment_rhs_end(source: str, start: int, operator: str) -> int:
    index = start
    while index < len(source) and source[index].isspace():
        index += 1

    round_depth = 0
    square_depth = 0
    curly_depth = 0
    while index < len(source):
        current = source[index]
        if current == "(":
            round_depth += 1
        elif current == ")":
            round_depth = max(0, round_depth - 1)
        elif current == "[":
            square_depth += 1
        elif current == "]":
            square_depth = max(0, square_depth - 1)
        elif current == "{":
            curly_depth += 1
        elif current == "}":
            if round_depth == 0 and square_depth == 0 and curly_depth == 0:
                return index
            curly_depth = max(0, curly_depth - 1)
        elif (
            current in {";", ","}
            and round_depth == 0
            and square_depth == 0
            and curly_depth == 0
        ):
            return index
        elif (
            operator == ":="
            and current in "\r\n"
            and round_depth == 0
            and square_depth == 0
            and curly_depth == 0
        ):
            return index
        index += 1
    return index


def numeric_assignments(
    source: str,
    identifier: str,
    *,
    start: int = 0,
    end: int | None = None,
    field: bool = False,
) -> list[tuple[int, str]]:
    findings: list[tuple[int, str]] = []
    for offset, expression in assignment_expressions(
        source,
        identifier,
        start=start,
        end=end,
        field=field,
    ):
        for literal in NUMERIC_LITERAL_RE.finditer(expression):
            findings.append((offset, literal.group("value")))
    return findings


def assignment_expressions(
    source: str,
    identifier: str,
    *,
    start: int = 0,
    end: int | None = None,
    field: bool = False,
) -> list[tuple[int, str]]:
    template = FIELD_HEAD_TEMPLATE if field else ASSIGNMENT_HEAD_TEMPLATE
    assignment_re = re.compile(template.format(identifier=re.escape(identifier)))
    limit = len(source) if end is None else end
    assignments: list[tuple[int, str]] = []
    for match in assignment_re.finditer(source, start, limit):
        rhs_end = min(
            assignment_rhs_end(source, match.end(), match.group("operator")),
            limit,
        )
        assignments.append((match.start(), source[match.end() : rhs_end]))
    return assignments


def scan_source(path: str, source: str) -> ScanResult:
    masked = mask_comments_and_strings(source)
    calls: Counter[CallUse] = Counter()
    declarations: Counter[LiteralDeclaration] = Counter()
    call_lines: dict[CallUse, list[int]] = defaultdict(list)
    declaration_lines: dict[LiteralDeclaration, list[int]] = defaultdict(list)
    implicit_stipends: list[ImplicitStipendUse] = []
    noncanonical_declarations: set[NonCanonicalLiteralDeclaration] = set()

    for match in CALL_OPTION_GAS_RE.finditer(masked):
        start = match.end()
        end = expression_end(masked, start)
        expression = normalize_expression(masked[start:end])
        use = CallUse(
            path,
            enclosing_callable(masked, match.start()),
            "call-option",
            "external-call",
            expression,
        )
        calls[use] += 1
        call_lines[use].append(source_line(masked, match.start()))

    for match in YUL_CALL_RE.finditer(masked):
        start = match.end()
        end = expression_end(masked, start)
        expression = normalize_expression(masked[start:end])
        if expression == YUL_AVAILABLE_GAS_EXPRESSION:
            continue
        use = CallUse(
            path,
            enclosing_callable(masked, match.start()),
            "yul-call",
            match.group("operation"),
            expression,
        )
        calls[use] += 1
        call_lines[use].append(source_line(masked, match.start()))

    for match in IMPLICIT_STIPEND_RE.finditer(masked):
        implicit_stipends.append(
            ImplicitStipendUse(
                path,
                enclosing_callable(masked, match.start()),
                match.group("operation"),
                source_line(masked, match.start()),
            )
        )

    for match in INITIALIZED_INTEGER_DECL_RE.finditer(masked):
        modifiers = match.group("modifiers").split()
        identifier = match.group("identifier")
        if not {"constant", "immutable"}.intersection(modifiers):
            continue
        if not is_literal_gas_declaration(identifier):
            continue
        rhs_end = assignment_rhs_end(masked, match.end(), "=")
        expression = masked[match.end() : rhs_end]
        if NUMERIC_LITERAL_RE.search(expression) is None:
            continue
        value = wrapped_integer_literal(expression)
        if value is None:
            noncanonical_declarations.add(
                NonCanonicalLiteralDeclaration(
                    path,
                    identifier,
                    normalize_expression(expression),
                    source_line(masked, match.start()),
                )
            )
            continue
        declaration = LiteralDeclaration(path, identifier, value)
        declarations[declaration] += 1
        declaration_lines[declaration].append(
            source_line(masked, match.start())
        )

    for match in UNINITIALIZED_IMMUTABLE_RE.finditer(masked):
        modifiers = match.group("modifiers").split()
        identifier = match.group("identifier")
        if "immutable" not in modifiers or not is_literal_gas_declaration(identifier):
            continue
        scope_end = enclosing_scope_end(masked, match.start())
        for offset, expression in assignment_expressions(
            masked, identifier, start=match.end(), end=scope_end
        ):
            if NUMERIC_LITERAL_RE.search(expression) is None:
                continue
            value = wrapped_integer_literal(expression)
            if value is None:
                noncanonical_declarations.add(
                    NonCanonicalLiteralDeclaration(
                        path,
                        identifier,
                        normalize_expression(expression),
                        source_line(masked, offset),
                    )
                )
                continue
            declaration = LiteralDeclaration(path, identifier, value)
            declarations[declaration] += 1
            declaration_lines[declaration].append(
                source_line(masked, offset)
            )

    literal_aliases: set[LiteralAlias] = set()
    alias_expressions = {
        use.expression
        for use in calls
        if re.fullmatch(
            r"[_A-Za-z][_A-Za-z0-9]*(?:\.[_A-Za-z][_A-Za-z0-9]*)*",
            use.expression,
        )
        and not use.expression.isupper()
    }
    alias_identifiers: set[str] = set(alias_expressions)
    for expression in alias_expressions:
        if "." in expression:
            alias_identifiers.add(expression.split(".", 1)[0])
            alias_identifiers.add(expression.rsplit(".", 1)[1])

    for identifier in sorted(alias_identifiers):
        for offset, literal in numeric_assignments(masked, identifier):
            literal_aliases.add(
                LiteralAlias(
                    path,
                    identifier,
                    literal,
                    source_line(masked, offset),
                )
            )
        for offset, literal in numeric_assignments(masked, identifier, field=True):
            literal_aliases.add(
                LiteralAlias(
                    path,
                    f"{identifier}:",
                    literal,
                    source_line(masked, offset),
                )
            )

    return ScanResult(
        calls,
        declarations,
        dict(call_lines),
        dict(declaration_lines),
        sorted(literal_aliases),
        sorted(implicit_stipends),
        sorted(noncanonical_declarations),
    )


def scan_tree(repo_root: Path) -> ScanResult:
    source_root = repo_root / SOLIDITY_ROOT
    if not source_root.is_dir():
        raise GasInventoryError(f"missing Solidity root: {SOLIDITY_ROOT}")

    calls: Counter[CallUse] = Counter()
    declarations: Counter[LiteralDeclaration] = Counter()
    call_lines: dict[CallUse, list[int]] = defaultdict(list)
    declaration_lines: dict[LiteralDeclaration, list[int]] = defaultdict(list)
    aliases: list[LiteralAlias] = []
    implicit_stipends: list[ImplicitStipendUse] = []
    noncanonical_declarations: list[NonCanonicalLiteralDeclaration] = []

    for source_path in sorted(source_root.rglob("*.sol")):
        relative = source_path.relative_to(repo_root).as_posix()
        result = scan_source(relative, source_path.read_text(encoding="utf-8"))
        calls.update(result.calls)
        declarations.update(result.declarations)
        for use, lines in result.call_lines.items():
            call_lines[use].extend(lines)
        for declaration, lines in result.declaration_lines.items():
            declaration_lines[declaration].extend(lines)
        aliases.extend(result.literal_aliases)
        implicit_stipends.extend(result.implicit_stipends)
        noncanonical_declarations.extend(result.noncanonical_declarations)

    return ScanResult(
        calls,
        declarations,
        dict(call_lines),
        dict(declaration_lines),
        sorted(aliases),
        sorted(implicit_stipends),
        sorted(noncanonical_declarations),
    )


def load_inventory(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            inventory = require_dict(
                json.load(
                    handle,
                    object_pairs_hook=ijson_object,
                    parse_int=ijson_integer,
                    parse_float=reject_ijson_float,
                    parse_constant=reject_ijson_constant,
                ),
                str(path),
            )
    except FileNotFoundError as exc:
        raise GasInventoryError(f"missing inventory: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GasInventoryError(f"invalid JSON in {path}: {exc}") from exc
    except UnicodeDecodeError as exc:
        raise GasInventoryError(f"inventory is not valid UTF-8: {path}") from exc

    validate_ijson_unicode(inventory)
    require_exact_keys(inventory, TOP_LEVEL_FIELDS, "inventory")
    if inventory.get("schema_version") != SCHEMA_VERSION:
        raise GasInventoryError(f"schema_version must be {SCHEMA_VERSION}")
    if inventory.get("tracking_issue") != TRACKING_ISSUE:
        raise GasInventoryError(f"tracking_issue must be {TRACKING_ISSUE}")
    if inventory.get("status") != "open-remediation-inventory":
        raise GasInventoryError("status must be open-remediation-inventory")
    note = require_string(inventory.get("note"), "note")
    if note != INVENTORY_NOTE:
        raise GasInventoryError(
            "note must retain the canonical no-accepted-risk inventory boundary"
        )
    return inventory


def expected_calls(inventory: dict[str, Any]) -> Counter[CallUse]:
    expected: Counter[CallUse] = Counter()
    group = "open_call_gas_expressions"
    for index, raw in enumerate(require_list(inventory.get(group), group)):
        location = f"{group}[{index}]"
        row = require_dict(raw, location)
        require_exact_keys(row, OPEN_CALL_FIELDS, location)
        use = CallUse(
            require_string(row.get("path"), f"{location}.path"),
            require_string(row.get("site"), f"{location}.site"),
            require_string(row.get("kind"), f"{location}.kind"),
            require_string(row.get("operation"), f"{location}.operation"),
            require_string(row.get("expression"), f"{location}.expression"),
        )
        count = require_positive_int(
            row.get("expected_count"), f"{location}.expected_count"
        )
        if use in expected:
            raise GasInventoryError(f"duplicate call inventory row: {use}")
        expected[use] = count
        path_class = require_string(
            row.get("path_class"), f"{location}.path_class"
        )
        if path_class not in PATH_CLASSES:
            raise GasInventoryError(
                f"{location}.path_class must be one of "
                f"{', '.join(sorted(PATH_CLASSES))}"
            )
        lane = require_string(row.get("lane"), f"{location}.lane")
        if lane not in OPEN_LANES:
            raise GasInventoryError(
                f"{location}.lane must be one of {', '.join(sorted(OPEN_LANES))}"
            )
        if row.get("issue") != "#669":
            raise GasInventoryError(f"{location}.issue must be #669")
        if row.get("disposition") != "open-remediation-required":
            raise GasInventoryError(
                f"{location}.disposition must be open-remediation-required"
            )

    probe_group = "explicit_probe_call_gas_expressions"
    probe_rows = require_list(inventory.get(probe_group), probe_group)
    if probe_rows:
        raise GasInventoryError(
            f"{probe_group} is reserved by schema v1 and must remain empty"
        )
    return expected


def expected_declarations(
    inventory: dict[str, Any],
) -> Counter[LiteralDeclaration]:
    group = "open_literal_gas_declarations"
    expected: Counter[LiteralDeclaration] = Counter()
    for index, raw in enumerate(require_list(inventory.get(group), group)):
        location = f"{group}[{index}]"
        row = require_dict(raw, location)
        require_exact_keys(row, LITERAL_DECLARATION_FIELDS, location)
        declaration = LiteralDeclaration(
            require_string(row.get("path"), f"{location}.path"),
            require_string(row.get("identifier"), f"{location}.identifier"),
            require_positive_int(row.get("value"), f"{location}.value"),
        )
        count = require_positive_int(
            row.get("expected_count"), f"{location}.expected_count"
        )
        if declaration in expected:
            raise GasInventoryError(f"duplicate literal declaration row: {declaration}")
        expected[declaration] = count
        path_class = require_string(
            row.get("path_class"), f"{location}.path_class"
        )
        if path_class not in PATH_CLASSES:
            raise GasInventoryError(
                f"{location}.path_class must be one of "
                f"{', '.join(sorted(PATH_CLASSES))}"
            )
        lane = require_string(row.get("lane"), f"{location}.lane")
        if lane not in OPEN_LANES:
            raise GasInventoryError(
                f"{location}.lane must be one of {', '.join(sorted(OPEN_LANES))}"
            )
        if row.get("issue") != "#669":
            raise GasInventoryError(f"{location}.issue must be #669")
        if row.get("disposition") != "open-remediation-required":
            raise GasInventoryError(
                f"{location}.disposition must be open-remediation-required"
            )
    return expected


def describe_counter_drift(
    label: str,
    actual: Counter[Any],
    expected: Counter[Any],
    lines: dict[Any, list[int]],
) -> list[str]:
    errors: list[str] = []
    for item, count in sorted((actual - expected).items()):
        locations = ",".join(str(line) for line in lines.get(item, []))
        errors.append(
            f"unexpected {label}: {item} x{count}"
            + (f" (source lines {locations})" if locations else "")
        )
    for item, count in sorted((expected - actual).items()):
        errors.append(f"missing inventoried {label}: {item} x{count}")
    return errors


def check_repository(repo_root: Path, inventory_path: Path) -> None:
    inventory_abs = (
        inventory_path if inventory_path.is_absolute() else repo_root / inventory_path
    )
    inventory = load_inventory(inventory_abs)
    result = scan_tree(repo_root)
    expected_call_inventory = expected_calls(inventory)
    expected_literal_inventory = expected_declarations(inventory)

    errors = describe_counter_drift(
        "call-gas expression",
        result.calls,
        expected_call_inventory,
        result.call_lines,
    )
    errors.extend(
        describe_counter_drift(
            "literal gas declaration",
            result.declarations,
            expected_literal_inventory,
            result.declaration_lines,
        )
    )
    errors.extend(
        f"literal assignment aliases call-gas expression: "
        f"{alias.path}:{alias.line} {alias.identifier}={alias.value}"
        for alias in result.literal_aliases
    )
    errors.extend(
        "implicit fixed-gas stipend is prohibited: "
        f"{use.path}:{use.line} {use.site} .{use.operation}(...)"
        for use in result.implicit_stipends
    )
    errors.extend(
        "non-canonical literal gas declaration cannot be inventoried exactly: "
        f"{declaration.path}:{declaration.line} "
        f"{declaration.identifier}={declaration.expression}"
        for declaration in result.noncanonical_declarations
    )
    if errors:
        raise GasInventoryError("\n".join(errors))

    open_call_count = sum(
        require_positive_int(row["expected_count"], "expected_count")
        for row in inventory["open_call_gas_expressions"]
    )
    open_declaration_count = sum(
        require_positive_int(row["expected_count"], "expected_count")
        for row in inventory["open_literal_gas_declarations"]
    )
    print(
        "External-call gas inventory passed: "
        f"{open_call_count} open call sites and "
        f"{open_declaration_count} open literal declarations remain tracked by #669."
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        check_repository(args.repo_root.resolve(), args.inventory)
    except GasInventoryError as exc:
        print(f"External-call gas inventory failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
