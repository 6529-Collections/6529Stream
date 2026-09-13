// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/EntropyFinalityEvidenceFixture.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../mocks/MockEntropyRoleRegistry.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "../../../smart-contracts/domains/finality/StreamFinalityServingHostAdapter.sol";

/// @notice Actual Coordinator policy and actual serving adapter, with explicit source boundaries.
contract StreamFinalityEntropyEvidenceProviderTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture,
    OfficialSafeFixture
{
    EntropyFinalityCoreBoundary private core;
    EntropyFinalityMetadataBoundary private metadata;
    EntropyFinalityMembershipBoundary private membership;
    EntropyFinalityModuleBoundary private modules;
    StreamEntropyCoordinator private entropy;
    StreamFinalityEntropyEvidenceProvider private evidence;
    StreamFinalityServingHostAdapter private adapter;
    MockStreamEntropyProvider private random;
    MockEntropyRoleRegistry public roleRegistry;
    bytes32 private constant MANIFEST = keccak256("entropy finality fixture manifest");
    bytes32 private constant FAMILY = keccak256("ENTROPY_COORDINATOR");
    bytes32 private constant SALT = keccak256("original collection salt");
    bytes32 private constant OWNER = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
    event log_named_uint(string key, uint256 value);

    function setUp() public {
        vm.roll(100);
        core = new EntropyFinalityCoreBoundary();
        modules = new EntropyFinalityModuleBoundary(address(this));
        _install(
            keccak256("MODULE_REGISTRY"), address(modules), type(IStreamModuleRegistry).interfaceId
        );
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        entropy = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                MANIFEST,
                "ipfs://entropy-finality-fixture",
                MANIFEST
            )
        );
        core.setCoordinator(entropy);
        random = new MockStreamEntropyProvider(address(entropy));
        entropy.configureCollection(1, address(random), SALT, true, 10);
        entropy.configureCollectionRevealPolicy(1, 0, OWNER, 10, 0);
        metadata = new EntropyFinalityMetadataBoundary(address(core));
        membership = new EntropyFinalityMembershipBoundary(address(core), address(metadata));
        evidence = new StreamFinalityEntropyEvidenceProvider(
            address(core), address(metadata), address(entropy), address(membership), 500000, 2000000
        );
        adapter = new StreamFinalityServingHostAdapter(
            address(core), address(entropy), address(evidence), FAMILY
        );
        _install(FAMILY, address(entropy), type(IStreamEntropyCoordinator).interfaceId);
        _install(
            keccak256("COLLECTION_METADATA"),
            address(metadata),
            type(IStreamCollectionMetadataV1).interfaceId
        );
    }

    function _install(bytes32 kind, address target, bytes4 id) private {
        core.setPointer(
            kind,
            StreamMetadataRecoveryRoutes.Pointer(
                target, target.codehash, false, kind, id, address(modules), 1, MANIFEST, MANIFEST, 1
            )
        );
    }

    function _scope() private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
    }

    function _policy() private view returns (bytes32 hash) {
        (, hash,,,) = entropy.entropyPolicyFrozen(1);
    }

    function testMissingDeclarationIsNotFrozenOrZeroFeePolicy() public {
        (bool frozen, bytes32 hash, address provider, uint32 epoch, bytes32 salt) =
            entropy.entropyPolicyFrozen(2);
        require(!frozen && hash == 0 && provider == address(0) && epoch == 0 && salt == 0);
        entropy.configureCollection(2, address(random), SALT, true, 10);
        (frozen, hash,,,) = entropy.entropyPolicyFrozen(2);
        require(!frozen && hash == 0, "provider alone is not complete policy");
        entropy.configureCollectionRevealPolicy(2, 0, OWNER, 10, 0);
        (frozen, hash,,,) = entropy.entropyPolicyFrozen(2);
        require(!frozen && hash != 0, "explicit declared zero fee is complete but mutable");
    }

    function testFirstTokenFreezesExactPolicyBeforeItsSeedExists() public {
        bytes32 before = _policy();
        require(!evidence.finalityComponentFacts(FAMILY, _scope()).frozen);
        core.registerToken(1);
        (bool frozen, bytes32 hash, address provider, uint32 epoch, bytes32 salt) =
            entropy.entropyPolicyFrozen(1);
        require(frozen && hash == before && provider == address(random) && epoch == 1 && salt != 0);
        require(
            entropy.tokenEntropyStatus(1) == StreamEntropyStatus.REGISTERED,
            "policy is not completed seed"
        );
        require(evidence.finalityComponentFacts(FAMILY, _scope()).frozen);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        entropy.configureCollection(1, address(random), keccak256("replacement"), true, 10);
        vm.expectRevert(abi.encodeWithSelector(StreamEntropyCoordinator.PolicyLocked.selector, 1));
        entropy.configureCollectionRevealPolicy(1, 1, OWNER, 20, 0);
        require(_policy() == before, "rejected writes preserve policy");
    }

    function testScopeRegistrationAlsoLocksActualPolicy() public {
        bytes32 before = _policy();
        entropy.registerEntropyScope(1, 1, keccak256("scope ref"));
        (bool frozen, bytes32 afterHash,,,) = entropy.entropyPolicyFrozen(1);
        require(frozen && afterHash == before && entropy.nonterminalTokenCount(1) == 0);
    }

    function testIndependentDomainSeparatedPolicyPreimage() public view {
        bytes32 salt = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_SALT_V1"),
                block.chainid,
                address(entropy),
                address(core),
                uint256(1),
                SALT
            )
        );
        bytes32 provider = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_SINGLE_PROVIDER_POLICY_V1"),
                address(random),
                address(random).codehash,
                uint32(1),
                random.streamEntropyProviderConfigHash(),
                salt,
                true,
                uint64(10)
            )
        );
        bytes32 reveal = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_DECLARED_REVEAL_POLICY_V1"),
                uint8(0),
                OWNER,
                uint64(10)
            )
        );
        require(
            _policy()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_FINALITY_POLICY_V1"),
                        block.chainid,
                        address(entropy),
                        address(core),
                        uint256(1),
                        keccak256("6529STREAM_ENTROPY_EPOCH1_NO_FRESH_RECOVERY_V1"),
                        provider,
                        reveal
                    )
                ),
            "complete literal typed preimage"
        );
    }

    function testOperationalChangesAndCompletedOutputPreservePolicy() public {
        core.registerToken(1);
        bytes32 before = _policy();
        bytes32 stateBefore = evidence.finalityComponentFacts(FAMILY, _scope()).dataHash;
        entropy.updateRevealFeePerToken(1, 100);
        entropy.setRequester(address(0x1234), true);
        entropy.setProviderRevoked(address(random), true);
        _raise(entropy.GTP_ENTROPY_REVEAL_SLO_BLOCKS(), 20);
        require(entropy.effectiveRevealSLOBlocks(1) == 20 && _policy() == before);
        require(evidence.finalityComponentFacts(FAMILY, _scope()).dataHash == stateBefore);
        entropy.setProviderRevoked(address(random), false);
        (, uint256 requestId) = entropy.requestEntropy(1);
        require(random.fulfill(requestId, bytes32(uint256(77))) == 0);
        require(entropy.tokenEntropyStatus(1) == StreamEntropyStatus.FINALIZED);
        require(
            _policy() == before
                && evidence.finalityComponentFacts(FAMILY, _scope()).dataHash == stateBefore
        );
    }

    function testProviderCodeLossDoesNotRewriteOriginalPolicy() public {
        core.registerToken(1);
        bytes32 before = _policy();
        vm.etch(address(random), "");
        require(_policy() == before && evidence.finalityComponentFacts(FAMILY, _scope()).frozen);
    }

    function testAllScopeKindsDeriveActualPolicyAndAdapterIdentity() public {
        core.registerToken(1);
        bytes32 previous;
        for (uint8 kind; kind < 5; ++kind) {
            StreamFinalityScope memory scope = StreamFinalityScope(
                StreamFinalityScopeType(kind),
                1,
                kind == 1 ? 1 : 0,
                kind > 1 ? bytes32(uint256(kind)) : bytes32(0)
            );
            StreamFinalityHostComponentFacts memory facts =
                evidence.finalityComponentFacts(FAMILY, scope);
            StreamFinalityComponentState memory state = adapter.finalityStateForScope(scope);
            require(state.frozen && state.dataHash == facts.dataHash && state.dataHash != previous);
            require(
                state.component == address(adapter) && state.codeHash == address(adapter).codehash
            );
            previous = state.dataHash;
        }
    }

    function testMissingMalformedAndWrongMembershipRejectThenRetry() public {
        for (uint8 fault = 1; fault <= 4; ++fault) {
            membership.setFault(fault);
            vm.expectRevert();
            evidence.finalityComponentFacts(FAMILY, _scope());
        }
        membership.setFault(0);
        evidence.finalityComponentFacts(FAMILY, _scope());
        StreamFinalityScope memory bad = _scope();
        bad.tokenId = 1;
        vm.expectRevert();
        evidence.finalityComponentFacts(FAMILY, bad);
        vm.expectRevert();
        evidence.finalityComponentFacts(keccak256("RENDERER"), _scope());
    }

    function testCurrentSelectionAndHistoricalFactsHaveSeparateLifetimes() public {
        core.registerToken(1);
        bytes32 before = evidence.finalityComponentFacts(FAMILY, _scope()).dataHash;
        evidence.requireCurrentEntropySelection();
        adapter.requireCurrentSelection();
        modules.setEligible(false);
        vm.expectRevert();
        evidence.requireCurrentEntropySelection();
        require(evidence.finalityComponentFacts(FAMILY, _scope()).dataHash == before);
        require(adapter.finalityState(1).dataHash == before);
        modules.setEligible(true);
        core.setPointer(
            FAMILY,
            StreamMetadataRecoveryRoutes.Pointer(address(0), 0, false, 0, 0, address(0), 0, 0, 0, 0)
        );
        vm.expectRevert();
        evidence.requireCurrentEntropySelection();
        require(adapter.finalityState(1).dataHash == before);
    }

    function testPinnedDependenciesAndChainChangeReject() public {
        address[4] memory targets =
            [address(core), address(metadata), address(entropy), address(membership)];
        for (uint256 i; i < 4; ++i) {
            bytes memory original = targets[i].code;
            vm.etch(targets[i], hex"60006000fd");
            vm.expectRevert();
            evidence.finalityComponentFacts(FAMILY, _scope());
            vm.etch(targets[i], original);
        }
        vm.chainId(block.chainid + 1);
        vm.expectRevert();
        evidence.finalityComponentFacts(FAMILY, _scope());
    }

    function testConstructorRejectsWrongReciprocalMembership() public {
        EntropyFinalityMembershipBoundary wrong =
            new EntropyFinalityMembershipBoundary(address(core), address(entropy));
        vm.expectRevert();
        new StreamFinalityEntropyEvidenceProvider(
            address(core), address(metadata), address(entropy), address(wrong), 500000, 2000000
        );
    }

    function testConcreteProductsFitEip170AndKeepExistingInterfaces() public view {
        require(address(entropy).code.length <= 24576 && address(evidence).code.length <= 24576);
        require(address(adapter).code.length <= 24576);
        require(entropy.supportsInterface(type(IStreamEntropyCoordinator).interfaceId));
        require(entropy.supportsInterface(type(IStreamEntropyView).interfaceId));
        require(entropy.supportsInterface(type(IStreamEntropyFinalityPolicy).interfaceId));
        require(!entropy.supportsInterface(0xffffffff) && !evidence.supportsInterface(0xffffffff));
    }

    function testThresholdSafeAllNewPolicyAndProviderCalls() public {
        core.registerToken(1);
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x5AFE01;
        keys[1] = 0x5AFE02;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 7351);
        string[13] memory getters = [
            "core()",
            "coreCodeHash()",
            "metadataHost()",
            "metadataHostCodeHash()",
            "entropyCoordinator()",
            "entropyCoordinatorCodeHash()",
            "scopeMembershipHost()",
            "scopeMembershipHostCodeHash()",
            "deploymentChainId()",
            "readGas()",
            "sourceGas()",
            "coordinatorModuleVersion()",
            "coordinatorModuleManifestHash()"
        ];
        for (uint256 i; i < getters.length; ++i) {
            require(
                executeSafe(
                    account,
                    keys,
                    address(evidence),
                    0,
                    abi.encodeWithSelector(bytes4(keccak256(bytes(getters[i])))),
                    0
                )
            );
        }
        require(
            executeSafe(
                account,
                keys,
                address(evidence),
                0,
                abi.encodeCall(
                    evidence.supportsInterface,
                    (type(IStreamFinalityEntropyEvidenceBinding).interfaceId)
                ),
                0
            )
        );
        require(
            executeSafe(
                account,
                keys,
                address(evidence),
                0,
                abi.encodeCall(evidence.componentHost, (FAMILY)),
                0
            )
        );
        require(
            executeSafe(
                account,
                keys,
                address(evidence),
                0,
                abi.encodeCall(evidence.finalityComponentFacts, (FAMILY, _scope())),
                0
            )
        );
        require(
            executeSafe(
                account,
                keys,
                address(evidence),
                0,
                abi.encodeCall(evidence.requireCurrentEntropySelection, ()),
                0
            )
        );
        require(
            executeSafe(
                account,
                keys,
                address(entropy),
                0,
                abi.encodeCall(entropy.entropyPolicyFrozen, (1)),
                0
            )
        );
        require(account.nonce() == 18, "all18 actual Safe transactions");
    }

    function testColdPolicyAndEvidenceReadCapacity() public {
        core.registerToken(1);
        safeVm.cool(address(entropy));
        uint256 start = gasleft();
        (bool ok, bytes memory raw) = address(entropy).staticcall{ gas: 500000 }(
            abi.encodeCall(entropy.entropyPolicyFrozen, (1))
        );
        emit log_named_uint("cold named coordinator policy call", start - gasleft());
        require(ok && raw.length == 160);
        safeVm.cool(address(core));
        safeVm.cool(address(metadata));
        safeVm.cool(address(entropy));
        safeVm.cool(address(membership));
        safeVm.cool(address(evidence));
        start = gasleft();
        (ok, raw) = address(evidence).staticcall{ gas: 3000000 }(
            abi.encodeCall(evidence.finalityComponentFacts, (FAMILY, _scope()))
        );
        emit log_named_uint("five named cold source evidence call", start - gasleft());
        require(ok && raw.length == 128);
    }

    function testFuzzFrozenPolicyRetainsCompleteDeclaredValues(
        bytes32 salt,
        uint64 timeout,
        bool publicRequests
    ) public {
        timeout = timeout == 0 ? 1 : timeout;
        entropy.configureCollection(1, address(random), salt, publicRequests, timeout);
        bytes32 before = _policy();
        core.registerToken(1);
        require(before != 0 && _policy() == before);
        (bool frozen,,,,) = entropy.entropyPolicyFrozen(1);
        require(frozen);
    }

    function _raise(bytes32 id, uint256 next) private {
        (uint256 value, uint256 floor, uint64 wall, uint64 revision) = entropy.timeParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0xd14cc3d71aa1ccb50b6f723d516042b10a7ef31958f86ccb049a09dbcfefff24),
                block.chainid,
                address(entropy),
                id
            )
        );
        bytes32 domain = 0x26290762a61f3dda3fad05a62e5a95dcb1c59db2eaf506cb363c2aa2ab7b8384;
        this.setCurrentAction(
            true,
            keccak256(abi.encode(id, next)),
            1,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, wall, revision)),
            keccak256(abi.encode(domain, scope, next, floor, wall, revision + 1))
        );
        entropy.raiseTimeParameter(id, next);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
