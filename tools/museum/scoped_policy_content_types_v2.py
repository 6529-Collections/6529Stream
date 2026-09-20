"""Distinct scoped factory-policy V2 content ABI at frozen native e0b4d17b."""
from .chain_abi import Array
from .canonical import schema_id
from .native_finality_wire import LEAF, ARTIFACT, COVERAGE
from .scoped_static_types import SCOPE, SELECTION_PLAN, SELECTION_ROW, SCOPE_INPUTS, COMPONENT, ROOT_PUBLICATION, ROOT_RECORD, ROOT_AGGREGATE, STATEMENT
from .policy_content_types_v2 import READINESS, CONTENT_PLAN, OUTPUT, OUTPUT_MANIFEST, OUTPUT_PLAN, TERMINAL_EVIDENCE, FINALITY_ENTROPY

SOURCE_REVISION = "e0b4d17bc548f778a379773234caee545658bcdc"
MAX_OUTPUTS, MAX_HISTORY, MAX_PARTS, CHUNK_BYTES = 818, 256, 64, 8192
PROFILE = schema_id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
ROOT_PROFILE = schema_id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2")
FACTORY_PROFILE = schema_id("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
OUTPUT_SCHEMA = schema_id("STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2")
OUTPUT_CANON = schema_id("STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2")
LEAF_SCHEMA = schema_id("STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2")
ROOT_SCHEMA = schema_id("STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2")
ROOT_CANON = schema_id("STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2")
ROOT_BINDING = ("bytes32", "address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
FACTORY_DEPENDENCIES = (("address",)*4, ("bytes32",)*4, "uint256", "uint32", "uint32")
OUTPUT_ENVELOPE = ("bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32", "bytes32",
    SCOPE, "bytes32", "bytes32", "uint64", Array(OUTPUT, MAX_OUTPUTS))
SNAPSHOT_DEFINITION_HASHES = ('0xf2033babe894d0d330b7199fd63eb59f57e1314db0ae56df25b114c95eb43f16', '0x2a9edb22fe6d8eb7105c2964dbcea97284c317242a3ee0c544dc04e6c3a4870b', '0xef2fb02d8cfc42671a863fdf6d4b6d5e2ffa03f053ff9019898ec0711af289a0')

# XOR of the selectors declared by each exact e0b4 interface (inherited methods excluded).
CONTENT_INTERFACE = "0x1cb8d2ce"
OUTPUT_INTERFACE = "0x002e3629"
ROOT_INTERFACE = "0x844388f1"
CONTENT_SIGNATURES = ("core()", "scopedPolicyProfile()", "sourceFactory()", "factoryDependenciesHash()",
    "metadataRouter()", "selectionCheckpoint()", "entropySourceSet()", "terminalReadiness()",
    "begin(bytes32,bytes32)", "append(bytes32,(uint256,bytes,bytes)[])", "checkpoint(bytes32)",
    "outputAt(bytes32,uint256)", "requireCurrentCheckpoint(bytes32)")
OUTPUT_SIGNATURES = ("outputProfile()", "scopedOutputProfile()", "core()", "contentCheckpoint()", "artifactCoverage()",
    "beginManifest(bytes32,bytes32,bytes32,bytes32)", "verifyNextOutputs(bytes32,uint256)",
    "manifestPlan(bytes32)", "manifestRecord(bytes32)", "requireCurrentManifest(bytes32,bytes32)")
ROOT_SIGNATURES = (
    "previewScopedPolicyContentRootPublication(((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,string),address)",
    "publishScopedPolicyContentRootPublication(((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,string))",
    "scopedPolicyContentRootBinding(bytes32)")
