// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../smart-contracts/core/StreamCoreExternalReads.sol";
import "../smart-contracts/domains/mint/StreamMintManager.sol";
import "../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../smart-contracts/domains/mint/StreamMintModuleRegistry.sol";
import "../smart-contracts/interfaces/stream/IStreamModuleRegistry.sol";

/// @dev Supplies only the constructor's ERC-721 dependency probe. No mint is simulated.
contract MintPointerCoreProbeFixture is ERC165 {
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == 0x80ac58cd || super.supportsInterface(interfaceId);
    }
}

/// @dev Supplies well-formed ACTIVE records to the exact production Core validator.
contract MintPointerRegistryFixture is ERC165 {
    mapping(address => StreamModuleRecord) private _records;

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IStreamModuleRegistry).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function moduleRecord(address module) external view returns (StreamModuleRecord memory) {
        return _records[module];
    }

    function register(address module, bytes32 moduleType, bytes4 interfaceId) external {
        _records[module] = StreamModuleRecord({
            status: ModuleRegistryStatus.ACTIVE,
            moduleType: moduleType,
            moduleVersion: keccak256("mint-pointer-test-v1"),
            interfaceId: interfaceId,
            moduleGasLimit: 100_000,
            runtimeCodeHash: module.codehash,
            deploymentManifestHash: keccak256("deployment-manifest"),
            moduleManifestHash: keccak256("module-manifest"),
            moduleManifestURI: "ipfs://mint-pointer-test",
            registeredAt: 1,
            statusUpdatedAt: 1,
            revision: 1
        });
    }
}

contract StreamMintPointerCompatibilityTest {
    bytes32 private constant MANAGER_POINTER =
        0x136326f089f522351128a5fb79275bd12b2d84fe5bb50d5e46c9f5508d6df7e2;
    bytes32 private constant LEDGER_POINTER =
        0xe5dd56591e517e4085238d3b93e69c570fcfba756eed59ca2c4e234606e661cd;

    StreamMintManager private _manager;
    StreamMintLedger private _ledger;
    MintPointerRegistryFixture private _registry;

    function setUp() public {
        _ledger = new StreamMintLedger();
        _manager = new StreamMintManager(
            IStreamCore(address(new MintPointerCoreProbeFixture())),
            _ledger,
            new StreamMintModuleRegistry()
        );
        _registry = new MintPointerRegistryFixture();
    }

    function testActualManagerPassesCorePointerValidation() public {
        _assertEligible(address(_manager), MANAGER_POINTER);
    }

    function testActualLedgerPassesCorePointerValidation() public {
        _assertEligible(address(_ledger), LEDGER_POINTER);
    }

    function testMintSatellitesRejectInvalidAndUnrelatedInterfaces() public view {
        require(_manager.supportsInterface(type(IERC165).interfaceId), "manager ERC165");
        require(_ledger.supportsInterface(type(IERC165).interfaceId), "ledger ERC165");
        require(!_manager.supportsInterface(0xffffffff), "manager invalid interface");
        require(!_ledger.supportsInterface(0xffffffff), "ledger invalid interface");
        require(!_manager.supportsInterface(0xdeadbeef), "manager unknown interface");
        require(!_ledger.supportsInterface(0xdeadbeef), "ledger unknown interface");
        require(
            !_manager.supportsInterface(type(IStreamMintLedger).interfaceId),
            "manager is not ledger"
        );
        require(
            !_ledger.supportsInterface(type(IStreamMintManager).interfaceId),
            "ledger is not manager"
        );
    }

    function _assertEligible(address module, bytes32 pointerType) private {
        (bool known, bytes32 moduleType, bytes4 interfaceId) =
            StreamCoreExternalReads.pointerConfiguration(pointerType, module, address(1));
        require(known && interfaceId != bytes4(0), "known production pointer");
        _registry.register(module, moduleType, interfaceId);
        (bool registryValid, StreamCorePointerState memory registryPointer) = StreamCoreExternalReads.genesisModuleRegistry(
            address(_registry),
            address(_registry).codehash,
            keccak256("module-manifest"),
            keccak256("deployment-manifest")
        );
        require(registryValid, "valid genesis registry");

        (StreamCoreValidationStatus status, StreamCorePointerState memory candidate) = StreamCoreExternalReads.eligiblePointer(
            registryPointer, module, moduleType, interfaceId
        );
        require(status == StreamCoreValidationStatus.VALID, "actual module must be eligible");
        require(candidate.target == module && candidate.codeHash == module.codehash, "target pin");
        require(candidate.interfaceId == interfaceId, "interface pin");
        require(candidate.registryStatus == uint8(ModuleRegistryStatus.ACTIVE), "ACTIVE record");
    }
}
