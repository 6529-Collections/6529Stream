// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/mint/IStreamDelegateRegistryGate.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../parameters/StreamGasParameterHost.sol";

/// @notice Live delegate.xyz v2 eligibility; delivery and RECIPIENT counters bind the vault.
/// @dev No mint replay or allowance storage. The Manager/Ledger atomically consume the
/// returned authorization/nullifier and policy counters with the actual Core mint.
contract StreamDelegateRegistryGate is IStreamDelegateRegistryGate, StreamGasParameterHost {
    bytes32 public constant MODULE_VERSION = keccak256("6529STREAM_DELEGATE_XYZ_V2_GATE_V1");
    bytes32 public constant DELEGATE_REGISTRY_GAS_LIMIT =
        keccak256("6529STREAM_GGP_DELEGATE_REGISTRY_GAS_LIMIT");
    bytes32 private constant COLLECTION_RIGHTS =
        keccak256("6529STREAM_DELEGATE_COLLECTION_RIGHTS_V1");
    bytes32 private constant AUTHORIZATION = keccak256("6529STREAM_DELEGATE_MINT_AUTHORIZATION_V1");
    bytes32 private constant NULLIFIER = keccak256("6529STREAM_DELEGATE_MINT_NONCE_V1");
    bytes4 private constant CHECK_CONTRACT =
        bytes4(keccak256("checkDelegateForContract(address,address,address,bytes32)"));

    address public immutable override core;
    address public immutable override delegateRegistry;
    bytes32 public immutable override delegateRegistryCodeHash;
    bytes32 public immutable override delegationUsecase;
    uint256 private immutable _chainId;

    struct MintRequest {
        address manager;
        address executor;
        uint256 collectionId;
        bytes32 phaseId;
        address payer;
        address authorizer;
        address[] initialRecipients;
        address[] beneficiaries;
        bytes32 contextHash;
        bytes32 expectedPolicyHash;
        bytes gateData;
    }

    constructor(address core_, address registry_, bytes32 usecase_, address governance_)
        StreamGasParameterHost(governance_)
    {
        if (core_.code.length == 0 || registry_.code.length == 0 || usecase_ == bytes32(0)) {
            revert DelegationConfigurationInvalid();
        }
        core = core_;
        delegateRegistry = registry_;
        delegateRegistryCodeHash = registry_.codehash;
        delegationUsecase = usecase_;
        _chainId = block.chainid;
        _registerGasParameter(
            GasParameterConfig("DELEGATE_REGISTRY_GAS_LIMIT", 150_000, 150_000, 2)
        );
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamDelegateRegistryGate).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function gateConfigHash() public view override returns (bytes32) {
        return keccak256(
            abi.encode(
                MODULE_VERSION,
                _chainId,
                core,
                delegateRegistry,
                delegateRegistryCodeHash,
                delegationUsecase
            )
        );
    }

    function moduleManifest() public view override returns (bytes memory) {
        return abi.encode(
            MODULE_VERSION,
            _chainId,
            address(this),
            core,
            delegateRegistry,
            delegateRegistryCodeHash,
            delegationUsecase,
            gateConfigHash()
        );
    }

    function moduleManifestHash() public view override returns (bytes32) {
        return keccak256(moduleManifest());
    }

    function collectionDelegationRights(uint256 collectionId)
        public
        view
        override
        returns (bytes32)
    {
        return keccak256(
            abi.encode(COLLECTION_RIGHTS, _chainId, core, delegationUsecase, collectionId)
        );
    }

    function isDelegated(address vault, address delegate, uint256 collectionId)
        public
        view
        override
        returns (bool)
    {
        if (_chainId != block.chainid) revert DelegationConfigurationInvalid();
        if (
            delegateRegistry.code.length == 0
                || delegateRegistry.codehash != delegateRegistryCodeHash
        ) revert DelegationRegistryUnavailable(delegateRegistry);
        if (vault == address(0) || delegate == address(0) || vault == delegate) return false;
        // v2's contract getter itself includes wallet-wide authority and wildcard rights.
        // A Stream collection is represented by a right, never by an ERC721 tokenId.
        return _read(vault, delegate, delegationUsecase)
            || _read(vault, delegate, collectionDelegationRights(collectionId));
    }

    function validateMint(
        address,
        address,
        uint256,
        bytes32,
        address,
        address,
        address[] memory,
        address[] memory,
        bytes32,
        bytes32,
        bytes memory
    ) public view override returns (GateResult memory) {
        // Prefix the tuple offset so the existing multi-argument gate ABI decodes as
        // one memory object without changing the selector or requiring a via-IR build.
        MintRequest memory r =
            abi.decode(bytes.concat(bytes32(uint256(32)), msg.data[4:]), (MintRequest));
        return _validate(r);
    }

    function _validate(MintRequest memory r) private view returns (GateResult memory result) {
        _requireManager(r);
        if (r.gateData.length != 64) revert DelegationProofInvalid();
        DelegationProof memory proof = abi.decode(r.gateData, (DelegationProof));
        uint256 quantity = r.initialRecipients.length;
        if (
            quantity == 0 || quantity > type(uint64).max || quantity != r.beneficiaries.length
                || proof.vault == address(0) || r.payer == address(0) || r.payer == proof.vault
                || r.executor == address(0) || r.authorizer != address(0)
        ) revert DelegationRouteInvalid();
        for (uint256 i; i < quantity; ++i) {
            if (r.initialRecipients[i] != proof.vault || r.beneficiaries[i] != proof.vault) {
                revert DelegationRouteInvalid();
            }
        }
        if (!isDelegated(proof.vault, r.payer, r.collectionId)) {
            revert DelegationNotFound(proof.vault, r.payer);
        }
        result.authorizationId =
            keccak256(abi.encode(AUTHORIZATION, _chainId, address(this), gateConfigHash(), r));
        result.nullifiers = new bytes32[](1);
        result.nullifiers[0] = keccak256(
            abi.encode(
                NULLIFIER,
                _chainId,
                address(this),
                r.manager,
                r.collectionId,
                r.phaseId,
                r.payer,
                proof.vault,
                proof.nonce
            )
        );
        result.maxQuantity = uint64(quantity);
        result.gateHash = keccak256(abi.encode(gateConfigHash(), result.authorizationId));
        // authorizer=zero and authorizerKind=NONE: registry eligibility is no signature.
    }

    function _requireManager(MintRequest memory r) private view {
        if (msg.sender != r.manager || r.manager.code.length == 0) {
            revert DelegationManagerMismatch(r.manager);
        }
        (bool ok, bytes memory data) =
            r.manager.staticcall{ gas: 30_000 }(abi.encodeWithSignature("core()"));
        if (!ok || data.length != 32 || abi.decode(data, (address)) != core) {
            revert DelegationManagerMismatch(r.manager);
        }
        IStreamMintManager.MintGateConfig memory configured =
            IStreamMintManager(r.manager).phaseGate(r.collectionId, r.phaseId);
        if (
            configured.gate != address(this) || configured.gateConfigHash != gateConfigHash()
                || configured.gateCodehash != address(this).codehash
                || configured.gateMetadataHash
                    != keccak256(abi.encode(MODULE_VERSION, moduleManifestHash()))
        ) revert DelegationPhaseMismatch();
    }

    function _read(address vault, address delegate, bytes32 rights) private view returns (bool) {
        bytes memory data = abi.encodeWithSelector(CHECK_CONTRACT, delegate, vault, core, rights);
        uint256 cap = _gasParameterValue(DELEGATE_REGISTRY_GAS_LIMIT);
        uint256 available = gasleft();
        if (cap > available || available - cap < cap / 63 + (cap % 63 == 0 ? 0 : 1) + 30_000) {
            revert DelegationReadGas(available, cap);
        }
        address target = delegateRegistry;
        bool ok;
        uint256 size;
        uint256 word;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            word := mload(0)
        }
        if (!ok) revert DelegationReadFailed(target);
        if (size != 32 || word > 1) revert DelegationReadMalformed(target, size);
        return word == 1;
    }
}
