// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/finality/StreamFinalityRecoveryBindings.sol";

interface RecoveryBindingsVm {
    function etch(address target, bytes calldata runtime) external;
}

/// @dev Deliberate raw dependency boundary; it makes no claim to implement actual artist governance.
contract RecoveryBindingEndpoint {
    mapping(bytes32 => bytes) private answers;

    function answer(bytes calldata input, bytes calldata output) external {
        answers[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = answers[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract RecoveryBindingsHost {
    StreamFinalityRecoveryBindings.Bound private bound;

    constructor(StreamFinalityRecoveryBindings.Inputs memory input) {
        bound = StreamFinalityRecoveryBindings.admit(input);
    }

    function configuration() external view returns (StreamFinalityRecoveryBindings.Bound memory) {
        return bound;
    }

    function pins(bool liveEvidence) external view {
        StreamFinalityRecoveryBindings.pins(bound, liveEvidence);
    }

    function current(address companion) external view {
        StreamFinalityRecoveryBindings.current(bound, companion);
    }
}

contract StreamFinalityRecoveryBindingsTest {
    RecoveryBindingsVm private constant vm =
        RecoveryBindingsVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RecoveryBindingEndpoint private core;
    RecoveryBindingEndpoint private artist;
    RecoveryBindingEndpoint private coordinator;
    RecoveryBindingEndpoint private finality;
    RecoveryBindingEndpoint private executor;
    RecoveryBindingEndpoint private ownerEvidence;
    RecoveryBindingEndpoint private roles;
    RecoveryBindingEndpoint private modules;
    RecoveryBindingEndpoint private companion;
    T.SuiteConfiguration private suite;
    StreamFinalityRecoveryBindings.Inputs private input;
    bytes32 private constant RECOVERY = keccak256("ARTWORK_FINALITY_RECOVERY");
    bytes32 private constant KIND = keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");

    function setUp() public {
        core = new RecoveryBindingEndpoint();
        artist = new RecoveryBindingEndpoint();
        coordinator = new RecoveryBindingEndpoint();
        finality = new RecoveryBindingEndpoint();
        executor = new RecoveryBindingEndpoint();
        ownerEvidence = new RecoveryBindingEndpoint();
        roles = new RecoveryBindingEndpoint();
        modules = new RecoveryBindingEndpoint();
        companion = new RecoveryBindingEndpoint();
        suite.registry = address(artist);
        suite.archive = address(new RecoveryBindingEndpoint());
        suite.core = address(core);
        suite.mintManager = address(new RecoveryBindingEndpoint());
        suite.roleRegistry = address(roles);
        suite.metadata = address(new RecoveryBindingEndpoint());
        suite.primaryResolver = address(new RecoveryBindingEndpoint());
        suite.royaltyResolver = address(new RecoveryBindingEndpoint());
        suite.primaryRevenueClass = keccak256("primary class");
        suite.validator = address(new RecoveryBindingEndpoint());
        bytes32[7] memory domains = [
            keccak256("domain:binding_lifecycle"),
            keccak256("domain:collaborator_lifecycle"),
            keccak256("domain:identity_authority"),
            keccak256("domain:acceptance_lifecycle"),
            keccak256("domain:attribution_lifecycle"),
            keccak256("domain:payout_lifecycle"),
            keccak256("domain:consent_finality")
        ];
        for (uint256 i; i < 7; ++i) {
            RecoveryBindingEndpoint o = new RecoveryBindingEndpoint();
            suite.owners[i] = address(o);
            _address(o, IStreamArtistOwner.artistRegistry.selector, address(artist));
            _address(o, IStreamArtistOwner.operationCoordinator.selector, address(coordinator));
            _address(o, IStreamArtistOwner.core.selector, address(core));
            _address(o, IStreamArtistOwner.mintManager.selector, suite.mintManager);
            _address(o, IStreamArtistOwner.archiveV2.selector, suite.archive);
            _word(o, IStreamArtistOwner.deploymentChainId.selector, block.chainid);
            _word(o, IStreamArtistOwner.domainId.selector, uint256(domains[i]));
        }
        _address(
            artist, IStreamArtistIngressBinding.operationCoordinator.selector, address(coordinator)
        );
        _address(artist, IStreamArtistMintConsent.core.selector, address(core));
        _address(artist, IStreamArtistMintConsent.mintManager.selector, suite.mintManager);
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()),
            abi.encode(suite)
        );
        _word(
            coordinator, IStreamArtistRecoveryDeployment.deploymentChainId.selector, block.chainid
        );
        _address(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistry.selector,
            address(finality)
        );
        _word(
            coordinator,
            IStreamArtistRecoveryDeployment.finalityRegistryCodeHash.selector,
            uint256(address(finality).codehash)
        );
        _address(finality, IStreamFinalityDeploymentBindings.coreReads.selector, address(core));
        _address(
            finality, IStreamFinalityDeploymentBindings.sanctionReads.selector, address(artist)
        );
        _address(executor, IStreamFinalityGovernanceBindings.roleRegistry.selector, address(roles));
        _address(roles, IStreamFinalityGovernanceBindings.owner.selector, address(executor));
        _erc(core, type(IStreamFinalityRecoveryCore).interfaceId);
        _erc(ownerEvidence, type(IStreamFinalityRecoveryOwnerEvidence).interfaceId);
        _address(ownerEvidence, IStreamFinalityRecoveryOwnerBindings.core.selector, address(core));
        _address(
            ownerEvidence,
            IStreamFinalityRecoveryOwnerBindings.governanceAuthority.selector,
            address(executor)
        );
        input = StreamFinalityRecoveryBindings.Inputs(
            address(core),
            address(executor),
            address(finality),
            address(artist),
            address(ownerEvidence),
            150000
        );
    }

    function _word(RecoveryBindingEndpoint target, bytes4 selector, uint256 value) private {
        target.answer(abi.encodeWithSelector(selector), abi.encode(value));
    }

    function _address(RecoveryBindingEndpoint target, bytes4 selector, address value) private {
        _word(target, selector, uint160(value));
    }

    function _erc(RecoveryBindingEndpoint target, bytes4 id) private {
        target.answer(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        target.answer(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        target.answer(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
    }

    function _pointer(bytes32 key, address target, bytes32 kind, bytes4 id, bytes32 code) private {
        core.answer(
            abi.encodeCall(IStreamCorePointers.getSatellitePointer, (key)),
            abi.encode(
                target,
                code,
                false,
                kind,
                id,
                address(modules),
                uint8(1),
                keccak256("module manifest"),
                keccak256("deployment"),
                uint64(1)
            )
        );
    }

    function _module(RecoveryBindingEndpoint target, bytes32 kind, bytes4 id, bool eligible)
        private
    {
        _word(target, IStreamModule.streamModuleType.selector, uint256(kind));
        _word(target, IStreamModule.streamModuleInterfaceId.selector, uint256(bytes32(id)));
        _erc(target, id);
        modules.answer(
            abi.encodeCall(IStreamModuleRegistry.isModuleEligible, (address(target), kind, id)),
            abi.encode(eligible)
        );
    }

    function _select() private {
        _pointer(
            keccak256("MODULE_REGISTRY"),
            address(modules),
            keccak256("MODULE_REGISTRY"),
            0x11223344,
            address(modules).codehash
        );
        _pointer(RECOVERY, address(companion), KIND, 0x83685f5c, address(companion).codehash);
        _module(companion, KIND, 0x83685f5c, true);
        bytes4 id = type(IStreamArtistMintConsent).interfaceId;
        _pointer(
            keccak256("ARTIST_REGISTRY"),
            address(artist),
            keccak256("ARTIST_REGISTRY"),
            id,
            address(artist).codehash
        );
        _module(artist, keccak256("ARTIST_REGISTRY"), id, true);
    }

    function _reject(address target, bytes memory data, bytes memory expected) private {
        (bool ok, bytes memory output) = target.call(data);
        require(!ok && keccak256(output) == keccak256(expected), "exact rejection");
    }

    function deploy(StreamFinalityRecoveryBindings.Inputs calldata args)
        external
        returns (address)
    {
        return address(new RecoveryBindingsHost(args));
    }

    function testRecoveryBindingsDeriveExactSuiteWithoutCoreSelection() public {
        RecoveryBindingsHost host = new RecoveryBindingsHost(input);
        StreamFinalityRecoveryBindings.Bound memory b = host.configuration();
        require(
            keccak256(abi.encode(b.inputs)) == keccak256(abi.encode(input))
                && b.coordinator == address(coordinator) && b.chainId == block.chainid,
            "constructor facts"
        );
        require(keccak256(abi.encode(b.suite)) == keccak256(abi.encode(suite)), "exact suite");
        address[7] memory expected = [
            address(core),
            address(artist),
            address(coordinator),
            suite.owners[6],
            address(finality),
            address(executor),
            address(ownerEvidence)
        ];
        for (uint256 i; i < 7; ++i) {
            require(b.codeHashes[i] == expected[i].codehash, "derived runtime pin");
        }
        host.pins(false);
        host.pins(true);
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector,
                address(core),
                IStreamCorePointers.getSatellitePointer.selector
            )
        );
        _select();
        host.current(address(companion));
    }

    function testRecoveryBindingsRejectMalformedSuiteAndReciprocalSubstitution() public {
        bytes memory canonical = abi.encode(suite);
        bytes memory malformed = abi.encode(suite);
        assembly ("memory-safe") { mstore(add(malformed, 32), shl(160, 1)) }
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()), malformed
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(coordinator)
            )
        );
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()),
            bytes.concat(canonical, bytes32(0))
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector,
                address(coordinator),
                IStreamArtistRecoveryDeployment.suiteConfiguration.selector
            )
        );
        coordinator.answer(
            abi.encodeCall(IStreamArtistRecoveryDeployment.suiteConfiguration, ()), canonical
        );
        _address(
            finality, IStreamFinalityDeploymentBindings.sanctionReads.selector, address(companion)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(coordinator)
            )
        );
        _address(
            finality, IStreamFinalityDeploymentBindings.sanctionReads.selector, address(artist)
        );
        _address(
            RecoveryBindingEndpoint(suite.owners[6]),
            IStreamArtistOwner.operationCoordinator.selector,
            address(companion)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                suite.owners[6]
            )
        );
        _address(
            RecoveryBindingEndpoint(suite.owners[6]),
            IStreamArtistOwner.operationCoordinator.selector,
            address(coordinator)
        );
        new RecoveryBindingsHost(input);
    }

    function testRecoveryBindingsHistoricalPinsIgnoreCurrentEvidenceAndPointers() public {
        RecoveryBindingsHost host = new RecoveryBindingsHost(input);
        _select();
        host.current(address(companion));
        bytes memory code = address(ownerEvidence).code;
        vm.etch(address(ownerEvidence), hex"00");
        host.pins(false);
        _reject(
            address(host),
            abi.encodeCall(host.pins, (true)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingChanged.selector,
                address(ownerEvidence)
            )
        );
        vm.etch(address(ownerEvidence), code);
        vm.etch(address(executor), hex"00");
        host.pins(false);
        _reject(
            address(host),
            abi.encodeCall(host.pins, (true)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingChanged.selector,
                address(executor)
            )
        );
        vm.etch(address(executor), code);
        _pointer(
            RECOVERY, address(ownerEvidence), KIND, 0x83685f5c, address(ownerEvidence).codehash
        );
        host.pins(false);
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _select();
        host.current(address(companion));
    }

    function testRecoveryBindingsConsentAndCoordinatorRuntimeDriftRejectRestore() public {
        RecoveryBindingsHost host = new RecoveryBindingsHost(input);
        address[5] memory targets = [
            address(core), address(artist), address(coordinator), suite.owners[6], address(finality)
        ];
        for (uint256 i; i < 5; ++i) {
            bytes memory code = targets[i].code;
            vm.etch(targets[i], hex"00");
            _reject(
                address(host),
                abi.encodeCall(host.pins, (false)),
                abi.encodeWithSelector(
                    StreamFinalityRecoveryBindings.FinalityRecoveryBindingChanged.selector,
                    targets[i]
                )
            );
            vm.etch(targets[i], code);
            host.pins(false);
        }
    }

    function testRecoveryBindingsLiveRegistryEligibilityAndInterfaceRejectRestore() public {
        RecoveryBindingsHost host = new RecoveryBindingsHost(input);
        _select();
        host.current(address(companion));
        _module(companion, KIND, 0x83685f5c, false);
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(companion)
            )
        );
        _module(companion, KIND, 0x83685f5c, true);
        host.current(address(companion));
        _word(
            companion,
            IStreamModule.streamModuleInterfaceId.selector,
            uint256(bytes32(bytes4(0x83685f5c))) + 1
        );
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(companion)
            )
        );
        _module(companion, KIND, 0x83685f5c, true);
        companion.answer(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true)
        );
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(companion)
            )
        );
        _module(companion, KIND, 0x83685f5c, true);
        _module(
            artist, keccak256("ARTIST_REGISTRY"), type(IStreamArtistMintConsent).interfaceId, false
        );
        _reject(
            address(host),
            abi.encodeCall(host.current, (address(companion))),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(artist)
            )
        );
        _select();
        host.current(address(companion));
    }

    function testRecoveryBindingsNoCodeAndBoundedGasFailureRestore() public {
        StreamFinalityRecoveryBindings.Inputs memory bad = input;
        bad.ownerEvidence = address(0xA0);
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (bad)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryDependencyHasNoCode.selector,
                address(0xA0)
            )
        );
        RecoveryBindingsHost host = new RecoveryBindingsHost(input);
        _select();
        (bool ok, bytes memory output) =
            address(host).call{ gas: 250000 }(abi.encodeCall(host.current, (address(companion))));
        require(
            !ok
                && bytes4(output)
                    == StreamFinalityRecoveryBindings.FinalityRecoveryParentGas.selector,
            "parent gas failure"
        );
        host.current(address(companion));
    }

    function testRecoveryBindingsOwnerReciprocalCoreExecutorRejectRestore() public {
        _address(
            ownerEvidence, IStreamFinalityRecoveryOwnerBindings.core.selector, address(companion)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _address(ownerEvidence, IStreamFinalityRecoveryOwnerBindings.core.selector, address(core));
        _address(
            ownerEvidence,
            IStreamFinalityRecoveryOwnerBindings.governanceAuthority.selector,
            address(companion)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _address(
            ownerEvidence,
            IStreamFinalityRecoveryOwnerBindings.governanceAuthority.selector,
            address(executor)
        );
        new RecoveryBindingsHost(input);
    }

    function testRecoveryBindingsOwnerInterfaceTriadFailsClosedAndRestores() public {
        bytes4 id = type(IStreamFinalityRecoveryOwnerEvidence).interfaceId;
        bytes memory probe = abi.encodeCall(IERC165.supportsInterface, (id));
        ownerEvidence.answer(probe, hex"");
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingReadFailed.selector,
                address(ownerEvidence),
                IERC165.supportsInterface.selector
            )
        );
        ownerEvidence.answer(probe, abi.encode(false));
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        ownerEvidence.answer(probe, abi.encode(uint256(2)));
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _erc(ownerEvidence, id);
        ownerEvidence.answer(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(true)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _erc(ownerEvidence, id);
        ownerEvidence.answer(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
            abi.encode(false)
        );
        _reject(
            address(this),
            abi.encodeCall(this.deploy, (input)),
            abi.encodeWithSelector(
                StreamFinalityRecoveryBindings.FinalityRecoveryBindingInvalid.selector,
                address(ownerEvidence)
            )
        );
        _erc(ownerEvidence, id);
        new RecoveryBindingsHost(input);
    }
}
