// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamGasParameterHost
} from "../../../smart-contracts/domains/parameters/StreamGasParameterHost.sol";
import {
    StreamMetadataRouter
} from "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    IStreamGasParameterHost as G
} from "../../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import {
    IStreamArtistAttribution
} from "../../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    PresentationCoreBoundary,
    PresentationArtistBoundary
} from "./StreamMetadataServing.t.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

contract DisplayGasExecutorBoundary {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    uint8 public mode;

    function setMode(uint8 m) external {
        mode = m;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        if (mode == 2) {
            assembly ("memory-safe") {
                mstore(0, 2)
                return(0, 192)
            }
        }
        return (
            active,
            active ? bytes32(uint256(1)) : bytes32(0),
            mode == 1 ? uint8(2) : uint8(1),
            scope,
            oldHash,
            newHash
        );
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n) external {
        active = true;
        scope = s;
        oldHash = o;
        newHash = n;
        (bool ok, bytes memory result) = target.call(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        active = false;
        scope = 0;
        oldHash = 0;
        newHash = 0;
    }
}

contract DisplayCanonicalGasHost is StreamGasParameterHost {
    constructor(address authority) StreamGasParameterHost(authority) {
        _registerGasParameter(
            GasParameterConfig("ROUTER_LIVE_ATTRIBUTION_GAS", 8000000, 8000000, 1)
        );
        _registerGasParameter(
            GasParameterConfig("ROUTER_LIVE_ATTRIBUTION_READ_GAS", 250000, 250000, 1)
        );
        _registerGasParameter(
            GasParameterConfig("ROUTER_LIVE_ATTRIBUTION_MEMBERSHIP_GAS", 2000000, 2000000, 1)
        );
        _registerGasParameter(
            GasParameterConfig("ROUTER_LIVE_ATTRIBUTION_RETURN_GAS", 2000000, 2000000, 3)
        );
        _registerGasParameter(GasParameterConfig("ROUTER_BUNDLE_READ_GAS", 2000000, 2000000, 2));
        _registerGasParameter(GasParameterConfig("ROUTER_BUNDLE_RENDER_GAS", 8000000, 8000000, 2));
        _registerGasParameter(GasParameterConfig("ROUTER_FULL_VIEW_GAS", 60000000, 60000000, 2));
    }
}

/// @notice Namespaced Router adapter compared with the shared GGP host under identical V2 controls.
contract StreamDisplayGasParametersTest is CharacterizationTestBase {
    StreamMetadataRouter private router;
    DisplayCanonicalGasHost private referenceHost;
    DisplayGasExecutorBoundary private executor;

    function setUp() public {
        executor = new DisplayGasExecutorBoundary();
        PresentationCoreBoundary core = new PresentationCoreBoundary();
        PresentationArtistBoundary artist = new PresentationArtistBoundary(address(core));
        router = new StreamMetadataRouter(
            address(core),
            address(executor),
            keccak256("deployment"),
            "urn:router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        referenceHost = new DisplayCanonicalGasHost(address(executor));
    }

    function _transition(address host, bytes32 id, uint256 next)
        private
        view
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        (uint256 amount, uint256 floor, uint8 failure, uint64 revision) =
            G(host).gasParameterInfo(id);
        scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                host,
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        oldHash = keccak256(abi.encode(domain, scope, amount, floor, failure, revision));
        newHash = keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
    }

    function _raise(address host, bytes32 id, uint256 next) private {
        (bytes32 s, bytes32 o, bytes32 n) = _transition(host, id, next);
        executor.execute(host, abi.encodeCall(G.raiseGasParameter, (id, next)), s, o, n);
    }

    function raiseChecked(address host, bytes32 id, uint256 next) external {
        require(msg.sender == address(this), "self only");
        _raise(host, id, next);
    }

    function testRouterInventoryAndTransitionMatchCanonicalHost() public view {
        bytes32[] memory ids = router.gasParameterIds();
        require(
            ids.length == 7
                && keccak256(abi.encode(ids))
                    == keccak256(abi.encode(referenceHost.gasParameterIds()))
        );
        for (uint256 i; i < ids.length; ++i) {
            (uint256 value, uint256 floor, uint8 failure, uint64 revision) =
                router.gasParameterInfo(ids[i]);
            (uint256 v, uint256 f, uint8 c, uint64 r) = referenceHost.gasParameterInfo(ids[i]);
            require(value == v && floor == f && failure == c && revision == r);
            (bytes32 s, bytes32 o, bytes32 n) = _transition(address(router), ids[i], value * 2);
            (bytes32 actualS, bytes32 actualO, bytes32 actualN) =
                router.gasParameterTransition(ids[i], value * 2);
            require(s == actualS && o == actualO && n == actualN);
        }
        require(
            router.governanceAuthority() == address(executor)
                && router.LIVE_ATTRIBUTION_GAS() == 8000000
        );
    }

    function testExactTwoTimesRaiseAndReplayMatchCanonicalHost() public {
        bytes32 id = router.gasParameterIds()[0];
        this.raiseChecked(address(router), id, 16000000);
        this.raiseChecked(address(referenceHost), id, 16000000);
        require(
            router.LIVE_ATTRIBUTION_GAS() == 16000000
                && router.gasParameter(id) == referenceHost.gasParameter(id)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterActionAlreadyApplied.selector, id, bytes32(uint256(1))
            )
        );
        this.raiseChecked(address(router), id, 32000000);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterActionAlreadyApplied.selector, id, bytes32(uint256(1))
            )
        );
        this.raiseChecked(address(referenceHost), id, 32000000);
    }

    function testAuthorityRangeAndClassErrorsMatchCanonicalHost() public {
        bytes32 id = router.gasParameterIds()[1];
        vm.expectRevert(abi.encodeWithSelector(G.GasParameterNotAuthority.selector, address(this)));
        router.raiseGasParameter(id, 500000);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterNotARaise.selector, id, uint256(250000), uint256(250000)
            )
        );
        this.raiseChecked(address(router), id, 250000);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterNotARaise.selector, id, uint256(250000), uint256(250000)
            )
        );
        this.raiseChecked(address(referenceHost), id, 250000);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterRaiseBoundExceeded.selector, id, uint256(250000), uint256(500001)
            )
        );
        this.raiseChecked(address(router), id, 500001);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterRaiseBoundExceeded.selector, id, uint256(250000), uint256(500001)
            )
        );
        this.raiseChecked(address(referenceHost), id, 500001);
        executor.setMode(1);
        vm.expectRevert(
            abi.encodeWithSelector(G.GasParameterActionClassMismatch.selector, uint8(1), uint8(2))
        );
        this.raiseChecked(address(router), id, 500000);
        vm.expectRevert(
            abi.encodeWithSelector(G.GasParameterActionClassMismatch.selector, uint8(1), uint8(2))
        );
        this.raiseChecked(address(referenceHost), id, 500000);
    }

    function testMalformedAndWrongCommitmentContextsCannotRaise() public {
        bytes32 id = router.gasParameterIds()[2];
        (bytes32 s, bytes32 o, bytes32 n) = _transition(address(router), id, 4000000);
        vm.expectRevert(
            abi.encodeWithSelector(
                G.GasParameterNewStateHashMismatch.selector, n, bytes32(uint256(77))
            )
        );
        executor.execute(
            address(router),
            abi.encodeCall(G.raiseGasParameter, (id, 4000000)),
            s,
            o,
            bytes32(uint256(77))
        );
        executor.setMode(2);
        vm.expectRevert(abi.encodeWithSelector(G.GasParameterActionContextInvalid.selector));
        this.raiseChecked(address(router), id, 4000000);
        vm.expectRevert(abi.encodeWithSelector(G.GasParameterActionContextInvalid.selector));
        this.raiseChecked(address(referenceHost), id, 4000000);
        require(router.gasParameter(id) == 2000000);
    }
}
