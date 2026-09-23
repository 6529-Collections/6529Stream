// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./EntropyCollectionPolicyFixtures.sol";
import "../../../smart-contracts/interfaces/stream/entropy/IStreamInstantEntropyProvider.sol";
import {
    IStreamInstantEntropyProviderIdentity as InstantIdentity
} from "../../../smart-contracts/interfaces/stream/entropy/IStreamInstantEntropyProviderIdentity.sol";
import {
    StreamEntropyInstantProviderReads
} from "../../../smart-contracts/domains/entropy/StreamEntropyInstantProviderReads.sol";
import {
    StreamEntropyIncidentParameters
} from "../../../smart-contracts/domains/entropy/StreamEntropyIncidentParameters.sol";

interface EntropyInstantVm {
    function mockCallRevert(address target, bytes calldata data, bytes calldata result) external;
    function clearMockedCalls() external;
}

/// @notice Narrow actual-library host: only the original incident GGP initialization and read path.
contract EntropyInstantReadBudgetHarness {
    bytes32 private constant PARAMETER = keccak256("6529STREAM_GGP_ENTROPY_INSTANT_READ_GAS_LIMIT");
    address public immutable authority;

    constructor(address authority_) {
        authority = authority_;
        StreamEntropyIncidentParameters.initialize(authority_);
    }

    function read(address provider, bytes32 key, bytes calldata context)
        external
        view
        returns (bytes32, bytes32)
    {
        return StreamEntropyInstantProviderReads.entropy(provider, key, context);
    }

    function parameter() external view returns (uint256, uint256, uint8, uint64) {
        return StreamEntropyIncidentParameters.info(PARAMETER);
    }

    function transition(uint256 next) external view returns (bytes32, bytes32, bytes32) {
        return StreamEntropyIncidentParameters.transition(PARAMETER, next);
    }

    function raise(uint256 next) external {
        StreamEntropyIncidentParameters.raise(authority, PARAMETER, next);
    }
}

/// @notice Cheap call-free return isolates parent-budget enforcement from provider execution cost.
contract EntropyInstantCheapReadFixture is IStreamInstantEntropyProvider {
    function instantEntropy(bytes32 key, bytes calldata context)
        external
        pure
        override
        returns (bytes32, bytes32)
    {
        return (key, keccak256(context));
    }
}

/// @notice Adversarial unit provider; the optional observer makes external reads and is not a
///         production-eligible call-free adapter. It never advertises the asynchronous interface.
contract EntropyInstantProviderFixture is IStreamInstantEntropyProvider, InstantIdentity {
    enum Response {
        Normal,
        Reverting,
        Empty,
        Short32,
        Short63,
        Long65,
        Long96,
        GasHeavy
    }
    bytes32 public constant ASSUMPTIONS =
        keccak256("UNIT ONLY: emulated delayed-blockhash profile");
    bytes32 public constant RAW_DOMAIN = keccak256("instant fixture raw");
    bytes32 public constant PROVENANCE_DOMAIN = keccak256("instant fixture provenance");
    StreamEntropyCoordinator public immutable coordinator;
    bytes32 private _configHash;
    Response public response;
    bool public zeroRaw;
    bool public attemptCallback;
    uint256 public profileWord = 1;
    bytes32 public profileAssumptions = ASSUMPTIONS;
    bytes32 private _observedKey;
    bytes32 private _expectedContextHash;
    uint256 private _observedToken;
    uint256 private _observedId;

    error AsyncPathForbidden();

    constructor(StreamEntropyCoordinator host) {
        coordinator = host;
        _configHash = keccak256(abi.encode("instant fixture identity", address(host)));
    }

    function setResponse(Response next) external {
        response = next;
    }

    function setZeroRaw(bool next) external {
        zeroRaw = next;
    }

    function setAttemptCallback(bool next) external {
        attemptCallback = next;
    }

    function setConfigHash(bytes32 next) external {
        _configHash = next;
    }

    function setProfile(uint256 word, bytes32 assumptions) external {
        profileWord = word;
        profileAssumptions = assumptions;
    }

    function armObserver(bytes32 key, uint256 tokenId, uint256 requestId, bytes32 contextHash)
        external
    {
        _observedKey = key;
        _observedToken = tokenId;
        _observedId = requestId;
        _expectedContextHash = contextHash;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamInstantEntropyProvider).interfaceId
            || id == type(InstantIdentity).interfaceId;
    }

    function isStreamInstantEntropyProvider() external pure override returns (bool) {
        return true;
    }

    function streamEntropyProviderFamily() external pure override returns (bytes32) {
        return keccak256("UNIT_ONLY_INSTANT");
    }

    function streamEntropyProviderVersion() external pure override returns (bytes32) {
        return keccak256("instant-fixture-v1");
    }

    function streamEntropyProviderConfigHash() external view override returns (bytes32) {
        return _configHash;
    }

    function instantEntropyProfile() external view override returns (InstantMode, bytes32) {
        if (_observedKey != 0) _assertRequested();
        uint256 word = profileWord;
        bytes32 assumptions = profileAssumptions;
        // Deliberately permits noncanonical enum words to test the consumer's exact ABI checks.
        assembly ("memory-safe") {
            let result := mload(0x40)
            mstore(result, word)
            mstore(add(result, 32), assumptions)
            return(result, 64)
        }
    }

    function quoteRequest(bytes calldata) external pure returns (uint256) {
        revert AsyncPathForbidden();
    }

    function requestEntropy(bytes32, bytes calldata) external payable returns (uint256) {
        revert AsyncPathForbidden();
    }

    function instantEntropy(bytes32 key, bytes calldata context)
        external
        view
        override
        returns (bytes32 raw, bytes32 provenance)
    {
        require(msg.sender == address(coordinator), "exact Coordinator caller");
        if (_observedKey != 0) {
            _assertRequested();
            require(
                key == _observedKey && keccak256(context) == _expectedContextHash,
                "literal normalized context"
            );
        }
        if (attemptCallback) {
            (bool ok,) = address(coordinator)
                .staticcall(
                    abi.encodeCall(coordinator.fulfillEntropy, (key, bytes32(uint256(999))))
                );
            require(!ok, "callback cannot participate in synchronous finality");
        }
        Response mode = response;
        if (mode == Response.Reverting) revert("instant read unavailable");
        if (mode == Response.GasHeavy) {
            uint256 start = gasleft();
            while (start - gasleft() < 1_000_000) { }
        }
        raw = zeroRaw ? bytes32(0) : keccak256(abi.encode(RAW_DOMAIN, key, keccak256(context)));
        provenance = keccak256(abi.encode(PROVENANCE_DOMAIN, key, keccak256(context)));
        // With an unbounded call the slow branch would return valid data, so its test specifically
        // detects the Coordinator's enforced read budget rather than an unrelated bad return size.
        if (mode == Response.Normal || mode == Response.GasHeavy) return (raw, provenance);
        uint256 size = mode == Response.Empty
            ? 0
            : mode == Response.Short32
                ? 32
                : mode == Response.Short63 ? 63 : mode == Response.Long65 ? 65 : 96;
        bytes memory encoded = new bytes(96);
        assembly ("memory-safe") {
            mstore(add(encoded, 32), raw)
            mstore(add(encoded, 64), provenance)
            mstore(add(encoded, 96), 1)
            return(add(encoded, 32), size)
        }
    }

    function _assertRequested() private view {
        require(
            coordinator.tokenEntropyStatus(_observedToken) == StreamEntropyStatus.REQUESTED,
            "REQUESTED before provider read"
        );
        (
            bytes32 subject,
            uint256 tokenId,
            bytes32 scope,
            address provider,
            uint64 requestedAt,
            uint256 requestId,
            bytes32 raw
        ) = coordinator.requests(_observedKey);
        require(
            subject == keccak256(abi.encode("TOKEN", _observedToken)) && tokenId == _observedToken
                && scope == 0,
            "stored request subject"
        );
        require(
            provider == address(this) && requestedAt == block.number && requestId == _observedId
                && raw == 0,
            "allocated ID before provider read"
        );
        IStreamEntropyEpochs.RequestPolicySnapshot memory p =
            coordinator.requestPolicySnapshot(_observedKey);
        require(
            p.provider == address(this) && p.providerCodeHash == address(this).codehash
                && p.providerEpoch == 1,
            "snapshot provider before read"
        );
        require(
            p.providerConfigHash == _configHash && p.requestAttempt == 1 && p.inputsHash == 0,
            "normalized snapshot before read"
        );
        require(
            coordinator.providerRequestKeys(address(this), _observedId) == _observedKey,
            "reverse ID bound before read"
        );
        require(
            coordinator.pendingRequestCount() == 1 && coordinator.nonterminalTokenCount(1) == 1,
            "pre-read counters"
        );
    }
}
