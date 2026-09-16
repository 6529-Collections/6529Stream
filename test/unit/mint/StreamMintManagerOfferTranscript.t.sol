// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/MintRevocationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamMintManagerOfferTranscript.sol";

/// @dev Deliberately exposes the post-admission seam. It does not authenticate signatures.
/// Actual production entry performs OfferExecution.admit first; carrier composition is separate.
contract OfferTranscriptHarness {
    StreamMintPhaseState.PhaseState private phaseState;
    IStreamMintManager.MintGateConfig private gate;
    bytes32[] private ids;
    mapping(bytes32 => IStreamMintManager.MintCounterConfig) private counters;
    address[] private executors;
    address public immutable core;
    StreamMintLedger public immutable mintLedger;
    address public immutable moduleRegistry;
    bytes32 public preparedNativeOfferAdmission;
    bytes32 public policy;
    uint256 public nextNonce;
    bytes32 private constant PHASE = keccak256("offer-transcript");

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

    function admit(bool value) external {
        preparedNativeOfferAdmission = value ? keccak256("explicit admission fixture") : bytes32(0);
    }

    function build(IStreamMintManager.MintBatch calldata b, bytes calldata data)
        public
        view
        returns (StreamMintTranscriptTypes.OperationTranscript memory)
    {
        return StreamMintManagerOfferTranscript.build(
            b,
            data,
            keccak256("6529STREAM_MINT_EXECUTION_PATH_PREPARED_V1"),
            phaseState,
            gate,
            ids,
            counters,
            executors,
            StreamMintManagerOfferTranscript.Context(core, _context(), policy, nextNonce, 150_000)
        );
    }

    function ordinary(IStreamMintManager.MintBatch calldata b, bytes calldata data)
        external
        view
        returns (StreamMintTranscriptTypes.OperationTranscript memory)
    {
        return StreamMintManagerTranscript.build(
            b,
            data,
            keccak256("6529STREAM_MINT_EXECUTION_PATH_PREPARED_V1"),
            phaseState,
            gate,
            ids,
            counters,
            executors,
            StreamMintManagerTranscript.Context(core, _context(), policy, nextNonce, 150_000)
        );
    }

    function consume(IStreamMintManager.MintBatch calldata b, bytes calldata data)
        external
        returns (StreamMintTranscriptTypes.OperationTranscript memory t)
    {
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

contract StreamMintManagerOfferTranscriptTest is CharacterizationTestBase {
    OfferTranscriptHarness private host;
    MintRevocationCoreMock private core;
    StreamMintLedger private ledger;
    address private buyer = address(0xB);
    address private buyerSigner = address(0xD);

    function setUp() public {
        vm.warp(100);
        core = new MintRevocationCoreMock();
        MintRevocationArtistMock artist = new MintRevocationArtistMock(address(core));
        MockGovernedParameterAuthority authority = new MockGovernedParameterAuthority(true);
        StreamModuleRegistry registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), keccak256("registry"), "ipfs://registry"
        );
        ledger = new StreamMintLedger();
        host = new OfferTranscriptHarness(address(core), ledger, address(registry));
        core.initialize(address(registry), address(artist), address(host));
        artist.setManager(address(host));
        ledger.setLedgerWriter(address(host), true);
        host.initialize();
        host.admit(true);
    }

    function _recipe(uint256 nonce)
        private
        view
        returns (
            IStreamMintManager.MintBatch memory b,
            StreamPreparedNativeOfferTypes.GateData memory d
        )
    {
        StreamPrivateSaleTypes.SaleOffer memory offer;
        offer.chainId = block.chainid;
        offer.saleAdapter = address(this);
        offer.core = address(core);
        offer.collectionId = 1;
        offer.buyer = buyer;
        offer.price = 1 ether;
        offer.nonce = bytes32(nonce);
        offer.deadline = 200;
        b.collectionId = 1;
        b.phaseId = keccak256("offer-transcript");
        b.payer = buyer;
        b.authorizer = buyerSigner;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = buyer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = hex"1234";
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = keccak256("commitment");
        b.expectedPolicyHash = host.policy();
        b.authorizationId = StreamMintTicketHash.authorizationId(
            StreamPrivateSaleHash.digest(
                block.chainid, address(this), StreamPrivateSaleHash.offerBody(offer)
            )
        );
        b.contextHash = keccak256("prepared context");
        d.offer = offer;
        d.authorizationId = b.authorizationId;
        d.buyerSignature.authorizer = buyerSigner;
        d.buyerSignature.kind = 1;
    }

    function testUnselectedRetainsVerifiedSignerPayerAndOriginalTicketInRealLedger() public {
        (IStreamMintManager.MintBatch memory b, StreamPreparedNativeOfferTypes.GateData memory d) =
            _recipe(1);
        StreamMintTranscriptTypes.OperationTranscript memory t = host.consume(b, abi.encode(d));
        require(
            t.authorization.authorizer == buyerSigner
                && t.authorization.authorizerKind == IStreamMintManager.AuthorizerKind.EOA_712,
            "verified signer"
        );
        require(
            t.authorization.gateHash == 0 && t.authorization.nullifiers.length == 0,
            "no fabricated gate"
        );
        require(
            t.consumptions.length == 1 && t.consumptions[0].authorizer == buyerSigner
                && t.consumptions[0].payer == buyer && t.consumptions[0].recipient == buyer
                && t.consumptions[0].executor == address(this),
            "original counter identities"
        );
        require(
            ledger.counterValue(t.consumptions[0].valueKey) == 1
                && ledger.isManagerAuthorizationUsed(address(host), b.authorizationId)
                && ledger.isManagerOperationRootUsed(address(host), t.operationRoot),
            "actual consumption"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.AuthorizationAlreadyConsumed.selector, b.authorizationId
            )
        );
        host.consume(b, abi.encode(d));
        require(
            host.nextNonce() == 1 && ledger.counterValue(t.consumptions[0].valueKey) == 1,
            "replay atomic"
        );
    }

    function testExplicit1271KindAndSignerChangeRemainInOriginalOperationIdentity() public {
        (IStreamMintManager.MintBatch memory b, StreamPreparedNativeOfferTypes.GateData memory d) =
            _recipe(2);
        StreamMintTranscriptTypes.OperationTranscript memory first = host.build(b, abi.encode(d));
        d.buyerSignature.kind = 2;
        StreamMintTranscriptTypes.OperationTranscript memory second = host.build(b, abi.encode(d));
        require(
            second.authorization.authorizerKind == IStreamMintManager.AuthorizerKind.ERC1271_712
                && first.operationRoot != second.operationRoot,
            "explicit kind identity"
        );
        b.authorizer = address(0xE);
        d.buyerSignature.authorizer = b.authorizer;
        StreamMintTranscriptTypes.OperationTranscript memory third = host.build(b, abi.encode(d));
        require(
            second.operationRoot != third.operationRoot
                && third.consumptions[0].authorizer == b.authorizer,
            "actual signer retained"
        );
    }

    function testOfferAdmissionRequiredAndOrdinaryNoGateRuleUnchanged() public {
        (IStreamMintManager.MintBatch memory b, StreamPreparedNativeOfferTypes.GateData memory d) =
            _recipe(3);
        host.admit(false);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeOfferHash.InvalidPreparedNativeOffer.selector
            )
        );
        host.build(b, abi.encode(d));
        host.admit(true);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintManager.MintInvalidAuthorizerKind.selector, uint8(0), buyerSigner
            )
        );
        host.ordinary(b, abi.encode(d));
        b.authorizer = address(0);
        StreamMintTranscriptTypes.OperationTranscript memory original = host.ordinary(b, "");
        require(
            original.authorization.authorizer == address(0)
                && original.authorization.authorizerKind == IStreamMintManager.AuthorizerKind.NONE,
            "ordinary unchanged"
        );
    }

    function testUnknownKindOrDifferentSignerOrTicketRejectsBeforeAnyConsumption() public {
        (IStreamMintManager.MintBatch memory b, StreamPreparedNativeOfferTypes.GateData memory d) =
            _recipe(4);
        d.buyerSignature.kind = 3;
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeOfferHash.InvalidPreparedNativeOffer.selector
            )
        );
        host.consume(b, abi.encode(d));
        d.buyerSignature.kind = 1;
        d.buyerSignature.authorizer = address(0xE);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeOfferHash.InvalidPreparedNativeOffer.selector
            )
        );
        host.consume(b, abi.encode(d));
        d.buyerSignature.authorizer = buyerSigner;
        d.authorizationId = keccak256("seller digest is not buyer ticket");
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamPreparedNativeOfferHash.InvalidPreparedNativeOffer.selector
            )
        );
        host.consume(b, abi.encode(d));
        require(
            host.nextNonce() == 0
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "no writes"
        );
    }

    function testPayerCapAggregatesSeparateBuyerOffersAndRejectsAtomically() public {
        (IStreamMintManager.MintBatch memory b, StreamPreparedNativeOfferTypes.GateData memory d) =
            _recipe(5);
        StreamMintTranscriptTypes.OperationTranscript memory t = host.consume(b, abi.encode(d));
        (b, d) = _recipe(6);
        host.consume(b, abi.encode(d));
        (b, d) = _recipe(7);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedger.CounterCapExceeded.selector,
                t.consumptions[0].valueKey,
                uint256(3),
                uint256(2)
            )
        );
        host.consume(b, abi.encode(d));
        require(
            host.nextNonce() == 2 && ledger.counterValue(t.consumptions[0].valueKey) == 2
                && !ledger.isManagerAuthorizationUsed(address(host), b.authorizationId),
            "cap and fresh ticket unchanged"
        );
    }
}
