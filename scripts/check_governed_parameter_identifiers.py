#!/usr/bin/env python3
"""Check the closed-world launch GGP/GTP identifier catalog and derivation."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Final


TARGET_ARCHITECTURE: Final = Path("docs/launch-v1-target-architecture.md")
LONG_TERM_ARCHITECTURE: Final = Path("docs/stream-long-term-architecture.md")
GAS_HOST: Final = Path("smart-contracts/StreamGasParameterHost.sol")
TIME_HOST: Final = Path("smart-contracts/StreamTimeParameterHost.sol")

GGP_NAMES: Final = (
    "ROYALTY_RESOLVER_GAS_LIMIT",
    "ROYALTY_RETURN_GAS_BUFFER",
    "ERC_1271_GAS_LIMIT",
    "ASSET_POLICY_GAS_LIMIT",
    "WALLET_DEPOSIT_GAS_LIMIT",
    "FLUSH_GAS_FLOOR",
    "MINT_GATE_GAS_LIMIT",
    "TICKET_ERC1271_GAS_LIMIT",
    "ARTIST_AUTHORITY_GAS_LIMIT",
    "SALE_ERC1271_GAS_LIMIT",
    "DELEGATE_REGISTRY_GAS_LIMIT",
    "SALE_ARTIST_AUTHORITY_GAS_LIMIT",
    "REVEAL_ATTEMPT_GAS_LIMIT",
    "SALE_NFT_DELIVERY_GAS_LIMIT",
    "METADATA_ROUTER_GAS_LIMIT",
    "ENTROPY_VIEW_GAS_LIMIT",
    "ENTROPY_REGISTRATION_GAS_LIMIT",
    "ENTROPY_RESULT_PROBE_GAS_LIMIT",
    "VRF_CALLBACK_GAS_LIMIT",
    "ARTIST_ERC1271_VERIFY_GAS",
    "METADATA_ERC1271_VERIFY_GAS",
    "FINALITY_COMPONENT_READ_GAS",
)

GTP_NAMES: Final = (
    "ENTROPY_REQUEST_TIMEOUT_BLOCKS",
    "ENTROPY_REVEAL_SLO_BLOCKS",
    "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS",
)

TARGET_SECTION_START: Final = "### Governed Gas Parameter Identifier Mirror Rows"
TARGET_TABLE_HEADER: Final = (
    "| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |"
)
TARGET_TABLE_SEPARATOR: Final = "| --- | --- | --- | --- | --- | --- |"
TARGET_TABLE_END: Final = "### Pinned-Name Glossary"
GGP_INVENTORY_START: Final = "GGP inventory."
GGP_INVENTORY_END: Final = "A future guarded path that is not in this inventory"
GGP_TABLE_HEADER: Final = "| Parameter | Host | Normative home |"
GGP_TABLE_SEPARATOR: Final = "| --- | --- | --- |"
GTP_INVENTORY_START: Final = "The GTP inventory is owned by the subsystem homes"
GTP_INVENTORY_END: Final = "GTP membership is closed-world and decidable"
GTP_TABLE_HEADER: Final = "| Time parameter | Host | Normative home |"
GTP_TABLE_SEPARATOR: Final = "| --- | --- | --- |"
GTP_INVENTORY_PREFIX: Final = (
    ". The genesis members are the coordinator-hosted entropy lifecycle windows "
    "below, overlaying the collection timing policies (`requestTimeoutBlocks`, "
    "`requestSLOBlocks`, `notBeforeBlocks`) and instantiated with their "
    "effective-window semantics by [EC-TIME]:"
)

TARGET_CONSTANT = re.compile(r"(?:GGP|GTP)_[A-Z0-9_]+")
PINNED_HASH = re.compile(r"0x[0-9a-f]{64}")

TARGET_ROW_METADATA: Final = (
    (
        "GGP_ROYALTY_RESOLVER_GAS_LIMIT",
        "StreamCore",
        "GGP key; revenue spec `[RSR-GGP]`, `[RSR-2981-GAS]`",
    ),
    ("GGP_ROYALTY_RETURN_GAS_BUFFER", "StreamCore", "GGP key; revenue spec `[RSR-GGP]`"),
    (
        "GGP_ERC_1271_GAS_LIMIT",
        "split factory parameter store",
        "GGP key; revenue spec `[RSR-GGP]`, `[RSR-1271]`",
    ),
    (
        "GGP_ASSET_POLICY_GAS_LIMIT",
        "split factory parameter store",
        "GGP key; revenue spec `[RSR-GGP]`, `[RSR-ASSET-POLICY]`",
    ),
    (
        "GGP_WALLET_DEPOSIT_GAS_LIMIT",
        "split factory parameter store",
        "GGP key; revenue spec `[RSR-GGP]`",
    ),
    ("GGP_FLUSH_GAS_FLOOR", "revenue escrow", "GGP key; revenue spec `[RSR-GGP]`"),
    ("GGP_MINT_GATE_GAS_LIMIT", "StreamMintManager", "GGP key; mint spec `[MPA-GATES]`"),
    (
        "GGP_TICKET_ERC1271_GAS_LIMIT",
        "StreamMintTicketGate",
        "GGP key; mint spec `[MPA-TICKET]`",
    ),
    (
        "GGP_ARTIST_AUTHORITY_GAS_LIMIT",
        "StreamMintManager",
        "GGP key; mint spec `[MPA-CONSENT]`",
    ),
    ("GGP_SALE_ERC1271_GAS_LIMIT", "sale adapters", "GGP key; sales spec `[SSA-GAS]`"),
    (
        "GGP_DELEGATE_REGISTRY_GAS_LIMIT",
        "delegate gate",
        "GGP key; sales spec `[SSA-GAS]`",
    ),
    (
        "GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT",
        "sale adapters",
        "GGP key; sales spec `[SSA-GAS]`, `[SSA-CONTEST-STOP]` (ADR 0012 decision T4)",
    ),
    (
        "GGP_REVEAL_ATTEMPT_GAS_LIMIT",
        "sale adapters",
        "GGP key; sales spec `[SSA-REVEAL]`, coordinator spec `AT_MINT` attempt bound (ADR 0013 decision U7)",
    ),
    (
        "GGP_SALE_NFT_DELIVERY_GAS_LIMIT",
        "sale adapters",
        "GGP key; sales spec `[SSA-GAS]` (ADR 0013 decision U6)",
    ),
    (
        "GGP_METADATA_ROUTER_GAS_LIMIT",
        "StreamCore",
        "GGP key; metadata spec `[MRR-ROUTER-GGP]`",
    ),
    (
        "GGP_ENTROPY_VIEW_GAS_LIMIT",
        "metadata router",
        "GGP key; metadata spec `[MRR-ENTROPY-READ]`",
    ),
    (
        "GGP_ENTROPY_REGISTRATION_GAS_LIMIT",
        "StreamCore",
        "GGP key; coordinator spec `[EC-REGGAS]`",
    ),
    (
        "GGP_ENTROPY_RESULT_PROBE_GAS_LIMIT",
        "StreamEntropyCoordinator",
        "GGP key; coordinator spec `[EC-INCIDENT-ROLE]`",
    ),
    (
        "GGP_VRF_CALLBACK_GAS_LIMIT",
        "provider adapters",
        "GGP key; providers spec `[EP-VRF-CONFIG]`",
    ),
    (
        "GGP_ARTIST_ERC1271_VERIFY_GAS",
        "StreamArtistRegistry",
        "GGP key; artist spec `[AA-SIGVER]`",
    ),
    (
        "GGP_METADATA_ERC1271_VERIFY_GAS",
        "verifying metadata satellites",
        "GGP key; CM spec `[CMC-SIGVER-GGP]` (ADR 0011 decision R10; `_ID` suffix retired, ADR 0013 decision U9)",
    ),
    (
        "GGP_FINALITY_COMPONENT_READ_GAS",
        "finality registry",
        "GGP key; umbrella `[LTA-GGP]` (Artwork Finality Freeze; `_ID` suffix retired, ADR 0013 decision U9)",
    ),
    (
        "GTP_ENTROPY_REQUEST_TIMEOUT_BLOCKS",
        "StreamEntropyCoordinator",
        "GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]`",
    ),
    (
        "GTP_ENTROPY_REVEAL_SLO_BLOCKS",
        "StreamEntropyCoordinator",
        "GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]`",
    ),
    (
        "GTP_ENTROPY_RECOVERY_STEP_DELAY_BLOCKS",
        "StreamEntropyCoordinator",
        "GTP key ([LTA-GTP]; ADR 0012 decision T1); coordinator spec `[EC-TIME]`",
    ),
)

LTA_GGP_ROWS: Final = (
    ("ROYALTY_RESOLVER_GAS_LIMIT", "StreamCore", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP], [RSR-2981-GAS]"),
    ("ROYALTY_RETURN_GAS_BUFFER", "StreamCore", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP]"),
    ("ERC_1271_GAS_LIMIT", "split factory parameter store", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-1271]"),
    ("ASSET_POLICY_GAS_LIMIT", "split factory parameter store", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP], [RSR-ASSET-POLICY]"),
    ("WALLET_DEPOSIT_GAS_LIMIT", "split factory parameter store", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP]"),
    ("FLUSH_GAS_FLOOR", "revenue escrow", "[`docs/revenue-splits-and-royalties.md`](revenue-splits-and-royalties.md) [RSR-GGP]"),
    ("MINT_GATE_GAS_LIMIT", "mint manager", "[`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-GATES]"),
    ("TICKET_ERC1271_GAS_LIMIT", "StreamMintTicketGate", "[`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-TICKET]"),
    ("ARTIST_AUTHORITY_GAS_LIMIT", "mint manager", "[`docs/mint-policy-and-accounting.md`](mint-policy-and-accounting.md) [MPA-CONSENT]"),
    ("SALE_ERC1271_GAS_LIMIT", "sale adapters", "[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS]"),
    ("DELEGATE_REGISTRY_GAS_LIMIT", "delegate gate", "[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS]"),
    ("SALE_ARTIST_AUTHORITY_GAS_LIMIT", "sale adapters", "[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS], [SSA-CONTEST-STOP]"),
    ("REVEAL_ATTEMPT_GAS_LIMIT", "sale adapters", "[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-REVEAL], [SSA-GAS] (ADR 0013 decision U7)"),
    ("SALE_NFT_DELIVERY_GAS_LIMIT", "sale adapters", "[`docs/stream-sales-and-auctions.md`](stream-sales-and-auctions.md) [SSA-GAS] (ADR 0013 decision U6)"),
    ("METADATA_ROUTER_GAS_LIMIT", "StreamCore", "[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) [MRR-ROUTER-GGP]"),
    ("ENTROPY_VIEW_GAS_LIMIT", "metadata router", "[`docs/metadata-router-and-renderer.md`](metadata-router-and-renderer.md) [MRR-ENTROPY-READ]"),
    ("ENTROPY_REGISTRATION_GAS_LIMIT", "StreamCore", "[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) [EC-REGGAS]"),
    ("ENTROPY_RESULT_PROBE_GAS_LIMIT", "entropy coordinator", "[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) [EC-INCIDENT-ROLE]"),
    ("VRF_CALLBACK_GAS_LIMIT", "provider adapters", "[`docs/stream-entropy-providers.md`](stream-entropy-providers.md) [EP-VRF-CONFIG]"),
    ("ARTIST_ERC1271_VERIFY_GAS", "artist registry", "[`docs/stream-artist-authority.md`](stream-artist-authority.md) [AA-SIGVER]"),
    ("METADATA_ERC1271_VERIFY_GAS", "verifying metadata satellites (owner records, attestations, artist-attestation host)", "[`docs/collection-metadata-contract.md`](collection-metadata-contract.md) [CMC-SIGVER-GGP]"),
    ("FINALITY_COMPONENT_READ_GAS", "finality registry", "this document (Artwork Finality Freeze)"),
)

LTA_GTP_ROWS: Final = tuple(
    (
        name,
        "StreamEntropyCoordinator",
        "[`docs/stream-entropy-coordinator.md`](stream-entropy-coordinator.md) [EC-TIME]",
    )
    for name in GTP_NAMES
)


class GovernedParameterIdentifierError(RuntimeError):
    """Raised when a governed-parameter identifier surface drifts."""


def _read(root: Path, relative: Path) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise GovernedParameterIdentifierError(f"cannot read {relative}: {exc}") from exc


def _blank_markdown(value: str) -> str:
    return "".join(character if character in "\r\n" else " " for character in value)


def _mask_nonrendered_markdown(text: str) -> str:
    """Mask comments, fences, and raw HTML blocks while preserving line boundaries."""
    result: list[str] = []
    in_html_comment = False
    fence_character = ""
    fence_length = 0
    raw_html_end: re.Pattern[str] | None = None
    raw_html_until_blank = False

    for line in text.splitlines(keepends=True):
        content = line.rstrip("\r\n")
        if raw_html_until_blank:
            if content.strip():
                result.append(_blank_markdown(line))
            else:
                raw_html_until_blank = False
                result.append(line)
            continue

        if raw_html_end is not None:
            result.append(_blank_markdown(line))
            if raw_html_end.search(content):
                raw_html_end = None
            continue

        if fence_character:
            result.append(_blank_markdown(line))
            closing_fence = re.fullmatch(
                rf" {{0,3}}{re.escape(fence_character)}{{{fence_length},}}[ \t]*",
                content,
            )
            if closing_fence is not None:
                fence_character = ""
                fence_length = 0
            continue

        if not in_html_comment:
            opening_raw_html = re.match(
                r"^ {0,3}<(?P<tag>pre|script|style|textarea)(?=[\s>])",
                content,
                flags=re.IGNORECASE,
            )
            if opening_raw_html is not None:
                tag = opening_raw_html.group("tag").lower()
                result.append(_blank_markdown(line))
                closing = re.compile(
                    rf"</\s*{re.escape(tag)}\s*>",
                    flags=re.IGNORECASE,
                )
                if closing.search(content[opening_raw_html.end() :]) is None:
                    raw_html_end = closing
                continue

            raw_html_delimiters = (
                (r"^ {0,3}<\?", r"\?>"),
                (r"^ {0,3}<!\[CDATA\[", r"\]\]>"),
                (r"^ {0,3}<![A-Za-z]", r">"),
            )
            for opening_pattern, closing_pattern in raw_html_delimiters:
                opening = re.match(opening_pattern, content)
                if opening is None:
                    continue
                result.append(_blank_markdown(line))
                closing = re.compile(closing_pattern)
                if closing.search(content[opening.end() :]) is None:
                    raw_html_end = closing
                break
            else:
                opening_html_tag = re.match(
                    r"^ {0,3}</?[A-Za-z][A-Za-z0-9-]*"
                    r"(?:\s+[^<>]*)?/?>[ \t]*$",
                    content,
                )
                block_html_tag = re.match(
                    r"^ {0,3}</?(?:address|article|aside|base|basefont|blockquote|"
                    r"body|caption|center|col|colgroup|dd|details|dialog|dir|div|"
                    r"dl|dt|fieldset|figcaption|figure|footer|form|frame|frameset|"
                    r"h[1-6]|head|header|hr|html|iframe|legend|li|link|main|menu|"
                    r"menuitem|nav|noframes|ol|optgroup|option|p|param|search|"
                    r"section|summary|table|tbody|td|tfoot|th|thead|title|tr|track|ul)"
                    r"(?=[\s>/]|$)",
                    content,
                    flags=re.IGNORECASE,
                )
                if opening_html_tag is not None or block_html_tag is not None:
                    raw_html_until_blank = True
                    result.append(_blank_markdown(line))
                    continue

            if raw_html_end is not None or any(
                re.match(opening_pattern, content)
                for opening_pattern, _ in raw_html_delimiters
            ):
                continue

            opening_fence = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", content)
            if opening_fence is not None:
                delimiter = opening_fence.group(1)
                info = opening_fence.group(2)
                if delimiter[0] != "`" or "`" not in info:
                    fence_character = delimiter[0]
                    fence_length = len(delimiter)
                    result.append(_blank_markdown(line))
                    continue

        masked = list(line)
        index = 0
        while index < len(line):
            if in_html_comment:
                end = line.find("-->", index)
                stop = len(line) if end < 0 else end + 3
                for position in range(index, stop):
                    if masked[position] not in "\r\n":
                        masked[position] = " "
                if end < 0:
                    index = len(line)
                else:
                    in_html_comment = False
                    index = stop
                continue

            start = line.find("<!--", index)
            if start < 0:
                break
            end = line.find("-->", start + 4)
            stop = len(line) if end < 0 else end + 3
            for position in range(start, stop):
                if masked[position] not in "\r\n":
                    masked[position] = " "
            if end < 0:
                in_html_comment = True
                index = len(line)
            else:
                index = stop
        result.append("".join(masked))

    return "".join(result)


def _bounded(text: str, start: str, end: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise GovernedParameterIdentifierError(f"missing {label} start marker: {start!r}")
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        raise GovernedParameterIdentifierError(f"missing {label} end marker: {end!r}")
    return text[start_index + len(start) : end_index]


def _bounded_headings(text: str, start: str, end: str, label: str) -> str:
    start_matches = list(re.finditer(rf"(?m)^{re.escape(start)}\s*$", text))
    end_matches = list(re.finditer(rf"(?m)^{re.escape(end)}\s*$", text))
    if len(start_matches) != 1:
        raise GovernedParameterIdentifierError(
            f"{label} must contain exactly one full-line start heading"
        )
    eligible_ends = [match for match in end_matches if match.start() > start_matches[0].end()]
    if len(eligible_ends) != 1:
        raise GovernedParameterIdentifierError(
            f"{label} must contain exactly one later full-line end heading"
        )
    return text[start_matches[0].end() : eligible_ends[0].start()]


def _keccak256(value: bytes) -> bytes:
    try:
        from eth_hash.auto import keccak

        return keccak(value)
    except ImportError:
        try:
            from Crypto.Hash import keccak as crypto_keccak
        except ImportError as exc:
            raise GovernedParameterIdentifierError(
                "Ethereum Keccak support requires eth-hash or pycryptodome"
            ) from exc
        digest = crypto_keccak.new(digest_bits=256)
        digest.update(value)
        return digest.digest()


def _expected_constants() -> tuple[str, ...]:
    return tuple(f"GGP_{name}" for name in GGP_NAMES) + tuple(
        f"GTP_{name}" for name in GTP_NAMES
    )


def _normalize_markdown_cell(cell: str) -> str:
    value = cell.strip()
    if value.startswith("`") and value.endswith("`") and value.count("`") == 2:
        return value[1:-1]
    return value


def _is_indented_markdown_code(line: str) -> bool:
    leading = line[: len(line) - len(line.lstrip(" \t"))]
    return "\t" in leading or len(leading) >= 4


def _parse_markdown_table(
    section: str,
    header: str,
    separator: str,
    column_count: int,
    label: str,
) -> tuple[tuple[str, ...], ...]:
    section_lines = section.splitlines()
    header_indices = [
        index for index, line in enumerate(section_lines) if line.strip() == header
    ]
    if len(header_indices) != 1:
        raise GovernedParameterIdentifierError(
            f"{label} must contain exactly one canonical header"
        )
    if _is_indented_markdown_code(section_lines[header_indices[0]]):
        raise GovernedParameterIdentifierError(
            f"{label} canonical header must be a rendered table, not indented code"
        )
    for line in section_lines[: header_indices[0]]:
        if line.strip().startswith("|"):
            raise GovernedParameterIdentifierError(
                f"{label} contains a table row before its canonical header"
            )
    raw_lines = [
        line for line in section_lines[header_indices[0] + 1 :] if line.strip()
    ]
    if any(_is_indented_markdown_code(line) for line in raw_lines):
        raise GovernedParameterIdentifierError(
            f"{label} must be rendered as a table, not indented code"
        )
    lines = [line.strip() for line in raw_lines]
    if not lines or lines[0] != separator:
        raise GovernedParameterIdentifierError(
            f"{label} must begin with the canonical separator row"
        )

    rows: list[tuple[str, ...]] = []
    for line in lines[1:]:
        if not line.startswith("|") or not line.endswith("|"):
            raise GovernedParameterIdentifierError(
                f"{label} contains non-table content before its end marker"
            )
        parts = line.split("|")
        if len(parts) != column_count + 2 or parts[0] or parts[-1]:
            raise GovernedParameterIdentifierError(
                f"{label} contains a malformed or extra-column row: {line!r}"
            )
        rows.append(tuple(_normalize_markdown_cell(cell) for cell in parts[1:-1]))
    return tuple(rows)


def _expected_target_rows() -> tuple[tuple[str, ...], ...]:
    rows: list[tuple[str, ...]] = []
    for constant_name, owner, inputs in TARGET_ROW_METADATA:
        preimage = f"6529STREAM_{constant_name}"
        pinned_hash = "0x" + _keccak256(preimage.encode("ascii")).hex()
        rows.append((constant_name, preimage, pinned_hash, owner, "1", inputs))
    return tuple(rows)


def _validate_target_table(text: str) -> None:
    text = _mask_nonrendered_markdown(text)
    section = _bounded_headings(
        text, TARGET_SECTION_START, TARGET_TABLE_END, "identifier mirror section"
    )
    rows = _parse_markdown_table(
        section,
        TARGET_TABLE_HEADER,
        TARGET_TABLE_SEPARATOR,
        6,
        "identifier mirror table",
    )
    expected_rows = _expected_target_rows()
    if rows != expected_rows:
        for index, (actual, expected) in enumerate(
            zip(rows, expected_rows, strict=False), start=1
        ):
            if actual != expected:
                raise GovernedParameterIdentifierError(
                    f"target identifier row {index} drifted: expected {expected!r}, "
                    f"got {actual!r}"
                )
        raise GovernedParameterIdentifierError(
            "target identifier table must contain exactly the reviewed "
            "22-GGP/3-GTP rows"
        )

    for constant_name, preimage, pinned_hash, owner, schema_version, inputs in rows:
        if TARGET_CONSTANT.fullmatch(constant_name) is None:
            raise GovernedParameterIdentifierError(
                f"malformed target identifier constant: {constant_name!r}"
            )
        if PINNED_HASH.fullmatch(pinned_hash) is None:
            raise GovernedParameterIdentifierError(
                f"{constant_name} has a malformed pinned hash"
            )
        expected_preimage = f"6529STREAM_{constant_name}"
        if preimage != expected_preimage:
            raise GovernedParameterIdentifierError(
                f"{constant_name} preimage must be {expected_preimage!r}, got {preimage!r}"
            )
        computed_hash = "0x" + _keccak256(preimage.encode("ascii")).hex()
        if pinned_hash != computed_hash:
            raise GovernedParameterIdentifierError(
                f"{constant_name} hash mismatch: expected {computed_hash}, got {pinned_hash}"
            )
        if schema_version != "1":
            raise GovernedParameterIdentifierError(
                f"{constant_name} identifier schema must remain 1"
            )
        if not owner.strip():
            raise GovernedParameterIdentifierError(f"{constant_name} owner must not be empty")
        if not inputs.strip():
            raise GovernedParameterIdentifierError(f"{constant_name} inputs must not be empty")


def _validate_lta_inventories(text: str) -> None:
    text = _mask_nonrendered_markdown(text)
    ggp_section = _bounded(
        text, GGP_INVENTORY_START, GGP_INVENTORY_END, "LTA GGP inventory"
    )
    ggp_rows = _parse_markdown_table(
        ggp_section,
        GGP_TABLE_HEADER,
        GGP_TABLE_SEPARATOR,
        3,
        "LTA GGP inventory",
    )
    if ggp_rows != LTA_GGP_ROWS:
        raise GovernedParameterIdentifierError(
            "LTA GGP inventory names, hosts, or normative homes drifted"
        )

    gtp_section = _bounded(
        text, GTP_INVENTORY_START, GTP_INVENTORY_END, "LTA GTP inventory"
    )
    gtp_prefix = gtp_section.split(GTP_TABLE_HEADER, 1)[0]
    if " ".join(gtp_prefix.split()) != GTP_INVENTORY_PREFIX:
        raise GovernedParameterIdentifierError(
            "LTA GTP inventory ownership or introductory semantics drifted"
        )
    gtp_rows = _parse_markdown_table(
        gtp_section,
        GTP_TABLE_HEADER,
        GTP_TABLE_SEPARATOR,
        3,
        "LTA GTP inventory",
    )
    if gtp_rows != LTA_GTP_ROWS:
        raise GovernedParameterIdentifierError(
            "LTA GTP inventory names, hosts, or normative homes drifted"
        )


def _strip_solidity_comments(source: str) -> str:
    result: list[str] = []
    index = 0
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""
        if quote:
            result.append(current)
            if current == "\\" and index + 1 < len(source):
                index += 1
                result.append(source[index])
            elif current == quote:
                quote = ""
            index += 1
            continue
        if current in ('"', "'"):
            quote = current
            result.append(current)
            index += 1
            continue
        if current == "/" and following == "/":
            index += 2
            while index < len(source) and source[index] not in "\r\n":
                index += 1
            continue
        if current == "/" and following == "*":
            end = source.find("*/", index + 2)
            if end < 0:
                raise GovernedParameterIdentifierError(
                    "unterminated Solidity block comment in governed-parameter host"
                )
            index = end + 2
            continue
        result.append(current)
        index += 1
    return "".join(result)


def _solidity_code_mask(source: str) -> list[bool]:
    mask = [True] * len(source)
    quote = ""
    index = 0
    while index < len(source):
        current = source[index]
        if quote:
            mask[index] = False
            if current == "\\" and index + 1 < len(source):
                index += 1
                mask[index] = False
            elif current == quote:
                quote = ""
        elif current in ('"', "'"):
            quote = current
            mask[index] = False
        index += 1
    if quote:
        raise GovernedParameterIdentifierError(
            "unterminated Solidity string in governed-parameter host"
        )
    return mask


def _live_derivation_count(source: str, pattern: re.Pattern[str]) -> int:
    source = _strip_solidity_comments(source)
    code_mask = _solidity_code_mask(source)
    return sum(
        1
        for match in pattern.finditer(source)
        if code_mask[match.start()] and code_mask[match.end() - 1]
    )


def _validate_host_derivation(gas_source: str, time_source: str) -> None:
    gas_pattern = re.compile(
        r'parameterId\s*=\s*keccak256\(\s*abi\.encodePacked\('
        r'\s*"6529STREAM_GGP_"\s*,\s*config\.name\s*\)\s*\)\s*;'
    )
    time_pattern = re.compile(
        r'parameterId\s*=\s*keccak256\(\s*abi\.encodePacked\('
        r'\s*"6529STREAM_GTP_"\s*,\s*config\.name\s*\)\s*\)\s*;'
    )
    if _live_derivation_count(gas_source, gas_pattern) != 1:
        raise GovernedParameterIdentifierError(
            "StreamGasParameterHost must contain exactly one canonical GGP derivation"
        )
    if _live_derivation_count(time_source, time_pattern) != 1:
        raise GovernedParameterIdentifierError(
            "StreamTimeParameterHost must contain exactly one canonical GTP derivation"
        )


def validate_repository(root: Path) -> None:
    _validate_target_table(_read(root, TARGET_ARCHITECTURE))
    _validate_lta_inventories(_read(root, LONG_TERM_ARCHITECTURE))
    _validate_host_derivation(_read(root, GAS_HOST), _read(root, TIME_HOST))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        validate_repository(args.repo_root.resolve())
    except GovernedParameterIdentifierError as exc:
        print(f"governed parameter identifier check failed: {exc}")
        return 1
    print("governed parameter identifier check passed (22 GGP, 3 GTP)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
