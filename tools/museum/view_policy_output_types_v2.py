"""Exact adopted VIEW policy output ABI at immutable e0b4d17b; no finality codec."""
from .chain_abi import Array
from .canonical import schema_id
from .scoped_static_types import SCOPE, MEMBERSHIP_FACTS
from .policy_preservation_types_v2 import POLICY, POLICY_ROW
from .native_finality_wire import COVERAGE

SOURCE_REVISION = 'e0b4d17bc548f778a379773234caee545658bcdc'
MAX_ROWS, PART_ROWS, MAX_PARTS, MAX_BYTES, CHUNK_BYTES = 16384, 64, 256, 524288, 8192
PROFILE = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_CHECKPOINT_V2')
OUTPUT_PROFILE = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_MANIFEST_V2')
ADOPTION_PROFILE = schema_id('6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2')
SOURCE_DOMAIN = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_CHECKPOINT_SOURCE_V2')
ROW_DOMAIN = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_ROW_V2')
PLAN_DOMAIN = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_CHECKPOINT_PLAN_V2')
CHAIN_DOMAIN = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_CHAIN_V2')
ROOT_DOMAIN = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_OUTPUT_ROOT_V2')
PART_DOMAIN = schema_id('6529STREAM_VIEW_OUTPUT_PART_VERIFIED_V2')
MANIFEST_PLAN_DOMAIN = schema_id('6529STREAM_VIEW_OUTPUT_MANIFEST_PLAN_V2')
PART_CHAIN_DOMAIN = schema_id('6529STREAM_VIEW_OUTPUT_PART_CHAIN_V2')
RECORD_DOMAIN = schema_id('6529STREAM_VIEW_OUTPUT_MANIFEST_VERIFIED_V2')
PART_SCHEMA = schema_id('STREAM_VIEW_POLICY_OUTPUT_PART_V2')
PART_CANON = schema_id('STREAM_ABI_VIEW_POLICY_OUTPUT_PART_V2')
INDEX_SCHEMA = schema_id('STREAM_VIEW_POLICY_OUTPUT_MANIFEST_V2')
INDEX_CANON = schema_id('STREAM_ABI_VIEW_POLICY_OUTPUT_MANIFEST_V2')
POLICY_FAMILY = '0x0d9d63287ae079e8c4867d6a82952c694dccd17190f625997cfcf8dccbe9bcb2'

CHECKPOINT_CONFIG = ('address','bytes32','address','bytes32','address','bytes32',
    'address','bytes32','bytes32','uint256','uint32','uint32')
MANIFEST_CONFIG = ('address','bytes32','address','bytes32','bytes32','address','bytes32',
    'address','bytes32','uint256','uint32','uint32')
VIEW_BINDING = ('address','bytes32','address','bytes32','address','bytes32','uint256',
    SCOPE,MEMBERSHIP_FACTS,'bytes32','bytes32','bytes32','uint256')
ENTROPY = ('address','bytes32','bytes32','bool',POLICY,'uint8','bytes32','bool','bool')
OUTPUT = ('uint64','uint256','uint256','uint8','bool','uint8','bytes32',ENTROPY,
    'bytes32','bytes32','uint32','uint32')
CHECKPOINT_PLAN = (SCOPE,'bytes32','bytes32','bytes32','bytes32','uint64','uint64','bytes32','bytes32')
HEADER = ('bytes32','bytes32',SCOPE,'bytes32','bytes32','bytes32','bytes32','uint64','bytes32')
CARRIER = ('bytes32','bytes32','bytes32','bytes32','uint64')
PART = (HEADER,CARRIER,'uint64','uint16','uint256','uint256')
DESCRIPTOR = ('bytes32','bytes32','bytes32','bytes32','uint64','uint64','uint16','uint256','uint256')
MANIFEST_PLAN = (HEADER,CARRIER,'uint16','uint16','uint64','uint256','bytes32','bytes32')
PART_ENVELOPE = ('bytes32','uint256','address','address','bytes32',HEADER,'uint64',Array(OUTPUT,PART_ROWS))
INDEX_ENVELOPE = ('bytes32','uint256','address','address','bytes32',HEADER,'bytes32',Array(DESCRIPTOR,MAX_PARTS))
GRAPH_KEYS = ('core','router','authority','serving','checkpoint','outputManifest','coverage','schemas',
    'checkpointSourceWorker','checkpointTokenWorker','manifestReadWorker','manifestEncodingWorker')

CHECKPOINT_SIGNATURES = ('configuration()','configurationHash()','checkpointProfile()',
    'begin((uint8,uint256,uint256,bytes32),bytes32)','append(bytes32,uint256,bytes,bytes)',
    'seal(bytes32)','checkpoint(bytes32)','outputAt(bytes32,uint256)','requireCurrentCheckpoint(bytes32)')
MANIFEST_SIGNATURES = ('configuration()','configurationHash()','outputProfile()',
    'preparePart(bytes32,uint64,bytes32,bytes32,bytes32)',
    'beginManifest(bytes32,bytes32,bytes32,bytes32)','verifyNextPart(bytes32,bytes32)',
    'partRecord(bytes32)','manifestPlan(bytes32)','manifestRecord(bytes32)',
    'manifestPart(bytes32,uint256)','requireCurrentManifest(bytes32,bytes32)')

def _interface(signatures):
    value = 0
    for signature in signatures: value ^= int(schema_id(signature)[2:10],16)
    return '0x'+value.to_bytes(4,'big').hex()

CHECKPOINT_INTERFACE = _interface(CHECKPOINT_SIGNATURES)
MANIFEST_INTERFACE = _interface(MANIFEST_SIGNATURES)
