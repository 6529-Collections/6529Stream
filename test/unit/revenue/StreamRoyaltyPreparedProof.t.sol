// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamRoyaltyPreparedProof as P
} from "../../../smart-contracts/domains/revenue/StreamRoyaltyPreparedProof.sol";
import {
    StreamModuleRecord,
    ModuleRegistryStatus,
    IStreamModuleRegistry
} from "../../../smart-contracts/interfaces/stream/modules/IStreamModuleRegistry.sol";
import {
    IStreamMintManager
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamMintLedger
} from "../../../smart-contracts/interfaces/stream/mint/IStreamMintLedger.sol";
import {
    IStreamRoyaltyResolver
} from "../../../smart-contracts/interfaces/stream/revenue/IStreamRoyaltyResolver.sol";
import {
    StreamPreparedMintRecord
} from "../../../smart-contracts/interfaces/stream/core/StreamCoreTypes.sol";

interface RoyaltyProofVM {
    function warp(uint256) external;
    function prank(address) external;
}

/// @dev Typed infrastructure boundaries for the isolated proof library only. Real producer
/// deployment/eligibility and whole mint snapshot behavior require the later integration cohort.
contract RoyaltyProofCoreFixture {
    mapping(bytes32 => P.Pointer) private pointers;
    StreamPreparedMintRecord private prepared;
    uint256 private pending;
    bool public identityExists = true;
    uint256 public identityCollection = 1;
    uint256 public identitySerial = 7;
    bool public identityBurned;

    function setPointer(bytes32 key, P.Pointer memory p) external {
        pointers[key] = p;
    }

    function getSatellitePointer(bytes32 key) external view returns (P.Pointer memory) {
        return pointers[key];
    }

    function setPrepared(bool exists, bytes32 operation, uint256 collection, uint256 token)
        external
    {
        prepared = StreamPreparedMintRecord(exists, operation, collection);
        pending = token;
    }

    function preparedMint(uint256) external view returns (StreamPreparedMintRecord memory) {
        return prepared;
    }

    function pendingPreparedMintTokenId() external view returns (uint256) {
        return pending;
    }

    function setIdentity(bool exists, uint256 collection, uint256 serial, bool burned) external {
        identityExists = exists;
        identityCollection = collection;
        identitySerial = serial;
        identityBurned = burned;
    }

    function tokenCollectionIdentity(uint256) external view returns (bool, uint256, uint256, bool) {
        return (identityExists, identityCollection, identitySerial, identityBurned);
    }
}

contract RoyaltyProofRegistryFixture {
    mapping(address => StreamModuleRecord) private records;

    function register(address target, bytes32 role, bytes4 id) external {
        records[target] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            role,
            keccak256("version"),
            id,
            100000,
            target.codehash,
            keccak256("deployment"),
            keccak256("module"),
            "",
            1,
            1,
            1
        );
    }

    function setStatus(address target, ModuleRegistryStatus status) external {
        records[target].status = status;
    }

    function setManifest(address target, bytes32 hash) external {
        records[target].moduleManifestHash = hash;
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return records[target];
    }

    function isModuleEligible(address target, bytes32 role, bytes4 id)
        external
        view
        returns (bool)
    {
        StreamModuleRecord storage r = records[target];
        return r.status == ModuleRegistryStatus.ACTIVE && r.moduleType == role
            && r.interfaceId == id && r.runtimeCodeHash == target.codehash;
    }
}

contract RoyaltyProofLedgerFixture {
    bool public writer = true;
    mapping(address => mapping(bytes32 => bool)) public isManagerOperationRootUsed;

    function setRoot(address manager, bytes32 root, bool value) external {
        isManagerOperationRootUsed[manager][root] = value;
    }

    function setWriter(bool value) external {
        writer = value;
    }

    function ledgerWriter(address) external view returns (bool) {
        return writer;
    }
}

contract RoyaltyProofManagerFixture {
    address public core;
    address public moduleRegistry;
    address public mintLedger;

    constructor(address c, address r, address l) {
        core = c;
        moduleRegistry = r;
        mintLedger = l;
    }

    function callProof(address target, P.Request memory request)
        external
        view
        returns (bool ok, bytes memory raw)
    {
        return target.staticcall(abi.encodeCall(RoyaltyProofHostFixture.proof, (request)));
    }
}

contract RoyaltyProofHostFixture {
    function proof(P.Request memory request) external view returns (bytes32) {
        return P.requireCurrent(request);
    }
}

contract StreamRoyaltyPreparedProofTest {
    RoyaltyProofVM private constant vm =
        RoyaltyProofVM(address(uint160(uint256(keccak256("hevm cheat code")))));
    RoyaltyProofCoreFixture private core;
    RoyaltyProofRegistryFixture private registry;
    RoyaltyProofLedgerFixture private ledger;
    RoyaltyProofManagerFixture private manager;
    RoyaltyProofHostFixture private host;
    P.Request private request;

    function setUp() public {
        vm.warp(1000);
        core = new RoyaltyProofCoreFixture();
        registry = new RoyaltyProofRegistryFixture();
        ledger = new RoyaltyProofLedgerFixture();
        manager = new RoyaltyProofManagerFixture(address(core), address(registry), address(ledger));
        host = new RoyaltyProofHostFixture();
        _install(
            "MODULE_REGISTRY",
            address(registry),
            keccak256("MODULE_REGISTRY"),
            type(IStreamModuleRegistry).interfaceId
        );
        _install(
            "MINT_MANAGER",
            address(manager),
            keccak256("MINT_MANAGER"),
            type(IStreamMintManager).interfaceId
        );
        _install(
            "MINT_LEDGER",
            address(ledger),
            keccak256("MINT_LEDGER"),
            type(IStreamMintLedger).interfaceId
        );
        _install(
            "ROYALTY_RESOLVER",
            address(host),
            keccak256("REVENUE_RESOLVER"),
            type(IStreamRoyaltyResolver).interfaceId
        );
        request = P.Request(
            address(core), address(core).codehash, 1, 77, keccak256("root"), keccak256("operation")
        );
        ledger.setRoot(address(manager), request.operationRoot, true);
        core.setPrepared(true, request.operationId, 1, 77);
    }

    function _install(string memory key, address target, bytes32 role, bytes4 id) private {
        registry.register(target, role, id);
        core.setPointer(
            keccak256(bytes(key)),
            P.Pointer(
                target,
                target.codehash,
                false,
                role,
                id,
                address(registry),
                1,
                keccak256("module"),
                keccak256("deployment"),
                1
            )
        );
    }

    function testCompleteTypedProofIsReadOnlyAndBindsActualCallerAndResolverHost() public {
        (bool ok, bytes memory raw) = manager.callProof(address(host), request);
        require(
            ok && raw.length == 32 && abi.decode(raw, (bytes32)) != 0, "complete prepared proof"
        );
        (, bytes memory again) = manager.callProof(address(host), request);
        require(keccak256(raw) == keccak256(again), "identical read has no state effect");
        (ok,) = address(host).staticcall(abi.encodeCall(host.proof, (request)));
        require(!ok, "arbitrary caller is not current selected Manager");
        RoyaltyProofHostFixture other = new RoyaltyProofHostFixture();
        (ok,) = manager.callProof(address(other), request);
        require(!ok, "another same-implementation host is not selected Resolver");
    }

    function testCurrentPreparedRecordCannotBeReplacedByUsedRootOrRetainedTokenIdentity() public {
        core.setPrepared(false, 0, 0, 0);
        _fails("completion clears original proof even while token identity and used root remain");
        core.setPrepared(true, keccak256("other operation"), 1, 77);
        _fails("another operation cannot borrow used root");
        core.setPrepared(true, request.operationId, 2, 77);
        _fails("prepared collection mismatch");
        core.setPrepared(true, request.operationId, 1, 78);
        _fails("only current pending token qualifies");
        core.setPrepared(true, request.operationId, 1, 77);
        (bool ok,) = manager.callProof(address(host), request);
        require(ok, "original proof restored");
    }

    function testCurrentRegistryAndOriginalCoreCommitmentsAreBothRequired() public {
        registry.setStatus(address(manager), ModuleRegistryStatus.INCIDENT_REVOKED);
        _fails("stored ACTIVE Core pointer cannot hide current incident");
        registry.setStatus(address(manager), ModuleRegistryStatus.ACTIVE);
        registry.setManifest(address(host), keccak256("substitute manifest"));
        _fails("current eligibility alone cannot replace original manifest");
        registry.setManifest(address(host), keccak256("module"));
        P.Request memory bad = request;
        bad.coreRuntimeHash = keccak256("wrong runtime");
        (bool ok,) = manager.callProof(address(host), bad);
        require(!ok, "bound Core runtime required");
        (ok,) = manager.callProof(address(host), request);
        require(ok, "original current graph restored");
    }

    function testLedgerProofIsManagerScopedAndRevokedWriterCannotSnapshot() public {
        ledger.setRoot(address(manager), request.operationRoot, false);
        ledger.setRoot(address(this), request.operationRoot, true);
        _fails("root consumed by another Manager is not this operation");
        ledger.setRoot(address(manager), request.operationRoot, true);
        ledger.setWriter(false);
        _fails("current writer authorization retained");
        ledger.setWriter(true);
        core.setIdentity(true, 2, 7, false);
        _fails("original token collection required");
        core.setIdentity(true, 1, 0, false);
        _fails("native collection serial is nonzero");
        core.setIdentity(true, 1, 7, true);
        _fails("burned token cannot be prepared snapshot");
    }

    function _fails(string memory why) private view {
        (bool ok,) = manager.callProof(address(host), request);
        require(!ok, why);
    }
}
