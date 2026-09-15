// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistSaleFacts.sol";

interface IArtistSaleGovernanceContext {
    function executeModuleContext(
        address target,
        bytes calldata data,
        uint8 actionClass,
        bytes32 scope,
        bytes32 oldState,
        bytes32 newState
    ) external;
}

/// @dev Real registry storage with exact target-side governance context; no timelock claim.
abstract contract ArtistSaleRegistryFixture {
    function _saleRegister(
        StreamModuleRegistry registry,
        address authority,
        address module,
        bytes32 role,
        bytes4 capability
    ) internal {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            module,
            role,
            keccak256("6529STREAM_UNIVERSAL_SETTLEMENT_V1"),
            capability,
            0,
            module.codehash,
            keccak256("artist sale fixture deployment"),
            keccak256("artist sale fixture module"),
            "urn:artist-sale-module"
        );
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        bytes32 record = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                module,
                role,
                capability,
                r.moduleVersion,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash
            )
        );
        bytes32 next = keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                block.chainid,
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                chain,
                record,
                count
            )
        );
        bytes32 scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                block.chainid,
                address(registry),
                module
            )
        );
        StreamModuleRegistration memory empty;
        bytes32 oldState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                false,
                _saleRegistrationFacts(empty, 0, 0),
                uint256(count),
                chain,
                count,
                address(0)
            )
        );
        bytes32 newState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scope,
                true,
                _saleRegistrationFacts(r, 1, 1),
                uint256(count) + 1,
                next,
                count + 1,
                module
            )
        );
        IArtistSaleGovernanceContext(authority)
            .executeModuleContext(
                address(registry),
                abi.encodeCall(StreamModuleRegistry.registerModule, (r)),
                1,
                scope,
                oldState,
                newState
            );
    }

    function _saleRegistrationFacts(
        StreamModuleRegistration memory r,
        uint8 status,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                status,
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.expectedRuntimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }

    function _saleStatus(
        StreamModuleRegistry registry,
        address authority,
        address module,
        ModuleRegistryStatus status
    ) internal {
        StreamModuleRecord memory r = registry.moduleRecord(module);
        (bytes32 chain, uint64 count) = registry.registrationChainHash();
        bytes32 scope = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(), block.chainid, address(registry), module
            )
        );
        bytes32 oldState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _saleStoredFacts(r, r.status, r.revision),
                uint256(count),
                chain,
                count
            )
        );
        bytes32 newState = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scope,
                _saleStoredFacts(r, status, r.revision + 1),
                uint256(count),
                chain,
                count
            )
        );
        IArtistSaleGovernanceContext(authority)
            .executeModuleContext(
                address(registry),
                abi.encodeCall(
                    StreamModuleRegistry.setModuleStatus,
                    (module, status, keccak256("test status"), "urn:test-status")
                ),
                uint8(status) > uint8(r.status) ? 0 : 1,
                scope,
                oldState,
                newState
            );
    }

    function _saleStoredFacts(
        StreamModuleRecord memory r,
        ModuleRegistryStatus status,
        uint64 revision
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                r.moduleType,
                r.moduleVersion,
                r.interfaceId,
                r.moduleGasLimit,
                r.runtimeCodeHash,
                r.deploymentManifestHash,
                r.moduleManifestHash,
                keccak256(bytes(r.moduleManifestURI)),
                revision
            )
        );
    }
}

/// @dev Deliberately malformed registered module for bounded-reader negative tests only.
contract ArtistSaleFactsAdversary {
    address public core;
    uint256 private mode;
    bytes32 private config;

    constructor(address core_, bytes32 config_) {
        core = core_;
        config = config_;
    }

    function setMode(uint256 mode_) external {
        mode = mode_;
    }

    function setCore(address core_) external {
        core = core_;
    }

    function streamModuleType() external pure returns (bytes32) {
        return keccak256("ARTIST_SALE_FACTS_TEST_BOUNDARY");
    }

    function streamModuleInterfaceId() external pure returns (bytes4) {
        return type(IStreamArtistSaleFacts).interfaceId;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistSaleFacts).interfaceId || id == type(IERC165).interfaceId;
    }

    function saleConsentFacts(bytes32) external view returns (uint256, bytes32) {
        uint256 mode_ = mode;
        if (mode_ == 1) revert("provider failure");
        if (mode_ == 2) assembly ("memory-safe") {
            mstore(0, 1)
            return(0, 32)
        }
        if (mode_ == 3) assembly ("memory-safe") {
            mstore(0, 1)
            return(0, 96)
        }
        if (mode_ == 4) assembly ("memory-safe") { for { } 1 { } { } }
        return (1, config);
    }
}
