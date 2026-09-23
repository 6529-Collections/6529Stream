// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import "../../smart-contracts/domains/mint/StreamOperatorDistribution.sol";
import "../../smart-contracts/integrations/delegation/NFTdelegation.sol";

contract CurrentDistributionRejector is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert("distribution recipient rejects");
    }

    function claim(StreamOperatorDistribution distribution, uint256 tokenId, address to)
        external
        returns (bool)
    {
        return distribution.claimNft(tokenId, to);
    }
}

/// @notice Actual current Core/Manager/Ledger/Artist/registry/entropy plus Safe 1.4.1 principals.
/// @dev The shared fixture's external entropy provider is the only service boundary.
contract StreamCurrentOperatorDistributionTest is StreamCurrentStackFixture, OfficialSafeFixture {
    bytes32 private constant DISTRIBUTION_PHASE = keccak256("current committed distribution");
    bytes32 private constant SUPPLY = keccak256("distribution supply");
    bytes32 private constant RECIPIENT = keccak256("distribution recipient");
    StreamOperatorDistribution private distributor;
    CurrentDistributionRejector private rejector;
    OfficialSafe private operatorSafe;
    OfficialSafe private artistSafe;
    uint256[] private keys;
    IStreamOperatorDistribution.Program private program;
    IStreamMintManager.MintBatch private batch;

    function setUp() public {
        keys.push(0xD15701);
        keys.push(0xD15702);
        SafeComponents memory c = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 1001);
        operatorSafe = createOfficialSafe(c, safeOwnerAddresses(keys), 2, 1002);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _deployAdditionalProducts() internal override {
        distributor = new StreamOperatorDistribution(
            StreamOperatorDistribution.DeploymentConfig(
                address(core),
                address(manager),
                address(registry),
                address(executor),
                address(new DelegationManagementContract()),
                2,
                keccak256("current distribution base manifest")
            )
        );
        rejector = new CurrentDistributionRejector();
        _assertDeployableProductionInstance(address(distributor));
    }

    function distributionTime() external view returns (uint256) {
        return block.timestamp;
    }

    function _configureAdditionalProducts() internal override {
        StreamModuleRegistration[] memory records = new StreamModuleRegistration[](1);
        records[0] = StreamModuleRegistration(
            address(distributor),
            distributor.MODULE_TYPE(),
            keccak256("6529STREAM_OPERATOR_DISTRIBUTION_V1"),
            type(IStreamOperatorDistribution).interfaceId,
            300_000,
            address(distributor).codehash,
            DEPLOYMENT_HASH,
            keccak256(distributor.moduleManifestBytes()),
            "urn:6529stream:fixture:distribution"
        );
        (GovernanceCall[] memory calls, bytes[] memory data) =
            StreamCurrentStackPlan.registrationCalls(registry, records);
        (bytes32 scope, bytes32 before_, bytes32 after_) = StreamGovernanceBootstrap.deriveBatchTransitionHashes(
            calls, StreamGovernanceBootstrap.governanceCallsHash(calls)
        );
        uint64 ready = uint64(this.distributionTime() + 48 hours);
        executor.publishGovernanceCallData(data);
        bytes memory scheduled = governanceRoot.execute(
            address(executor),
            0,
            abi.encodeCall(
                executor.scheduleGovernanceBatch,
                (
                    uint8(1),
                    calls,
                    scope,
                    before_,
                    after_,
                    ready,
                    uint64(ready + 7 days),
                    keccak256("distribution admission"),
                    "urn:6529stream:fixture:distribution-admission",
                    DEPLOYMENT_HASH
                )
            )
        );
        vm.warp(ready);
        executor.executeGovernanceBatch(abi.decode(scheduled, (bytes32)), calls, data);

        program = IStreamOperatorDistribution.Program(
            address(operatorSafe),
            0,
            SUPPLY,
            RECIPIENT,
            3,
            1,
            IStreamOperatorDistribution.DeliveryMode.FAILURE_ISOLATED,
            false
        );
        batch.collectionId = 1;
        batch.phaseId = DISTRIBUTION_PHASE;
        for (uint256 i; i < 3; ++i) {
            batch.initialRecipients.push(address(distributor));
            batch.beneficiaries
                .push(i == 0 ? address(operatorSafe) : i == 1 ? address(rejector) : BUYER);
            batch.tokenData.push(TOKEN_DATA);
            batch.mintCommitments.push(keccak256(abi.encode("distribution commitment", i)));
        }
        batch.contextHash = distributor.sliceHash(0, batch);
        batch.authorizationId = distributor.sliceAuthorization(1, DISTRIBUTION_PHASE, 0);
        program.slicesRoot = batch.contextHash;
        _phase();
        batch.expectedPolicyHash = manager.phasePolicyHash(1, DISTRIBUTION_PHASE);
    }

    function _phase() private {
        bytes32[] memory ids = new bytes32[](2);
        ids[0] = SUPPLY;
        ids[1] = RECIPIENT;
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](2);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            3,
            1,
            keccak256("supply config")
        );
        configs[1] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            1,
            1,
            keccak256("recipient config")
        );
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            3,
            distributor.programHash(1, DISTRIBUTION_PHASE, program),
            keccak256("published three-recipient manifest")
        );
        IStreamMintManager.MintGateConfig memory gate;
        _recordFixturePolicy(
            DISTRIBUTION_PHASE,
            manager.previewPhasePolicyHash(
                1, DISTRIBUTION_PHASE, config, gate, ids, configs, new address[](0)
            )
        );
        manager.configurePhase(1, DISTRIBUTION_PHASE, config, gate, ids, configs);
        address[] memory enabled = new address[](1);
        enabled[0] = address(distributor);
        _recordFixturePolicy(
            DISTRIBUTION_PHASE,
            manager.previewPhasePolicyHash(
                1, DISTRIBUTION_PHASE, config, gate, ids, configs, enabled
            )
        );
        manager.setPhaseExecutor(1, DISTRIBUTION_PHASE, address(distributor), true);
    }

    function testActualSafeOperatorBatchAccountsBeneficiariesAndRecoversFailedDelivery() public {
        require(
            executeSafe(
                operatorSafe,
                keys,
                address(distributor),
                0,
                abi.encodeCall(
                    distributor.distribute, (program, 0, new bytes32[](0), batch, bytes(""))
                ),
                0
            ),
            "actual Safe operator distribution"
        );
        require(
            core.collectionMintedEver(1) == 3 && manager.nextOperationNonce() == 3,
            "current mint and ledger batch"
        );
        uint256 last = core.lastAllocatedTokenId();
        require(
            core.ownerOf(last - 2) == address(operatorSafe) && core.ownerOf(last) == BUYER,
            "current sibling transfers"
        );
        require(
            core.ownerOf(last - 1) == address(distributor), "rejecting token remains in custody"
        );
        require(
            distributor.nftClaim(last - 1).beneficiary == address(rejector),
            "original beneficiary claim"
        );
        require(
            rejector.claim(distributor, last - 1, address(operatorSafe)),
            "owed delivery to real Safe"
        );
        require(core.ownerOf(last - 1) == address(operatorSafe), "recovered token delivered");
        bytes32 subject = manager.previewSubjectKey(
            IStreamMintManager.CounterKeyMode.RECIPIENT,
            1,
            DISTRIBUTION_PHASE,
            RECIPIENT,
            address(0),
            address(rejector),
            address(distributor),
            address(0),
            batch.contextHash
        );
        require(
            ledger.counterValue(
                manager.previewCounterValueKey(1, DISTRIBUTION_PHASE, RECIPIENT, subject)
            ) == 1,
            "recipient cap consumed for beneficiary before recovery"
        );
        require(manager.isAuthorizationUsed(batch.authorizationId), "current durable ledger replay");
    }
}
