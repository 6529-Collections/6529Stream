// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOwner } from "../../../smart-contracts/domains/artist/StreamArtistOwner.sol";
import {
    StreamArtistRecoveredHydrationState as State
} from "../../../smart-contracts/domains/artist/StreamArtistRecoveredHydrationState.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @dev Actual Owner read/guard and immutable prefix worker; producer/source graph is explicitly typed.
contract ImportedOriginCertificateProbe is StreamArtistOwner {
    bool private refuse;
    uint8 private immutable index;

    constructor(uint8 ownerIndex)
        StreamArtistOwner(
            address(0x111),
            msg.sender,
            address(0x222),
            RH.ownerDomain(ownerIndex),
            address(0x333),
            address(0x444)
        )
    {
        index = ownerIndex;
    }

    function setRefusal(bool value) external {
        require(msg.sender == operationCoordinator, "fixture coordinator");
        refuse = value;
    }

    function install(T.ActionContext calldata c, RH.OwnerProvenance calldata p, bytes32 commitment)
        external
    {
        _check(c, 60);
        State.installOwnerPrefix(p, index, commitment, c.expected.revision + 1);
        require(!refuse, "late fixture failure");
        _commit(c, keccak256("fixture import"), commitment, bytes32(0), bytes32(0));
    }

    function retained(bytes32 hash) external view returns (RH.OriginEnvironment memory) {
        return State.environment(hash);
    }
}

/// @notice Original prefix hashing, exact certificate bytes, absent/local refusal and atomic retry.
/// @dev No actual seven-owner op60/Safe/Archive execution is claimed by this focused owner probe.
contract StreamArtistImportedOriginCertificateTest {
    bytes32 private constant COMMITMENT = keccak256("original seven-owner import value");

    function _prefix(uint8 index) private pure returns (RH.OwnerProvenance memory p) {
        p.origins = new RH.OriginEnvironment[](1);
        RH.OriginEnvironment memory o;
        o.chainId = 1;
        o.registry = address(1);
        o.coordinator = address(2);
        o.archive = address(3);
        o.core = address(4);
        o.manager = address(5);
        o.suiteConfigurationHash = bytes32(uint256(6));
        for (uint8 i; i < 7; ++i) {
            o.owners[i] = address(uint160(100) + i);
            o.ownerCodeHashes[i] = bytes32(uint256(200) + i);
        }
        p.origins[0] = o;
        p.eras = new RH.OwnerEra[](1);
        p.eras[0].originHash = RH.originHash(o);
        p.eras[0].checkpoint.schema = RH.CHECKPOINT;
        p.eras[0].checkpoint.ownerState =
            T.Snapshot(RH.ownerDomain(index), 12, bytes32(uint256(300)), bytes32(uint256(301)));
    }

    function _call(ImportedOriginCertificateProbe owner, RH.OwnerProvenance memory p)
        private
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            owner.install,
            (T.ActionContext(60, address(this), owner.ownerStateSnapshotV2()), p, COMMITMENT)
        );
    }

    function _install(ImportedOriginCertificateProbe owner, RH.OwnerProvenance memory p) private {
        (bool ok, bytes memory why) = address(owner).call(_call(owner, p));
        if (!ok) assembly ("memory-safe") { revert(add(why, 32), mload(why)) }
    }

    function _refuse(ImportedOriginCertificateProbe owner, bytes32 hash) private view {
        (bool ok, bytes memory why) = address(owner)
            .staticcall(abi.encodeCall(owner.recoveredHydrationImportedOriginCertificate, (hash)));
        require(
            !ok
                && keccak256(why)
                    == keccak256(
                        abi.encodeWithSelector(RH.InvalidRecoveredHydrationProvenance.selector)
                    ),
            "exact missing/local refusal"
        );
    }

    function testExactCertificateAndFullOriginalEnvironmentWithoutCoordinatorRead() public {
        ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(2);
        RH.OwnerProvenance memory p = _prefix(2);
        bytes32 hash = p.eras[0].originHash;
        _install(owner, p);
        bytes32 before_ = keccak256(abi.encode(owner.authorityCheckpoint()));
        (bool ok, bytes memory raw) = address(owner)
            .staticcall(abi.encodeCall(owner.recoveredHydrationImportedOriginCertificate, (hash)));
        require(
            ok && raw.length == 128
                && keccak256(raw) == keccak256(abi.encode(hash, COMMITMENT, uint64(1), uint8(2))),
            "literal four words"
        );
        require(
            keccak256(abi.encode(owner.retained(hash))) == keccak256(abi.encode(p.origins[0])),
            "all original21 words retained"
        );
        require(
            keccak256(abi.encode(owner.authorityCheckpoint())) == before_, "read does not write"
        );
        // This test contract has no authorityHydrationSuite; compact read cannot rebuild current suite.
    }

    function testMissingZeroAndForeignOriginalNeverBecomeLocal() public {
        ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(2);
        RH.OwnerProvenance memory p = _prefix(2);
        _refuse(owner, p.eras[0].originHash);
        _install(owner, p);
        _refuse(owner, bytes32(0));
        _refuse(owner, keccak256("other original"));
    }

    function testAllSevenFixedOwnerIndicesRemainExact() public {
        for (uint8 i; i < 7; ++i) {
            ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(i);
            RH.OwnerProvenance memory p = _prefix(i);
            _install(owner, p);
            (bytes32 hash, bytes32 commitment, uint64 revision, uint8 index) =
                owner.recoveredHydrationImportedOriginCertificate(p.eras[0].originHash);
            require(
                hash == p.eras[0].originHash && commitment == COMMITMENT && revision == 1
                    && index == i,
                "original owner index"
            );
        }
    }

    function testInvalidOriginalKeyCannotInstallCertificate() public {
        ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(2);
        RH.OwnerProvenance memory p = _prefix(2);
        bytes32 hash = p.eras[0].originHash;
        p.origins[0].coordinator = address(9);
        (bool ok,) = address(owner).call(_call(owner, p));
        require(!ok, "original key mismatch admitted");
        _refuse(owner, hash);
        require(owner.ownerStateSnapshotV2().revision == 0, "no partial import");
        _install(owner, _prefix(2));
    }

    function testLocalOriginAndMalformedCallRemainUnavailable() public {
        ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(2);
        RH.OwnerProvenance memory p = _prefix(2);
        p.origins[0].registry = owner.artistRegistry();
        p.eras[0].originHash = RH.originHash(p.origins[0]);
        // Explicit injected fixture shape: real apply additionally forbids this source/destination equality.
        _install(owner, p);
        _refuse(owner, p.eras[0].originHash);
        (bool ok,) = address(owner)
            .staticcall(
                abi.encodePacked(
                    owner.recoveredHydrationImportedOriginCertificate.selector, bytes1(0)
                )
            );
        require(!ok, "short hash accepted");
    }

    function testLateRefusalRollsBackCertificateThenIdenticalCalldataRetry() public {
        ImportedOriginCertificateProbe owner = new ImportedOriginCertificateProbe(2);
        RH.OwnerProvenance memory p = _prefix(2);
        bytes memory exact = _call(owner, p);
        bytes32 before_ = keccak256(abi.encode(owner.authorityCheckpoint()));
        owner.setRefusal(true);
        (bool ok, bytes memory why) = address(owner).call(exact);
        require(
            !ok
                && keccak256(why)
                    == keccak256(abi.encodeWithSignature("Error(string)", "late fixture failure")),
            "reached late refusal"
        );
        require(keccak256(abi.encode(owner.authorityCheckpoint())) == before_, "owner rollback");
        _refuse(owner, p.eras[0].originHash);
        owner.setRefusal(false);
        (ok,) = address(owner).call(exact);
        require(ok, "identical retry");
        (bytes32 hash, bytes32 commitment,,) =
            owner.recoveredHydrationImportedOriginCertificate(p.eras[0].originHash);
        require(hash == p.eras[0].originHash && commitment == COMMITMENT, "retry certificate");
        (ok,) = address(owner).call(exact);
        require(!ok, "original snapshot replay");
    }
}
