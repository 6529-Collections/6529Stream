// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/mint/StreamOperatorDistribution.sol";
import "../../smart-contracts/domains/mint/StreamMintManager.sol";
import "../../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../../smart-contracts/vendor/openzeppelin/ERC721.sol";

interface DistributionVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function deal(address account, uint256 balance) external;
    function prank(address caller) external;
    function warp(uint256 timestamp) external;
    function expectRevert() external;
    function expectRevert(bytes4 selector) external;
    function expectPartialRevert(bytes4 selector) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Typed Governance-V2 marker only. Actual governance integration has a separate current test.
contract DistributionAuthorityBoundary {
    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, 0, 0, 0, 0, 0);
    }
}

/// @dev Exact canonical registry shapes; lifecycle mutations are fixture inputs, not governance evidence.
contract DistributionRegistryBoundary is ERC165 {
    address public governanceExecutor;
    mapping(address => StreamModuleRecord) private _records;

    constructor(address authority) {
        governanceExecutor = authority;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || super.supportsInterface(id);
    }

    function register(StreamOperatorDistribution distribution) external {
        _records[address(distribution)] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            distribution.MODULE_TYPE(),
            keccak256("v1"),
            type(IStreamOperatorDistribution).interfaceId,
            300_000,
            address(distribution).codehash,
            keccak256("deployment"),
            keccak256(distribution.moduleManifestBytes()),
            "urn:fixture",
            uint64(block.timestamp),
            uint64(block.timestamp),
            1
        );
    }

    function revoke(address target) external {
        _records[target].status = ModuleRegistryStatus.INCIDENT_REVOKED;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return _records[target];
    }

    function isModuleEligible(address target, bytes32 kind, bytes4 id)
        external
        view
        returns (bool)
    {
        StreamModuleRecord memory r = _records[target];
        return r.status == ModuleRegistryStatus.ACTIVE && r.moduleType == kind
            && r.interfaceId == id && r.runtimeCodeHash == target.codehash;
    }
}

/// @dev Only fixture-approved exact policy hashes pass; actual Artist signatures are separate coverage.
contract DistributionArtistBoundary {
    address public core;
    address public mintManager;
    mapping(bytes32 => bool) public consented;

    constructor(address core_) {
        core = core_;
    }

    function configure(address manager) external {
        mintManager = manager;
    }

    function consent(bytes32 policy) external {
        consented[policy] = true;
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32 policy)
        external
        view
        returns (bool, bytes32)
    {
        return (consented[policy], consented[policy] ? policy : bytes32(0));
    }

    function requireMintConsent(uint256, bytes32, bytes32 policy) external view {
        require(consented[policy], "fixture policy not consented");
    }
}

/// @dev Sale-facing fee and request boundary with adjustable failures; never a provider simulation claim.
contract DistributionEntropyBoundary {
    address public core;
    uint256 public fee;
    uint8 public mode;
    bool public requestFails;
    bool public fundingFails;
    uint256 public requests;
    mapping(uint256 => uint256) public revealFeeEscrow;

    constructor(address core_) {
        core = core_;
    }

    function setFee(uint256 value) external {
        fee = value;
    }

    function setMode(uint8 value) external {
        mode = value;
    }

    function fail(bool funding, bool requesting) external {
        fundingFails = funding;
        requestFails = requesting;
    }

    function collectionRevealPolicy(uint256)
        external
        view
        returns (IStreamRevealFeeEscrow.CollectionRevealPolicy memory)
    {
        return
            IStreamRevealFeeEscrow.CollectionRevealPolicy(true, mode, keccak256("role"), 100, fee);
    }

    function fundRevealFeeEscrow(uint256 collectionId) external payable {
        require(!fundingFails, "fixture funding failure");
        revealFeeEscrow[collectionId] += msg.value;
    }

    function requestEntropy(uint256) external payable returns (bytes32, uint256) {
        require(!requestFails, "fixture request failure");
        return (keccak256(abi.encode(++requests)), requests);
    }
}

/// @dev Real ERC721 transfer/rejection behavior and current Core mint ABI, without Core governance.
contract DistributionCoreBoundary is ERC721 {
    address public registry;
    address public artists;
    address public entropy;
    address public manager;
    uint256 public minted;
    uint256 private pending;
    bytes32 private operation;
    constructor() ERC721("Distribution boundary", "DIST") { }

    function configure(address registry_, address artists_, address entropy_, address manager_)
        external
    {
        registry = registry_;
        artists = artists_;
        entropy = entropy_;
        manager = manager_;
    }

    function getSatellitePointer(bytes32 role)
        external
        view
        returns (
            address target,
            bytes32 hash,
            address,
            bytes32,
            bytes4,
            bytes32,
            bytes32,
            uint8,
            uint64,
            uint64
        )
    {
        if (role == keccak256("MODULE_REGISTRY")) target = registry;
        else if (role == keccak256("ARTIST_REGISTRY")) target = artists;
        else if (role == keccak256("ENTROPY_COORDINATOR")) target = entropy;
        return (target, target.codehash, address(0), 0, 0, 0, 0, 0, 0, 0);
    }

    function mintFromManager(uint256, address to, bytes calldata, bytes32, bytes32)
        external
        returns (uint256, uint256)
    {
        require(msg.sender == manager, "manager only");
        uint256 id = ++minted;
        _safeMint(to, id);
        return (id, id);
    }

    function prepareMintFromManager(uint256, bytes calldata, bytes32, bytes32 op)
        external
        returns (uint256, uint256)
    {
        require(msg.sender == manager && pending == 0, "prepare manager only");
        pending = ++minted;
        operation = op;
        return (pending, pending);
    }

    function completePreparedMintFromManager(uint256 id, address to, bytes32 op, bytes32) external {
        require(msg.sender == manager && id == pending && op == operation, "exact preparation");
        pending = 0;
        _safeMint(to, id);
    }
}

/// @dev Original NFTDelegation read ABI and packed key, with live configurable retained rows.
contract DistributionDelegationBoundary {
    struct Row {
        address vault;
        address delegate;
        uint256 start;
        uint256 end;
        bool allTokens;
        uint256 tokenId;
    }
    mapping(bytes32 => mapping(uint256 => Row)) public globalDelegationHashes;

    function set(address vault, address delegate, address scope, uint256 usecase, uint256 expiry)
        external
    {
        globalDelegationHashes[keccak256(abi.encodePacked(vault, scope, delegate, usecase))][0] =
            Row(vault, delegate, block.timestamp, expiry, true, 0);
    }
}

contract DistributionReceiver is IERC721Receiver {
    uint8 public mode;
    StreamOperatorDistribution public distributor;
    uint256 public claimToken;
    bool public reentrySucceeded;

    constructor(uint8 mode_) {
        mode = mode_;
    }

    function setMode(uint8 next) external {
        mode = next;
    }

    function claim(StreamOperatorDistribution target, uint256 tokenId, address receiver)
        external
        returns (bool)
    {
        return target.claimNft(tokenId, receiver);
    }

    function setReentry(StreamOperatorDistribution target, uint256 tokenId) external {
        distributor = target;
        claimToken = tokenId;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (mode == 1) revert("reject");
        if (mode == 2) assembly ("memory-safe") { revert(0, 1000000) }
        if (mode == 3) {
            while (gasleft() > 100) { }
            revert("gas");
        }
        if (mode == 4) {
            (reentrySucceeded,) = address(distributor)
                .call(abi.encodeCall(distributor.claimNft, (claimToken, address(this))));
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
