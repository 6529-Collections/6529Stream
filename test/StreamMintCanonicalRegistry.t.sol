// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/CharacterizationTestBase.sol";
import "../smart-contracts/domains/mint/StreamMintManager.sol";
import "../smart-contracts/domains/mint/StreamMintLedger.sol";
import "../smart-contracts/domains/modules/StreamModuleRegistry.sol";

contract CanonicalMintCoreFixture is ERC165 {
    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == 0x80ac58cd || super.supportsInterface(id);
    }
}

contract CanonicalMintExecutorFixture {
    function currentAction()
        external
        pure
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return (false, bytes32(0), 0, bytes32(0), bytes32(0), bytes32(0));
    }
}

contract CanonicalMintGateFixture is ERC165 {
    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamMintGate).interfaceId || super.supportsInterface(id);
    }
}

contract CanonicalMintRecordFixture is ERC165 {
    StreamModuleRecord private _record;

    constructor(address gate) {
        _record = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            keccak256("6529STREAM_MINT_GATE_V1"),
            keccak256("full bytes32 version"),
            type(IStreamMintGate).interfaceId,
            100_000,
            gate.codehash,
            keccak256("deployment"),
            keccak256("manifest"),
            "ipfs://gate",
            1,
            1,
            1
        );
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamModuleRegistry).interfaceId || super.supportsInterface(id);
    }

    function moduleRecord(address) external view returns (StreamModuleRecord memory) {
        return _record;
    }

    function setVersion(bytes32 version) external {
        _record.moduleVersion = version;
    }

    function revoke() external {
        _record.status = ModuleRegistryStatus.INCIDENT_REVOKED;
    }
}

contract StreamMintCanonicalRegistryTest is CharacterizationTestBase {
    function testManagerAcceptsActualCanonicalRegistry() public {
        StreamModuleRegistry registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(new CanonicalMintExecutorFixture())),
            keccak256("manifest"),
            "ipfs://manifest"
        );
        StreamMintManager manager = new StreamMintManager(
            IStreamCore(address(new CanonicalMintCoreFixture())), new StreamMintLedger(), registry
        );
        require(address(manager.moduleRegistry()) == address(registry), "one canonical registry");
    }

    function testCanonicalGatePinsFullVersionAndManifestWithoutTruncation() public {
        CanonicalMintGateFixture gate = new CanonicalMintGateFixture();
        CanonicalMintRecordFixture registry = new CanonicalMintRecordFixture(address(gate));
        IStreamMintManager.MintGateConfig memory input;
        input.gate = address(gate);
        input.gateConfigHash = keccak256("gate config");
        IStreamMintManager.MintGateConfig memory config =
            StreamMintGateValidator.validateConfiguration(input, registry);
        require(
            config.gateCodehash == address(gate).codehash && config.gateGasLimit == 100_000,
            "registry pins"
        );
        require(
            config.gateMetadataHash
                == keccak256(abi.encode(keccak256("full bytes32 version"), keccak256("manifest"))),
            "full version identity"
        );
        IStreamMintManager.MintBatch memory batch;
        batch.authorizationId = keccak256("authorization");
        registry.setVersion(keccak256("different version"));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.MintGateNotActive.selector, address(gate))
        );
        StreamMintGateValidator.validateAuthorization(
            batch, "", 1, keccak256("policy"), config, registry, address(this)
        );
    }

    function testRevokedCanonicalGateCannotConfigurePhase() public {
        CanonicalMintGateFixture gate = new CanonicalMintGateFixture();
        CanonicalMintRecordFixture registry = new CanonicalMintRecordFixture(address(gate));
        IStreamMintManager.MintGateConfig memory input;
        input.gate = address(gate);
        input.gateConfigHash = keccak256("gate config");
        registry.revoke();
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintManager.MintGateNotActive.selector, address(gate))
        );
        StreamMintGateValidator.validateConfiguration(input, registry);
    }
}
