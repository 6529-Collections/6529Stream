// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamSaleArtist.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev Explicit dependency doubles isolate commercial attribution admission, not mint eligibility.
contract SaleArtistCoreBoundary {
    address private _selected;
    bytes32 private _codeHash;

    function select(address selected, bytes32 hash) external {
        _selected = selected;
        _codeHash = hash;
    }

    function getSatellitePointer(bytes32)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (_selected, _codeHash, false, 0, 0, address(0), 0, 0, 0, 0);
    }
}

contract SaleArtistAttributionBoundary is IStreamArtistAttribution {
    address public immutable core;
    address private _accepted;
    IStreamCollectionArtistRegistry.Attribution private _facts;

    constructor(address core_) {
        core = core_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId || id == 0x01ffc9a7;
    }

    function acceptedArtist(uint256) external view returns (address) {
        return _accepted;
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return _facts;
    }

    function set(address accepted, IStreamCollectionArtistRegistry.Attribution calldata facts)
        external
    {
        _accepted = accepted;
        _facts = facts;
    }
}

contract SaleArtistAdmissionProbe {
    IStreamArtistAttribution private immutable _registry;
    bytes32 private immutable _hash;

    constructor(IStreamArtistAttribution registry_) {
        require(StreamSaleArtist.supportsAttribution(registry_), "narrow admission");
        _registry = registry_;
        _hash = address(registry_).codehash;
    }

    function check(address artist) external view {
        StreamSaleArtist.requireArtist(_registry, _hash, 1, artist);
    }
}

contract StreamSaleArtistTest is CharacterizationTestBase {
    address private constant ARTIST = address(0xA47157);
    SaleArtistCoreBoundary private core;
    SaleArtistAttributionBoundary private registry;
    SaleArtistAdmissionProbe private probe;
    IStreamCollectionArtistRegistry.Attribution private facts;

    function setUp() public {
        core = new SaleArtistCoreBoundary();
        registry = new SaleArtistAttributionBoundary(address(core));
        probe = new SaleArtistAdmissionProbe(registry);
        core.select(address(registry), address(registry).codehash);
        facts = IStreamCollectionArtistRegistry.Attribution(
            ARTIST,
            ARTIST,
            keccak256("identity"),
            keccak256("binding"),
            keccak256("acceptance"),
            1,
            1
        );
        registry.set(ARTIST, facts);
    }

    function testNarrowAcceptedAttributionAdmitsWithoutLegacyMutationInterface() public view {
        require(
            !registry.supportsInterface(type(IStreamCollectionArtistRegistry).interfaceId),
            "legacy ID advertised"
        );
        probe.check(ARTIST);
    }

    function testProposedOrOptedOutArtistCannotAuthorizeNewSale() public {
        registry.set(address(0), facts);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch.selector,
                1,
                address(0),
                ARTIST
            )
        );
        probe.check(ARTIST);
    }

    function testWrongArtistCannotAuthorizeNewSale() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionArtistRegistry.ArtistRegistryArtistMismatch.selector,
                1,
                ARTIST,
                address(this)
            )
        );
        probe.check(address(this));
    }

    function testInconsistentOrIncompleteFactsCannotAuthorizeNewSale() public {
        facts.artist = address(this);
        _incomplete();
        facts.artist = ARTIST;
        facts.nominationHash = 0;
        _incomplete();
        facts.nominationHash = keccak256("binding");
        facts.acceptanceHash = 0;
        _incomplete();
    }

    function _incomplete() private {
        registry.set(ARTIST, facts);
        vm.expectRevert(
            abi.encodeWithSelector(StreamSaleArtist.IncompleteArtistAttribution.selector, 1)
        );
        probe.check(ARTIST);
    }

    function testOperativeArtistMayDifferFromOriginalNominee() public {
        facts.nominatedArtist = address(0x01D);
        registry.set(ARTIST, facts);
        probe.check(ARTIST);
    }

    function testRemovedReplacedOrWrongHashRegistryCannotAuthorizeNewSale() public {
        core.select(address(0), 0);
        _changed(address(0));
        SaleArtistAttributionBoundary replacement = new SaleArtistAttributionBoundary(address(core));
        core.select(address(replacement), address(replacement).codehash);
        _changed(address(replacement));
        core.select(address(registry), keccak256("wrong hash"));
        _changed(address(registry));
    }

    function testChangedRuntimeCannotBecomeValidByUpdatingPointerHash() public {
        vm.etch(address(registry), hex"60006000f3");
        core.select(address(registry), address(registry).codehash);
        vm.expectRevert();
        probe.check(ARTIST);
    }

    function _changed(address selected) private {
        vm.expectRevert(
            abi.encodeWithSelector(StreamSaleArtist.ArtistRegistryBindingChanged.selector, selected)
        );
        probe.check(ARTIST);
    }
}
