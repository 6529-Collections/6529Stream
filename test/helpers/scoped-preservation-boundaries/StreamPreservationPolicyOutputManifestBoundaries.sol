// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { LeafManifestVm } from "./StreamContentLeafManifestVm.sol";
import {
    LeafManifestArchiveBoundary,
    LeafManifestFinalityBoundary
} from "./StreamContentLeafManifestBoundaries.sol";
import { CheckpointCoreBoundary } from "./StreamOnchainContentCheckpointCoreBoundary.sol";
import {
    CharacterizationTestBase,
    Vm
} from "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import { MetadataExecutorBoundary } from "./StreamCollectionMetadataV1Boundaries.sol";
import {
    StreamSchemaRegistry
} from "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import {
    StreamSchemaDocumentStore
} from "../../../smart-contracts/domains/metadata/StreamSchemaDocumentStore.sol";
import {
    IStreamSchemaRegistry as Schema
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamFinalityArtifactCoverage
} from "../../../smart-contracts/domains/preservation/StreamFinalityArtifactCoverage.sol";
import {
    IStreamFinalityArtifactCoverage
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamFinalityArtifactCoverage.sol";
import {
    StreamFinalityArtifactTypes as F
} from "../../../smart-contracts/interfaces/stream/preservation/StreamFinalityArtifactTypes.sol";
import {
    IStreamCorePointers
} from "../../../smart-contracts/interfaces/stream/core/IStreamCorePointers.sol";
import {
    IStreamGasParameterHost
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    StreamTokenContentLeaf
} from "../../../smart-contracts/interfaces/stream/metadata/StreamTokenContentTypes.sol";
import {
    StreamTokenContentTree
} from "../../../smart-contracts/domains/metadata/StreamTokenContentTree.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as E
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as O
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as V
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputTypesV1 as P
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyOutputTypesV1.sol";
import {
    StreamPreservationPolicyOutputManifestV1
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationPolicyOutputSchemasV1 as Definitions
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV1.sol";
import {
    IStreamPolicyContentCheckpointV2 as OldOutput
} from "../../../smart-contracts/interfaces/stream/finality/IStreamPolicyContentCheckpointV2.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

/// @dev Explicit producer identity boundary. This marker makes no rendering/admission claim.
contract PreservationManifestProducerBoundary {
    function preservationProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }
}

/// @dev Explicit checkpoint/currentness boundary. Full-policy rendering, membership and governed
/// per-version admission are tested at their producer, not simulated as genuine evidence here.
contract PreservationManifestCheckpointBoundary {
    address public immutable core;
    bytes32 public preservationPolicyProfile =
        keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V1");
    bool public capability = true;
    bool public valid = true;
    O.Plan private _plan;
    O.Output[] private _rows;
    address public metadataRouter;
    address private immutable _firstProducer;
    address private immutable _secondProducer;

    constructor(address c, address firstProducer, address secondProducer) {
        core = c;
        metadataRouter = c;
        _firstProducer = firstProducer;
        _secondProducer = secondProducer;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return capability && id == type(O).interfaceId;
    }

    function entropySourceSet() external view returns (address) {
        return address(this);
    }

    function preservationOutputProfile() external pure returns (bytes32) {
        return keccak256("6529STREAM_PRESERVATION_RENDER_V1");
    }

    function seed(uint256 count, StreamFinalityScope calldata scope) external {
        delete _rows;
        bytes32 chain;
        StreamTokenContentLeaf[] memory leaves = new StreamTokenContentLeaf[](count);
        for (uint256 i; i < count; ++i) {
            leaves[i] = StreamTokenContentLeaf(
                i + 1,
                keccak256(abi.encode("preservation json", i)),
                keccak256(abi.encode("image", i)),
                keccak256(abi.encode("preservation html", i)),
                0,
                keccak256(abi.encode("original token data", i))
            );
            bool finalized = i % 2 == 1;
            address rowProducer = finalized ? _secondProducer : _firstProducer;
            O.Output memory row = O.Output(
                leaves[i],
                keccak256(abi.encode("selection", i)),
                keccak256(abi.encode("source", i)),
                leaves[i].animationHash,
                E.TokenReadiness(
                    address(this),
                    address(this).codehash,
                    keccak256(abi.encode("full policy", i)),
                    finalized ? 5 : 1,
                    0,
                    0,
                    1,
                    !finalized,
                    finalized,
                    finalized ? keccak256(abi.encode("original seed", i)) : bytes32(0)
                ),
                finalized ? bytes32(0) : keccak256(abi.encode("terminal admission", i)),
                P.Binding(
                    rowProducer,
                    rowProducer.codehash,
                    keccak256("6529STREAM_PRESERVATION_RENDER_V1"),
                    core,
                    metadataRouter,
                    rowProducer,
                    rowProducer.codehash,
                    rowProducer,
                    rowProducer.codehash
                ),
                P.Admission(
                    core,
                    core.codehash,
                    keccak256(abi.encode("version", i)),
                    keccak256(abi.encode("registration", i)),
                    keccak256(abi.encode("read set", i)),
                    keccak256(abi.encode("analysis", i)),
                    keccak256(abi.encode("golden", i))
                )
            );
            _rows.push(row);
            chain = keccak256(
                abi.encode(keccak256("6529STREAM_PRESERVATION_POLICY_OUTPUTS_V1"), chain, i, row)
            );
        }
        _plan = O.Plan(
            keccak256("selection"),
            keccak256("selected complete plan"),
            keccak256("complete inventory"),
            keccak256("full frozen policy chain"),
            scope,
            uint64(count),
            uint64(count),
            keccak256("leaf chain"),
            StreamTokenContentTree.root(block.chainid, core, leaves),
            chain,
            keccak256("6529STREAM_PRESERVATION_RENDER_V1")
        );
    }

    function setProfile(bytes32 profile) external {
        preservationPolicyProfile = profile;
    }

    function setCapability(bool value) external {
        capability = value;
    }

    function setValid(bool value) external {
        valid = value;
    }

    function setPlan(O.Plan calldata p) external {
        _plan = p;
    }

    function setRouter(address router) external {
        metadataRouter = router;
    }

    function setRow(uint256 index, O.Output calldata row) external {
        _rows[index] = row;
    }

    function requireCurrentCheckpoint(bytes32) external view returns (O.Plan memory) {
        require(valid, "checkpoint currentness boundary refused");
        return _plan;
    }

    function outputAt(bytes32, uint256 index) external view returns (O.Output memory) {
        return _rows[index];
    }
}
