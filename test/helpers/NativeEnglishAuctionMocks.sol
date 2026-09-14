// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/auctions/StreamNativeEnglishAuction.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../smart-contracts/interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";

/// @dev Target-side governance context only; actual role/module registries remain real.
contract NativeAuctionAuthority is MockGovernedParameterAuthority {
    address public roleRegistry;
    constructor() MockGovernedParameterAuthority(true) { }

    function setRoleRegistry(address value) external {
        roleRegistry = value;
    }
}

/// @dev Explicit Artist semantic boundary, preserving original identity independently of keys.
contract NativeAuctionArtist is IStreamArtistAttribution {
    address public immutable override core;
    address public immutable mintManager;
    address public artist;
    bool public consent = true;
    uint8 public state = 2;

    constructor(address source, address manager) {
        core = source;
        mintManager = manager;
    }

    function accept(address value) external {
        artist = value;
    }

    function setConsent(bool value) external {
        consent = value;
    }

    function setState(uint8 value) external {
        state = value;
    }

    function supportsInterface(bytes4 id) public pure virtual returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtistAttribution).interfaceId
            || id == 0x606af4b9 || id == type(IStreamArtistAttributionState).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return artist;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        if (artist != address(0)) {
            a.artist = artist;
            a.nominationHash = keccak256("nomination");
            a.acceptanceHash = keccak256("acceptance");
        }
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return
            (state, 1, keccak256("native auction artist"), 1, keccak256("native auction binding"));
    }

    function requireEconomicsConsent(uint256, bytes32, uint8, uint256, bytes32) external view {
        require(consent, "artist economics");
    }

    function requireSaleConsent(uint256, bytes32, bytes32) external view {
        require(consent, "artist sale");
    }

    function consentMode(uint256) external pure returns (uint8) {
        return 1;
    }

    function isPolicyConsented(uint256, bytes32, bytes32 hash)
        external
        view
        returns (bool, bytes32)
    {
        return (artist != address(0) && consent, keccak256(abi.encode("fixture policy", hash)));
    }

    function requireMintConsent(uint256, bytes32, bytes32) external view {
        require(artist != address(0) && consent, "artist mint");
    }
}

    /// @dev Actual fee escrow API and controlled mint/provider outcomes, not a real Coordinator.
    contract NativeAuctionEntropy is IStreamRevealFeeEscrow {
        address public immutable override core;
        uint256 public fee = 100;
        uint8 public mode = 1;
        bool public rejectingMint;
        bool public rejectingRequest;
        uint256 public mintCalls;
        uint256 public requestCalls;
        mapping(uint256 => uint256) public override revealFeeEscrow;

        constructor(address value) {
            core = value;
        }

        function supportsInterface(bytes4 id) external pure returns (bool) {
            return id == 0x01ffc9a7 || id == type(IStreamRevealFeeEscrow).interfaceId
                || id == type(IStreamEntropyCoordinator).interfaceId;
        }

        function configure(uint256 value, uint8 requestMode, bool rejectMint, bool rejectRequest)
            external
        {
            fee = value;
            mode = requestMode;
            rejectingMint = rejectMint;
            rejectingRequest = rejectRequest;
        }

        function collectionRevealPolicy(uint256)
            external
            view
            returns (CollectionRevealPolicy memory)
        {
            return CollectionRevealPolicy(true, mode, keccak256("ROLE_ENTROPY_REQUESTER"), 20, fee);
        }

        function fundRevealFeeEscrow(uint256 collection) external payable {
            revealFeeEscrow[collection] += msg.value;
        }

        function onTokenMinted(uint256, uint256, address, bytes32) external {
            require(!rejectingMint, "mint endpoint failed");
            ++mintCalls;
        }

        function requestEntropy(uint256 token) external returns (bytes32, uint256) {
            require(!rejectingRequest, "provider rejected");
            ++requestCalls;
            return (keccak256(abi.encode(token)), requestCalls);
        }
    }

        contract NativeAuctionReceiver is IERC721Receiver {
            bool public rejectNFT;
            bool public rejectETH;
            address public callback;
            bytes public callbackData;
            bool public callbackRejected;
            address public forwardTo;

            function configure(
                bool nft,
                bool eth,
                address target,
                bytes calldata data,
                address forward
            ) external {
                rejectNFT = nft;
                rejectETH = eth;
                callback = target;
                callbackData = data;
                forwardTo = forward;
            }

            function callTarget(address target, uint256 value, bytes calldata data)
                external
                payable
                returns (bytes memory)
            {
                (bool ok, bytes memory result) = target.call{ value: value }(data);
                require(ok, "receiver call");
                return result;
            }

            function onERC721Received(address, address, uint256 token, bytes calldata)
                external
                returns (bytes4)
            {
                require(!rejectNFT, "NFT rejected");
                if (callback != address(0)) {
                    (bool ok,) = callback.call(callbackData);
                    callbackRejected = !ok;
                }
                if (forwardTo != address(0)) {
                    IStreamCore(msg.sender).transferFrom(address(this), forwardTo, token);
                }
                return IERC721Receiver.onERC721Received.selector;
            }

            receive() external payable {
                require(!rejectETH, "ETH rejected");
            }
        }
