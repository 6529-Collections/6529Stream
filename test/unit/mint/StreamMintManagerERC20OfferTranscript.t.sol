// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintRevocationTestBase.sol";
import {
    StreamMintManagerERC20OfferTranscript
} from "../../../smart-contracts/domains/mint/StreamMintManagerERC20OfferTranscript.sol";
import {
    StreamERC20OfferMintTypes
} from "../../../smart-contracts/interfaces/stream/mint/StreamERC20OfferMintTypes.sol";

/// @dev Exercises the full signature/content/fee/transcript worker and actual Ledger consumption.
/// The paid receipt and complete carrier remain separate acceptance surfaces.
contract ERC20OfferTranscriptHarness {
    StreamMintPhaseState.PhaseState private phaseState;
    IStreamMintManager.MintGateConfig private gate;
    bytes32[] private ids;
    mapping(bytes32 => IStreamMintManager.MintCounterConfig) private counters;
    address[] private executors;
    address public immutable core;
    StreamMintLedger public immutable mintLedger;
    address public immutable moduleRegistry;
    bytes32 public policy;
    uint256 public nextNonce;
    bytes32 private constant PHASE = keccak256("erc20-offer-transcript");

    constructor(address c, StreamMintLedger l, address r) {
        core = c;
        mintLedger = l;
        moduleRegistry = r;
        phaseState.exists = true;
        phaseState.config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("config"), keccak256("metadata")
        );
        ids.push(keccak256("payer"));
        counters[ids[0]] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            2,
            1,
            keccak256("payer policy")
        );
        executors.push(msg.sender);
    }

    function _context() private view returns (StreamMintOperationIdentity.PolicyContext memory) {
        return StreamMintOperationIdentity.PolicyContext(
            block.chainid, address(this), address(mintLedger), moduleRegistry, 1, 1, PHASE
        );
    }

    function initialize() external {
        policy = StreamMintPhaseState.computeStoredPolicyHash(
            phaseState, gate, ids, counters, executors, _context()
        );
        (bytes32[] memory keys, IStreamMintLedger.LedgerCounterPolicy[] memory policies) =
            StreamMintManagerAccounting.ledgerPolicies(ids, counters);
        mintLedger.registerPhasePolicy(address(this), 1, PHASE, policy, keys, policies, 0);
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return gate;
    }

    function build(
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData calldata data
    ) public view returns (StreamMintTranscriptTypes.OperationTranscript memory) {
        return StreamMintManagerERC20OfferTranscript.build(
            b,
            abi.encode(b, data),
            keccak256("6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1"),
            phaseState,
            gate,
            ids,
            counters,
            executors,
            StreamMintManagerERC20OfferTranscript.Context(
                core, _context(), policy, nextNonce, 150_000
            )
        );
    }

    function buildArguments(IStreamMintManager.MintBatch calldata b, bytes calldata arguments)
        public
        view
        returns (StreamMintTranscriptTypes.OperationTranscript memory)
    {
        return StreamMintManagerERC20OfferTranscript.build(
            b,
            arguments,
            keccak256("6529STREAM_MINT_EXECUTION_PATH_SINGLE_STEP_V1"),
            phaseState,
            gate,
            ids,
            counters,
            executors,
            StreamMintManagerERC20OfferTranscript.Context(
                core, _context(), policy, nextNonce, 150_000
            )
        );
    }

    function consume(
        IStreamMintManager.MintBatch calldata b,
        StreamERC20OfferMintTypes.GateData calldata data
    ) external returns (StreamMintTranscriptTypes.OperationTranscript memory t) {
        t = build(b, data);
        nextNonce += t.quantity;
        mintLedger.consume(
            1,
            PHASE,
            t.consumptions,
            b.authorizationId,
            t.authorization.nullifiers,
            t.boundPolicyHash,
            t.operationRoot
        );
    }
}

contract ERC20OfferTranscriptCore {
    address public registry;
    address public artist;
    address public entropy;

    function initialize(address r, address a, address e) external {
        registry = r;
        artist = a;
        entropy = e;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address selected = kind == keccak256("MODULE_REGISTRY")
            ? registry
            : kind == keccak256("ENTROPY_COORDINATOR") ? entropy : artist;
        return (selected, selected.codehash, false, kind, 0, selected, 1, 0, 0, 1);
    }
}

contract ERC20OfferTranscriptEntropy {
    address public immutable core;
    bool public declared = true;
    uint256 public fee;

    constructor(address c) {
        core = c;
    }

    function set(bool isDeclared, uint256 amount) external {
        declared = isDeclared;
        fee = amount;
    }

    function collectionRevealPolicy(uint256)
        external
        view
        returns (bool, uint8, bytes32, uint64, uint256)
    {
        return (declared, 1, keccak256("zero fee policy"), 0, fee);
    }
}

contract StreamMintManagerERC20OfferTranscriptTest is CharacterizationTestBase {
    uint256 private constant BUYER_KEY = 0xB011;
    uint256 private constant SELLER_KEY = 0xA011;
    bytes32 private constant PHASE = keccak256("erc20-offer-transcript");
    ERC20OfferTranscriptHarness private host;
    ERC20OfferTranscriptCore private core;
    ERC20OfferTranscriptEntropy private entropy;
    StreamMintLedger private ledger;
    address private buyer;
    address private seller;

    function setUp() public {
        vm.warp(100);
        buyer = vm.addr(BUYER_KEY);
        seller = vm.addr(SELLER_KEY);
        core = new ERC20OfferTranscriptCore();
        entropy = new ERC20OfferTranscriptEntropy(address(core));
        MintRevocationArtistMock artist = new MintRevocationArtistMock(address(core));
        MockGovernedParameterAuthority authority = new MockGovernedParameterAuthority(true);
        StreamModuleRegistry registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), keccak256("registry"), "ipfs://registry"
        );
        ledger = new StreamMintLedger();
        host = new ERC20OfferTranscriptHarness(address(core), ledger, address(registry));
        core.initialize(address(registry), address(artist), address(entropy));
        artist.setManager(address(host));
        ledger.setLedgerWriter(address(host), true);
        host.initialize();
    }

    function primaryOfferAuthorizationBinding(bytes32)
        external
        view
        returns (uint256, bytes32, address, uint8, bytes32)
    {
        return (1, PHASE, seller, 1, keccak256("sale config"));
    }

    function gasParameter(bytes32) external pure returns (uint256) {
        return 150_000;
    }

    function _recipe(uint256 nonce)
        private
        returns (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d)
    {
        b.collectionId = 1;
        b.phaseId = PHASE;
        b.payer = buyer;
        b.authorizer = buyer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = buyer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = buyer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = hex"1234";
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("mint commitment");
        b.expectedPolicyHash = host.policy();
        d.executor = buyer;
        d.offer = StreamPrivateSaleTypes.SaleOffer(
            block.chainid,
            address(this),
            address(core),
            1,
            0,
            0,
            buyer,
            address(0xE20),
            100,
            bytes32(nonce),
            200,
            0
        );
        d.authorization.chainId = block.chainid;
        d.authorization.saleAdapter = address(this);
        d.authorization.mintManager = address(host);
        d.authorization.collectionId = 1;
        d.authorization.phaseId = PHASE;
        d.authorization.saleId = keccak256("sale");
        d.authorization.saleKind = 6;
        d.authorization.revenueClass = keccak256("PRIMARY_SALE");
        d.authorization.expectedPrimaryPolicyHash = keccak256("primary policy");
        d.authorization.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        d.authorization.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        d.authorization.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        d.authorization.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        d.authorization.payer = buyer;
        d.authorization.executor = buyer;
        d.authorization.asset = d.offer.asset;
        d.authorization.unitPrice = 100;
        d.authorization.quantity = 1;
        d.authorization.policyHash = b.expectedPolicyHash;
        d.authorization.nonce = bytes32(nonce);
        d.authorization.deadline = 200;
        bytes32 offerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(d.offer)
        );
        b.authorizationId = StreamMintTicketHash.authorizationId(offerDigest);
        d.buyerSignature =
            IStreamPrivateSaleAdapter.Signature(buyer, 1, _sign(BUYER_KEY, offerDigest));
        _seller(b, d);
    }

    function _seller(
        IStreamMintManager.MintBatch memory b,
        StreamERC20OfferMintTypes.GateData memory d
    ) private {
        b.contextHash = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(d.authorization)
        );
        d.sellerSignature =
            IStreamPrivateSaleAdapter.Signature(seller, 1, _sign(SELLER_KEY, b.contextHash));
    }

    function _sign(uint256 key, bytes32 digest) private returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function testAuthenticatedUnselectedOfferConsumesOriginalTicketAndCounterIdentities() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(1);
        StreamMintTranscriptTypes.OperationTranscript memory preview = host.build(b, d);
        StreamMintTranscriptTypes.OperationTranscript memory t = host.consume(b, d);
        require(
            t.operationRoot == preview.operationRoot
                && t.operationIds[0] == preview.operationIds[0],
            "exact preview"
        );
        require(
            t.authorization.authorizer == buyer && uint8(t.authorization.authorizerKind) == 1,
            "buyer signer"
        );
        require(t.authorization.gateHash == 0 && t.authorization.maxQuantity == 1, "unselected");
        require(
            t.consumptions[0].payer == buyer && t.consumptions[0].recipient == buyer, "economics"
        );
        require(
            t.consumptions[0].executor == address(this) && t.consumptions[0].authorizer == buyer,
            "identities"
        );
        require(
            ledger.counterValue(t.consumptions[0].valueKey) == 1
                && ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "ledger"
        );
    }

    function testFreshSellerAuthorizationCannotReplaySameBuyerOffer() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(2);
        StreamMintTranscriptTypes.OperationTranscript memory t = host.consume(b, d);
        d.authorization.nonce = keccak256("fresh seller nonce");
        _seller(b, d);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        host.consume(b, d);
        require(
            host.nextNonce() == 1 && ledger.counterValue(t.consumptions[0].valueKey) == 1,
            "replay rollback"
        );
    }

    function testChangedRawTokenBytesCannotConsumeSignedOffer() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(3);
        b.tokenData[0] = hex"5678";
        vm.expectRevert();
        host.consume(b, d);
        require(
            host.nextNonce() == 0
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "no consumption"
        );
        b.tokenData[0] = hex"1234";
        host.consume(b, d);
    }

    function testMissingOrPositiveNativeFeePolicyRejectsBeforeLedgerAndCanRetry() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(4);
        entropy.set(false, 0);
        vm.expectRevert();
        host.consume(b, d);
        entropy.set(true, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintManagerERC20OfferTranscript.InvalidERC20OfferNativeFee.selector
            )
        );
        host.consume(b, d);
        require(
            host.nextNonce() == 0
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "fee rollback"
        );
        entropy.set(true, 0);
        host.consume(b, d);
    }

    function testPreviewAndExecuteArgumentLayoutsDeriveIdenticalTranscript() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(6);
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c;
        c.saleAdapter = address(this);
        c.executor = buyer;
        c.sale.amount = 100;
        StreamMintTranscriptTypes.OperationTranscript memory p =
            host.buildArguments(b, abi.encode(b, d));
        StreamMintTranscriptTypes.OperationTranscript memory e =
            host.buildArguments(b, abi.encode(b, d, c));
        require(
            p.operationRoot == e.operationRoot && p.operationIds[0] == e.operationIds[0],
            "same typed identities"
        );
        require(keccak256(abi.encode(p)) == keccak256(abi.encode(e)), "same entire transcript");
    }

    function testMalformedDynamicArgumentsAndDifferentBatchRejectBeforeConsumption() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(7);
        bytes memory arguments = abi.encode(b, d);
        assembly ("memory-safe") { mstore(add(arguments, 64), not(0)) }
        vm.expectRevert();
        host.buildArguments(b, arguments);
        arguments = abi.encode(b, d);
        assembly ("memory-safe") { mstore(add(arguments, 32), not(0)) }
        vm.expectRevert();
        host.buildArguments(b, arguments);
        vm.expectRevert();
        host.buildArguments(b, new bytes(63));
        arguments = abi.encode(b, d);
        b.tokenData[0] = hex"deadbeef";
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintManagerERC20OfferTranscript.InvalidERC20OfferArguments.selector
            )
        );
        host.buildArguments(b, arguments);
        require(
            host.nextNonce() == 0
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "no consumption"
        );
    }

    function testInvalidSellerSignatureLeavesIdenticalOfferRetryable() public {
        (IStreamMintManager.MintBatch memory b, StreamERC20OfferMintTypes.GateData memory d) =
            _recipe(5);
        bytes memory valid = d.sellerSignature.signature;
        d.sellerSignature.signature = hex"0102";
        vm.expectRevert();
        host.consume(b, d);
        require(
            host.nextNonce() == 0
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "signature rollback"
        );
        d.sellerSignature.signature = valid;
        host.consume(b, d);
    }
}
