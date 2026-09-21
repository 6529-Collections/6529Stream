// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityScope
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamRenderCriticalSourceTypes as RetrievalInventoryTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamViewRetrievalWitnessTypesV1 as RetrievalWitnessTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamViewRetrievalWitnessTypesV1.sol";
import {
    StreamViewPreservationSnapshotTypesV1 as RetrievalSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamViewPreservationSnapshotTypesV1.sol";
import {
    StreamViewPreservationCheckpointTypesV1 as RetrievalCheckpointTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    IStreamViewRetrievalWitnessV1 as RetrievalWitnessInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamViewRetrievalWitnessV1.sol";
import {
    IStreamViewRetrievalInventoryBindingV1 as RetrievalCompanionInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamViewRetrievalInventoryBindingV1.sol";
import {
    IStreamViewPreservationContentCheckpointV1 as RetrievalCheckpointInterface
} from "../../smart-contracts/interfaces/stream/finality/IStreamViewPreservationContentCheckpointV1.sol";
import {
    IStreamExternalArtifactCoverage as RetrievalArchiveInterface
} from "../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCoverage.sol";

/// @dev Constructor configuration only. No publication/current correspondence selector is accepted.
contract ViewRetrievalConfigurationBoundary {
    mapping(bytes32 => bytes) private responses;

    function set(bytes memory input, bytes memory output) external {
        responses[keccak256(input)] = output;
    }

    function revocationEpoch(StreamFinalityScope calldata) external pure returns (uint64) {
        return 0;
    }

    fallback() external {
        bytes memory out = responses[keccak256(msg.data)];
        require(out.length != 0, "unconfigured retrieval evidence");
        assembly ("memory-safe") { return(add(out, 32), mload(out)) }
    }
}

library ViewRetrievalConfigurationFixture {
    function set(address a, bytes memory input, bytes memory out) internal {
        ViewRetrievalConfigurationBoundary(a).set(input, out);
    }

    function support(address a, bytes4 id) internal {
        set(a, abi.encodeWithSignature("supportsInterface(bytes4)", id), abi.encode(true));
    }

    function configure(RetrievalInventoryTypes.Dependencies memory d, bool typedArchive)
        internal
        returns (address witness)
    {
        address cp = address(new ViewRetrievalConfigurationBoundary());
        witness = address(new ViewRetrievalConfigurationBoundary());
        RetrievalWitnessTypes.Configuration memory c = RetrievalWitnessTypes.Configuration(
            d.targets[0],
            d.codeHashes[0],
            d.targets[4],
            d.codeHashes[4],
            cp,
            cp.codehash,
            d.targets[11],
            d.codeHashes[11],
            d.chainId,
            50000,
            2000000,
            2000000,
            400000
        );
        set(witness, abi.encodeCall(RetrievalWitnessInterface.configuration, ()), abi.encode(c));
        set(
            witness,
            abi.encodeCall(RetrievalWitnessInterface.configurationHash, ()),
            abi.encode(keccak256(abi.encode(RetrievalWitnessTypes.PROFILE, c)))
        );
        set(
            witness,
            abi.encodeCall(RetrievalWitnessInterface.retrievalProfile, ()),
            abi.encode(RetrievalWitnessTypes.PROFILE)
        );
        support(witness, type(RetrievalWitnessInterface).interfaceId);
        RetrievalSnapshotTypes.Dependencies memory snap;
        snap.targets[0] = d.targets[0];
        snap.codeHashes[0] = d.codeHashes[0];
        snap.targets[4] = d.targets[4];
        snap.codeHashes[4] = d.codeHashes[4];
        snap.targets[6] = cp;
        snap.codeHashes[6] = cp.codehash;
        snap.chainId = d.chainId;
        set(d.targets[5], abi.encodeWithSignature("dependencies()"), abi.encode(snap));
        RetrievalCheckpointTypes.Configuration memory cc;
        cc.core = c.core;
        cc.coreCodeHash = c.coreCodeHash;
        cc.router = c.router;
        cc.routerCodeHash = c.routerCodeHash;
        cc.chainId = c.chainId;
        set(cp, abi.encodeCall(RetrievalCheckpointInterface.configuration, ()), abi.encode(cc));
        set(
            cp,
            abi.encodeCall(RetrievalCheckpointInterface.checkpointProfile, ()),
            abi.encode(RetrievalCheckpointTypes.PROFILE)
        );
        support(cp, type(RetrievalCheckpointInterface).interfaceId);
        set(c.router, abi.encodeWithSignature("core()"), abi.encode(c.core));
        if (typedArchive) {
            set(c.archive, abi.encodeCall(RetrievalArchiveInterface.core, ()), abi.encode(c.core));
            set(
                c.archive,
                abi.encodeCall(RetrievalArchiveInterface.profileHash, ()),
                abi.encode(keccak256("STREAM_EXTERNAL_ARTIFACT_COVERAGE_V1"))
            );
            support(c.archive, type(RetrievalArchiveInterface).interfaceId);
        }
    }

    function bind(address inventory, address witness) internal {
        support(inventory, type(RetrievalCompanionInterface).interfaceId);
        set(
            inventory,
            abi.encodeCall(RetrievalCompanionInterface.retrievalWitnessBinding, ()),
            abi.encode(witness, witness.codehash)
        );
    }
}
