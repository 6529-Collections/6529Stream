// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CanonicalNativeSalesDeploymentFixture
} from "../helpers/CanonicalNativeSalesDeploymentFixture.sol";
import {
    StreamCanonicalNativeSalesDeployment as D
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "../../script/current/StreamCanonicalNativeSalesActivationPlan.sol";
import { StreamCurrentStackPlan } from "../../script/current/StreamCurrentStackPlan.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import {
    IStreamNativeClaimSales as C
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeClaimSales.sol";
import {
    IStreamNativeDutchSales as Dutch
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeDutchSales.sol";
import {
    IStreamDutchPriceSchedule
} from "../../smart-contracts/interfaces/stream/mint/IStreamDutchPriceSchedule.sol";
import {
    IStreamMintManager
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamMintLedger
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol";
import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";
import {
    GovernanceCall,
    GovernanceActionPolicyEntry,
    GovernanceActionStatus
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    IStreamPrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import {
    IStreamNativeSaleBinding
} from "../../smart-contracts/interfaces/stream/revenue/IStreamNativeSaleBinding.sol";
import {
    StreamModuleRegistration,
    ModuleRegistryStatus
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

/// @notice Actual current graph and Safe-governed deployment/activation of canonical native companions.
/// @dev Only the upstream entropy provider is substituted. No paid mint, Floor or live-deployment
/// acceptance is inferred from constructor, registration or sale-configuration success.
contract StreamCanonicalNativeSalesDeploymentTest is CanonicalNativeSalesDeploymentFixture {
    function validateCanonicalSaved(D.Configuration calldata c, D.Products calldata p)
        external
        view
    {
        D.validate(c, p);
    }

    function testCanonicalDeploymentPinsWholeExistingGraphWithoutGrantingAdmission() public view {
        D.Configuration memory c = companionConfiguration;
        D.Products memory p = companionProducts;
        D.validate(c, p);
        require(
            p.chainId == block.chainid && p.configurationHash == keccak256(abi.encode(c)),
            "exact original configuration commitment"
        );
        require(
            D.constructionHash(c, p)
                == keccak256(
                    abi.encode(keccak256("6529STREAM_CANONICAL_NATIVE_SALES_CONSTRUCTION_V1"), c, p)
                ),
            "complete saved construction commitment"
        );
        address[12] memory expected = [
            address(core),
            address(manager),
            address(ledger),
            address(companionRecorder),
            address(primaryResolver),
            address(registry),
            address(factory),
            address(assetPolicy),
            address(revenueEscrow),
            address(artists),
            address(roles),
            address(executor)
        ];
        address[12] memory dependencies = D.dependencies(c);
        for (uint256 i; i < expected.length; ++i) {
            require(
                dependencies[i] == expected[i] && p.dependencyCodeHashes[i] == expected[i].codehash,
                "exact shared dependency and live runtime"
            );
        }
        address[3] memory carriers = D.addresses(p);
        for (uint256 i; i < carriers.length; ++i) {
            require(
                carriers[i].code.length > 0 && carriers[i].code.length <= 24576
                    && carriers[i].codehash == p.codeHashes[i],
                "deployed canonical runtime"
            );
            require(
                registry.moduleRecord(carriers[i]).status == ModuleRegistryStatus.UNKNOWN
                    && !manager.phaseExecutor(1, COMPANION_PHASE, carriers[i]),
                "construction grants no admission or mint authority"
            );
        }
        require(
            p.immediate.owner() == address(executor) && p.claims.owner() == address(executor)
                && p.dutch.owner() == address(executor),
            "explicit deployment ownership handoff"
        );
        (bool enabled,,) = revenueEscrow.creditProducer(address(companionRecorder));
        require(
            !enabled
                && registry.moduleRecord(address(companionRecorder)).status
                    == ModuleRegistryStatus.UNKNOWN,
            "reused Recorder is neither implicitly admitted nor credited"
        );
        require(
            p.immediate.primarySaleSettlement() == address(companionRecorder)
                && p.claims.primarySaleSettlement() == address(companionRecorder)
                && p.dutch.primarySaleSettlement() == address(companionRecorder),
            "all carriers reuse original Recorder"
        );
        StreamModuleRegistration[] memory rows = D.registrations(c, p);
        require(rows.length == 3, "three canonical native admission records");
        for (uint256 i; i < rows.length; ++i) {
            require(
                rows[i].module == carriers[i]
                    && rows[i].moduleType == keccak256("NATIVE_PRIMARY_SALE_ADAPTER")
                    && rows[i].moduleVersion == keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1")
                    && rows[i].interfaceId == type(IStreamNativeSaleBinding).interfaceId
                    && rows[i].expectedRuntimeCodeHash == p.codeHashes[i]
                    && rows[i].moduleGasLimit == c.readGas[i],
                "native universal coordinates retain configured pins"
            );
        }
    }

    function testCanonicalSavedWrongChainGraphAndConfigurationAreRejected() public {
        D.Configuration memory c = companionConfiguration;
        D.Products memory p = companionProducts;
        ++p.chainId;
        _rejectSaved(c, p);
        --p.chainId;
        c.claims.recorder = IStreamPrimarySaleSettlement(address(sale));
        _rejectSaved(c, p);
        c = companionConfiguration;
        c.manifests[1].hash = keccak256("different artifact declaration");
        _rejectSaved(c, p);
        c = companionConfiguration;
        p.configurationHash = keccak256("different configuration");
        _rejectSaved(c, p);
        D.validate(companionConfiguration, companionProducts);
    }

    function testCanonicalSavedAndLiveRuntimeDriftCannotProduceActivationCoordinates() public {
        D.Configuration memory c = companionConfiguration;
        D.Products memory p = companionProducts;
        p.codeHashes[1] ^= bytes32(uint256(1));
        _rejectSaved(c, p);
        p = companionProducts;
        p.dependencyCodeHashes[8] ^= bytes32(uint256(1));
        _rejectSaved(c, p);
        p = companionProducts;
        vm.etch(address(p.dutch), hex"60006000fd");
        _rejectSaved(c, p);
        require(
            registry.moduleRecord(address(p.dutch)).status == ModuleRegistryStatus.UNKNOWN,
            "runtime drift never admitted the product"
        );
    }

    function inspectCanonicalPending() external view returns (StreamModuleRegistration[] memory) {
        return A.pendingRegistrations(_activationContext());
    }

    function inspectCanonicalCredit() external view returns (GenesisBatch memory) {
        return A.recorderCredit(_activationContext());
    }

    function validateCanonicalOwner(A.OwnerCall calldata saved) external view {
        A.validateOwnerCall(_activationContext(), saved);
    }

    function inspectCanonicalGoverned(A.OwnerCall calldata saved)
        external
        view
        returns (GenesisBatch memory)
    {
        return A.governed(_activationContext(), saved);
    }

    function inspectCanonicalCatalog(GovernanceActionPolicyEntry[] calldata known)
        external
        view
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return A.catalogAdditions(_activationContext(), known);
    }

    function testCanonicalPolicyIntentsAreExactAndCompatibleProfilesArePreserved() public view {
        A.Context memory x = _activationContext();
        GovernanceActionPolicyEntry[] memory wanted = A.policies(x);
        require(wanted.length == 10, "exact ten catalog intents");
        GovernanceActionPolicyEntry[] memory original = new GovernanceActionPolicyEntry[](4);
        original[0] = _companionPolicy(address(registry), registry.registerModule.selector);
        original[1] =
            _companionPolicy(address(revenueEscrow), revenueEscrow.setCreditProducer.selector);
        original[2] = _companionPolicy(address(manager), manager.configurePhase.selector);
        original[3] = _companionPolicy(address(manager), manager.setPhaseExecutor.selector);
        GovernanceActionPolicyEntry[] memory carrierRows = _additionalOperatingPolicies();
        uint256 seen;
        for (uint256 i; i < wanted.length; ++i) {
            GovernanceActionPolicyEntry memory row = wanted[i];
            bytes32 key = keccak256(abi.encode(row.actionClass, row.target, row.selector));
            if (i != 0) {
                require(
                    keccak256(
                        abi.encode(
                            wanted[i - 1].actionClass, wanted[i - 1].target, wanted[i - 1].selector
                        )
                    ) < key,
                    "strictly sorted unique class/target/selector keys"
                );
            }
            require(
                row.actionClass == 1 && row.targetCodeHash == row.target.codehash
                    && row.targetProfileHash == keccak256(abi.encode(DEPLOYMENT_HASH, row.target))
                    && row.callType == 1 && row.valuePolicy == 0 && row.valueLimit == 0
                    && row.valueSemanticsHash == 0,
                "pinned target with exact zero-value class1 call semantics"
            );
            for (uint256 j; j < 10; ++j) {
                GovernanceActionPolicyEntry memory expected =
                    j < 4 ? original[j] : carrierRows[j - 4];
                if (row.target == expected.target && row.selector == expected.selector) {
                    require(
                        (seen & (uint256(1) << j)) == 0,
                        "one intent per exact expected target selector"
                    );
                    seen |= uint256(1) << j;
                }
            }
        }
        require(seen == 1023, "registry, escrow, Manager and all six carrier selectors covered");
        for (uint256 i; i < original.length; ++i) {
            original[i].targetProfileHash = keccak256(abi.encode("retained compatible profile", i));
        }
        bytes32 before_ = keccak256(abi.encode(original));
        GovernanceActionPolicyEntry[] memory additions = A.catalogAdditions(x, original);
        require(
            additions.length == 6 && keccak256(abi.encode(original)) == before_,
            "compatible existing profile commitments remain unchanged"
        );
        for (uint256 i; i < additions.length; ++i) {
            require(
                additions[i].target != address(registry)
                    && additions[i].target != address(revenueEscrow)
                    && additions[i].target != address(manager),
                "only unadmitted carrier keys remain"
            );
        }
        GovernanceActionPolicyEntry[] memory invalid = new GovernanceActionPolicyEntry[](2);
        invalid[0] = original[0];
        invalid[1] = original[0];
        (bool ok,) =
            address(this).staticcall(abi.encodeCall(this.inspectCanonicalCatalog, (invalid)));
        require(!ok, "duplicate known key rejects even when profiles match");
        invalid = new GovernanceActionPolicyEntry[](1);
        invalid[0] = original[0];
        invalid[0].valueLimit = 1;
        (ok,) = address(this).staticcall(abi.encodeCall(this.inspectCanonicalCatalog, (invalid)));
        require(!ok, "conflicting value semantics cannot be silently overwritten");
    }

    function testActualSafePartialCanonicalRegistrationResumesExactPendingRows() public {
        A.Context memory x = _activationContext();
        uint256 priorCount = registry.moduleCount();
        GenesisBatch memory all = A.registrationBatch(x);
        require(all.actionClass == 1 && all.calls.length == 3, "exact class1 trio registration");
        GenesisBatch memory first;
        first.actionClass = 1;
        first.calls = new GovernanceCall[](1);
        first.callDatas = new bytes[](1);
        first.calls[0] = all.calls[0];
        first.callDatas[0] = all.callDatas[0];
        bytes32 action = _runCompanionBatch(first);
        require(
            executor.governanceAction(action).proposer == address(governorSafe)
                && executor.governanceAction(action).executor == address(governorSafe)
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "actual Safe proposed and executed delayed registration"
        );
        StreamModuleRegistration[] memory pending = A.pendingRegistrations(x);
        require(
            pending.length == 2 && pending[0].module == address(companionProducts.claims)
                && pending[1].module == address(companionProducts.dutch),
            "exact remaining registered identities"
        );
        _runCompanionBatch(A.registrationBatch(x));
        A.requireRegistered(x);
        require(
            registry.moduleCount() == priorCount + 3 && A.pendingRegistrations(x).length == 0,
            "no duplicate registration during resume"
        );
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.inspectCanonicalCredit, ()));
        require(!ok, "registered sale carriers do not admit the original Recorder");
        (bool enabled,,) = revenueEscrow.creditProducer(address(companionRecorder));
        require(!enabled, "registration alone cannot grant payment credit authority");
    }

    function testActualConflictingCompanionRegistrationCannotBeSilentlySkipped() public {
        StreamModuleRegistration[] memory planned =
            D.registrations(companionConfiguration, companionProducts);
        StreamModuleRegistration[] memory altered = new StreamModuleRegistration[](1);
        altered[0] = planned[1];
        altered[0].moduleManifestHash = keccak256("different retained module artifact");
        GenesisBatch memory batch;
        batch.actionClass = 1;
        (batch.calls, batch.callDatas) = StreamCurrentStackPlan.registrationCalls(registry, altered);
        _runCompanionBatch(batch);
        require(
            registry.moduleRecord(altered[0].module).moduleManifestHash
                == altered[0].moduleManifestHash,
            "different manifest actually registered through delayed Safe governance"
        );
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.inspectCanonicalPending, ()));
        require(!ok, "pending planner refuses observed registration drift");
    }

    function testActualRecorderAdmissionAndCreditAreSeparateOrderedActions() public {
        _runCompanionBatch(A.registrationBatch(_activationContext()));
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.inspectCanonicalCredit, ()));
        require(!ok, "unregistered Recorder cannot receive planned escrow authority");
        _admitCompanionRecorder();
        GenesisBatch memory credit = A.recorderCredit(_activationContext());
        require(
            credit.calls.length == 1 && credit.calls[0].target == address(revenueEscrow),
            "one original Recorder credit transition"
        );
        (bool enabled,,) = revenueEscrow.creditProducer(address(companionRecorder));
        require(!enabled, "building the action grants no credit");
        _runCompanionBatch(credit);
        A.requireSettlementReady(_activationContext());
        bytes32 codeHash;
        (enabled, codeHash,) = revenueEscrow.creditProducer(address(companionRecorder));
        require(
            enabled && codeHash == address(companionRecorder).codehash,
            "actual pinned original Recorder credit"
        );
        (ok,) = address(this).staticcall(abi.encodeCall(this.inspectCanonicalCredit, ()));
        require(!ok, "completed credit transition cannot be planned again");
        (address prepared,,,) = manager.preparedNativeRecorder();
        require(
            prepared == address(0),
            "canonical single-step activation did not install prepared custody binding"
        );
    }

    function testActualArtistPolicyConsentThenExecutorSignersAndThreeSaleRegistrations() public {
        _activateTrio();
        _configureCompanionPhase();
        for (uint8 i; i < 3; ++i) {
            _executeCompanionOwner(
                A.configureSigner(
                    _activationContext(),
                    i,
                    1,
                    vm.addr(ARTIST_KEY),
                    1,
                    keccak256(abi.encode("canonical collection signer evidence", i)),
                    true
                )
            );
        }
        S.Configuration memory immediate = _saleConfiguration(0, 0);
        bytes32 immediateId = companionProducts.immediate.saleIdFor(1, COMPANION_PHASE, 1);
        _executeCompanionOwner(A.registerImmediate(_activationContext(), immediate));
        require(
            companionProducts.immediate.saleRecord(immediateId).configHash
                == companionProducts.immediate.saleConfigurationHash(immediate),
            "exact current immediate sale registered"
        );
        C.Configuration memory claim = C.Configuration(_saleConfiguration(1, 12), 0);
        claim.sale.unitPrice = 0;
        claim.sale.expectedPrimaryPolicyHash = 0;
        bytes32 claimId = companionProducts.claims.saleIdFor(1, COMPANION_PHASE, 1);
        _executeCompanionOwner(A.registerClaim(_activationContext(), claim));
        require(
            companionProducts.claims.saleRecord(claimId).sale.configHash
                == companionProducts.claims.saleConfigurationHash(claim),
            "exact current zero-claim declaration registered"
        );
        C.Configuration memory publicClaim = C.Configuration(_saleConfiguration(1, 13), 2000);
        publicClaim.sale.unitPrice = 100;
        publicClaim.sale.authorityMode = 2;
        publicClaim.sale.signer = S.SignerBinding(address(0), 0, 0, 0, address(0));
        bytes32 publicClaimId = companionProducts.claims.saleIdFor(1, COMPANION_PHASE, 2);
        _executeCompanionOwner(A.registerClaim(_activationContext(), publicClaim));
        C.Record memory publicRecord = companionProducts.claims.saleRecord(publicClaimId);
        require(
            publicRecord.sale.configHash
                    == companionProducts.claims.saleConfigurationHash(publicClaim)
                && publicRecord.sale.config.saleKind == 13
                && publicRecord.sale.config.authorityMode == 2
                && publicRecord.sale.config.unitPrice == 100 && publicRecord.maxUnitPrice == 2000
                && publicRecord.sale.config.signer.authorizer == address(0),
            "public PWYW setup retains positive floor, complete band and zero signer"
        );
        Dutch.Configuration memory dutch;
        dutch.sale = _saleConfiguration(2, 3);
        dutch.sale.startsAt = uint64(block.timestamp + executor.minimumDelay(1) + 1 hours);
        dutch.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(
            1000, 100, dutch.sale.startsAt, dutch.sale.startsAt + 1 days, 0, 0, 0
        );
        bytes32 dutchId = companionProducts.dutch.saleIdFor(1, COMPANION_PHASE, 1);
        _executeCompanionOwner(A.registerDutch(_activationContext(), dutch));
        require(
            companionProducts.dutch.saleRecord(dutchId).sale.configHash
                == companionProducts.dutch.saleConfigurationHash(dutch),
            "future immutable Dutch curve registered after governance delay"
        );
        require(
            manager.phaseExecutors(1, COMPANION_PHASE).length == 3
                && companionProducts.immediate.nextSaleNonce() == 2
                && companionProducts.claims.nextSaleNonce() == 3
                && companionProducts.dutch.nextSaleNonce() == 2
                && core.collectionMintedEver(1) == 0,
            "three real activation sequences grant no implicit mint"
        );
    }

    function testSavedExecutorPlanRejectsPriorPolicyAfterAnotherCompanionIsAdded() public {
        _activateTrio();
        A.Phase memory phase = _phaseConfiguration();
        A.OwnerCall memory configure = A.configurePhase(_activationContext(), phase);
        _recordFixturePolicy(COMPANION_PHASE, configure.resultingPolicyHash);
        _executeCompanionOwner(configure);
        A.OwnerCall memory first = A.phaseExecutor(_activationContext(), 0, 1, COMPANION_PHASE);
        A.OwnerCall memory stale = A.phaseExecutor(_activationContext(), 1, 1, COMPANION_PHASE);
        _recordFixturePolicy(COMPANION_PHASE, first.resultingPolicyHash);
        _executeCompanionOwner(first);
        (bool ok,) = address(this).staticcall(abi.encodeCall(this.validateCanonicalOwner, (stale)));
        require(
            !ok && !manager.phaseExecutor(1, COMPANION_PHASE, address(companionProducts.claims)),
            "saved plan detects exact predecessor-policy drift"
        );
        A.OwnerCall memory current = A.phaseExecutor(_activationContext(), 1, 1, COMPANION_PHASE);
        require(
            current.resultingPolicyHash != stale.resultingPolicyHash
                && current.observedStateHash != stale.observedStateHash,
            "fresh plan observes accumulated current executors"
        );
        _recordFixturePolicy(COMPANION_PHASE, current.resultingPolicyHash);
        _executeCompanionOwner(current);
        require(
            manager.phasePolicyHash(1, COMPANION_PHASE) == current.resultingPolicyHash,
            "actual Artist-consented current policy installed"
        );
    }

    function testActualSafeOwnerCallCannotBeWrappedAsExecutorOwnedAction() public {
        _activateTrio();
        _configureCompanionPhase();
        bytes memory transfer =
            abi.encodeCall(companionProducts.immediate.transferOwnership, (address(governorSafe)));
        _govern(_governanceRequest(1, address(companionProducts.immediate), transfer, 0, 0, 0));
        D.validate(companionConfiguration, companionProducts);
        A.OwnerCall memory signer = A.configureSigner(
            _activationContext(),
            0,
            1,
            vm.addr(ARTIST_KEY),
            1,
            keccak256("actual Safe-owned collection signer"),
            true
        );
        require(
            signer.call.caller == address(governorSafe), "owner plan names original Safe caller"
        );
        (bool ok,) =
            address(this).staticcall(abi.encodeCall(this.inspectCanonicalGoverned, (signer)));
        require(!ok, "Safe ownership cannot be represented as Executor ownership");
        A.validateOwnerCall(_activationContext(), signer);
        this.executeCurrentGovernorCall(signer.call.target, signer.call.data);
        S.Configuration memory saleConfig = _saleConfiguration(0, 0);
        A.OwnerCall memory saleCall = A.registerImmediate(_activationContext(), saleConfig);
        A.validateOwnerCall(_activationContext(), saleCall);
        this.executeCurrentGovernorCall(saleCall.call.target, saleCall.call.data);
        require(
            companionProducts.immediate.nextSaleNonce() == 2
                && companionProducts.immediate.owner() == address(governorSafe),
            "actual Safe directly installs owned sale"
        );
    }

    function _activationContext() internal view returns (A.Context memory) {
        return A.Context(companionConfiguration, companionProducts);
    }

    function _activateTrio() internal {
        _runCompanionBatch(A.registrationBatch(_activationContext()));
        _admitCompanionRecorder();
        _runCompanionBatch(A.recorderCredit(_activationContext()));
        A.requireSettlementReady(_activationContext());
    }

    function _phaseConfiguration() internal pure returns (A.Phase memory p) {
        p.collectionId = 1;
        p.phaseId = COMPANION_PHASE;
        p.config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("canonical phase terms"),
            keccak256("canonical phase metadata")
        );
        p.counterIds = new bytes32[](1);
        p.counterIds[0] = keccak256("canonical deployment supply counter");
        p.counterConfigs = new IStreamMintManager.MintCounterConfig[](1);
        p.counterConfigs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("canonical counter definition")
        );
    }

    function _configureCompanionPhase() internal {
        A.OwnerCall memory next = A.configurePhase(_activationContext(), _phaseConfiguration());
        require(next.resultingPolicyHash != 0, "prospective policy before Artist consent");
        _recordFixturePolicy(COMPANION_PHASE, next.resultingPolicyHash);
        _executeCompanionOwner(next);
        for (uint8 i; i < 3; ++i) {
            next = A.phaseExecutor(_activationContext(), i, 1, COMPANION_PHASE);
            _recordFixturePolicy(COMPANION_PHASE, next.resultingPolicyHash);
            _executeCompanionOwner(next);
            require(
                manager.phasePolicyHash(1, COMPANION_PHASE) == next.resultingPolicyHash,
                "actual new consent-bound policy"
            );
        }
    }

    function _executeCompanionOwner(A.OwnerCall memory next) internal {
        require(next.call.caller == address(executor), "expected actual owner");
        A.validateOwnerCall(_activationContext(), next);
        _runCompanionBatch(A.governed(_activationContext(), next));
    }

    function _saleConfiguration(uint8 index, uint8 kind)
        internal
        view
        returns (S.Configuration memory c)
    {
        c.collectionId = 1;
        c.phaseId = COMPANION_PHASE;
        c.saleKind = kind;
        c.authorityMode = 1;
        c.unitPrice = 1000;
        c.startsAt = uint64(block.timestamp);
        c.endsAt = uint64(block.timestamp + 10 days);
        c.saleSupplyLimit = 8;
        c.mintPolicyHash = manager.phasePolicyHash(1, COMPANION_PHASE);
        c.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        address[3] memory targets = D.addresses(companionProducts);
        (c.signer,) = S(targets[index]).collectionSigner(1, artist, 1);
    }

    function _rejectSaved(D.Configuration memory c, D.Products memory p) private view {
        (bool ok, bytes memory reason) =
            address(this).staticcall(abi.encodeCall(this.validateCanonicalSaved, (c, p)));
        require(!ok && reason.length != 0, "invalid exact saved deployment rejects");
    }
}
