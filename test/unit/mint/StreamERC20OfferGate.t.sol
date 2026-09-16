// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20OfferGate
} from "../../../smart-contracts/domains/mint/StreamERC20OfferGate.sol";
import {
    StreamERC20OfferReads as Reads
} from "../../../smart-contracts/domains/mint/StreamERC20OfferReads.sol";
import {
    StreamPrivateSaleHash as SalesHash
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import {
    StreamMintTicketHash
} from "../../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    StreamERC20OfferMintTypes as Offer
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import {
    StreamPreparedNativeContentTypes as Content
} from "../../../smart-contracts/interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    IStreamMintManager as Manager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamMintLedger as Ledger
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamMintGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintGate.sol";
import {
    IStreamMintBatchGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintBatchGate.sol";
import {
    IStreamERC20OfferGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamERC20OfferGate.sol";
import {
    IStreamPreparedNativeOfferGate
} from "../../../smart-contracts/interfaces/stream/mint/IStreamPreparedNativeOfferGate.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IERC165 } from "../../../smart-contracts/vendor/openzeppelin/IERC165.sol";

interface ERC20OfferGateVm {
    function warp(uint256) external;
    function addr(uint256) external returns (address);
    function sign(uint256, bytes32) external returns (uint8, bytes32, bytes32);
    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectEmit(bool, bool, bool, bool) external;
    function etch(address, bytes calldata) external;
}

/// @dev Only Manager configuration reads and its typed call boundary are substituted.
contract ERC20OfferGateManagerBoundary {
    address public core = address(0xC0DE);
    address public moduleRegistry;
    Manager.MintGateConfig private _gate;
    bytes32 private _counterId;
    uint256 public fault;

    constructor(address registry) {
        moduleRegistry = registry;
    }

    function setGate(Manager.MintGateConfig memory g, bytes32 counterId) external {
        _gate = g;
        _counterId = counterId;
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function phaseGate(uint256, bytes32) external view returns (Manager.MintGateConfig memory) {
        return _gate;
    }

    function phase(uint256, bytes32)
        external
        view
        returns (bool, Manager.MintPhaseConfig memory p)
    {
        p.maxBatchQuantity = fault == 2 ? 2 : 1;
        p.paused = fault == 3;
        return (fault != 1, p);
    }

    function phaseExecutor(uint256, bytes32, address) external view returns (bool) {
        return fault != 4;
    }

    function phaseCounterIds(uint256, bytes32) external view returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = fault == 5 ? bytes32(0) : _counterId;
    }

    function counterConfig(uint256, bytes32, bytes32)
        external
        view
        returns (Manager.MintCounterConfig memory c)
    {
        c.enabled = fault != 6;
        c.keyMode = fault == 7 ? Manager.CounterKeyMode.PAYER : Manager.CounterKeyMode.CONTEXT;
        c.capMode = fault == 8 ? Ledger.CounterCapMode.NONE : Ledger.CounterCapMode.STATIC;
        c.deltaMode = fault == 9 ? Ledger.CounterDeltaMode.RESOLVER : Ledger.CounterDeltaMode.STATIC;
        c.staticCap = fault == 10 ? 2 : 1;
        c.staticIncrement = fault == 11 ? 2 : 1;
        c.counterConfigHash = fault == 12 ? bytes32(0) : keccak256("context-cap-one");
    }

    function validate(
        StreamERC20OfferGate gate,
        address house,
        Manager.MintBatch calldata b,
        Offer.GateData calldata d
    ) external view returns (IStreamMintGate.GateResult memory) {
        return gate.validateERC20OfferBatch(address(this), house, b, d);
    }

    function readBatch(address house, Manager.MintBatch calldata b, Offer.GateData calldata d)
        external
        view
        returns (Content.Facts memory)
    {
        return Reads.requireBatch(address(this), moduleRegistry, house, b, d);
    }

    function readPublication(
        address house,
        uint256 collection,
        bytes32 phaseId,
        bytes32 sale,
        bytes32 root
    ) external view returns (Manager.MintGateConfig memory, Content.Publication memory) {
        return Reads.requirePublication(
            address(this), moduleRegistry, house, collection, phaseId, sale, root
        );
    }

    function ordinary(
        StreamERC20OfferGate gate,
        address house,
        Manager.MintBatch calldata b,
        Offer.GateData calldata d
    ) external view returns (IStreamMintGate.GateResult memory) {
        return gate.validateMint(
            address(this),
            house,
            b.collectionId,
            b.phaseId,
            b.payer,
            b.authorizer,
            b.initialRecipients,
            b.beneficiaries,
            b.contextHash,
            b.expectedPolicyHash,
            abi.encode(d)
        );
    }
}

/// @dev Canonical registry records; the real gate runtime and publication remain under test.
contract ERC20OfferGateRegistryBoundary {
    StreamModuleRecord private _record;

    function set(StreamModuleRecord memory value) external {
        _record = value;
    }

    function moduleRecord(address) external view returns (StreamModuleRecord memory) {
        return _record;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamModuleRegistry).interfaceId;
    }
}

/// @dev Exact seller-membership and signature budget boundary, no payment or mint simulation.
contract ERC20OfferGateHouseBoundary {
    address private _seller;

    constructor(address seller) {
        _seller = seller;
    }

    function primaryOfferAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        return (1, keccak256("erc20-offer-phase"), _seller, 1, keccak256("sale-configuration"));
    }

    function gasParameter(bytes32) external pure returns (uint256) {
        return 500000;
    }
}

/// @notice Gate/read unit evidence; settlement receipts and durable replay remain Manager tests.
contract StreamERC20OfferGateTest {
    ERC20OfferGateVm private constant vm =
        ERC20OfferGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x5151;
    uint256 private constant BUYER_KEY = 0xB001;
    bytes32 private constant SALE = keccak256("erc20-offer-sale");
    bytes32 private constant PHASE = keccak256("erc20-offer-phase");
    bytes32 private constant COUNTER = keccak256("erc20-offer-content");
    ERC20OfferGateManagerBoundary private manager;
    ERC20OfferGateRegistryBoundary private registry;
    ERC20OfferGateHouseBoundary private house;
    StreamERC20OfferGate private gate;
    Manager.MintGateConfig private gateConfig;

    struct Request {
        Manager.MintBatch batch;
        Offer.GateData data;
    }

    event OfferManifestPublished(
        bytes32 indexed saleId,
        bytes32 indexed root,
        bytes32 indexed manifestHash,
        uint256 count,
        bytes manifest
    );

    function setUp() public {
        vm.warp(1000);
        registry = new ERC20OfferGateRegistryBoundary();
        manager = new ERC20OfferGateManagerBoundary(address(registry));
        house = new ERC20OfferGateHouseBoundary(vm.addr(SELLER_KEY));
        gate = new StreamERC20OfferGate(
            address(manager), address(house), SALE, 1, PHASE, COUNTER, _rows()
        );
        _configureGate();
    }

    function testOriginalPublicationManifestAndOddRowRootUseOnlyNewGateDomain() public {
        Content.Row[] memory rows = _rows();
        bytes memory manifest = abi.encode(rows);
        bytes32 root = _pair(
            _pair(
                _leaf(rows[0].contentId, rows[0].tokenDataHash),
                _leaf(rows[1].contentId, rows[1].tokenDataHash)
            ),
            _leaf(rows[2].contentId, rows[2].tokenDataHash)
        );
        vm.expectEmit(true, true, true, true);
        emit OfferManifestPublished(SALE, root, keccak256(manifest), 3, manifest);
        StreamERC20OfferGate published = new StreamERC20OfferGate(
            address(manager), address(house), SALE, 1, PHASE, COUNTER, rows
        );
        Content.Publication memory p = published.publication();
        require(
            p.manifestRoot == root && p.manifestHash == keccak256(manifest), "original publication"
        );
        require(
            keccak256(published.manifestBytes()) == p.manifestHash && published.itemCount() == 3,
            "complete manifest"
        );
        require(
            published.gateConfigHash()
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"),
                        p,
                        address(manager).codehash,
                        address(house).codehash
                    )
                ),
            "ERC20 config domain"
        );
        require(
            published.offerPurchaseVersion() == keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_V1"),
            "version"
        );
        require(published.supportsInterface(type(IERC165).interfaceId), "ERC165");
        require(
            published.supportsInterface(type(IStreamMintGate).interfaceId), "base gate registration"
        );
        require(
            published.supportsInterface(type(IStreamERC20OfferGate).interfaceId),
            "typed offer route"
        );
        require(
            !published.supportsInterface(type(IStreamMintBatchGate).interfaceId),
            "no ordinary batch gate"
        );
        require(
            !published.supportsInterface(type(IStreamPreparedNativeOfferGate).interfaceId),
            "no native gate"
        );
        require(!published.supportsInterface(0xffffffff), "invalid ERC165");
    }

    function testPublicationRejectsUnsortedDuplicatesMissingBytesOrPreview() public {
        for (uint256 fault; fault < 5; ++fault) {
            Content.Row[] memory rows = _rows();
            if (fault == 0) rows[1].contentId = rows[0].contentId;
            else if (fault == 1) rows[0].contentId = rows[2].contentId;
            else if (fault == 2) rows[0].tokenDataHash = 0;
            else if (fault == 3) rows[0].previewURI = "";
            else rows = new Content.Row[](0);
            vm.expectRevert(
                abi.encodeWithSelector(StreamERC20OfferGate.InvalidOfferPublication.selector)
            );
            new StreamERC20OfferGate(
                address(manager), address(house), SALE, 1, PHASE, COUNTER, rows
            );
        }
    }

    function testDedicatedGateVerifiesRealSignaturesAndReturnsOriginalOfferTicket() public {
        Request memory q = _request(true);
        IStreamMintGate.GateResult memory r =
            manager.validate(gate, address(house), q.batch, q.data);
        require(
            r.authorizationId == q.batch.authorizationId
                && r.authorizationId == StreamMintTicketHash.authorizationId(_offerDigest(q)),
            "original wrapped offer"
        );
        require(
            r.authorizer == q.data.offer.buyer && r.authorizerKind == 1,
            "explicit buyer signature kind"
        );
        require(r.nullifiers.length == 0 && r.maxQuantity == 1, "canonical gate result");
        require(
            r.gateHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ERC20_PRIMARY_OFFER_GATE_RESULT_V1"),
                        gate.gateConfigHash(),
                        _sellerDigest(q),
                        _offerDigest(q),
                        q.batch.expectedPolicyHash,
                        keccak256(abi.encode(q.data))
                    )
                ),
            "complete result commitment"
        );
        Content.Facts memory c = manager.readBatch(address(house), q.batch, q.data);
        require(
            c.operationRoot == 0 && c.gate == address(gate)
                && c.gateCodeHash == address(gate).codehash,
            "actual gate"
        );
        require(
            c.tokenDataHash == keccak256(q.batch.tokenData[0])
                && c.contentLeaf == q.data.offer.contentSelectionHash,
            "bytes and original leaf distinct"
        );
        require(
            c.contextHash == q.batch.contextHash && c.counterId == COUNTER,
            "original content context"
        );
        vm.expectRevert(abi.encodeWithSelector(StreamERC20OfferGate.InvalidOfferMint.selector));
        manager.ordinary(gate, address(house), q.batch, q.data);
        vm.expectRevert(abi.encodeWithSelector(StreamERC20OfferGate.InvalidOfferMint.selector));
        gate.validateERC20OfferBatch(address(manager), address(house), q.batch, q.data);
    }

    function testGateIndependentlyRejectsBadSellerAndBuyerSignatures() public {
        for (uint256 n; n < 2; ++n) {
            Request memory q = _request(true);
            if (n == 0) q.data.sellerSignature.signature = _sign(BUYER_KEY, _sellerDigest(q));
            else q.data.buyerSignature.signature = _sign(SELLER_KEY, _offerDigest(q));
            vm.expectRevert();
            manager.validate(gate, address(house), q.batch, q.data);
        }
    }

    function testSelectedBytesAndProofAreCheckedIndependentlyOfValidSignatures() public {
        Request memory q = _request(true);
        q.data.selection.proof[0] = keccak256("wrong sibling");
        vm.expectRevert();
        manager.validate(gate, address(house), q.batch, q.data);
        vm.expectRevert();
        manager.readBatch(address(house), q.batch, q.data);
        q = _request(true);
        q.batch.tokenData[0] = "other bytes";
        _signRequest(q);
        vm.expectRevert();
        manager.validate(gate, address(house), q.batch, q.data);
        vm.expectRevert();
        manager.readBatch(address(house), q.batch, q.data);
        q.data.selection.tokenDataHash = keccak256(q.batch.tokenData[0]);
        q.data.authorization.contentSelectionHash =
            _leaf(q.data.selection.contentId, q.data.selection.tokenDataHash);
        q.data.offer.contentSelectionHash = q.data.authorization.contentSelectionHash;
        _signRequest(q);
        vm.expectRevert();
        manager.validate(gate, address(house), q.batch, q.data);
        vm.expectRevert();
        manager.readBatch(address(house), q.batch, q.data);
    }

    function testSelectedGateRequiresDirectBuyerRecipientsAndPinnedHouseCode() public {
        for (uint256 n; n < 3; ++n) {
            Request memory q = _request(true);
            if (n == 0) q.batch.payer = address(house);
            else if (n == 1) q.batch.initialRecipients[0] = address(house);
            else q.batch.beneficiaries[0] = address(house);
            _signRequest(q);
            vm.expectRevert();
            manager.validate(gate, address(house), q.batch, q.data);
        }
        Request memory valid = _request(true);
        vm.etch(address(house), hex"00");
        vm.expectRevert(abi.encodeWithSelector(StreamERC20OfferGate.InvalidOfferMint.selector));
        manager.validate(gate, address(house), valid.batch, valid.data);
    }

    function testReadsRequireCurrentSingletonContextStaticCapAndIncrementOne() public {
        Request memory q = _request(true);
        manager.readBatch(address(house), q.batch, q.data);
        for (uint256 fault = 1; fault <= 12; ++fault) {
            manager.setFault(fault);
            vm.expectRevert(abi.encodeWithSelector(Reads.InvalidERC20OfferContent.selector));
            manager.readBatch(address(house), q.batch, q.data);
        }
        manager.setFault(0);
        manager.readBatch(address(house), q.batch, q.data);
    }

    function testReadsRejectWrongPublicationIdentityRegistryAndGatePins() public {
        bytes32 root = gate.publication().manifestRoot;
        for (uint256 n; n < 5; ++n) {
            vm.expectRevert(abi.encodeWithSelector(Reads.InvalidERC20OfferContent.selector));
            manager.readPublication(
                n == 0 ? address(this) : address(house),
                n == 1 ? 2 : 1,
                n == 2 ? keccak256("other phase") : PHASE,
                n == 3 ? keccak256("other sale") : SALE,
                n == 4 ? keccak256("other root") : root
            );
        }
        for (uint256 n; n < 5; ++n) {
            Manager.MintGateConfig memory g = gateConfig;
            if (n == 0) g.gateCodehash = keccak256("wrong code");
            else if (n == 1) g.gateConfigHash = keccak256("wrong configuration");
            else if (n == 2) g.gateMetadataHash = keccak256("wrong metadata");
            else if (n == 3) g.gateGasLimit += 1;
            else g.gateSemanticVersion = 1;
            manager.setGate(g, COUNTER);
            vm.expectRevert();
            manager.readPublication(address(house), 1, PHASE, SALE, root);
        }
        manager.setGate(gateConfig, COUNTER);
        StreamModuleRecord memory record = _record();
        record.status = ModuleRegistryStatus.DEPRECATED;
        registry.set(record);
        vm.expectRevert();
        manager.readPublication(address(house), 1, PHASE, SALE, root);
    }

    function testUnselectedReadsUseFullSellerDigestAndExactEmptyGate() public {
        Manager.MintGateConfig memory empty;
        manager.setGate(empty, COUNTER);
        Request memory q = _request(false);
        Content.Facts memory c = manager.readBatch(address(house), q.batch, q.data);
        Content.Facts memory expected;
        expected.tokenDataHash = keccak256(q.batch.tokenData[0]);
        expected.contextHash = _sellerDigest(q);
        require(
            keccak256(abi.encode(c)) == keccak256(abi.encode(expected)), "unselected content facts"
        );
        require(c.contextHash != _offerDigest(q), "full original seller context");
        bytes32 oldContext = q.batch.contextHash;
        q.data.authorization.nonce = keccak256("fresh seller nonce");
        _signRequest(q);
        q.batch.contextHash = oldContext;
        vm.expectRevert();
        manager.readBatch(address(house), q.batch, q.data);
        q.batch.contextHash = _sellerDigest(q);
        manager.readBatch(address(house), q.batch, q.data);
        for (uint256 n; n < 5; ++n) {
            Manager.MintGateConfig memory g;
            if (n == 0) g.gateCodehash = gateConfig.gateCodehash;
            else if (n == 1) g.gateConfigHash = gateConfig.gateConfigHash;
            else if (n == 2) g.gateMetadataHash = gateConfig.gateMetadataHash;
            else if (n == 3) g.gateGasLimit = 1;
            else g.gateSemanticVersion = 1;
            manager.setGate(g, COUNTER);
            vm.expectRevert();
            manager.readBatch(address(house), q.batch, q.data);
        }
    }

    function testUnselectedRejectsEverySelectionResidueAndSelectedRequestWithoutGate() public {
        Manager.MintGateConfig memory empty;
        manager.setGate(empty, COUNTER);
        for (uint256 n; n < 5; ++n) {
            Request memory q = _request(false);
            if (n == 0) q.data.selection.contentId = bytes32(uint256(1));
            else if (n == 1) q.data.selection.tokenDataHash = keccak256(q.batch.tokenData[0]);
            else if (n == 2) q.data.selection.proof = new bytes32[](1);
            else if (n == 3) q.data.authorization.contentSelectionHash = bytes32(uint256(1));
            else q.data.offer.contentSelectionHash = bytes32(uint256(1));
            _signRequest(q);
            q.batch.contextHash = _sellerDigest(q);
            vm.expectRevert();
            manager.readBatch(address(house), q.batch, q.data);
        }
        Request memory selected = _request(true);
        vm.expectRevert();
        manager.readBatch(address(house), selected.batch, selected.data);
        Request memory unselected = _request(false);
        manager.setGate(gateConfig, COUNTER);
        vm.expectRevert();
        manager.readBatch(address(house), unselected.batch, unselected.data);
    }

    function _rows() private pure returns (Content.Row[] memory rows) {
        rows = new Content.Row[](3);
        rows[0] = Content.Row(bytes32(uint256(1)), keccak256("artwork one"), "ipfs://one");
        rows[1] = Content.Row(bytes32(uint256(2)), keccak256("artwork two"), "ipfs://two");
        rows[2] = Content.Row(bytes32(uint256(3)), keccak256("artwork three"), "ipfs://three");
    }

    function _configureGate() private {
        StreamModuleRecord memory record = _record();
        registry.set(record);
        gateConfig = Manager.MintGateConfig(
            address(gate),
            gate.gateConfigHash(),
            address(gate).codehash,
            keccak256(abi.encode(record.moduleVersion, record.moduleManifestHash)),
            0,
            record.moduleGasLimit
        );
        manager.setGate(gateConfig, COUNTER);
    }

    function _record() private view returns (StreamModuleRecord memory r) {
        r.status = ModuleRegistryStatus.ACTIVE;
        r.moduleType = keccak256("6529STREAM_MINT_GATE_V1");
        r.moduleVersion = keccak256("ERC20 gate version");
        r.interfaceId = type(IStreamMintGate).interfaceId;
        r.moduleGasLimit = 5000000;
        r.runtimeCodeHash = address(gate).codehash;
        r.moduleManifestHash = keccak256("ERC20 gate declaration");
        r.registeredAt = 1000;
        r.statusUpdatedAt = 1000;
        r.revision = 1;
    }

    function _request(bool selected) private returns (Request memory q) {
        address buyer = vm.addr(BUYER_KEY);
        q.batch.collectionId = 1;
        q.batch.phaseId = PHASE;
        q.batch.payer = buyer;
        q.batch.authorizer = buyer;
        q.batch.initialRecipients = new address[](1);
        q.batch.initialRecipients[0] = buyer;
        q.batch.beneficiaries = new address[](1);
        q.batch.beneficiaries[0] = buyer;
        q.batch.tokenData = new bytes[](1);
        q.batch.tokenData[0] = "artwork one";
        q.batch.mintCommitments = new bytes32[](1);
        q.batch.mintCommitments[0] = keccak256("actual commitment");
        q.batch.expectedPolicyHash = keccak256("actual mint policy");
        q.data.executor = buyer;
        q.data.authorization.chainId = block.chainid;
        q.data.authorization.saleAdapter = address(house);
        q.data.authorization.mintManager = address(manager);
        q.data.authorization.collectionId = 1;
        q.data.authorization.phaseId = PHASE;
        q.data.authorization.saleId = SALE;
        q.data.authorization.saleKind = 6;
        q.data.authorization.revenueClass = keccak256("PRIMARY_SALE");
        q.data.authorization.expectedPrimaryPolicyHash = keccak256("primary policy");
        q.data.authorization.payer = buyer;
        q.data.authorization.executor = buyer;
        q.data.authorization.asset = address(0xA55E7);
        q.data.authorization.unitPrice = 1000;
        q.data.authorization.quantity = 1;
        q.data.authorization.policyHash = q.batch.expectedPolicyHash;
        q.data.authorization.nonce = keccak256("seller nonce");
        q.data.authorization.deadline = 2000;
        q.data.offer.chainId = block.chainid;
        q.data.offer.saleAdapter = address(house);
        q.data.offer.core = manager.core();
        q.data.offer.collectionId = 1;
        q.data.offer.buyer = buyer;
        q.data.offer.asset = q.data.authorization.asset;
        q.data.offer.price = 1000;
        q.data.offer.nonce = keccak256("buyer nonce");
        q.data.offer.deadline = 2000;
        q.data.buyerSignature.authorizer = buyer;
        q.data.buyerSignature.kind = 1;
        q.data.sellerSignature.authorizer = vm.addr(SELLER_KEY);
        q.data.sellerSignature.kind = 1;
        if (selected) {
            q.data.selection.contentId = bytes32(uint256(1));
            q.data.selection.tokenDataHash = keccak256(q.batch.tokenData[0]);
            q.data.selection.proof = new bytes32[](2);
            q.data.selection.proof[0] = _leaf(bytes32(uint256(2)), keccak256("artwork two"));
            q.data.selection.proof[1] = _leaf(bytes32(uint256(3)), keccak256("artwork three"));
            q.data.authorization.contentSelectionHash =
                _leaf(q.data.selection.contentId, q.data.selection.tokenDataHash);
            q.data.offer.contentSelectionHash = q.data.authorization.contentSelectionHash;
            q.batch.contextHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_CONTEXT_V1"),
                    block.chainid,
                    address(house),
                    SALE,
                    q.data.selection.contentId
                )
            );
        }
        _signRequest(q);
        if (!selected) q.batch.contextHash = _sellerDigest(q);
    }

    function _signRequest(Request memory q) private {
        q.data.authorization.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), q.batch.initialRecipients)
        );
        q.data.authorization.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), q.batch.beneficiaries)
        );
        q.data.authorization.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), q.batch.tokenData)
        );
        q.data.authorization.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), q.batch.mintCommitments)
        );
        q.batch.authorizationId = StreamMintTicketHash.authorizationId(_offerDigest(q));
        q.data.sellerSignature.signature = _sign(SELLER_KEY, _sellerDigest(q));
        q.data.buyerSignature.signature = _sign(BUYER_KEY, _offerDigest(q));
    }

    function _sellerDigest(Request memory q) private view returns (bytes32) {
        return SalesHash.digest(
            block.chainid, address(house), SalesHash.authorizationBody(q.data.authorization)
        );
    }

    function _offerDigest(Request memory q) private view returns (bytes32) {
        return SalesHash.digest(block.chainid, address(house), SalesHash.offerBody(q.data.offer));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _leaf(bytes32 id, bytes32 dataHash) private view returns (bytes32) {
        return keccak256(
            bytes.concat(
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_LEAF_V1"),
                        block.chainid,
                        address(house),
                        SALE,
                        id,
                        dataHash
                    )
                )
            )
        );
    }

    function _pair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
}
