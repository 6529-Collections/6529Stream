// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamNativeCuratedContentGate.sol";
import "../../../smart-contracts/domains/auctions/StreamNativeAuctionContentGate.sol";

interface CuratedGateVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function warp(uint256 timestamp) external;
    function chainId(uint256 value) external;
    function prank(address sender) external;
    function etch(address target, bytes calldata runtime) external;
    function addr(uint256 key) external returns (address);
    function sign(uint256 key, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function expectRevert(bytes4 selector) external;
    function expectRevert() external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Typed active-admission fixture only. It neither derives raw batch hashes nor mints.
contract CuratedGateManagerFixture {
    struct Request {
        address manager;
        address executor;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address authorizer;
        address[] initialRecipients;
        address[] beneficiaries;
        bytes32 contextHash;
        bytes32 policyHash;
    }
    bytes32 public preparedNativeContentAdmission;

    function admit(bytes32 value) external {
        preparedNativeContentAdmission = value;
    }

    function validate(IStreamMintGate gate, Request memory r, bytes memory data)
        external
        view
        returns (IStreamMintGate.GateResult memory)
    {
        return gate.validateMint(
            r.manager,
            r.executor,
            r.collectionId,
            r.phaseId,
            r.payer,
            r.authorizer,
            r.initialRecipients,
            r.beneficiaries,
            r.contextHash,
            r.policyHash,
            data
        );
    }
}

/// @dev Explicit active sale receipts and immutable-membership read seam; no sale admission simulated.
contract CuratedGateHouseFixture {
    bytes32 private _active;
    StreamPreparedNativeContentPurchaseTypes.Purchase private _purchase;
    StreamPreparedNativeSettlementTypes.Intent private _intent;
    uint256 private _collection;
    bytes32 private _phase;
    address private _signer;
    uint8 private _kind;
    bytes32 private _config;
    uint256 public cap = 200000;
    bool public unavailable;

    function arm(
        bytes32 active,
        StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
        StreamPreparedNativeSettlementTypes.Intent memory i
    ) external {
        _active = active;
        _purchase = p;
        _intent = i;
    }

    function binding(uint256 collection, bytes32 phase, address signer, uint8 kind, bytes32 config)
        external
    {
        _collection = collection;
        _phase = phase;
        _signer = signer;
        _kind = kind;
        _config = config;
    }

    function setCap(uint256 value) external {
        cap = value;
    }

    function setUnavailable(bool value) external {
        unavailable = value;
    }

    function gasParameter(bytes32) external view returns (uint256) {
        return cap;
    }

    function curatedSaleAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        require(!unavailable, "inactive fixture");
        return (_collection, _phase, _signer, _kind, _config);
    }

    function activePreparedNativeContentPurchase(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeContentPurchaseTypes.Purchase memory)
    {
        require(!unavailable && hash == _active, "inactive fixture");
        return _purchase;
    }

    function activePreparedNativeContentIntent(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory)
    {
        require(!unavailable && hash == _active, "inactive fixture");
        return _intent;
    }
}

/// @dev ERC1271 positive path verifies an actual owner ECDSA signature over the supplied digest.
contract CuratedGateSignatureWallet {
    address private immutable owner;
    uint256 private mode;

    constructor(address signer) {
        owner = signer;
    }

    function setMode(uint256 value) external {
        mode = value;
    }

    function isValidSignature(bytes32 digest, bytes calldata signature)
        external
        view
        returns (bytes4)
    {
        if (mode == 1) revert("wallet unavailable");
        if (mode != 0) {
            uint256 m = mode;
            assembly ("memory-safe") {
                mstore(0, shl(224, 0x1626ba7e))
                switch m
                case 2 { return(0, 4) }
                case 3 { return(0, 64) }
                default {
                    mstore(0, or(mload(0), 1))
                    return(0, 32)
                }
            }
        }
        if (signature.length != 65) return 0xffffffff;
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        return ecrecover(digest, v, r, s) == owner ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }
}

/// @dev Gate only: Manager admission is an explicit fixture, not actual Manager/Ledger/settlement evidence.
contract StreamNativeCuratedContentGateTest {
    CuratedGateVm private constant vm =
        CuratedGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant KEY = 0xC017;
    bytes32 private constant SALE = keccak256("original immutable curated sale");
    bytes32 private constant PHASE = keccak256("phase");
    bytes32 private constant COUNTER = keccak256("content context counter");
    bytes32 private constant CONFIG = keccak256("immutable sale configuration");
    bytes32 private constant POLICY = keccak256("mint policy");
    address private constant BUYER = address(0xB0B);
    address private constant EXECUTOR = address(0xCA11);
    CuratedGateManagerFixture private manager;
    CuratedGateHouseFixture private house;
    StreamNativeCuratedContentGate private gate;
    address private seller;

    struct Case {
        CuratedGateManagerFixture.Request request;
        StreamPreparedNativeContentPurchaseTypes.GateData data;
        StreamPreparedNativeContentPurchaseTypes.Purchase purchase;
        StreamPreparedNativeSettlementTypes.Intent intent;
    }

    function setUp() external {
        vm.warp(1000);
        seller = vm.addr(KEY);
        manager = new CuratedGateManagerFixture();
        house = new CuratedGateHouseFixture();
        gate = _deploy(_rows());
        house.binding(1, PHASE, seller, 1, CONFIG);
    }

    function _rows() private pure returns (StreamPreparedNativeContentTypes.Row[] memory rows) {
        rows = new StreamPreparedNativeContentTypes.Row[](3);
        rows[0] = StreamPreparedNativeContentTypes.Row(0, keccak256(""), "urn:preview:empty");
        rows[1] = StreamPreparedNativeContentTypes.Row(
            bytes32(uint256(1)), keccak256("artwork one"), "urn:preview:one"
        );
        rows[2] = StreamPreparedNativeContentTypes.Row(
            bytes32(uint256(2)), keccak256("artwork two"), "urn:preview:two"
        );
    }

    function _deploy(StreamPreparedNativeContentTypes.Row[] memory rows)
        private
        returns (StreamNativeCuratedContentGate)
    {
        return new StreamNativeCuratedContentGate(
            address(manager), address(house), SALE, 1, PHASE, COUNTER, rows
        );
    }

    function _leaf(bytes32 id, bytes32 data) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(house),
                        SALE,
                        id,
                        data
                    )
                )
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }

    function _context(bytes32 id) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_CONTEXT_V1"), block.chainid, address(house), SALE, id
            )
        );
    }

    function _purchaseId(uint256 nonce) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"),
                block.chainid,
                address(house),
                SALE,
                BUYER,
                nonce
            )
        );
    }

    function _publicCase() private view returns (Case memory c) {
        c.request = CuratedGateManagerFixture.Request(
            address(manager),
            address(house),
            1,
            PHASE,
            BUYER,
            address(0),
            new address[](1),
            new address[](1),
            _context(bytes32(uint256(1))),
            POLICY
        );
        c.request.initialRecipients[0] = address(house);
        c.request.beneficiaries[0] = BUYER;
        c.data.intentHash = keccak256("active positive-price intent");
        c.data.authorizationId = c.data.intentHash;
        c.data.selection = StreamPreparedNativeContentTypes.Selection(
            bytes32(uint256(1)), keccak256("artwork one"), new bytes32[](2)
        );
        c.data.selection.proof[0] = _leaf(0, keccak256(""));
        c.data.selection.proof[1] = _leaf(bytes32(uint256(2)), keccak256("artwork two"));
        c.purchase = StreamPreparedNativeContentPurchaseTypes.Purchase(
            SALE, 7, CONFIG, _purchaseId(1), BUYER, 1, c.data.authorizationId, address(0), 0, 1
        );
        c.intent = StreamPreparedNativeSettlementTypes.Intent(
            1,
            PHASE,
            SALE,
            7,
            EXECUTOR,
            BUYER,
            address(0),
            BUYER,
            1000,
            1,
            keccak256("primary policy"),
            1,
            2,
            0,
            keccak256("execution"),
            _leaf(c.data.selection.contentId, c.data.selection.tokenDataHash),
            keccak256("mint commitment"),
            POLICY
        );
    }

    function _privateCase(address signer, uint8 kind) private returns (Case memory c) {
        c = _publicCase();
        c.intent.authorityMode = 1;
        c.request.authorizer = signer;
        c.purchase.authorizer = signer;
        c.purchase.authorizerKind = kind;
        StreamPrivateSaleTypes.SaleAuthorization memory a;
        a.chainId = block.chainid;
        a.saleAdapter = address(house);
        a.mintManager = address(manager);
        a.collectionId = 1;
        a.phaseId = PHASE;
        a.saleId = SALE;
        a.saleKind = 5;
        a.revenueClass = keccak256("PRIMARY_SALE");
        a.expectedPrimaryPolicyHash = c.intent.originalPrimaryPolicyHash;
        a.primaryPolicyMode = 1;
        a.initialRecipientsHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), c.request.initialRecipients
            )
        );
        a.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), c.request.beneficiaries)
        );
        bytes[] memory raw = new bytes[](1);
        raw[0] = "artwork one";
        a.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), raw));
        bytes32[] memory commitments = new bytes32[](1);
        commitments[0] = c.intent.mintCommitment;
        a.mintCommitmentsHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), commitments));
        a.payer = BUYER;
        a.executor = EXECUTOR;
        a.unitPrice = 1000;
        a.quantity = 1;
        a.contentSelectionHash = c.intent.contentSelectionHash;
        a.policyHash = POLICY;
        a.nonce = keccak256("commercial nonce");
        a.deadline = 1100;
        c.data.authorization = a;
        c.data.signature.authorizer = signer;
        c.data.signature.kind = kind;
        _signCase(c, KEY);
    }

    function _digest(StreamPrivateSaleTypes.SaleAuthorization memory a)
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
                address(house)
            )
        );
        bytes32 typeHash = keccak256(
            "SaleAuthorization(uint256 chainId,address saleAdapter,address mintManager,uint256 collectionId,bytes32 phaseId,bytes32 saleId,uint8 saleKind,bytes32 revenueClass,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 initialRecipientsHash,bytes32 beneficiariesHash,bytes32 tokenDataArrayHash,bytes32 mintCommitmentsHash,address payer,address executor,address asset,uint256 unitPrice,uint256 quantity,bytes32 contentSelectionHash,bytes32 policyHash,bytes32 nonce,uint64 deadline,uint64 finalizeBy)"
        );
        return keccak256(abi.encodePacked(hex"1901", domain, keccak256(abi.encode(typeHash, a))));
    }

    function _signCase(Case memory c, uint256 key) private {
        bytes32 digest = _digest(c.data.authorization);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        c.data.signature.signature = abi.encodePacked(r, s, v);
        c.intent.saleAuthorizationDigest = digest;
        c.data.authorizationId =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"), digest));
        c.purchase.authorizationId = c.data.authorizationId;
    }

    function _facts(Case memory c)
        private
        view
        returns (StreamPreparedNativeContentTypes.Facts memory)
    {
        StreamPreparedNativeContentTypes.Publication memory p = gate.publication();
        return StreamPreparedNativeContentTypes.Facts(
            0,
            address(gate),
            address(gate).codehash,
            gate.gateConfigHash(),
            p.manifestRoot,
            p.manifestHash,
            COUNTER,
            c.data.selection.contentId,
            c.data.selection.tokenDataHash,
            _leaf(c.data.selection.contentId, c.data.selection.tokenDataHash),
            c.request.contextHash
        );
    }

    function _admission(Case memory c) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_PURCHASE_ADMISSION_V1"),
                block.chainid,
                address(house),
                c.data.intentHash,
                c.purchase,
                _facts(c)
            )
        );
    }

    function _activate(Case memory c) private {
        house.arm(c.data.intentHash, c.purchase, c.intent);
        manager.admit(_admission(c));
    }

    function _validate(Case memory c) private view returns (IStreamMintGate.GateResult memory) {
        return manager.validate(gate, c.request, abi.encode(c.data));
    }

    function _reject(Case memory c) private {
        _activate(c);
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        _validate(c);
    }

    function testCompleteManifestRootPublicationConfigAndEventDomains() external {
        vm.recordLogs();
        StreamNativeCuratedContentGate published = _deploy(_rows());
        CuratedGateVm.Log[] memory logs = vm.getRecordedLogs();
        StreamPreparedNativeContentTypes.Publication memory p = published.publication();
        bytes32 root = _pair(
            _pair(_leaf(0, keccak256("")), _leaf(bytes32(uint256(1)), keccak256("artwork one"))),
            _leaf(bytes32(uint256(2)), keccak256("artwork two"))
        );
        bytes memory manifest = abi.encode(_rows());
        require(
            p.chainId == block.chainid && p.manager == address(manager) && p.house == address(house)
                && p.saleId == SALE && p.collectionId == 1 && p.phaseId == PHASE
                && p.counterId == COUNTER,
            "publication identity"
        );
        require(
            p.manifestRoot == root && p.manifestHash == keccak256(manifest)
                && published.itemCount() == 3
                && keccak256(published.manifestBytes()) == keccak256(manifest),
            "complete odd-width tree and bytes"
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"),
                p,
                address(manager).codehash,
                address(house).codehash
            )
        );
        require(
            published.gateConfigHash() == expected
                && published.contentPurchaseVersion()
                    == keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_V1"),
            "purchase config domain"
        );
        require(logs.length == 1 && logs[0].emitter == address(published), "one publication event");
        require(
            logs[0].topics[0]
                    == keccak256("CuratedManifestPublished(bytes32,bytes32,bytes32,uint256,bytes)")
                && logs[0].topics[1] == SALE && logs[0].topics[2] == root
                && logs[0].topics[3] == p.manifestHash,
            "event topics"
        );
        (uint256 count, bytes memory raw) = abi.decode(logs[0].data, (uint256, bytes));
        require(count == 3 && keccak256(raw) == p.manifestHash, "event complete manifest");
    }

    function testMalformedManifestsAndMissingCreationIdentityReject() external {
        for (uint256 n; n < 5; ++n) {
            StreamPreparedNativeContentTypes.Row[] memory rows = _rows();
            if (n == 0) rows = new StreamPreparedNativeContentTypes.Row[](0);
            else if (n == 1) rows[1].contentId = rows[0].contentId;
            else if (n == 2) rows[0].contentId = bytes32(uint256(9));
            else if (n == 3) rows[1].tokenDataHash = 0;
            else rows[1].previewURI = "";
            vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedPublication.selector);
            _deploy(rows);
        }
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedPublication.selector);
        new StreamNativeCuratedContentGate(
            address(0x123), address(house), SALE, 1, PHASE, COUNTER, _rows()
        );
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedPublication.selector);
        new StreamNativeCuratedContentGate(
            address(manager), address(0x123), SALE, 1, PHASE, COUNTER, _rows()
        );
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedPublication.selector);
        new StreamNativeCuratedContentGate(
            address(manager), address(house), 0, 1, PHASE, COUNTER, _rows()
        );
    }

    function testPublicZeroAuthorizationAndExactPurchaseAdmissionResult() external {
        Case memory c = _publicCase();
        _activate(c);
        IStreamMintGate.GateResult memory r = _validate(c);
        require(
            r.authorizationId == c.data.intentHash && r.authorizer == address(0)
                && r.authorizerKind == 0 && r.maxQuantity == 1 && r.nullifiers.length == 0,
            "public result"
        );
        require(
            r.gateHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_NATIVE_CONTENT_PURCHASE_GATE_RESULT_V1"),
                        gate.gateConfigHash(),
                        _admission(c),
                        POLICY,
                        keccak256(abi.encode(c.data))
                    )
                ),
            "complete result commitment"
        );
        require(
            _validate(c).authorizationId == r.authorizationId,
            "view gate does not consume Ledger replay"
        );
    }

    function testPublicRejectsEveryNonzeroAuthorizationPresentation() external {
        for (uint256 n; n < 7; ++n) {
            Case memory c = _publicCase();
            if (n == 0) {
                c.request.authorizer = seller;
                c.purchase.authorizer = seller;
            } else if (n == 1) {
                c.purchase.authorizerKind = 1;
            } else if (n == 2) {
                c.data.authorizationId = keccak256("other ID");
                c.purchase.authorizationId = c.data.authorizationId;
            } else if (n == 3) {
                c.data.authorization.quantity = 1;
            } else if (n == 4) {
                c.data.signature.authorizer = seller;
            } else if (n == 5) {
                c.data.signature.kind = 1;
            } else {
                c.data.signature.signature = hex"01";
            }
            _reject(c);
        }
    }

    function testDistinctPurchasesRetainOriginalSaleIdentityWithDifferentAdmission() external {
        Case memory c = _publicCase();
        _activate(c);
        bytes32 first = _validate(c).gateHash;
        c.purchase.purchaseNonce = 2;
        c.purchase.purchaseId = _purchaseId(2);
        c.intent.executionNonce = 2;
        c.data.intentHash = keccak256("second active positive-price intent");
        c.data.authorizationId = c.data.intentHash;
        c.purchase.authorizationId = c.data.authorizationId;
        _activate(c);
        IStreamMintGate.GateResult memory r = _validate(c);
        require(
            r.gateHash != first && r.authorizationId == c.data.intentHash, "per-purchase admission"
        );
        require(
            c.purchase.saleId == SALE && c.purchase.saleNonce == 7, "original creation retained"
        );
    }

    function testUnsupportedAuthorityModesRejectWithoutInterpretingAuthorization() external {
        Case memory c = _publicCase();
        c.intent.authorityMode = 0;
        _reject(c);
        c.intent.authorityMode = 3;
        _reject(c);
    }

    function testPinnedManagerAndHouseRuntimeChangesRejectBeforeReceiptReads() external {
        Case memory c = _publicCase();
        _activate(c);
        bytes memory original = address(house).code;
        vm.etch(address(house), hex"00");
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        _validate(c);
        vm.etch(address(house), original);
        vm.etch(address(manager), hex"00");
        vm.prank(address(manager));
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        gate.validateMint(
            c.request.manager,
            c.request.executor,
            1,
            PHASE,
            BUYER,
            address(0),
            c.request.initialRecipients,
            c.request.beneficiaries,
            c.request.contextHash,
            POLICY,
            abi.encode(c.data)
        );
    }

    function testEOAAndCompactPrivateSignaturesUseCanonicalOriginalDigest() external {
        Case memory c = _privateCase(seller, 1);
        _activate(c);
        IStreamMintGate.GateResult memory r = _validate(c);
        require(
            r.authorizer == seller && r.authorizerKind == 1
                && r.authorizationId == c.data.authorizationId,
            "EOA membership and full digest"
        );
        (uint8 v, bytes32 rr, bytes32 ss) = vm.sign(KEY, _digest(c.data.authorization));
        c.data.signature.signature =
            abi.encodePacked(rr, bytes32(uint256(ss) | (uint256(v - 27) << 255)));
        require(_validate(c).authorizationId == r.authorizationId, "compact EOA parity");
        _signCase(c, 0xBAD);
        _reject(c);
    }

    function testERC1271VerifiesOwnerAndRejectsRevertOrMalformedReturns() external {
        CuratedGateSignatureWallet wallet = new CuratedGateSignatureWallet(seller);
        house.binding(1, PHASE, address(wallet), 2, CONFIG);
        Case memory c = _privateCase(address(wallet), 2);
        _activate(c);
        require(_validate(c).authorizer == address(wallet), "actual owner signature");
        for (uint256 mode = 1; mode <= 4; ++mode) {
            wallet.setMode(mode);
            _reject(c);
        }
        wallet.setMode(0);
        _signCase(c, 0xBAD);
        _reject(c);
    }

    function testPrivateRequiresImmutableMembershipKindAndConfiguration() external {
        Case memory c = _privateCase(seller, 1);
        house.binding(1, PHASE, address(0xBAD), 1, CONFIG);
        _reject(c);
        house.binding(1, PHASE, seller, 2, CONFIG);
        _reject(c);
        house.binding(1, PHASE, seller, 1, keccak256("different creation config"));
        _reject(c);
        house.binding(2, PHASE, seller, 1, CONFIG);
        _reject(c);
        house.binding(1, keccak256("other phase"), seller, 1, CONFIG);
        _reject(c);
        house.binding(1, PHASE, seller, 1, CONFIG);
        c.data.signature.authorizer = address(0xBAD);
        _reject(c);
        c.data.signature.authorizer = seller;
        c.data.signature.kind = 2;
        _reject(c);
    }

    function testResignedPrivateFieldTamperingStillFailsSemanticBinding() external {
        for (uint256 n; n < 23; ++n) {
            Case memory c = _privateCase(seller, 1);
            _mutateAuthorization(c.data.authorization, n);
            _signCase(c, KEY);
            _reject(c);
        }
    }

    function _mutateAuthorization(StreamPrivateSaleTypes.SaleAuthorization memory a, uint256 n)
        private
        pure
    {
        if (n == 0) ++a.chainId;
        else if (n == 1) a.saleAdapter = address(0xBAD);
        else if (n == 2) a.mintManager = address(0xBAD);
        else if (n == 3) ++a.collectionId;
        else if (n == 4) a.phaseId = keccak256("other");
        else if (n == 5) a.saleId = keccak256("other");
        else if (n == 6) a.saleKind = 2;
        else if (n == 7) a.revenueClass = keccak256("other");
        else if (n == 8) a.expectedPrimaryPolicyHash = keccak256("other");
        else if (n == 9) a.primaryPolicyMode = 0;
        else if (n == 10) a.initialRecipientsHash = keccak256("other");
        else if (n == 11) a.beneficiariesHash = keccak256("other");
        else if (n == 12) a.mintCommitmentsHash = keccak256("other");
        else if (n == 13) a.payer = address(0xBAD);
        else if (n == 14) a.executor = address(0xBAD);
        else if (n == 15) a.asset = address(0xBAD);
        else if (n == 16) ++a.unitPrice;
        else if (n == 17) ++a.quantity;
        else if (n == 18) a.contentSelectionHash = keccak256("other");
        else if (n == 19) a.policyHash = keccak256("other");
        else if (n == 20) a.nonce = 0;
        else if (n == 21) a.deadline = 999;
        else a.finalizeBy = 1200;
    }

    function testPrivateTokenArrayHashTamperingInvalidatesSignatureWithoutClaimingRawBatchValidation()
        external
    {
        Case memory c = _privateCase(seller, 1);
        c.data.authorization.tokenDataArrayHash = keccak256("changed raw-array commitment");
        _reject(c);
        // This gate receives no raw tokenData[]: independently recomputing that hash is
        // the actual Manager requireBatch seam, intentionally outside this typed fixture.
    }

    function testPrivateOriginalDigestLedgerIdCommitmentAndPositivePriceRequired() external {
        for (uint256 n; n < 5; ++n) {
            Case memory c = _privateCase(seller, 1);
            if (n == 0) {
                c.intent.saleAuthorizationDigest = keccak256("other digest");
            } else if (n == 1) {
                c.data.authorizationId = _digest(c.data.authorization);
                c.purchase.authorizationId = c.data.authorizationId;
            } else if (n == 2) {
                c.intent.mintCommitment = keccak256("other mint");
            } else if (n == 3) {
                c.intent.mintCommitment = 0;
            } else {
                c.intent.amount = 0;
            }
            _reject(c);
        }
        Case memory c = _privateCase(seller, 1);
        house.setCap(0);
        _reject(c);
        house.setCap(uint256(type(uint64).max) + 1);
        _reject(c);
    }

    function testPurchaseIdentityCreationNonceAndIntentReceiptMismatchReject() external {
        for (uint256 n; n < 13; ++n) {
            Case memory c = _publicCase();
            if (n == 0) c.purchase.purchaseId = keccak256("wrong purchase");
            else if (n == 1) c.purchase.purchaseNonce = 0;
            else if (n == 2) c.purchase.purchaseNonce = 2;
            else if (n == 3) c.purchase.saleNonce = 0;
            else if (n == 4) ++c.purchase.saleNonce;
            else if (n == 5) c.purchase.saleId = keccak256("other creation");
            else if (n == 6) c.purchase.saleConfigHash = 0;
            else if (n == 7) c.purchase.buyer = address(0xBAD);
            else if (n == 8) c.intent.executionNonce = 2;
            else if (n == 9) c.intent.saleId = keccak256("other creation");
            else if (n == 10) c.intent.beneficiary = address(0xBAD);
            else if (n == 11) c.intent.boundMintPolicyHash = keccak256("other policy");
            else c.intent.contentSelectionHash = keccak256("other leaf");
            _reject(c);
        }
    }

    function testWrongCallerManagerExecutorRecipientsPolicyAndChainReject() external {
        Case memory c = _publicCase();
        _activate(c);
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        gate.validateMint(
            c.request.manager,
            c.request.executor,
            1,
            PHASE,
            BUYER,
            address(0),
            c.request.initialRecipients,
            c.request.beneficiaries,
            c.request.contextHash,
            POLICY,
            abi.encode(c.data)
        );
        for (uint256 n; n < 8; ++n) {
            c = _publicCase();
            if (n == 0) c.request.manager = address(0xBAD);
            else if (n == 1) c.request.executor = address(0xBAD);
            else if (n == 2) c.request.initialRecipients[0] = BUYER;
            else if (n == 3) c.request.beneficiaries = new address[](0);
            else if (n == 4) c.request.payer = address(house);
            else if (n == 5) c.request.policyHash = 0;
            else if (n == 6) c.request.collectionId = 2;
            else c.request.phaseId = keccak256("other phase");
            _reject(c);
        }
        c = _publicCase();
        _activate(c);
        vm.chainId(block.chainid + 1);
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        _validate(c);
    }

    function testStaleProofWrongDataContextAndNoncanonicalEncodingReject() external {
        for (uint256 n; n < 5; ++n) {
            Case memory c = _publicCase();
            if (n == 0) c.data.selection.proof[0] = keccak256("stale manifest leaf");
            else if (n == 1) c.data.selection.tokenDataHash = keccak256("changed artwork");
            else if (n == 2) c.data.selection.tokenDataHash = 0;
            else if (n == 3) c.data.selection.contentId = bytes32(uint256(2));
            else c.request.contextHash = keccak256("wrong content context");
            _reject(c);
        }
        Case memory c = _publicCase();
        _activate(c);
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        manager.validate(gate, c.request, bytes.concat(abi.encode(c.data), hex"00"));
        vm.expectRevert();
        manager.validate(gate, c.request, hex"00");
    }

    function testZeroContentIdAndEmptyArtworkAreValidPublishedChoices() external {
        Case memory c = _publicCase();
        c.data.selection.contentId = 0;
        c.data.selection.tokenDataHash = keccak256("");
        c.data.selection.proof[0] = _leaf(bytes32(uint256(1)), keccak256("artwork one"));
        c.request.contextHash = _context(0);
        c.intent.contentSelectionHash = _leaf(0, keccak256(""));
        _activate(c);
        require(_validate(c).maxQuantity == 1, "zero ID has a real double-hashed leaf");
    }

    function testAdmissionBindsFullManifestGatePurchaseAndOperationZeroFacts() external {
        Case memory c = _publicCase();
        _activate(c);
        for (uint256 n; n < 7; ++n) {
            StreamPreparedNativeContentTypes.Facts memory facts = _facts(c);
            if (n == 0) facts.manifestHash = keccak256("other manifest bytes");
            else if (n == 1) facts.manifestRoot = keccak256("other root");
            else if (n == 2) facts.gateConfigHash = keccak256("other config");
            else if (n == 3) facts.gateCodeHash = keccak256("other runtime");
            else if (n == 4) facts.counterId = keccak256("other counter");
            else if (n == 5) facts.operationRoot = keccak256("premature operation receipt");
            else facts.gate = address(0xBAD);
            manager.admit(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_PURCHASE_ADMISSION_V1"),
                        block.chainid,
                        address(house),
                        c.data.intentHash,
                        c.purchase,
                        facts
                    )
                )
            );
            vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
            _validate(c);
        }
        manager.admit(0);
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        _validate(c);
        _activate(c);
        house.setUnavailable(true);
        vm.expectRevert();
        _validate(c);
    }

    function testOldAuctionCapabilityAdmissionAndGatePayloadCannotSubstitute() external {
        StreamNativeAuctionContentGate old = new StreamNativeAuctionContentGate(
            address(manager), address(house), SALE, 1, PHASE, COUNTER, _rows()
        );
        require(
            gate.supportsInterface(type(IStreamPreparedNativeContentPurchaseGate).interfaceId)
                && !old.supportsInterface(
                    type(IStreamPreparedNativeContentPurchaseGate).interfaceId
                ),
            "explicit purchase capability"
        );
        require(
            !gate.supportsInterface(type(IStreamNativeAuctionContentGate).interfaceId)
                && old.supportsInterface(type(IStreamNativeAuctionContentGate).interfaceId),
            "auction capability separate"
        );
        Case memory c = _publicCase();
        _activate(c);
        manager.admit(
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_ADMISSION_V1"),
                    block.chainid,
                    address(house),
                    c.data.intentHash,
                    _facts(c)
                )
            )
        );
        vm.expectRevert(StreamNativeCuratedContentGate.InvalidCuratedMint.selector);
        _validate(c);
        _activate(c);
        StreamPreparedNativeContentTypes.GateData memory legacy =
            StreamPreparedNativeContentTypes.GateData(c.data.authorizationId, c.data.selection);
        vm.expectRevert();
        manager.validate(gate, c.request, abi.encode(legacy));
    }
}
