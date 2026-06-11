// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../script/RehearseDeployment.s.sol";
import "../smart-contracts/AuctionContract.sol";
import "../smart-contracts/RandomizerRNG.sol";
import "../smart-contracts/RandomizerVRF.sol";
import "../smart-contracts/StreamAdmins.sol";
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
}
