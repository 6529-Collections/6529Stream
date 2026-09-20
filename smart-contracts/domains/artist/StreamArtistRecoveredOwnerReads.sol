// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistRecoveredHydrationOwner as API
} from "../../interfaces/stream/artist/IStreamArtistRecoveredHydration.sol";
import {
    IStreamArtistImportedReceiptRead as ReceiptAPI
} from "../../interfaces/stream/artist/IStreamArtistImportedReceiptRead.sol";
import {
    IStreamArtistAuthorityHydrationCoordinator as Coordinator
} from "../../interfaces/stream/artist/IStreamArtistAuthorityHydration.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import { StreamArtistOwnerHydration as Original } from "./StreamArtistOwnerHydration.sol";
import {
    StreamArtistRecoveredHydrationState as Imported
} from "./StreamArtistRecoveredHydrationState.sol";

/// @notice Fixed typed reads over this owner's immutable imported prefix and actual replay cells.
library StreamArtistRecoveredOwnerReads {
    function ownerIndex(bytes32 domain) public pure returns (uint8) {
        for (uint8 i; i < 7; ++i) {
            if (RH.ownerDomain(i) == domain) return i;
        }
        revert RH.InvalidRecoveredHydrationProfile();
    }

    function read(
        mapping(bytes32 => T.ReplayCell) storage replay,
        Original.Binding memory binding,
        uint256 features,
        bytes calldata data
    ) public view returns (bytes memory) {
        uint8 index = ownerIndex(binding.domain);
        bytes4 selector = bytes4(data[:4]);
        if (selector == API.recoveredAuthorityHydrationCapability.selector) {
            if ((features & ~RH.KNOWN_FEATURES) != 0) revert RH.InvalidRecoveredHydrationProfile();
            return abi.encode(
                RH.Capability(
                    RH.PROFILE,
                    RH.VERSION,
                    index,
                    binding.domain,
                    RH.CHECKPOINT,
                    RH.ownerTag(index),
                    features
                )
            );
        }
        if (selector == API.recoveredHydrationImportedPrefix.selector) {
            return abi.encode(
                Imported.importedPrefix(), Imported.commitment(), Imported.importedAtRevision()
            );
        }
        if (selector == ReceiptAPI.recoveredHydrationImportedReceiptAt.selector) {
            uint256 receiptIndex = abi.decode(data[4:], (uint256));
            (RH.JournalEntry memory entry, bytes32 commitment, uint64 revision) =
                Imported.importedReceiptAt(receiptIndex, index, binding.registry);
            return abi.encode(entry, commitment, revision);
        }
        if (selector == API.recoveredHydrationAuxiliaryPoint.selector) {
            (bytes32 kind, bytes32 key) = abi.decode(data[4:], (bytes32, bytes32));
            return abi.encode(Imported.artifact(kind, key));
        }
        if (selector == API.recoveredHydrationImportedOriginCertificate.selector) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            (bytes32 origin, bytes32 commitment, uint64 revision, uint8 importedIndex) =
                Imported.originCertificateInline(hash, index, binding.registry);
            return abi.encode(origin, commitment, revision, importedIndex);
        }
        RH.OriginEnvironment memory current = environment(binding, index);
        bytes32 currentHash = RH.originHash(current);
        if (selector == API.recoveredHydrationOrigin.selector) {
            bytes32 hash = abi.decode(data[4:], (bytes32));
            return abi.encode(hash == currentHash ? current : Imported.environment(hash));
        }
        if (selector == API.recoveredHydrationReplayPoint.selector) {
            bytes32 key = abi.decode(data[4:], (bytes32));
            T.ReplayCell memory cell = replay[key];
            if (cell.status == 0) revert RH.InvalidRecoveredHydrationProvenance();
            return abi.encode(
                Imported.activeReplayPoint(
                    key, cell.touchedRevision, RH.Point(currentHash, index, cell.touchedRevision)
                )
            );
        }
        revert RH.InvalidRecoveredHydrationProfile();
    }

    /// @dev Only immutable constructor bindings and code identities are read across the suite.
    /// No other semantic owner's mutable state is read from an owner-local apply or getter.
    function environment(Original.Binding memory binding, uint8 index)
        public
        view
        returns (RH.OriginEnvironment memory result)
    {
        T.SuiteConfiguration memory suite =
            Coordinator(binding.coordinator).authorityHydrationSuite();
        if (
            suite.registry != binding.registry || suite.archive != binding.archive
                || suite.owners[index] != address(this) || binding.domain != RH.ownerDomain(index)
        ) revert RH.InvalidRecoveredHydrationProvenance();
        result.chainId = block.chainid;
        result.registry = suite.registry;
        result.coordinator = binding.coordinator;
        result.archive = suite.archive;
        result.owners = suite.owners;
        for (uint256 i; i < 7; ++i) {
            result.ownerCodeHashes[i] = suite.owners[i].codehash;
        }
        result.core = suite.core;
        result.manager = suite.mintManager;
        result.suiteConfigurationHash = keccak256(abi.encode(suite));
    }
}
