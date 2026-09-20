"""Exact non-sanction VIEW preservation output ABI at immutable e8a569b3."""
from .chain_abi import Array
from .canonical import schema_id
from .scoped_static_types import SCOPE, MEMBERSHIP_FACTS
from .policy_preservation_types_v2 import POLICY, POLICY_ROW
from .native_finality_wire import COVERAGE

SOURCE_REVISION = 'e8a569b36927ed7f711a14a30ce5b09690694dd0'
MAX_ROWS, PART_ROWS, MAX_PARTS, MAX_BYTES, CHUNK_BYTES = 16384, 64, 256, 524288, 8192
PROFILE = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_CHECKPOINT_V1')
OUTPUT_PROFILE = schema_id('6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1')
ADOPTION_PROFILE = schema_id('6529STREAM_STATIC_ADOPTED_POLICY_VIEW_V2')
SOURCE_DOMAIN = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_SOURCE_V1')
ROW_DOMAIN = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_ROW_V1')
PLAN_DOMAIN = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_PLAN_V1')
CHAIN_DOMAIN = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_CHAIN_V1')
ROOT_DOMAIN = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_OUTPUT_ROOT_V1')
PART_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_VERIFIED_V1')
MANIFEST_PLAN_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_PLAN_V1')
PART_CHAIN_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_OUTPUT_PART_CHAIN_V1')
RECORD_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_VERIFIED_V1')
PART_SCHEMA = schema_id('STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1')
PART_CANON = schema_id('STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1')
INDEX_SCHEMA = schema_id('STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1')
INDEX_CANON = schema_id('STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1')
MANIFEST_PROFILE = schema_id('6529STREAM_ADOPTED_VIEW_PRESERVATION_MANIFEST_V1')
LEAF_SCHEMA = schema_id('STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1')
LEAF_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1')
NODE_DOMAIN = schema_id('6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1')
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
CHECKPOINT_PLAN = (SCOPE,'bytes32','bytes32','bytes32','bytes32','uint64','uint64','bytes32','bytes32','bytes32')
HEADER = ('bytes32','bytes32',SCOPE,'bytes32','bytes32','bytes32','bytes32','uint64','bytes32','bytes32')
CARRIER = ('bytes32','bytes32','bytes32','bytes32','uint64')
PART = (HEADER,CARRIER,'uint64','uint16','uint256','uint256')
DESCRIPTOR = ('bytes32','bytes32','bytes32','bytes32','uint64','uint64','uint16','uint256','uint256')
MANIFEST_PLAN = (HEADER,CARRIER,'uint16','uint16','uint64','uint256','bytes32','bytes32')
PART_ENVELOPE = ('bytes32','uint256','address','address','bytes32',HEADER,'uint64',Array(OUTPUT,PART_ROWS))
INDEX_ENVELOPE = ('bytes32','uint256','address','address','bytes32',HEADER,'bytes32',Array(DESCRIPTOR,MAX_PARTS))
GRAPH_KEYS = ('core','router','authority','preservationRenderer','preservationAttribution','checkpoint','outputManifest','coverage','schemas',
    'checkpointSourceWorker','checkpointTokenWorker','manifestReadWorker','manifestEncodingWorker')

CHECKPOINT_SIGNATURES = ('configuration()','configurationHash()','checkpointProfile()',
    'begin((uint8,uint256,uint256,bytes32),bytes32)','append(bytes32,uint256,bytes,bytes)',
    'seal(bytes32)','currentSource((uint8,uint256,uint256,bytes32))','checkpoint(bytes32)','outputAt(bytes32,uint256)','requireCurrentCheckpoint(bytes32)')
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

from .view_policy_adoption_types_v2 import RECORD as ADOPTION_RECORD
PRESERVATION_CONFIG = ('address','bytes32','address','bytes32','address','bytes32','uint256','uint32','uint32')
PRESERVATION_BINDING = ('address','address','address','bytes32','address','bytes32')
PRODUCER_BINDING = ('address','bytes32','bytes32','address','address','address','bytes32','address','bytes32')
ADMISSION = ('address','bytes32','bytes32','bytes32','bytes32','bytes32','bytes32')
SOURCE = (ADOPTION_RECORD, VIEW_BINDING, PRESERVATION_BINDING, ADMISSION, 'bytes32')
