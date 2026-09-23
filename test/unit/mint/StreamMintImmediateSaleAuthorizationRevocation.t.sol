// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintRevocationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @dev Typed adapter seam. Only the historical getter is a product boundary in this unit suite.
contract ImmediateHistoricalSignerFixture is IStreamImmediateSaleAuthorizationBinding {
    bytes32 public immutable saleId;
    bytes32 public immutable phase;
    address public immutable signer;
    uint8 public immutable kind;
    uint8 public immutable saleKind;
    bool public live = true;

    constructor(bytes32 id, bytes32 p, address s, uint8 k, uint8 saleKind_) {
        saleId = id;
        phase = p;
        signer = s;
        kind = k;
        saleKind = saleKind_;
    }

    function withdrawLiveMembership() external {
        live = false;
    }

    function immediateSaleAuthorizationBinding(bytes32 id)
        external
        view
        returns (uint256, bytes32, uint8, uint8, bytes32, address, uint8)
    {
        require(id == saleId, "unknown sale");
        return (1, phase, saleKind, 1, keccak256("immutable sale config"), signer, kind);
    }
}

/// @dev Adversarial fixed-read seam: arbitrary length and noncanonical words, without mockCall.
contract ImmediateMalformedBindingFixture {
    bytes private _reply;
    bool private _fail;

    function setReply(bytes calldata reply, bool fail) external {
        _reply = reply;
        _fail = fail;
    }

    fallback() external {
        require(!_fail, "binding unavailable");
        bytes memory reply = _reply;
        assembly ("memory-safe") { return(add(reply, 32), mload(reply)) }
    }
}

/// @notice Actual Manager/Ledger/registry and Safe 1.4.1; Core, Artist and adapter are typed seams.
/// @dev This suite does not claim actual current Core/Artist or the new adapter's purchase flow.
contract StreamMintImmediateSaleAuthorizationRevocationTest is
    MintRevocationTestBase,
    OfficialSafeFixture
{
    bytes32 private constant SALE = keccak256("immutable immediate sale");

    function testFixedDirectVoidUsesFullDigestAndOnlyExistingLedgerEvents() public {
        address adapter = _adapter(signer, 1, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 0, 1);
        bytes32 id = _literalId(a);
        require(manager.mintSaleAuthorizationId(a) == id, "canonical original id");
        require(
            manager.supportsInterface(
                type(IStreamMintImmediateSaleAuthorizationRevocation).interfaceId
            ),
            "additive capability"
        );
        require(
            manager.supportsInterface(type(IStreamMintSaleAuthorizationRevocation).interfaceId),
            "private capability retained"
        );
        (bytes32 root,) = manager.previewSingleStepMintOperation(_batch(id), "");
        vm.recordLogs();
        vm.prank(signer);
        require(manager.voidMintImmediateSaleAuthorization(a, signer, 1, "") == id, "same id");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "only existing void events");
        require(
            logs[0].emitter == address(ledger) && logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256("MintLedgerAuthorizationVoided(uint16,bytes32,address)")
                && logs[0].topics[1] == id
                && logs[0].topics[2] == bytes32(uint256(uint160(address(manager))))
                && keccak256(logs[0].data) == keccak256(abi.encode(uint16(1))),
            "Ledger event"
        );
        require(
            logs[1].emitter == address(manager) && logs[1].topics.length == 4
                && logs[1].topics[0]
                    == keccak256(
                        "MintAuthorizationVoided(uint16,uint256,bytes32,bytes32,address,address,uint8)"
                    ) && logs[1].topics[1] == bytes32(uint256(1)) && logs[1].topics[2] == PHASE
                && logs[1].topics[3] == id
                && keccak256(logs[1].data)
                    == keccak256(abi.encode(uint16(1), signer, adapter, uint8(2))),
            "Sales family event"
        );
        require(
            ledger.isManagerAuthorizationUsed(address(manager), id)
                && !manager.isOperationRootUsed(root) && manager.nextOperationNonce() == 0
                && core.minted() == 0,
            "void only"
        );
    }

    function testOpenHistoricalSignerRevokesAfterExpiryPauseAndCoreUnavailability() public {
        address adapter = _adapter(signer, 1, 1);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 1, 2);
        bytes32 id = _literalId(a);
        bytes memory proof = _proof(a);
        ImmediateHistoricalSignerFixture(adapter).withdrawLiveMembership();
        manager.setPhasePaused(1, PHASE, true);
        core.setUnavailable(true);
        vm.warp(5000);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, proof);
        require(
            manager.isAuthorizationUsed(id) && !ImmediateHistoricalSignerFixture(adapter).live(),
            "historical member only"
        );
    }

    function testVoidThenMintAndMintThenVoidUseSameActualReplayMap() public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 0), 0, 3);
        bytes32 id = _literalId(a);
        IStreamMintManager.MintBatch memory b = _batch(id);
        (bytes32 root,) = manager.previewSingleStepMintOperation(b, "");
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        manager.executeSingleStepMint(b, "");
        require(
            !manager.isOperationRootUsed(root) && manager.nextOperationNonce() == 0
                && core.minted() == 0,
            "mint rollback"
        );
        a.nonce = bytes32(uint256(4));
        id = _literalId(a);
        manager.executeSingleStepMint(_batch(id), "");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        require(core.minted() == 1 && manager.nextOperationNonce() == 1, "sole consume");
    }

    function testOrdinarySaleAndCustodyRevocationSignaturesCannotVoid() public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 0), 0, 5);
        bytes32 digest = _saleDigest(a);
        bytes memory ordinary = _signature(SIGNER_KEY, digest);
        _expectSignature(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, ordinary);
        bytes32 custody = keccak256(
            abi.encodePacked(
                hex"1901",
                _domain(a.saleAdapter),
                keccak256(
                    abi.encode(
                        keccak256(
                            "SaleAuthorizationRevocation(uint256 chainId,address saleAdapter,address authorizer,bytes32 authorizationDigest)"
                        ),
                        block.chainid,
                        a.saleAdapter,
                        signer,
                        digest
                    )
                )
            )
        );
        bytes memory custodyProof = _signature(SIGNER_KEY, custody);
        _expectSignature(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, custodyProof);
        require(!manager.isAuthorizationUsed(_literalId(a)), "failed proofs do not void");
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, _proof(a));
        require(manager.isAuthorizationUsed(_literalId(a)), "original domain revocation");
    }

    function testFullPayloadSubstitutionCannotReuseOriginalRevocationProof() public {
        address adapter = _adapter(signer, 1, 0);
        StreamPrivateSaleTypes.SaleAuthorization memory original = _sale(adapter, 0, 6);
        bytes memory proof = _proof(original);
        // Every non-namespace payload word remains committed even though revocation does not
        // check current economics, expiry, payer membership or live policy values.
        uint256[18] memory words =
            [uint256(8), 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 3, 4];
        for (uint256 i; i < words.length; ++i) {
            StreamPrivateSaleTypes.SaleAuthorization memory changed = _sale(adapter, 0, 6);
            uint256 index = words[i];
            assembly ("memory-safe") {
                let ptr := add(changed, mul(index, 32))
                mstore(ptr, xor(mload(ptr), 1))
            }
            if (index == 3 || index == 4) _expectBinding();
            else _expectSignature(signer);
            manager.voidMintImmediateSaleAuthorization(changed, signer, 1, proof);
            require(!manager.isAuthorizationUsed(_literalId(changed)), "substituted id unused");
        }
        manager.voidMintImmediateSaleAuthorization(original, signer, 1, proof);
        require(manager.isAuthorizationUsed(_literalId(original)), "same proof retry");
    }

    function testNamespacesUnknownSaleAndUnsupportedFamiliesFailBeforeVoid() public {
        address adapter = _adapter(signer, 1, 0);
        for (uint256 i; i < 10; ++i) {
            StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(adapter, 0, 7);
            if (i == 0) a.chainId += 1;
            else if (i == 1) a.mintManager = address(0xBAD);
            else if (i == 2) a.saleAdapter = address(0);
            else if (i == 3) a.saleAdapter = address(0xE0A);
            else if (i == 4) a.saleId = 0;
            else if (i == 5) a.saleId = keccak256("unknown sale");
            else if (i == 6) a.collectionId = 0;
            else if (i == 7) a.phaseId = 0;
            else if (i == 8) a.saleKind = 5;
            else a.revenueClass = keccak256("SECONDARY_SALE");
            _expectBinding();
            vm.prank(signer);
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        }
        StreamPrivateSaleTypes.SaleAuthorization memory valid = _sale(adapter, 0, 7);
        require(!manager.isAuthorizationUsed(_literalId(valid)), "original unused");
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(valid, signer, 1, "");
    }

    function testClaimedSignerAndKindMustMatchHistoricalMember() public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 0), 0, 8);
        _expectBinding();
        manager.voidMintImmediateSaleAuthorization(a, address(0), 1, "");
        _expectBinding();
        vm.prank(address(0xBAD));
        manager.voidMintImmediateSaleAuthorization(a, address(0xBAD), 1, "");
        _expectBinding();
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 2, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationUnsupportedKind.selector, uint8(0)
            )
        );
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 0, "");
        _expectSignature(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        require(!manager.isAuthorizationUsed(_literalId(a)), "no failed attempt consumed");
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
    }

    function testMalformedShortLongAndRevertingBindingsFailClosed() public {
        ImmediateMalformedBindingFixture adapter = new ImmediateMalformedBindingFixture();
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(address(adapter), 0, 9);
        uint256[7] memory lengths = [uint256(0), 32, 223, 225, 256, 1024, 65536];
        for (uint256 i; i < lengths.length; ++i) {
            bytes memory reply = new bytes(lengths[i]);
            bytes memory valid = _binding();
            // Long replies have an otherwise valid canonical prefix, so the length guard
            // itself must reject them. Short replies contain that prefix truncated exactly.
            for (uint256 j; j < reply.length && j < valid.length; ++j) {
                reply[j] = valid[j];
            }
            adapter.setReply(reply, false);
            _expectBinding();
            vm.prank(signer);
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        }
        adapter.setReply(_binding(), true);
        _expectBinding();
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        require(!manager.isAuthorizationUsed(_literalId(a)), "no malformed write");
        adapter.setReply(_binding(), false);
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        require(manager.isAuthorizationUsed(_literalId(a)), "same payload after repair");
    }

    function testNoncanonicalBindingWordsPublicModeAndZeroConfigRefuse() public {
        ImmediateMalformedBindingFixture adapter = new ImmediateMalformedBindingFixture();
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(address(adapter), 0, 10);
        for (uint256 i; i < 10; ++i) {
            uint256[7] memory words = abi.decode(_binding(), (uint256[7]));
            if (i == 0) words[0] = 0;
            else if (i == 1) words[1] = 0;
            else if (i == 2) words[2] = 256;
            else if (i == 3) words[3] = 257;
            else if (i == 4) words[3] = 2;
            else if (i == 5) words[4] = 0;
            else if (i == 6) words[5] |= uint256(1) << 160;
            else if (i == 7) words[5] = 0;
            else if (i == 8) words[6] = 257;
            else words[6] = 0;
            adapter.setReply(abi.encode(words), false);
            _expectBinding();
            vm.prank(signer);
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
        }
        require(!manager.isAuthorizationUsed(_literalId(a)), "all words exact");
        adapter.setReply(_binding(), false);
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
    }

    function testPrivateEntryStillRejectsImmediateFamily() public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 0), 0, 11);
        _expectBinding();
        vm.prank(signer);
        manager.voidMintSaleAuthorization(a, "");
        vm.prank(signer);
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
    }

    function testEveryWhitelistedImmediateKindDirectlyVoidsHistoricalPayload() public {
        uint8[5] memory kinds = [uint8(0), 1, 3, 12, 13];
        manager.setPhasePaused(1, PHASE, true);
        core.setUnavailable(true);
        vm.warp(5000);
        for (uint256 i; i < kinds.length; ++i) {
            StreamPrivateSaleTypes.SaleAuthorization memory a =
                _sale(_adapter(signer, 1, kinds[i]), kinds[i], 100 + i);
            if (kinds[i] == 12 || kinds[i] == 13) a.unitPrice = 0;
            bytes32 id = _literalId(a);
            vm.prank(signer);
            require(
                manager.voidMintImmediateSaleAuthorization(a, signer, 1, "") == id,
                "same canonical digest"
            );
            require(
                ledger.isManagerAuthorizationUsed(address(manager), id),
                "each approved kind uses actual Ledger"
            );
        }
        require(
            core.minted() == 0 && manager.nextOperationNonce() == 0,
            "historical void has no mint effects"
        );
    }

    function testDutchZeroAndPWYWHistoricalRevocationRelaysOriginalSalesProof() public {
        uint8[3] memory kinds = [uint8(3), 12, 13];
        for (uint256 i; i < kinds.length; ++i) {
            StreamPrivateSaleTypes.SaleAuthorization memory a =
                _sale(_adapter(signer, 1, kinds[i]), kinds[i], 200 + i);
            // Economic limits are historical signature inputs, never current revocation admission.
            a.unitPrice = kinds[i] == 3 ? type(uint256).max : 0;
            bytes32 id = _literalId(a);
            bytes memory proof = _proof(a);
            vm.warp(6000 + i);
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, proof);
            require(manager.isAuthorizationUsed(id), "original domain proof voids new kind");
            vm.expectRevert(
                abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
            );
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, proof);
        }
    }

    function testKindWhitelistRejectsAuctionPrivateDeferredReservedAndUnknownValues() public {
        uint8[12] memory kinds = [uint8(2), 4, 5, 6, 7, 8, 9, 10, 11, 14, 15, 255];
        for (uint256 i; i < kinds.length; ++i) {
            StreamPrivateSaleTypes.SaleAuthorization memory a =
                _sale(_adapter(signer, 1, kinds[i]), kinds[i], 300 + i);
            _expectBinding();
            vm.prank(signer);
            manager.voidMintImmediateSaleAuthorization(a, signer, 1, "");
            require(
                !manager.isAuthorizationUsed(_literalId(a)),
                "matching historical binding cannot widen supported kinds"
            );
        }
    }

    function testActualSafeIdenticalSignedCallRetriesAfterLedgerWriterRestoration() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _sale(_adapter(address(account), 2, 0), 0, 12);
        bytes32 id = _literalId(a);
        bytes memory data = abi.encodeCall(
            manager.voidMintImmediateSaleAuthorization, (a, address(account), uint8(2), bytes(""))
        );
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(manager), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        bytes memory saved = abi.encodeCall(
            account.execTransaction,
            (address(manager), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signatures)
        );
        ledger.setLedgerWriter(address(manager), false);
        (bool ok, bytes memory result) = address(account).call(saved);
        require(
            !ok
                && keccak256(result)
                    == keccak256(abi.encodeWithSignature("Error(string)", "GS013")),
            "exact Safe failure"
        );
        require(
            account.nonce() == nonce && !manager.isAuthorizationUsed(id), "Safe and Ledger rollback"
        );
        ledger.setLedgerWriter(address(manager), true);
        (ok, result) = address(account).call(saved);
        require(
            ok && result.length == 32 && abi.decode(result, (bool)), "identical signed call retry"
        );
        require(
            account.nonce() == nonce + 1 && ledger.isManagerAuthorizationUsed(address(manager), id),
            "actual Safe completion"
        );
    }

    function testActualSafeRelayedRevocationRequiresSafeMessageWrapper() public {
        (OfficialSafe account, uint256[] memory keys) = _safe();
        StreamPrivateSaleTypes.SaleAuthorization memory a =
            _sale(_adapter(address(account), 2, 1), 1, 13);
        bytes32 id = _literalId(a);
        bytes32 digest = _revokeDigest(_domain(a.saleAdapter), id);
        bytes memory raw = safeThresholdSignature(keys, digest);
        _expectSignature(address(account));
        manager.voidMintImmediateSaleAuthorization(a, address(account), 2, raw);
        require(!manager.isAuthorizationUsed(id), "raw proof refused");
        bytes memory proof =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest)));
        manager.voidMintImmediateSaleAuthorization(a, address(account), 2, proof);
        require(
            manager.isAuthorizationUsed(id) && account.nonce() == 0, "relayed actual Safe proof"
        );
    }

    function testCodeBearingECDSAClaimUsesExplicitKindAndCompactProof() public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 0), 0, 14);
        vm.etch(signer, hex"60006000fd");
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(SIGNER_KEY, _revokeDigest(_domain(a.saleAdapter), _literalId(a)));
        bytes32 vs = bytes32(uint256(s) | (uint256(v - 27) << 255));
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, abi.encodePacked(r, vs));
        require(manager.isAuthorizationUsed(_literalId(a)), "explicit ECDSA kind");
    }

    function testFuzzHistoricalPayloadUsesEveryOriginalHashWithoutLiveEconomics(
        bytes32 salt,
        uint256 price,
        uint256 quantity,
        uint64 deadline,
        uint64 finalizeBy,
        uint8 primaryMode
    ) public {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _sale(_adapter(signer, 1, 1), 1, 15);
        a.unitPrice = price;
        a.quantity = quantity;
        a.deadline = deadline;
        a.finalizeBy = finalizeBy;
        a.primaryPolicyMode = primaryMode;
        a.expectedPrimaryPolicyHash = keccak256(abi.encode(salt, uint8(0)));
        a.initialRecipientsHash = keccak256(abi.encode(salt, uint8(1)));
        a.beneficiariesHash = keccak256(abi.encode(salt, uint8(2)));
        a.tokenDataArrayHash = keccak256(abi.encode(salt, uint8(3)));
        a.mintCommitmentsHash = keccak256(abi.encode(salt, uint8(4)));
        a.contentSelectionHash = keccak256(abi.encode(salt, uint8(5)));
        a.policyHash = keccak256(abi.encode(salt, uint8(6)));
        a.nonce = salt;
        bytes32 id = _literalId(a);
        require(manager.mintSaleAuthorizationId(a) == id, "independent full hash");
        manager.voidMintImmediateSaleAuthorization(a, signer, 1, _proof(a));
        require(manager.isAuthorizationUsed(id) && core.minted() == 0, "historical full payload");
    }

    function _adapter(address authorizer, uint8 kind, uint8 saleKind) private returns (address) {
        return
            address(new ImmediateHistoricalSignerFixture(SALE, PHASE, authorizer, kind, saleKind));
    }

    function _sale(address adapter, uint8 saleKind, uint256 nonce)
        private
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        a.chainId = block.chainid;
        a.saleAdapter = adapter;
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = PHASE;
        a.saleId = SALE;
        a.saleKind = saleKind;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = keccak256("original primary policy");
        a.initialRecipientsHash = keccak256("original recipients");
        a.beneficiariesHash = keccak256("original beneficiaries");
        a.tokenDataArrayHash = keccak256("original token data");
        a.mintCommitmentsHash = keccak256("original mint commitments");
        a.payer = address(0xA);
        a.executor = address(0xA);
        a.unitPrice = 1 ether;
        a.quantity = 1;
        a.contentSelectionHash = keccak256("original content selection");
        a.policyHash = keccak256("original phase policy");
        a.nonce = bytes32(nonce);
        a.deadline = 1001;
    }

    function _domain(address adapter) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256("6529Stream Sales"),
                keccak256("1"),
                block.chainid,
                adapter
            )
        );
    }

    function _saleDigest(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        bytes32 body = keccak256(
            abi.encode(
                keccak256(
                    "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
                ),
                a
            )
        );
        return keccak256(abi.encodePacked(hex"1901", _domain(a.saleAdapter), body));
    }

    function _literalId(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), _saleDigest(a))
        );
    }

    function _proof(StreamPrivateSaleTypes.SaleAuthorization memory a)
        private
        returns (bytes memory)
    {
        return _signature(SIGNER_KEY, _revokeDigest(_domain(a.saleAdapter), _literalId(a)));
    }

    function _binding() private view returns (bytes memory) {
        return abi.encode(
            uint256(1),
            PHASE,
            uint8(0),
            uint8(1),
            keccak256("immutable sale config"),
            signer,
            uint8(1)
        );
    }

    function _safe() private returns (OfficialSafe account, uint256[] memory keys) {
        keys = new uint256[](2);
        keys[0] = 0xAC01;
        keys[1] = 0xAC02;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 171);
        require(
            keccak256(bytes(account.VERSION())) == keccak256("1.4.1")
                && account.getThreshold() == 2,
            "actual Safe"
        );
    }

    function _expectBinding() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding.selector
            )
        );
    }

    function _expectSignature(address expectedSigner) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                expectedSigner
            )
        );
    }
}
