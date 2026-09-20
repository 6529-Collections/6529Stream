// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationProvenance as Provenance
} from "./StreamArtistRecoveredHydrationProvenance.sol";

/// @notice Owner-local immutable import prefix and precise origins for retained historical facts.
/// @dev A separate namespace; original owner fields, native rows, counters and roots are untouched.
/// Fixed import workers call these methods only after their original operation60 caller/snapshot
/// check and complete source authentication. This storage is not an alternative authorization API.
library StreamArtistRecoveredHydrationState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_RECOVERED_HYDRATION_STATE_V1");

    struct State {
        bytes32 commitment;
        bytes32 profile;
        RH.OriginEnvironment[] origins;
        RH.OwnerEra[] eras;
        mapping(bytes32 => uint256) originIndexPlusOne;
        RH.JournalEntry[] journal;
        RH.ReplayAlias[] aliases;
        mapping(bytes32 => uint256) aliasIndexPlusOne;
        mapping(bytes32 => RH.Point) artifacts;
        mapping(bytes32 => RH.Point) activeReplayPoints;
        uint64 importedAtRevision;
        uint8 ownerIndex;
    }

    function _state() private pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function commitment() public view returns (bytes32) {
        return _state().commitment;
    }

    function importedAtRevision() public view returns (uint64) {
        return _state().importedAtRevision;
    }

    /// @dev Stores only this owner's slice. The Coordinator authenticates the joined seven-owner
    /// certificate; no owner reads another owner's mutable state or duplicates its journal.
    function installPrefix(
        RH.Provenance memory p,
        uint8 ownerIndex,
        bytes32 importCommitment,
        uint64 localImportRevision
    ) public {
        Provenance.validate(p);
        installOwnerPrefix(
            RH.ownerProvenance(p, ownerIndex), ownerIndex, importCommitment, localImportRevision
        );
    }

    /// @dev The destination receives only its authenticated slice, not seven copies of the
    /// global certificate. Validation here is structural and performs no source-owner calls.
    function installOwnerPrefix(
        RH.OwnerProvenance memory p,
        uint8 ownerIndex,
        bytes32 importCommitment,
        uint64 localImportRevision
    ) public {
        State storage s = _state();
        if (
            importCommitment == 0 || localImportRevision == 0 || s.commitment != 0
                || ownerIndex >= 7 || s.origins.length != 0 || s.eras.length != 0
                || s.journal.length != 0 || s.aliases.length != 0
        ) revert RH.InvalidRecoveredHydrationProvenance();
        Provenance.validateOwner(p, ownerIndex);
        s.commitment = importCommitment;
        s.profile = RH.PROFILE;
        s.importedAtRevision = localImportRevision;
        s.ownerIndex = ownerIndex;
        for (uint256 i; i < p.origins.length; ++i) {
            RH.OwnerEra memory era = p.eras[i];
            s.origins.push(p.origins[i]);
            s.eras.push(era);
            s.originIndexPlusOne[era.originHash] = i + 1;
        }
        for (uint256 i; i < p.journal.length; ++i) {
            s.journal.push(p.journal[i]);
        }
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory alias_ = p.aliases[i];
            s.aliases.push(alias_);
            s.aliasIndexPlusOne[alias_.originalKey] = i + 1;
        }
    }

    function importedPrefix() public view returns (RH.OwnerProvenance memory p) {
        State storage s = _state();
        p.origins = s.origins;
        p.eras = s.eras;
        p.journal = s.journal;
        p.aliases = s.aliases;
    }

    /// @notice Compact read of a key installed only by the unchanged validated op60 producer.
    /// @dev Full original environment bytes remain available through environment(). No cache/write.
    function originCertificate(bytes32 hash, uint8 ownerIndex, address currentRegistry)
        public view returns (bytes32, bytes32, uint64, uint8)
    {
        return originCertificateInline(hash, ownerIndex, currentRegistry);
    }

    /// @dev Same immutable namespace/checks in a caller's existing fixed read frame.
    /// Retains the public method above while avoiding a second cold delegatecall for Owner reads.
    function originCertificateInline(bytes32 hash, uint8 ownerIndex, address currentRegistry)
        internal view returns (bytes32, bytes32, uint64, uint8)
    {
        State storage s = _state();
        uint256 plus = s.originIndexPlusOne[hash];
        if (
            hash == 0 || s.commitment == 0 || s.profile != RH.PROFILE
                || s.importedAtRevision == 0 || ownerIndex >= 7 || s.ownerIndex != ownerIndex
                || plus == 0 || plus > s.origins.length || plus > s.eras.length
                || s.eras[plus - 1].originHash != hash
                || s.origins[plus - 1].registry == currentRegistry
        ) revert RH.InvalidRecoveredHydrationProvenance();
        return (hash, s.commitment, s.importedAtRevision, s.ownerIndex);
    }

    function environment(bytes32 originHash) public view returns (RH.OriginEnvironment memory) {
        State storage s = _state();
        uint256 plus = s.originIndexPlusOne[originHash];
        if (plus == 0) revert RH.InvalidRecoveredHydrationProvenance();
        return s.origins[plus - 1];
    }

    function historicalAlias(bytes32 originalKey) public view returns (RH.ReplayAlias memory) {
        State storage s = _state();
        uint256 plus = s.aliasIndexPlusOne[originalKey];
        if (plus == 0) revert RH.InvalidRecoveredHydrationProvenance();
        return s.aliases[plus - 1];
    }

    /// @dev Called for every authenticated imported native/auxiliary semantic artifact. Kind
    /// separates original records, executions, preparations, continuations and occurrence scopes.
    function installArtifact(bytes32 kind, bytes32 key, RH.Point memory point) public {
        State storage s = _state();
        _importedPoint(s, point);
        if (kind == 0 || key == 0) revert RH.InvalidRecoveredHydrationProvenance();
        bytes32 id = keccak256(abi.encode(kind, key));
        RH.Point storage old = s.artifacts[id];
        if (old.environmentHash != 0 && keccak256(abi.encode(old)) != keccak256(abi.encode(point))) revert RH.InvalidRecoveredHydrationProvenance();
        s.artifacts[id] = point;
    }

    /// @notice Missing imported metadata is an error, never an implicit current-domain artifact.
    function artifact(bytes32 kind, bytes32 key) public view returns (RH.Point memory point) {
        point = _state().artifacts[keccak256(abi.encode(kind, key))];
        if (kind == 0 || key == 0 || point.environmentHash == 0) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }

    /// @dev Only a fixed typed owner adapter may supply actualRevision, after reading the
    /// matching producer record from its own state. A caller accepting a returned current point
    /// must also prove a local native occurrence or the original current-domain producer hash.
    /// A retained raw revision alone is not proof of local production, even above the boundary.
    function artifactPoint(
        bytes32 kind,
        bytes32 key,
        uint64 actualRevision,
        RH.Point memory current
    ) public view returns (RH.Point memory point) {
        State storage s = _state();
        if (
            kind == 0 || key == 0 || actualRevision == 0 || current.environmentHash == 0
                || current.ownerIndex >= 7 || current.ownerRevision != actualRevision
                || (s.commitment != 0 && current.ownerIndex != s.ownerIndex)
        ) revert RH.InvalidRecoveredHydrationProvenance();
        point = s.artifacts[keccak256(abi.encode(kind, key))];
        if (point.environmentHash != 0) {
            if (point.ownerIndex != current.ownerIndex || point.ownerRevision != actualRevision) {
                revert RH.InvalidRecoveredHydrationProvenance();
            }
            return point;
        }
        if (s.commitment != 0 && actualRevision <= s.importedAtRevision) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        return current;
    }

    /// @dev Install after the ordinary guard worker's checkpoint notes. One-way cutover latches
    /// remain historical and are never installed as destination active guards by that worker.
    function installActiveReplayPoint(bytes32 currentKey, bytes32 sourceKey) public {
        State storage s = _state();
        uint256 plus = s.aliasIndexPlusOne[sourceKey];
        if (
            s.commitment == 0 || currentKey == 0 || plus == 0
                || s.activeReplayPoints[currentKey].environmentHash != 0
        ) revert RH.InvalidRecoveredHydrationProvenance();
        s.activeReplayPoints[currentKey] = s.aliases[plus - 1].admittedAt;
    }

    /// @dev The actual original Checkpoint.noteReplay hook invokes this for a real current write.
    /// Its cell now carries a local mutation revision, so an old imported point must not survive.
    function noteLocalReplay(bytes32 key) public {
        if (key == 0) revert RH.InvalidRecoveredHydrationProvenance();
        delete _state().activeReplayPoints[key];
    }

    /// @dev The fixed owner must supply its actual nonempty replay cell and current environment.
    /// An absent historical override means that actual cell was produced in this owner, not that
    /// arbitrary missing keys or supplied revisions establish admission.
    function activeReplayPoint(bytes32 key, uint64 actualRevision, RH.Point memory current)
        public
        view
        returns (RH.Point memory point)
    {
        if (
            key == 0 || actualRevision == 0 || current.environmentHash == 0
                || current.ownerIndex >= 7 || current.ownerRevision != actualRevision
        ) revert RH.InvalidRecoveredHydrationProvenance();
        point = _state().activeReplayPoints[key];
        if (point.environmentHash == 0) return current;
        if (point.ownerIndex != current.ownerIndex || point.ownerRevision != actualRevision) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }

    function _importedPoint(State storage s, RH.Point memory point) private view {
        uint256 plus = s.originIndexPlusOne[point.environmentHash];
        if (s.commitment == 0 || plus == 0 || point.ownerIndex != s.ownerIndex) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
        RH.OwnerEra storage era = s.eras[plus - 1];
        // Original local55/56 guards precede this owner's operation60. They are legitimate
        // auxiliary points; the import boundary is a lower bound only for native suffix rows.
        if (point.ownerRevision == 0 || point.ownerRevision > era.checkpoint.ownerState.revision) {
            revert RH.InvalidRecoveredHydrationProvenance();
        }
    }
}
