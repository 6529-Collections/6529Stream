// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/EntropyTimeTestMocks.sol";
import "../../mocks/MockStreamEntropyProvider.sol";
import "./EntropyPolicySuccessorFixtures.sol";
import {
    IStreamEntropyPolicyContinuity as CapacityContinuity
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyPolicyContinuity.sol";
import {
    IStreamEntropyOriginRelay as CapacityRelay
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyOriginRelay.sol";
import {
    IStreamEntropyRecoveryPolicies as CapacityRecovery
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamEntropyRecoveryPolicies.sol";
import {
    StreamEntropyPolicyImport
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyImport.sol";
import {
    StreamEntropyRelayAdmission
} from "../../../smart-contracts/domains/entropy/StreamEntropyRelayAdmission.sol";
import {
    StreamEntropyProviderLifecycle
} from "../../../smart-contracts/domains/entropy/StreamEntropyProviderLifecycle.sol";
import {
    StreamEntropyRecoveryPolicies
} from "../../../smart-contracts/domains/entropy/StreamEntropyRecoveryPolicies.sol";
import {
    StreamEntropyPolicyImportValidation
} from "../../../smart-contracts/domains/entropy/StreamEntropyPolicyImportValidation.sol";
import {
    StreamEntropyCoordinatorReads
} from "../../../smart-contracts/domains/entropy/StreamEntropyCoordinatorReads.sol";

interface RecoveryCapacityColdVm {
    function cool(address target) external;
}

/// @notice Cold capacity of the actual Coordinator export, import and origin admission paths.
/// @dev Core pointers, Artist, module eligibility and executing governance are typed unit seams.
/// Recovery storage is populated only by genuine public configuration/freeze/binding calls.
/// This is one collection with 32 recovery steps, not a 32-collection inventory or a Safe test.
/// Gas probes use vm.cool within one transaction: storage-cooled evidence, not all-cold accounts.
/// `cool` resets storage access warmth inside this test transaction; measurements do not establish
/// an entirely cold fresh-transaction budget or include its intrinsic gas.
contract StreamEntropyRecoveryAuthCapacityTest is
    CharacterizationTestBase,
    EntropyTimeAuthorityFixture
{
    bytes32 private constant HASH = keccak256("cold production recovery capacity");
    bytes32 private constant POLICY = keccak256("complete 32-step recovery definition");
    bytes32 private constant ROLE = keccak256("ROLE_ENTROPY_INCIDENT_DECLARER");
    bytes32 private constant AUTH = keccak256("6529STREAM_GGP_ENTROPY_RELAY_AUTH_READ_GAS_LIMIT");
    uint256 private constant SUPPORTED_CAP = 400000;
    uint256 private constant EXPORT_BYTES = 576 + 32 * 160;

    EntropyPolicySuccessorCoreFixture private core;
    EntropySuccessorModuleFixture private modules;
    MockEntropyRoleRegistry public roleRegistry;
    StreamEntropyCoordinator private source;
    StreamEntropyCoordinator private candidate;
    address[] private providers;
    uint256 private actionNonce;

    event log_named_uint(string key, uint256 value);

    function setUp() public {
        vm.roll(100);
        core = new EntropyPolicySuccessorCoreFixture();
        modules = new EntropySuccessorModuleFixture(address(this));
        roleRegistry = new MockEntropyRoleRegistry(address(this));
        source = _deploy();
        EntropyCollectionPolicyArtistFixture artist =
            new EntropyCollectionPolicyArtistFixture(address(core));
        core.wire(source, address(artist), address(modules));
        candidate = _deploy();
        CapacityRecovery.FreshRecoveryStep[] memory steps =
            new CapacityRecovery.FreshRecoveryStep[](32);
        for (uint256 i; i < 32; ++i) {
            MockStreamEntropyProvider provider = new MockStreamEntropyProvider(address(source));
            providers.push(address(provider));
            _admitEntropyProvider(address(source), address(provider));
            _admitEntropyProvider(address(candidate), address(provider));
            steps[i] = CapacityRecovery.FreshRecoveryStep(
                address(provider),
                uint32(i + 3),
                provider.streamEntropyProviderConfigHash(),
                uint64(i + 12),
                i % 2 == 0
            );
        }
        source.configureCollection(1, providers[0], HASH, true, 10);
        source.configureCollectionRevealPolicy(1, 0, keccak256("ROLE_ENTROPY_REVEAL_OWNER"), 10, 0);
        _configureRecovery(steps);
        // The real hook locks the collection; the typed Core retains the original host identity.
        core.registerToken(1, 1, HASH);
    }

    function testColdProduction32StepExportImportAndOriginAdmissionWithGovernedAuthCaps() public {
        _assertCap(source, 100000, 1);
        _assertCap(candidate, 100000, 1);
        (uint256 inventoryCount,,) = source.entropyPolicyInventory();
        require(inventoryCount == 1, "one collection, thirty-two recovery steps");
        bytes memory original = abi.encode(source.exportEntropyRecovery(POLICY));
        require(original.length == EXPORT_BYTES, "complete 5696-byte recovery export");
        bytes32 policyBefore = keccak256(abi.encode(source.exportEntropyPolicy(1)));
        require(!_exportAt(source, 100000, original), "original default fails cold");
        uint256 originalMinimum = _minimumExportCap(source, original);
        emit log_named_uint(
            "original production cold export minimum forwarded gas", originalMinimum
        );

        _begin();
        CapacityContinuity.ImportReceipt memory receipt = candidate.entropyPolicyImport();
        bytes32 untouchedReceipt = keccak256(abi.encode(receipt));
        _failedColdImport(untouchedReceipt);
        _raise(candidate, 200000);
        _failedColdImport(untouchedReceipt);
        _raise(candidate, SUPPORTED_CAP);
        _assertCap(candidate, SUPPORTED_CAP, 3);
        require(
            keccak256(abi.encode(candidate.entropyPolicyImport())) == untouchedReceipt,
            "cap changes preserve original import session"
        );

        _coolGraph();
        uint256 before = gasleft();
        candidate.importNextEntropyPolicy(0);
        emit log_named_uint("actual cold one-policy 32-step import caller gas", before - gasleft());
        require(candidate.entropyPolicyImport().nextIndex == 1, "same index imported");
        require(
            keccak256(abi.encode(candidate.exportEntropyPolicy(1))) == policyBefore,
            "original collection facts retained"
        );
        uint256 importedMinimum = _minimumExportCap(candidate, original);
        emit log_named_uint(
            "imported production cold export minimum forwarded gas", importedMinimum
        );

        // The origin owns an independent AUTH row. Candidate's raise cannot fund origin reads.
        _assertCap(source, 100000, 1);
        _coldAdmissionPreviewFails(receipt.importHash);
        // A warm preview supplies genuine commitments; execution is cooled again below.
        require(_exportAt(source, SUPPORTED_CAP, original), "warm only for transition preview");
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            source.entropyRelayAdmissionTransition(1, address(candidate), receipt.importHash);
        bytes32 admissionAction = _nextAction();
        _failedColdAdmission(receipt.importHash, admissionAction, scope, oldHash, newHash);
        _raise(source, 200000);
        _failedColdAdmission(receipt.importHash, admissionAction, scope, oldHash, newHash);
        _raise(source, SUPPORTED_CAP);
        _assertCap(source, SUPPORTED_CAP, 3);
        (bytes32 nextScope, bytes32 nextOld, bytes32 nextNew) =
            source.entropyRelayAdmissionTransition(1, address(candidate), receipt.importHash);
        require(
            nextScope == scope && nextOld == oldHash && nextNew == newHash,
            "cap repair preserves admission commitments"
        );
        _action(admissionAction, scope, oldHash, newHash, 1);
        _coolGraph();
        before = gasleft();
        source.admitEntropyRelay(1, address(candidate), receipt.importHash);
        emit log_named_uint("actual cold 32-step origin admission caller gas", before - gasleft());
        _clearAction();
        (bytes32 pin, bytes32 imported, bytes32 policyHash) =
            source.entropyRelayAdmission(1, address(candidate));
        require(
            pin == address(candidate).codehash && imported == receipt.importHash
                && policyHash == source.exportEntropyPolicy(1).record.policyHash,
            "exact origin route"
        );
        candidate.confirmEntropyRelayRoute(1);
        _sealAndActivate();
        require(
            candidate.entropyPolicyImport().state == CapacityContinuity.ImportState.ACTIVE,
            "complete import active"
        );
        require(
            keccak256(abi.encode(candidate.exportEntropyRecovery(POLICY))) == keccak256(original),
            "original definition and provenance unchanged"
        );

        // Exact checks at the read site are floor((available-reserve)/64)*63 >= cap.
        // Therefore 400k needs 416400 there for import (10k reserve), 421400 for relay
        // authentication (15k reserve). These exclude earlier work and transaction intrinsic gas.
        emit log_named_uint(
            "400k import AUTH read-site parent requirement",
            10000 + 64 * ((SUPPORTED_CAP + 62) / 63)
        );
        emit log_named_uint(
            "400k relay AUTH read-site parent requirement", 15000 + 64 * ((SUPPORTED_CAP + 62) / 63)
        );
    }

    function _minimumExportCap(StreamEntropyCoordinator host, bytes memory expected)
        private
        returns (uint256 minimum)
    {
        uint256 failing = 200000;
        uint256 passing = SUPPORTED_CAP;
        require(!_exportAt(host, failing, expected), "200k is insufficient cold");
        require(_exportAt(host, passing, expected), "supported 400k returns exact export");
        // Each probe cools the same actual host and every accessed storage slot again.
        // This is a threshold for this exact runtime/state, not a new immutable protocol floor.
        while (passing - failing > 1) {
            uint256 middle = failing + (passing - failing) / 2;
            if (_exportAt(host, middle, expected)) passing = middle;
            else failing = middle;
        }
        require(!_exportAt(host, passing - 1, expected), "minimum minus one fails");
        require(_exportAt(host, passing, expected), "measured minimum succeeds");
        return passing;
    }

    function _exportAt(StreamEntropyCoordinator host, uint256 cap, bytes memory expected)
        private
        returns (bool ok)
    {
        bytes memory callData = abi.encodeCall(CapacityContinuity.exportEntropyRecovery, (POLICY));
        RecoveryCapacityColdVm(address(vm)).cool(address(host));
        bytes memory result;
        uint256 before = gasleft();
        (ok, result) = address(host).staticcall{ gas: cap }(callData);
        uint256 used = before - gasleft();
        if (cap == SUPPORTED_CAP) {
            emit log_named_uint("400k cold production export caller gas", used);
        }
        if (ok) {
            require(
                result.length == EXPORT_BYTES && keccak256(result) == keccak256(expected),
                "exact untruncated production export"
            );
        } else {
            require(result.length == 0, "only exhausted read budget expected");
        }
    }

    function _failedColdImport(bytes32 receiptHash) private {
        _coolGraph();
        vm.expectRevert(
            abi.encodeWithSelector(
                CapacityContinuity.EntropyPolicyImportDependency.selector, address(source)
            )
        );
        candidate.importNextEntropyPolicy(0);
        require(
            keccak256(abi.encode(candidate.entropyPolicyImport())) == receiptHash,
            "failed export leaves receipt untouched"
        );
        (uint256 count,,) = candidate.entropyPolicyInventory();
        require(
            count == 0 && candidate.collectionProviderEpoch(1) == 0,
            "failed export installs no collection"
        );
    }

    function _coldAdmissionPreviewFails(bytes32 importHash) private {
        _coolGraph();
        (bool ok, bytes memory error) = address(source)
            .staticcall(
                abi.encodeCall(
                    CapacityRelay.entropyRelayAdmissionTransition,
                    (1, address(candidate), importHash)
                )
            );
        require(
            !ok
                && keccak256(error)
                    == keccak256(
                        abi.encodeWithSelector(
                            CapacityRelay.EntropyRelayReadFailed.selector, address(source)
                        )
                    ),
            "origin default cannot read complete cold recovery"
        );
    }

    function _failedColdAdmission(
        bytes32 importHash,
        bytes32 actionId,
        bytes32 scope,
        bytes32 oldHash,
        bytes32 newHash
    ) private {
        _action(actionId, scope, oldHash, newHash, 1);
        _coolGraph();
        vm.expectRevert(
            abi.encodeWithSelector(CapacityRelay.EntropyRelayReadFailed.selector, address(source))
        );
        source.admitEntropyRelay(1, address(candidate), importHash);
        _clearAction();
        (bytes32 pin, bytes32 admitted, bytes32 hash) =
            source.entropyRelayAdmission(1, address(candidate));
        require(pin == 0 && admitted == 0 && hash == 0, "failed read installs no route");
        CapacityContinuity.ImportReceipt memory receipt = candidate.entropyPolicyImport();
        require(
            receipt.importHash == importHash && receipt.nextIndex == 1
                && receipt.confirmedRelayCount == 0,
            "failed admission preserves import progress"
        );
    }

    function _configureRecovery(CapacityRecovery.FreshRecoveryStep[] memory steps) private {
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_POLICY_V1"),
                block.chainid,
                address(source),
                POLICY,
                uint16(32),
                ROLE,
                HASH,
                HASH,
                keccak256(
                    abi.encode(keccak256("6529STREAM_ENTROPY_FRESH_RECOVERY_STEPS_V1"), steps)
                )
            )
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            source.freshRecoveryPolicyTransition(POLICY, hash, false);
        _action(_nextAction(), scope, oldHash, newHash, 1);
        source.configureFreshRecoveryPolicy(POLICY, 32, ROLE, HASH, HASH, steps);
        (scope, oldHash, newHash) = source.freshRecoveryPolicyTransition(POLICY, hash, true);
        _action(_nextAction(), scope, oldHash, newHash, 1);
        source.freezeFreshRecoveryPolicy(POLICY);
        (scope, oldHash, newHash) = source.collectionFreshRecoveryTransition(1, 32, POLICY);
        _action(_nextAction(), scope, oldHash, newHash, 1);
        source.configureCollectionFreshRecovery(1, 32, POLICY);
        _clearAction();
    }

    function _deploy() private returns (StreamEntropyCoordinator host) {
        host = new StreamEntropyCoordinator(
            StreamEntropyCoordinator.DeploymentConfig(
                address(core),
                address(this),
                address(roleRegistry),
                EntropyTimeTestConfigs.parameters(),
                HASH,
                "urn:test:cold-recovery-capacity",
                HASH
            )
        );
        modules.setEligible(address(host), true);
    }

    function _raise(StreamEntropyCoordinator host, uint256 next) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = host.gasParameterTransition(AUTH, next);
        _action(_nextAction(), scope, oldHash, newHash, 1);
        host.raiseGasParameter(AUTH, next);
        _clearAction();
    }

    function _assertCap(StreamEntropyCoordinator host, uint256 value, uint64 revision)
        private
        view
    {
        (uint256 current, uint256 floor, uint8 failureClass, uint64 actualRevision) =
            host.gasParameterInfo(AUTH);
        require(
            current == value && floor == 100000 && failureClass == 2 && actualRevision == revision,
            "configured allowance with unchanged immutable floor"
        );
    }

    function _begin() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            candidate.entropyPolicyImportTransition(address(source), HASH);
        _action(_nextAction(), scope, oldHash, newHash, 1);
        candidate.beginEntropyPolicyImport(address(source), HASH);
        _clearAction();
    }

    function _sealAndActivate() private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            candidate.entropyPolicyImportSealTransition();
        _action(_nextAction(), scope, oldHash, newHash, 1);
        candidate.sealEntropyPolicyImport();
        (scope, oldHash, newHash) = candidate.entropyPolicyImportActivationTransition();
        core.select(candidate, core.pointerRevision() + 1);
        _action(_nextAction(), scope, oldHash, newHash, 3);
        candidate.activateEntropyPolicyImport();
        _clearAction();
    }

    function _coolGraph() private {
        RecoveryCapacityColdVm cold = RecoveryCapacityColdVm(address(vm));
        cold.cool(address(source));
        cold.cool(address(candidate));
        cold.cool(address(core));
        cold.cool(address(modules));
        cold.cool(address(roleRegistry));
        cold.cool(address(StreamEntropyPolicyImport));
        cold.cool(address(StreamEntropyRelayAdmission));
        cold.cool(address(StreamEntropyProviderLifecycle));
        cold.cool(address(StreamEntropyRecoveryPolicies));
        cold.cool(address(StreamEntropyPolicyImportValidation));
        cold.cool(address(StreamEntropyCoordinatorReads));
        for (uint256 i; i < providers.length; ++i) {
            cold.cool(providers[i]);
        }
    }

    function _nextAction() private returns (bytes32) {
        return keccak256(abi.encode("capacity action", ++actionNonce));
    }

    function _action(bytes32 id, bytes32 scope, bytes32 oldHash, bytes32 newHash, uint8 cls)
        private
    {
        this.setCurrentAction(true, id, cls, scope, oldHash, newHash);
    }

    function _clearAction() private {
        this.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
