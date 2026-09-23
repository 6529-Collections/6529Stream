// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../helpers/StreamCurrentSafeGovernanceFixture.sol";
import {
    StreamArtistBindingCorrectionAdmission as Admission
} from "../../smart-contracts/domains/artist/StreamArtistBindingCorrectionAdmission.sol";
import {
    StreamArtistBindingCorrectionTypes as BC,
    IStreamArtistBindingCorrection,
    IStreamArtistBindingCorrectionOwner
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistBindingCorrection.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

interface BindingCorrectionVm {
    function mockCallRevert(address, bytes calldata, bytes calldata) external;
    function clearMockedCalls() external;
    function expectCall(address, bytes calldata, uint64) external;
}

/// @notice Actual current Artist/Core/Manager/Archive, sealed Executor catalog and threshold Safe correction.
/// @dev Inherits the current fixture's external entropy provider boundary. No native/capacity acceptance is claimed by source.
contract StreamCurrentArtistBindingCorrectionTest is StreamCurrentSafeGovernanceFixture {
    OfficialSafe private principal;
    uint256[] private keys;
    BindingCorrectionVm private constant cvm =
        BindingCorrectionVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function setUp() public {
        keys.push(0xB1C01);
        keys.push(0xB1C02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        principal = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 901);
        OfficialSafe governor = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 902);
        _deployCurrentStack(address(principal), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, keys);
        _setRole(keccak256("ROLE_ATTRIBUTION_ARBITER"), address(governorSafe), true);
        _setRole(keccak256("ROLE_ARTIST_REGISTRY_ADMIN"), address(executor), true);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(principal, abi.encode(digest)));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = _correctionPolicy(1);
        rows[1] = _correctionPolicy(2);
    }

    function _correctionPolicy(uint8 cls)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            cls,
            address(artists),
            IStreamArtistBindingCorrection.proposeArtistBindingAfterRevocation.selector,
            address(artists).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(artists))),
            1,
            0,
            0,
            bytes32(0)
        );
    }

    function _binding() private view returns (T.Binding memory) {
        return IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
    }

    function _nonce() private view returns (uint256) {
        return IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
    }

    function _repudiate() private returns (bytes32 record) {
        T.Binding memory b = _binding();
        AD.Filing memory p =
            AD.Filing(1, b.generation, 4, 0, keccak256("current Artist voluntary exit"));
        require(
            executeSafe(
                principal,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistAttributionRepudiation.revokeAttribution,
                    (p, T.Authorization(_nonce(), 0, ""))
                ),
                0
            ),
            "actual original47 Safe"
        );
        (uint64 generation, uint64 at, bytes32 hash) = artists.pendingRepudiation(1);
        record = hash;
        require(generation == b.generation && record != 0, "original staged record");
        vm.warp(at);
        artists.executeAttributionRepudiation(1, record);
        require(
            artists.attributionRepudiationTerminal(record).phase == 4, "actual original50 terminal"
        );
    }

    function _terms() private view returns (T.BindingProposal memory p) {
        p.artistId = fixtureArtistId;
        p.artistAddress = address(principal);
        p.identityRecordHash = _binding().identityRecordHash;
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 1;
        p.saleConsentScope = 1;
        p.reasonHash = GOVERNANCE_REASON;
        p.reasonURI = "urn:binding:correction";
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
    }

    function _schedule(bytes32 repudiation, uint8 cls)
        private
        returns (bytes32 action, bytes memory data, uint64 ready)
    {
        T.BindingProposal memory p = _terms();
        (BC.Context memory c,) = Admission.context(
            artistSuite, 1, p, bytes("current-stack artist identity"), "Stream Artist", repudiation
        );
        data = abi.encodeCall(
            IStreamArtistBindingCorrection.proposeArtistBindingAfterRevocation,
            (uint256(1), p, bytes("current-stack artist identity"), "Stream Artist", repudiation)
        );
        GovernanceActionRequest memory r = _governanceRequest(
            cls, address(artists), data, c.scopeHash, c.oldValueHash, c.newValueHash
        );
        action = _scheduleAsGovernor(r);
        ready = r.notBefore;
    }

    function testActualClass2CorrectionPreservesOriginalCauseAndRequiresFreshSafeAcceptance()
        public
    {
        T.Binding memory previous = _binding();
        bytes32 repudiation = _repudiate();
        (bytes32 action, bytes memory data, uint64 ready) = _schedule(repudiation, 2);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        vm.warp(ready);
        _executeAsGovernor(action, data);
        T.Binding memory b = _binding();
        require(b.generation == 2 && !b.accepted, "governance does not accept");
        require(
            keccak256(abi.encode(IStreamArtistBindingOwner(artistSuite.owners[0]).bindingAt(1, 1)))
                == keccak256(abi.encode(previous)),
            "old accepted binding exact"
        );
        (BC.Approval memory a, bytes32 hash) = IStreamArtistBindingCorrectionOwner(
                artistSuite.owners[0]
            ).bindingCorrection(b.bindingHash);
        require(
            a.cause == 3 && a.causeRecord == repudiation && a.governance.actionId == action
                && a.governance.proposer == address(governorSafe),
            "actual staged authority and executed cause"
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_BINDING_CORRECTION_RECORD_V1"),
                        block.chainid,
                        address(artists),
                        address(core),
                        address(manager),
                        uint256(1),
                        b.bindingHash,
                        a
                    )
                ),
            "independent immutable full preimage"
        );
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            executeSafe(
                principal,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
                    (uint256(1), b.generation, b.bindingHash, T.Authorization(_nonce(), 0, ""))
                ),
                0
            ),
            "fresh original op2 actual Safe"
        );
        require(
            _binding().accepted && artists.attributionRepudiationTerminal(repudiation).phase == 4,
            "new acceptance never rewrites prior exit"
        );
    }

    function testOldExecutedRepudiationCannotAuthorizeLaterRevokedGeneration() public {
        bytes32 first = _repudiate();
        (bytes32 action, bytes memory data, uint64 ready) = _schedule(first, 2);
        vm.warp(ready);
        _executeAsGovernor(action, data);
        T.Binding memory b = _binding();
        require(
            executeSafe(
                principal,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    IStreamArtistBindingLifecycle.acceptArtistBindingExpected,
                    (uint256(1), b.generation, b.bindingHash, T.Authorization(_nonce(), 0, ""))
                ),
                0
            ),
            "actual next acceptance"
        );
        bytes32 second = _repudiate();
        require(second != first, "two original executed exits");
        T.BindingProposal memory p = _terms();
        vm.expectRevert(abi.encodeWithSelector(BC.InvalidBindingCorrection.selector, uint256(1)));
        Admission.context(
            artistSuite, 1, p, bytes("current-stack artist identity"), "Stream Artist", first
        );
        (BC.Context memory c, BC.Approval memory a) = Admission.context(
            artistSuite, 1, p, bytes("current-stack artist identity"), "Stream Artist", second
        );
        require(
            c.scopeHash != 0 && a.previous.generation == 2 && a.causeRecord == second,
            "only exact current-generation cause"
        );
    }

    function testActualClass1AndRevokedArbiterCannotAuthorizeCorrection() public {
        bytes32 record = _repudiate();
        (bytes32 action, bytes memory data, uint64 ready) = _schedule(record, 1);
        vm.warp(ready);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(_binding().generation == 1, "class1 preserves revoked generation");
        (action, data, ready) = _schedule(record, 2);
        _setRole(keccak256("ROLE_ATTRIBUTION_ARBITER"), address(governorSafe), false);
        if (block.timestamp < ready) vm.warp(ready);
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            _binding().generation == 1
                && executor.governanceAction(action).status == GovernanceActionStatus.SCHEDULED,
            "live proposer role refusal"
        );
    }

    function testLateArchiveFailureRollsBackCorrectionAndIdenticalGovernorSafeRetry() public {
        bytes32 record = _repudiate();
        (bytes32 action, bytes memory data, uint64 ready) = _schedule(record, 2);
        vm.warp(ready);
        bytes32 before_ = _roots();
        uint256 nonce = governorSafe.nonce();
        bytes memory append =
            abi.encodePacked(IStreamArtistArchiveV2.appendArtistEvidenceV2.selector);
        cvm.expectCall(artistSuite.archive, append, uint64(2));
        cvm.mockCallRevert(
            artistSuite.archive,
            append,
            abi.encodeWithSignature("Error(string)", "late correction archive")
        );
        vm.expectRevert();
        this.executeCurrentGovernorCall(
            address(executor), abi.encodeCall(executor.executeGovernanceAction, (action, data))
        );
        require(
            _roots() == before_ && governorSafe.nonce() == nonce && _binding().generation == 1,
            "owner replay/approval/action/Safe rollback"
        );
        cvm.clearMockedCalls();
        _executeAsGovernor(action, data);
        require(
            _binding().generation == 2 && governorSafe.nonce() == nonce + 1,
            "exact unchanged action and Safe argument retry"
        );
    }

    function _roots() private view returns (bytes32 h) {
        for (uint256 i; i < 7; ++i) {
            h = keccak256(
                abi.encode(h, IStreamArtistOwner(artistSuite.owners[i]).ownerStateSnapshotV2())
            );
        }
    }
}
