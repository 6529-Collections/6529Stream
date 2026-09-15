// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamEntropySubjectIdentity.t.sol";

interface EntropyEpochVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
    function expectCall(address target, bytes calldata data) external;
}

/// @notice Real coordinator/provider flows with a typed Core boundary.
contract StreamEntropyEpochsTest is CharacterizationTestBase, EntropyTimeAuthorityFixture {
    EntropyEpochVm private constant epochVm = EntropyEpochVm(address(vm));
    bytes32 private constant MANIFEST = keccak256("entropy epochs test");
    bytes32 private constant SALT = keccak256("collection salt");
    bytes32 private constant COMMITMENT = keccak256("mint commitment");
    EntropySubjectCoreFixture private core;
    StreamEntropyCoordinator private entropy;
    MockStreamEntropyProvider private provider;
    MockEntropyRoleRegistry public roleRegistry;

    function setUp() public {
        core = new EntropySubjectCoreFixture();
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        core.setModuleRegistry(address(new MockEntropyModuleRegistry(address(this))));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                MANIFEST,
                "urn:test:entropy-epochs",
                MANIFEST
            )
        );
        core.setCoordinator(entropy);
        provider = new MockStreamEntropyProvider(address(entropy));
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
    }

    function testInitialAndUnconfiguredEpochsAndAdditiveInterfaces() public view {
        require(entropy.collectionProviderEpoch(1) == 1 && entropy.collectionProviderEpoch(2) == 0);
        require(entropy.supportsInterface(type(IStreamEntropyEpochs).interfaceId));
        require(entropy.supportsInterface(type(IStreamEntropyCoordinator).interfaceId));
        require(entropy.supportsInterface(type(IStreamEntropyView).interfaceId));
        require(entropy.supportsInterface(type(IStreamEntropyFinalityPolicy).interfaceId));
        require(!entropy.supportsInterface(0xffffffff));
        require(entropy.requestPolicySnapshot(keccak256("unknown")).provider == address(0));
        (bool frozen, bytes32 policy, address selected, uint32 epoch, bytes32 salt) =
            entropy.entropyPolicyFrozen(2);
        require(!frozen && policy == 0 && selected == address(0) && epoch == 0 && salt == 0);
    }

    function testOperationalAndIdenticalUpdatesDoNotIncrementProviderEpoch() public {
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        entropy.configureCollection(1, address(provider), SALT, false, 20);
        entropy.configureCollection(
            1, address(provider), keccak256("revised pre-mint salt"), true, 10
        );
        provider.setFee(0);
        require(entropy.collectionProviderEpoch(1) == 1);
        _assertPolicy(1, false);
    }

    function testProviderReplacementReturnAndOtherCollectionsHaveDistinctEpochs() public {
        MockStreamEntropyProvider replacement = new MockStreamEntropyProvider(address(entropy));
        vm.recordLogs();
        entropy.configureCollection(1, address(replacement), SALT, true, 10);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "retained config event plus explicit epoch event");
        require(logs[1].emitter == address(entropy));
        require(
            logs[1].topics[0]
                == keccak256("CollectionEntropyEpochConfigured(uint16,uint256,address,uint32,bytes32)")
        );
        require(logs[1].topics[1] == bytes32(uint256(1)));
        require(logs[1].topics[2] == bytes32(uint256(uint160(address(replacement)))));
        require(
            keccak256(logs[1].data)
                == keccak256(abi.encode(uint16(1), uint32(2), replacement.streamEntropyProviderConfigHash()))
        );
        _assertPolicy(2, false);
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        require(entropy.collectionProviderEpoch(1) == 3);
        entropy.configureCollection(2, address(replacement), SALT, true, 10);
        require(entropy.collectionProviderEpoch(2) == 1 && entropy.collectionProviderEpoch(1) == 3);
    }

    function testProviderConfigChangeIncrementsAndInvalidUpdateRollsBack() public {
        _configHash(keccak256("provider config two"));
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        require(entropy.collectionProviderEpoch(1) == 2);
        bytes32 beforeHash = _configRecordHash();
        _configHash(bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidDependency.selector, address(provider)
            )
        );
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        require(entropy.collectionProviderEpoch(1) == 2 && _configRecordHash() == beforeHash);
    }

    function testEpochChangesRemainAuthorityOnlyAndLockedAfterTokenOrScopeRegistration() public {
        vm.prank(address(0xbad));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.Unauthorized.selector, address(0xbad))
        );
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        core.registerToken(1, COMMITMENT);
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, uint256(1))
        );
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        entropy.configureCollection(2, address(provider), SALT, true, 10);
        entropy.configureCollectionRevealPolicy(2, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        entropy.registerEntropyScope(2, 0, keccak256("scope"));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, uint256(2))
        );
        entropy.configureCollection(2, address(provider), SALT, true, 10);
        require(entropy.collectionProviderEpoch(1) == 1 && entropy.collectionProviderEpoch(2) == 1);
    }

    function testCoreFreezeStillBlocksPreMintEpochChange() public {
        core.freezeCollection(1);
        _configHash(keccak256("new provider config"));
        vm.expectRevert(
            abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, uint256(1))
        );
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        require(entropy.collectionProviderEpoch(1) == 1);
    }

    function testEpochOneRetainsOriginalTokenKeySeedAndPolicyPreimages() public {
        core.registerToken(1, COMMITMENT);
        _assertPolicy(1, true);
        bytes32 expectedKey = _tokenRequestKey(1, provider.streamEntropyProviderConfigHash());
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        require(key == expectedKey);
        _assertSnapshot(key, 1, provider.streamEntropyProviderConfigHash(), COMMITMENT);
        bytes32 raw = bytes32(uint256(42));
        require(provider.fulfill(id, raw) == 0);
        (bytes32 actual, bool finalized) = entropy.tokenSeed(1);
        require(finalized && actual == _seed(key, bytes32(uint256(1)), id, raw, false));
        require(provider.fulfill(id, raw) == 3 && entropy.pendingRequestCount() == 0);
    }

    function testTokenRequestUsesRecordedEpochContextAndSurvivesLaterProviderConfigDrift() public {
        bytes32 configHash = keccak256("provider config two");
        _configHash(configHash);
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        core.registerToken(1, COMMITMENT);
        _assertPolicy(2, true);
        bytes32 expectedKey = _tokenRequestKey(2, configHash);
        bytes memory context = abi.encode(
            uint16(1),
            address(core),
            uint256(1),
            uint256(1),
            bytes32(0),
            uint32(2),
            configHash,
            uint16(1),
            COMMITMENT
        );
        epochVm.expectCall(
            address(provider),
            abi.encodeWithSelector(
                IStreamEntropyProvider.requestEntropy.selector, expectedKey, context
            )
        );
        (bytes32 key, uint256 id) = entropy.requestEntropy(1);
        require(key == expectedKey);
        _assertSnapshot(key, 2, configHash, COMMITMENT);
        _configHash(keccak256("later upstream drift"));
        bytes32 raw = keccak256("raw output");
        require(provider.fulfill(id, raw) == 0);
        (
            StreamEntropyStatus status,
            bytes32 seed,
            address selected,
            uint32 epoch,
            bytes32 recordedConfig,
            bytes32 recordedKey,
            uint256 recordedId,
            uint16 attempt
        ) = entropy.tokenEntropy(1);
        require(
            status == StreamEntropyStatus.FINALIZED
                && seed == _seed(key, bytes32(uint256(1)), id, raw, false)
        );
        require(selected == address(provider) && epoch == 2 && recordedConfig == configHash);
        require(recordedKey == key && recordedId == id && attempt == 1);
        require(core.metadataNotifications() == 1);
    }

    function testScopeRequestUsesRecordedEpochContextAndSeed() public {
        bytes32 configHash = keccak256("scope provider config two");
        _configHash(configHash);
        entropy.configureCollection(1, address(provider), SALT, true, 10);
        bytes32 scopeId = entropy.registerEntropyScope(1, 0, keccak256("sale scope"));
        bytes32 inputs = keccak256("scope inputs");
        bytes32 expectedKey = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SCOPE_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                scopeId,
                address(provider),
                uint32(2),
                configHash,
                inputs,
                uint16(1)
            )
        );
        bytes memory context = abi.encode(
            uint16(2),
            address(core),
            uint256(1),
            uint256(0),
            scopeId,
            uint32(2),
            configHash,
            uint16(1),
            inputs
        );
        epochVm.expectCall(
            address(provider),
            abi.encodeWithSelector(
                IStreamEntropyProvider.requestEntropy.selector, expectedKey, context
            )
        );
        (bytes32 key, uint256 id) = entropy.requestScopeEntropy(scopeId, inputs);
        require(key == expectedKey);
        _assertSnapshot(key, 2, configHash, inputs);
        bytes32 raw = bytes32(uint256(99));
        require(provider.fulfill(id, raw) == 0);
        (bytes32 seed, bool finalized) = entropy.scopeSeed(scopeId);
        require(finalized && seed == _seed(key, scopeId, id, raw, true));
        require(core.metadataNotifications() == 0 && entropy.pendingRequestCount() == 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamEntropyCoordinator.InvalidStatus.selector, StreamEntropyStatus.FINALIZED
            )
        );
        entropy.requestScopeEntropy(scopeId, inputs);
    }

    function testRejectedProviderSubmissionLeavesNoRequestSnapshot() public {
        core.registerToken(1, COMMITMENT);
        bytes32 key = _tokenRequestKey(1, provider.streamEntropyProviderConfigHash());
        provider.setReenterOnRequest(true);
        vm.expectRevert();
        entropy.requestEntropy(1);
        require(entropy.requestPolicySnapshot(key).providerEpoch == 0);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED);
        require(entropy.pendingRequestCount() == 0 && provider.nextRequestId() == 1);
        provider.setReenterOnRequest(false);
        (bytes32 retried,) = entropy.requestEntropy(1);
        require(retried == key && entropy.requestPolicySnapshot(key).providerEpoch == 1);
    }

    function testFuzzProviderRevisionNeverReusesEpoch(uint8 revisionCount) public {
        uint256 count = uint256(revisionCount) % 20 + 1;
        for (uint256 i; i < count; ++i) {
            _configHash(keccak256(abi.encode("provider revision", i)));
            entropy.configureCollection(1, address(provider), SALT, true, 10);
            require(entropy.collectionProviderEpoch(1) == i + 2);
            entropy.configureCollection(1, address(provider), SALT, true, 10);
            require(entropy.collectionProviderEpoch(1) == i + 2);
        }
    }

    function _configHash(bytes32 hash) private {
        epochVm.mockCall(
            address(provider),
            abi.encodeWithSelector(IStreamEntropyProvider.streamEntropyProviderConfigHash.selector),
            abi.encode(hash)
        );
    }

    function _configRecordHash() private view returns (bytes32) {
        (bool ok, bytes memory result) = address(entropy)
            .staticcall(
                abi.encodeWithSelector(entropy.collectionEntropyConfig.selector, uint256(1))
            );
        require(ok);
        return keccak256(result);
    }

    function _tokenRequestKey(uint32 epoch, bytes32 configHash) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_REQUEST_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                uint256(1),
                address(provider),
                epoch,
                configHash,
                uint16(1)
            )
        );
    }

    function _assertSnapshot(bytes32 key, uint32 epoch, bytes32 configHash, bytes32 inputs)
        private
        view
    {
        IStreamEntropyEpochs.RequestPolicySnapshot memory policy =
            entropy.requestPolicySnapshot(key);
        require(
            policy.provider == address(provider)
                && policy.providerCodeHash == address(provider).codehash
        );
        require(policy.providerEpoch == epoch && policy.providerConfigHash == configHash);
        require(
            policy.collectionSalt == SALT && policy.inputsHash == inputs
                && policy.requestAttempt == 1
        );
    }

    function _seed(bytes32 key, bytes32 identity, uint256 id, bytes32 raw, bool scope)
        private
        view
        returns (bytes32)
    {
        IStreamEntropyEpochs.RequestPolicySnapshot memory policy =
            entropy.requestPolicySnapshot(key);
        return keccak256(
            abi.encode(
                scope
                    ? keccak256("6529STREAM_ENTROPY_SCOPE_SEED_V1")
                    : keccak256("6529STREAM_ENTROPY_SEED_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                identity,
                policy.provider,
                policy.providerEpoch,
                policy.providerConfigHash,
                key,
                id,
                raw,
                policy.collectionSalt,
                policy.inputsHash
            )
        );
    }

    function _assertPolicy(uint32 expectedEpoch, bool expectedFrozen) private view {
        (
            address selected,
            bool publicRequests,,
            uint64 timeout,
            bytes32 configHash,
            bytes32 codeHash,
            bytes32 salt
        ) = entropy.collectionEntropyConfig(1);
        bytes32 saltCommitment = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                salt
            )
        );
        bytes32 providerPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                selected,
                codeHash,
                expectedEpoch,
                configHash,
                saltCommitment,
                publicRequests,
                timeout
            )
        );
        bytes32 revealPolicy = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"),
                uint8(0),
                keccak256("ROLE_ENTROPY_REVEAL_OWNER"),
                uint64(10)
            )
        );
        bytes32 profile = expectedEpoch == 1
            ? keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1")
            : keccak256("6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1");
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FINALITY_POLICY_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                profile,
                providerPolicy,
                revealPolicy
            )
        );
        (bool frozen, bytes32 actual, address providerAddress, uint32 epoch, bytes32 saltHash) =
            entropy.entropyPolicyFrozen(1);
        require(frozen == expectedFrozen && actual == expected && providerAddress == selected);
        require(epoch == expectedEpoch && saltHash == saltCommitment);
    }
}
