"""Exact VIEW media locators and original Archive admission correspondence.

Locator rows preserve an HTTPS identifier or Arweave transaction ID without
claiming it is a file digest.  A temporary local copy receives the retained
external object's content hash and size before the unchanged
full bundle admission validator runs; the retained inventory row is never
mutated.
"""

import base64
import binascii

from . import view_preservation_bundle_wire_v1 as bundle_wire
from . import view_preservation_inventory_items_v1 as inventory_items
from . import view_preservation_inventory_types_v1 as inventory_types
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json


SOURCE_REVISION = "0ab0cf308894afb2c80d10fe0b1a4da8db9ca615"
SOURCE_BLOBS = {
    "smart-contracts/domains/preservation/StreamViewPreservationMediaCorrespondenceV1.sol":
        "d82a99a81428ed8ff0031e2db127a4a0058a806e9266b533c9248e2dee7c7815",
    "smart-contracts/domains/preservation/StreamViewPreservationArchiveReadsV1.sol":
        "de3f3169d8ba2537a25ad22f9d6fa9b35265da48b9465fa54f9c6d7ec1acb1c6",
    "smart-contracts/domains/preservation/StreamPreservationInventoryItems.sol":
        "80a85f2cfbbed0b51db75322d877612489f9856ebee240bc388540ecae499c8e",
    "smart-contracts/interfaces/stream/preservation/StreamPreservationInventoryTypes.sol":
        "b4f1112529dce21229f68975fbf2dbf5a52073e8e6371846a1357c5b831e1e37",
}

LOCATOR_ROLE = schema_id("VIEW_ARCHIVE_LOCATOR_IMAGE")
LOCATOR_DOMAIN = schema_id("6529STREAM_VIEW_ARCHIVE_LOCATOR_OBLIGATION_V1")
RAW = schema_id("RAW_BYTES")


def _locator(uri):
    require(type(uri) is str, "invalid VIEW preservation media locator")
    try:
        raw = uri.encode("utf-8")
    except UnicodeError as exc:
        raise MuseumError("invalid VIEW preservation media locator") from exc
    if raw.startswith(b"https://"):
        require(10 <= len(raw) <= 2048, "invalid VIEW institutional locator")
        host_end = len(raw)
        for index, value in enumerate(raw[8:], start=8):
            require(
                0x20 < value < 0x7F and value not in b"@#\\%",
                "invalid VIEW institutional locator",
            )
            if host_end == len(raw) and value == ord("/"):
                host_end = index
        require(
            host_end not in (8, len(raw))
            and host_end + 1 != len(raw)
            and host_end - 8 <= 253,
            "invalid VIEW institutional locator",
        )
        label_start = 8
        for index in range(8, host_end + 1):
            if index == host_end or raw[index] == ord("."):
                require(
                    index != label_start
                    and index - label_start <= 63
                    and raw[label_start] != ord("-")
                    and raw[index - 1] != ord("-"),
                    "invalid VIEW institutional locator",
                )
                label_start = index + 1
            else:
                value = raw[index]
                require(
                    ord("a") <= value <= ord("z")
                    or ord("0") <= value <= ord("9")
                    or value == ord("-"),
                    "invalid VIEW institutional locator",
                )
        return 1, ZERO

    require(
        len(raw) == 48 and raw.startswith(b"ar://"),
        "invalid VIEW Arweave locator",
    )
    encoded = raw[5:]
    require(
        all(
            ord("A") <= value <= ord("Z")
            or ord("a") <= value <= ord("z")
            or ord("0") <= value <= ord("9")
            or value in (ord("-"), ord("_"))
            for value in encoded
        ),
        "invalid VIEW Arweave locator",
    )
    try:
        transaction = base64.urlsafe_b64decode(encoded + b"=")
    except (binascii.Error, ValueError, TypeError) as exc:
        raise MuseumError("invalid VIEW Arweave locator") from exc
    require(
        len(transaction) == 32
        and any(transaction)
        and base64.urlsafe_b64encode(transaction).rstrip(b"=") == encoded,
        "invalid VIEW Arweave locator",
    )
    return 2, "0x" + transaction.hex()


def locator(uri):
    """Return native locator kind and its optional canonical transaction ID."""
    try:
        return _locator(uri)
    except MuseumError:
        raise
    except (TypeError, ValueError, OverflowError, UnicodeError) as exc:
        raise MuseumError("invalid VIEW preservation media locator") from exc


def _media(source, record, uri):
    require(type(uri) is str, "invalid VIEW preservation media URI")
    if type(uri) is str and (uri.startswith("https://") or uri.startswith("ar://")):
        locator(uri)
        row = list(inventory_items.empty(4, LOCATOR_ROLE, source, record, 0))
        row[6] = RAW
        row[8] = uri
        row[16] = keccak256(
            encode(("bytes32", "address", "bytes32", "string"),
                   (LOCATOR_DOMAIN, source, record, uri))
        )
        return tuple(row)
    # Unchanged absent and canonical raw-CID behavior remains owned by the
    # frozen inventory item constructor.
    return inventory_items.media(source, record, uri)


def media(source, record, uri):
    """Construct the exact native VIEW media item without materializing bytes."""
    try:
        return _media(source, record, uri)
    except MuseumError:
        raise
    except (TypeError, ValueError, OverflowError, UnicodeError) as exc:
        raise MuseumError("invalid VIEW preservation media URI") from exc


def _validate_admission(item, admission, evidence, dependencies, artist, originals):
    row = from_json(inventory_types.ITEM, item)
    saved = from_json(inventory_types.ADMISSION, admission)
    d = from_json(inventory_types.BUNDLE_DEPENDENCIES, dependencies)
    artist = from_json("bytes32", artist)
    if row[1] != LOCATOR_ROLE:
        bundle_wire._admission(row, saved, evidence, d, artist, originals)
        return None

    require(
        row == media(row[2], row[3], row[8])
        and row[0] == 4
        and saved[0][0] == 1
        and saved[0][1] != ZERO
        and saved[0][2] != ZERO
        and type(evidence) is dict
        and set(evidence) == {"object", "receipts", "fixities", "checkpoint"},
        "VIEW locator original item/proof differs",
    )
    obj = from_json(bundle_wire.OBJECT, evidence["object"])
    materialized = list(row)
    materialized[5] = 1
    materialized[7] = hex_bytes(obj[3], 32)
    materialized[9] = obj[6]
    bundle_wire._admission(tuple(materialized), saved, evidence, d, artist, originals)

    kind, transaction_id = locator(row[8])
    coverage = saved[3]
    receipt_index = 1 if kind == 1 else 0
    receipt_hash = coverage[10] if kind == 1 else coverage[9]
    family_hash = coverage[8] if kind == 1 else coverage[7]
    raw = hex_bytes(evidence["receipts"][receipt_index])
    receipt, observed, _ = decode(
        (bundle_wire.RECEIPT, "bytes", "bytes"), raw, maximum=65536
    )
    expected = row[8].encode("utf-8") if kind == 1 else hex_bytes(transaction_id, 32)
    require(
        receipt[0] == coverage[1]
        and receipt[1] == family_hash
        and receipt[6] != ZERO_ADDRESS
        and observed == expected
        and receipt[2] == keccak256(expected)
        and receipt_hash
        == bundle_wire._domain(
            "6529STREAM_EXTERNAL_RECEIPT_V1",
            ("uint256", "address", bundle_wire.RECEIPT),
            (d[2], d[0][4], receipt),
        )
        and (kind != 2 or receipt[5] == coverage[13]),
        "VIEW locator signed receipt correspondence differs",
    )
    return json_values(
        {
            "kind": "institutional_https" if kind == 1 else "arweave_transaction",
            "receiptHash": receipt_hash,
            "objectHash": coverage[1],
            "coverageHash": coverage[0],
        }
    )


def validate_admission(item, admission, evidence, dependencies, artist, originals):
    """Validate one ordinary or locator-aware original bundle admission."""
    try:
        return _validate_admission(
            item, admission, evidence, dependencies, artist, originals
        )
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError) as exc:
        raise MuseumError("invalid VIEW locator admission") from exc
