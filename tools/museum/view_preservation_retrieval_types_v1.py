"""Exact ABI vocabulary for the frozen attributed VIEW retrieval consumer."""

from .canonical import schema_id
from .chain_abi import Array
from .scoped_static_types import SCOPE, ARTIST_PRESENTATION
from .view_preservation_inventory_types_v1 import (
    ITEM, ADMISSION, BUNDLE_DEPENDENCIES, CONTEXT as INVENTORY_CONTEXT,
    EVIDENCE as INVENTORY_EVIDENCE, DEPENDENCIES as INVENTORY_DEPENDENCIES,
)
from .view_preservation_snapshot_types_v1 import DEPENDENCIES as SNAPSHOT_DEPENDENCIES
from .view_preservation_reference_types_v1 import COVERAGE
from .view_preservation_bundle_wire_v1 import OBJECT

SOURCE_REVISION = "666331709d590ce680b52cc9fd2c1f0c43561ac6"
ROOT_INTEGRATION_REVISION = "0c14acde766b65f791de9930bc7e9575078eaae4"

PROFILE = schema_id("6529STREAM_VIEW_ATTRIBUTED_RETRIEVAL_V1")
OBSERVATION_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_OBSERVATION_V1")
SOURCE_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_SOURCE_V1")
RECORD_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_RECORD_V1")
NONCE_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_NONCE_V1")
ROLE = schema_id("VIEW_ATTRIBUTED_RETRIEVAL_IMAGE")
REVOCATION_SCOPE_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_REVOCATION_SCOPE_V1")
ARCHIVE_ENVIRONMENT_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_ARCHIVE_ENVIRONMENT_V1")
ADMITTED_BUNDLE_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_ADMITTED_BUNDLE_V1")
CURRENT_OBSERVATION_DOMAIN = schema_id("6529STREAM_VIEW_RETRIEVAL_CURRENT_OBSERVATION_V1")
INVENTORY_PROFILE = schema_id("6529STREAM_VIEW_PRESERVATION_RENDER_CRITICAL_RETRIEVAL_V1")

MAX_BYTES = 524288
MAX_SIGNATURE = 4096
MAX_URI = 2048
MAX_STEPS = 256  # Offline reader availability bound; the native payload byte cap is authoritative.

CONFIGURATION = (
    "address", "bytes32", "address", "bytes32", "address", "bytes32",
    "address", "bytes32", "uint256", "uint32", "uint32", "uint32", "uint32",
)
SOURCE = (
    SCOPE, "address", "address", "bytes32", "bytes32", "address", "bytes32",
    "bytes32", "bytes32", "string", "bytes32", "bytes32",
)
STEP = ("uint8", "string", "string", "uint16", "bytes32", "bytes32", "bytes")
STEPS = Array(STEP, MAX_STEPS)
REQUEST = (SCOPE, "bytes32", STEPS, "string", "uint64", "uint256", "uint64")
OBSERVATION = (SOURCE, OBJECT, COVERAGE, STEPS, "string", "address", "uint64", "uint256", "uint64")
RECEIPT = (
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "address",
    "uint64", "bytes32", "uint32",
)
CURRENT_PAIR = (
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64",
    "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32",
)
ARCHIVE_FAMILY = ("bytes32",) * 8 + ("uint8", "address", "bytes32")

WITNESS_INTERFACE_ID = "0xbb7daaf2"
INVENTORY_BINDING_INTERFACE_ID = "0xb3df912c"
SELECTORS = {
    "configuration": "0x6c70bee9",
    "configurationHash": "0x183ccffa",
    "encoded": "0x4571fe2c",
    "nonceUsed": "0x61a4422b",
    "prepare": "0xe8045dff",
    "publish": "0x383f8034",
    "record": "0xb5c645bd",
    "requireCorrespondence": "0x82f09dbc",
    "requireCurrent": "0x3652337c",
    "retrievalProfile": "0x3593ffb1",
    "revocationEpoch": "0xffc47b19",
    "revoke": "0xc2664610",
    "revoked": "0x328a93e8",
    "retrievalWitnessBinding": "0xb3df912c",
}

RECORDED_TOPIC = schema_id(
    "ViewRetrievalRecorded(bytes32,bytes32,address,(bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bytes32,uint32))"
)
REVOKED_TOPIC = schema_id("ViewRetrievalRevoked(bytes32,address,bytes32)")

SOURCE_BLOBS = {
    "smart-contracts/interfaces/stream/preservation/StreamViewPreservationRenderCriticalTypesV1.sol":
        "c04a1b1650daffb042c61f22390a11a36ab7de174642caefba2555d0c1fdf98d",
    "smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalInventoryV1.sol":
        "2cc45986dc2678155ec58d763d0b5ec724c0b5c8f2c94228ebea8a889cb58656",
    "smart-contracts/domains/preservation/StreamViewPreservationRenderCriticalArtworkReadsV1.sol":
        "63bb3fa971eea43b06919d6cd31c3161ccdfb416b75ffea3512fb9bf5b94b8b6",
    "smart-contracts/interfaces/stream/preservation/IStreamViewRetrievalInventoryBindingV1.sol":
        "34f196c574ab216a12762c583d0c2b7e6a661c78f7452232a4edb40e922b9216",
    "smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol":
        "1884c98e1d54b4a291376ae83d4e743b135125a98b93b1ab27d106b228ec78fe",
    "smart-contracts/interfaces/stream/preservation/IStreamViewRetrievalWitnessV1.sol":
        "e8053565fc143a0a74bd25741587ec4f06e8d4ab4b1db83514191ca0a7762e26",
    "smart-contracts/domains/preservation/StreamViewRetrievalCodecV1.sol":
        "ee736be196258bf6b769e309b43aa195cdf4f2f96d5af9df220c7faab834c932",
    "smart-contracts/domains/preservation/StreamViewRetrievalSourceV1.sol":
        "332fabdf3afe388841338c7e7d83e8c80be44c8b8d17bb02124fdc4d4a7880db",
    "smart-contracts/domains/preservation/StreamViewRetrievalArchiveV1.sol":
        "12b32caedffd3e4a307e7a1cad1a2b64891022e394173019064ffafdd549cb1c",
    "smart-contracts/domains/preservation/StreamViewRetrievalWitnessV1.sol":
        "265ddc4188438787d723a2a4a55b8f413188dbb906df641943f638d701ff9970",
    "smart-contracts/domains/preservation/StreamViewRetrievalBindingV1.sol":
        "9db566bbd0026e88d3e17f7fc2e230cbb77f6cf660d6f96d10f9d7a985348e00",
    "smart-contracts/domains/preservation/StreamViewRetrievalObligationV1.sol":
        "447ec84a0b7e54795f8b1f8876260daf0075813845783ad09b67750273263b65",
    "smart-contracts/domains/preservation/StreamViewRetrievalConsumerV1.sol":
        "ae74567a3b60c61e93a39583a28e6366d3da687475f1059c0f498f17cee5a84e",
}
