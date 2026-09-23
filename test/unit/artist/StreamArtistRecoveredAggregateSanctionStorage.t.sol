// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredAggregateSanctionStorage as Storage
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredAggregateSanctionStorage.sol";
import {
    StreamArtistRecoveredSanctionHistoryTypes as H
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredSanctionHistoryTypes.sol";
import {
    StreamArtistSanctionState as Sanctions
} from "../../../smart-contracts/domains/artist/StreamArtistSanctionState.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    IStreamArtistSanctionArchiveFacts as Facts
} from "../../../smart-contracts/interfaces/stream/finality/IStreamArtistSanctionArchiveFacts.sol";

/// @dev Synthetic typed storage boundary only; no Archive, authority, replay or op60 proof claim.
contract AggregateSanctionStorageHarness {
    uint256 private beforeState = 0x112233;
    Sanctions.State private state;
    uint256 private afterState = 0x445566;

    function install(H.Inventory memory x) external {
        Storage.install(state, x);
    }

    function row(bytes32 hash)
        external
        view
        returns (S.Record memory record, bytes memory archive, Facts.Facts memory facts)
    {
        return (state.records[hash], state.archives[hash], state.archiveFacts[hash]);
    }

    function latest(bytes32 key) external view returns (bytes32) {
        return state.latest[key];
    }

    function canaries() external view returns (uint256, uint256) {
        return (beforeState, afterState);
    }

    function seed(uint8 kind, bytes32 hash, bytes32 key) external {
        if (kind == 1) state.records[hash].signer = address(0xBEEF);
        else if (kind == 2) state.latest[key] = bytes32(uint256(0xCAFE));
        else if (kind == 3) state.archives[hash] = hex"001122";
        else if (kind == 4) state.archiveFacts[hash].schemaId = bytes32(uint256(0xFACE));
        else revert("seed kind");
    }

    function clear(uint8 kind, bytes32 hash, bytes32 key) external {
        if (kind == 1) delete state.records[hash];
        else if (kind == 2) delete state.latest[key];
        else if (kind == 3) delete state.archives[hash];
        else if (kind == 4) delete state.archiveFacts[hash];
        else revert("clear kind");
    }
}

/// @notice Original rows survive repeated heads; every preexisting typed root refuses atomically.
contract StreamArtistRecoveredAggregateSanctionStorageTest {
    function testOrderedAssociationHeadsRetainFullEarlierBytesAndDistinctScopes() external {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory x = _inventory(4);
        x.sanctions[1].record.artistId = x.sanctions[0].record.artistId;
        x.sanctions[1].archiveFacts.artistId = x.sanctions[0].record.artistId;
        x.sanctions[2].record.terms.scopeType = 1;
        x.sanctions[2].record.terms.tokenId = 42;
        x.sanctions[3].record.terms.scopeType = 4;
        x.sanctions[3].record.terms.scopeId = bytes32(uint256(91));
        host.install(x);
        for (uint256 i; i < x.sanctions.length; ++i) {
            _same(host, x.sanctions[i]);
        }
        require(_key(x.sanctions[0].record) == _key(x.sanctions[1].record), "shared association");
        require(
            host.latest(_key(x.sanctions[0].record)) == x.sanctions[1].record.recordHash,
            "last head"
        );
        require(
            host.latest(_key(x.sanctions[2].record)) == x.sanctions[2].record.recordHash,
            "token head"
        );
        require(
            host.latest(_key(x.sanctions[3].record)) == x.sanctions[3].record.recordHash,
            "view head"
        );
        _canaries(host);
    }

    function testHistoricalArtistAndCollectionKeepIndependentSameGenerationHeads() external {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory x = _inventory(3);
        // Original and replacement Artist retain distinct permanent associations in one collection.
        x.sanctions[1].record.artistId = bytes32(uint256(82));
        x.sanctions[1].archiveFacts.artistId = bytes32(uint256(82));
        x.sanctions[2].record.terms.collectionId = 102;
        host.install(x);
        for (uint256 i; i < x.sanctions.length; ++i) {
            _same(host, x.sanctions[i]);
            require(
                host.latest(_key(x.sanctions[i].record)) == x.sanctions[i].record.recordHash,
                "exact association"
            );
        }
        _canaries(host);
    }

    function testOccupiedPartialRecordRefusesWholeBatchThenSameInputRetries() external {
        _occupied(1);
    }

    function testOccupiedAssociationRefusesWholeBatchThenSameInputRetries() external {
        _occupied(2);
    }

    function testOccupiedArchiveRefusesWholeBatchThenSameInputRetries() external {
        _occupied(3);
    }

    function testOccupiedPartialFactsRefusesWholeBatchThenSameInputRetries() external {
        _occupied(4);
    }

    function testDuplicateRecordDoesNotInstallOrOverwriteEarlierRow() external {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory x = _inventory(2);
        x.sanctions[1] = abi.decode(abi.encode(x.sanctions[0]), (H.SanctionRow));
        bytes32 before_ = _observed(host, x);
        _reject(host, x);
        require(_observed(host, x) == before_, "duplicate atomicity");
        x = _inventory(2);
        host.install(x);
        _same(host, x.sanctions[0]);
        _same(host, x.sanctions[1]);
        _canaries(host);
    }

    function testDetachedArchiveFactsAndZeroIdentityRefuseThenExactValidInputRetries() external {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory original = _inventory(2);
        for (uint256 kind; kind < 12; ++kind) {
            H.Inventory memory x = abi.decode(abi.encode(original), (H.Inventory));
            if (kind == 0) {
                x.sanctions[1].record.recordHash = 0;
            } else if (kind == 1) {
                x.sanctions[1].record.artistId = 0;
            } else if (kind == 2) {
                x.sanctions[1].record.bindingGeneration = 0;
            } else if (kind == 3) {
                x.sanctions[1].record.bindingHash = 0;
            } else if (kind == 4) {
                x.sanctions[1].record.terms.collectionId = 0;
            } else if (kind == 5) {
                x.sanctions[1].archiveBytes = bytes("");
            } else if (kind == 6) {
                x.sanctions[1].archiveFacts.sanctionRecordHash = bytes32(uint256(19));
            } else if (kind == 7) {
                x.sanctions[1].archiveFacts.artistId = bytes32(uint256(19));
            } else if (kind == 8) {
                x.sanctions[1].archiveFacts.schemaId = bytes32(uint256(19));
            } else if (kind == 9) {
                x.sanctions[1].archiveFacts.canonicalizationId = bytes32(uint256(19));
            } else if (kind == 10) {
                x.sanctions[1].archiveFacts.contentHash = bytes32(uint256(19));
            } else {
                x.sanctions[1].archiveFacts.byteLength += 1;
            }
            bytes32 before_ = _observed(host, original);
            _reject(host, x);
            require(_observed(host, original) == before_, "malformed row atomicity");
        }
        host.install(original);
        _same(host, original.sanctions[0]);
        _same(host, original.sanctions[1]);
        _canaries(host);
    }

    function testReplayCannotOverwriteOriginalInstalledEvidence() external {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory x = _inventory(2);
        host.install(x);
        bytes32 before_ = _observed(host, x);
        _reject(host, x);
        require(_observed(host, x) == before_, "installed evidence unchanged");
        _canaries(host);
    }

    function _occupied(uint8 kind) private {
        AggregateSanctionStorageHarness host = new AggregateSanctionStorageHarness();
        H.Inventory memory x = _inventory(2);
        // Keep distinct heads so an occupied final row cannot accidentally test only the first row.
        x.sanctions[1].record.terms.collectionId = 102;
        bytes32 hash = x.sanctions[1].record.recordHash;
        bytes32 key = _key(x.sanctions[1].record);
        host.seed(kind, hash, key);
        bytes32 before_ = _observed(host, x);
        _reject(host, x);
        require(_observed(host, x) == before_, "all maps unchanged");
        host.clear(kind, hash, key);
        host.install(x);
        _same(host, x.sanctions[0]);
        _same(host, x.sanctions[1]);
        _canaries(host);
    }

    function _reject(AggregateSanctionStorageHarness host, H.Inventory memory x) private {
        (bool ok, bytes memory reason) =
            address(host).call(abi.encodeWithSelector(host.install.selector, x));
        require(!ok, "must refuse");
        require(
            keccak256(reason)
                == keccak256(abi.encodeWithSelector(RH.InvalidRecoveredHydrationProfile.selector)),
            "exact refusal"
        );
    }

    function _same(AggregateSanctionStorageHarness host, H.SanctionRow memory expected)
        private
        view
    {
        (S.Record memory r, bytes memory archive, Facts.Facts memory facts) =
            host.row(expected.record.recordHash);
        require(
            keccak256(abi.encode(r)) == keccak256(abi.encode(expected.record)),
            "full original record"
        );
        require(
            keccak256(archive) == keccak256(expected.archiveBytes), "full original archive bytes"
        );
        require(
            keccak256(abi.encode(facts)) == keccak256(abi.encode(expected.archiveFacts)),
            "full original facts"
        );
    }

    function _observed(AggregateSanctionStorageHarness host, H.Inventory memory x)
        private
        view
        returns (bytes32 h)
    {
        for (uint256 i; i < x.sanctions.length; ++i) {
            (S.Record memory r, bytes memory archive, Facts.Facts memory facts) =
                host.row(x.sanctions[i].record.recordHash);
            h = keccak256(
                abi.encode(h, r, archive, facts, host.latest(_key(x.sanctions[i].record)))
            );
        }
    }

    function _key(S.Record memory r) private pure returns (bytes32) {
        // Independent original association preimage, rather than calling the production helper.
        return keccak256(
            abi.encode(
                r.artistId,
                r.bindingGeneration,
                r.bindingHash,
                r.terms.scopeType,
                r.terms.collectionId,
                r.terms.tokenId,
                r.terms.scopeId
            )
        );
    }

    function _canaries(AggregateSanctionStorageHarness host) private view {
        (uint256 a, uint256 b) = host.canaries();
        require(a == 0x112233 && b == 0x445566, "typed state boundaries");
    }

    function _inventory(uint256 count) private pure returns (H.Inventory memory x) {
        x.sanctions = new H.SanctionRow[](count);
        for (uint256 i; i < count; ++i) {
            S.Record memory r;
            r.recordHash = keccak256(abi.encode("synthetic original record", i));
            r.artistId = bytes32(uint256(81));
            r.signer = address(0x1234);
            r.authorityClass = 1;
            r.terms = S.Terms(0, 101, 0, 0, bytes32(uint256(301)), bytes32(uint256(401 + i)));
            r.nonce = 500 + i;
            r.signedAt = uint64(600 + i);
            r.deadline = 700;
            r.bindingGeneration = 1;
            r.bindingHash = bytes32(uint256(801));
            r.digest = bytes32(uint256(901 + i));
            bytes memory archive = abi.encode("synthetic retained original bytes", i, hex"001100ff");
            x.sanctions[i].record = r;
            x.sanctions[i].archiveBytes = archive;
            x.sanctions[i].archiveFacts = Facts.Facts(
                r.recordHash,
                r.artistId,
                keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_V1"),
                keccak256("6529STREAM_ARTIST_SANCTION_ARCHIVE_ABI_V1"),
                keccak256(archive),
                uint64(archive.length)
            );
        }
    }
}
