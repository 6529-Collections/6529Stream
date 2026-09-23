// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    CanonicalNativeSalesDeploymentFixture
} from "../helpers/CanonicalNativeSalesDeploymentFixture.sol";
import { DeployCanonicalNativeSales } from "../../script/current/DeployCanonicalNativeSales.s.sol";
import {
    StreamCanonicalNativeSalesDeployment as D
} from "../../script/current/StreamCanonicalNativeSalesDeployment.sol";
import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "../../script/current/StreamCanonicalNativeSalesActivationPlan.sol";
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
    StreamModuleRegistration
} from "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";

interface CanonicalEntrypointVm {
    function chainId(uint256 chainId) external;
}

/// @notice Read-only entrypoint delegation against the actual current graph and Governor Safe.
/// @dev The script is a test-created planning artifact, not a deployed protocol product. No allowed-
/// chain run(), environment lookup, broadcast, purchase or live-deployment acceptance is exercised.
contract StreamCanonicalNativeSalesEntrypointTest is CanonicalNativeSalesDeploymentFixture {
    CanonicalEntrypointVm private constant entryVm =
        CanonicalEntrypointVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    DeployCanonicalNativeSales private entry;

    function setUp() public override {
        entryVm.chainId(31337);
        super.setUp();
        entry = new DeployCanonicalNativeSales();
    }

    function testEntrypointAllFifteenMethodsRejectUnsupportedChainBeforeDependencies() public {
        A.Context memory invalid;
        A.Phase memory phase;
        A.OwnerCall memory ownerCall;
        S.Configuration memory immediate;
        C.Configuration memory claim;
        Dutch.Configuration memory dutch;
        GovernanceActionPolicyEntry[] memory known = new GovernanceActionPolicyEntry[](0);
        bytes[] memory calls = new bytes[](15);
        calls[0] = abi.encodeCall(entry.run, (invalid.configuration));
        calls[1] = abi.encodeCall(entry.verifyConstruction, (invalid));
        calls[2] = abi.encodeCall(entry.pendingRegistrations, (invalid));
        calls[3] = abi.encodeCall(entry.prepareAdmission, (invalid));
        calls[4] = abi.encodeCall(entry.prepareCatalogAdditions, (invalid, known));
        calls[5] = abi.encodeCall(entry.prepareRecorderCredit, (invalid));
        calls[6] = abi.encodeCall(entry.verifySettlementReady, (invalid));
        calls[7] = abi.encodeCall(entry.preparePhase, (invalid, phase));
        calls[8] = abi.encodeCall(entry.preparePhaseExecutor, (invalid, 0, 1, COMPANION_PHASE));
        calls[9] = abi.encodeCall(
            entry.prepareSigner, (invalid, 0, 1, artist, 1, bytes32(uint256(1)), true)
        );
        calls[10] = abi.encodeCall(entry.prepareImmediate, (invalid, immediate));
        calls[11] = abi.encodeCall(entry.prepareClaim, (invalid, claim));
        calls[12] = abi.encodeCall(entry.prepareDutch, (invalid, dutch));
        calls[13] = abi.encodeCall(entry.verifyOwnerCall, (invalid, ownerCall));
        calls[14] = abi.encodeCall(entry.prepareGoverned, (invalid, ownerCall));
        bytes32 before_ = _observedState();
        entryVm.chainId(1);
        for (uint256 i; i < calls.length; ++i) {
            _expectError(
                calls[i], abi.encodeWithSignature("Error(string)", "Anvil or Sepolia only")
            );
        }
        entryVm.chainId(31337);
        require(_observedState() == before_, "unsupported chain changed no graph state");
        // Sepolia passes the same guard and reaches the invalid configuration check. No run call.
        entryVm.chainId(11155111);
        _expectError(
            abi.encodeCall(entry.verifyConstruction, (invalid)),
            abi.encodeWithSelector(D.InvalidCanonicalNativeSalesConfiguration.selector)
        );
        entryVm.chainId(31337);
    }

    function testEntrypointConstructionAndAdmissionAreExactReadOnlyPlans() public view {
        A.Context memory x = _context();
        bytes32 before_ = _observedState();
        require(
            entry.verifyConstruction(x) == D.constructionHash(x.configuration, x.products),
            "same construction proof"
        );
        (GenesisBatch memory batch, GovernanceActionPolicyEntry[] memory policies) =
            entry.prepareAdmission(x);
        _same(abi.encode(batch), abi.encode(A.registrationBatch(x)));
        _same(abi.encode(policies), abi.encode(A.policies(x)));
        _same(abi.encode(entry.pendingRegistrations(x)), abi.encode(A.pendingRegistrations(x)));
        require(
            batch.actionClass == 1 && batch.calls.length == 3 && policies.length == 10,
            "finite original plans"
        );
        GovernanceActionPolicyEntry[] memory known = new GovernanceActionPolicyEntry[](1);
        known[0] = policies[0];
        known[0].targetProfileHash = keccak256("retained original compatible profile");
        GovernanceActionPolicyEntry[] memory missing = entry.prepareCatalogAdditions(x, known);
        _same(abi.encode(missing), abi.encode(A.catalogAdditions(x, known)));
        require(missing.length == 9, "original compatible catalog key omitted");
        require(
            _observedState() == before_, "planning did not admit, credit, configure or advance Safe"
        );
        x.products.codeHashes[0] ^= bytes32(uint256(1));
        _expectError(
            abi.encodeCall(entry.verifyConstruction, (x)),
            abi.encodeWithSelector(
                D.CanonicalNativeSalesRuntimeChanged.selector, address(companionProducts.immediate)
            )
        );
        _expectError(
            abi.encodeCall(entry.prepareAdmission, (x)),
            abi.encodeWithSelector(
                D.CanonicalNativeSalesRuntimeChanged.selector, address(companionProducts.immediate)
            )
        );
    }

    function testEntrypointResumesOnlyActualPendingSafeRegistrations() public {
        A.Context memory x = _context();
        uint256 count = registry.moduleCount();
        (GenesisBatch memory all,) = entry.prepareAdmission(x);
        GenesisBatch memory first;
        first.actionClass = all.actionClass;
        first.calls = new GovernanceCall[](1);
        first.callDatas = new bytes[](1);
        first.calls[0] = all.calls[0];
        first.callDatas[0] = all.callDatas[0];
        bytes32 action = _runCompanionBatch(first);
        require(
            executor.governanceAction(action).proposer == address(governorSafe)
                && executor.governanceAction(action).executor == address(governorSafe)
                && executor.governanceAction(action).status == GovernanceActionStatus.EXECUTED,
            "real delayed Governor Safe execution"
        );
        bytes32 before_ = _observedState();
        StreamModuleRegistration[] memory pending = entry.pendingRegistrations(x);
        require(
            pending.length == 2 && pending[0].module == address(companionProducts.claims)
                && pending[1].module == address(companionProducts.dutch),
            "only two original missing coordinates"
        );
        (GenesisBatch memory rest,) = entry.prepareAdmission(x);
        _same(abi.encode(rest), abi.encode(A.registrationBatch(x)));
        require(_observedState() == before_, "resume preview did not register");
        _runCompanionBatch(rest);
        require(
            entry.pendingRegistrations(x).length == 0 && registry.moduleCount() == count + 3,
            "resume neither duplicates nor replaces companions"
        );
        _expectError(
            abi.encodeCall(entry.prepareAdmission, (x)),
            abi.encodeWithSignature("Error(string)", "companions already registered")
        );
        require(
            entry.verifyConstruction(x) == D.constructionHash(x.configuration, x.products),
            "same deployed trio retained"
        );
    }

    function testEntrypointRecorderCreditRetainsOriginalAdmissionAndExecutionBoundary() public {
        A.Context memory x = _context();
        (GenesisBatch memory registrations,) = entry.prepareAdmission(x);
        _runCompanionBatch(registrations);
        (bool ok, bytes memory reason) =
            address(entry).staticcall(abi.encodeCall(entry.prepareRecorderCredit, (x)));
        require(!ok && reason.length != 0, "unadmitted Recorder is not a credit producer");
        _admitCompanionRecorder();
        bytes32 before_ = _observedState();
        GenesisBatch memory credit = entry.prepareRecorderCredit(x);
        _same(abi.encode(credit), abi.encode(A.recorderCredit(x)));
        require(_observedState() == before_, "credit planning grants no authority");
        _expectError(
            abi.encodeCall(entry.verifySettlementReady, (x)),
            abi.encodeWithSignature("Error(string)", "Recorder escrow credit missing")
        );
        _runCompanionBatch(credit);
        entry.verifySettlementReady(x);
        (bool enabled, bytes32 runtime,) = revenueEscrow.creditProducer(address(companionRecorder));
        require(
            enabled && runtime == address(companionRecorder).codehash,
            "real original Recorder credit installed"
        );
        _expectError(
            abi.encodeCall(entry.prepareRecorderCredit, (x)),
            abi.encodeWithSignature("Error(string)", "Recorder credit already enabled")
        );
    }

    function testEntrypointPhaseAndSalePreviewsDelegateExactCurrentGraph() public {
        _activate();
        A.Context memory x = _context();
        A.Phase memory phase = _phase();
        bytes32 before_ = _observedState();
        A.OwnerCall memory next = entry.preparePhase(x, phase);
        _same(abi.encode(next), abi.encode(A.configurePhase(x, phase)));
        require(
            next.resultingPolicyHash != 0 && _observedState() == before_,
            "prospective policy without mutation"
        );
        _recordFixturePolicy(COMPANION_PHASE, next.resultingPolicyHash);
        _execute(next);
        for (uint8 i; i < 3; ++i) {
            next = entry.preparePhaseExecutor(x, i, 1, COMPANION_PHASE);
            _same(abi.encode(next), abi.encode(A.phaseExecutor(x, i, 1, COMPANION_PHASE)));
            _recordFixturePolicy(COMPANION_PHASE, next.resultingPolicyHash);
            _execute(next);
        }
        bytes32 evidence = keccak256("entrypoint signer authority evidence");
        next = entry.prepareSigner(x, 0, 1, artist, 1, evidence, true);
        _same(abi.encode(next), abi.encode(A.configureSigner(x, 0, 1, artist, 1, evidence, true)));
        _execute(next);
        before_ = _observedState();
        S.Configuration memory immediate = _sale(0);
        immediate.authorityMode = 1;
        (immediate.signer,) = companionProducts.immediate.collectionSigner(1, artist, 1);
        _same(
            abi.encode(entry.prepareImmediate(x, immediate)),
            abi.encode(A.registerImmediate(x, immediate))
        );
        C.Configuration memory claim = C.Configuration(_sale(13), 2000);
        claim.sale.unitPrice = 100;
        _same(abi.encode(entry.prepareClaim(x, claim)), abi.encode(A.registerClaim(x, claim)));
        Dutch.Configuration memory dutch;
        dutch.sale = _sale(3);
        dutch.sale.startsAt = uint64(block.timestamp + executor.minimumDelay(1) + 1 hours);
        dutch.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(
            1000, 100, dutch.sale.startsAt, dutch.sale.startsAt + 1 days, 0, 0, 0
        );
        _same(abi.encode(entry.prepareDutch(x, dutch)), abi.encode(A.registerDutch(x, dutch)));
        require(
            _observedState() == before_ && core.collectionMintedEver(1) == 0,
            "sale previews neither register nor mint nor advance Safe nonce"
        );
    }

    function testEntrypointRejectsStaleOwnerPlanAndPreservesDirectSafeRoute() public {
        (GenesisBatch memory admission,) = entry.prepareAdmission(_context());
        _runCompanionBatch(admission);
        A.Context memory x = _context();
        bytes32 evidence = keccak256("entrypoint observed signer state");
        A.OwnerCall memory original = entry.prepareSigner(x, 0, 1, artist, 1, evidence, true);
        _execute(original);
        _expectError(
            abi.encodeCall(entry.verifyOwnerCall, (x, original)),
            abi.encodeWithSignature("Error(string)", "owner plan state changed")
        );
        A.OwnerCall memory oldOwner = entry.prepareSigner(x, 0, 1, artist, 1, evidence, false);
        bytes memory transfer =
            abi.encodeCall(companionProducts.immediate.transferOwnership, (address(governorSafe)));
        _govern(_governanceRequest(1, address(companionProducts.immediate), transfer, 0, 0, 0));
        _expectError(
            abi.encodeCall(entry.verifyOwnerCall, (x, oldOwner)),
            abi.encodeWithSignature("Error(string)", "owner plan state changed")
        );
        A.OwnerCall memory direct = entry.prepareSigner(x, 0, 1, artist, 1, evidence, false);
        require(
            direct.call.caller == address(governorSafe)
                && direct.call.target == address(companionProducts.immediate)
                && direct.call.value == 0,
            "literal current Safe owner route"
        );
        _same(
            abi.encode(direct), abi.encode(A.configureSigner(x, 0, 1, artist, 1, evidence, false))
        );
        entry.verifyOwnerCall(x, direct);
        _expectError(
            abi.encodeCall(entry.prepareGoverned, (x, direct)),
            abi.encodeWithSignature("Error(string)", "owner is not Executor")
        );
        this.executeCurrentGovernorCall(direct.call.target, direct.call.data);
        (, bool enabled) = companionProducts.immediate.collectionSigner(1, artist, 1);
        require(
            !enabled && companionProducts.immediate.owner() == address(governorSafe),
            "direct Safe actually revokes signer"
        );
        require(
            entry.verifyConstruction(x) == D.constructionHash(x.configuration, x.products),
            "legitimate owner change retains construction"
        );
    }

    function _context() private view returns (A.Context memory) {
        return A.Context(companionConfiguration, companionProducts);
    }

    function _activate() private {
        (GenesisBatch memory batch,) = entry.prepareAdmission(_context());
        _runCompanionBatch(batch);
        _admitCompanionRecorder();
        _runCompanionBatch(entry.prepareRecorderCredit(_context()));
        entry.verifySettlementReady(_context());
    }

    function _execute(A.OwnerCall memory next) private {
        entry.verifyOwnerCall(_context(), next);
        GenesisBatch memory batch = entry.prepareGoverned(_context(), next);
        _same(abi.encode(batch), abi.encode(A.governed(_context(), next)));
        _runCompanionBatch(batch);
    }

    function _phase() private pure returns (A.Phase memory p) {
        p.collectionId = 1;
        p.phaseId = COMPANION_PHASE;
        p.config = IStreamMintManager.MintPhaseConfig(
            false,
            0,
            0,
            1,
            keccak256("entrypoint phase terms"),
            keccak256("entrypoint phase metadata")
        );
        p.counterIds = new bytes32[](1);
        p.counterIds[0] = keccak256("entrypoint supply counter");
        p.counterConfigs = new IStreamMintManager.MintCounterConfig[](1);
        p.counterConfigs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            1,
            keccak256("entrypoint counter definition")
        );
    }

    function _sale(uint8 kind) private view returns (S.Configuration memory c) {
        c.collectionId = 1;
        c.phaseId = COMPANION_PHASE;
        c.saleKind = kind;
        c.authorityMode = 2;
        c.unitPrice = 1000;
        c.startsAt = uint64(block.timestamp);
        c.endsAt = uint64(block.timestamp + 10 days);
        c.saleSupplyLimit = 8;
        c.mintPolicyHash = manager.phasePolicyHash(1, COMPANION_PHASE);
        c.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
    }

    function _observedState() private view returns (bytes32) {
        (bool credit, bytes32 codeHash, uint64 revision) =
            revenueEscrow.creditProducer(address(companionRecorder));
        bytes32 authority = keccak256(
            abi.encode(
                registry.moduleCount(),
                governorSafe.nonce(),
                credit,
                codeHash,
                revision,
                companionProducts.immediate.owner(),
                companionProducts.claims.owner(),
                companionProducts.dutch.owner()
            )
        );
        bytes32 sales = keccak256(
            abi.encode(
                companionProducts.immediate.nextSaleNonce(),
                companionProducts.claims.nextSaleNonce(),
                companionProducts.dutch.nextSaleNonce(),
                manager.phasePolicyHash(1, COMPANION_PHASE),
                core.collectionMintedEver(1)
            )
        );
        return keccak256(abi.encode(authority, sales));
    }

    function _expectError(bytes memory callData, bytes memory expected) private view {
        (bool ok, bytes memory reason) = address(entry).staticcall(callData);
        require(!ok && keccak256(reason) == keccak256(expected), "exact entrypoint rejection");
    }

    function _same(bytes memory actual, bytes memory expected) private pure {
        require(
            keccak256(actual) == keccak256(expected),
            "entrypoint preserves complete original planner tuple"
        );
    }
}
