// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCorePermanentTarget.t.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintReads.sol";
import "../../../smart-contracts/interfaces/stream/mint/IStreamMintLedgerImport.sol";

/// @dev Typed Manager/Ledger boundaries; the Core under test is the actual production contract.
contract MintContinuityPointerBoundary {
    address private _core;
    address private _ledger;
    address private _predecessorLedger;
    address private _predecessor;
    address private _successor;
    bool private _complete;
    bytes4 public badSelector;
    uint8 public badShape;

    function configureManager(address core_, address ledger_) external {
        _core = core_;
        _ledger = ledger_;
    }

    function configureMigration(
        address ledger_,
        address predecessor_,
        address successor_,
        bool ready
    ) external {
        _predecessorLedger = ledger_;
        _predecessor = predecessor_;
        _successor = successor_;
        _complete = ready;
    }

    function malformed(bytes4 selector, uint8 shape) external {
        badSelector = selector;
        badShape = shape;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamMintManager).interfaceId
            || id == type(IStreamMintLedger).interfaceId || id == type(IERC165).interfaceId;
    }

    function core() external view returns (address) {
        _shape(_core);
        return _core;
    }

    function mintLedger() external view returns (address) {
        _shape(_ledger);
        return _ledger;
    }

    function isMintSuccessorReady(address ledger_, address predecessor_, address successor_)
        external
        view
        returns (bool)
    {
        _shape(address(0));
        return _complete && ledger_ == _predecessorLedger && predecessor_ == _predecessor
            && successor_ == _successor;
    }

    function _shape(address original) private view {
        if (msg.sig != badSelector || badShape == 0) return;
        uint8 shape = badShape;
        if (shape == 1) revert("unavailable continuity source");
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

/// @notice Actual Core governance/pointer invariants; producer and governance replies are typed fixtures.
contract StreamCoreMintContinuityAdmissionTest is CharacterizationTestBase {
    PermanentTargetCoreHarness private target;
    PermanentTargetGovernanceExecutor private authority;
    PermanentTargetModuleRegistry private modules;
    bytes32 private constant MANAGER = keccak256("MINT_MANAGER");
    bytes32 private constant MANIFEST = keccak256("history module manifest");
    bytes32 private constant DEPLOYMENT = keccak256("history deployment manifest");
    MintContinuityPointerBoundary private first;
    MintContinuityPointerBoundary private next;
    MintContinuityPointerBoundary private oldLedger;
    MintContinuityPointerBoundary private newLedger;

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
            "Mint Core",
            "MINT",
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

    function _pair(bool sameLedger) private {
        first = new MintContinuityPointerBoundary();
        next = new MintContinuityPointerBoundary();
        oldLedger = new MintContinuityPointerBoundary();
        newLedger = sameLedger ? oldLedger : new MintContinuityPointerBoundary();
        first.configureManager(address(target), address(oldLedger));
        next.configureManager(address(target), address(newLedger));
        _register(address(first));
        _plan(address(first));
        _execute(address(first));
        modules.setRecord(
            address(newLedger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId,
            MANIFEST,
            DEPLOYMENT
        );
        _register(address(next));
        _plan(address(next));
        _ready(false);
    }

    function _ready(bool ready) private {
        newLedger.configureMigration(address(oldLedger), address(first), address(next), ready);
    }

    function testNewLedgerRequiresCompletedImportAndRetriesSavedAction() external {
        _pair(false);
        _reject();
        _ready(true);
        _execute(address(next));
        require(target.pointerState(MANAGER).target == address(next));
        require(target.pointerState(MANAGER).revision == 2);
    }

    function testSameLedgerStillRequiresExactManagerMigration() external {
        _pair(true);
        _reject();
        _ready(true);
        _execute(address(next));
        require(target.pointerState(MANAGER).target == address(next));
    }

    function testWrongPredecessorLedgerOrManagerOrSuccessorCannotSatisfyGuard() external {
        _pair(false);
        newLedger.configureMigration(address(newLedger), address(first), address(next), true);
        _reject();
        newLedger.configureMigration(address(oldLedger), address(next), address(next), true);
        _reject();
        newLedger.configureMigration(address(oldLedger), address(first), address(first), true);
        _reject();
        _ready(true);
        _execute(address(next));
    }

    function testUnavailableShortOversizedDirtyManagerRepliesFailClosed() external {
        _pair(false);
        _ready(true);
        bytes4[2] memory selectors =
            [IStreamMintReads.core.selector, IStreamMintReads.mintLedger.selector];
        MintContinuityPointerBoundary[2] memory managers = [first, next];
        for (uint256 m; m < managers.length; ++m) {
            for (uint256 i; i < selectors.length; ++i) {
                for (uint8 shape = 1; shape <= 5; ++shape) {
                    managers[m].malformed(selectors[i], shape);
                    _reject();
                }
                managers[m].malformed(bytes4(0), 0);
            }
        }
        _execute(address(next));
    }

    function testReadinessRequiresExactCanonicalTrueWord() external {
        _pair(false);
        _ready(true);
        for (uint8 shape = 1; shape <= 4; ++shape) {
            newLedger.malformed(IStreamMintLedgerImport.isMintSuccessorReady.selector, shape);
            _reject();
        }
        newLedger.malformed(bytes4(0), 0);
        _execute(address(next));
    }

    function testForeignCoreAndMissingOrDelegatedLedgerRejected() external {
        _pair(false);
        _ready(true);
        first.configureManager(address(0x1234), address(oldLedger));
        _reject();
        first.configureManager(address(target), address(oldLedger));
        next.configureManager(address(0x1234), address(newLedger));
        _reject();
        next.configureManager(address(target), address(0x1234));
        _reject();
        next.configureManager(address(target), address(newLedger));
        bytes memory saved = address(newLedger).code;
        vm.etch(address(newLedger), abi.encodePacked(hex"ef0100", address(first)));
        _reject();
        vm.etch(address(newLedger), saved);
        _execute(address(next));
    }

    function testUnadmittedOrRuntimeDriftedCandidateLedgerCannotAssertReadiness() external {
        _pair(false);
        _ready(true);
        modules.setStatus(address(newLedger), ModuleRegistryStatus.DEPRECATED);
        _reject();
        modules.setStatus(address(newLedger), ModuleRegistryStatus.ACTIVE);
        modules.setRuntimeCodeHash(address(newLedger), keccak256("wrong catalog runtime"));
        _reject();
        modules.setRuntimeCodeHash(address(newLedger), address(newLedger).codehash);
        _execute(address(next));
    }

    function testPredecessorRuntimeDriftPreservesPointerAndRetry() external {
        _pair(false);
        _ready(true);
        bytes memory saved = address(first).code;
        vm.etch(address(first), hex"60006000fd");
        _reject();
        vm.etch(address(first), saved);
        _execute(address(next));
        require(target.pointerState(MANAGER).revision == 2);
    }

    function _reject() private {
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamCore.InvalidSatellitePointer.selector, MANAGER, address(next)
            )
        );
        _execute(address(next));
        require(target.pointerState(MANAGER).target == address(first));
        require(target.pointerState(MANAGER).revision == 1, "failed action changed pointer");
    }

    function _register(address p) private {
        modules.setRecord(p, MANAGER, type(IStreamMintManager).interfaceId, MANIFEST, DEPLOYMENT);
    }

    function _plan(address p) private {
        StreamCorePointerState memory previous = target.pointerState(MANAGER);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            p,
            p.codehash,
            false,
            MANAGER,
            type(IStreamMintManager).interfaceId,
            address(modules),
            1,
            MANIFEST,
            DEPLOYMENT,
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldValue, bytes32 newValue) =
            target.pointerTransitionHashes(MANAGER, previous, candidate);
        authority.setAction(3, scope, oldValue, newValue);
    }

    function _execute(address p) private {
        authority.execute(
            address(target), abi.encodeCall(target.updateSatellitePointer, (MANAGER, p))
        );
    }
}
