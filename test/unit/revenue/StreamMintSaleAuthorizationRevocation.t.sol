// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

interface CuratedRevocationVm {
    function mockCall(address target, bytes calldata data, bytes calldata returned) external;
    function clearMockedCalls() external;
}

/// @dev Only the immutable sale-record boundary is typed. Manager/Ledger/registry/Safe are actual.
contract CuratedHistoricalSignerFixture {
    address public immutable signer;
    uint8 public immutable kind;
    bytes32 public immutable phase;

    constructor(address s, uint8 k, bytes32 p) {
        signer = s;
        kind = k;
        phase = p;
    }

    function curatedSaleAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        return (1, phase, signer, kind, keccak256("immutable sale configuration"));
    }
}

contract StreamMintSaleAuthorizationRevocationTest is MintRevocationTestBase, OfficialSafeFixture {
    function testSixStoredViewCodecsRetainCanonicalWidthsAndActualPhaseUpdates() public {
        StreamPreparedNativeSettlementTypes.Facts memory nativeFacts;
        StreamPreparedNativeContentTypes.Facts memory contentFacts;
        StreamPreparedNativeRightsTypes.Facts memory rightsFacts;
        _readEquals(abi.encodeCall(manager.activePreparedNativeMint, ()), abi.encode(nativeFacts));
        _readEquals(
            abi.encodeCall(manager.activePreparedNativeContent, ()), abi.encode(contentFacts)
        );
        _readEquals(abi.encodeCall(manager.activePreparedNativeRights, ()), abi.encode(rightsFacts));
        IStreamMintManager.MintPhaseConfig memory phaseConfig = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 10, keccak256("config"), keccak256("metadata")
        );
        _readEquals(
            abi.encodeCall(manager.phase, (uint256(1), PHASE)), abi.encode(true, phaseConfig)
        );
        manager.setPhasePaused(1, PHASE, true);
        phaseConfig.paused = true;
        _readEquals(
            abi.encodeCall(manager.phase, (uint256(1), PHASE)), abi.encode(true, phaseConfig)
        );
        IStreamMintManager.MintCounterConfig memory counter = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            100,
            1,
            keccak256("counter config")
        );
        _readEquals(
            abi.encodeCall(manager.counterConfig, (uint256(1), PHASE, keccak256("supply"))),
            abi.encode(counter)
        );
        IStreamMintManager.MintGateConfig memory gate;
        _readEquals(abi.encodeCall(manager.phaseGate, (uint256(1), PHASE)), abi.encode(gate));
    }

    function _readEquals(bytes memory data, bytes memory expected) private view {
        (bool ok, bytes memory actual) = address(manager).staticcall(data);
        require(
            ok && actual.length == expected.length && keccak256(actual) == keccak256(expected),
            "exact typed view bytes"
        );
    }

    function _sale(address adapter, uint256 nonce)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        a.chainId = block.chainid;
        a.saleAdapter = adapter;
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = PHASE;
        a.saleId = keccak256("stable sale");
        a.saleKind = 5;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = keccak256("original primary");
        a.initialRecipientsHash = keccak256("original recipients");
        a.beneficiariesHash = keccak256("original beneficiaries");
        a.tokenDataArrayHash = keccak256("original full token bytes");
        a.mintCommitmentsHash = keccak256("original commitments");
        a.payer = address(0xA);
        a.executor = address(0xB);
        a.unitPrice = 1 ether;
        a.quantity = 1;
        a.contentSelectionHash = keccak256("original content leaf");
        a.policyHash = keccak256("original phase policy");
        a.nonce = bytes32(nonce);
        a.deadline = 1001;
    }

    function _literalId(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        bytes32 domain = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                a.saleAdapter
            )
        );
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                keccak256(abi.encodePacked(hex"1901", domain, body))
            )
        );
    }

    function testOriginalFullDigestAndExpiredUnavailablePhaseStillVoidExactLedgerKey() public {
        address adapter = address(new CuratedHistoricalSignerFixture(signer, 1, PHASE));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 1);
        bytes32 id = _literalId(a);
        require(id == manager.mintSaleAuthorizationId(a), "original full digest");
        uint256 operationNonce = manager.nextOperationNonce();
        manager.setPhasePaused(1, PHASE, true);
        core.setUnavailable(true);
        vm.warp(3000);
        vm.prank(signer);
        require(manager.voidMintSaleAuthorization(a, "") == id, "same key");
        require(ledger.isManagerAuthorizationUsed(address(manager), id), "actual Ledger void");
        require(
            manager.nextOperationNonce() == operationNonce && core.minted() == 0, "no mint or nonce"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
    }

    function testVoidThenActualManagerConsumeAndConsumeThenVoidShareReplay() public {
        address adapter = address(new CuratedHistoricalSignerFixture(signer, 1, PHASE));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 2);
        bytes32 id = _literalId(a);
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
        IStreamMintManager.MintBatch memory b = _batch(id);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        manager.executeSingleStepMint(b, "");
        a.nonce = bytes32(uint256(3));
        id = _literalId(a);
        b = _batch(id);
        manager.executeSingleStepMint(b, "");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
        require(core.minted() == 1, "sole actual consume");
    }

    function testFullPayloadSubstitutionAndOrdinarySaleSignatureCannotRevoke() public {
        address adapter = address(new CuratedHistoricalSignerFixture(signer, 1, PHASE));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 4);
        bytes32 id = _literalId(a);
        bytes memory proof = _signature(
            SIGNER_KEY, _revokeDigest(StreamPrivateSaleHash.domain(block.chainid, adapter), id)
        );
        a.tokenDataArrayHash = keccak256("substitution");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector, signer
            )
        );
        manager.voidMintSaleAuthorization(a, proof);
        a = _sale(adapter, 4);
        bytes memory saleProof = _signature(
            SIGNER_KEY,
            StreamPrivateSaleHash.digest(
                block.chainid, adapter, StreamPrivateSaleHash.authorizationBody(a)
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector, signer
            )
        );
        manager.voidMintSaleAuthorization(a, saleProof);
        manager.voidMintSaleAuthorization(a, proof);
        require(
            ledger.isManagerAuthorizationUsed(address(manager), id), "same revocation proof retry"
        );
    }

    function testWrongHistoricalMemberAndMalformedBindingRefuseBeforeLedgerWrite() public {
        address adapter = address(new CuratedHistoricalSignerFixture(signer, 1, PHASE));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 5);
        bytes32 id = _literalId(a);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector, signer
            )
        );
        manager.voidMintSaleAuthorization(a, "");
        bytes memory callData =
            abi.encodeWithSignature("curatedSaleAuthorizationBinding(bytes32)", a.saleId);
        CuratedRevocationVm(address(vm)).mockCall(adapter, callData, new bytes(192));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding.selector
            )
        );
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
        CuratedRevocationVm(address(vm)).clearMockedCalls();
        a.phaseId = keccak256("wrong phase");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding.selector
            )
        );
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
        require(!ledger.isManagerAuthorizationUsed(address(manager), id), "no replay consumed");
    }

    function testActualSafeIdenticalTransactionRetriesAfterLedgerRestoration() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xAC01;
        keys[1] = 0xAC02;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 17);
        address adapter = address(new CuratedHistoricalSignerFixture(address(account), 2, PHASE));
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 6);
        bytes32 id = _literalId(a);
        bytes memory data = abi.encodeCall(manager.voidMintSaleAuthorization, (a, bytes("")));
        uint256 nonce = account.nonce();
        bytes memory sig = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes memory saved = abi.encodeCall(
            account.execTransaction,
            (address(manager), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sig)
        );
        ledger.setLedgerWriter(address(manager), false);
        (bool ok, bytes memory failure) = address(account).call(saved);
        require(
            !ok
                && keccak256(failure)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "exact Safe denial"
        );
        require(
            account.nonce() == nonce && !ledger.isManagerAuthorizationUsed(address(manager), id),
            "atomic failure"
        );
        ledger.setLedgerWriter(address(manager), true);
        bytes memory result;
        (ok, result) = address(account).call(saved);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)), "identical signed CALL retry"
        );
        require(
            account.nonce() == nonce + 1 && ledger.isManagerAuthorizationUsed(address(manager), id),
            "actual Safe Ledger completion"
        );
    }
}
