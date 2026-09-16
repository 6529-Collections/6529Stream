// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamDelegateRegistryGate.sol";
import "../../../smart-contracts/vendor/openzeppelin/ERC721.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";

/// @dev ABI-level registry fixture with v2 wallet/contract/right inheritance, not upstream bytecode.
contract MintDelegateRegistryFixture {
    mapping(bytes32 => bool) private grants;
    uint256 public responseMode;

    function delegateAll(address to, bytes32 rights, bool enable) external {
        grants[keccak256(abi.encode(msg.sender, to, address(0), rights))] = enable;
    }

    function delegateContract(address to, address target, bytes32 rights, bool enable) external {
        grants[keccak256(abi.encode(msg.sender, to, target, rights))] = enable;
    }

    function setResponseMode(uint256 mode) external {
        responseMode = mode;
    }

    function checkDelegateForContract(address to, address from, address target, bytes32 rights)
        external
        view
        returns (bool)
    {
        uint256 mode = responseMode;
        if (mode == 1) revert("unavailable");
        if (mode == 2) assembly { return(0, 31) }
        if (mode == 3) {
            assembly {
                mstore(0, 1)
                return(0, 64)
            }
        }
        if (mode == 4) {
            assembly {
                mstore(0, 2)
                return(0, 32)
            }
        }
        if (mode == 5) assembly { for { } 1 { } { } }
        return grants[keccak256(abi.encode(from, to, address(0), bytes32(0)))]
            || grants[keccak256(abi.encode(from, to, target, bytes32(0)))]
            || grants[keccak256(abi.encode(from, to, address(0), rights))]
            || grants[keccak256(abi.encode(from, to, target, rights))];
    }
}

/// @dev Receipt-only Core boundary. This fixture does not implement current StreamCore policy.
contract MintDelegateReceiptFixture is ERC721 {
    uint256 public nextId;
    constructor() ERC721("Vault gate receipt", "VGR") { }

    function mint(address recipient) external {
        _safeMint(recipient, ++nextId);
    }
}

/// @dev Typed Manager phase/read/consume boundary; current-stack counters remain separate acceptance.
contract MintDelegateManagerFixture {
    address public core;
    IStreamMintManager.MintGateConfig private configured;
    mapping(bytes32 => bool) public used;

    constructor(address core_) {
        core = core_;
    }

    function setCore(address core_) external {
        core = core_;
    }

    function configure(StreamDelegateRegistryGate gate) external {
        configured = IStreamMintManager.MintGateConfig(
            address(gate),
            gate.gateConfigHash(),
            address(gate).codehash,
            keccak256(abi.encode(gate.MODULE_VERSION(), gate.moduleManifestHash())),
            0,
            500_000
        );
    }

    function setConfigHash(bytes32 hash) external {
        configured.gateConfigHash = hash;
    }

    function setMetadataHash(bytes32 hash) external {
        configured.gateMetadataHash = hash;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory)
    {
        return configured;
    }

    function validate(
        StreamDelegateRegistryGate gate,
        StreamDelegateRegistryGate.MintRequest memory r
    ) public view returns (IStreamMintGate.GateResult memory) {
        return gate.validateMint(
            r.manager,
            r.executor,
            r.collectionId,
            r.phaseId,
            r.payer,
            r.authorizer,
            r.initialRecipients,
            r.beneficiaries,
            r.contextHash,
            r.expectedPolicyHash,
            r.gateData
        );
    }

    function consume(
        StreamDelegateRegistryGate gate,
        StreamDelegateRegistryGate.MintRequest memory r
    ) external {
        IStreamMintGate.GateResult memory result = validate(gate, r);
        require(!used[result.nullifiers[0]], "nonce replay");
        used[result.nullifiers[0]] = true;
        for (uint256 i; i < r.initialRecipients.length; ++i) {
            MintDelegateReceiptFixture(core).mint(r.initialRecipients[i]);
        }
    }
}

contract StreamDelegateRegistryGateTest is CharacterizationTestBase, OfficialSafeFixture {
    address private constant VAULT = address(0xA111);
    address private constant HOT = address(0xA222);
    address private constant EXECUTOR = address(0xA333);
    bytes32 private constant USECASE = keccak256("Stream mint");
    bytes32 private constant NONCE = keccak256("mint nonce");
    MintDelegateRegistryFixture private registry;
    MintDelegateReceiptFixture private receipt;
    MintDelegateManagerFixture private manager;
    StreamDelegateRegistryGate private gate;

    function setUp() public {
        registry = new MintDelegateRegistryFixture();
        receipt = new MintDelegateReceiptFixture();
        manager = new MintDelegateManagerFixture(address(receipt));
        gate = new StreamDelegateRegistryGate(
            address(receipt), address(registry), USECASE, address(0)
        );
        manager.configure(gate);
    }

    function testWalletGrantLiveRevocationAndPayerNotExecutor() public {
        vm.prank(VAULT);
        registry.delegateAll(HOT, USECASE, true);
        IStreamMintGate.GateResult memory result = manager.validate(gate, _request(VAULT));
        require(result.authorizationId != 0 && result.nullifiers.length == 1, "bound identity");
        require(
            result.authorizer == address(0) && result.authorizerKind == 0, "registry not signer"
        );
        require(result.maxQuantity == 1, "quantity");
        require(!gate.isDelegated(VAULT, EXECUTOR, 42), "executor must not replace hot payer");
        vm.prank(VAULT);
        registry.delegateAll(HOT, USECASE, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationNotFound.selector, VAULT, HOT
            )
        );
        manager.validate(gate, _request(VAULT));
    }

    function testCoreScopeAndWildcardRights() public {
        vm.prank(VAULT);
        registry.delegateContract(HOT, address(receipt), USECASE, true);
        require(gate.isDelegated(VAULT, HOT, 42), "Core authority");
        require(gate.isDelegated(VAULT, HOT, 43), "Core covers collections");
        vm.prank(VAULT);
        registry.delegateContract(HOT, address(receipt), USECASE, false);
        vm.prank(VAULT);
        registry.delegateContract(HOT, address(receipt), bytes32(0), true);
        require(gate.isDelegated(VAULT, HOT, 42), "explicit wildcard rights");
    }

    function testCollectionUsecaseCannotAuthorizeAnotherCollectionCoreOrUsecase() public {
        bytes32 rights = gate.collectionDelegationRights(42);
        vm.prank(VAULT);
        registry.delegateContract(HOT, address(receipt), rights, true);
        require(gate.isDelegated(VAULT, HOT, 42), "collection authority");
        require(!gate.isDelegated(VAULT, HOT, 43), "collection separated");
        StreamDelegateRegistryGate anotherUsecase = new StreamDelegateRegistryGate(
            address(receipt), address(registry), keccak256("other usecase"), address(0)
        );
        require(!anotherUsecase.isDelegated(VAULT, HOT, 42), "usecase separated");
        MintDelegateReceiptFixture otherCore = new MintDelegateReceiptFixture();
        StreamDelegateRegistryGate anotherCore = new StreamDelegateRegistryGate(
            address(otherCore), address(registry), USECASE, address(0)
        );
        require(!anotherCore.isDelegated(VAULT, HOT, 42), "Core separated");
    }

    function testWrongUsecaseAndWrongCoreDoNotAuthorize() public {
        vm.prank(VAULT);
        registry.delegateAll(HOT, keccak256("unrelated right"), true);
        vm.prank(VAULT);
        registry.delegateContract(HOT, address(0xBAD), USECASE, true);
        require(!gate.isDelegated(VAULT, HOT, 42), "wrong rights and Core");
    }

    function testRecipientBeneficiaryAndPayerMismatchesFail() public {
        _grant();
        StreamDelegateRegistryGate.MintRequest memory r = _request(VAULT);
        r.initialRecipients[0] = HOT;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
        r = _request(VAULT);
        r.beneficiaries[0] = HOT;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
        r = _request(VAULT);
        r.payer = EXECUTOR;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationNotFound.selector, VAULT, EXECUTOR
            )
        );
        manager.validate(gate, r);
        r.payer = VAULT;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
    }

    function testManagerCoreConfigAndModuleManifestMustMatch() public {
        _grant();
        manager.setCore(address(0xBAD));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationManagerMismatch.selector, address(manager)
            )
        );
        manager.validate(gate, _request(VAULT));
        manager.setCore(address(receipt));
        manager.setConfigHash(keccak256("other config"));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationPhaseMismatch.selector)
        );
        manager.validate(gate, _request(VAULT));
        manager.configure(gate);
        manager.setMetadataHash(keccak256("unbound module manifest"));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationPhaseMismatch.selector)
        );
        manager.validate(gate, _request(VAULT));
    }

    function testWrongManagerAuthorizerAndProofShapeFail() public {
        _grant();
        StreamDelegateRegistryGate.MintRequest memory r = _request(VAULT);
        r.manager = address(this);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationManagerMismatch.selector, address(this)
            )
        );
        manager.validate(gate, r);
        r = _request(VAULT);
        r.authorizer = VAULT;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
        r = _request(VAULT);
        r.gateData = abi.encode(VAULT);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationProofInvalid.selector)
        );
        manager.validate(gate, r);
        r.gateData = abi.encode(VAULT, NONCE, uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationProofInvalid.selector)
        );
        manager.validate(gate, r);
    }

    function testEntireBatchMustDeliverToSingleVault() public {
        _grant();
        StreamDelegateRegistryGate.MintRequest memory r = _request(VAULT);
        r.initialRecipients = new address[](2);
        r.beneficiaries = new address[](2);
        r.initialRecipients[0] = VAULT;
        r.initialRecipients[1] = VAULT;
        r.beneficiaries[0] = VAULT;
        r.beneficiaries[1] = VAULT;
        require(manager.validate(gate, r).maxQuantity == 2, "batch quantity");
        r.initialRecipients[1] = HOT;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
        r.initialRecipients = new address[](0);
        r.beneficiaries = new address[](0);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamDelegateRegistryGate.DelegationRouteInvalid.selector)
        );
        manager.validate(gate, r);
    }

    function testChangedRegistryCodeAndChainFailClosed() public {
        _grant();
        vm.chainId(block.chainid + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationConfigurationInvalid.selector
            )
        );
        gate.isDelegated(VAULT, HOT, 42);
        vm.chainId(block.chainid - 1);
        vm.etch(address(registry), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationRegistryUnavailable.selector,
                address(registry)
            )
        );
        gate.isDelegated(VAULT, HOT, 42);
    }

    function testRegistryRevertShortLongNoncanonicalAndGasExhaustionFailClosed() public {
        _grant();
        for (uint256 mode = 1; mode <= 5; ++mode) {
            registry.setResponseMode(mode);
            vm.expectRevert();
            gate.isDelegated(VAULT, HOT, 42);
        }
    }

    function testInsufficientParentGasFailsClosed() public {
        _grant();
        (bool ok,) = address(gate).staticcall{ gas: 150_000 }(
            abi.encodeCall(gate.isDelegated, (VAULT, HOT, 42))
        );
        require(!ok, "must reserve EIP150 forwarding and return gas");
    }

    function testIdentityBindsRequestWhileNullifierPreventsChangedPayloadReplay() public {
        _grant();
        StreamDelegateRegistryGate.MintRequest memory r = _request(VAULT);
        IStreamMintGate.GateResult memory first = manager.validate(gate, r);
        r.contextHash = keccak256("other context");
        IStreamMintGate.GateResult memory second = manager.validate(gate, r);
        require(first.authorizationId != second.authorizationId, "context bound");
        require(first.nullifiers[0] == second.nullifiers[0], "same nonce remains spent");
        manager.consume(gate, r);
        r.contextHash = keccak256("third context");
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "nonce replay"));
        manager.consume(gate, r);
        require(receipt.ownerOf(1) == VAULT && receipt.balanceOf(HOT) == 0, "vault ownership");
    }

    function testNoncePhaseAndCollectionDomainsAreDistinct() public {
        _grant();
        StreamDelegateRegistryGate.MintRequest memory r = _request(VAULT);
        IStreamMintGate.GateResult memory first = manager.validate(gate, r);
        r.phaseId = keccak256("another phase");
        IStreamMintGate.GateResult memory next = manager.validate(gate, r);
        require(
            first.authorizationId != next.authorizationId
                && first.nullifiers[0] != next.nullifiers[0],
            "phase domain"
        );
        r = _request(VAULT);
        r.collectionId = 43;
        next = manager.validate(gate, r);
        require(
            first.authorizationId != next.authorizationId
                && first.nullifiers[0] != next.nullifiers[0],
            "collection domain"
        );
        r = _request(VAULT);
        r.gateData = abi.encode(VAULT, keccak256("next nonce"));
        next = manager.validate(gate, r);
        require(first.nullifiers[0] != next.nullifiers[0], "new nonce");
    }

    function testOfficialSafe141OwnsDeliveryAndExecutesGrantRevocation() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xD311;
        keys[1] = 0xD312;
        OfficialSafe vault =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9181);
        require(keccak256(bytes(vault.VERSION())) == keccak256("1.4.1"), "actual Safe version");
        require(
            executeSafe(
                vault,
                keys,
                address(registry),
                0,
                abi.encodeCall(registry.delegateContract, (HOT, address(receipt), USECASE, true)),
                0
            ),
            "Safe grant"
        );
        StreamDelegateRegistryGate.MintRequest memory r = _request(address(vault));
        manager.consume(gate, r);
        require(receipt.ownerOf(1) == address(vault), "Safe NFT ownership");
        require(
            receipt.balanceOf(HOT) == 0 && receipt.balanceOf(EXECUTOR) == 0,
            "hot and executor never receive"
        );
        require(
            executeSafe(
                vault,
                keys,
                address(registry),
                0,
                abi.encodeCall(registry.delegateContract, (HOT, address(receipt), USECASE, false)),
                0
            ),
            "Safe revoke"
        );
        r.gateData = abi.encode(address(vault), keccak256("after revoke"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamDelegateRegistryGate.DelegationNotFound.selector, address(vault), HOT
            )
        );
        manager.consume(gate, r);
        require(receipt.nextId() == 1, "revocation prevents later delivery");
    }

    function _grant() private {
        vm.prank(VAULT);
        registry.delegateAll(HOT, USECASE, true);
    }

    function _request(address vault)
        private
        view
        returns (StreamDelegateRegistryGate.MintRequest memory r)
    {
        r.manager = address(manager);
        r.executor = EXECUTOR;
        r.collectionId = 42;
        r.phaseId = keccak256("delegate mint phase");
        r.payer = HOT;
        r.initialRecipients = new address[](1);
        r.initialRecipients[0] = vault;
        r.beneficiaries = new address[](1);
        r.beneficiaries[0] = vault;
        r.expectedPolicyHash = keccak256("bound manager policy");
        r.gateData = abi.encode(vault, NONCE);
    }
}
