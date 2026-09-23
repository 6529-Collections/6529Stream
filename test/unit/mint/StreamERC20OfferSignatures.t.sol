// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20OfferHash
} from "../../../smart-contracts/domains/mint/StreamERC20OfferHash.sol";
import {
    StreamERC20OfferSignatures
} from "../../../smart-contracts/domains/mint/StreamERC20OfferSignatures.sol";
import {
    StreamPreparedNativeContentHash as ContentHash
} from "../../../smart-contracts/domains/mint/StreamPreparedNativeContentHash.sol";
import {
    StreamPrivateSaleHash
} from "../../../smart-contracts/domains/mint/StreamPrivateSaleHash.sol";
import {
    StreamMintTicketHash
} from "../../../smart-contracts/domains/mint/StreamMintTicketHash.sol";
import {
    StreamERC20OfferMintTypes as Offer
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import {
    StreamPrivateSaleTypes as Sales
} from "../../../smart-contracts/interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamNativeRefundDelegatedClaims as Refund
} from "../../../smart-contracts/interfaces/stream/mint/IStreamNativeRefundDelegatedClaims.sol";
import {
    IStreamModuleRegistry,
    StreamModuleRecord,
    ModuleRegistryStatus
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    DelegationManagementContract
} from "../../../smart-contracts/integrations/delegation/NFTdelegation.sol";

interface ERC20OfferVm {
    function addr(uint256 privateKey) external returns (address);
    function sign(uint256 privateKey, bytes32 digest)
        external
        returns (uint8 v, bytes32 r, bytes32 s);
    function warp(uint256 timestamp) external;
    function prank(address sender) external;
    function expectRevert() external;
}

contract ERC20OfferSignatureWallet {
    address private immutable owner;
    uint256 private mode;

    constructor(address value) {
        owner = value;
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

contract ERC20OfferManagerBoundary {
    address public core = address(0xC0DE);
    address public moduleRegistry;

    constructor(address registry) {
        moduleRegistry = registry;
    }
}

contract ERC20OfferRegistryBoundary {
    mapping(address => StreamModuleRecord) private records;

    function set(address target, StreamModuleRecord memory record) external {
        records[target] = record;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return records[target];
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || id == 0x01ffc9a7;
    }
}

contract ERC20OfferHouseBoundary {
    uint256 private collection = 1;
    bytes32 private phase;
    address private seller;
    uint8 private sellerKind;
    bytes32 private configHash = keccak256("immutable ERC20 offer config");
    Refund.DelegationConfiguration private delegation;
    uint256 public fault;

    function bind(bytes32 phaseId, address authorizer, uint8 kind) external {
        phase = phaseId;
        seller = authorizer;
        sellerKind = kind;
    }

    function configure(Refund.DelegationConfiguration memory value) external {
        delegation = value;
    }

    function setFault(uint256 value) external {
        fault = value;
    }

    function primaryOfferAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        if (fault == 1) assembly ("memory-safe") { return(0, 128) }
        return (collection, phase, seller, sellerKind, configHash);
    }

    function offerDelegationConfiguration()
        external
        view
        returns (Refund.DelegationConfiguration memory)
    {
        if (fault == 2) assembly ("memory-safe") { return(0, 224) }
        return delegation;
    }

    function gasParameter(bytes32) external view returns (uint256) {
        if (fault == 3) return 0;
        if (fault == 4) return uint256(type(uint64).max) + 1;
        return 500_000;
    }
}

/// @notice Full-payload Sales hashes, explicit signer kinds and live dual delegation only.
/// Manager execution, ERC20 transfer and official settlement are separate batch evidence.
contract StreamERC20OfferSignaturesTest {
    ERC20OfferVm private constant vm =
        ERC20OfferVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 private constant SELLER_KEY = 0x5E11;
    uint256 private constant BUYER_KEY = 0xB0B;
    uint256 private constant SIGNER_KEY = 0x51A;
    uint256 private constant EXECUTOR_KEY = 0xE0EC;
    bytes32 private constant PHASE = keccak256("ERC20 offer phase");
    bytes32 private constant SALE = keccak256("original ERC20 offer sale");
    bytes32 private constant MINT_POLICY = keccak256("mint policy");
    address private constant ASSET = address(0xA55E7);

    struct Case {
        IStreamMintManager.MintBatch batch;
        Offer.GateData data;
    }

    ERC20OfferRegistryBoundary private registry;
    ERC20OfferManagerBoundary private manager;
    ERC20OfferHouseBoundary private house;
    address private seller;
    address private buyer;

    function setUp() public {
        vm.warp(1000);
        seller = vm.addr(SELLER_KEY);
        buyer = vm.addr(BUYER_KEY);
        registry = new ERC20OfferRegistryBoundary();
        manager = new ERC20OfferManagerBoundary(address(registry));
        house = new ERC20OfferHouseBoundary();
        house.bind(PHASE, seller, 1);
    }

    function testFullOriginalECDSAOfferReturnsDistinctSellerAndTicketDigests() public {
        Case memory c = _case(seller, 1, buyer, 1, buyer);
        (bytes32 sellerDigest, bytes32 offerDigest) = _validate(c);
        require(sellerDigest != offerDigest, "separate original authorities");
        require(
            c.batch.authorizationId == StreamMintTicketHash.authorizationId(offerDigest),
            "full buyer digest is ticket replay key"
        );
    }

    function testUnselectedOfferUsesFullSellerDigestContextAndRejectsResidualSelection() public {
        Case memory c = _unselectedCase();
        (bytes32 sellerDigest,) = _validate(c);
        require(c.batch.contextHash == sellerDigest, "full seller digest is unselected context");
        c.data.selection.contentId = bytes32(uint256(1));
        vm.expectRevert();
        _validate(c);
        c = _unselectedCase();
        c.data.selection.tokenDataHash = keccak256(c.batch.tokenData[0]);
        vm.expectRevert();
        _validate(c);
        c = _unselectedCase();
        c.data.selection.proof = new bytes32[](1);
        vm.expectRevert();
        _validate(c);
    }

    function testEveryOriginalPayloadWordAndActualBatchFieldIsAuthenticated() public {
        Case memory original = _case(seller, 1, buyer, 1, buyer);
        for (uint256 n; n < 24; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            bytes memory raw = abi.encode(c.data.authorization);
            assembly ("memory-safe") {
                let p := add(add(raw, 32), mul(n, 32))
                mstore(p, xor(mload(p), 1))
            }
            c.data.authorization = abi.decode(raw, (Sales.SaleAuthorization));
            vm.expectRevert();
            _validate(c);
        }
        for (uint256 n; n < 12; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            bytes memory raw = abi.encode(c.data.offer);
            assembly ("memory-safe") {
                let p := add(add(raw, 32), mul(n, 32))
                mstore(p, xor(mload(p), 1))
            }
            c.data.offer = abi.decode(raw, (Sales.SaleOffer));
            vm.expectRevert();
            _validate(c);
        }
        for (uint256 n; n < 8; ++n) {
            Case memory c = abi.decode(abi.encode(original), (Case));
            if (n == 0) c.batch.collectionId++;
            if (n == 1) c.batch.phaseId = keccak256("other phase");
            if (n == 2) c.batch.payer = seller;
            if (n == 3) c.batch.authorizer = seller;
            if (n == 4) c.batch.initialRecipients[0] = seller;
            if (n == 5) c.batch.beneficiaries[0] = seller;
            if (n == 6) c.batch.tokenData[0] = "different bytes";
            if (n == 7) c.batch.mintCommitments[0] = keccak256("different commitment");
            vm.expectRevert();
            _validate(c);
        }
    }

    function testERC20StrictProfileAndAtomicFieldsFailClosed() public {
        Case memory c = _case(seller, 1, buyer, 1, buyer);
        c.data.authorization.asset = address(0);
        vm.expectRevert();
        _validate(c);
        c = _case(seller, 1, buyer, 1, buyer);
        c.data.authorization.primaryPolicyMode = 1;
        vm.expectRevert();
        _validate(c);
        c = _case(seller, 1, buyer, 1, buyer);
        c.data.offer.finalizeBy = 1001;
        vm.expectRevert();
        _validate(c);
        c = _case(seller, 1, buyer, 1, buyer);
        c.data.authorization.saleKind = 5;
        vm.expectRevert();
        _validate(c);
    }

    function testActualERC1271SellerAndBuyerUseExplicitKindsAndBoundedReads() public {
        ERC20OfferSignatureWallet sellerWallet = new ERC20OfferSignatureWallet(vm.addr(SELLER_KEY));
        ERC20OfferSignatureWallet buyerWallet = new ERC20OfferSignatureWallet(vm.addr(BUYER_KEY));
        buyer = address(buyerWallet);
        house.bind(PHASE, address(sellerWallet), 2);
        Case memory c =
            _case(address(sellerWallet), 2, address(buyerWallet), 2, address(buyerWallet));
        _validate(c);
        buyerWallet.setMode(2);
        vm.expectRevert();
        _validate(c);
        buyerWallet.setMode(0);
        house.setFault(4);
        vm.expectRevert();
        _validate(c);
    }

    function testBuyerSignerAndExecutorEachRequireLiveExactHouseDelegation() public {
        address signer = vm.addr(SIGNER_KEY);
        address executor = vm.addr(EXECUTOR_KEY);
        Case memory c = _case(seller, 1, signer, 1, executor);
        DelegationManagementContract delegates = _configureDelegation();
        address core = manager.core();
        vm.prank(buyer);
        delegates.registerDelegationAddress(core, signer, 1500, 2, true, 0);
        vm.prank(buyer);
        delegates.registerDelegationAddress(core, executor, 1500, 2, true, 0);
        StreamModuleRecord memory record = registry.moduleRecord(address(house));
        bytes32 manifest = record.moduleManifestHash;
        record.moduleManifestHash = keccak256("wrong house manifest");
        registry.set(address(house), record);
        vm.expectRevert();
        _validate(c);
        record.moduleManifestHash = manifest;
        registry.set(address(house), record);
        _validate(c);
        vm.prank(buyer);
        delegates.revokeDelegationAddress(core, executor, 2);
        vm.expectRevert();
        _validate(c);
    }

    function testHistoricalBindingAndDelegationConfigurationUseExactReturnShapes() public {
        Case memory c = _case(seller, 1, buyer, 1, buyer);
        house.setFault(1);
        vm.expectRevert();
        _validate(c);
        address signer = vm.addr(SIGNER_KEY);
        c = _case(seller, 1, signer, 1, buyer);
        _configureDelegation();
        house.setFault(2);
        vm.expectRevert();
        _validate(c);
    }

    function _case(
        address sellerAuthorizer,
        uint8 sellerKind,
        address buyerAuthorizer,
        uint8 buyerKind,
        address executor
    ) private returns (Case memory c) {
        c.batch.collectionId = 1;
        c.batch.phaseId = PHASE;
        c.batch.payer = buyer;
        c.batch.authorizer = buyerAuthorizer;
        c.batch.initialRecipients = new address[](1);
        c.batch.initialRecipients[0] = buyer;
        c.batch.beneficiaries = new address[](1);
        c.batch.beneficiaries[0] = buyer;
        c.batch.tokenData = new bytes[](1);
        c.batch.tokenData[0] = "exact ERC20 offer token bytes";
        c.batch.mintCommitments = new bytes32[](1);
        c.batch.mintCommitments[0] = keccak256("exact ERC20 offer commitment");
        c.batch.expectedPolicyHash = MINT_POLICY;
        c.data.executor = executor;
        c.data.selection.contentId = bytes32(uint256(7));
        c.data.selection.tokenDataHash = keccak256(c.batch.tokenData[0]);
        bytes32 selectedLeaf = ContentHash.leaf(
            block.chainid,
            address(house),
            SALE,
            c.data.selection.contentId,
            c.data.selection.tokenDataHash
        );
        c.batch.contextHash =
            ContentHash.context(block.chainid, address(house), SALE, c.data.selection.contentId);
        Sales.SaleAuthorization memory authorization;
        authorization.chainId = block.chainid;
        authorization.saleAdapter = address(house);
        authorization.mintManager = address(manager);
        authorization.collectionId = 1;
        authorization.phaseId = PHASE;
        authorization.saleId = SALE;
        authorization.saleKind = 6;
        authorization.revenueClass = keccak256("PRIMARY_SALE");
        authorization.expectedPrimaryPolicyHash = keccak256("original primary profile");
        authorization.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), c.batch.initialRecipients)
        );
        authorization.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), c.batch.beneficiaries)
        );
        authorization.tokenDataArrayHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), c.batch.tokenData)
        );
        authorization.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), c.batch.mintCommitments)
        );
        authorization.payer = buyer;
        authorization.executor = executor;
        authorization.asset = ASSET;
        authorization.unitPrice = 1000;
        authorization.quantity = 1;
        authorization.contentSelectionHash = selectedLeaf;
        authorization.policyHash = MINT_POLICY;
        authorization.nonce = keccak256("seller nonce");
        authorization.deadline = 2000;
        c.data.authorization = authorization;
        c.data.offer = Sales.SaleOffer(
            block.chainid,
            address(house),
            manager.core(),
            1,
            0,
            selectedLeaf,
            buyer,
            ASSET,
            1000,
            keccak256("buyer offer nonce"),
            2000,
            0
        );
        c.data.sellerSignature.authorizer = sellerAuthorizer;
        c.data.sellerSignature.kind = sellerKind;
        c.data.buyerSignature.authorizer = buyerAuthorizer;
        c.data.buyerSignature.kind = buyerKind;
        _sign(c, buyerKind == 2 || buyerAuthorizer == buyer ? BUYER_KEY : SIGNER_KEY);
    }

    function _sign(Case memory c, uint256 buyerSignerKey) private {
        bytes32 sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid,
            address(house),
            StreamPrivateSaleHash.authorizationBody(c.data.authorization)
        );
        bytes32 offerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(house), StreamPrivateSaleHash.offerBody(c.data.offer)
        );
        c.batch.authorizationId = StreamMintTicketHash.authorizationId(offerDigest);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SELLER_KEY, sellerDigest);
        c.data.sellerSignature.signature = abi.encodePacked(r, s, v);
        (v, r, s) = vm.sign(buyerSignerKey, offerDigest);
        c.data.buyerSignature.signature = abi.encodePacked(r, s, v);
    }

    function _unselectedCase() private returns (Case memory c) {
        c = _case(seller, 1, buyer, 1, buyer);
        c.data.authorization.contentSelectionHash = 0;
        c.data.offer.contentSelectionHash = 0;
        c.data.selection.contentId = 0;
        c.data.selection.tokenDataHash = 0;
        c.data.selection.proof = new bytes32[](0);
        c.batch.contextHash = StreamPrivateSaleHash.digest(
            block.chainid,
            address(house),
            StreamPrivateSaleHash.authorizationBody(c.data.authorization)
        );
        _sign(c, BUYER_KEY);
    }

    function _validate(Case memory c)
        private
        view
        returns (bytes32 sellerDigest, bytes32 offerDigest)
    {
        return StreamERC20OfferSignatures.validate(
            address(manager), address(house), c.batch, c.data
        );
    }

    function _configureDelegation() private returns (DelegationManagementContract delegates) {
        delegates = new DelegationManagementContract();
        Refund.DelegationConfiguration memory config = Refund.DelegationConfiguration(
            block.chainid,
            manager.core(),
            address(delegates),
            address(delegates).codehash,
            2,
            keccak256("ERC20 offer house manifest"),
            address(registry),
            address(registry).codehash
        );
        house.configure(config);
        StreamModuleRecord memory record;
        record.status = ModuleRegistryStatus.ACTIVE;
        record.runtimeCodeHash = address(house).codehash;
        record.deploymentManifestHash = keccak256("ERC20 offer house deployment");
        record.moduleManifestHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_AUCTION_NFTDELEGATION_MANIFEST_V1"),
                block.chainid,
                address(house),
                config.baseManifestHash,
                manager.core(),
                address(delegates),
                address(delegates).codehash,
                uint256(2)
            )
        );
        record.registeredAt = 1000;
        record.statusUpdatedAt = 1000;
        record.revision = 1;
        registry.set(address(house), record);
    }
}
