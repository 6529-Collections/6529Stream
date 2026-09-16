// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamMintBatchGate.sol";
import "../../vendor/openzeppelin/ERC165.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamMintTicketHash.sol";

/// @dev The existing Manager getter is intentionally outside its permanent compatibility ABI.
interface IStreamMintTicketManagerBinding {
    function mintLedger() external view returns (address);
}

/// @notice Canonical full-payload EIP-712 ticket gate with an immutable authorized signer policy.
/// @dev Gate evidence is view-only. Manager consumes the returned authorization ID in Ledger
///      before calling Core; neither successful preview nor signature verification consumes it.
contract StreamMintTicketGate is
    IStreamMintGate,
    IStreamMintBatchGate,
    ERC165,
    StreamGasParameterHost
{
    bytes32 public constant GGP_TICKET_ERC1271_GAS_LIMIT =
        keccak256("6529STREAM_GGP_TICKET_ERC1271_GAS_LIMIT");
    bytes32 public constant CONFIG_DOMAIN = keccak256("6529STREAM_MINT_TICKET_GATE_CONFIG_V1");
    bytes32 private constant BATCH_RECIPIENTS_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1");
    bytes32 private constant BATCH_BENEFICIARIES_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1");
    bytes32 private constant BATCH_TOKEN_DATA_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1");
    bytes32 private constant BATCH_COMMITMENTS_DOMAIN =
        keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1");

    address public immutable ticketSigner;
    uint8 public immutable ticketSignerKind;
    bytes32 public immutable gateConfigHash;

    error MintTicketInvalidSignerPolicy(address signer, uint8 kind);
    error MintTicketFullBatchRequired();
    error MintTicketGateConfigurationMismatch();
    error MintTicketBindingMismatch();
    error MintTicketPayloadMismatch();
    error MintTicketPolicyMismatch(bytes32 policyHash);
    error MintTicketExpired(uint64 deadline);
    error MintTicketInvalidSignature();
    error MintTicketAuthorizationMismatch(bytes32 expected, bytes32 supplied);
    error MintTicketInsufficientGas(uint256 required, uint256 available);

    /// @param authority Canonical Governance-V2 executor; zero permanently disables GGP raises.
    /// @param signer The sole signer admitted by this configuration, including a Safe when kind=2.
    /// @param kind Explicit EOA_712 (1) or ERC1271_712 (2); never inferred from signer code.
    constructor(address authority, address signer, uint8 kind) StreamGasParameterHost(authority) {
        if (signer == address(0) || (kind != 1 && kind != 2)) {
            revert MintTicketInvalidSignerPolicy(signer, kind);
        }
        ticketSigner = signer;
        ticketSignerKind = kind;
        gateConfigHash = keccak256(abi.encode(CONFIG_DOMAIN, signer, kind));
        _registerGasParameter(GasParameterConfig("TICKET_ERC1271_GAS_LIMIT", 400_000, 350_000, 2));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC165)
        returns (bool)
    {
        return interfaceId == type(IStreamMintGate).interfaceId
            || interfaceId == type(IStreamMintBatchGate).interfaceId
            || interfaceId == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @notice ERC-5267 discovery of the exact MPA-TICKET EIP-712 domain.
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            hex"0f",
            "6529Stream Mint Tickets",
            "1",
            block.chainid,
            address(this),
            0,
            new uint256[](0)
        );
    }

    /// @notice The old gate ABI cannot authenticate tokenData or mintCommitments and fails closed.
    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] calldata,
        address[] calldata,
        bytes32,
        bytes32,
        bytes calldata
    ) external pure override returns (GateResult memory) {
        revert MintTicketFullBatchRequired();
    }

    /// @param gateData abi.encode(StreamMintTicketTypes.MintTicket, bytes signature).
    function validateMintBatch(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external view override returns (GateResult memory result) {
        (StreamMintTicketTypes.MintTicket memory ticket, bytes memory signature) =
            abi.decode(gateData, (StreamMintTicketTypes.MintTicket, bytes));
        _requireBindings(manager, executor, batch, ticket);
        _requirePolicy(manager, batch);
        if (block.timestamp > ticket.deadline) revert MintTicketExpired(ticket.deadline);
        bytes32 digest = StreamMintTicketHash.digest(block.chainid, address(this), ticket);
        if (!_validSignature(digest, signature)) revert MintTicketInvalidSignature();
        bytes32 id = StreamMintTicketHash.authorizationId(digest);
        if (batch.authorizationId != id) {
            revert MintTicketAuthorizationMismatch(id, batch.authorizationId);
        }
        return GateResult({
            authorizationId: id,
            nullifiers: new bytes32[](0),
            authorizer: ticketSigner,
            authorizerKind: ticketSignerKind,
            maxQuantity: uint64(ticket.quantity),
            gateHash: digest
        });
    }

    function _requireBindings(
        address manager,
        address executor,
        IStreamMintManager.MintBatch calldata batch,
        StreamMintTicketTypes.MintTicket memory ticket
    ) private view {
        if (
            manager == address(0) || ticket.chainId != block.chainid || ticket.manager != manager
                || ticket.ledger == address(0)
                || ticket.ledger != IStreamMintTicketManagerBinding(manager).mintLedger()
        ) revert MintTicketBindingMismatch();
        if (
            ticket.authorizer != ticketSigner || ticket.authorizerKind != ticketSignerKind
                || ticket.authorizer != batch.authorizer || ticket.executor != executor
                || ticket.payer != batch.payer || ticket.collectionId != batch.collectionId
                || ticket.phaseId != batch.phaseId || ticket.contextHash != batch.contextHash
                || ticket.policyHash != batch.expectedPolicyHash
        ) revert MintTicketPayloadMismatch();
        uint256 quantity = batch.initialRecipients.length;
        if (
            quantity == 0 || quantity > type(uint64).max || ticket.quantity != quantity
                || batch.beneficiaries.length != quantity || batch.tokenData.length != quantity
                || batch.mintCommitments.length != quantity
                || ticket.initialRecipientsHash
                    != keccak256(abi.encode(BATCH_RECIPIENTS_DOMAIN, batch.initialRecipients))
                || ticket.beneficiariesHash
                    != keccak256(abi.encode(BATCH_BENEFICIARIES_DOMAIN, batch.beneficiaries))
                || ticket.tokenDataArrayHash
                    != keccak256(abi.encode(BATCH_TOKEN_DATA_DOMAIN, batch.tokenData))
                || ticket.mintCommitmentsHash
                    != keccak256(abi.encode(BATCH_COMMITMENTS_DOMAIN, batch.mintCommitments))
        ) revert MintTicketPayloadMismatch();
    }

    function _requirePolicy(address manager, IStreamMintManager.MintBatch calldata batch)
        private
        view
    {
        IStreamMintManager source = IStreamMintManager(manager);
        IStreamMintManager.MintGateConfig memory config =
            source.phaseGate(batch.collectionId, batch.phaseId);
        if (config.gate != address(this) || config.gateConfigHash != gateConfigHash) {
            revert MintTicketGateConfigurationMismatch();
        }
        bytes32 policy = batch.expectedPolicyHash;
        if (policy == bytes32(0)) revert MintTicketPolicyMismatch(policy);
        if (source.phasePolicyHash(batch.collectionId, batch.phaseId) == policy) return;
        (bytes32 previous, uint64 graceUntil) =
            source.phasePolicyGrace(batch.collectionId, batch.phaseId);
        if (policy != previous || block.timestamp > graceUntil) {
            revert MintTicketPolicyMismatch(policy);
        }
    }

    /// @dev Explicit-kind counterpart to StreamMintRevocation's canonical signature verifier.
    function _validSignature(bytes32 digest, bytes memory signature) private view returns (bool) {
        if (ticketSignerKind == 1) {
            bytes32 r;
            bytes32 s;
            uint8 v;
            if (signature.length == 65) {
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    s := mload(add(signature, 64))
                    v := byte(0, mload(add(signature, 96)))
                }
            } else if (signature.length == 64) {
                bytes32 vs;
                assembly ("memory-safe") {
                    r := mload(add(signature, 32))
                    vs := mload(add(signature, 64))
                }
                s = bytes32(uint256(vs) & ((uint256(1) << 255) - 1));
                v = uint8((uint256(vs) >> 255) + 27);
            } else {
                return false;
            }
            if (
                uint256(s) > 0x7fffffffffffffffffffffffffffffff5d576e7357a4501ddfe92f46681b20a0
                    || (v != 27 && v != 28)
            ) return false;
            address recovered = ecrecover(digest, v, r, s);
            return recovered != address(0) && recovered == ticketSigner;
        }
        bytes memory data = abi.encodeWithSelector(bytes4(0x1626ba7e), digest, signature);
        uint256 cap = _gasParameterValue(GGP_TICKET_ERC1271_GAS_LIMIT);
        uint256 available = gasleft();
        uint256 required = cap + (cap + 62) / 63 + 40_000;
        if (available < required) revert MintTicketInsufficientGas(required, available);
        bool ok;
        uint256 size;
        uint256 word;
        address signer = ticketSigner;
        assembly ("memory-safe") {
            ok := staticcall(cap, signer, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        return ok && size == 32 && word == uint256(uint32(0x1626ba7e)) << 224;
    }
}
