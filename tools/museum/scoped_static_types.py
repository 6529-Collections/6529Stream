"""Exact stable scoped STATIC ABI descriptors at the immutable 896899 native source.

Array maxima are finite consumer bounds. No schema registration, source
authentication, renderer execution or historical/current authority is implied.
"""
from .chain_abi import Array
from .canonical import schema_id
from .independent_wire import RECORD as METADATA_RECORD
from .native_finality_wire import ARTIFACT, COVERAGE, LEAF, COMPONENT, MANIFEST_REF

SOURCE_REVISION = "896899f7ca4130f86e066587f780a3b1f755a25d"
SCOPED_INPUT_SCHEMA = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1")
SCOPED_INPUT_CANON = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1")
OUTPUT_SCHEMA = schema_id("STREAM_STATIC_OUTPUT_MANIFEST_V1")
OUTPUT_CANON = schema_id("STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1")
MAX_OUTPUTS = 1818  # (64 * 8192 - 480) // 288, the original output manifest bound.
MAX_HISTORY = 1024
MAX_MEMBERS = 16384
MAX_PARTS = 64
CHUNK_BYTES = 8192
SCOPE = ("uint8", "uint256", "uint256", "bytes32")
ADDRESS11 = ("address",) * 11
HASH11 = ("bytes32",) * 11
METADATA_RECEIPT = ("uint256", "address", "uint8", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32")
MEMBERSHIP_FACTS = ("bytes32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32", "uint256", "bytes32")
MEMBERSHIP_PUBLICATION = ("bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "uint64", METADATA_RECEIPT)
MEMBERSHIP_PROGRESS = ("bool", "bool", "uint256", "uint256", "uint256", "uint256")
# Flat abi.encode fields, not abi.encode(one dynamic struct).
MEMBERSHIP_MANIFEST = ("uint16", "uint256", "address", "uint256", "uint8", "uint256", "bytes32", Array("bytes32", MAX_PARTS))
STATIC_SELECTION = ("address", "bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
SELECTION_PLAN = (SCOPE, "bytes32", "bytes32", "uint64", "uint64", "bytes32")
SELECTION_ROW = ("uint256", "bytes32", "bytes32", "bytes32", "bytes32", STATIC_SELECTION, ("address",) * 6, ("bytes32",) * 6)
CONTENT_PLAN = ("bytes32", "bytes32", SCOPE, "uint64", "uint64", "bytes32", "bytes32", "bytes32")
OUTPUT = (LEAF, "bytes32", "bytes32", "bytes32")
OUTPUT_MANIFEST = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", SCOPE, "uint64", "uint64")
OUTPUT_PLAN = (OUTPUT_MANIFEST, "uint64", "bytes32")
OUTPUT_ENVELOPE = ("bytes32", "uint256", "address", "address", "bytes32", "bytes32", SCOPE,
    "bytes32", "bytes32", "uint64", Array(OUTPUT, MAX_OUTPUTS))
ARTIST_PRESENTATION = ("bool", "address", "bytes32", "bytes32", "uint64", "bytes32", "address", "bytes32", "bytes32", "uint64", "uint64", "bytes32")
COORDINATOR_POLICY = ("address", "bytes32", "uint256", "bool", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "uint32", "bytes32", "bytes32")
COORDINATOR_EVIDENCE = ("bytes32", "bytes32", "bytes32", "uint256", "bool", Array(COORDINATOR_POLICY, MAX_OUTPUTS))
SNAPSHOT_DEPS = (ADDRESS11, HASH11, "uint256", "uint256", "uint256", "uint256")
SNAPSHOT_PUBLICATION = (SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", "string", "uint64", "bytes32")
SNAPSHOT_RECEIPT = ("bytes32", "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "uint32", "bytes32", "address",
    "uint8", "uint64", "uint8", "uint64", "uint64", "bytes32", "bytes32", "bytes32")
SNAPSHOT_SOURCE = (SCOPE, MEMBERSHIP_FACTS, ARTIST_PRESENTATION, SELECTION_PLAN, CONTENT_PLAN, OUTPUT_MANIFEST, COORDINATOR_EVIDENCE)
SNAPSHOT_LOCK = ("bytes32", "uint64", "bytes32", "uint64")
SNAPSHOT_ENVELOPE = ("bytes32", "uint256", "address", ADDRESS11, HASH11, SNAPSHOT_PUBLICATION, SNAPSHOT_RECEIPT, SNAPSHOT_SOURCE)
ROOT_PUBLICATION = (SCOPE, "bytes32", "bytes32", "uint64", "string")
ROOT_RECORD = (ROOT_PUBLICATION, "address", "bytes32", "bytes32", "bytes32", "bytes32", "uint64", "bytes32",
    "bytes32", "uint64", "bytes32", "address", "uint8", "uint64", "bytes32", "bytes32", "bytes32", "uint64")
ROOT_AGGREGATE = ("uint64", "bytes32")
SCOPE_INPUTS = ("bytes32",) * 10
STATEMENT = (SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", SCOPE_INPUTS, Array(COMPONENT, 9), "uint8", "uint8", "uint8")
INPUT_ENVELOPE = ("bytes32", "bytes32", "uint256", "address", "address", "address", STATEMENT)
