// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./helpers/StreamSaleTestBase.sol";
import "../smart-contracts/domains/revenue/StreamRoyaltyResolver.sol";

contract RoyaltyFaultFixture {
    uint8 private _mode;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamRoyaltyResolver).interfaceId || id == type(IERC165).interfaceId;
    }

    function setMode(uint8 mode) external {
        _mode = mode;
    }

    function royaltyReceiverAndBps(address, uint256, uint256, uint256, bool)
        external
        view
        returns (address, uint16)
    {
        uint8 mode = _mode;
        if (mode == 1) revert("royalty fault");
        if (mode == 2) assembly {
            mstore(0, 1)
            return(0, 32)
        }
        if (mode == 3) return (address(0xCAFE), 1001);
        if (mode == 4) assembly {
            mstore(0, shl(160, 1))
            mstore(32, 500)
            return(0, 64)
        }
        if (mode == 5) assembly {
            mstore(0, 0xCAFE)
            mstore(32, 65536)
            return(0, 64)
        }
        if (mode == 6) assembly { for { } 1 { } { } }
        if (mode == 7) return (address(0), 500);
        return (address(0xCAFE), 500);
    }
}

contract StreamRoyaltyResolverTest is StreamSaleTestBase {
    bytes32 private constant PHASE = keccak256("royalty-test-mint");
    bytes32 private constant ROYALTY_POINTER =
        0xafcd60ac064e6f5b3428ca05e721b02c16a658af3989d079e29e38df5fab9c91;
    bytes32 private constant REVENUE_MODULE =
        0x217d16181cfb7c9bb7e1687d0b13ef4b864e9154dc37b60f75a88bec454b5467;
    StreamRoyaltyResolver private resolver;

    function setUp() public {
        _setUpSaleFixture();
        resolver = new StreamRoyaltyResolver(core, factory, address(governance));
        _installResolver(address(resolver));
        _configureSalePhase(PHASE, address(this));
    }

    function testActualCoreInstallsTypedResolverAndDisclosesCollectionSplit() public {
        require(resolver.owner() == address(governance), "executor owns royalty mutations");
        require(
            resolver.supportsInterface(type(IStreamRoyaltyResolver).interfaceId),
            "royalty interface"
        );
        require(resolver.supportsInterface(type(IERC165).interfaceId), "ERC165 interface");
        require(
            !resolver.supportsInterface(0xffffffff) && !resolver.supportsInterface(0x12345678),
            "strict ERC165"
        );
        require(
            core.pointerState(ROYALTY_POINTER).target == address(resolver),
            "installed in actual Core"
        );
        _configureCollection(profile, 690);
        uint256 tokenId = _mint();
        (address receiver, uint256 amount) = core.royaltyInfo(tokenId, 1 ether);
        require(
            receiver == wallet && amount == 0.069 ether, "native ERC2981 returns immutable split"
        );
        (bool funded,) = payable(receiver).call{ value: amount }("");
        require(funded, "marketplace can deposit royalty");
        IStreamSplitWallet(wallet).release(address(0), artist, payable(artist));
        IStreamSplitWallet(wallet).release(address(0), protocol, payable(protocol));
        require(
            artist.balance == 0.0621 ether && protocol.balance == 0.0069 ether,
            "royalty shares withdrawn"
        );
    }

    function testBurnedTokenRetainsCollectionRoyaltyAndUnmappedUsesDefault() public {
        _configureDefault(profile, 500);
        _configureCollection(profile, 690);
        uint256 tokenId = _mint();
        vm.prank(artist);
        core.burn(tokenId);
        (bool mapped, uint256 collectionId,, bool burned) = core.tokenCollectionIdentity(tokenId);
        require(mapped && collectionId == 1 && burned, "Core retained authoritative identity");
        (address receiver, uint256 amount) = core.royaltyInfo(tokenId, 10_000);
        require(receiver == wallet && amount == 690, "burned collection royalty");
        (receiver, amount) = core.royaltyInfo(type(uint256).max, 10_000);
        require(receiver == wallet && amount == 500, "unmapped default, no token arithmetic");
    }

    function testExplicitZeroOverridesDefaultAndMaximumPriceNeverOverflows() public {
        _configureDefault(profile, 1000);
        (address receiver, uint256 amount) = core.royaltyInfo(999, type(uint256).max);
        require(
            receiver == wallet && amount == type(uint256).max / 10,
            "maximum-price royalty remains total"
        );
        _configureCollection(bytes32(0), 0);
        uint256 tokenId = _mint();
        (receiver, amount) = core.royaltyInfo(tokenId, 1 ether);
        require(receiver == address(0) && amount == 0, "explicit collection zero shadows default");
        _configureCollection(profile, 1000);
        (receiver, amount) = core.royaltyInfo(tokenId, 9);
        require(receiver == wallet && amount == 0, "floor rounding preserved");
    }

    function testOnlyExecutorCanConfigureAndInvalidProfilesRatesOrCollectionsFail() public {
        vm.expectRevert();
        resolver.configureDefaultRoyalty(profile, 500);
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (profile, uint16(1001)))
        );
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (keccak256("unknown"), uint16(500)))
        );
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureCollectionRoyalty, (uint256(2), profile, uint16(500)))
        );
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (bytes32(0), uint16(500)))
        );
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (profile, uint16(0)))
        );
        require(
            !resolver.defaultRoyalty().configured && !resolver.collectionRoyalty(1).configured,
            "invalid config no state"
        );
    }

    function testCollectionFreezeSnapshotsInheritedTermsBeforeDefaultChanges() public {
        _configureDefault(profile, 500);
        vm.recordLogs();
        governance.execute(
            address(resolver), abi.encodeCall(resolver.freezeCollectionRoyalty, (uint256(1)))
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 1
                && logs[0].topics[0]
                    == keccak256("RoyaltyFrozen(uint256,bytes32,address,uint16,uint64)"),
            "freeze is observable"
        );
        IStreamRoyaltyResolver.RoyaltyConfig memory item = resolver.collectionRoyalty(1);
        require(
            item.frozen && item.configured && item.profileId == profile && item.wallet == wallet
                && item.royaltyBps == 500,
            "exact inherited freeze"
        );
        _configureDefault(bytes32(0), 0);
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps(address(core), 1, 10_000, 1, true);
        require(receiver == wallet && bps == 500, "default change cannot alter frozen collection");
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureCollectionRoyalty, (uint256(1), profile, uint16(690)))
        );
        vm.expectRevert();
        governance.execute(
            address(resolver), abi.encodeCall(resolver.freezeCollectionRoyalty, (uint256(1)))
        );
    }

    function testFreezingUnconfiguredCollectionPermanentlyCapturesZero() public {
        governance.execute(
            address(resolver), abi.encodeCall(resolver.freezeCollectionRoyalty, (uint256(1)))
        );
        _configureDefault(profile, 500);
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps(address(core), 1, 10_000, 1, true);
        require(
            receiver == address(0) && bps == 0 && resolver.collectionRoyalty(1).frozen,
            "inherited zero cannot drift"
        );
        governance.execute(address(resolver), abi.encodeCall(resolver.freezeDefaultRoyalty, ()));
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (profile, uint16(690)))
        );
    }

    function testReadUsesOnlyCachedStorageAndRejectsAnotherCore() public {
        _configureDefault(profile, 500);
        _configureCollection(profile, 690);
        vm.etch(address(factory), hex"00");
        vm.etch(wallet, hex"00");
        (address receiver, uint16 bps) =
            resolver.royaltyReceiverAndBps{ gas: 25_000 }(address(core), 1, 10_000, 1, true);
        require(receiver == wallet && bps == 690, "cached assignment needs no wallet/factory calls");
        (receiver, bps) = resolver.royaltyReceiverAndBps(address(0xBAD), 1, 10_000, 1, true);
        require(receiver == address(0) && bps == 0, "different Core has no assignment");
        (receiver, bps) = resolver.royaltyReceiverAndBps(address(core), 1, 10_000, 1, false);
        require(receiver == wallet && bps == 500, "only authoritative mapping selects collection");
    }

    function testChangedWalletCodeCannotBeAssigned() public {
        vm.etch(wallet, hex"00");
        vm.expectRevert();
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureDefaultRoyalty, (profile, uint16(500)))
        );
        require(!resolver.defaultRoyalty().configured, "factory verification at assignment");
    }

    function testCoreFailsSoftForResolverFaultsAndMalformedResponses() public {
        RoyaltyFaultFixture fault = new RoyaltyFaultFixture();
        _installResolver(address(fault));
        (address receiver, uint256 amount) = core.royaltyInfo(999, 10_000);
        require(receiver == address(0xCAFE) && amount == 500, "valid exact response");
        for (uint8 mode = 1; mode <= 7; ++mode) {
            fault.setMode(mode);
            (receiver, amount) = core.royaltyInfo(999, 10_000);
            require(receiver == address(0) && amount == 0, "Core remains fail-soft");
        }
    }

    function testCoreRequiresPublishedRoyaltyInterfaceBeforePointerInstall() public {
        PermanentTargetMetadataRouter wrong = new PermanentTargetMetadataRouter();
        registry.setRecord(
            address(wrong),
            REVENUE_MODULE,
            type(IStreamRoyaltyResolver).interfaceId,
            keccak256("module"),
            keccak256("deploy")
        );
        vm.expectRevert();
        governance.execute(
            address(core),
            abi.encodeCall(core.updateSatellitePointer, (ROYALTY_POINTER, address(wrong)))
        );
        require(
            core.pointerState(ROYALTY_POINTER).target == address(resolver),
            "bad interface cannot replace resolver"
        );
    }

    function _configureCollection(bytes32 profileId, uint16 bps) private {
        governance.execute(
            address(resolver),
            abi.encodeCall(resolver.configureCollectionRoyalty, (uint256(1), profileId, bps))
        );
    }

    function _configureDefault(bytes32 profileId, uint16 bps) private {
        governance.execute(
            address(resolver), abi.encodeCall(resolver.configureDefaultRoyalty, (profileId, bps))
        );
    }

    function _installResolver(address target) private {
        bytes4 interfaceId = type(IStreamRoyaltyResolver).interfaceId;
        registry.setRecord(
            target, REVENUE_MODULE, interfaceId, keccak256("module"), keccak256("deploy")
        );
        StreamCorePointerState memory previous = core.pointerState(ROYALTY_POINTER);
        StreamCorePointerState memory candidate = StreamCorePointerState(
            target,
            target.codehash,
            false,
            REVENUE_MODULE,
            interfaceId,
            address(registry),
            1,
            keccak256("module"),
            keccak256("deploy"),
            previous.revision + 1
        );
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            core.pointerTransitionHashes(ROYALTY_POINTER, previous, candidate);
        governance.setAction(3, scope, oldHash, newHash);
        governance.execute(
            address(core), abi.encodeCall(core.updateSatellitePointer, (ROYALTY_POINTER, target))
        );
    }

    function _mint() private returns (uint256 tokenId) {
        IStreamMintManager.MintBatch memory batch;
        batch.collectionId = 1;
        batch.phaseId = PHASE;
        batch.initialRecipients = new address[](1);
        batch.beneficiaries = new address[](1);
        batch.tokenData = new bytes[](1);
        batch.mintCommitments = new bytes32[](1);
        batch.initialRecipients[0] = artist;
        batch.beneficiaries[0] = artist;
        batch.tokenData[0] = tokenData;
        batch.mintCommitments[0] = keccak256("royalty commitment");
        batch.expectedPolicyHash = manager.phasePolicyHash(1, PHASE);
        batch.authorizationId = keccak256("royalty test mint");
        (uint256[] memory tokenIds,,) = manager.executeSingleStepMint(batch, "");
        return tokenIds[0];
    }
}
