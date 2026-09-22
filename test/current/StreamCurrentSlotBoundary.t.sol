// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentTestSlots.sol";
import {
    StreamArtistExtensionFactory
} from "../../smart-contracts/domains/artist/StreamArtistExtensionFactory.sol";
import {
    StreamArtistOnboardingRegistry
} from "../../smart-contracts/domains/artist/StreamArtistOnboardingRegistry.sol";
import {
    StreamCurrentFinalityArtifacts
} from "../../script/current/StreamCurrentFinalityArtifacts.sol";

interface SlotBoundaryVm {
    struct Log {
        bytes32[] topics;
        bytes data;
        address emitter;
    }
    function snapshotState() external returns (uint256);
    function revertToState(uint256 id) external returns (bool);
    function getNonce(address account) external view returns (uint64);
    function computeCreateAddress(address deployer, uint256 nonce) external pure returns (address);
    function expectCall(address callee, bytes calldata data, uint64 count) external;
    function recordLogs() external;
    function getRecordedLogs() external returns (Log[] memory);
}

/// @dev Explicit boundary doubles, not current production Artist topology.
contract SlotBoundaryChild {
    uint256 public kind;
    bytes32 public pinsHash;
    address public creator;

    constructor(uint256 k, bytes32 p) {
        kind = k;
        pinsHash = p;
        creator = msg.sender;
    }
}

contract SlotBoundaryFactory {
    address public immutable expectedHost;
    uint256 public count;
    uint256 public failAt;
    bool public rejectConstruction;
    address public lastParent;
    address[3] public children;
    bytes32 public transcript;

    constructor(address host) {
        expectedHost = host;
    }

    function failures(uint256 at, bool construction) external {
        failAt = at;
        rejectConstruction = construction;
    }

    function deployRegistry(uint8 kind, address parent, address coordinator)
        external
        returns (address child)
    {
        require(msg.sender == expectedHost, "factory host caller");
        require(count < 3 && kind == count + 4, "registry child order");
        require(failAt != count + 1, "factory late failure");
        lastParent = parent;
        child = address(new SlotBoundaryChild(kind, keccak256(abi.encode(parent, coordinator))));
        children[count++] = child;
        transcript = keccak256(abi.encode(transcript, msg.sender, msg.data, child));
    }

    function deployIdentity(uint8 kind, address[6] calldata pins) external returns (address child) {
        require(msg.sender == expectedHost, "factory host caller");
        require(count < 3 && kind == count + 1, "identity child order");
        require(failAt != count + 1, "factory late failure");
        lastParent = pins[0];
        child = address(new SlotBoundaryChild(kind, keccak256(abi.encode(pins))));
        children[count++] = child;
        transcript = keccak256(abi.encode(transcript, msg.sender, msg.data, child));
    }
}

contract SlotBoundaryReadDouble {
    address public immutable expectedHost;
    uint256 public immutable role;
    address private core_;
    address private registry_;
    address private authority_;
    address private verifier_;

    constructor(address host, uint256 tag) {
        expectedHost = host;
        role = tag;
    }
    modifier hostRead() {
        require(msg.sender == expectedHost, "read host caller");
        _;
    }

    function configure(address c, address r, address a, address v) external {
        core_ = c;
        registry_ = r;
        authority_ = a;
        verifier_ = v;
    }

    function core() external view hostRead returns (address) {
        return core_;
    }

    function moduleRegistry() external view hostRead returns (address) {
        return registry_;
    }

    function governanceAuthority() external view hostRead returns (address) {
        return authority_;
    }

    function governanceExecutor() external view hostRead returns (address) {
        return authority_;
    }

    function isStreamGovernedParameterAuthority() external view hostRead returns (bool) {
        return true;
    }

    function supportsInterface(bytes4) external view hostRead returns (bool) {
        return true;
    }

    function checkpointVerifier() external view hostRead returns (address) {
        return verifier_;
    }

    function configurationHash() external view hostRead returns (bytes32) {
        return keccak256("slot boundary observers");
    }

    function profileHash() external view hostRead returns (bytes32) {
        return role == 4
            ? keccak256("6529STREAM_PUBLIC_DUAL_FAMILY_ARCHIVAL_V1")
            : keccak256("6529STREAM_ARWEAVE_SINGLE_CHUNK_QUORUM_V1");
    }

    function getSatellitePointer(bytes32 key)
        external
        view
        hostRead
        returns (
            address,
            bytes32,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        require(key == keccak256("MODULE_REGISTRY"), "registry pointer key");
        return (registry_, registry_.codehash, 0, 0, 0, 0, 0, 0, 0, 0);
    }
}

contract SlotBoundarySimpleProduct {
    address public creator;
    bytes32 public argumentsHash;

    constructor(bytes32 value) {
        creator = msg.sender;
        argumentsHash = value;
    }
}

contract SlotBoundaryFacadeProduct {
    address public creator;
    bytes32 public argumentsHash;

    constructor(
        address a,
        address b,
        address c,
        address d,
        address e,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash,
        address factory,
        address[3] memory children
    ) {
        require(!SlotBoundaryFactory(factory).rejectConstruction(), "constructor rejected");
        creator = msg.sender;
        argumentsHash =
            keccak256(
            abi.encode(a, b, c, d, e, deploymentHash, uri, manifestHash, factory, children)
        );
    }
}

contract SlotBoundaryIdentityProduct {
    address public creator;
    bytes32 public argumentsHash;

    constructor(
        address a,
        address b,
        address c,
        address d,
        address e,
        address factory,
        address[3] memory children
    ) {
        require(!SlotBoundaryFactory(factory).rejectConstruction(), "constructor rejected");
        creator = msg.sender;
        argumentsHash = keccak256(abi.encode(a, b, c, d, e, factory, children));
    }
}

contract SlotBoundaryRuntimeWitness {
    address public immutable expectedHost;
    SlotBoundaryFactory public immutable factory;
    StreamCurrentTestSlots.FacadeContext private facade;
    StreamCurrentTestSlots.IdentityContext private identity;
    address private verifier;
    bool public rejectHook;
    bool public wrongRuntime;
    SlotBoundaryVm private constant vm =
        SlotBoundaryVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    constructor(address host, SlotBoundaryFactory f) {
        expectedHost = host;
        factory = f;
    }

    function configure(
        StreamCurrentTestSlots.FacadeContext calldata f,
        StreamCurrentTestSlots.IdentityContext calldata i,
        address v
    ) external {
        facade = f;
        identity = i;
        verifier = v;
    }

    function failures(bool reject, bool wrong) external {
        rejectHook = reject;
        wrongRuntime = wrong;
    }

    function _same(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _word(address a) private pure returns (bytes32) {
        return bytes32(uint256(uint160(a)));
    }

    function _value(
        StreamCurrentFinalityArtifacts.RuntimeValue[] calldata v,
        uint256 at,
        string memory domain,
        string memory name,
        string memory variable,
        bytes32 value
    ) private pure {
        require(
            _same(
                v[at].source, string.concat("smart-contracts/domains/", domain, "/", name, ".sol")
            ) && _same(v[at].contractName, name) && _same(v[at].variable, variable)
            && v[at].value == value,
            "complete runtime value"
        );
    }

    function inspect(
        string calldata artifactPath,
        string[] calldata declarations,
        bytes calldata creation,
        StreamCurrentFinalityArtifacts.RuntimeValue[] calldata v
    ) external view returns (bytes memory) {
        require(
            msg.sender == expectedHost && factory.count() == 3,
            "runtime hook after three host factory calls"
        );
        require(!rejectHook, "runtime hook rejected");
        bool isFacade = _same(artifactPath, "slot-boundary/StreamArtistOnboardingRegistry.json");
        if (isFacade) {
            require(
                declarations.length == 3 && _same(declarations[0], artifactPath)
                    && _same(declarations[1], "slot-boundary/StreamGasParameterHost.json")
                    && _same(declarations[2], "slot-boundary/StreamModuleBase.json"),
                "facade virtual artifact paths"
            );
            require(
                keccak256(creation) == keccak256(type(SlotBoundaryFacadeProduct).creationCode)
                    && v.length == 14,
                "facade full template"
            );
            _value(v, 0, "artist", "StreamArtistOnboardingRegistry", "core", _word(facade.p[0]));
            _value(
                v, 1, "artist", "StreamArtistOnboardingRegistry", "mintManager", _word(facade.p[1])
            );
            _value(
                v,
                2,
                "artist",
                "StreamArtistOnboardingRegistry",
                "operationCoordinator",
                _word(facade.p[2])
            );
            _value(
                v,
                3,
                "artist",
                "StreamArtistOnboardingRegistry",
                "registryWriterExtension",
                _word(factory.children(0))
            );
            _value(
                v,
                4,
                "artist",
                "StreamArtistOnboardingRegistry",
                "registryReadExtension",
                _word(factory.children(1))
            );
            _value(
                v,
                5,
                "artist",
                "StreamArtistOnboardingRegistry",
                "registryFinalityReadExtension",
                _word(factory.children(2))
            );
            _value(
                v,
                6,
                "artist",
                "StreamArtistOnboardingRegistry",
                "archivalCoverage",
                _word(facade.p[4])
            );
            _value(
                v,
                7,
                "artist",
                "StreamArtistOnboardingRegistry",
                "archivalCoverageCodeHash",
                facade.p[4].codehash
            );
            bytes32 binding = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_ARCHIVAL_COVERAGE_BINDING_V1"),
                    block.chainid,
                    facade.p[0],
                    facade.p[3],
                    facade.p[4],
                    facade.p[4].codehash,
                    verifier,
                    verifier.codehash,
                    keccak256("slot boundary observers")
                )
            );
            _value(
                v,
                8,
                "artist",
                "StreamArtistOnboardingRegistry",
                "archivalCoverageConfigurationHash",
                binding
            );
            _value(
                v,
                9,
                "parameters",
                "StreamGasParameterHost",
                "governanceAuthority",
                _word(facade.p[3])
            );
            _value(
                v,
                10,
                "modules",
                "StreamModuleBase",
                "_schemaHash",
                keccak256("6529stream.artist-onboarding.v1")
            );
            _value(v, 11, "modules", "StreamModuleBase", "_supersedes", bytes32(0));
            _value(
                v,
                12,
                "modules",
                "StreamModuleBase",
                "_deploymentManifestHash",
                facade.deploymentHash
            );
            _value(v, 13, "modules", "StreamModuleBase", "_manifestHash", facade.manifestHash);
            if (wrongRuntime) return hex"00";
            return type(SlotBoundaryFacadeProduct).runtimeCode;
        }
        require(
            _same(artifactPath, "slot-boundary/StreamArtistIdentityAuthority.json")
                && declarations.length == 2 && _same(declarations[0], artifactPath)
                && _same(declarations[1], "slot-boundary/StreamArtistOwner.json"),
            "identity virtual artifact paths"
        );
        require(
            keccak256(creation) == keccak256(type(SlotBoundaryIdentityProduct).creationCode)
                && v.length == 13,
            "identity full template"
        );
        _value(v, 0, "artist", "StreamArtistOwner", "artistRegistry", _word(identity.p[0]));
        _value(v, 1, "artist", "StreamArtistOwner", "operationCoordinator", _word(identity.p[1]));
        _value(v, 2, "artist", "StreamArtistOwner", "archiveV2", _word(identity.p[2]));
        _value(v, 3, "artist", "StreamArtistOwner", "core", _word(identity.p[3]));
        _value(v, 4, "artist", "StreamArtistOwner", "mintManager", _word(identity.p[4]));
        _value(v, 5, "artist", "StreamArtistOwner", "deploymentChainId", bytes32(block.chainid));
        _value(
            v, 6, "artist", "StreamArtistOwner", "domainId", keccak256("domain:identity_authority")
        );
        _value(
            v,
            7,
            "artist",
            "StreamArtistIdentityAuthority",
            "artistWindowAuthority",
            _word(facade.p[3])
        );
        _value(
            v,
            8,
            "artist",
            "StreamArtistIdentityAuthority",
            "identityWriterExtension",
            _word(factory.children(0))
        );
        _value(
            v,
            9,
            "artist",
            "StreamArtistIdentityAuthority",
            "identityEstateExtension",
            _word(factory.children(1))
        );
        _value(
            v,
            10,
            "artist",
            "StreamArtistIdentityAuthority",
            "identityRecoveryExtension",
            _word(factory.children(2))
        );
        _value(
            v,
            11,
            "artist",
            "StreamArtistIdentityAuthority",
            "identityAdjudicationExtension",
            _word(vm.computeCreateAddress(factory.lastParent(), 1))
        );
        _value(
            v,
            12,
            "artist",
            "StreamArtistIdentityAuthority",
            "identityRewindExtension",
            _word(vm.computeCreateAddress(factory.lastParent(), 2))
        );
        if (wrongRuntime) return hex"00";
        return type(SlotBoundaryIdentityProduct).runtimeCode;
    }
}

contract SlotBoundaryHarness is StreamCurrentFinalityArtifacts {
    address internal graphOperator;
    SlotBoundaryRuntimeWitness internal witness;

    constructor() {
        graphOperator = address(this);
    }

    function configure(SlotBoundaryRuntimeWitness w) external {
        witness = w;
    }

    function reserve(bool linked) external returns (StreamDeploymentSlot slot, address expected) {
        return linked ? _slot() : _originalSlot();
    }

    function deploy(
        bool linked,
        StreamDeploymentSlot slot,
        address expected,
        bytes calldata creation,
        bytes calldata args,
        bytes calldata runtime
    ) external returns (address) {
        return linked
            ? _deploySlot(slot, expected, creation, args, runtime)
            : _originalDeploySlot(slot, expected, creation, args, runtime);
    }

    function facade(bool linked, StreamCurrentTestSlots.FacadeContext calldata c)
        external
        returns (address)
    {
        return address(
            linked
                ? _deploySplitArtistFacade(
                    type(SlotBoundaryFacadeProduct).creationCode,
                    c.operator_,
                    c.factory_,
                    c.p,
                    c.deploymentHash,
                    c.uri,
                    c.manifestHash
                )
                : _originalFacade(
                    type(SlotBoundaryFacadeProduct).creationCode,
                    c.operator_,
                    c.factory_,
                    c.p,
                    c.deploymentHash,
                    c.uri,
                    c.manifestHash
                )
        );
    }

    function identity(bool linked, StreamCurrentTestSlots.IdentityContext calldata c)
        external
        returns (address)
    {
        return linked
            ? _deploySplitArtistIdentity(
                type(SlotBoundaryIdentityProduct).creationCode, c.operator_, c.factory_, c.p
            )
            : _originalIdentity(
                type(SlotBoundaryIdentityProduct).creationCode, c.operator_, c.factory_, c.p
            );
    }

    function _runtime(
        string memory path,
        string[] memory declarations,
        bytes memory creation,
        RuntimeValue[] memory values
    ) internal view override returns (bytes memory) {
        return witness.inspect(path, declarations, creation, values);
    }

    function _artifact(string memory name) internal pure virtual returns (string memory) {
        return string.concat("slot-boundary/", name, ".json");
    }

    function _originalSlot() internal returns (StreamDeploymentSlot slot, address expected) {
        slot = new StreamDeploymentSlot(graphOperator);
        expected = slot.product();
        require(
            slot.operator() == graphOperator && !slot.consumed()
                && graphVm.getNonce(address(slot)) == 1,
            "fresh operator-owned CREATE coordinate"
        );
        require(
            expected == graphVm.computeCreateAddress(address(slot), 1), "exact product reservation"
        );
    }

    function _originalDeploySlot(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory creation,
        bytes memory args,
        bytes memory runtime
    ) internal returns (address product) {
        require(
            slot.operator() == graphOperator && slot.product() == expected && !slot.consumed(),
            "original operator reservation"
        );
        require(graphVm.getNonce(address(slot)) == 1, "only first CREATE admitted");
        product = slot.deploy(bytes.concat(creation, args), keccak256(runtime));
        require(
            product == expected && graphVm.getNonce(address(slot)) == 2 && slot.consumed(),
            "one original product CREATE"
        );
        require(keccak256(product.code) == keccak256(runtime), "full actual runtime bytes");
    }

    function _originalFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    ) internal returns (StreamArtistOnboardingRegistry) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        for (uint8 i; i < 3; ++i) {
            children[i] =
                StreamArtistExtensionFactory(factory_).deployRegistry(i + 4, slot.product(), p[2]);
        }
        RuntimeValue[] memory v = new RuntimeValue[](14);
        string memory name = "StreamArtistOnboardingRegistry";
        v[0] = _runtimeValue("artist", name, "core", _addressWord(p[0]));
        v[1] = _runtimeValue("artist", name, "mintManager", _addressWord(p[1]));
        v[2] = _runtimeValue("artist", name, "operationCoordinator", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", name, "registryWriterExtension", _addressWord(children[0]));
        v[4] = _runtimeValue("artist", name, "registryReadExtension", _addressWord(children[1]));
        v[5] = _runtimeValue(
            "artist", name, "registryFinalityReadExtension", _addressWord(children[2])
        );
        v[6] = _runtimeValue("artist", name, "archivalCoverage", _addressWord(p[4]));
        v[7] = _runtimeValue("artist", name, "archivalCoverageCodeHash", p[4].codehash);
        v[8] = _runtimeValue(
            "artist",
            name,
            "archivalCoverageConfigurationHash",
            StreamArtistEstateCoverage.admit(p[0], p[1], p[3], p[4])
        );
        v[9] = _runtimeValue(
            "parameters", "StreamGasParameterHost", "governanceAuthority", _addressWord(p[3])
        );
        v[10] = _runtimeValue(
            "modules",
            "StreamModuleBase",
            "_schemaHash",
            keccak256("6529stream.artist-onboarding.v1")
        );
        v[11] = _runtimeValue("modules", "StreamModuleBase", "_supersedes", bytes32(0));
        v[12] =
            _runtimeValue("modules", "StreamModuleBase", "_deploymentManifestHash", deploymentHash);
        v[13] = _runtimeValue("modules", "StreamModuleBase", "_manifestHash", manifestHash);
        string[] memory parents = new string[](2);
        parents[0] = "StreamGasParameterHost";
        parents[1] = "StreamModuleBase";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        address host = slot.deploy(
            bytes.concat(
                creation,
                abi.encode(
                    p[0],
                    p[1],
                    p[2],
                    p[3],
                    p[4],
                    deploymentHash,
                    uri,
                    manifestHash,
                    factory_,
                    children
                )
            ),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split facade runtime"
        );
        return StreamArtistOnboardingRegistry(payable(host));
    }

    function _originalIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    ) internal returns (address host) {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(operator_);
        address[3] memory children;
        address[6] memory pins = [slot.product(), p[0], p[1], p[2], p[3], p[4]];
        for (uint8 i; i < 3; ++i) {
            children[i] = StreamArtistExtensionFactory(factory_).deployIdentity(i + 1, pins);
        }
        RuntimeValue[] memory v = new RuntimeValue[](13);
        string memory name = "StreamArtistIdentityAuthority";
        v[0] = _runtimeValue("artist", "StreamArtistOwner", "artistRegistry", _addressWord(p[0]));
        v[1] = _runtimeValue(
            "artist", "StreamArtistOwner", "operationCoordinator", _addressWord(p[1])
        );
        v[2] = _runtimeValue("artist", "StreamArtistOwner", "archiveV2", _addressWord(p[2]));
        v[3] = _runtimeValue("artist", "StreamArtistOwner", "core", _addressWord(p[3]));
        v[4] = _runtimeValue("artist", "StreamArtistOwner", "mintManager", _addressWord(p[4]));
        v[5] = _runtimeValue(
            "artist", "StreamArtistOwner", "deploymentChainId", bytes32(block.chainid)
        );
        v[6] = _runtimeValue(
            "artist", "StreamArtistOwner", "domainId", keccak256("domain:identity_authority")
        );
        v[7] = _runtimeValue(
            "artist",
            name,
            "artistWindowAuthority",
            _addressWord(StreamArtistTimingState.canonicalAuthority(p[3], p[4]))
        );
        v[8] = _runtimeValue("artist", name, "identityWriterExtension", _addressWord(children[0]));
        v[9] = _runtimeValue("artist", name, "identityEstateExtension", _addressWord(children[1]));
        v[10] =
            _runtimeValue("artist", name, "identityRecoveryExtension", _addressWord(children[2]));
        // The real Identity constructor creates these children in order through fixed
        // delegatecalled deployment libraries. Both CREATEs execute in the new host.
        v[11] = _runtimeValue(
            "artist",
            name,
            "identityAdjudicationExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 1))
        );
        v[12] = _runtimeValue(
            "artist",
            name,
            "identityRewindExtension",
            _addressWord(graphVm.computeCreateAddress(slot.product(), 2))
        );
        string[] memory parents = new string[](1);
        parents[0] = "StreamArtistOwner";
        bytes memory runtime = _productRuntime(name, parents, creation, v);
        host = slot.deploy(
            bytes.concat(creation, abi.encode(p[0], p[1], p[2], p[3], p[4], factory_, children)),
            keccak256(runtime)
        );
        require(
            host == slot.product() && keccak256(host.code) == keccak256(runtime),
            "complete split Identity runtime"
        );
    }

    function _productRuntime(
        string memory name,
        string[] memory parents,
        bytes memory creation,
        RuntimeValue[] memory values
    ) internal view returns (bytes memory) {
        string[] memory declarations = new string[](parents.length + 1);
        declarations[0] = _artifact(name);
        for (uint256 i; i < parents.length; ++i) {
            declarations[i + 1] = _artifact(parents[i]);
        }
        return _runtime(declarations[0], declarations, creation, values);
    }

    function _runtimeValue(
        string memory domain,
        string memory name,
        string memory variable,
        bytes32 value
    ) private pure returns (RuntimeValue memory) {
        return RuntimeValue(
            string.concat("smart-contracts/domains/", domain, "/", name, ".sol"),
            name,
            variable,
            value
        );
    }

    function _addressWord(address value) private pure returns (bytes32) {
        return bytes32(uint256(uint160(value)));
    }

    function _slot() internal returns (StreamDeploymentSlot slot, address expected) {
        return StreamCurrentTestSlots.reserve(graphOperator);
    }

    function _deploySlot(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory creation,
        bytes memory args,
        bytes memory runtime
    ) internal returns (address product) {
        return StreamCurrentTestSlots.deploySlot(
            graphOperator, slot, expected, creation, args, runtime
        );
    }

    function _deploySplitArtistFacade(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p,
        bytes32 deploymentHash,
        string memory uri,
        bytes32 manifestHash
    ) internal returns (StreamArtistOnboardingRegistry) {
        StreamCurrentTestSlots.FacadeContext memory c =
            StreamCurrentTestSlots.FacadeContext(
                operator_, factory_, p, deploymentHash, uri, manifestHash
            );
        StreamCurrentTestSlots.SplitPlan memory plan = StreamCurrentTestSlots.prepareFacade(c);
        bytes memory runtime = _productRuntime(plan.name, plan.parents, creation, plan.values);
        return StreamArtistOnboardingRegistry(
            payable(StreamCurrentTestSlots.finishFacade(c, plan, creation, runtime))
        );
    }

    function _deploySplitArtistIdentity(
        bytes memory creation,
        address operator_,
        address factory_,
        address[5] memory p
    ) internal returns (address host) {
        StreamCurrentTestSlots.IdentityContext memory c =
            StreamCurrentTestSlots.IdentityContext(operator_, factory_, p);
        StreamCurrentTestSlots.SplitPlan memory plan = StreamCurrentTestSlots.prepareIdentity(c);
        bytes memory runtime = _productRuntime(plan.name, plan.parents, creation, plan.values);
        return StreamCurrentTestSlots.finishIdentity(c, plan, creation, runtime);
    }
}

contract SlotBoundaryArtifactRejectHarness is SlotBoundaryHarness {
    function _artifact(string memory) internal pure override returns (string memory) {
        revert("artifact hook rejected");
    }
}

contract StreamCurrentSlotBoundaryTest {
    SlotBoundaryVm private constant vm =
        SlotBoundaryVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    SlotBoundaryHarness private host;
    SlotBoundaryFactory private factory;
    SlotBoundaryRuntimeWitness private witness;
    StreamCurrentTestSlots.FacadeContext private facade;
    StreamCurrentTestSlots.IdentityContext private identity;

    function setUp() public {
        _wire(new SlotBoundaryHarness());
    }

    function _wire(SlotBoundaryHarness h) private {
        host = h;
        factory = new SlotBoundaryFactory(address(h));
        witness = new SlotBoundaryRuntimeWitness(address(h), factory);
        SlotBoundaryReadDouble[] memory reads = new SlotBoundaryReadDouble[](7);
        for (uint256 i; i < 7; ++i) {
            reads[i] = new SlotBoundaryReadDouble(address(h), i);
        }
        for (uint256 i; i < 7; ++i) {
            reads[i].configure(
                address(reads[0]), address(reads[2]), address(reads[3]), address(reads[5])
            );
        }
        facade = StreamCurrentTestSlots.FacadeContext(
            address(h),
            address(factory),
            [
                address(reads[0]),
                address(reads[1]),
                address(reads[6]),
                address(reads[3]),
                address(reads[4])
            ],
            keccak256("slot boundary deployment"),
            "urn:slot-boundary:full:constructor-uri",
            keccak256("slot boundary manifest")
        );
        identity = StreamCurrentTestSlots.IdentityContext(
            address(h),
            address(factory),
            [
                address(reads[2]),
                address(reads[6]),
                address(reads[4]),
                address(reads[0]),
                address(reads[1])
            ]
        );
        witness.configure(facade, identity, address(reads[5]));
        h.configure(witness);
    }

    function _error(string memory reason) private pure returns (bytes memory) {
        return abi.encodeWithSignature("Error(string)", reason);
    }

    function _simpleArgs() private pure returns (bytes memory) {
        return abi.encode(keccak256("complete constructor input"));
    }

    function _rejectDeploy(
        StreamDeploymentSlot slot,
        address expected,
        bytes memory runtime,
        bytes memory error
    ) private {
        for (uint256 i; i < 2; ++i) {
            (bool ok, bytes memory data) = address(host)
                .call(
                    abi.encodeCall(
                        host.deploy,
                        (
                            i == 1,
                            slot,
                            expected,
                            type(SlotBoundarySimpleProduct).creationCode,
                            _simpleArgs(),
                            runtime
                        )
                    )
                );
            require(!ok && keccak256(data) == keccak256(error), "same exact slot rejection");
        }
    }

    function _rejectSplit(bool isFacade, bytes memory error) private {
        for (uint256 i; i < 2; ++i) {
            bytes memory callData = isFacade
                ? abi.encodeCall(host.facade, (i == 1, facade))
                : abi.encodeCall(host.identity, (i == 1, identity));
            (bool ok, bytes memory data) = address(host).call(callData);
            require(!ok && keccak256(data) == keccak256(error), "same exact split rejection");
        }
    }

    function _reservation() private view returns (address slot, address product) {
        slot = vm.computeCreateAddress(address(host), vm.getNonce(address(host)));
        product = vm.computeCreateAddress(slot, 1);
    }

    function _expectThirdFactoryCall(bool isFacade, address product, uint64 count) private {
        bytes memory data;
        if (isFacade) {
            data = abi.encodeCall(factory.deployRegistry, (uint8(6), product, facade.p[2]));
        } else {
            address[6] memory pins =
                [product, identity.p[0], identity.p[1], identity.p[2], identity.p[3], identity.p[4]];
            data = abi.encodeCall(factory.deployIdentity, (uint8(3), pins));
        }
        vm.expectCall(address(factory), data, count);
    }

    function _rolledBack(address slot, address product, uint64 hostNonce, uint64 factoryNonce)
        private
        view
    {
        require(
            vm.getNonce(address(host)) == hostNonce
                && vm.getNonce(address(factory)) == factoryNonce,
            "host and factory CREATE nonces roll back"
        );
        require(
            slot.code.length == 0 && product.code.length == 0 && factory.count() == 0
                && factory.transcript() == bytes32(0),
            "slot product and factory state roll back"
        );
        for (uint256 i; i < 3; ++i) {
            require(factory.children(i) == address(0), "child records roll back");
            require(
                vm.computeCreateAddress(address(factory), factoryNonce + i).code.length == 0,
                "actual factory child CREATEs roll back"
            );
        }
    }

    function _splitDigest(bool isFacade, address product, address slot)
        private
        view
        returns (bytes32)
    {
        address[3] memory children = [factory.children(0), factory.children(1), factory.children(2)];
        require(
            factory.count() == 3 && factory.lastParent() == product,
            "three children bound to original product"
        );
        StreamDeploymentSlot coordinate = StreamDeploymentSlot(slot);
        require(
            coordinate.operator() == address(host) && coordinate.product() == product
                && coordinate.consumed(),
            "original operator and consumed coordinate"
        );
        require(vm.getNonce(slot) == 2 && vm.getNonce(product) == 1, "one actual product CREATE");
        bytes32 argsHash;
        if (isFacade) {
            require(
                SlotBoundaryFacadeProduct(product).creator() == slot,
                "facade constructor sees original slot"
            );
            argsHash = keccak256(
                abi.encode(
                    facade.p[0],
                    facade.p[1],
                    facade.p[2],
                    facade.p[3],
                    facade.p[4],
                    facade.deploymentHash,
                    facade.uri,
                    facade.manifestHash,
                    facade.factory_,
                    children
                )
            );
            require(
                SlotBoundaryFacadeProduct(product).argumentsHash() == argsHash
                    && keccak256(product.code)
                        == keccak256(type(SlotBoundaryFacadeProduct).runtimeCode),
                "all facade constructor and runtime bytes"
            );
        } else {
            require(
                SlotBoundaryIdentityProduct(product).creator() == slot,
                "identity constructor sees original slot"
            );
            argsHash = keccak256(
                abi.encode(
                    identity.p[0],
                    identity.p[1],
                    identity.p[2],
                    identity.p[3],
                    identity.p[4],
                    identity.factory_,
                    children
                )
            );
            require(
                SlotBoundaryIdentityProduct(product).argumentsHash() == argsHash
                    && keccak256(product.code)
                        == keccak256(type(SlotBoundaryIdentityProduct).runtimeCode),
                "all identity constructor and runtime bytes"
            );
        }
        return keccak256(
            abi.encode(
                slot,
                slot.code,
                product,
                product.code,
                argsHash,
                factory.transcript(),
                children,
                vm.getNonce(address(host)),
                vm.getNonce(address(factory))
            )
        );
    }

    function _differentialSplit(bool isFacade) private {
        (address slot, address predicted) = _reservation();
        uint256 snapshot = vm.snapshotState();
        address old = isFacade ? host.facade(false, facade) : host.identity(false, identity);
        require(old == predicted, "historical product coordinate");
        bytes32 oldDigest = _splitDigest(isFacade, old, slot);
        require(vm.revertToState(snapshot), "restore original host/factory nonces");
        address current = isFacade ? host.facade(true, facade) : host.identity(true, identity);
        require(
            current == old && _splitDigest(isFacade, current, slot) == oldDigest,
            "complete original versus linked split transcript"
        );
    }

    function testReservePreservesCreatorOperatorAndFirstProductNonce() public {
        uint64 nonce = vm.getNonce(address(host));
        uint256 snapshot = vm.snapshotState();
        (StreamDeploymentSlot old, address oldProduct) = host.reserve(false);
        bytes memory oldCode = address(old).code;
        require(vm.revertToState(snapshot), "restore slot creator nonce");
        (StreamDeploymentSlot current, address product) = host.reserve(true);
        require(
            address(current) == address(old) && product == oldProduct
                && keccak256(address(current).code) == keccak256(oldCode),
            "full original slot runtime and addresses"
        );
        require(
            address(current) == vm.computeCreateAddress(address(host), nonce)
                && product == vm.computeCreateAddress(address(current), 1),
            "exact host and slot CREATE coordinates"
        );
        require(
            current.operator() == address(host) && !current.consumed()
                && vm.getNonce(address(current)) == 1 && vm.getNonce(address(host)) == nonce + 1,
            "fresh operator coordinate and nonces"
        );
    }

    function testSlotDeployPreservesCompleteBytesAndEvent() public {
        (StreamDeploymentSlot slot, address expected) = host.reserve(false);
        uint256 snapshot = vm.snapshotState();
        vm.recordLogs();
        address old = host.deploy(
            false,
            slot,
            expected,
            type(SlotBoundarySimpleProduct).creationCode,
            _simpleArgs(),
            type(SlotBoundarySimpleProduct).runtimeCode
        );
        SlotBoundaryVm.Log[] memory oldLogs = vm.getRecordedLogs();
        require(vm.revertToState(snapshot), "restore reserved coordinate");
        vm.recordLogs();
        address current = host.deploy(
            true,
            slot,
            expected,
            type(SlotBoundarySimpleProduct).creationCode,
            _simpleArgs(),
            type(SlotBoundarySimpleProduct).runtimeCode
        );
        SlotBoundaryVm.Log[] memory logs = vm.getRecordedLogs();
        require(
            current == old && current == expected && slot.consumed()
                && vm.getNonce(address(slot)) == 2,
            "same consumed product coordinate"
        );
        require(
            SlotBoundarySimpleProduct(current).creator() == address(slot)
                && SlotBoundarySimpleProduct(current).argumentsHash()
                    == keccak256("complete constructor input"),
            "original creator and constructor input"
        );
        require(
            keccak256(current.code) == keccak256(type(SlotBoundarySimpleProduct).runtimeCode),
            "full real product runtime"
        );
        require(
            logs.length == 1 && keccak256(abi.encode(logs)) == keccak256(abi.encode(oldLogs)),
            "complete deployment event preserved"
        );
        require(
            logs[0].emitter == address(slot)
                && logs[0].topics[0] == keccak256("ProductDeployed(address,bytes32,bytes32)")
                && logs[0].topics[1] == bytes32(uint256(uint160(expected))),
            "original event identity"
        );
    }

    function testWrongExpectedCoordinateRejectedBeforeCreate() public {
        (StreamDeploymentSlot slot, address expected) = host.reserve(false);
        _rejectDeploy(
            slot,
            address(uint160(expected) ^ 1),
            type(SlotBoundarySimpleProduct).runtimeCode,
            _error("original operator reservation")
        );
        require(
            !slot.consumed() && vm.getNonce(address(slot)) == 1 && expected.code.length == 0,
            "no product side effects"
        );
    }

    function testWrongOperatorRejectedByBothPaths() public {
        StreamDeploymentSlot slot = new StreamDeploymentSlot(address(this));
        _rejectDeploy(
            slot,
            slot.product(),
            type(SlotBoundarySimpleProduct).runtimeCode,
            _error("original operator reservation")
        );
        require(
            !slot.consumed() && vm.getNonce(address(slot)) == 1, "wrong operator never consumes"
        );
    }

    function testConsumedSlotRejectedByBothPaths() public {
        (StreamDeploymentSlot slot, address expected) = host.reserve(true);
        host.deploy(
            true,
            slot,
            expected,
            type(SlotBoundarySimpleProduct).creationCode,
            _simpleArgs(),
            type(SlotBoundarySimpleProduct).runtimeCode
        );
        _rejectDeploy(
            slot,
            expected,
            type(SlotBoundarySimpleProduct).runtimeCode,
            _error("original operator reservation")
        );
        require(slot.consumed() && vm.getNonce(address(slot)) == 2, "no second product CREATE");
    }

    function testRuntimeMismatchRollsBackAndRetriesSameCreationBytes() public {
        (StreamDeploymentSlot slot, address expected) = host.reserve(false);
        bytes memory reason = abi.encodeWithSelector(
            StreamDeploymentSlot.RuntimeMismatch.selector,
            keccak256(type(SlotBoundarySimpleProduct).runtimeCode),
            keccak256(hex"00")
        );
        _rejectDeploy(slot, expected, hex"00", reason);
        require(
            !slot.consumed() && vm.getNonce(address(slot)) == 1 && expected.code.length == 0,
            "runtime failure rolls back CREATE and consumption"
        );
        require(
            host.deploy(
                true,
                slot,
                expected,
                type(SlotBoundarySimpleProduct).creationCode,
                _simpleArgs(),
                type(SlotBoundarySimpleProduct).runtimeCode
            ) == expected,
            "same creation bytes retry"
        );
    }

    function testFacadePreservesFactoryCallerPinsHooksConstructorAndRuntime() public {
        _differentialSplit(true);
    }

    function testIdentityPreservesFactoryCallerPinsHooksConstructorAndRuntime() public {
        _differentialSplit(false);
    }

    function _factoryRollback(bool isFacade) private {
        (address slot, address product) = _reservation();
        uint64 hn = vm.getNonce(address(host));
        uint64 fn = vm.getNonce(address(factory));
        factory.failures(3, false);
        _expectThirdFactoryCall(isFacade, product, 3);
        _rejectSplit(isFacade, _error("factory late failure"));
        _rolledBack(slot, product, hn, fn);
        factory.failures(0, false);
        address deployed = isFacade ? host.facade(true, facade) : host.identity(true, identity);
        require(deployed == product, "identical split inputs retry original coordinate");
        _splitDigest(isFacade, deployed, slot);
    }

    function testFacadeFactoryFailureRollsBackAndRetriesIdenticalInputs() public {
        _factoryRollback(true);
    }

    function testIdentityFactoryFailureRollsBackAndRetriesIdenticalInputs() public {
        _factoryRollback(false);
    }

    function testRuntimeHookFailureStaysAfterFactoryCallsAndRollsBack() public {
        (address slot, address product) = _reservation();
        uint64 hn = vm.getNonce(address(host));
        uint64 fn = vm.getNonce(address(factory));
        witness.failures(true, false);
        _expectThirdFactoryCall(true, product, 3);
        _rejectSplit(true, _error("runtime hook rejected"));
        _rolledBack(slot, product, hn, fn);
        witness.failures(false, false);
        require(host.facade(true, facade) == product, "identical hook retry coordinate");
        _splitDigest(true, product, slot);
    }

    function testArtifactHookFailureStaysAfterFactoryCalls() public {
        _wire(new SlotBoundaryArtifactRejectHarness());
        (address slot, address product) = _reservation();
        uint64 hn = vm.getNonce(address(host));
        uint64 fn = vm.getNonce(address(factory));
        _expectThirdFactoryCall(true, product, 2);
        _rejectSplit(true, _error("artifact hook rejected"));
        _rolledBack(slot, product, hn, fn);
    }

    function testFacadeConstructorFailureRollsBackAndRetriesIdenticalInputs() public {
        (address slot, address product) = _reservation();
        uint64 hn = vm.getNonce(address(host));
        uint64 fn = vm.getNonce(address(factory));
        factory.failures(0, true);
        _expectThirdFactoryCall(true, product, 3);
        _rejectSplit(true, abi.encodeWithSelector(StreamDeploymentSlot.DeploymentFailed.selector));
        _rolledBack(slot, product, hn, fn);
        factory.failures(0, false);
        require(host.facade(true, facade) == product, "identical constructor input retry");
        _splitDigest(true, product, slot);
    }

    function testIdentityRuntimeFailureRollsBackAndRetriesIdenticalInputs() public {
        (address slot, address product) = _reservation();
        uint64 hn = vm.getNonce(address(host));
        uint64 fn = vm.getNonce(address(factory));
        witness.failures(false, true);
        _expectThirdFactoryCall(false, product, 3);
        _rejectSplit(
            false,
            abi.encodeWithSelector(
                StreamDeploymentSlot.RuntimeMismatch.selector,
                keccak256(type(SlotBoundaryIdentityProduct).runtimeCode),
                keccak256(hex"00")
            )
        );
        _rolledBack(slot, product, hn, fn);
        witness.failures(false, false);
        require(host.identity(true, identity) == product, "identical runtime retry inputs");
        _splitDigest(false, product, slot);
    }
}
