// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentEstateArchivalFixture.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistSuccessionTypes as Succ
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistSuccessionTypes.sol";

/// @notice Estate activation through actual Core, artist owners, Archive, coverage and threshold Safes.
contract StreamCurrentEstateActivationTest is StreamCurrentEstateArchivalFixture {
    OfficialSafe private livingSafe;
    OfficialSafe private successorSafe;
    uint256[] private livingKeys;
    uint256[] private successorKeys;
    Estate.Request private request;

    function setUp() public {
        livingKeys.push(0xE5101);
        livingKeys.push(0xE5102);
        successorKeys.push(0xE5201);
        successorKeys.push(0xE5203);
        uint256[] memory successorOwners = new uint256[](3);
        successorOwners[0] = 0xE5201;
        successorOwners[1] = 0xE5202;
        successorOwners[2] = 0xE5203;
        SafeComponents memory components = deploySafeComponents("1.4.1");
        livingSafe = createOfficialSafe(components, safeOwnerAddresses(livingKeys), 2, 0xE51);
        successorSafe =
            createOfficialSafe(components, safeOwnerAddresses(successorOwners), 2, 0xE52);
        uint256[] memory governorSigners = new uint256[](2);
        governorSigners[0] = 0xE5301;
        governorSigners[1] = 0xE5302;
        OfficialSafe governor =
            createOfficialSafe(components, safeOwnerAddresses(governorSigners), 2, 0xE53);
        _deployCurrentStack(address(livingSafe), vm.addr(PLATFORM_KEY));
        _installGovernorSafe(governor, governorSigners);
        uint256 nonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        Succ.Designation memory designation = Succ.Designation(
            fixtureArtistId,
            address(successorSafe),
            2,
            0,
            keccak256("current estate conditions"),
            bytes32(0)
        );
        this.executeEstateSafe(
            livingSafe,
            livingKeys,
            abi.encodeCall(
                artists.recordSuccessorDesignation, (designation, T.Authorization(nonce, 0, ""))
            )
        );
        (bytes32 evidence, bytes32 coverage) = _estateArchiveEvidence(fixtureArtistId);
        request = Estate.Request(
            fixtureArtistId,
            address(successorSafe),
            evidence,
            artists.operativeSuccessorRecord(fixtureArtistId),
            coverage
        );
        require(artistArchivalCoverage.roleRegistry() == address(roles), "canonical coverage roles");
        require(artistArchivalCoverage.core() == address(core), "canonical coverage Core");
        require(
            artistArchivalCoverage.checkpointVerifier() == address(artistArchivalCheckpoint),
            "pinned checkpoint"
        );
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(livingKeys, safeMessageDigest(livingSafe, abi.encode(digest)));
    }

    function testCurrentEstateSafeNoticeAndActivationPreserveIdentityAndExistingMintAuthority()
        public
    {
        T.Binding memory before_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 phasePolicy = manager.phasePolicyHash(1, PHASE);
        artists.requireMintConsent(1, PHASE, phasePolicy);
        _request(0);
        (address pending, uint64 ends, bytes32 record) =
            artists.estateActivationState(fixtureArtistId);
        require(
            pending == address(successorSafe) && ends == block.timestamp + 180 days, "actual notice"
        );
        Estate.Execution memory p =
            Estate.Execution(fixtureArtistId, record, request.selectedCoverageHash);
        uint256 safeNonce = successorSafe.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeEstateSafe(
            successorSafe, successorKeys, abi.encodeCall(artists.executeEstateActivation, (p))
        );
        require(successorSafe.nonce() == safeNonce, "early execution rolls Safe nonce back");
        vm.warp(ends);
        vm.recordLogs();
        this.executeEstateSafe(
            livingSafe, livingKeys, abi.encodeCall(artists.executeEstateActivation, (p))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Estate.AuthorityCapabilities memory rights =
            artists.currentAuthorityCapabilities(fixtureArtistId);
        require(
            rights.authorityAddress == address(successorSafe) && rights.authorityClass == 3
                && rights.status == 3 && rights.effectiveCapabilities == 0
                && rights.activationRecordHash == record,
            "truthful zero-capability estate authority"
        );
        require(
            artists.acceptedArtist(1) == address(successorSafe),
            "successor resolves from actual Core binding"
        );
        T.Binding memory after_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        require(
            after_.bindingHash == before_.bindingHash && after_.artistId == before_.artistId
                && after_.generation == before_.generation,
            "binding identity retained"
        );
        (Estate.RequestRecord memory saved, uint8 phase, Estate.ExecutionFacts memory result) =
            artists.estateActivationRecord(record);
        require(
            phase == 2 && saved.terms.evidenceHash == request.evidenceHash
                && result.coverageRecordHash == request.selectedCoverageHash
                && result.executedAt == ends && result.governanceActionId == 0
                && result.effectiveCapabilities == 0,
            "actual archival execution facts"
        );
        uint256 activationEvents;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == artistSuite.owners[2] && logs[i].topics.length == 3
                    && logs[i].topics[0]
                        == keccak256(
                            "ArtistSuccessionActivated(uint16,bytes32,address,uint8,uint32,bytes32,bytes32)"
                        )
            ) {
                require(
                    logs[i].topics[1] == fixtureArtistId
                        && logs[i].topics[2] == bytes32(uint256(uint160(address(successorSafe)))),
                    "event identities"
                );
                (
                    uint16 schemaVersion,
                    uint8 authorityClass,
                    uint32 caps,
                    bytes32 evidence,
                    bytes32 action
                ) = abi.decode(logs[i].data, (uint16, uint8, uint32, bytes32, bytes32));
                require(
                    schemaVersion == 1 && authorityClass == 3 && caps == 0
                        && evidence == request.evidenceHash && action == 0,
                    "event authority and evidence"
                );
                ++activationEvents;
            }
        }
        require(activationEvents == 1, "one Identity owner estate event");
        artists.requireMintConsent(1, PHASE, phasePolicy);
        vm.expectRevert(bytes("GS013"));
        this.executeEstateSafe(
            successorSafe, successorKeys, abi.encodeCall(artists.executeEstateActivation, (p))
        );
        require(
            artists.currentAuthorityCapabilities(fixtureArtistId).effectiveCapabilities == 0,
            "replay cannot grant rights"
        );
    }

    function testCurrentEstateLivingSafeCancelsAndConsumedRequestCannotReplay() public {
        _request(0);
        (,, bytes32 first) = artists.estateActivationState(fixtureArtistId);
        this.executeEstateSafe(
            livingSafe,
            livingKeys,
            abi.encodeCall(artists.cancelEstateActivation, (fixtureArtistId, first))
        );
        (,, bytes32 pending) = artists.estateActivationState(fixtureArtistId);
        require(
            pending == 0 && artists.acceptedArtist(1) == address(livingSafe),
            "living authority preserved"
        );
        require(
            artists.estateActivationNonceHint(fixtureArtistId, address(successorSafe)) == 1,
            "request nonce stays consumed"
        );
        vm.warp(block.timestamp + 1);
        vm.expectRevert(bytes("GS013"));
        this.executeEstateSafe(successorSafe, successorKeys, _requestData(0));
        _request(1);
        (,, bytes32 second) = artists.estateActivationState(fixtureArtistId);
        require(second != 0 && second != first, "fresh request retains cancelled history");
        (, uint8 phase,) = artists.estateActivationRecord(first);
        require(phase == 3, "cancelled record retained");
    }

    function testCurrentEstateWrongCoverageRollsBackAndIdenticalAuthorizationCanRetry() public {
        Estate.Request memory wrong = request;
        wrong.selectedCoverageHash = keccak256("missing coverage");
        T.Authorization memory auth = T.Authorization(0, uint64(block.timestamp + 1 days), "");
        uint256 safeNonce = successorSafe.nonce();
        vm.expectRevert(bytes("GS013"));
        this.executeEstateSafe(
            successorSafe,
            successorKeys,
            abi.encodeCall(artists.requestEstateActivation, (wrong, auth))
        );
        (,, bytes32 pending) = artists.estateActivationState(fixtureArtistId);
        require(
            pending == 0 && successorSafe.nonce() == safeNonce
                && artists.estateActivationNonceHint(fixtureArtistId, address(successorSafe)) == 0,
            "coverage failure leaves both replay lanes intact"
        );
        this.executeEstateSafe(
            successorSafe,
            successorKeys,
            abi.encodeCall(artists.requestEstateActivation, (request, auth))
        );
        (,, pending) = artists.estateActivationState(fixtureArtistId);
        require(pending != 0, "valid coverage accepts same authorization");
    }

    function _request(uint256 nonce) private {
        this.executeEstateSafe(successorSafe, successorKeys, _requestData(nonce));
    }

    function _requestData(uint256 nonce) private view returns (bytes memory) {
        return abi.encodeCall(
            artists.requestEstateActivation,
            (request, T.Authorization(nonce, uint64(block.timestamp + 1 days), ""))
        );
    }

    function executeEstateSafe(OfficialSafe safe, uint256[] calldata keys, bytes calldata data)
        external
    {
        require(msg.sender == address(this), "test only");
        require(
            executeSafe(safe, keys, address(artists), 0, data, 0), "actual estate Safe execution"
        );
    }
}
