// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import {
    StreamEntropyProviderInstant
} from "../../../smart-contracts/domains/entropy/StreamEntropyProviderInstant.sol";
import "./EntropyPolicyImportFixtures.sol";
import {
    IStreamEntropyPolicyContinuity as C
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyCollectionPolicy as P
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCollectionPolicy.sol";
import {
    IStreamEntropyRecoveryPolicies as RP
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";

interface EntropyImportVm {
    function mockCall(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
    function cool(address target) external;
}

/// @notice Actual import/export/state workers, typed original storage/Core/registry/relay seams.
/// @dev No actual Artist signatures, Core pointer governance, origin admissions, or provider requests.
contract StreamEntropyPolicyImportTest is CharacterizationTestBase, EntropyTimeAuthorityFixture {
    bytes32 private constant MANIFEST = keccak256("import unit manifest");
    EntropyImportRegistryFixture private registry;
    EntropyImportCoreFixture private core;
    EntropyPolicyImportHostFixture private source;
    EntropyPolicyImportHostFixture private candidate;
    C private target;
    uint256 private nonce;

    event log_named_uint(string key, uint256 value);

    function setUp() public {
        registry = new EntropyImportRegistryFixture(address(this));
        core = new EntropyImportCoreFixture(address(registry));
        source = _host();
        candidate = _host();
        target = C(address(candidate));
        core.select(address(source), 7);
    }

    function testEmptyInventoryBeginHashExactClassSealActivationAndLatchedReady() public {
        _begin(candidate, source);
        C.ImportReceipt memory r = target.entropyPolicyImport();
        require(
            r.nonce == 1 && r.state == C.ImportState.STAGING && r.count == 0 && r.nextIndex == 0,
            "staging"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_POLICY_IMPORT_V1"),
                block.chainid,
                address(candidate),
                address(candidate).codehash,
                address(core),
                uint64(1),
                address(source),
                address(source).codehash,
                uint64(7),
                r.count,
                r.serial,
                r.idDigest,
                MANIFEST
            )
        );
        require(
            r.importHash == expected && r.beginActionId != 0 && r.sealActionId == 0
                && !_ready(target, r),
            "begin evidence"
        );
        _seal(candidate);
        require(_ready(target, r), "sealed readiness");
        _activate(candidate, 8);
        r = target.entropyPolicyImport();
        require(
            r.state == C.ImportState.ACTIVE && r.activationActionId != 0 && !_ready(target, r),
            "active receipt, sealed-only admission"
        );
        source.seedPolicy(_disabled(address(source), 17));
        candidate.operational();
        require(
            keccak256(abi.encode(target.entropyPolicyImport())) == keccak256(abi.encode(r)),
            "active receipt must latch"
        );
    }

    function testWrongClassWrongActionAndMalformedAuthorityRollbackBegin() public {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportTransition(address(source), MANIFEST);
        this.setCurrentAction(true, bytes32(uint256(1)), 3, scope, oldHash, newHash);
        _reject(
            address(candidate),
            abi.encodeCall(C.beginEntropyPolicyImport, (address(source), MANIFEST))
        );
        this.setCurrentAction(true, bytes32(uint256(1)), 1, scope, oldHash, bytes32(uint256(1)));
        _reject(
            address(candidate),
            abi.encodeCall(C.beginEntropyPolicyImport, (address(source), MANIFEST))
        );
        this.setCurrentAction(true, bytes32(uint256(1)), 1, scope, oldHash, newHash);
        this.setResponseMode(ResponseMode.NonCanonicalExecuting);
        _reject(
            address(candidate),
            abi.encodeCall(C.beginEntropyPolicyImport, (address(source), MANIFEST))
        );
        require(target.entropyPolicyImport().state == C.ImportState.NONE, "failed begin wrote");
        this.setResponseMode(ResponseMode.Canonical);
        target.beginEntropyPolicyImport(address(source), MANIFEST);
        require(target.entropyPolicyImport().beginActionId == bytes32(uint256(1)), "exact retry");
    }

    function testConsumedBeginActionCannotAuthorizeSealAndNoSessionResetExists() public {
        _begin(candidate, source);
        bytes32 action = target.entropyPolicyImport().beginActionId;
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportSealTransition();
        this.setCurrentAction(true, action, 1, scope, oldHash, newHash);
        _reject(address(candidate), abi.encodeCall(C.sealEntropyPolicyImport, ()));
        _reject(
            address(candidate),
            abi.encodeCall(C.beginEntropyPolicyImport, (address(source), MANIFEST))
        );
        require(target.entropyPolicyImport().state == C.ImportState.STAGING, "session altered");
        _seal(candidate);
    }

    function testIrreversibleUsedLatchBlocksVirginLookingCandidate() public {
        candidate.markUsed();
        (uint256 count,,) = candidate.entropyPolicyInventory();
        require(count == 0, "no configuration needed for used latch");
        _reject(
            address(candidate),
            abi.encodeCall(C.entropyPolicyImportTransition, (address(source), MANIFEST))
        );
        require(target.entropyPolicyImport().state == C.ImportState.NONE, "invalid session");
    }

    function testPartialDisabledCopyPreservesOriginalReceiptsAndBlocksMutation() public {
        source.seedPolicy(_disabled(address(source), 0));
        source.seedPolicy(_disabled(address(source), 9));
        C.PolicyExport memory original = source.exportEntropyPolicy(0);
        _begin(candidate, source);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (1)));
        vm.recordLogs();
        target.importNextEntropyPolicy(0);
        _importedEvent(vm.getRecordedLogs(), original);
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(0)))
                == keccak256(abi.encode(original)),
            "exact policy copy"
        );
        (bytes32 importHash, bytes32 exportHash, address origin, bytes32 originHash, bytes32 hash) =
            target.importedEntropyPolicy(0);
        require(
            importHash == target.entropyPolicyImport().importHash
                && exportHash == keccak256(abi.encode(original)) && origin == address(source)
                && originHash == address(source).codehash && hash == original.record.policyHash,
            "generation receipt"
        );
        _reject(address(candidate), abi.encodeCall(candidate.markUsed, ()));
        _reject(address(candidate), abi.encodeCall(candidate.changeFee, (0, 1)));
        _reject(address(candidate), abi.encodeCall(C.importedEntropyPolicy, (9)));
        _reject(address(candidate), abi.encodeCall(C.entropyPolicyImportSealTransition, ()));
        target.importNextEntropyPolicy(1);
        require(target.entropyPolicyImport().requiredRelayCount == 0, "disabled route-free");
        _seal(candidate);
        _activate(candidate, 8);
    }

    function testLegacyDeclaredAndUndeclaredPoliciesRetainHashesAndBothRequireRoutes() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 0, true));
        source.seedPolicy(_legacy(address(provider), 4, false));
        C.PolicyExport memory declared = source.exportEntropyPolicy(0);
        C.PolicyExport memory undeclared = source.exportEntropyPolicy(4);
        require(
            declared.record.policyHash != 0 && undeclared.record.policyHash == 0
                && !undeclared.policy.reveal.declared,
            "legacy availability"
        );
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        target.importNextEntropyPolicy(1);
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(0)))
                    == keccak256(abi.encode(declared))
                && keccak256(abi.encode(candidate.exportEntropyPolicy(4)))
                    == keccak256(abi.encode(undeclared)),
            "legacy tuple exact"
        );
        require(target.entropyPolicyImport().requiredRelayCount == 2, "both async routes");
        _reject(address(candidate), abi.encodeCall(C.entropyPolicyImportSealTransition, ()));
        _route(source, candidate, 0);
        _route(source, candidate, 4);
        _seal(candidate);
        _activate(candidate, 8);
    }

    function testNoCopiedLifecycleAdmissionAndStagingCannotAddProvider() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        source.seedPolicy(_legacy(address(provider), 1, true));
        _begin(candidate, source);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        _reject(
            address(candidate),
            abi.encodeCall(candidate.activateEntropyProvider, (address(provider), "staging"))
        );
        require(target.entropyPolicyImport().nextIndex == 0, "partial policy");
        _reject(address(candidate), abi.encodeCall(C.importedEntropyPolicy, (1)));
    }

    function testInstantNotRequiredIsRouteFreeButAsyncNotRequiredStillNeedsRoute() public {
        MockStreamEntropyProvider asyncProvider = new MockStreamEntropyProvider(address(source));
        StreamEntropyProviderInstant instantProvider =
            new StreamEntropyProviderInstant(address(source));
        _admitEntropyProvider(address(candidate), address(asyncProvider));
        _admitEntropyProvider(address(candidate), address(instantProvider));
        C.PolicyExport memory asynchronous = _legacy(address(asyncProvider), 1, true);
        asynchronous.policy.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        source.seedPolicy(_makeExplicit(asynchronous));
        C.PolicyExport memory instant;
        instant.collectionId = 2;
        instant.policy.mode = P.Mode.INSTANT;
        instant.policy.securityClass = P.SecurityClass.LOW_SECURITY;
        instant.policy.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        instant.policy.provider = address(instantProvider);
        instant.providerCodeHash = address(instantProvider).codehash;
        instant.providerConfigHash = instantProvider.streamEntropyProviderConfigHash();
        instant.record.providerEpoch = 1;
        source.seedPolicy(_makeExplicit(instant));
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        target.importNextEntropyPolicy(1);
        require(target.entropyPolicyImport().requiredRelayCount == 1, "mode-specific route count");
        _reject(address(candidate), abi.encodeCall(C.confirmEntropyRelayRoute, (2)));
        _route(source, candidate, 1);
        _seal(candidate);
        _activate(candidate, 8);
    }

    function testLocallyAdmittedProviderWithWrongUltimateCallerCannotImport() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(candidate));
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 1, true));
        _begin(candidate, source);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        require(target.entropyPolicyImport().nextIndex == 0, "wrong caller installed");
    }

    function testRouteWrongGenerationAndDuplicateCannotInflateConfirmedCount() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 1, true));
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        bytes32 hash = source.exportEntropyPolicy(1).record.policyHash;
        source.admitRoute(1, address(candidate), bytes32(uint256(1)), hash);
        _reject(address(candidate), abi.encodeCall(C.confirmEntropyRelayRoute, (1)));
        require(target.entropyPolicyImport().confirmedRelayCount == 0, "wrong generation counted");
        _route(source, candidate, 1);
        _reject(address(candidate), abi.encodeCall(C.confirmEntropyRelayRoute, (1)));
        require(target.entropyPolicyImport().confirmedRelayCount == 1, "duplicate count");
    }

    function testSourceFeeSerialChangeInvalidatesRemainingCopyAndSeal() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 1, true));
        source.seedPolicy(_legacy(address(provider), 2, true));
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        source.changeFee(1, 30);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (1)));
        _reject(address(candidate), abi.encodeCall(C.entropyPolicyImportSealTransition, ()));
        require(target.entropyPolicyImport().nextIndex == 1, "stale session advanced");
    }

    function testSourceEligibilityAndRuntimeAndPointerRevisionRemainAuthenticated() public {
        source.seedPolicy(_disabled(address(source), 1));
        _begin(candidate, source);
        registry.admit(address(source), false);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        registry.admit(address(source), true);
        core.select(address(source), 8);
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        core.select(address(source), 7);
        bytes memory oldCode = address(source).code;
        vm.etch(address(source), hex"00");
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        vm.etch(address(source), oldCode);
        target.importNextEntropyPolicy(0);
    }

    function testMalformedExportRollsBackAndExactNextIndexCanRetry() public {
        source.seedPolicy(_disabled(address(source), 1));
        C.PolicyExport memory p = source.exportEntropyPolicy(1);
        _begin(candidate, source);
        EntropyImportVm mockVm = EntropyImportVm(address(vm));
        mockVm.mockCall(
            address(source),
            abi.encodeCall(C.exportEntropyPolicy, (1)),
            bytes.concat(abi.encode(p), bytes32(0))
        );
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        mockVm.clearMockedCalls();
        p.record.artistConsentRecord = 0;
        mockVm.mockCall(address(source), abi.encodeCall(C.exportEntropyPolicy, (1)), abi.encode(p));
        _reject(address(candidate), abi.encodeCall(C.importNextEntropyPolicy, (0)));
        mockVm.clearMockedCalls();
        require(target.entropyPolicyImport().nextIndex == 0, "malformed wrote state");
        target.importNextEntropyPolicy(0);
        require(target.entropyPolicyImport().nextIndex == 1, "retry failed");
    }

    function testActivationRequiresExactNextCoreRevisionAndFreshClassThreeAction() public {
        _begin(candidate, source);
        _seal(candidate);
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            target.entropyPolicyImportActivationTransition();
        this.setCurrentAction(true, _actionId(), 3, scope, oldHash, newHash);
        _reject(address(candidate), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        core.select(address(candidate), 9);
        _reject(address(candidate), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        core.select(address(candidate), 8);
        this.setCurrentAction(true, _actionId(), 1, scope, oldHash, newHash);
        _reject(address(candidate), abi.encodeCall(C.activateEntropyPolicyImport, ()));
        require(
            target.entropyPolicyImport().state == C.ImportState.SEALED, "failed activation wrote"
        );
        this.setCurrentAction(true, _actionId(), 3, scope, oldHash, newHash);
        target.activateEntropyPolicyImport();
        require(target.entropyPolicyImport().state == C.ImportState.ACTIVE, "exact activation");
    }

    function testFrozenRecoveryDefinitionKeepsFullOriginalTermsAndSharedBinding() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        MockStreamEntropyProvider recoveryProvider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(candidate), address(provider));
        _admitEntropyProvider(address(candidate), address(recoveryProvider));
        C.RecoveryExport memory recovery = _recovery(address(recoveryProvider));
        source.seedRecovery(recovery);
        C.PolicyExport memory p = _legacy(address(provider), 1, true);
        p.policy.recoveryPolicyId = recovery.policyId;
        p.policy.maxFreshRecoveryAttempts = 1;
        p.recovery.policyId = recovery.policyId;
        p.recovery.policyHash = recovery.policyHash;
        p.recovery.maxFreshRecoveryAttempts = 1;
        p.recovery.revision = 4;
        p.recovery.lastActionId = keccak256("original binding action");
        source.seedPolicy(p);
        p.collectionId = 2;
        source.seedPolicy(p);
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        target.importNextEntropyPolicy(1);
        require(
            keccak256(abi.encode(candidate.exportEntropyRecovery(recovery.policyId)))
                == keccak256(abi.encode(source.exportEntropyRecovery(recovery.policyId))),
            "full recovery exact"
        );
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(1)))
                == keccak256(abi.encode(source.exportEntropyPolicy(1))),
            "binding exact"
        );
        _route(source, candidate, 1);
        _route(source, candidate, 2);
        _seal(candidate);
        _activate(candidate, 8);
    }

    function testSuccessorOfSuccessorRetainsUltimateOriginAndLegacyPolicyHash() public {
        MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 1, true));
        C.PolicyExport memory original = source.exportEntropyPolicy(1);
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        _route(source, candidate, 1);
        _seal(candidate);
        _activate(candidate, 8);
        EntropyPolicyImportHostFixture third = _host();
        _admitEntropyProvider(address(third), address(provider));
        _begin(third, candidate);
        C(address(third)).importNextEntropyPolicy(0);
        _route(source, third, 1);
        _seal(third);
        _activate(third, 9);
        require(
            keccak256(abi.encode(third.exportEntropyPolicy(1))) == keccak256(abi.encode(original)),
            "ultimate origin lost"
        );
    }

    /// @dev Capacity of the actual storage export/import workers, with typed source setup and
    /// authority. This is not a gas claim for actual Core, Artist or origin route admission.
    function testCold32StepRecoveryExportFailsClosedThenSameImportRetriesAfterGovernedRaise()
        public
    {
        address[] memory providers = new address[](32);
        for (uint256 i; i < providers.length; ++i) {
            providers[i] = address(new MockStreamEntropyProvider(address(source)));
            _admitEntropyProvider(address(candidate), providers[i]);
        }
        C.RecoveryExport memory recovery = _recovery(providers[0]);
        recovery.policy.maxFreshRecoveryAttempts = 32;
        recovery.policy.steps = new RP.FreshRecoveryStep[](32);
        for (uint256 i; i < providers.length; ++i) {
            recovery.policy.steps[i] = RP.FreshRecoveryStep(
                providers[i],
                uint32(i + 2),
                MockStreamEntropyProvider(providers[i]).streamEntropyProviderConfigHash(),
                uint64(i + 12),
                i % 2 == 0
            );
        }
        recovery.policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(source),
                recovery.policyId,
                recovery.policy.maxFreshRecoveryAttempts,
                recovery.policy.incidentDeclarerRole,
                recovery.policy.reasonSchemaHash,
                recovery.policy.policyManifestHash,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"),
                        recovery.policy.steps
                    )
                )
            )
        );
        source.seedRecovery(recovery);
        C.PolicyExport memory p = _legacy(providers[0], 1, true);
        p.policy.recoveryPolicyId = recovery.policyId;
        p.policy.maxFreshRecoveryAttempts = 32;
        p.recovery.policyId = recovery.policyId;
        p.recovery.policyHash = recovery.policyHash;
        p.recovery.maxFreshRecoveryAttempts = 32;
        p.recovery.revision = 4;
        p.recovery.lastActionId = keccak256("32-step original binding action");
        source.seedPolicy(p);
        _begin(candidate, source);
        bytes32 receiptBefore = keccak256(abi.encode(target.entropyPolicyImport()));
        bytes memory exportCall = abi.encodeCall(C.exportEntropyRecovery, (recovery.policyId));

        // cool clears this account's accessed storage, including all 96 distinct step slots.
        EntropyImportVm(address(vm)).cool(address(source));
        uint256 before = gasleft();
        (bool ok, bytes memory data) = address(source).staticcall{ gas: 100000 }(exportCall);
        emit log_named_uint("32-step cold recovery export at 100k: caller gas", before - gasleft());
        require(!ok && data.length == 0, "cold full export exceeds genesis AUTH cap");

        EntropyImportVm(address(vm)).cool(address(source));
        before = gasleft();
        (ok, data) = address(source).staticcall{ gas: 400000 }(exportCall);
        uint256 exportGas = before - gasleft();
        emit log_named_uint("32-step cold recovery export at 400k: caller gas", exportGas);
        emit log_named_uint("32-step recovery export return bytes", data.length);
        require(
            ok && data.length == 5696 && keccak256(data) == keccak256(abi.encode(recovery)),
            "exact full recovery export"
        );

        _coolImport(providers);
        vm.expectRevert(
            abi.encodeWithSelector(C.EntropyPolicyImportDependency.selector, address(source))
        );
        target.importNextEntropyPolicy(0);
        require(
            keccak256(abi.encode(target.entropyPolicyImport())) == receiptBefore,
            "failed read changed receipt"
        );
        (uint256 count,,) = candidate.entropyPolicyInventory();
        require(count == 0 && candidate.epochs(1) == 0, "failed read installed collection");
        _reject(address(candidate), abi.encodeCall(C.importedEntropyPolicy, (1)));
        _reject(address(candidate), abi.encodeCall(C.exportEntropyRecovery, (recovery.policyId)));

        bytes32 auth = keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
        _raiseAuth(auth, 200000);
        _raiseAuth(auth, 400000);
        (uint256 cap, uint256 floor, uint8 failureClass, uint64 revision) =
            candidate.gasParameterInfo(auth);
        require(
            cap == 400000 && floor == 100000 && failureClass == 2 && revision == 3,
            "governed raises preserve genesis floor"
        );
        require(
            keccak256(abi.encode(target.entropyPolicyImport())) == receiptBefore,
            "raise changed import session"
        );
        _coolImport(providers);
        before = gasleft();
        target.importNextEntropyPolicy(0);
        emit log_named_uint("32-step cold exact import after AUTH raise gas", before - gasleft());
        require(target.entropyPolicyImport().nextIndex == 1, "same index did not retry");
        require(
            keccak256(abi.encode(candidate.exportEntropyRecovery(recovery.policyId)))
                == keccak256(abi.encode(recovery)),
            "32 steps imported exactly"
        );
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(1)))
                == keccak256(abi.encode(source.exportEntropyPolicy(1))),
            "same policy and binding imported"
        );
        _route(source, candidate, 1);
        _seal(candidate);
        _activate(candidate, 8);
    }

    function _raiseAuth(bytes32 id, uint256 next) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            candidate.gasParameterTransition(id, next);
        this.setCurrentAction(true, _actionId(), 1, scope, oldHash, newHash);
        candidate.raiseGasParameter(id, next);
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _coolImport(address[] memory providers) private {
        EntropyImportVm coldVm = EntropyImportVm(address(vm));
        coldVm.cool(address(source));
        coldVm.cool(address(candidate));
        coldVm.cool(address(core));
        coldVm.cool(address(registry));
        coldVm.cool(address(W));
        coldVm.cool(address(L));
        for (uint256 i; i < providers.length; ++i) {
            coldVm.cool(providers[i]);
        }
    }

    function testImportedReauthorRejectsOriginalCallerAtomicallyThenLocalProviderReplacementWorks()
        public
    {
        MockStreamEntropyProvider original = new MockStreamEntropyProvider(address(source));
        _activeLegacy(original);
        C.PolicyExport memory before_ = candidate.exportEntropyPolicy(1);
        bytes32 beforeHash = keccak256(abi.encode(before_));
        bytes32 salt = keccak256("local reauthored salt");
        _reject(
            address(candidate),
            abi.encodeCall(
                candidate.configureCollection, (1, address(original), salt, true, uint64(10))
            )
        );
        _reject(
            address(candidate),
            abi.encodeCall(
                candidate.configureCollectionRevealPolicy,
                (1, uint8(0), keccak256("ROLE_ENTROPY_REVEAL_OWNER"), uint64(12), uint256(30))
            )
        );
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(1))) == beforeHash,
            "failed reauthor changed original terms"
        );
        candidate.updateRevealFee(1, 30);
        C.PolicyExport memory feeOnly = candidate.exportEntropyPolicy(1);
        require(
            feeOnly.policyOrigin == address(source)
                && feeOnly.record.policyHash == before_.record.policyHash
                && feeOnly.policy.reveal.revealFeePerTokenWei == 30,
            "fee retune reauthored content"
        );
        MockStreamEntropyProvider local = new MockStreamEntropyProvider(address(candidate));
        _admitEntropyProvider(address(candidate), address(local));
        candidate.configureCollection(1, address(local), salt, true, 10);
        C.PolicyExport memory after_ = candidate.exportEntropyPolicy(1);
        require(
            after_.policyOrigin == address(candidate)
                && after_.policyOriginCodeHash == address(candidate).codehash
                && after_.policy.provider == address(local) && after_.record.providerEpoch == 2
                && after_.record.policyHash != before_.record.policyHash
                && after_.record.policyHash != 0,
            "local replacement did not reauthor"
        );
    }

    function testReauthorChecksEveryUsedRecoveryProviderAndIgnoresUnusedSuffix() public {
        MockStreamEntropyProvider original = new MockStreamEntropyProvider(address(source));
        _activeLegacy(original);
        MockStreamEntropyProvider local = new MockStreamEntropyProvider(address(candidate));
        C.RecoveryExport memory recovery = _recovery(address(local));
        recovery.policy.maxFreshRecoveryAttempts = 2;
        recovery.policy.steps = new RP.FreshRecoveryStep[](2);
        recovery.policy.steps[0] = RP.FreshRecoveryStep(
            address(local), 2, local.streamEntropyProviderConfigHash(), 10, true
        );
        recovery.policy.steps[1] = RP.FreshRecoveryStep(
            address(original), 3, original.streamEntropyProviderConfigHash(), 10, false
        );
        // Typed definition seeding isolates the caller guard; no Artist or definition-authority claim.
        candidate.seedRecovery(recovery);
        candidate.reauthorProviders(1, address(local), recovery.policyId, 1);
        _reject(
            address(candidate),
            abi.encodeCall(
                candidate.reauthorProviders, (1, address(local), recovery.policyId, uint16(2))
            )
        );
        candidate.reauthorProviders(1, address(0), bytes32(0), 0);
    }

    function testReauthorRejectsDirtyOrOversizedCoordinatorWordAndExactReadRetries() public {
        MockStreamEntropyProvider original = new MockStreamEntropyProvider(address(source));
        _activeLegacy(original);
        MockStreamEntropyProvider local = new MockStreamEntropyProvider(address(candidate));
        EntropyImportVm mockVm = EntropyImportVm(address(vm));
        bytes memory callData = abi.encodeWithSignature("coordinator()");
        mockVm.mockCall(
            address(local),
            callData,
            abi.encode((uint256(1) << 160) | uint256(uint160(address(candidate))))
        );
        _reject(
            address(candidate),
            abi.encodeCall(candidate.reauthorProviders, (1, address(local), bytes32(0), uint16(0)))
        );
        mockVm.clearMockedCalls();
        mockVm.mockCall(address(local), callData, abi.encode(address(candidate), uint256(0)));
        _reject(
            address(candidate),
            abi.encodeCall(candidate.reauthorProviders, (1, address(local), bytes32(0), uint16(0)))
        );
        mockVm.clearMockedCalls();
        candidate.reauthorProviders(1, address(local), bytes32(0), 0);
    }

    function _activeLegacy(MockStreamEntropyProvider provider) private {
        _admitEntropyProvider(address(candidate), address(provider));
        source.seedPolicy(_legacy(address(provider), 1, true));
        _begin(candidate, source);
        target.importNextEntropyPolicy(0);
        _route(source, candidate, 1);
        _seal(candidate);
        _activate(candidate, 8);
    }

    function _host() private returns (EntropyPolicyImportHostFixture h) {
        h = new EntropyPolicyImportHostFixture(IStreamCore(address(core)), address(this));
        registry.admit(address(h), true);
    }

    function _importedEvent(Vm.Log[] memory logs, C.PolicyExport memory p) private view {
        C.ImportReceipt memory r = target.entropyPolicyImport();
        require(logs.length == 1 && logs[0].emitter == address(candidate), "import event emitter");
        require(
            logs[0].topics.length == 4
                && logs[0].topics[0]
                    == keccak256(
                        "EntropyPolicyImported(uint16,bytes32,uint256,address,uint256,bytes32,bytes32,bytes32)"
                    ) && logs[0].topics[1] == r.importHash
                && logs[0].topics[2] == bytes32(p.collectionId)
                && logs[0].topics[3] == bytes32(uint256(uint160(p.policyOrigin))),
            "import event identity"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1),
                        uint256(0),
                        p.policyOriginCodeHash,
                        p.record.policyHash,
                        r.exportDigest
                    )
                ),
            "import event contents"
        );
    }

    function _begin(EntropyPolicyImportHostFixture h, EntropyPolicyImportHostFixture previous)
        private
    {
        C c = C(address(h));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            c.entropyPolicyImportTransition(address(previous), MANIFEST);
        this.setCurrentAction(true, _actionId(), 1, scope, oldHash, newHash);
        c.beginEntropyPolicyImport(address(previous), MANIFEST);
    }

    function _seal(EntropyPolicyImportHostFixture h) private {
        C c = C(address(h));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = c.entropyPolicyImportSealTransition();
        this.setCurrentAction(true, _actionId(), 1, scope, oldHash, newHash);
        c.sealEntropyPolicyImport();
    }

    function _activate(EntropyPolicyImportHostFixture h, uint64 revision) private {
        C c = C(address(h));
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            c.entropyPolicyImportActivationTransition();
        core.select(address(h), revision);
        this.setCurrentAction(true, _actionId(), 3, scope, oldHash, newHash);
        c.activateEntropyPolicyImport();
    }

    function _route(
        EntropyPolicyImportHostFixture origin,
        EntropyPolicyImportHostFixture h,
        uint256 id
    ) private {
        C c = C(address(h));
        origin.admitRoute(
            id,
            address(h),
            c.entropyPolicyImport().importHash,
            h.exportEntropyPolicy(id).record.policyHash
        );
        c.confirmEntropyRelayRoute(id);
    }

    function _ready(C c, C.ImportReceipt memory r) private view returns (bool) {
        return c.entropyPolicyImportReady(
            r.predecessor, r.predecessorCodeHash, r.pointerRevision, r.count, r.serial, r.idDigest
        );
    }

    function _actionId() private returns (bytes32) {
        return keccak256(abi.encode("import unit action", ++nonce));
    }

    function _reject(address host, bytes memory data) private {
        (bool ok,) = host.call(data);
        require(!ok, "expected rejection");
    }

    function _disabled(address origin, uint256 id) private view returns (C.PolicyExport memory p) {
        p.collectionId = id;
        p.profile = C.PolicyProfile.EXPLICIT;
        p.policyOrigin = origin;
        p.policyOriginCodeHash = origin.codehash;
        p.policy.mode = P.Mode.DISABLED;
        p.policy.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        p.record.configured = true;
        p.record.explicitPolicy = true;
        p.record.frozen = true;
        p.record.mode = P.Mode.DISABLED;
        p.record.renderRequirement = P.RenderRequirement.NOT_REQUIRED;
        p.record.revision = 3;
        p.record.lastActionId = keccak256(abi.encode("original action", id));
        p.record.artistConsentRecord = keccak256(abi.encode("original Artist evidence", id));
        p.record.policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
                block.chainid,
                origin,
                address(core),
                id,
                P.Mode.DISABLED,
                P.SecurityClass.HIGH_ASSURANCE,
                P.RenderRequirement.NOT_REQUIRED,
                address(0),
                bytes32(0),
                bytes32(0),
                uint32(0),
                bytes32(0),
                false,
                uint64(0),
                false,
                uint8(0),
                bytes32(0),
                uint64(0),
                bytes32(0),
                bytes32(0),
                uint16(0)
            )
        );
        p.record.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.record.policyHash, true)
        );
    }

    function _legacy(address provider, uint256 id, bool declared)
        private
        view
        returns (C.PolicyExport memory p)
    {
        p.collectionId = id;
        p.policy.mode = P.Mode.ASYNC;
        p.policy.provider = provider;
        p.policy.publicRequests = true;
        p.policy.timeoutBlocks = 10;
        p.policy.collectionSalt = keccak256("original salt");
        p.record.providerEpoch = 1;
        p.providerCodeHash = provider.codehash;
        p.providerConfigHash = MockStreamEntropyProvider(provider).streamEntropyProviderConfigHash();
        if (declared) {
            p.policy.reveal.declared = true;
            p.policy.reveal.revealOwnerRole = keccak256("ROLE_ENTROPY_REVEAL_OWNER");
            p.policy.reveal.requestSLOBlocks = 10;
            p.policy.reveal.revealFeePerTokenWei = 29;
        }
    }

    function _recovery(address provider) private view returns (C.RecoveryExport memory r) {
        r.policyId = keccak256("original recovery");
        r.policyOrigin = address(source);
        r.policyOriginCodeHash = address(source).codehash;
        r.revision = 2;
        r.lastActionId = keccak256("original recovery freeze");
        r.policy.exists = true;
        r.policy.frozen = true;
        r.policy.maxFreshRecoveryAttempts = 1;
        r.policy.incidentDeclarerRole = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
        r.policy.reasonSchemaHash = keccak256("reason");
        r.policy.policyManifestHash = keccak256("recovery manifest");
        r.policy.steps = new RP.FreshRecoveryStep[](1);
        r.policy.steps[0] = RP.FreshRecoveryStep(
            provider,
            2,
            MockStreamEntropyProvider(provider).streamEntropyProviderConfigHash(),
            12,
            true
        );
        r.policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(source),
                r.policyId,
                uint16(1),
                r.policy.incidentDeclarerRole,
                r.policy.reasonSchemaHash,
                r.policy.policyManifestHash,
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), r.policy.steps
                    )
                )
            )
        );
    }

    function _makeExplicit(C.PolicyExport memory p) private view returns (C.PolicyExport memory) {
        p.profile = C.PolicyProfile.EXPLICIT;
        p.policyOrigin = address(source);
        p.policyOriginCodeHash = address(source).codehash;
        p.record.configured = true;
        p.record.explicitPolicy = true;
        p.record.frozen = true;
        p.record.mode = p.policy.mode;
        p.record.securityClass = p.policy.securityClass;
        p.record.renderRequirement = p.policy.renderRequirement;
        p.record.revision = 3;
        p.record.lastActionId = keccak256(abi.encode("original action", p.collectionId));
        p.record.artistConsentRecord =
            keccak256(abi.encode("original Artist evidence", p.collectionId));
        p.record.policyHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_COLLECTION_POLICY_V2"),
                block.chainid,
                address(source),
                address(core),
                p.collectionId,
                p.policy.mode,
                p.policy.securityClass,
                p.policy.renderRequirement,
                p.policy.provider,
                p.providerCodeHash,
                p.providerConfigHash,
                p.record.providerEpoch,
                p.policy.collectionSalt,
                p.policy.publicRequests,
                p.policy.timeoutBlocks,
                p.policy.reveal.declared,
                p.policy.reveal.requestMode,
                p.policy.reveal.revealOwnerRole,
                p.policy.reveal.requestSLOBlocks,
                p.recovery.policyId,
                p.recovery.policyHash,
                p.recovery.maxFreshRecoveryAttempts
            )
        );
        p.record.contentStateHash = keccak256(
            abi.encode(keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1"), p.record.policyHash, true)
        );
        return p;
    }
}
