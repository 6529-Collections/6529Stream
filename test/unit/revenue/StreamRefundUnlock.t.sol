// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/mint/StreamRefundUnlock.sol";

interface RefundFactVm {
    function warp(uint256 time) external;
    function expectRevert() external;
}

/// @dev Typed read-boundary doubles only; the final consumer suite owns canonical governance proof.
contract RefundFactCore {
    address public artist;
    bool public collectionHasMaxSupply;
    uint256 public collectionMaxSupply;
    uint256 public collectionMintedEver;

    function setArtist(address a) external {
        artist = a;
    }

    function setSupply(bool limited, uint256 cap, uint256 minted) external {
        collectionHasMaxSupply = limited;
        collectionMaxSupply = cap;
        collectionMintedEver = minted;
    }

    fallback() external {
        if (msg.sig == IStreamCorePointers.getSatellitePointer.selector) {
            address a = artist;
            bytes32 hash = a.codehash;
            bytes memory result = abi.encode(
                a,
                hash,
                false,
                bytes32(0),
                bytes4(0),
                address(0),
                uint8(1),
                bytes32(0),
                bytes32(0),
                uint64(1)
            );
            assembly ("memory-safe") { return(add(result, 32), mload(result)) }
        }
        uint256 result;
        if (msg.sig == IStreamCoreCollectionView.collectionHasMaxSupply.selector) {
            result = collectionHasMaxSupply ? 1 : 0;
        } else if (msg.sig == IStreamCoreCollectionView.collectionMaxSupply.selector) {
            result = collectionMaxSupply;
        } else if (msg.sig == IStreamCoreCollectionView.collectionMintedEver.selector) {
            result = collectionMintedEver;
        } else {
            revert("unexpected core selector");
        }
        assembly ("memory-safe") {
            mstore(0, result)
            return(0, 32)
        }
    }
}

contract RefundFactManager {
    uint64 public end = 2000;
    bytes32 public current = bytes32(uint256(1));
    bytes32 public prior;
    uint64 public grace;
    bool public failRead;
    IStreamMintManager.MintCounterConfig private counter;
    address public gate;
    uint64 public value;
    bytes32 public expectedValueKey;

    function setPhase(uint64 e, bool fail) external {
        end = e;
        failRead = fail;
    }

    function setPolicy(bytes32 c, bytes32 p, uint64 g) external {
        current = c;
        prior = p;
        grace = g;
    }

    function setCounter(IStreamMintManager.MintCounterConfig calldata c, uint64 v, address g)
        external
    {
        counter = c;
        value = v;
        gate = g;
    }

    function setExpectedKey(bytes32 key) external {
        expectedValueKey = key;
    }

    function phase(uint256, bytes32)
        external
        view
        returns (bool, IStreamMintManager.MintPhaseConfig memory c)
    {
        require(!failRead, "unavailable");
        c.endTime = end;
        return (true, c);
    }

    function phasePolicyHash(uint256, bytes32) external view returns (bytes32) {
        require(!failRead, "unavailable");
        return current;
    }

    function phasePolicyGrace(uint256, bytes32) external view returns (bytes32, uint64) {
        return (prior, grace);
    }

    function phaseCounterIds(uint256, bytes32) external pure returns (bytes32[] memory ids) {
        ids = new bytes32[](1);
        ids[0] = bytes32(uint256(7));
    }

    function counterConfig(uint256, bytes32, bytes32)
        external
        view
        returns (IStreamMintManager.MintCounterConfig memory)
    {
        return counter;
    }

    function phaseGate(uint256, bytes32)
        external
        view
        returns (IStreamMintManager.MintGateConfig memory c)
    {
        c.gate = gate;
    }

    function mintLedger() external view returns (address) {
        return address(this);
    }

    function counterValue(bytes32 key) external view returns (uint64) {
        require(expectedValueKey == 0 || key == expectedValueKey, "exact counter context");
        return value;
    }

    function previewSubjectKey(
        IStreamMintManager.CounterKeyMode mode,
        uint256 collection,
        bytes32 phaseId,
        bytes32 id,
        address payer,
        address recipient,
        address executor,
        address authorizer,
        bytes32 digest
    ) external pure returns (bytes32) {
        return keccak256(
            abi.encode(
                mode, collection, phaseId, id, payer, recipient, executor, authorizer, digest
            )
        );
    }

    function previewCounterValueKey(
        uint256 collection,
        bytes32 phaseId,
        bytes32 id,
        bytes32 subject
    ) external pure returns (bytes32) {
        return keccak256(abi.encode(collection, phaseId, id, subject));
    }
}

contract RefundFactArtist {
    uint8 public state = 2;
    uint64 public generation = 3;
    bytes32 public identity = bytes32(uint256(4));
    uint8 public authority = 1;
    bytes32 public binding = bytes32(uint256(5));

    function set(uint8 s, uint64 g, bytes32 i, uint8 a, bytes32 b) external {
        state = s;
        generation = g;
        identity = i;
        authority = a;
        binding = b;
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (state, generation, identity, authority, binding);
    }
}

contract RefundFactRegistry {
    mapping(address => uint8) private status;
    bool public malformed;

    function set(address module, uint8 s) external {
        status[module] = s;
    }

    function setMalformed(bool value) external {
        malformed = value;
    }

    function moduleRecord(address module) external view returns (StreamModuleRecord memory r) {
        if (malformed) {
            assembly ("memory-safe") {
                mstore(0, 3)
                return(0, 32)
            }
        }
        r.status = ModuleRegistryStatus(status[module]);
        r.moduleType = bytes32(uint256(1));
        r.moduleVersion = bytes32(uint256(2));
        r.interfaceId = 0x12345678;
        r.runtimeCodeHash = bytes32(uint256(3));
        r.deploymentManifestHash = bytes32(uint256(4));
        r.moduleManifestHash = bytes32(uint256(5));
        r.registeredAt = 1;
        r.statusUpdatedAt = 2;
        r.revision = 2;
    }
}

contract RefundFactHarness {
    function fact(
        StreamRefundUnlock.Context memory x,
        IStreamNativeRefundWindowSale.RefundSaleRecord memory s,
        IStreamNativeRefundWindowSale.RefundPurchaseRecord memory p,
        uint8 r
    ) external view returns (bytes32) {
        return StreamRefundUnlock.reasonHash(x, s, p, r);
    }
}

contract StreamRefundUnlockTest {
    RefundFactVm private constant vm =
        RefundFactVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    RefundFactCore private core;
    RefundFactManager private manager;
    RefundFactArtist private artist;
    RefundFactRegistry private registry;
    RefundFactHarness private harness;
    StreamRefundUnlock.Context private context;
    IStreamNativeRefundWindowSale.RefundSaleRecord private sale;
    IStreamNativeRefundWindowSale.RefundPurchaseRecord private purchase;

    function setUp() public {
        vm.warp(1000);
        core = new RefundFactCore();
        manager = new RefundFactManager();
        artist = new RefundFactArtist();
        registry = new RefundFactRegistry();
        harness = new RefundFactHarness();
        core.setArtist(address(artist));
        context.support.core = address(core);
        context.support.manager = IStreamMintManager(address(manager));
        context.support.artists = IStreamArtistAttribution(address(artist));
        context.support.artistHash = address(artist).codehash;
        context.support.artistGas = 100000;
        context.registry = address(registry);
        context.registryHash = address(registry).codehash;
        context.coreHash = address(core).codehash;
        context.managerHash = address(manager).codehash;
        context.recorder = address(0x999);
        sale.config.collectionId = 1;
        sale.config.phaseId = bytes32(uint256(6));
        sale.config.mintPolicyHash = bytes32(uint256(1));
        purchase.artistId = bytes32(uint256(4));
        purchase.bindingGeneration = 3;
        purchase.bindingHash = bytes32(uint256(5));
        purchase.referencedGate = address(0x777);
        purchase.authorization.payer = address(0xAA);
        purchase.authorization.recipient = address(0xBB);
        purchase.authorizationDigest = bytes32(uint256(8));
    }

    function _fact(uint8 r) private view returns (bytes32) {
        return harness.fact(context, sale, purchase, r);
    }

    function testPhaseEndEqualityAndReadFailureAreNotPermanentFacts() public {
        vm.warp(2000);
        require(_fact(1) == 0, "end equality still executable");
        vm.warp(2001);
        require(_fact(1) == keccak256("REFUND_PHASE_ENDED"), "past end");
        manager.setPhase(2000, true);
        vm.expectRevert();
        harness.fact(context, sale, purchase, 1);
    }

    function testPolicyGraceIncludesEqualityAndCurrentHashAlwaysWins() public {
        manager.setPolicy(bytes32(uint256(2)), sale.config.mintPolicyHash, 2000);
        vm.warp(2000);
        require(_fact(3) == 0, "inclusive grace");
        vm.warp(2001);
        require(_fact(3) == keccak256("REFUND_MINT_POLICY_UNMATCHABLE"), "expired grace");
        manager.setPolicy(sale.config.mintPolicyHash, 0, 0);
        require(_fact(3) == 0, "current policy");
        manager.setPolicy(bytes32(uint256(3)), bytes32(uint256(2)), 3000);
        require(_fact(3) != 0, "only immediate predecessor accepted");
    }

    function testSupplyAndCounterUseLifetimeAndExactProspectiveConsumption() public {
        core.setSupply(true, 2, 1);
        require(_fact(2) == 0, "one token remains");
        core.setSupply(true, 2, 2);
        require(_fact(2) == keccak256("REFUND_SUPPLY_EXHAUSTED"), "lifetime equality");
        core.setSupply(false, 0, 0);
        IStreamMintManager.MintCounterConfig memory c = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.PAYER,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            10,
            2,
            bytes32(uint256(9))
        );
        bytes32 subject = keccak256(
            abi.encode(
                c.keyMode,
                uint256(1),
                sale.config.phaseId,
                bytes32(uint256(7)),
                purchase.authorization.payer,
                purchase.authorization.recipient,
                address(harness),
                address(0),
                purchase.authorizationDigest
            )
        );
        manager.setExpectedKey(
            keccak256(abi.encode(uint256(1), sale.config.phaseId, bytes32(uint256(7)), subject))
        );
        manager.setCounter(c, 8, address(0));
        require(_fact(2) == 0, "exact cap permitted");
        manager.setCounter(c, 9, address(0));
        require(_fact(2) == keccak256("REFUND_COUNTER_EXHAUSTED"), "increment crosses cap");
        c.keyMode = IStreamMintManager.CounterKeyMode.AUTHORIZER;
        manager.setCounter(c, 9, address(0x778));
        require(_fact(2) == 0, "unknown gate authorizer is not inferred");
    }

    function testOnlyMatchingAttributionGenerationUnlocksAndAuthorityContestIsDistinct() public {
        artist.set(2, 3, purchase.artistId, 4, purchase.bindingHash);
        require(_fact(4) == 0, "authority contest is not attribution dispute");
        artist.set(4, 3, purchase.artistId, 1, purchase.bindingHash);
        require(_fact(4) == keccak256("REFUND_BOUND_ATTRIBUTION_STOPPED"), "matched dispute");
        artist.set(5, 4, purchase.artistId, 1, purchase.bindingHash);
        require(_fact(4) == 0, "later generation");
        artist.set(5, 3, purchase.artistId, 1, bytes32(uint256(9)));
        require(_fact(4) == 0, "other binding");
        core.setArtist(address(0));
        vm.expectRevert();
        harness.fact(context, sale, purchase, 4);
    }

    function testOnlyRecordedModuleIncidentsUnlockAndMalformedReadsDoNot() public {
        registry.set(address(harness), 2);
        require(_fact(5) == 0, "deprecation is grandfathered");
        registry.set(address(0x778), 3);
        require(_fact(5) == 0, "unrelated replacement gate");
        registry.set(purchase.referencedGate, 3);
        require(_fact(5) == keccak256("REFUND_REFERENCED_MODULE_INCIDENT_REVOKED"), "original gate");
        registry.set(purchase.referencedGate, 0);
        registry.set(context.recorder, 3);
        require(_fact(5) != 0, "bound recorder");
        registry.set(context.recorder, 0);
        registry.set(address(harness), 3);
        require(_fact(5) != 0, "adapter incident");
        registry.setMalformed(true);
        vm.expectRevert();
        harness.fact(context, sale, purchase, 5);
    }
}
