// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../regression/legacy/helpers/CharacterizationTestBase.sol";
import "./GovernedParameterTestMocks.sol";
import "../../smart-contracts/domains/mint/StreamPrivateSaleAdapter.sol";
import "../../smart-contracts/domains/modules/StreamModuleRegistry.sol";
import "../../smart-contracts/vendor/openzeppelin/ERC721.sol";

/// @dev Explicit target-side role/governance seams; actual Executor/role ceremony is integration work.
contract PrivateSaleAuthorityMock is MockGovernedParameterAuthority {
    address public roleRegistry;
    constructor() MockGovernedParameterAuthority(true) { }

    function setRoles(address r) external {
        roleRegistry = r;
    }
}

contract PrivateSaleRolesMock {
    address public owner;
    mapping(bytes32 => mapping(address => bool)) public hasRole;

    constructor(address a) {
        owner = a;
    }

    function grant(bytes32 role, address account) external {
        hasRole[role][account] = true;
    }
}

/// @dev Core identity/royalty seam around real ERC721 transfers, not current Core composition.
contract PrivateSaleCoreMock is ERC721 {
    address public registry;
    address public royaltyReceiver;
    uint256 public royaltyBps = 1000;
    bool public failRoyalty;
    mapping(uint256 => uint8) public lifecycle;

    constructor(address r) ERC721("Consignment fixture", "CF") {
        registry = r;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == 0x2a55205a || super.supportsInterface(id);
    }

    function mint(address receiver, uint256 id) external {
        lifecycle[id] = 2;
        _mint(receiver, id);
    }

    function setRoyalty(address receiver, uint256 bps, bool fail) external {
        royaltyReceiver = receiver;
        royaltyBps = bps;
        failRoyalty = fail;
    }

    function setLifecycle(uint256 id, uint8 status) external {
        lifecycle[id] = status;
    }

    function royaltyInfo(uint256, uint256 price) external view returns (address, uint256) {
        require(!failRoyalty, "royalty read failed");
        return (royaltyReceiver, price * royaltyBps / 10000);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return lifecycle[id];
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (lifecycle[id] != 0, 1, id, lifecycle[id] == 3);
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        return (
            registry,
            registry.codehash,
            false,
            kind,
            type(IStreamModuleRegistry).interfaceId,
            registry,
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
    }
}

contract PrivateSaleRecipient {
    bool public rejectMoney;
    bool public rejectNft;
    bool public valid = true;
    address public callback;
    bytes public callbackData;
    bool public callbackSucceeded;
    bytes public callbackResult;

    function configure(bool money, bool nft) external {
        rejectMoney = money;
        rejectNft = nft;
    }

    function configureCallback(address target, bytes calldata data) external {
        callback = target;
        callbackData = data;
    }

    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4) {
        return valid ? bytes4(0x1626ba7e) : bytes4(0xffffffff);
    }

    function execute(address target, uint256 value, bytes calldata data)
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory result) = target.call{ value: value }(data);
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
        return result;
    }

    receive() external payable {
        require(!rejectMoney, "no money");
        if (callback != address(0)) {
            (callbackSucceeded, callbackResult) = callback.call(callbackData);
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        require(!rejectNft, "no nft");
        if (callback != address(0)) {
            (callbackSucceeded, callbackResult) = callback.call(callbackData);
        }
        return 0x150b7a02;
    }
}

abstract contract PrivateSaleTestBase is CharacterizationTestBase {
    uint256 internal constant PLATFORM_KEY = 0x331;
    uint256 internal constant OWNER_KEY = 0x332;
    uint256 internal constant BUYER_KEY = 0x333;
    address internal consignor;
    address internal buyer;
    address internal platform;
    PrivateSaleAuthorityMock internal authority;
    PrivateSaleRolesMock internal roles;
    StreamModuleRegistry internal registry;
    PrivateSaleCoreMock internal core;
    StreamPrivateSaleAdapter internal sale;
    PrivateSaleRecipient internal royalty;
    uint256 internal actionNonce;

    function setUp() public virtual {
        vm.warp(1000);
        consignor = vm.addr(OWNER_KEY);
        buyer = vm.addr(BUYER_KEY);
        platform = vm.addr(PLATFORM_KEY);
        authority = new PrivateSaleAuthorityMock();
        roles = new PrivateSaleRolesMock(address(authority));
        authority.setRoles(address(roles));
        registry = new StreamModuleRegistry(
            IStreamGovernanceExecutor(address(authority)), keccak256("registry"), "ipfs://registry"
        );
        core = new PrivateSaleCoreMock(address(registry));
        royalty = new PrivateSaleRecipient();
        core.setRoyalty(address(royalty), 1000, false);
        sale = _newSale(platform, address(this));
        _register();
        sale.configureCollectionSigner(1, keccak256("explicit collection signer authority"), true);
        vm.deal(buyer, 100 ether);
        core.mint(consignor, 1);
        vm.prank(consignor);
        core.setApprovalForAll(address(sale), true);
    }

    function _newSale(address signer, address configOwner)
        internal
        returns (StreamPrivateSaleAdapter)
    {
        IStreamGasParameterHost.GasParameterConfig[3] memory gasConfigs;
        gasConfigs[0] =
            IStreamGasParameterHost.GasParameterConfig("SALE_ERC1271_GAS_LIMIT", 400000, 350000, 2);
        gasConfigs[1] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_NFT_DELIVERY_GAS_LIMIT", 300000, 150000, 2
        );
        // Planning-only floor. Actual Core and recipient sizing remains integration evidence.
        gasConfigs[2] = IStreamGasParameterHost.GasParameterConfig(
            "SALE_ROYALTY_DELIVERY_GAS_LIMIT", 100000, 30000, 2
        );
        return new StreamPrivateSaleAdapter(
            StreamPrivateSaleAdapter.DeploymentConfig(
                address(core),
                address(registry),
                signer,
                configOwner,
                address(authority),
                address(roles),
                gasConfigs
            )
        );
    }

    function _config(uint8 kind, uint256 token, address who, bytes32 digest)
        internal
        view
        returns (IStreamPrivateSaleAdapter.SaleConfig memory c)
    {
        c.saleKind = kind;
        c.collectionId = 1;
        c.tokenId = token;
        c.consignor = consignor;
        c.buyer = who;
        c.price = 1000;
        c.startTime = 1000;
        c.deadline = 2000;
        c.offerDigest = digest;
        c.signerEvidenceHash = keccak256("explicit collection signer authority");
        c.signerRevision = 1;
        c.signerAuthority = address(this);
        c.secondaryConsignment = true;
    }

    function _authorization(bytes32 id, address who, uint256 price)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleAuthorization memory a)
    {
        IStreamPrivateSaleAdapter.Sale memory stored = sale.saleDetails(id);
        a.chainId = block.chainid;
        a.saleAdapter = address(sale);
        a.collectionId = 1;
        a.saleId = id;
        a.saleKind = stored.config.saleKind;
        address[] memory one = new address[](1);
        one[0] = who;
        a.initialRecipientsHash = keccak256(abi.encode(one));
        a.beneficiariesHash = keccak256(abi.encode(one));
        a.tokenDataArrayHash = keccak256(abi.encode(new bytes[](0)));
        a.mintCommitmentsHash = keccak256(abi.encode(new bytes32[](0)));
        a.payer = who;
        a.executor = who;
        a.unitPrice = price;
        a.quantity = 1;
        a.nonce = keccak256(abi.encode(id, "authorization"));
        a.deadline = 2000;
    }

    function _offer(uint256 token, address who, uint256 price)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleOffer memory o)
    {
        return StreamPrivateSaleTypes.SaleOffer(
            block.chainid,
            address(sale),
            address(core),
            1,
            token,
            0,
            who,
            address(0),
            price,
            keccak256(abi.encode(token, who)),
            2000,
            0
        );
    }

    function _grant(uint256 token, bytes32 ref)
        internal
        view
        returns (StreamPrivateSaleTypes.SaleCustodyGrant memory)
    {
        return StreamPrivateSaleTypes.SaleCustodyGrant(
            block.chainid,
            address(sale),
            address(core),
            token,
            consignor,
            ref,
            keccak256(abi.encode(ref, token)),
            2000
        );
    }

    function _signature(uint256 key, bytes32 digest) internal returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        return abi.encodePacked(r, s, v);
    }

    function _platformProof(StreamPrivateSaleTypes.SaleAuthorization memory a)
        internal
        returns (IStreamPrivateSaleAdapter.Signature memory)
    {
        return IStreamPrivateSaleAdapter.Signature(
            platform, 1, _signature(PLATFORM_KEY, sale.authorizationDigest(a))
        );
    }

    function _deposit(bytes32 id) internal {
        StreamPrivateSaleTypes.SaleCustodyGrant memory g =
            _grant(sale.saleDetails(id).config.tokenId, id);
        vm.prank(consignor);
        sale.depositCustody(id, g, 1, "");
    }

    function _purchase(bytes32 id, uint256 value) internal {
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        vm.prank(buyer);
        sale.purchasePrivate{ value: value }(a, proof);
    }

    function _register() internal {
        StreamModuleRegistration memory r = StreamModuleRegistration(
            address(sale),
            sale.streamModuleType(),
            sale.streamModuleVersion(),
            sale.streamModuleInterfaceId(),
            0,
            address(sale).codehash,
            keccak256("deployment"),
            keccak256("module"),
            "ipfs://module"
        );
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _registrationTransition(r);
        authority.setCurrentAction(true, bytes32(++actionNonce), 1, scope, oldState, newState);
        vm.prank(address(authority));
        registry.registerModule(r);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _expectedChainHash(
        bytes32 previousChainHash,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 recordIndex
    ) internal view returns (bytes32) {
        bytes32 recordHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_RECORD_V1(),
                registration.module,
                registration.moduleType,
                registration.interfaceId,
                registration.moduleVersion,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash
            )
        );
        return keccak256(
            abi.encode(
                registry.STREAM_RECORD_CHAIN_V1(),
                uint256(block.chainid),
                address(registry),
                uint256(0),
                keccak256("MODULE_REGISTRATION"),
                previousChainHash,
                recordHash,
                recordIndex
            )
        );
    }

    function _recordFactsHash(
        ModuleRegistryStatus status,
        StreamModuleRegistration memory registration,
        bytes32 runtimeCodeHash,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                registration.moduleType,
                registration.moduleVersion,
                registration.interfaceId,
                registration.moduleGasLimit,
                runtimeCodeHash,
                registration.deploymentManifestHash,
                registration.moduleManifestHash,
                keccak256(bytes(registration.moduleManifestURI)),
                revision
            )
        );
    }

    function _storedRecordFactsHash(
        StreamModuleRecord memory record,
        ModuleRegistryStatus status,
        uint64 revision
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                uint8(status),
                record.moduleType,
                record.moduleVersion,
                record.interfaceId,
                record.moduleGasLimit,
                record.runtimeCodeHash,
                record.deploymentManifestHash,
                record.moduleManifestHash,
                keccak256(bytes(record.moduleManifestURI)),
                revision
            )
        );
    }

    function _emptyRecordFactsHash() internal pure returns (bytes32) {
        StreamModuleRegistration memory empty;
        return _recordFactsHash(ModuleRegistryStatus.UNKNOWN, empty, bytes32(0), 0);
    }

    function _registrationTransition(StreamModuleRegistration memory registration)
        private
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        uint256 count = registry.moduleCount();
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        uint64 index = uint64(count);
        bytes32 newChainHash =
            _expectedChainHash(chainHash, registration, registration.module.codehash, index);
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                registration.module
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                false,
                _emptyRecordFactsHash(),
                count,
                chainHash,
                recordCount,
                address(0)
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_REGISTRATION_STATE_V1(),
                scopeHash,
                true,
                _recordFactsHash(
                    ModuleRegistryStatus.ACTIVE, registration, registration.module.codehash, 1
                ),
                count + 1,
                newChainHash,
                recordCount + 1,
                registration.module
            )
        );
    }

    function _statusTransition(address moduleAddress, ModuleRegistryStatus newStatus)
        private
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        StreamModuleRecord memory record = registry.moduleRecord(moduleAddress);
        (bytes32 chainHash, uint64 recordCount) = registry.registrationChainHash();
        scopeHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_SCOPE_V1(),
                uint256(block.chainid),
                address(registry),
                moduleAddress
            )
        );
        oldValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, record.status, record.revision),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
        newValueHash = keccak256(
            abi.encode(
                registry.STREAM_MODULE_STATUS_STATE_V1(),
                scopeHash,
                _storedRecordFactsHash(record, newStatus, record.revision + 1),
                registry.moduleCount(),
                chainHash,
                recordCount
            )
        );
    }

    function _status(ModuleRegistryStatus next) internal {
        (bytes32 scope, bytes32 oldState, bytes32 newState) = _statusTransition(address(sale), next);
        uint8 actionClass = uint8(next) > uint8(registry.moduleRecord(address(sale)).status) ? 0 : 1;
        authority.setCurrentAction(
            true, bytes32(++actionNonce), actionClass, scope, oldState, newState
        );
        vm.prank(address(authority));
        registry.setModuleStatus(
            address(sale), next, keccak256("fixture transition"), "ipfs://reason"
        );
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }

    function _raiseGas(bytes32 id, uint256 next) internal {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            sale.gasParameterInfo(id);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(sale),
                id
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        authority.setCurrentAction(
            true,
            bytes32(++actionNonce),
            1,
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failureClass, revision + 1))
        );
        vm.prank(address(authority));
        sale.raiseGasParameter(id, next);
        authority.setCurrentAction(false, 0, 0, 0, 0, 0);
    }
}
