// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../script/RehearseDeployment.s.sol";
import "../script/RehearseAuctionCeremony.s.sol";
import "../script/RehearseDeploymentSuite.s.sol";
import "../script/RehearseEmergencyRedeployment.s.sol";
import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/StreamAdmins.sol";
import "../smart-contracts/StreamContractMetadata.sol";
import "../smart-contracts/StreamCore.sol";
import "../smart-contracts/StreamDrops.sol";
import "../smart-contracts/StreamMinter.sol";
import "./helpers/Assertions.sol";
import "./helpers/CharacterizationTestBase.sol";

contract StreamDeploymentManifestTest is CharacterizationTestBase {
    function testLocalDeploymentRehearsalWiresStackAndCeremony() public {
        vm.chainId(31_337);
        RehearseDeployment rehearsor = new RehearseDeployment();
        RehearseDeployment.DeploymentConfig memory config = rehearsor.defaultLocalConfig();

        RehearseDeployment.DeploymentResult memory result = rehearsor.deployLocal(config);

        Assertions.assertEq(result.chainId, 31_337, "chain id not recorded");
        Assertions.assertTrue(result.manifestHash != bytes32(0), "manifest hash missing");

        StreamAdmins admins = StreamAdmins(result.admins);
        StreamCore core = StreamCore(result.core);
        StreamContractMetadata metadata = StreamContractMetadata(result.contractMetadata);
        StreamDrops drops = StreamDrops(result.drops);
        StreamMinter minter = StreamMinter(result.minter);

        Assertions.assertEq(admins.owner(), config.adminSafe, "admin owner not safe");
        Assertions.assertEq(core.owner(), config.adminSafe, "core owner not safe");
        Assertions.assertTrue(admins.retrieveGlobalAdmin(config.adminSafe), "safe not admin");
        Assertions.assertFalse(admins.retrieveGlobalAdmin(config.deployer), "temp admin kept");
        Assertions.assertTrue(
            admins.retrieveFunctionAdmin(
                config.adminSafe, result.drops, drops.updateTDHsigner.selector
            ) == false,
            "unexpected function admin grant"
        );
        Assertions.assertTrue(admins.pauseGuardians(config.pauseGuardian), "guardian missing");
        Assertions.assertTrue(admins.unpauseAdmins(config.adminSafe), "unpause admin missing");
        Assertions.assertTrue(admins.signerManagers(config.adminSafe), "signer manager missing");
        Assertions.assertTrue(
            admins.signerLifecycleTargets(result.drops), "signer lifecycle target missing"
        );
        Assertions.assertEq(
            admins.emergencyRecipient(), config.emergencyRecipient, "emergency recipient"
        );

        Assertions.assertEq(core.minterContract(), result.minter, "core minter");
        Assertions.assertEq(metadata.streamCore(), result.core, "metadata core");
        Assertions.assertEq(metadata.adminsContract(), result.admins, "metadata admins");
        Assertions.assertEq(metadata.contractURI(), config.contractMetadataURI, "metadata uri");
        Assertions.assertEq(
            metadata.contractURIHash(),
            keccak256(bytes(config.contractMetadataURI)),
            "metadata uri hash"
        );
        Assertions.assertTrue(metadata.isStreamContractMetadata(), "metadata marker");
        Assertions.assertEq(minter.streamDrops(), result.drops, "minter drops");
        Assertions.assertEq(drops.auctionContract(), result.auctions, "drops auction");
        Assertions.assertEq(drops.payOutAddress(), config.payout, "drops payout");
        Assertions.assertEq(drops.curatorsPoolAddress(), result.curatorsPool, "drops curators pool");

        (uint256 startTime, uint256 endTime) =
            minter.retrieveCollectionPhases(result.sampleCollectionId);
        Assertions.assertEq(startTime, result.sampleMintStart, "mint start");
        Assertions.assertEq(endTime, result.sampleMintEnd, "mint end");

        (,, uint256 circulation, uint256 totalSupply,, address randomizer) =
            core.retrieveCollectionAdditionalData(result.sampleCollectionId);
        Assertions.assertEq(circulation, 0, "unexpected circulation");
        Assertions.assertEq(totalSupply, 10, "unexpected sample supply");
        Assertions.assertEq(randomizer, result.randomizerVrf, "sample randomizer");
        Assertions.assertTrue(
            NextGenRandomizerVRF(result.randomizerVrf).isRandomizerContract(), "vrf randomizer"
        );
        Assertions.assertTrue(
            NextGenRandomizerRNG(payable(result.randomizerRng)).isRandomizerContract(),
            "rng randomizer"
        );
        Assertions.assertTrue(
            StreamAuctions(result.auctions).isStreamAuctionsContract(), "auction contract"
        );
    }

    function testDeploymentManifestJsonArtifactsParse() public view {
        string memory schema = vm.readFile("deployments/schema/deployment-manifest.schema.json");
        string memory example = vm.readFile("deployments/examples/anvil-6529stream-v0.1.0-001.json");

        Assertions.assertTrue(vm.parseJson(schema).length > 0, "schema json invalid");
        Assertions.assertTrue(vm.parseJson(example).length > 0, "example json invalid");
    }

    function testLocalAuctionCeremonyRehearsalSettlesAndWithdrawsProceeds() public {
        vm.chainId(31_337);
        RehearseAuctionCeremony rehearsor = new RehearseAuctionCeremony();

        RehearseAuctionCeremony.AuctionCeremonyResult memory result = rehearsor.run();

        Assertions.assertEq(result.chainId, 31_337, "chain id not recorded");
        Assertions.assertTrue(result.deploymentManifestHash != bytes32(0), "manifest hash missing");
        Assertions.assertEq(result.collectionId, 1, "collection id");
        Assertions.assertTrue(result.dropId != bytes32(0), "drop id missing");
        Assertions.assertEq(result.tokenId, 10_000_000_000, "token id");
        Assertions.assertEq(
            result.finalOwner, address(0x00000000000000000000000000000000000065A2), "final owner"
        );
        Assertions.assertEq(
            result.highestBidder,
            address(0x00000000000000000000000000000000000065A2),
            "highest bidder"
        );
        Assertions.assertEq(result.highestBid, 4 ether, "highest bid");
        Assertions.assertEq(
            result.finalStatus, uint8(StreamAuctions.AuctionStatus.SettledWithBid), "final status"
        );
        Assertions.assertEq(result.posterProceedsWithdrawn, 2 ether, "poster proceeds");
        Assertions.assertEq(result.protocolProceedsWithdrawn, 1 ether, "protocol proceeds");
        Assertions.assertEq(result.curatorProceedsWithdrawn, 1 ether, "curator proceeds");
        Assertions.assertEq(result.totalOwedAfterWithdrawals, 0, "owed after withdrawals");
        Assertions.assertEq(
            keccak256(bytes(result.evidenceKind)),
            keccak256(bytes("local-anvil-auction-ceremony")),
            "evidence kind"
        );
    }

    function testLocalEmergencyRedeploymentRehearsalProducesReplacementEvidence() public {
        vm.chainId(31_337);
        RehearseEmergencyRedeployment rehearsor = new RehearseEmergencyRedeployment();

        RehearseEmergencyRedeployment.EmergencyRedeploymentResult memory result = rehearsor.run();

        Assertions.assertEq(result.chainId, 31_337, "chain id not recorded");
        Assertions.assertEq(
            result.evidenceKindHash,
            keccak256(bytes("local-anvil-emergency-redeployment")),
            "evidence kind"
        );
        Assertions.assertEq(
            result.oldLifecycleStateHash, keccak256(bytes("EmergencySuperseded")), "old lifecycle"
        );
        Assertions.assertEq(
            result.replacementLifecycleStateHash, keccak256(bytes("Rehearsed")), "new lifecycle"
        );
        Assertions.assertEq(
            result.oldDeploymentVersionHash,
            keccak256(bytes("anvil-6529stream-v0.1.0-001")),
            "old version"
        );
        Assertions.assertEq(
            result.replacementDeploymentVersionHash,
            keccak256(bytes("anvil-6529stream-v0.1.0-emergency-002")),
            "replacement version"
        );
        Assertions.assertTrue(result.oldManifestHash != bytes32(0), "old manifest missing");
        Assertions.assertTrue(
            result.replacementManifestHash != bytes32(0), "replacement manifest missing"
        );
        Assertions.assertTrue(
            result.oldManifestHash != result.replacementManifestHash, "manifest reused"
        );
        Assertions.assertTrue(
            result.oldDropDomainSeparator != result.replacementDropDomainSeparator,
            "drop domain reused"
        );
        Assertions.assertEq(
            result.adminSafe, address(0x0000000000000000000000000000000000006529), "admin safe"
        );
        Assertions.assertEq(result.tdhSigner, vm.addr(0xA11CE), "signer");
        Assertions.assertTrue(result.oldCore != result.replacementCore, "core reused");
        Assertions.assertTrue(result.oldDrops != result.replacementDrops, "drops reused");
        Assertions.assertTrue(result.oldAuctions != result.replacementAuctions, "auctions reused");
        Assertions.assertEq(result.oldCollectionId, 1, "old collection");
        Assertions.assertEq(result.replacementCollectionId, 1, "replacement collection");
        Assertions.assertEq(result.replacementTokenId, 10_000_000_000, "replacement token");
        Assertions.assertEq(
            result.replacementTokenOwner,
            address(0x00000000000000000000000000000000000065E2),
            "replacement token owner"
        );
        Assertions.assertTrue(
            result.replacementTokenHash != bytes32(0), "replacement token hash missing"
        );
        Assertions.assertEq(result.replacementSignerEpoch, 1, "replacement signer epoch");
    }

    function testAggregateDeploymentSuiteRunsAllRehearsals() public {
        vm.chainId(31_337);
        RehearseDeploymentSuite suite = new RehearseDeploymentSuite();

        RehearseDeploymentSuite.DeploymentSuiteResult memory result = suite.run();

        Assertions.assertEq(
            result.suiteKindHash, keccak256(bytes("local-anvil-deployment-suite")), "suite kind"
        );
        Assertions.assertTrue(result.suiteHash != bytes32(0), "suite hash missing");
        Assertions.assertEq(result.deployment.chainId, 31_337, "deployment chain id");
        Assertions.assertTrue(
            result.deployment.manifestHash != bytes32(0), "deployment manifest missing"
        );
        Assertions.assertEq(
            keccak256(bytes(result.auction.evidenceKind)),
            keccak256(bytes("local-anvil-auction-ceremony")),
            "auction evidence kind"
        );
        Assertions.assertEq(
            result.auction.finalStatus,
            uint8(StreamAuctions.AuctionStatus.SettledWithBid),
            "auction final status"
        );
        Assertions.assertEq(result.auction.totalOwedAfterWithdrawals, 0, "auction owed");
        Assertions.assertEq(
            result.emergency.evidenceKindHash,
            keccak256(bytes("local-anvil-emergency-redeployment")),
            "emergency kind"
        );
        Assertions.assertTrue(
            result.emergency.oldManifestHash != result.emergency.replacementManifestHash,
            "emergency manifest reused"
        );
        Assertions.assertTrue(
            result.emergency.oldDropDomainSeparator
                != result.emergency.replacementDropDomainSeparator,
            "emergency domain reused"
        );
    }
}
