// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    IStreamArtistRecoveryDeployment
} from "../../interfaces/stream/artist/IStreamArtistRecoveryDeployment.sol";
import {
    IStreamArtistIngressBinding
} from "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import { IStreamArtistOwner } from "../../interfaces/stream/artist/IStreamArtistOwner.sol";
import {
    IStreamArtistMintConsent
} from "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import {
    IStreamFinalityDeploymentBindings
} from "../../interfaces/stream/finality/IStreamFinalityDeploymentBindings.sol";
import {
    IStreamFinalityGovernanceBindings
} from "../../interfaces/stream/finality/IStreamFinalityGovernanceBindings.sol";
import {
    IStreamFinalityRecoveryCore
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryCore.sol";
import {
    IStreamFinalityRecoveryOwnerEvidence
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryOwnerEvidence.sol";
import {
    IStreamFinalityRecoveryOwnerBindings
} from "../../interfaces/stream/finality/IStreamFinalityRecoveryOwnerBindings.sol";
import { IStreamCorePointers } from "../../interfaces/stream/core/IStreamCorePointers.sol";
import { IStreamModuleRegistry } from "../../interfaces/stream/modules/IStreamModuleRegistry.sol";
import { IStreamModule } from "../../interfaces/stream/modules/IStreamModule.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";

/// @notice Fixed construction joins and separate current module-selection gates for recovery.
/// @dev Only the companion constructor supplies Inputs. Historical observations retain original
///      runtime pins without following today's Core pointers or requiring current evidence hosts.
library StreamFinalityRecoveryBindings {
    error FinalityRecoveryBindingInvalid(address target);
    error FinalityRecoveryBindingReadFailed(address target, bytes4 selector);
    error FinalityRecoveryDependencyHasNoCode(address target);
    error FinalityRecoveryBindingChanged(address target);
    error FinalityRecoveryParentGas(uint256 available, uint256 required);

    struct Inputs {
        address core;
        address executor;
        address originalFinality;
        address artist;
        address ownerEvidence;
        uint256 readGas;
    }

    struct Bound {
        Inputs inputs;
        address coordinator;
        T.SuiteConfiguration suite;
        // Core, artist, Coordinator, Consent, original Finality, Executor, OwnerRecords.
        bytes32[7] codeHashes;
        uint256 chainId;
    }

    function admit(Inputs memory input) public view returns (Bound memory b) {
        b.inputs = input;
        b.chainId = block.chainid;
        uint256 cap = input.readGas;
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert FinalityRecoveryBindingInvalid(address(0));
        }
        _code(input.core);
        _code(input.executor);
        _code(input.originalFinality);
        _code(input.artist);
        _code(input.ownerEvidence);
        b.coordinator = _address(
            input.artist, abi.encodeCall(IStreamArtistIngressBinding.operationCoordinator, ()), cap
        );
        _code(b.coordinator);
        bytes memory raw = fixedRead(
            b.coordinator,
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()),
            544,
            cap
        );
        for (uint256 i; i < 17; ++i) {
            if (i != 15 && _word(raw, i) >> 160 != 0) {
                revert FinalityRecoveryBindingInvalid(b.coordinator);
            }
        }
        b.suite = abi.decode(raw, (T.SuiteConfiguration));
        if (
            b.suite.core != input.core || b.suite.registry != input.artist
                || b.suite.primaryRevenueClass == 0
        ) {
            revert FinalityRecoveryBindingInvalid(b.coordinator);
        }
        if (
            _word(
                        fixedRead(
                            b.coordinator,
                            abi.encodeCall(IStreamArtistRecoveryDeployment.deploymentChainId, ()),
                            32,
                            cap
                        ),
                        0
                    ) != block.chainid
                || _address(
                        b.coordinator,
                        abi.encodeCall(IStreamArtistRecoveryDeployment.finalityRegistry, ()),
                        cap
                    ) != input.originalFinality
                || bytes32(
                        _word(
                            fixedRead(
                                b.coordinator,
                                abi.encodeCall(
                                    IStreamArtistRecoveryDeployment.finalityRegistryCodeHash, ()
                                ),
                                32,
                                cap
                            ),
                            0
                        )
                    ) != input.originalFinality.codehash
                || _address(
                        input.originalFinality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.coreReads, ()),
                        cap
                    ) != input.core
                || _address(
                        input.originalFinality,
                        abi.encodeCall(IStreamFinalityDeploymentBindings.sanctionReads, ()),
                        cap
                    ) != input.artist
                || _address(input.artist, abi.encodeCall(IStreamArtistMintConsent.core, ()), cap)
                    != input.core
                || _address(
                        input.artist, abi.encodeCall(IStreamArtistMintConsent.mintManager, ()), cap
                    ) != b.suite.mintManager
                || _address(
                        input.executor,
                        abi.encodeCall(IStreamFinalityGovernanceBindings.roleRegistry, ()),
                        cap
                    ) != b.suite.roleRegistry
                || _address(
                        b.suite.roleRegistry,
                        abi.encodeCall(IStreamFinalityGovernanceBindings.owner, ()),
                        cap
                    ) != input.executor
        ) revert FinalityRecoveryBindingInvalid(b.coordinator);
        _owners(b);
        if (!_supports(input.core, type(IStreamFinalityRecoveryCore).interfaceId, cap)) {
            revert FinalityRecoveryBindingInvalid(input.core);
        }
        if (!_supports(
                input.ownerEvidence, type(IStreamFinalityRecoveryOwnerEvidence).interfaceId, cap
            )) revert FinalityRecoveryBindingInvalid(input.ownerEvidence);
        if (
            _address(
                        input.ownerEvidence,
                        abi.encodeCall(IStreamFinalityRecoveryOwnerBindings.core, ()),
                        cap
                    ) != input.core
                || _address(
                        input.ownerEvidence,
                        abi.encodeCall(
                            IStreamFinalityRecoveryOwnerBindings.governanceAuthority, ()
                        ),
                        cap
                    ) != input.executor
        ) revert FinalityRecoveryBindingInvalid(input.ownerEvidence);
        for (uint256 i; i < 7; ++i) {
            b.codeHashes[i] = _target(b, i).codehash;
        }
    }

    /// @notice Recheck original fixed runtime identities; current evidence hosts are optional.
    /// @dev Historical record resolution passes false. New admission/execution passes true.
    function pins(Bound memory b, bool currentEvidence) public view {
        if (block.chainid != b.chainId) revert FinalityRecoveryBindingInvalid(address(0));
        for (uint256 i; i < (currentEvidence ? 7 : 5); ++i) {
            address target = _target(b, i);
            if (target.code.length == 0 || target.codehash != b.codeHashes[i]) {
                revert FinalityRecoveryBindingChanged(target);
            }
        }
    }

    /// @notice Require today's exact selected companion and artist, including live registry eligibility.
    /// @dev No constructor or historical getter calls this function. The fixed host passes itself.
    function current(Bound memory b, address companion) public view {
        pins(b, true);
        selected(
            b.inputs.core,
            keccak256("ARTWORK_FINALITY_RECOVERY"),
            companion,
            keccak256("STREAM_ARTWORK_FINALITY_RECOVERY"),
            bytes4(0x83685f5c),
            b.inputs.readGas
        );
        selected(
            b.inputs.core,
            keccak256("ARTIST_REGISTRY"),
            b.inputs.artist,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId,
            b.inputs.readGas
        );
    }

    function selected(
        address core,
        bytes32 key,
        address expected,
        bytes32 kind,
        bytes4 interfaceId,
        uint256 cap
    ) public view {
        bytes memory pointer = fixedRead(
            core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)), 320, cap
        );
        address target = address(uint160(_word(pointer, 0)));
        if (
            target != expected || target == address(0) || _word(pointer, 0) >> 160 != 0
                || target.code.length == 0 || target.codehash != bytes32(_word(pointer, 1))
                || _word(pointer, 2) > 1 || bytes32(_word(pointer, 3)) != kind
                || bytes32(_word(pointer, 4)) != bytes32(interfaceId)
                || _word(pointer, 5) >> 160 != 0
                || (_word(pointer, 6) != 1 && _word(pointer, 6) != 2) || _word(pointer, 9) == 0
                || _word(pointer, 9) > type(uint64).max
        ) revert FinalityRecoveryBindingInvalid(target);
        bytes memory registryPointer = fixedRead(
            core,
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (keccak256("MODULE_REGISTRY"))),
            320,
            cap
        );
        address registry = address(uint160(_word(registryPointer, 0)));
        if (
            _word(registryPointer, 0) >> 160 != 0 || registry == address(0)
                || registry != address(uint160(_word(pointer, 5))) || registry.code.length == 0
                || registry.codehash != bytes32(_word(registryPointer, 1))
                || bytes32(
                        _word(
                            fixedRead(
                                target, abi.encodeCall(IStreamModule.streamModuleType, ()), 32, cap
                            ),
                            0
                        )
                    ) != kind
                || bytes32(
                        _word(
                            fixedRead(
                                target,
                                abi.encodeCall(IStreamModule.streamModuleInterfaceId, ()),
                                32,
                                cap
                            ),
                            0
                        )
                    ) != bytes32(interfaceId)
                || _word(
                        fixedRead(
                            registry,
                            abi.encodeCall(
                                IStreamModuleRegistry.isModuleEligible, (target, kind, interfaceId)
                            ),
                            32,
                            cap
                        ),
                        0
                    ) != 1 || !_supports(target, interfaceId, cap)
        ) revert FinalityRecoveryBindingInvalid(target);
    }

    function _owners(Bound memory b) private view {
        bytes32[7] memory domains = [
            keccak256("domain:binding_lifecycle"),
            keccak256("domain:collaborator_lifecycle"),
            keccak256("domain:identity_authority"),
            keccak256("domain:acceptance_lifecycle"),
            keccak256("domain:attribution_lifecycle"),
            keccak256("domain:payout_lifecycle"),
            keccak256("domain:consent_finality")
        ];
        uint256 cap = b.inputs.readGas;
        for (uint256 i; i < 7; ++i) {
            address target = b.suite.owners[i];
            _code(target);
            if (
                _address(target, abi.encodeCall(IStreamArtistOwner.artistRegistry, ()), cap)
                        != b.inputs.artist
                    || _address(
                            target, abi.encodeCall(IStreamArtistOwner.operationCoordinator, ()), cap
                        ) != b.coordinator
                    || _address(target, abi.encodeCall(IStreamArtistOwner.core, ()), cap)
                        != b.inputs.core
                    || _address(target, abi.encodeCall(IStreamArtistOwner.mintManager, ()), cap)
                        != b.suite.mintManager
                    || _address(target, abi.encodeCall(IStreamArtistOwner.archiveV2, ()), cap)
                        != b.suite.archive
                    || _word(
                            fixedRead(
                                target,
                                abi.encodeCall(IStreamArtistOwner.deploymentChainId, ()),
                                32,
                                cap
                            ),
                            0
                        ) != block.chainid
                    || bytes32(
                            _word(
                                fixedRead(
                                    target, abi.encodeCall(IStreamArtistOwner.domainId, ()), 32, cap
                                ),
                                0
                            )
                        ) != domains[i]
            ) revert FinalityRecoveryBindingInvalid(target);
        }
    }

    function _target(Bound memory b, uint256 i) private pure returns (address) {
        if (i == 0) return b.inputs.core;
        if (i == 1) return b.inputs.artist;
        if (i == 2) return b.coordinator;
        if (i == 3) return b.suite.owners[6];
        if (i == 4) return b.inputs.originalFinality;
        if (i == 5) return b.inputs.executor;
        return b.inputs.ownerEvidence;
    }

    function _supports(address target, bytes4 id, uint256 cap) private view returns (bool) {
        return _word(fixedRead(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, cap), 0)
                == 1
            && _word(
                fixedRead(
                target,
                abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                32,
                cap
            ),
                0
            ) == 1
            && _word(
                fixedRead(
                target, abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), 32, cap
            ),
                0
            ) == 0;
    }

    function _code(address target) private view {
        if (target.code.length == 0) revert FinalityRecoveryDependencyHasNoCode(target);
    }

    function _address(address target, bytes memory data, uint256 cap)
        private
        view
        returns (address)
    {
        uint256 value = _word(fixedRead(target, data, 32, cap), 0);
        if (value == 0 || value >> 160 != 0) revert FinalityRecoveryBindingInvalid(target);
        return address(uint160(value));
    }

    function _word(bytes memory raw, uint256 index) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(raw, 32), mul(index, 32))) }
    }

    function fixedRead(address target, bytes memory input, uint256 length, uint256 cap)
        public
        view
        returns (bytes memory raw)
    {
        if (cap == 0 || cap > type(uint256).max / 64) {
            revert FinalityRecoveryBindingInvalid(target);
        }
        raw = new bytes(length);
        bool ok;
        uint256 size;
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) revert FinalityRecoveryParentGas(gasleft(), required);
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), length)
            size := returndatasize()
        }
        if (!ok || size != length) revert FinalityRecoveryBindingReadFailed(target, bytes4(input));
    }
}
