// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCorePermanentTarget.t.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistHistory.sol";

/// @dev Typed successor-read boundary; the companion Artist suite exercises the real producer.
contract ArtistHistoryPointerBoundary {
    address public predecessor;
    bytes32 public code;
    uint256 public count;
    uint8 public shape;

    function configure(address p, bytes32 c, uint256 n, uint8 s) external {
        predecessor = p;
        code = c;
        count = n;
        shape = s;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistMintConsent).interfaceId || id == type(IERC165).interfaceId;
    }

    function artistHistoryPredecessorBinding(address p)
        external
        view
        returns (bool, bytes32, uint256)
    {
        if (shape == 1) revert("missing history provider");
        if (shape == 2) {
            assembly ("memory-safe") {
                let q := mload(0x40)
                mstore(q, 1)
                mstore(add(q, 32), 0)
                mstore(add(q, 64), 1)
                mstore(add(q, 96), 0)
                return(q, 128)
            }
        }
        return (p == predecessor && count != 0, code, count);
    }
}

/// @notice Actual Core update/Executor context; Artist marker, module catalog and governance are typed boundaries.
contract StreamCoreArtistHistoryAdmissionTest is CharacterizationTestBase {
    PermanentTargetCoreHarness private target;
    PermanentTargetGovernanceExecutor private authority;
    PermanentTargetModuleRegistry private modules;
    bytes32 private constant ARTIST = keccak256("ARTIST_REGISTRY");
    bytes32 private constant MANIFEST = keccak256("history module manifest");
    bytes32 private constant DEPLOYMENT = keccak256("history deployment manifest");

    function setUp() public {
        authority = new PermanentTargetGovernanceExecutor();
        modules = new PermanentTargetModuleRegistry();
        modules.setGovernanceExecutor(address(authority));
        StreamCore.GasParameterGenesisConfig[] memory gasConfigs =
            new StreamCore.GasParameterGenesisConfig[](4);
        gasConfigs[0] = StreamCore.GasParameterGenesisConfig(
            0x9bae92ab1dd0c5535c65125ea4ee7cff3d55fc31fc2555096c2b5eabceb5bcda, 50000, 25000, 1
        );
        gasConfigs[1] = StreamCore.GasParameterGenesisConfig(
            0x0af6f5a1a5059e398191fa0af185be12fee6d609933826603244c7f247793be7, 2910000, 1460000, 1
        );
        gasConfigs[2] = StreamCore.GasParameterGenesisConfig(
            0x02ad62929eaa837b9d1704745193125454925fd11a6bf273d7bb1faa23272e93, 500000, 250000, 1
        );
        gasConfigs[3] = StreamCore.GasParameterGenesisConfig(
            0x51125071e3dfb233a2711689d4cc377bbda429f1356ebc09a58d763548541e17, 120000, 120000, 2
        );
        target = new PermanentTargetCoreHarness(
            "History Core",
            "HIST",
            address(authority),
            StreamCore.GenesisModuleRegistryConfig(
                address(modules), address(modules).codehash, MANIFEST, DEPLOYMENT
            ),
            gasConfigs
        );
        modules.setRecord(
            address(modules),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId,
            MANIFEST,
            DEPLOYMENT
        );
    }

    function testCoreHistoryInitialInstallUnchangedAndSavedReplacementRetriesExactly() external {
        ArtistHistoryPointerBoundary first = new ArtistHistoryPointerBoundary();
        ArtistHistoryPointerBoundary next = new ArtistHistoryPointerBoundary();
        _register(address(first));
        _plan(address(first));
        _execute(address(first));
        require(
            target.pointerState(ARTIST).target == address(first),
            "initial installation needs no predecessor"
        );
        _register(address(next));
        _plan(address(next));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ARTIST, address(next)
            )
        );
        _execute(address(next));
        require(
            target.pointerState(ARTIST).target == address(first)
                && target.pointerState(ARTIST).revision == 1,
            "failed replacement leaves original pointer"
        );
        next.configure(address(first), address(first).codehash, 1, 0);
        _execute(address(next));
        require(
            target.pointerState(ARTIST).target == address(next)
                && target.pointerState(ARTIST).revision == 2,
            "same saved action succeeds only after exact predecessor commitment"
        );
        _plan(address(next));
        vm.expectRevert(abi.encodeWithSelector(StreamCore.SatellitePointerNoOp.selector, ARTIST));
        _execute(address(next));
    }

    function testCoreHistoryRejectsForeignCodeAndMalformedAdvertisedRead() external {
        ArtistHistoryPointerBoundary first = new ArtistHistoryPointerBoundary();
        ArtistHistoryPointerBoundary next = new ArtistHistoryPointerBoundary();
        _register(address(first));
        _plan(address(first));
        _execute(address(first));
        _register(address(next));
        _plan(address(next));
        next.configure(address(first), keccak256("wrong predecessor runtime"), 1, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ARTIST, address(next)
            )
        );
        _execute(address(next));
        next.configure(address(first), address(first).codehash, 1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ARTIST, address(next)
            )
        );
        _execute(address(next));
        next.configure(address(first), address(first).codehash, 1, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ARTIST, address(next)
            )
        );
        _execute(address(next));
        next.configure(address(first), address(first).codehash, 1, 0);
        _execute(address(next));
        require(target.pointerState(ARTIST).target == address(next), "healthy exact-return retry");
    }

    function _register(address p) private {
        modules.setRecord(
            p, ARTIST, type(IStreamArtistMintConsent).interfaceId, MANIFEST, DEPLOYMENT
        );
    }

    function _plan(address p) private {
        StreamCorePointerState memory previous = target.pointerState(ARTIST);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            p,
            p.codehash,
            false,
            ARTIST,
            type(IStreamArtistMintConsent).interfaceId,
            address(modules),
            1,
            MANIFEST,
            DEPLOYMENT,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) =
            target.pointerTransitionHashes(ARTIST, previous, candidate);
        authority.setAction(3, scope, oldValue, newValue);
    }

    function _execute(address p) private {
        authority.execute(
            address(target), abi.encodeCall(target.updateSatellitePointer, (ARTIST, p))
        );
    }
}
