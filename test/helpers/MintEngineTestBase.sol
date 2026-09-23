// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./MintRevocationTestBase.sol";

interface MintEngineLedgerBinding {
    function mintLedger() external view returns (address);
}

/// @dev Typed current Core boundary: only declared registry/artist pointers are populated.
contract MintEngineCoreFixture {
    address public registry;
    address public artist;
    address public manager;
    address public mintLedger;
    uint256 public minted;
    bool public rejectMint;
    mapping(uint256 => address) public ownerOf;

    function initialize(address r, address a, address m) external {
        registry = r;
        artist = a;
        manager = m;
        mintLedger = m == address(0) ? address(0) : MintEngineLedgerBinding(m).mintLedger();
    }

    function setMintLedger(address value) external {
        mintLedger = value;
    }

    function setRejectMint(bool reject) external {
        rejectMint = reject;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address selected;
        if (kind == keccak256("MODULE_REGISTRY")) selected = registry;
        else if (kind == keccak256("ARTIST_REGISTRY")) selected = artist;
        else if (kind == keccak256("MINT_MANAGER")) selected = manager;
        else if (kind == keccak256("MINT_LEDGER")) selected = mintLedger;
        return (
            selected,
            selected == address(0) ? bytes32(0) : selected.codehash,
            false,
            kind,
            0,
            selected,
            1,
            0,
            0,
            1
        );
    }

    function mintFromManager(uint256, address recipient, bytes calldata, bytes32, bytes32)
        external
        returns (uint256, uint256)
    {
        require(msg.sender == manager && !rejectMint, "core mint admission");
        ownerOf[++minted] = recipient;
        return (minted, minted);
    }
}

/// @dev Actual Manager/Ledger/ModuleRegistry, with explicit typed Core/Artist/governance seams.
abstract contract MintEngineTestBase is MintRevocationTestBase {
    function setUp() public virtual override {
        vm.warp(1000);
        signer = vm.addr(SIGNER_KEY);
        authority = new MockGovernedParameterAuthority(true);
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), keccak256("registry"), "ipfs://registry"
        );
        core = MintRevocationCoreMock(address(new MintEngineCoreFixture()));
        artist = new MintRevocationArtistMock(address(core));
        core.initialize(address(registry), address(artist), address(0));
        ledger = new StreamMintLedger();
        manager = _manager(address(ledger));
        ledger.setLedgerWriter(address(manager), true);
        artist.setManager(address(manager));
        core.initialize(address(registry), address(artist), address(manager));
    }
}
