// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    GenesisBatch
} from "../../smart-contracts/interfaces/stream/governance/IStreamGenesisInitializer.sol";

import {
    CanonicalNativeSalesDeploymentFixture
} from "../../test/helpers/CanonicalNativeSalesDeploymentFixture.sol";
import {
    CurrentCommerceConservationFixture
} from "../../test/helpers/CurrentCommerceConservationFixture.sol";
import {
    CurrentDocumentaryConservationFixture
} from "../../test/helpers/CurrentDocumentaryConservationFixture.sol";
import {
    CurrentDocumentaryMediaFixture
} from "../../test/helpers/CurrentDocumentaryMediaFixture.sol";
import { StreamCurrentStackFixture } from "../../test/helpers/StreamCurrentStackFixture.sol";
import {
    StreamCanonicalNativeSalesActivationPlan as A
} from "../../script/current/StreamCanonicalNativeSalesActivationPlan.sol";
import {
    IStreamNativeImmediateSales as S
} from "../../smart-contracts/interfaces/stream/mint/IStreamNativeImmediateSales.sol";
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
    GovernanceActionPolicyEntry
} from "../../smart-contracts/interfaces/stream/governance/StreamGovernanceTypes.sol";
import {
    StreamPrimarySettlementTypes as R
} from "../../smart-contracts/interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import {
    StreamNativeSettlementTypes
} from "../../smart-contracts/interfaces/stream/revenue/StreamNativeSettlementTypes.sol";
import {
    StreamConservationFloorTypes as F
} from "../../smart-contracts/interfaces/stream/metadata/StreamConservationFloorTypes.sol";
import {
    IStreamPrimarySaleSettlement
} from "../../smart-contracts/interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import {
    StreamConservationFloor
} from "../../smart-contracts/domains/metadata/StreamConservationFloor.sol";

interface ActualPurchaseCoreView {
    function ownerOf(uint256 tokenId) external view returns (address);
    function tokenLifecycle(uint256 tokenId) external view returns (uint8);
    function coordinatorAtMint(uint256 tokenId) external view returns (address);
    function burn(uint256 tokenId) external;
    function approve(address approved, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
}

/// @dev Only a receiver actor. Core, Coordinator, Recorder and Floor remain the real instances.
contract ActualCanonicalPurchaseReceiver {
    address private immutable controller = msg.sender;
    ActualPurchaseCoreView private immutable core;
    Dutch private immutable dutch;
    IStreamPrimarySaleSettlement private immutable recorder;
    StreamConservationFloor private immutable floor;
    address private immutable coordinator;
    bytes32 private execution;
    bool private reject;
    address private transferTo;
    uint256 public callbacks;

    constructor(
        address core_,
        address dutch_,
        address recorder_,
        address floor_,
        address coordinator_
    ) {
        core = ActualPurchaseCoreView(core_);
        dutch = Dutch(dutch_);
        recorder = IStreamPrimarySaleSettlement(recorder_);
        floor = StreamConservationFloor(floor_);
        coordinator = coordinator_;
    }

    function arm(bytes32 id, bool reject_, address transferTo_) external {
        require(msg.sender == controller, "receiver test controller");
        execution = id;
        reject = reject_;
        transferTo = transferTo_;
    }

    function onERC721Received(address, address, uint256 tokenId, bytes calldata)
        external
        returns (bytes4)
    {
        require(msg.sender == address(core), "actual Core callback");
        S.Receipt memory pending = dutch.executionReceipt(execution);
        require(
            dutch.executionStatus(execution) == 1 && pending.tokenId == 0
                && pending.settlementKey == 0,
            "consumer still pending at receiver"
        );
        bytes32 key = recorder.settlementKey(address(dutch), execution);
        require(
            recorder.settlementConsumed(key) && recorder.settlementResult(key).settlementKey == key,
            "official published before receiver"
        );
        require(
            floor.settlementReceipt(key).receiptHash != 0 && floor.firstSale(1).receiptHash != 0,
            "Floor published before receiver"
        );
        require(
            core.ownerOf(tokenId) == address(this) && core.tokenLifecycle(tokenId) == 2
                && core.coordinatorAtMint(tokenId) == coordinator,
            "Core complete before receiver"
        );
        (bool burned,) = address(core).call(abi.encodeCall(core.burn, (tokenId)));
        require(!burned, "Core completion guard blocks receiver burn");
        ++callbacks;
        if (transferTo != address(0)) {
            core.approve(transferTo, tokenId);
            core.transferFrom(address(this), transferTo, tokenId);
        }
        require(!reject, "intentional receiver rejection");
        return this.onERC721Received.selector;
    }
}

interface ActualPurchaseExportVm {
    function dumpState(string calldata path) external;
    function envString(string calldata name) external returns (string memory);
    function writeFileBinary(string calldata path, bytes calldata data) external;
}

/// @notice Source-only actual-graph purchase/control recipe pinned to production 28c145e.
/// @dev No gas result is implied until native ownership, runtime checks and cold RPC pass.
/// Activation helpers retain the canonical deployment test's real Artist/Safe/Executor flow.
abstract contract ActualCanonicalDutchPurchaseFixture is CanonicalNativeSalesDeploymentFixture {
    uint256 internal constant PURCHASE_PRICE = 1000;
    bytes32 internal actualSaleId;

    function _activateActualPublicDutch() internal {
        A.Context memory x = A.Context(companionConfiguration, companionProducts);
        _runCompanionBatch(_canonicalRegistrationBatch(x));
        _admitCompanionRecorder();
        _runCompanionBatch(_canonicalRecorderCredit(x));
        _canonicalRequireSettlementReady(x);

        A.Phase memory p;
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
        _executeWithArtistConsent(_canonicalConfigurePhase(x, p));
        for (uint8 i; i < 3; ++i) {
            _executeWithArtistConsent(_canonicalPhaseExecutor(x, i, 1, COMPANION_PHASE));
        }

        Dutch.Configuration memory c;
        c.sale.collectionId = 1;
        c.sale.phaseId = COMPANION_PHASE;
        c.sale.saleKind = 3;
        c.sale.authorityMode = 2;
        c.sale.unitPrice = PURCHASE_PRICE;
        c.sale.startsAt = uint64(block.timestamp + executor.minimumDelay(1) + 1 hours);
        c.sale.endsAt = c.sale.startsAt + 10 days;
        c.sale.saleSupplyLimit = 8;
        c.sale.mintPolicyHash = manager.phasePolicyHash(1, COMPANION_PHASE);
        c.sale.expectedPrimaryPolicyHash = _nativePrimaryPolicyHash();
        c.schedule = IStreamDutchPriceSchedule.DutchPriceSchedule(
            uint96(PURCHASE_PRICE), 100, c.sale.startsAt, c.sale.startsAt + 1 days, 0, 0, 0
        );
        actualSaleId = companionProducts.dutch.saleIdFor(1, COMPANION_PHASE, 1);
        A.OwnerCall memory next = _canonicalRegisterDutch(x, c);
        _canonicalValidateOwnerCall(x, next);
        _runCompanionBatch(_canonicalGoverned(x, next));
        vm.warp(c.sale.startsAt);
        vm.deal(BUYER, 100 ether);
        S.Record memory installed = companionProducts.dutch.saleRecord(actualSaleId).sale;
        require(
            installed.artistGeneration == 1 && installed.artistId != 0, "actual generation-1 Artist"
        );
        require(
            installed.configHash == companionProducts.dutch.saleConfigurationHash(c),
            "exact installed public sale"
        );
        require(core.collectionMintedEver(1) == 0, "no setup mint");
        require(
            companionProducts.dutch.saleRevealQuote(actualSaleId).policy.revealFeePerTokenWei == 0,
            "original zero-fee reveal policy"
        );
    }

    function _executeWithArtistConsent(A.OwnerCall memory next) private {
        require(next.resultingPolicyHash != 0, "prospective actual Artist policy");
        _recordFixturePolicy(COMPANION_PHASE, next.resultingPolicyHash);
        A.Context memory x = A.Context(companionConfiguration, companionProducts);
        _canonicalValidateOwnerCall(x, next);
        _runCompanionBatch(_canonicalGoverned(x, next));
        require(
            manager.phasePolicyHash(1, COMPANION_PHASE) == next.resultingPolicyHash,
            "installed consent-bound policy"
        );
    }

    function _canonicalRegistrationBatch(A.Context memory x)
        internal view virtual returns (GenesisBatch memory)
    {
        return A.registrationBatch(x);
    }

    function _canonicalRecorderCredit(A.Context memory x)
        internal view virtual returns (GenesisBatch memory)
    {
        return A.recorderCredit(x);
    }

    function _canonicalRequireSettlementReady(A.Context memory x)
        internal view virtual
    {
        A.requireSettlementReady(x);
    }

    function _canonicalConfigurePhase(A.Context memory x, A.Phase memory p)
        internal view virtual returns (A.OwnerCall memory)
    {
        return A.configurePhase(x, p);
    }

    function _canonicalPhaseExecutor(A.Context memory x, uint8 index, uint256 collection, bytes32 phase)
        internal view virtual returns (A.OwnerCall memory)
    {
        return A.phaseExecutor(x, index, collection, phase);
    }

    function _canonicalRegisterDutch(A.Context memory x, Dutch.Configuration memory config)
        internal view virtual returns (A.OwnerCall memory)
    {
        return A.registerDutch(x, config);
    }

    function _canonicalValidateOwnerCall(A.Context memory x, A.OwnerCall memory saved)
        internal view virtual
    {
        A.validateOwnerCall(x, saved);
    }

    function _canonicalGoverned(A.Context memory x, A.OwnerCall memory saved)
        internal view virtual returns (GenesisBatch memory)
    {
        return A.governed(x, saved);
    }

    function _actualPurchase(bytes memory data) internal view returns (S.Purchase memory p) {
        p.saleId = actualSaleId;
        p.payer = BUYER;
        p.executor = BUYER;
        p.initialRecipient = BUYER;
        p.beneficiary = BUYER;
        p.tokenData = data;
        p.mintCommitment = keccak256(abi.encode("actual canonical collector", data));
        // First purchase is literal nonce 1: no preview or execution nonce read in the measured call.
        p.executionNonce = 1;
    }

    function _buyActual(S.Purchase memory p, uint256 value) internal returns (S.Receipt memory r) {
        vm.prank(BUYER);
        r = companionProducts.dutch.purchasePublic{ value: value }(p);
    }

    function _assertActualPurchase(S.Purchase memory p, S.Receipt memory r, uint256 credit)
        internal
        view
    {
        _assertActualPurchaseAccounting(p, r, credit, 0);
    }

    function _assertActualPurchaseAccounting(
        S.Purchase memory p, S.Receipt memory r, uint256 credit, uint256 fee
    ) internal view {
        require(
            r.saleId == actualSaleId && r.tokenId != 0 && r.settlementKey != 0,
            "complete consumer identity"
        );
        require(
            r.chargedAmount == PURCHASE_PRICE && r.revealFee == fee && r.revealCredit == credit,
            "exact price and excess"
        );
        require(
            companionProducts.dutch.executionStatus(r.executionId) == 2, "complete consumer status"
        );
        require(
            keccak256(abi.encode(companionProducts.dutch.executionReceipt(r.executionId)))
                == keccak256(abi.encode(r)),
            "full consumer tuple"
        );
        require(
            companionProducts.dutch.nextExecutionNonce(actualSaleId, BUYER) == 2,
            "per-payer replay consumed"
        );
        require(
            companionProducts.dutch.saleRecord(actualSaleId).sale.soldQuantity == 1,
            "sale count once"
        );
        require(
            core.ownerOf(r.tokenId) == p.initialRecipient && core.tokenLifecycle(r.tokenId) == 2,
            "real Core delivered"
        );
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(r.tokenId);
        require(
            exists && collectionId == 1 && serial == 1 && !burned, "actual first token identity"
        );
        require(
            core.coordinatorAtMint(r.tokenId) == address(entropy), "actual Coordinator captured"
        );
        require(
            keccak256(core.tokenData(r.tokenId)) == keccak256(p.tokenData), "complete artwork bytes"
        );
        require(core.collectionMintedEver(1) == 1, "real collection count once");
        R.PrimarySettlementResult memory result =
            companionRecorder.settlementResult(r.settlementKey);
        require(
            companionRecorder.settlementConsumed(r.settlementKey),
            "independent official replay consumed"
        );
        require(
            result.settlementKey == r.settlementKey && result.executionId == r.executionId
                && result.amount == PURCHASE_PRICE,
            "real official result"
        );
        require(
            result.operationIdentityCommitment == r.operationRoot
                && result.currentPolicyHash == result.boundPolicyHash,
            "retained mint transcript"
        );
        require(
            companionRecorder.totalOfficialSettled(address(0)) == PURCHASE_PRICE,
            "official native accounting"
        );
        require(
            companionProducts.dutch.refundableBalance(actualSaleId, BUYER) == credit
                && companionProducts.dutch.refundLiability() == credit,
            "exact refund accounting"
        );
        require(
            address(companionProducts.dutch).balance == credit, "no trapped exact-payment value"
        );
    }

    /// @dev Export hosts execute setup+dump in ONE non-isolated test call. Foundry 1.7.1 dumpState
    /// serializes the live journal, not arbitrary untouched backend state. The cold RPC driver must
    /// validate runtime provenance and every selected prestate/poststate getter before claiming gas.
    /// ABI schema: version, chainId, blockNumber, timestamp, [buyer,Dutch,Core,Manager,Ledger,
    /// Recorder,Artist,Coordinator,Floor,Executor,Registry,Metadata,Governor], saleId, value, calldata.
    function _exportActualPurchase(string memory label, address floor) internal {
        ActualPurchaseExportVm writer = ActualPurchaseExportVm(address(vm));
        string memory folder = writer.envString("COLLECTOR_ACTUAL_EXPORT_DIR");
        address[13] memory addresses = [
            BUYER,
            address(companionProducts.dutch),
            address(core),
            address(manager),
            address(ledger),
            address(companionRecorder),
            address(artists),
            address(entropy),
            floor,
            address(executor),
            address(registry),
            address(assemblyMetadata),
            address(governorSafe)
        ];
        bytes memory callData =
            abi.encodeCall(companionProducts.dutch.purchasePublic, (_actualPurchase("")));
        writer.writeFileBinary(
            string.concat(folder, "/", label, "-transaction.abi"),
            abi.encode(
                uint256(1),
                block.chainid,
                block.number,
                block.timestamp,
                addresses,
                actualSaleId,
                PURCHASE_PRICE,
                callData
            )
        );
        writer.dumpState(string.concat(folder, "/", label, "-alloc.json"));
    }
}

/// @notice Explicit WAIVED baseline only. Does not establish documentary or royalty acceptance.
abstract contract ActualCanonicalDutchWaivedFixture is
    CurrentCommerceConservationFixture,
    ActualCanonicalDutchPurchaseFixture
{
    function _deployAdditionalProducts()
        internal
        override(StreamCurrentStackFixture, CanonicalNativeSalesDeploymentFixture)
    {
        CanonicalNativeSalesDeploymentFixture._deployAdditionalProducts();
    }

    function _additionalOperatingPolicies()
        internal
        view
        override(StreamCurrentStackFixture, CanonicalNativeSalesDeploymentFixture)
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return _commerceFloorPolicies(
            CanonicalNativeSalesDeploymentFixture._additionalOperatingPolicies()
        );
    }

    function setUp() public virtual override {
        CanonicalNativeSalesDeploymentFixture.setUp();
        _enableWaivedCommerceFloor();
        _activateActualPublicDutch();
    }

}

contract ActualCanonicalDutchWaivedTest is ActualCanonicalDutchWaivedFixture {
    function testActualCanonicalPublicDutchExactPaymentWaived() public {
        S.Purchase memory p = _actualPurchase("");
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        _assertActualPurchase(p, r, 0);
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
    }

    function testActualCanonicalPublicDutch128BytesAndOverpaymentWaived() public {
        bytes memory data = new bytes(128);
        for (uint256 i; i < data.length; ++i) {
            data[i] = bytes1(uint8(i + 1));
        }
        S.Purchase memory p = _actualPurchase(data);
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE + 500);
        _assertActualPurchase(p, r, 500);
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
    }

    function testActualCanonicalFullWidthTokenAndDistinctSerialWaived() public {
        // Synthetic identity-boundary control only, never a gas baseline. Slots are authenticated
        // by the independent exact-28c145 solc storage-layout analysis, not inferred from a trace.
        uint256 previousToken = uint256(1) << 200;
        uint256 nextSerial = (uint256(1) << 220) + 17;
        vm.store(address(core), bytes32(uint256(7)), bytes32(previousToken));
        bytes32 serialSlot = bytes32(uint256(keccak256(abi.encode(uint256(1), uint256(9)))) + 3);
        vm.store(address(core), serialSlot, bytes32(nextSerial));
        S.Purchase memory p = _actualPurchase(hex"aabbcc");
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        (bool exists, uint256 collectionId, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(r.tokenId);
        require(
            r.tokenId == previousToken + 1 && exists && collectionId == 1 && serial == nextSerial
                && !burned,
            "independent full-width token and serial"
        );
        require(
            core.ownerOf(r.tokenId) == BUYER
                && core.coordinatorAtMint(r.tokenId) == address(entropy),
            "actual high-ID mint callbacks"
        );
        require(keccak256(core.tokenData(r.tokenId)) == keccak256(p.tokenData), "high-ID artwork");
        require(
            companionProducts.dutch.executionReceipt(r.executionId).tokenId == r.tokenId,
            "full-width completed consumer token"
        );
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
    }

    function testActualCanonicalPublicDutchReplayLeavesFullReceiptWaived() public {
        S.Purchase memory p = _actualPurchase("");
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        bytes32 original = keccak256(
            abi.encode(
                commerceFloor.firstSale(1),
                commerceFloor.settlementReceipt(r.settlementKey),
                companionRecorder.settlementResult(r.settlementKey)
            )
        );
        vm.prank(BUYER);
        (bool ok,) = address(companionProducts.dutch).call{ value: PURCHASE_PRICE }(
            abi.encodeCall(companionProducts.dutch.purchasePublic, (p))
        );
        require(!ok, "same execution nonce rejected");
        _assertActualPurchase(p, r, 0);
        require(
            original
                == keccak256(
                    abi.encode(
                        commerceFloor.firstSale(1),
                        commerceFloor.settlementReceipt(r.settlementKey),
                        companionRecorder.settlementResult(r.settlementKey)
                    )
                ),
            "history unchanged after replay"
        );
    }

    function testActualCanonicalReceiverRejectRollsBackAndIdenticalRetryWaived() public {
        ActualCanonicalPurchaseReceiver receiver = _actualReceiver();
        S.Purchase memory p = _actualPurchase("");
        p.initialRecipient = address(receiver);
        (StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate,) =
            companionProducts.dutch.previewPublicPurchase(p);
        bytes32 id = candidate.executionBinding.executionId;
        bytes32 key = companionRecorder.settlementKey(address(companionProducts.dutch), id);
        receiver.arm(id, true, address(0));
        bytes32 before_ = _actualRollbackState(id, key);
        vm.prank(BUYER);
        (bool ok,) = address(companionProducts.dutch).call{ value: PURCHASE_PRICE }(
            abi.encodeCall(companionProducts.dutch.purchasePublic, (p))
        );
        require(!ok && receiver.callbacks() == 0, "late receiver failure rolls back callback");
        require(
            _actualRollbackState(id, key) == before_, "full observed purchase state rolled back"
        );
        receiver.arm(id, false, address(0));
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        _assertActualPurchase(p, r, 0);
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
        require(receiver.callbacks() == 1, "same purchase succeeds after recipient recovery");
    }

    function testActualCanonicalReceiverTransferIsNotOverwrittenWaived() public {
        ActualCanonicalPurchaseReceiver receiver = _actualReceiver();
        S.Purchase memory p = _actualPurchase("");
        p.initialRecipient = address(receiver);
        (StreamNativeSettlementTypes.NativeSettlementCandidate memory candidate,) =
            companionProducts.dutch.previewPublicPurchase(p);
        receiver.arm(candidate.executionBinding.executionId, false, BUYER);
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        require(
            core.ownerOf(r.tokenId) == BUYER && receiver.callbacks() == 1,
            "callback transfer retained after completion"
        );
        require(
            companionProducts.dutch.executionStatus(r.executionId) == 2,
            "consumer completed after transfer"
        );
        _assertWaivedCommerceReceipt(address(companionRecorder), r.settlementKey);
    }

    function _actualReceiver() private returns (ActualCanonicalPurchaseReceiver) {
        return new ActualCanonicalPurchaseReceiver(
            address(core),
            address(companionProducts.dutch),
            address(companionRecorder),
            address(commerceFloor),
            address(entropy)
        );
    }

    function _actualRollbackState(bytes32 id, bytes32 key) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                core.lastAllocatedTokenId(),
                core.collectionNextSerial(1),
                core.collectionMintedEver(1),
                core.totalSupply(),
                companionProducts.dutch.saleRecord(actualSaleId),
                companionProducts.dutch.nextExecutionNonce(actualSaleId, BUYER),
                companionProducts.dutch.executionStatus(id),
                companionProducts.dutch.executionReceipt(id),
                companionRecorder.settlementConsumed(key),
                companionRecorder.settlementResult(key),
                companionRecorder.totalOfficialSettled(address(0)),
                commerceFloor.firstSale(1),
                commerceFloor.settlementReceipt(key),
                BUYER.balance,
                address(companionProducts.dutch).balance,
                companionProducts.dutch.refundLiability()
            )
        );
    }
}

/// @notice Real MUSEUM_GRADE_LITE records/provider and the same canonical PLURAL purchase.
/// @dev Reuses documentary setup, including its extra setup-only DIRECT admission and Buyer Safe.
/// No DIRECT purchase is used as the canonical purchase baseline.
abstract contract ActualCanonicalDutchDocumentaryFixture is
    ActualCanonicalDutchPurchaseFixture,
    CurrentDocumentaryConservationFixture
{
    function _deployAdditionalProducts()
        internal
        override(StreamCurrentStackFixture, CanonicalNativeSalesDeploymentFixture)
    {
        CanonicalNativeSalesDeploymentFixture._deployAdditionalProducts();
    }

    function _fixtureSupplyLimit()
        internal
        pure
        override(StreamCurrentStackFixture, CurrentDocumentaryConservationFixture)
        returns (uint64)
    {
        return CurrentDocumentaryConservationFixture._fixtureSupplyLimit();
    }

    function _additionalOperatingPolicies()
        internal
        view
        override(CanonicalNativeSalesDeploymentFixture, CurrentDocumentaryMediaFixture)
        returns (GovernanceActionPolicyEntry[] memory)
    {
        return super._additionalOperatingPolicies();
    }

    function setUp() public virtual override {
        _setUpDocumentaryConservation();
        _activateActualPublicDutch();
    }

    function _assertActualDocumentaryReceipt(S.Receipt memory r) internal view {
        F.SettlementReceipt memory receipt = documentaryFloor.settlementReceipt(r.settlementKey);
        F.FirstSaleReceipt memory first = documentaryFloor.firstSale(1);
        require(
            receipt.receiptHash != 0 && receipt.effectiveTier == DOCUMENTARY_TIER
                && receipt.tokenId == 0,
            "actual non-WAIVED order-1 Floor publication"
        );
        require(
            receipt.settlementKey == r.settlementKey
                && receipt.recorder == address(companionRecorder),
            "real universal Recorder link"
        );
        require(
            receipt.firstSaleReceiptHash == first.receiptHash && first.receiptHash != 0
                && first.sourceId != 0,
            "documentary first-sale evidence"
        );
        require(
            first.facts.identityRecordHash != 0 && first.facts.rightsRecordHash != 0
                && first.facts.personhoodEvidenceHash != 0,
            "real Artist documentary facts"
        );
        require(receipt.releaseReceiptHash != 0, "real release evidence published");
        require(
            documentaryFloor.sourceAt(first.sourceId).provider == address(documentaryProvider),
            "admitted actual documentary provider"
        );
        require(
            keccak256(abi.encode(first.facts))
                == keccak256(abi.encode(_expectedDocumentaryCollectionFacts())),
            "complete documentary collection facts"
        );
        F.ReleaseContext memory context = _documentaryContext();
        F.ReleaseFloorReceipt memory release =
            documentaryFloor.releaseFloorReceipt(_documentaryReleaseKey(context));
        require(
            release.receiptHash == receipt.releaseReceiptHash
                && release.recorder == address(companionRecorder)
                && release.settlementKey == r.settlementKey,
            "exact universal release history"
        );
        require(
            keccak256(abi.encode(release.context)) == keccak256(abi.encode(context))
                && release.facts.mediaEvidenceHash == documentaryMediaEvidenceHash
                && release.facts.referenceEvidenceHash == 0,
            "occupied OFFCHAIN master evidence"
        );
    }
}

contract ActualCanonicalDutchDocumentaryTest is ActualCanonicalDutchDocumentaryFixture {
    function testActualCanonicalPublicDutchExactPaymentDocumentary() public {
        S.Purchase memory p = _actualPurchase("");
        S.Receipt memory r = _buyActual(p, PURCHASE_PRICE);
        _assertActualPurchase(p, r, 0);
        _assertActualDocumentaryReceipt(r);
    }
}

contract ActualCanonicalDutchWaivedExportTest is ActualCanonicalDutchWaivedFixture {
    // Only testExportActualWaived may be selected in this host. It performs setup in its own journal.
    function setUp() public override { }

    function testExportActualWaived() public {
        ActualCanonicalDutchWaivedFixture.setUp();
        _exportActualPurchase("waived", address(commerceFloor));
    }
}

contract ActualCanonicalDutchDocumentaryExportTest is ActualCanonicalDutchDocumentaryFixture {
    // Only testExportActualDocumentary may be selected in this host; no --isolate during export.
    function setUp() public override { }

    function testExportActualDocumentary() public {
        ActualCanonicalDutchDocumentaryFixture.setUp();
        _exportActualPurchase("documentary", address(documentaryFloor));
    }
}
