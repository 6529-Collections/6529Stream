"""Exact original COLLECTION policy V2 ABI; no runtime source discovery."""
from .chain_abi import Array
from .canonical import schema_id
from .native_finality_wire import LEAF, ROOT_PUBLICATION, ROOT_RECORD, ARTIFACT, COVERAGE
from .scoped_static_types import SCOPE, SELECTION_PLAN, SELECTION_ROW, SCOPE_INPUTS, COMPONENT

SOURCE_REVISION = "896899f7ca4130f86e066587f780a3b1f755a25d"
MAX_OUTPUTS, MAX_HISTORY, MAX_PARTS, CHUNK_BYTES = 818, 256, 64, 8192
PROFILE = schema_id("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2")
OUTPUT_SCHEMA = schema_id("STREAM_POLICY_OUTPUT_MANIFEST_V2")
OUTPUT_CANON = schema_id("STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2")
LEAF_SCHEMA = schema_id("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2")
ROOT_SCHEMA = schema_id("STREAM_POLICY_CONTENT_ROOT_RECORD_V2")
ROOT_CANON = schema_id("STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2")
CHECKPOINT_INTERFACE, MANIFEST_INTERFACE, ROOT_INTERFACE = "0xb5adb94d", "0x80210de4", "0xd1ef3880"
READINESS = ("address", "bytes32", "bytes32", "uint8", "uint8", "uint8", "uint8", "bool", "bool", "bytes32")
CONTENT_PLAN = ("bytes32", "bytes32", "bytes32", "bytes32", SCOPE, "uint64", "uint64", "bytes32", "bytes32", "bytes32")
OUTPUT = (LEAF, "bytes32", "bytes32", "bytes32", READINESS, "bytes32")
OUTPUT_MANIFEST = ("bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", SCOPE, "uint64", "uint64")
OUTPUT_PLAN = (OUTPUT_MANIFEST, "uint64", "bytes32")
OUTPUT_ENVELOPE = ("bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32",
    SCOPE, "bytes32", "bytes32", "uint64", Array(OUTPUT, MAX_OUTPUTS))
ROOT_BINDING = ("bytes32", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
TERMINAL_EVIDENCE = (READINESS, "bytes32", "bytes32", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32")
FINALITY_ENTROPY = ("address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32")
STATEMENT = (SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", SCOPE_INPUTS,
    Array(COMPONENT, 9), FINALITY_ENTROPY, "uint8", "uint8")
