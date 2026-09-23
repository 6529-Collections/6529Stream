"""Exact adopted VIEW V1/V2 ABI vocabulary at native source e0b4d17b.

The two adoption profiles deliberately share one Router head, record carrier,
and collection aggregate.  A zero profile tag identifies an original V1
record; the V2 tag is explicit.  The bounds below are reader availability
bounds and are not native producer limits unless the native type says so.
"""
from .chain_abi import Array
from .canonical import schema_id
from .independent_wire import HASH_REF, RECORD as COLLECTION_RECORD
from .scoped_static_types import MEMBERSHIP_FACTS, SCOPE, STATIC_SELECTION

SOURCE_REVISION = "e0b4d17bc548f778a379773234caee545658bcdc"
MAX_HISTORY = 256
MAX_PAYLOAD = 40960
MAX_CHUNKS = 5

V1_PROFILE = schema_id("6529STREAM_STATIC_ADOPTED_VIEW_V1")
V1_CONTEXT = schema_id("STREAM_ADOPTED_VIEW_CONTEXT_V1")
V2_PROFILE = schema_id("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2")
V2_CONTEXT = schema_id("STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2")

ROUTE_BINDING = ("address", "bytes32", "address", "bytes32", "uint32", "uint32")
ROUTE = ("address", "bytes32", "address", "bytes32", "address", "bytes32",
    "address", "bytes32", "address", "bytes32", "address", "bytes32",
    "address", "bytes32", "address", "bytes32", ROUTE_BINDING)
INPUT = (SCOPE, "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32")
SOURCE = (ROUTE, MEMBERSHIP_FACTS, STATIC_SELECTION, "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32", "bytes32", "uint32", ("address",) * MAX_CHUNKS,
    ("bytes32",) * MAX_CHUNKS)
AGGREGATE = ("uint64", "bytes32")
RECORD = (INPUT, SOURCE, "bytes32", "bytes32", "uint64", "address", "uint8",
    "uint256", "uint64", "bytes32", "uint64", AGGREGATE)

VIEW_MANIFEST = ("bytes32", "bytes32", "string", "bytes32", "string", "bool")
VIEW_RECEIPT = ("uint256", "bytes32", "uint64", "bytes32", "address", "uint8",
    "uint256", "uint64", "uint64", "uint64", "bytes32", "bytes32", "bytes32", "bytes32")
DECLARATION = (VIEW_MANIFEST, VIEW_RECEIPT, COLLECTION_RECORD)
PAYLOAD = ("bytes32", "string", "string", "string", "bytes")

RENDERER_MANIFEST = ("bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "string", "string", "bytes32", "uint32", "uint32", "bool")
RENDERER_BINDINGS = (("address",) * 4, ("bytes32",) * 4, "address", "bytes32",
    RENDERER_MANIFEST)

POLICY_BINDING = ("address", "bytes32", "address", "bytes32", "address", "bytes32",
    "uint256", SCOPE, MEMBERSHIP_FACTS, "bytes32", "bytes32", "bytes32", "uint256")

# Normalized capture-only rows. Native events carry the complete RECORD tuple;
# block coordinates and timestamp come from the retained receipt/header.
EVENT = ("uint16", "bytes32", "uint256", "bytes32", "bytes32", RECORD,
    "uint256", "bytes32", "bytes32", "uint256", "uint256", "uint64")

# Retained chunks include their complete bytes so an offline consumer does not
# trust a pointer/hash assertion. The pointer runtime is STOP || bytes.
CHUNK = ("address", "bytes32", "bytes")
CHUNKS = Array(CHUNK, MAX_CHUNKS)
