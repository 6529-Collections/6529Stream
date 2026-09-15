// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./SaleFundingTestMocks.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttributionState.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../smart-contracts/interfaces/stream/entropy/IStreamRevealFeeEscrow.sol";

/// @dev Explicit target-side governance context, not an executing delayed Executor.
contract RefundRuntimeAuthority is MockGovernedParameterAuthority {
    address public roleRegistry;
    constructor() MockGovernedParameterAuthority(true) { }

    function setRoleRegistry(address target) external {
        roleRegistry = target;
    }
}

/// @dev Current Core pointer and collection facts seam. No actual Core storage/mint claim.
contract RefundRuntimeCore {
    mapping(bytes32 => address) public pointers;
    bool public limited;
    uint256 public cap;
    uint256 public minted;

    function setPointer(bytes32 kind, address target) external {
        pointers[kind] = target;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function setSupply(bool l, uint256 c, uint256 m) external {
        limited = l;
        cap = c;
        minted = m;
    }

    function collectionHasMaxSupply(uint256) external view returns (bool) {
        return limited;
    }

    function collectionMaxSupply(uint256) external view returns (uint256) {
        return cap;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = pointers[kind];
        bytes4 capability = kind == keccak256("ARTIST_REGISTRY")
            ? type(IStreamArtistAttribution).interfaceId
            : kind == keccak256("ENTROPY_COORDINATOR")
                ? type(IStreamRevealFeeEscrow).interfaceId
                : type(IStreamModuleRegistry).interfaceId;
        return (
            target,
            target.codehash,
            false,
            kind,
            capability,
            pointers[keccak256("MODULE_REGISTRY")],
            1,
            keccak256("manifest"),
            keccak256("deployment"),
            1
        );
    }
}

/// @dev Actual snapshot/preview/receiver calls, with phase/counter/ledger authority explicitly doubled.
contract RefundRuntimeManager {
    address public immutable core;
    address public immutable moduleRegistry;
    bytes32 public currentPolicy = keccak256("refund phase policy");
    bytes32 public priorPolicy;
    uint64 public graceUntil;
    uint64 public phaseEnd = 20_000_000;
    bool public paused;
    bool public admitted = true;
    bool public unavailable;
    uint256 public nonce;
    uint256 public mode;
    mapping(uint256 => address) public ownerOf;
    bytes32 public lastAuthorizationId;
    bytes32 public lastContextHash;
    address public lastPayer;
    IStreamMintManager.MintGateConfig private _gate;

    constructor(address c, address r) {
        core = c;
        moduleRegistry = r;
    }

    function isStreamMintManager() external pure returns (bool) {
        return true;
    }

    function setPhase(bool p, uint64 end, bool allowed) external {
        paused = p;
        phaseEnd = end;
        admitted = allowed;
    }

    function setUnavailable(bool value) external {
        unavailable = value;
    }

    function setPolicy(bytes32 current, bytes32 prior, uint64 grace) external {
        currentPolicy = current;
        priorPolicy = prior;
        graceUntil = grace;
    }

    function setMode(uint256 value) external {
        mode = value;
    }

    function phasePolicyHash(uint256, bytes32) external view returns (bytes32) {
        require(!unavailable, "phase unavailable");
        return currentPolicy;
    }

    function phasePolicyGrace(uint256, bytes32) external view returns (bytes32, uint64) {
        require(!unavailable, "phase unavailable");
        return (priorPolicy, graceUntil);
    }

    function phase(uint256, bytes32)
        external
        view
        returns (bool, IStreamMintManager.MintPhaseConfig memory c)
    {
        require(!unavailable, "phase unavailable");
        c.paused = paused;
        c.endTime = phaseEnd;
        c.maxBatchQuantity = 1;
        return (true, c);
    }

    function phaseExecutor(uint256, bytes32, address) external view returns (bool) {
        return admitted;
    }

    function setGate(address target) external {
        _gate.gate = target;
        _gate.gateCodehash = target.codehash;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return _gate;
    }

    function phaseCounterIds(uint256, bytes32) external pure returns (bytes32[] memory ids) {
        ids = new bytes32[](0);
    }

    function previewSingleStepMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata
    ) external view returns (bytes32 root, bytes32[] memory ids) {
        return _identity(batch);
    }

    function executeSingleStepMint(IStreamMintManager.MintBatch calldata batch, bytes calldata)
        external
        returns (uint256[] memory tokens, bytes32 root, bytes32[] memory ids)
    {
        require(mode != 1, "mint rejected");
        (root, ids) = _identity(batch);
        if (mode == 2) root = bytes32(uint256(root) + 1);
        if (mode == 3) ids[0] = bytes32(uint256(ids[0]) + 1);
        tokens = new uint256[](1);
        tokens[0] = ++nonce;
        ownerOf[tokens[0]] = batch.initialRecipients[0];
        lastAuthorizationId = batch.authorizationId;
        lastContextHash = batch.contextHash;
        lastPayer = batch.payer;
        if (batch.initialRecipients[0].code.length != 0) {
            require(
                IERC721Receiver(batch.initialRecipients[0])
                    .onERC721Received(msg.sender, address(0), tokens[0], "")
                == IERC721Receiver.onERC721Received.selector,
                "receiver magic"
            );
        }
    }

    function _identity(IStreamMintManager.MintBatch calldata batch)
        private
        view
        returns (bytes32 root, bytes32[] memory ids)
    {
        require(
            !unavailable && !paused && admitted && (phaseEnd == 0 || block.timestamp <= phaseEnd),
            "phase closed"
        );
        require(
            batch.expectedPolicyHash == currentPolicy
                || (batch.expectedPolicyHash == priorPolicy && block.timestamp <= graceUntil),
            "policy stale"
        );
        root = keccak256(abi.encode(batch, msg.sender, nonce));
        ids = new bytes32[](1);
        ids[0] = keccak256(abi.encode(root, uint256(0)));
    }
}

contract RefundRuntimeArtist is
    SaleFundingArtistMock,
    IStreamArtistAttributionState,
    IStreamArtistBeneficiaryFacts
{
    uint8 public state = 2;
    uint64 public generation = 1;
    bytes32 public identity = keccak256("refund artist identity");
    uint8 public authorityStatus = 1;
    bytes32 public binding = keccak256("refund artist binding");
    address public payout;
    bytes32 public designation = keccak256("refund payout designation");
    constructor(address c) SaleFundingArtistMock(c) { }

    function setAssociation(uint8 s, uint64 g, bytes32 i, uint8 a, bytes32 b) external {
        state = s;
        generation = g;
        identity = i;
        authorityStatus = a;
        binding = b;
    }

    function setPayout(address p) external {
        payout = p;
        designation = keccak256(abi.encode(p));
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (state, generation, identity, authorityStatus, binding);
    }

    function collectionArtistBeneficiary(uint256)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(state == 2 && artist != address(0), "unaccepted");
        return (identity, payout, designation);
    }
}

/// @dev Implements the pinned fee boundary; real Coordinator/provider composition is separate.
contract RefundRuntimeEntropy is IStreamRevealFeeEscrow {
    address public immutable override core;
    CollectionRevealPolicy private _policy;
    mapping(uint256 => uint256) public override revealFeeEscrow;
    uint256 public requestCount;
    uint256 public requestMode;
    uint256 public fundMode;
    address public callback;
    bytes public callbackData;

    constructor(address c) {
        core = c;
        _policy = CollectionRevealPolicy(true, 1, keccak256("ROLE_ENTROPY_REQUESTER"), 20, 100);
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamRevealFeeEscrow).interfaceId || id == type(IERC165).interfaceId;
    }

    function collectionRevealPolicy(uint256) external view returns (CollectionRevealPolicy memory) {
        return _policy;
    }

    function setPolicy(bool declared, uint8 mode, uint256 fee) external {
        _policy.declared = declared;
        _policy.requestMode = mode;
        _policy.revealFeePerTokenWei = fee;
    }

    function setModes(uint256 f, uint256 r) external {
        fundMode = f;
        requestMode = r;
    }

    function setCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function fundRevealFeeEscrow(uint256 collection) external payable {
        require(fundMode != 1, "fund rejected");
        if (fundMode != 2) revealFeeEscrow[collection] += msg.value;
        if (callback != address(0)) {
            (bool ok,) = callback.call(callbackData);
            require(ok, "fee callback rejected");
        }
        if (fundMode == 3) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 32)
            }
        }
    }

    function requestEntropy(uint256 tokenId) external returns (bytes32, uint256) {
        ++requestCount;
        if (requestMode == 1) revert("provider rejected");
        if (requestMode == 2) assembly ("memory-safe") { for { } 1 { } { } }
        if (requestMode == 3) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 32)
            }
        }
        if (requestMode == 4) {
            assembly ("memory-safe") {
                let p := mload(0x40)
                mstore(p, 1)
                return(p, 65536)
            }
        }
        return (keccak256(abi.encode(tokenId)), block.number);
    }
}
