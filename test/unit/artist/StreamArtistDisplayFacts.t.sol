// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEstateStandingHistoryActual.t.sol";
import "../../../smart-contracts/domains/artist/StreamArtistHashes.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionOwner.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamArtistSanctionTypes as S
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionTypes.sol";
import {
    StreamArtistSanctionRequestTypes as Q
} from "../../../smart-contracts/interfaces/stream/artist/StreamArtistSanctionRequestTypes.sol";

/// @notice Actual Artist/Safe attestation authority and fixed-owner display reads.
/// @dev Typed unit Core/governance; injected old/disputed state is explicitly a read-boundary control.
contract StreamArtistDisplayFactsTest is StreamArtistEstateStandingHistoryActualTest {
    function _displayFacts(uint256 id) private view returns (bytes32) {
        return StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            id,
            ingress.displayBinding(id)
        );
    }

    function _displayStatus(uint256 id, bytes32 current)
        private
        view
        returns (uint8, bytes32, bytes32, uint8, uint64)
    {
        return ingress.artistAttestationStatus(
            id, 9, bytes32(uint256(uint160(address(core)))), current
        );
    }

    function displayAttestDeployment() external onlySelf {
        _attest(
            9,
            bytes32(uint256(uint160(address(core)))),
            _displayFacts(1),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
    }

    function testDisplayClaimedBindingAndExactCurrentStaleAttestation() public {
        T.Binding memory b = ingress.displayBinding(1);
        require(
            !b.accepted && b.generation != 0 && b.consentMode == 1,
            "raw claimed policy is visible without calling acceptedBinding or inventing a mode"
        );
        (uint8 absent, bytes32 noRecord, bytes32 noHash, uint8 noClass, uint64 noTime) =
            _displayStatus(1, bytes32(uint256(17)));
        require(
            absent == 0 && noRecord == 0 && noHash == 0 && noClass == 0 && noTime == 0,
            "exact absent tuple"
        );
        _accept();
        this.displayAttestDeployment();
        bytes32 facts = _displayFacts(1);
        (uint8 current, bytes32 record, bytes32 saved, uint8 class_, uint64 at) =
            _displayStatus(1, facts);
        require(
            current == 1 && record != 0 && saved == facts && class_ == 1 && at != 0,
            "actual signature producer persisted original class1 and exact state"
        );
        (bytes32 deploymentRecord, uint8 referenceClass, uint64 referenceTime) =
            ingress.deploymentAttestation(1);
        require(
            deploymentRecord == record && referenceClass == class_ && referenceTime == at,
            "historical deployment projection"
        );
        (uint8 stale, bytes32 old, bytes32 oldHash, uint8 oldClass, uint64 oldTime) =
            _displayStatus(1, bytes32(uint256(facts) ^ 1));
        require(
            stale == 2 && old == record && oldHash == saved && oldClass == class_ && oldTime == at,
            "caller-provided changed live hash cannot relabel historical approval"
        );
        require(
            ingress.attestationAuthorityClass(record) == 1
                && ingress.attestationAuthorityClass(keccak256("absent")) == 0,
            "historical authority is explicit and absent is never guessed"
        );
    }

    function testDisplayActualEstateClassAndOriginalLivingHistoryRemainDistinct() public {
        _accept();
        this.displayAttestDeployment();
        this.historySetup(0, 1, false);
        (bytes32 old, uint8 oldClass,) = ingress.deploymentAttestation(1);
        require(
            old != 0 && oldClass == 1
                && ingress.currentAuthorityCapabilities(artistId).authorityClass == 3,
            "old living attestation is not rewritten by actual estate activation"
        );
        this.displayAttestDeployment();
        (uint8 status, bytes32 current,, uint8 class_,) = _displayStatus(1, _displayFacts(1));
        require(
            status == 1 && current != old && class_ == 3
                && ingress.attestationAuthorityClass(old) == 1
                && ingress.attestationAuthorityClass(current) == 3,
            "actual cap-authorized estate signature retains class3 while old class1 record stays immutable"
        );
    }

    function testDisplaySanctionUsesActualCurrentAssociationAndSavedSigningClass() public {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        require(ingress.displaySanction(scope).recordHash == 0, "claimed binding has no sanction");
        _accept();
        (Q.Request memory q,) = _sanctionPrepared();
        bytes32 record = ingress.recordArtistSanction(q, _sanctionAuthorization(q));
        S.Record memory saved = ingress.sanctionRecord(record);
        require(
            keccak256(abi.encode(ingress.displaySanction(scope))) == keccak256(abi.encode(saved))
                && saved.authorityClass == 1,
            "complete actual saved current sanction, no class inference"
        );
        scope.tokenId = 41;
        scope.scopeType = StreamFinalityScopeType.TOKEN;
        require(
            ingress.displaySanction(scope).recordHash == 0,
            "exact scope getter does not invent a token-specific association"
        );
        scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        this.historySetup(0, 0, false);
        require(
            keccak256(abi.encode(ingress.displaySanction(scope))) == keccak256(abi.encode(saved)),
            "current binding retains original living signature after estate succession"
        );
    }

    function _displaySlot(bytes32 value, bytes32[] memory slots)
        private
        view
        returns (bytes32 slot)
    {
        uint256 n;
        for (uint256 i; i < slots.length; ++i) {
            if (vm.load(suite.owners[4], slots[i]) == value) {
                slot = slots[i];
                ++n;
            }
        }
        require(n == 1, "unique observed owner slot, no guessed layout");
    }

    function testDisplayUnknownHistoricalClassAndDisputedReadBoundary() public {
        _accept();
        this.displayAttestDeployment();
        (bytes32 record,,) = ingress.deploymentAttestation(1);
        ClosedEstateStorageVm probe = ClosedEstateStorageVm(address(vm));
        probe.record();
        ingress.attestationAuthorityClass(record);
        (bytes32[] memory slots,) = probe.accesses(suite.owners[4]);
        bytes32 classSlot = _displaySlot(bytes32(uint256(1)), slots);
        vm.store(suite.owners[4], classSlot, 0);
        (uint8 status, bytes32 saved,, uint8 class_,) = _displayStatus(1, _displayFacts(1));
        require(
            status == 1 && saved == record && class_ == 0,
            "labelled legacy sidecar absence exposes unknown class rather than inferred Artist"
        );
        vm.store(suite.owners[4], classSlot, bytes32(uint256(1)));
        probe.record();
        (uint8 state, uint64 generation) =
            IStreamArtistAttributionOwner(suite.owners[4]).attributionState(1);
        (slots,) = probe.accesses(suite.owners[4]);
        bytes32 packed = bytes32(uint256(state) | uint256(generation) << 8);
        bytes32 attrSlot = _displaySlot(packed, slots);
        vm.store(suite.owners[4], attrSlot, bytes32(uint256(4) | uint256(generation) << 8));
        (status, saved,, class_,) = _displayStatus(1, _displayFacts(1));
        require(
            status == 3 && saved == record && class_ == 1,
            "typed stored-dispute read, not executed arbitration"
        );
        vm.store(suite.owners[4], attrSlot, bytes32(uint256(5) | uint256(generation) << 8));
        (status,,,,) = _displayStatus(1, _displayFacts(1));
        require(status == 2, "revoked binding cannot remain currently attested");
        vm.store(suite.owners[4], attrSlot, packed);
        (status,,,,) = _displayStatus(1, _displayFacts(1));
        require(status == 1, "exact original state restored");
    }

    function testDisplayAttestationClassArchiveRollbackAndIdenticalSignedRetry() public {
        _accept();
        bytes memory statement = bytes("original deployment statement");
        T.Attestation memory p = T.Attestation(
            1,
            9,
            bytes32(uint256(uint160(address(core)))),
            _displayFacts(1),
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1"),
            keccak256(statement),
            "urn:display:retry"
        );
        T.Authorization memory a = _authorization(true);
        a.signature = _signature(ingress.attestationDigest(p, a));
        bytes32 expected = StreamArtistHashes.attestationRecordForAuthority(
            StreamArtistHashes.Environment(
                block.chainid, address(ingress), suite.core, suite.mintManager
            ),
            p,
            artistId,
            address(artist),
            1,
            a.nonce,
            a.time
        );
        bytes32 roots = _roots();
        uint256 oldBlock = block.number;
        vm.roll(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "ArtistArchiveBlockNumberOverflow(uint256)", uint256(type(uint64).max) + 1
            )
        );
        ingress.recordArtistAttestation(p, a, statement);
        require(
            _roots() == roots && ingress.attestationAuthorityClass(expected) == 0,
            "new class sidecar and authority nonce roll back with the actual late Archive failure"
        );
        vm.roll(oldBlock);
        ingress.recordArtistAttestation(p, a, statement);
        (bytes32 saved, uint8 class_,) = ingress.deploymentAttestation(1);
        require(saved == expected && class_ == 1, "same original signed bytes succeed after repair");
    }
}
