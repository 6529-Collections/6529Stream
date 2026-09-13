// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../smart-contracts/domains/finality/StreamArtworkFinalityRecovery.sol";
import "./RecoveryOriginalRecordFixture.sol";

interface CompanionVm {
    function etch(address target, bytes calldata code) external;
    function warp(uint256 time) external;
    function chainId(uint256 id) external;
}

// Exact raw dependency preparation reused from bindings7; no real artist/OwnerRecords authority.
contract CompanionDependencyBoundary {
    mapping(bytes32 => bytes) private answers;

    function answer(bytes calldata input, bytes calldata output) external {
        answers[keccak256(input)] = output;
    }

    fallback() external {
        bytes memory output = answers[keccak256(msg.data)];
        assembly ("memory-safe") { return(add(output, 32), mload(output)) }
    }
}

contract CompanionExecutorBoundary is CompanionDependencyBoundary {
    bool private executing;
    uint8 private actionClass;
    bytes32[4] private facts;

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (executing, facts[0], actionClass, facts[1], facts[2], facts[3]);
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function run(address target, bytes calldata data, bytes32[4] calldata f, uint8 cls)
        external
        returns (bool ok, bytes memory result)
    {
        executing = true;
        facts = f;
        actionClass = cls;
        (ok, result) = target.call(data);
        executing = false;
        delete facts;
        actionClass = 0;
    }
}

abstract contract RecoveryCompanionBoundaryFixture {
    CompanionVm internal constant vm =
        CompanionVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    CompanionDependencyBoundary internal core;
    CompanionDependencyBoundary internal artist;
    CompanionDependencyBoundary internal coordinator;
    CompanionDependencyBoundary internal finality;
    CompanionDependencyBoundary internal executor;
    CompanionDependencyBoundary internal ownerEvidence;
    CompanionDependencyBoundary internal roles;
    CompanionDependencyBoundary internal modules;
    CompanionDependencyBoundary internal companion;
    T.SuiteConfiguration internal suite;
    StreamFinalityRecoveryBindings.Inputs internal input;
    bytes32 internal constant RECOVERY = keccak256("ARTWORK_FINALITY_RECOVERY");
    bytes32 internal constant KIND = keccak256("STREAM_ARTWORK_FINALITY_RECOVERY");

    function setUp() public virtual {
        core = new CompanionDependencyBoundary();
        artist = new CompanionDependencyBoundary();
        coordinator = new CompanionDependencyBoundary();
        finality = new CompanionDependencyBoundary();
        executor = new CompanionDependencyBoundary();
        ownerEvidence = new CompanionDependencyBoundary();
        roles = new CompanionDependencyBoundary();
        modules = new CompanionDependencyBoundary();
        companion = new CompanionDependencyBoundary();
        suite.registry = address(artist);
        suite.archive = address(new CompanionDependencyBoundary());
        suite.core = address(core);
        suite.mintManager = address(new CompanionDependencyBoundary());
        suite.roleRegistry = address(roles);
        suite.metadata = address(new CompanionDependencyBoundary());
        suite.primaryResolver = address(new CompanionDependencyBoundary());
        suite.royaltyResolver = address(new CompanionDependencyBoundary());
        suite.primaryRevenueClass = keccak256("primary class");
        suite.validator = address(new CompanionDependencyBoundary());
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
            CompanionDependencyBoundary o = new CompanionDependencyBoundary();
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

    function _word(CompanionDependencyBoundary target, bytes4 selector, uint256 value) internal {
        target.answer(abi.encodeWithSelector(selector), abi.encode(value));
    }

    function _address(CompanionDependencyBoundary target, bytes4 selector, address value) internal {
        _word(target, selector, uint160(value));
    }

    function _erc(CompanionDependencyBoundary target, bytes4 id) internal {
        target.answer(abi.encodeCall(IERC165.supportsInterface, (id)), abi.encode(true));
        target.answer(
            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)), abi.encode(true)
        );
        target.answer(
            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))), abi.encode(false)
        );
    }

    function _pointer(bytes32 key, address target, bytes32 kind, bytes4 id, bytes32 code) internal {
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

    function _module(CompanionDependencyBoundary target, bytes32 kind, bytes4 id, bool eligible)
        internal
    {
        _word(target, IStreamModule.streamModuleType.selector, uint256(kind));
        _word(target, IStreamModule.streamModuleInterfaceId.selector, uint256(bytes32(id)));
        _erc(target, id);
        modules.answer(
            abi.encodeCall(IStreamModuleRegistry.isModuleEligible, (address(target), kind, id)),
            abi.encode(eligible)
        );
    }

    function _select() internal {
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

    function _reject(address target, bytes memory data, bytes memory expected) internal {
        (bool ok, bytes memory output) = target.call(data);
        require(!ok && keccak256(output) == keccak256(expected), "exact rejection");
    }
}
