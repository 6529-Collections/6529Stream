"""Exact e8a569b VIEW preservation producer and Registry ABI vocabulary."""
from .chain_abi import Array
from .canonical import schema_id
from .view_policy_adoption_types_v2 import RECORD, POLICY_BINDING, SCOPE

SOURCE_REVISION = "e8a569b36927ed7f711a14a30ce5b09690694dd0"
PROFILE = schema_id("STREAM_VIEW_PRESERVATION_ADOPTION_EVIDENCE_V1")
OUTPUT_PROFILE = schema_id("6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1")
ATTRIBUTION_PROFILE = schema_id("6529STREAM_NON_SANCTION_ATTRIBUTION_V1")

CONFIGURATION = ("address", "bytes32", "address", "bytes32", "address", "bytes32",
    "uint256", "uint32", "uint32")
BINDING = ("address", "address", "address", "bytes32", "address", "bytes32")
PRODUCER_BINDING = ("address", "bytes32", "bytes32", "address", "address", "address",
    "bytes32", "address", "bytes32")
ADMISSION = ("address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
PRESERVATION_REGISTRATION = ("bytes32", PRODUCER_BINDING, "bytes32", "bytes32", "bytes32")
PRESERVATION_RECORD = (PRESERVATION_REGISTRATION, "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32")
READ = ("uint16", "bytes4", "uint32", "bool")
TARGET = ("address", "bytes32", "bytes32")
VERSION = ("bool", "bool", "address", "bytes32", "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32")

MAX_READS = 128
MAX_TARGETS = 64
READS = Array(READ, MAX_READS)
TARGETS = Array(TARGET, MAX_TARGETS)

# Exact selected historical source tuple consumed by the later checkpoint source.
SOURCE = (RECORD, POLICY_BINDING, BINDING, ADMISSION, "bytes32")

GRAPH_KEYS = (
    "core", "router", "authority", "checkpoint", "outputManifest", "coverage", "schemas",
    "store", "artist", "metadata", "finality", "provider", "views", "scopeMembership",
    "sourceFactory", "entropySourceSet", "coordinatorInventory", "renderer",
    "rendererRegistry", "checkpointSourceWorker", "checkpointTokenWorker",
    "manifestReadWorker", "manifestEncodingWorker", "tokenInventory", "attribution",
    "rendererEncoding", "preservationRenderer", "preservationAttribution",
    "preservationWorker", "preservationEncoding", "viewSnapshot",
)
