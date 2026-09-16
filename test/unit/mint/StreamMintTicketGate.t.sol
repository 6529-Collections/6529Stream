// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamMintTicketGate.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../helpers/GovernedParameterTestMocks.sol";

interface TicketGateVm {
    function addr(uint256 key) external returns (address);
    function sign(uint256 key, bytes32 digest) external returns (uint8, bytes32, bytes32);
    function expectRevert(bytes4 selector) external;
    function expectRevert(bytes calldata data) external;
    function warp(uint256 timestamp) external;
    function chainId(uint256 chainId_) external;
    function etch(address target, bytes calldata code) external;
    function prank(address sender) external;
}

/// @dev Explicit read seam: these tests exercise the actual gate, not Manager/Core execution.
contract TicketGateManagerReadFixture {
    address public mintLedger = address(0x1ED6E2);
    IStreamMintManager.MintGateConfig private _gate;
    bytes32 private _current;
    bytes32 private _previous;
    uint64 private _grace;

    function setGate(address gate, bytes32 configHash) external {
        _gate.gate = gate;
        _gate.gateConfigHash = configHash;
    }

    function setPolicy(bytes32 current, bytes32 previous, uint64 grace) external {
        _current = current;
        _previous = previous;
        _grace = grace;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return _gate;
    }

    function phasePolicyHash(uint256, bytes32) external view returns (bytes32) {
        return _current;
    }

    function phasePolicyGrace(uint256, bytes32) external view returns (bytes32, uint64) {
        return (_previous, _grace);
    }
}

/// @dev Deliberately adversarial return-data and gas seam; positive Safe tests use real bytecode.
contract TicketGate1271Adversary {
    uint256 private _mode;

    function setMode(uint256 mode) external {
        _mode = mode;
    }

    fallback() external {
        uint256 mode = _mode;
        if (mode == 1) revert("invalid");
        if (mode == 2) {
            assembly ("memory-safe") { invalid() }
        }
        assembly ("memory-safe") {
            mstore(0, shl(224, 0x1626ba7e))
            switch mode
            case 3 { return(0, 4) }
            case 4 { return(0, 64) }
            case 5 {
                mstore(0, 0)
                return(0, 32)
            }
            case 6 {
                mstore(0, or(mload(0), 1))
                return(0, 32)
            }
            default { return(0, 32) }
        }
    }
}

abstract contract TicketGateTestBase {
    TicketGateVm internal constant vm =
        TicketGateVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    uint256 internal constant SIGNER_KEY = 0x71201;
    address internal constant EXECUTOR = address(0xE1EC);
    bytes32 internal constant POLICY = keccak256("ticket policy");
    TicketGateManagerReadFixture internal manager;
    StreamMintTicketGate internal gate;

    function setUp() public virtual {
        vm.warp(1000);
        manager = new TicketGateManagerReadFixture();
        _useGate(new StreamMintTicketGate(address(0), vm.addr(SIGNER_KEY), 1));
        manager.setPolicy(POLICY, 0, 0);
    }

    function _useGate(StreamMintTicketGate next) internal {
        gate = next;
        manager.setGate(address(next), next.gateConfigHash());
    }

    function _batch() internal view returns (IStreamMintManager.MintBatch memory b) {
        b.collectionId = 71;
        b.phaseId = keccak256("ticket phase");
        b.payer = address(0xFA7E);
        b.authorizer = gate.ticketSigner();
        b.initialRecipients = new address[](2);
        b.initialRecipients[0] = address(0xAA01);
        b.initialRecipients[1] = address(0xAA02);
        b.beneficiaries = new address[](2);
        b.beneficiaries[0] = address(0xBB01);
        b.beneficiaries[1] = address(0xBB02);
        b.tokenData = new bytes[](2);
        b.tokenData[0] = hex"1122";
        b.tokenData[1] = hex"334455";
        b.mintCommitments = new bytes32[](2);
        b.mintCommitments[0] = keccak256("commitment one");
        b.mintCommitments[1] = keccak256("commitment two");
        b.expectedPolicyHash = POLICY;
        b.contextHash = keccak256("curated allowance context");
    }

    function _ticket(IStreamMintManager.MintBatch memory b)
        internal
        view
        returns (StreamMintTicketTypes.MintTicket memory t)
    {
        t.chainId = block.chainid;
        t.manager = address(manager);
        t.ledger = manager.mintLedger();
        t.collectionId = b.collectionId;
        t.phaseId = b.phaseId;
        t.executor = EXECUTOR;
        t.payer = b.payer;
        t.authorizer = b.authorizer;
        t.authorizerKind = gate.ticketSignerKind();
        t.initialRecipientsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients)
        );
        t.beneficiariesHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries)
        );
        t.tokenDataArrayHash =
            keccak256(abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData));
        t.mintCommitmentsHash = keccak256(
            abi.encode(keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments)
        );
        t.quantity = b.initialRecipients.length;
        t.contextHash = b.contextHash;
        t.policyHash = b.expectedPolicyHash;
        t.nonce = keccak256("ticket nonce");
        t.deadline = 2000;
    }

    function _digest(StreamMintTicketTypes.MintTicket memory t) internal view returns (bytes32) {
        return StreamMintTicketHash.digest(block.chainid, address(gate), t);
    }

    function _sign(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _validate(
        IStreamMintManager.MintBatch memory b,
        StreamMintTicketTypes.MintTicket memory t,
        bytes memory signature
    ) internal view returns (IStreamMintGate.GateResult memory) {
        return gate.validateMintBatch(address(manager), EXECUTOR, b, abi.encode(t, signature));
    }

    function _bindId(
        IStreamMintManager.MintBatch memory b,
        StreamMintTicketTypes.MintTicket memory t
    ) internal view {
        b.authorizationId = StreamMintTicketHash.authorizationId(_digest(t));
    }
}

contract StreamMintTicketGateTest is TicketGateTestBase {
    function testEOACanonicalAndCompactSignaturesProduceSameLedgerIdAndGateHash() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes32 digest = _digest(t);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        IStreamMintGate.GateResult memory a = _validate(b, t, abi.encodePacked(r, s, v));
        IStreamMintGate.GateResult memory compact =
            _validate(b, t, abi.encodePacked(r, bytes32(uint256(s) | (uint256(v - 27) << 255))));
        require(
            a.authorizationId == b.authorizationId && a.gateHash == digest, "canonical identity"
        );
        require(
            a.authorizer == b.authorizer && a.authorizerKind == 1 && a.maxQuantity == 2,
            "result fields"
        );
        require(a.nullifiers.length == 0, "no invented nullifier domain");
        require(
            keccak256(abi.encode(a)) == keccak256(abi.encode(compact)), "presentation independent"
        );
        // Repeated view validation remains valid: Ledger alone owns durable consumption.
        require(
            _validate(b, t, abi.encodePacked(r, s, v)).authorizationId == a.authorizationId,
            "view replay identity"
        );
    }

    function testDiscoveryUsesExactCanonicalDomain() public view {
        (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chain,
            address verifier,
            bytes32 salt,
            uint256[] memory extensions
        ) = gate.eip712Domain();
        require(
            fields == hex"0f" && chain == block.chainid && verifier == address(gate),
            "domain fields"
        );
        require(keccak256(bytes(name)) == keccak256("6529Stream Mint Tickets"), "name");
        require(
            keccak256(bytes(version)) == keccak256("1") && salt == 0 && extensions.length == 0,
            "version salt extensions"
        );
        require(
            gate.supportsInterface(type(IStreamMintBatchGate).interfaceId), "full batch capability"
        );
        require(gate.supportsInterface(type(IStreamMintGate).interfaceId), "legacy admission");
        require(
            gate.supportsInterface(type(IERC165).interfaceId)
                && !gate.supportsInterface(0xffffffff),
            "ERC165"
        );
    }

    function testLegacyGateSelectorFailsClosed() public {
        IStreamMintManager.MintBatch memory b = _batch();
        vm.expectRevert(StreamMintTicketGate.MintTicketFullBatchRequired.selector);
        gate.validateMint(
            address(manager),
            EXECUTOR,
            b.collectionId,
            b.phaseId,
            b.payer,
            b.authorizer,
            b.initialRecipients,
            b.beneficiaries,
            b.contextHash,
            b.expectedPolicyHash,
            hex""
        );
    }

    function testSignerPolicyCannotBeZeroNoneOrAdapter() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintTicketGate.MintTicketInvalidSignerPolicy.selector, address(0), uint8(1)
            )
        );
        new StreamMintTicketGate(address(0), address(0), 1);
        for (uint8 kind; kind < 5; ++kind) {
            if (kind == 1 || kind == 2) continue;
            address signer = vm.addr(SIGNER_KEY);
            vm.expectRevert(
                abi.encodeWithSelector(
                    StreamMintTicketGate.MintTicketInvalidSignerPolicy.selector, signer, kind
                )
            );
            new StreamMintTicketGate(address(0), signer, kind);
        }
    }

    function testPhaseMustPinExactGateAndSignerConfig() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        manager.setGate(address(gate), keccak256("foreign config"));
        vm.expectRevert(StreamMintTicketGate.MintTicketGateConfigurationMismatch.selector);
        _validate(b, t, sig);
        manager.setGate(address(0xDEAD), gate.gateConfigHash());
        vm.expectRevert(StreamMintTicketGate.MintTicketGateConfigurationMismatch.selector);
        _validate(b, t, sig);
    }

    function testUnlistedSelfSignerCannotAuthorizeTicket() public {
        IStreamMintManager.MintBatch memory b = _batch();
        b.authorizer = vm.addr(0xBAD);
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory sig = _sign(0xBAD, _digest(t));
        vm.expectRevert(StreamMintTicketGate.MintTicketPayloadMismatch.selector);
        _validate(b, t, sig);
    }

    function testEOAKindDoesNotInferFromCodePresence() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        // Reverting code stands in for nonzero delegated code: own-key ECDSA remains the path.
        vm.etch(t.authorizer, hex"60006000fd");
        require(_validate(b, t, sig).authorizer == t.authorizer, "explicit own-key kind");
    }

    function testEveryPayloadFieldMutationRejectsOriginalSignature() public {
        for (uint256 field; field < 18; ++field) {
            IStreamMintManager.MintBatch memory b = _batch();
            StreamMintTicketTypes.MintTicket memory t = _ticket(b);
            _bindId(b, t);
            bytes memory sig = _sign(SIGNER_KEY, _digest(t));
            // The ticket has eighteen static ABI words; mutate exactly one low bit.
            assembly ("memory-safe") {
                let slot := add(t, mul(field, 32))
                mstore(slot, xor(mload(slot), 1))
            }
            (bool ok,) = address(gate)
                .staticcall(
                    abi.encodeCall(
                        gate.validateMintBatch, (address(manager), EXECUTOR, b, abi.encode(t, sig))
                    )
                );
            require(!ok, "changed ticket field accepted");
        }
    }

    function testActualBatchChangesCannotHideBehindUnchangedTicketHashes() public {
        for (uint256 field; field < 10; ++field) {
            IStreamMintManager.MintBatch memory b = _batch();
            StreamMintTicketTypes.MintTicket memory t = _ticket(b);
            _bindId(b, t);
            bytes memory sig = _sign(SIGNER_KEY, _digest(t));
            if (field == 0) b.initialRecipients[0] = address(0x99);
            if (field == 1) b.beneficiaries[0] = address(0x99);
            if (field == 2) b.tokenData[0] = hex"11";
            if (field == 3) b.mintCommitments[0] = bytes32(uint256(1));
            if (field == 4) b.payer = address(0x99);
            if (field == 5) b.authorizer = address(0x99);
            if (field == 6) ++b.collectionId;
            if (field == 7) b.phaseId = bytes32(uint256(1));
            if (field == 8) b.contextHash = bytes32(uint256(1));
            if (field == 9) b.expectedPolicyHash = bytes32(uint256(1));
            vm.expectRevert(StreamMintTicketGate.MintTicketPayloadMismatch.selector);
            _validate(b, t, sig);
        }
    }

    function testArrayLengthsAndEmptyBatchRejectEvenWhenResigned() public {
        for (uint256 field; field < 4; ++field) {
            IStreamMintManager.MintBatch memory b = _batch();
            if (field == 0) b.initialRecipients = new address[](0);
            if (field == 1) b.beneficiaries = new address[](1);
            if (field == 2) b.tokenData = new bytes[](1);
            if (field == 3) b.mintCommitments = new bytes32[](1);
            StreamMintTicketTypes.MintTicket memory t = _ticket(b);
            _bindId(b, t);
            bytes memory sig = _sign(SIGNER_KEY, _digest(t));
            vm.expectRevert(StreamMintTicketGate.MintTicketPayloadMismatch.selector);
            _validate(b, t, sig);
        }
    }

    function testWrongExecutorRejects() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory data = abi.encode(t, _sign(SIGNER_KEY, _digest(t)));
        vm.expectRevert(StreamMintTicketGate.MintTicketPayloadMismatch.selector);
        gate.validateMintBatch(address(manager), address(0x99), b, data);
    }

    function testWrongManagerAndLedgerRejectEvenWithFreshSignature() public {
        for (uint256 field; field < 2; ++field) {
            IStreamMintManager.MintBatch memory b = _batch();
            StreamMintTicketTypes.MintTicket memory t = _ticket(b);
            if (field == 0) t.manager = address(0x99);
            else t.ledger = address(0x99);
            _bindId(b, t);
            bytes memory sig = _sign(SIGNER_KEY, _digest(t));
            vm.expectRevert(StreamMintTicketGate.MintTicketBindingMismatch.selector);
            _validate(b, t, sig);
        }
    }

    function testWrongChainAndWrongVerifyingGateDomainsReject() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory wrongGate =
            _sign(SIGNER_KEY, StreamMintTicketHash.digest(block.chainid, address(0x99), t));
        bytes memory wrongChain =
            _sign(SIGNER_KEY, StreamMintTicketHash.digest(block.chainid + 1, address(gate), t));
        vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
        _validate(b, t, wrongGate);
        vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
        _validate(b, t, wrongChain);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        vm.chainId(block.chainid + 1);
        vm.expectRevert(StreamMintTicketGate.MintTicketBindingMismatch.selector);
        _validate(b, t, sig);
    }

    function testDeadlinesAreInclusiveAndEnforced() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        vm.warp(t.deadline);
        _validate(b, t, sig);
        vm.warp(uint256(t.deadline) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(StreamMintTicketGate.MintTicketExpired.selector, t.deadline)
        );
        _validate(b, t, sig);
    }

    function testOnlyCurrentOrUnexpiredImmediatePredecessorPolicyAccepts() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        manager.setPolicy(keccak256("next policy"), POLICY, 1500);
        vm.warp(1500);
        _validate(b, t, sig);
        vm.warp(1501);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintTicketGate.MintTicketPolicyMismatch.selector, b.expectedPolicyHash
            )
        );
        _validate(b, t, sig);
        manager.setPolicy(keccak256("newest policy"), keccak256("next policy"), 1700);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintTicketGate.MintTicketPolicyMismatch.selector, b.expectedPolicyHash
            )
        );
        _validate(b, t, sig);
    }

    function testAuthorizationIdMustBeFullDomainSeparatedTicketId() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        bytes memory sig = _sign(SIGNER_KEY, _digest(t));
        b.authorizationId = StreamMintTicketHash.body(t);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMintTicketGate.MintTicketAuthorizationMismatch.selector,
                StreamMintTicketHash.authorizationId(_digest(t)),
                b.authorizationId
            )
        );
        _validate(b, t, sig);
    }

    function testZeroRecoveryHighSInvalidVWrongKeyAndMalformedSignaturesReject() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, _digest(t));
        bytes[6] memory bad = [
            abi.encodePacked(bytes32(0), bytes32(0), uint8(27)),
            abi.encodePacked(r, bytes32(type(uint256).max), v),
            abi.encodePacked(r, s, uint8(29)),
            _sign(0xBAD, _digest(t)),
            new bytes(63),
            new bytes(66)
        ];
        for (uint256 i; i < bad.length; ++i) {
            vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
            _validate(b, t, bad[i]);
        }
    }

    function testMalformedGateDataRejects() public {
        IStreamMintManager.MintBatch memory b = _batch();
        (bool ok,) = address(gate)
            .staticcall(
                abi.encodeCall(gate.validateMintBatch, (address(manager), EXECUTOR, b, hex"01"))
            );
        require(!ok, "malformed gateData");
    }
}

contract StreamMintTicketGateSafeTest is TicketGateTestBase, OfficialSafeFixture {
    OfficialSafe private account;
    uint256[] private keys;

    function setUp() public override {
        super.setUp();
        keys = new uint256[](2);
        keys[0] = 0x71211;
        keys[1] = 0x71212;
        uint256[] memory owners = new uint256[](3);
        owners[0] = keys[0];
        owners[1] = keys[1];
        owners[2] = 0x71213;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 1);
        _useGate(new StreamMintTicketGate(address(0), address(account), 2));
    }

    function testActualSafe141ThresholdSignatureValidatesCanonicalTicket() public {
        require(keccak256(bytes(account.VERSION())) == keccak256("1.4.1"), "actual Safe version");
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(_digest(t))));
        IStreamMintGate.GateResult memory result = _validate(b, t, signature);
        require(result.authorizer == address(account) && result.authorizerKind == 2, "Safe signer");
        require(
            result.authorizationId == b.authorizationId && result.gateHash == _digest(t),
            "full digest"
        );
    }

    function testActualSafeRawDigestAndInsufficientThresholdReject() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory raw = safeThresholdSignature(keys, _digest(t));
        uint256[] memory insufficient = new uint256[](1);
        insufficient[0] = keys[0];
        bytes memory shortProof = safeThresholdSignature(
            insufficient, safeMessageDigest(account, abi.encode(_digest(t)))
        );
        vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
        _validate(b, t, raw);
        vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
        _validate(b, t, shortProof);
    }

    function testActualSafePayloadMutationRejectsAndOriginalRemainsValid() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(_digest(t))));
        bytes memory original = b.tokenData[0];
        b.tokenData[0] = hex"deadbeef";
        vm.expectRevert(StreamMintTicketGate.MintTicketPayloadMismatch.selector);
        _validate(b, t, signature);
        b.tokenData[0] = original;
        _validate(b, t, signature);
    }

    function testContractVerificationRequiresFullParentBudget() public {
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory signature =
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(_digest(t))));
        bytes memory payload = abi.encodeCall(
            gate.validateMintBatch, (address(manager), EXECUTOR, b, abi.encode(t, signature))
        );
        (bool ok, bytes memory result) = address(gate).staticcall{ gas: 400_000 }(payload);
        require(
            !ok && bytes4(result) == StreamMintTicketGate.MintTicketInsufficientGas.selector,
            "bounded parent precheck"
        );
        _validate(b, t, signature);
    }

    function testRevertingOutOfGasShortLongWrongMagicAndDirtyMagicAllReject() public {
        TicketGate1271Adversary adversary = new TicketGate1271Adversary();
        _useGate(new StreamMintTicketGate(address(0), address(adversary), 2));
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        for (uint256 mode = 1; mode <= 6; ++mode) {
            adversary.setMode(mode);
            vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
            _validate(b, t, hex"");
        }
    }

    function testERC1271KindOnEOARejectsWithoutChangingVerificationFamily() public {
        _useGate(new StreamMintTicketGate(address(0), vm.addr(SIGNER_KEY), 2));
        IStreamMintManager.MintBatch memory b = _batch();
        StreamMintTicketTypes.MintTicket memory t = _ticket(b);
        _bindId(b, t);
        bytes memory signature = _sign(SIGNER_KEY, _digest(t));
        vm.expectRevert(StreamMintTicketGate.MintTicketInvalidSignature.selector);
        _validate(b, t, signature);
    }
}

contract StreamMintTicketGateGasPolicyTest is TicketGateTestBase {
    function testGasPolicyInventoryHasImmutableFloorAndFailClosedClass() public view {
        bytes32 id = gate.GGP_TICKET_ERC1271_GAS_LIMIT();
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            gate.gasParameterInfo(id);
        require(
            value == 400000 && floor == 350000 && failureClass == 2 && revision == 1, "registration"
        );
        bytes32[] memory ids = gate.gasParameterIds();
        require(ids.length == 1 && ids[0] == id, "closed inventory");
    }

    function testZeroAuthorityPermanentlyDisablesRaises() public {
        bytes32 id = gate.GGP_TICKET_ERC1271_GAS_LIMIT();
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotAuthority.selector, address(this)
            )
        );
        gate.raiseGasParameter(id, 800000);
    }

    function testExactGovernanceContextRaisesBudgetWithoutChangingSignerPolicy() public {
        MockGovernedParameterAuthority authority = new MockGovernedParameterAuthority(true);
        _useGate(new StreamMintTicketGate(address(authority), vm.addr(SIGNER_KEY), 1));
        bytes32 id = gate.GGP_TICKET_ERC1271_GAS_LIMIT();
        bytes32 config = gate.gateConfigHash();
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(gate), id
            )
        );
        bytes32 oldState = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                uint256(400000),
                uint256(350000),
                uint8(2),
                uint64(1)
            )
        );
        bytes32 nextState = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_STATE_V2"),
                scope,
                uint256(800000),
                uint256(350000),
                uint8(2),
                uint64(2)
            )
        );
        authority.setCurrentAction(true, keccak256("ticket raise"), 1, scope, oldState, nextState);
        vm.prank(address(authority));
        gate.raiseGasParameter(id, 800000);
        require(
            gate.gasParameter(id) == 800000 && gate.gateConfigHash() == config,
            "operational-only raise"
        );
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterNotARaise.selector,
                id,
                uint256(800000),
                uint256(400000)
            )
        );
        gate.raiseGasParameter(id, 400000);
        vm.prank(address(authority));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamGasParameterHost.GasParameterRaiseBoundExceeded.selector,
                id,
                uint256(800000),
                uint256(1600001)
            )
        );
        gate.raiseGasParameter(id, 1600001);
    }
}
