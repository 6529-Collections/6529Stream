// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice The original signed op24 head chooses documentary evidence, not legal truth.
library StreamArtistPersonhoodTypes {
    enum Status {
        NONE,
        WAIVER,
        RESOLVED,
        STALE,
        UNRESOLVED
    }

    struct Reference {
        uint16 version;
        bytes32 profileHash;
        address artistRegistry;
        bytes32 artistId;
        bytes32 operativeIdentityRecordHash;
        address notarizationHost;
        bytes32 notarizationRuntimeHash;
        bytes32 notarizationRecordHash;
    }

    /// @dev Immutable result of full verification at original op24, or an exact authenticated import.
    /// Neither mutable payload bytes nor mutable report-head selection are cached here.
    struct Summary {
        uint16 version;
        uint256 chainId;
        bytes32 nativeRecordHash;
        bytes32 statementHash;
        bytes32 artistId;
        bytes32 bindingHash;
        uint64 generation;
        uint256 collectionId;
        bytes32 identityRecordHash;
        Reference evidenceReference;
        bytes32 originalRegistryCodeHash;
        address core;
        bytes32 coreCodeHash;
        address moduleRegistry;
        bytes32 moduleRegistryCodeHash;
        address schemaRegistry;
        bytes32 schemaRegistryCodeHash;
        address chunkStore;
        bytes32 chunkStoreCodeHash;
        bytes32[4] definitionFactsHashes;
        uint256 notarizationCollectionId;
        bytes32 attestationType;
        bytes32 subjectId;
        address recorder;
        bytes32 documentaryHash;
        bytes32 moduleIdentityHash;
        address[6] carriers;
        bytes32[6] carrierCodeHashes;
    }

    struct NotarizationFacts {
        bytes32 attestationType;
        address recorder;
        bytes32 head;
        bool current;
    }

    struct Selection {
        T.AttestationRecord nativeRecord;
        address sourceRegistry;
        Reference evidenceReference;
        bytes32 notarizationType;
        address recorder;
        bytes32 notarizationHead;
        bool identityCurrent;
        bool notarizationCurrent;
        Status status;
    }
    error InvalidPersonhoodReference();
    error PersonhoodDependencyChanged(address target);
    error PersonhoodReadFailed(address target);
    error PersonhoodParentGas(uint256 available, uint256 required);
}

/// @notice Fixed Attribution-owner reads. The existing op24 head is the only evidence selector.
interface IStreamArtistPersonhoodEvidence {
    function personhoodEvidence(uint256 collectionId, bytes32 artistId)
        external
        view
        returns (StreamArtistPersonhoodTypes.Selection memory);
    function personhoodEvidenceStatus(uint256 collectionId, bytes32 artistId)
        external
        view
        returns (bytes32 nativeRecordHash, StreamArtistPersonhoodTypes.Status);
    function personhoodProofSummary(bytes32 nativeRecordHash)
        external
        view
        returns (StreamArtistPersonhoodTypes.Summary memory);
    function personhoodProofSummaryHash(bytes32 nativeRecordHash) external view returns (bytes32);
    function auditPersonhoodEvidence(bytes32 nativeRecordHash)
        external
        view
        returns (bytes32 documentaryHash, StreamArtistPersonhoodTypes.NotarizationFacts memory);
}

/// @dev Self-only view frame permits explicit UNRESOLVED disclosure on a failed bounded read.
interface IStreamArtistPersonhoodReadFrame {
    function personhoodResolution(
        uint256 collectionId,
        bytes32 artistId,
        T.AttestationRecord calldata record,
        bool checkEvidence
    ) external view returns (bool, StreamArtistPersonhoodTypes.NotarizationFacts memory);
}
