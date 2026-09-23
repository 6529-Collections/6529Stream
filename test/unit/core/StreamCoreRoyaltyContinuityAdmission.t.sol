// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCorePermanentTarget.t.sol";
import "../../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyEconomicContinuity.sol";

/// @dev Typed continuity producer boundary. Actual import/route proofs have their own suite.
contract RoyaltyContinuityPointerBoundary {
    bytes32 public protectedHash;
    address public source;
    bytes32 public manifest;
    bool public ready = true;
    bool public accepted = true;
    bytes4 public badSelector;
    uint8 public badShape;
    address public expectedCore;

    function configure(address core, bytes32 root, address predecessor, bytes32 manifestHash)
        external
    {
        expectedCore = core;
        protectedHash = root;
        source = predecessor;
        manifest = manifestHash;
    }

    function setReady(bool value) external {
        ready = value;
    }

    function setAccepted(bool value) external {
        accepted = value;
    }

    function malformed(bytes4 selector, uint8 shape) external {
        badSelector = selector;
        badShape = shape;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamRoyaltyResolver).interfaceId || id == type(IERC165).interfaceId;
    }

    function economicContinuityReady() external view returns (bool) {
        _shape();
        return ready;
    }

    function frozenEconomicStateHash(address core) external view returns (bytes32) {
        _shape();
        require(core == expectedCore, "actual Core context");
        return protectedHash;
    }

    function continuitySource() external view returns (address) {
        _shape();
        return source;
    }

    function continuityManifestHash() external view returns (bytes32) {
        _shape();
        return manifest;
    }

    function supportsEconomicContinuity(address predecessor, bytes32 root, bytes32 manifestHash)
        external
        view
        returns (bool)
    {
        _shape();
        return
            accepted && predecessor == source && root == protectedHash && manifestHash == manifest;
    }

    function _shape() private view {
        if (msg.sig != badSelector || badShape == 0) return;
        uint8 shape = badShape;
        address original = source;
        if (shape == 1) revert("continuity source unavailable");
        assembly ("memory-safe") {
            let p := mload(0x40)
            mstore(p, 2)
            mstore(add(p, 32), 0)
            switch shape
            case 2 { return(p, 64) }
            case 3 { return(p, 31) }
            case 5 {
                mstore(p, or(shl(160, 1), original))
                return(p, 32)
            }
            default { return(p, 32) }
        }
    }
}

/// @notice Actual Core pointer updates with typed module/governance/continuity boundaries.
contract StreamCoreRoyaltyContinuityAdmissionTest is CharacterizationTestBase {
    PermanentTargetCoreHarness private target;
    PermanentTargetGovernanceExecutor private authority;
    PermanentTargetModuleRegistry private modules;
    bytes32 private constant ROYALTY = keccak256("ROYALTY_RESOLVER");
    bytes32 private constant REVENUE = keccak256("REVENUE_RESOLVER");
    bytes32 private constant MANIFEST = keccak256("history module manifest");
    bytes32 private constant DEPLOYMENT = keccak256("history deployment manifest");
    bytes32 private constant ROOT = keccak256("protected original routes and elections");
    bytes32 private constant IMPORT = keccak256("completed exact continuity manifest");

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
            "Royalty Core",
            "ROY",
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

    function _pair(bool protectedState)
        private
        returns (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next)
    {
        first = new RoyaltyContinuityPointerBoundary();
        next = new RoyaltyContinuityPointerBoundary();
        first.configure(address(target), protectedState ? ROOT : bytes32(0), address(0), bytes32(0));
        _register(address(first));
        _plan(address(first));
        _execute(address(first));
        next.configure(address(target), protectedState ? ROOT : bytes32(0), address(first), IMPORT);
        _register(address(next));
        _plan(address(next));
    }

    function testUnprotectedReplacementStillRejectsImportInProgressAndRetriesExactly() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(false);
        next.setReady(false);
        _reject(first, next);
        next.setReady(true);
        _execute(address(next));
        require(target.pointerState(ROYALTY).target == address(next));
        require(target.pointerState(ROYALTY).revision == 2);
    }

    function testProtectedReplacementRequiresExactRootSourceManifestAndAcceptance() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(true);
        next.configure(address(target), keccak256("wrong root"), address(first), IMPORT);
        _reject(first, next);
        next.configure(address(target), ROOT, address(0x1234), IMPORT);
        _reject(first, next);
        next.configure(address(target), ROOT, address(first), bytes32(0));
        _reject(first, next);
        next.configure(address(target), ROOT, address(first), IMPORT);
        next.setAccepted(false);
        _reject(first, next);
        next.setAccepted(true);
        _execute(address(next));
        require(target.pointerState(ROYALTY).target == address(next));
    }

    function testCanonicalBooleanAndExactReturnShapesFailClosed() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(true);
        bytes4[2] memory selectors = [
            IStreamRoyaltyEconomicContinuity.economicContinuityReady.selector,
            IStreamRevenueResolverContinuity.supportsEconomicContinuity.selector
        ];
        for (uint256 i; i < selectors.length; ++i) {
            for (uint8 shape = 1; shape <= 4; ++shape) {
                next.malformed(selectors[i], shape);
                _reject(first, next);
            }
        }
        next.malformed(bytes4(0), 0);
        _execute(address(next));
        require(target.pointerState(ROYALTY).revision == 2);
    }

    function testMissingOrMalformedPredecessorCommitmentCannotMeanEmptyState() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(false);
        for (uint8 shape = 1; shape <= 3; ++shape) {
            first.malformed(
                IStreamRevenueResolverContinuity.frozenEconomicStateHash.selector, shape
            );
            _reject(first, next);
        }
        first.malformed(bytes4(0), 0);
        _execute(address(next));
    }

    function testSourceRuntimeDriftRejectsBeforeIdenticalSavedActionRetry() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(true);
        bytes memory saved = address(first).code;
        vm.etch(address(first), hex"60006000fd");
        _reject(first, next);
        vm.etch(address(first), saved);
        _execute(address(next));
        require(target.pointerState(ROYALTY).target == address(next));
    }

    function testNewProtectedSourceStateRequiresCorrespondingCompletedCandidate() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(true);
        bytes32 later = keccak256("later protected snapshot");
        first.configure(address(target), later, address(0), bytes32(0));
        _reject(first, next);
        next.configure(
            address(target), later, address(first), keccak256("updated complete manifest")
        );
        _execute(address(next));
    }

    function testWrongCoreOrMalformedSourceAddressRefusesReplacement() external {
        (RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next) =
            _pair(true);
        next.configure(address(0x1234), ROOT, address(first), IMPORT);
        _reject(first, next);
        next.configure(address(target), ROOT, address(first), IMPORT);
        next.malformed(IStreamRoyaltyEconomicContinuity.continuitySource.selector, 5);
        _reject(first, next);
        next.malformed(bytes4(0), 0);
        _execute(address(next));
    }

    function _reject(RoyaltyContinuityPointerBoundary first, RoyaltyContinuityPointerBoundary next)
        private
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, ROYALTY, address(next)
            )
        );
        _execute(address(next));
        require(target.pointerState(ROYALTY).target == address(first));
        require(target.pointerState(ROYALTY).revision == 1, "failed action cannot advance pointer");
    }

    function _register(address p) private {
        modules.setRecord(
            p, REVENUE, type(IStreamRoyaltyResolver).interfaceId, MANIFEST, DEPLOYMENT
        );
    }

    function _plan(address p) private {
        StreamCorePointerState memory previous = target.pointerState(ROYALTY);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            p,
            p.codehash,
            false,
            REVENUE,
            type(IStreamRoyaltyResolver).interfaceId,
            address(modules),
            1,
            MANIFEST,
            DEPLOYMENT,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) =
            target.pointerTransitionHashes(ROYALTY, previous, candidate);
        authority.setAction(3, scope, oldValue, newValue);
    }

    function _execute(address p) private {
        authority.execute(
            address(target), abi.encodeCall(target.updateSatellitePointer, (ROYALTY, p))
        );
    }
}
