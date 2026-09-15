// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

contract StreamRevenueResolverArtistBindingTest is RevenueV1TestBase, OfficialSafeFixture {
    event SafeSelectorObserved(address indexed target, bytes4 indexed selector, uint8 result);
    bytes32 private constant CLASS = keccak256("PRIMARY_FIXED_PRICE");
    address private constant ARTIST = address(0xA11CE);
    StreamSplitFactory private factory;
    RevenueResolverCoreMock private core;
    RevenueResolverArtistMock private artists;
    StreamRevenueResolver private resolver;
    bytes32 private profile;
    bytes32 private replacement;
    bytes32 private template;
    bytes32 private initialHash;
    OfficialSafe private safe;
    uint256[] private keys;

    function setUp() public {
        StreamAssetPolicyRegistry policy =
            new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        core = new RevenueResolverCoreMock();
        artists = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(artists), address(artists).codehash);
        core.setToken(77, 1, false);
        resolver = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        profile = _profile(ARTIST, keccak256("artist"));
        replacement = _profile(address(0xB0B), keccak256("other"));
        template = resolver.createPrimaryTemplate(_templateEntries(), bytes32(uint256(1)));
        initialHash = resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
    }

    function testCoreFacadeAndOwnerAreActualConstructorBindings() public view {
        require(
            resolver.core() == address(core) && resolver.artistRegistry() == address(artists)
                && resolver.coreCodeHash() == address(core).codehash
                && resolver.artistRegistryCodeHash() == address(artists).codehash
                && resolver.owner() == address(this),
            "constructor bindings"
        );
    }

    function testZeroNoLooseningPolicyMatchesCanonicalAssignmentHash() public view {
        bytes32 resolverContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_RESOLVER_CONTEXT_V1"),
                address(resolver),
                address(factory),
                address(factory.assetPolicyRegistry()),
                factory.splitWalletRuntimeCodeHash()
            )
        );
        bytes32 scopeContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_SCOPE_CONTEXT_V1"),
                CLASS,
                uint8(1),
                uint256(1),
                uint8(1)
            )
        );
        bytes32 profileContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_PROFILE_CONTEXT_V1"),
                factory.walletFor(profile),
                factory.profileEntriesHash(profile),
                factory.profileMetadataURIHash(profile)
            )
        );
        bytes32 pointerContext = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_POINTER_CONTEXT_V1"),
                profile,
                profileContext,
                bytes32(0),
                bytes32(0)
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_ASSIGNMENT_V1"),
                block.chainid,
                resolverContext,
                scopeContext,
                pointerContext,
                bytes32(0),
                false
            )
        );
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        require(
            initialHash == expected && actual.assignmentHash == expected
                && actual.policyHash == bytes32(0),
            "canonical zero no-loosening commitment"
        );
    }

    function testArbitraryNonzeroPolicyIsNotAcceptedAsLooseningEvidence() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
        );
        resolver.setPrimaryProfileAssignment(
            CLASS, 1, 1, replacement, keccak256("arbitrary document")
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
        );
        resolver.setPrimaryTemplateAssignment(
            CLASS, 1, 1, template, keccak256("arbitrary document")
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
        );
        resolver.primaryAssignmentHash(
            CLASS, 1, 1, 1, profile, bytes32(0), keccak256("arbitrary document"), false
        );
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == initialHash,
            "unchanged"
        );
    }

    function testProposalBeforeAcceptanceClosesAllAssignmentMutation() public {
        artists.setBinding(1, keccak256("permanent proposal"), address(0));
        _assertClosed(1, 1);
        _assertClosed(2, 77);
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == initialHash,
            "proposal retains terms"
        );
    }

    function testAcceptedArtistTermsCannotBeChangedEvenToSameProfile() public {
        artists.setBinding(1, keccak256("permanent binding"), ARTIST);
        _assertClosed(1, 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        require(
            resolver.resolvePrimaryAssignment(1, 77, CLASS).assignmentHash == initialHash,
            "token falls to exact collection profile"
        );
    }

    function testDefaultMutationCannotChangeAnExplicitBoundCollectionProfile() public {
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, replacement, bytes32(0));
        artists.setBinding(1, keccak256("binding"), ARTIST);
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, profile, bytes32(0));
        resolver.clearPrimaryAssignment(CLASS, 0, 0);
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == initialHash,
            "explicit artist terms unchanged"
        );
    }

    function testArtistBoundDefaultTemplateAndTokenProfilesAreExplicitlyUnsupported() public {
        resolver.setPrimaryProfileAssignment(CLASS, 0, 0, profile, bytes32(0));
        artists.setBinding(2, keccak256("default-bound"), ARTIST);
        _expectUnsupported(2, 0);
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 3, template, bytes32(0));
        artists.setBinding(3, keccak256("template-bound"), ARTIST);
        _expectUnsupported(3, 0);
        resolver.setPrimaryProfileAssignment(CLASS, 2, 77, replacement, bytes32(0));
        artists.setBinding(1, keccak256("token-bound"), ARTIST);
        _expectUnsupported(1, 77);
    }

    function testCoreTokenMappingCannotBeReplacedWithCallerSuppliedUnboundCollection() public {
        artists.setBinding(1, keccak256("binding"), ARTIST);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 77, 2
            )
        );
        resolver.resolvePrimaryAssignment(2, 77, CLASS);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        resolver.setPrimaryProfileAssignment(CLASS, 2, 77, replacement, bytes32(0));
        require(
            resolver.resolvePrimaryAssignment(0, 77, CLASS).assignmentHash == initialHash,
            "Core mapping supplies omitted collection"
        );
    }

    function testBurnedTokenRetainsCoreMappingAndArtistProtection() public {
        core.setToken(77, 1, true);
        artists.setBinding(1, keccak256("binding"), ARTIST);
        require(
            resolver.resolvePrimaryAssignment(1, 77, CLASS).assignmentHash == initialHash,
            "burn preserves identity"
        );
        _assertClosed(2, 77);
    }

    function testUnknownCollectionAndUnmappedTokenCannotAcquireAssignments() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryCollection.selector, 1001)
        );
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1001, profile, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 88, 0
            )
        );
        resolver.setPrimaryProfileAssignment(CLASS, 2, 88, profile, bytes32(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryTokenIdentity.selector, 88, 1
            )
        );
        resolver.resolvePrimaryAssignment(1, 88, CLASS);
    }

    function testFacadeRemovalAndReplacementCannotErasePriorArtistRights() public {
        artists.setBinding(1, keccak256("binding"), ARTIST);
        core.selectArtist(address(0), bytes32(0));
        _expectInvalidPointer(address(0));
        RevenueResolverArtistMock replacementFacade = new RevenueResolverArtistMock(address(core));
        core.selectArtist(address(replacementFacade), address(replacementFacade).codehash);
        _expectInvalidPointer(address(replacementFacade));
        core.selectArtist(address(artists), address(artists).codehash);
        _assertClosed(1, 1);
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == initialHash,
            "restored pointer retains rights"
        );
    }

    function testFacadeRuntimeAndCoreRuntimeDriftCannotReopenMutation() public {
        artists.setBinding(1, keccak256("binding"), ARTIST);
        core.selectArtist(address(artists), keccak256("incorrect stored pointer code hash"));
        _expectInvalidPointer(address(artists));
        vm.etch(address(artists), hex"60006000fd");
        core.selectArtist(address(artists), address(artists).codehash);
        _expectInvalidPointer(address(artists));
        vm.etch(address(core), hex"60006000fd");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryResolverConfiguration.selector
            )
        );
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
    }

    function testUnavailableArtistReadFailsClosedInsteadOfAssumingUnbound() public {
        artists.setReadFailure(true);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "artist facts unavailable"));
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
    }

    function testConstructorRejectsNoCodeAndWrongExplicitFacadeBinding() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryResolverConfiguration.selector
            )
        );
        new StreamRevenueResolver(
            IStreamCore(address(0)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamGasParameterHost.GasParameterInvalidAuthority.selector, address(0xE0A))
        );
        new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(0xE0A),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        RevenueResolverArtistMock wrong = new RevenueResolverArtistMock(address(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(wrong)
            )
        );
        new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            wrong,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
            )
        );
        new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            IStreamArtistAttribution(address(0)),
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
    }

    function testDeployBeforePointerAndCoordinatorThenConfigureBeforeProposal() public {
        core.selectArtist(address(0), bytes32(0));
        artists.setReadFailure(true);
        StreamRevenueResolver staged = new StreamRevenueResolver(
            IStreamCore(address(core)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        staged.transferOwnership(address(this));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
            )
        );
        staged.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        core.selectArtist(address(artists), address(artists).codehash);
        artists.setReadFailure(false);
        bytes32 hash = staged.setPrimaryProfileAssignment(CLASS, 1, 1, profile, bytes32(0));
        artists.setBinding(1, keccak256("genesis then proposal"), ARTIST);
        require(
            staged.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == hash,
            "construction does not require installed pointer or attribution reader"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        staged.clearPrimaryAssignment(CLASS, 1, 1);
    }

    /// @dev The Safe is the actual target owner here. Executor timelock routing belongs
    ///      to integration tests; an owner EOA is never substituted for the Safe caller.
    function testActualSafeExecutesEveryOwnerAndPermissionlessWrite() public {
        _makeSafe();
        resolver.transferOwnership(address(safe));
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.createPrimaryTemplate,
                (_templateEntries(), bytes32(uint256(1)))
            )
        );
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.setPrimaryProfileAssignment,
                (CLASS, uint8(1), uint256(2), profile, bytes32(0))
            )
        );
        require(resolver.resolvePrimaryAssignment(2, 0, CLASS).profileId == profile, "Safe profile");
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.setPrimaryTemplateAssignment,
                (CLASS, uint8(1), uint256(2), template, bytes32(0))
            )
        );
        require(
            resolver.resolvePrimaryAssignment(2, 0, CLASS).templateId == template, "Safe template"
        );
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.clearPrimaryAssignment, (CLASS, uint8(1), uint256(2))
            )
        );
        require(!resolver.resolvePrimaryAssignment(2, 0, CLASS).exists, "Safe clear");
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.materializePrimaryProfile, (template, address(safe))
            )
        );
        (bytes32 materialized, address wallet,) =
            resolver.materializePrimaryProfile(template, address(safe));
        require(
            factory.splitWalletExists(materialized) && wallet == factory.walletFor(materialized),
            "Safe materialization creates real official wallet"
        );
        _exec(
            abi.encodeCall(
                IStreamRevenueResolver.freezePrimaryAssignment, (CLASS, uint8(1), uint256(1))
            )
        );
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).frozen, "Safe freeze before nomination"
        );
        _exec(abi.encodeWithSignature("transferOwnership(address)", address(safe)));
        require(resolver.owner() == address(safe), "Safe retains authority");
        _exec(abi.encodeWithSignature("renounceOwnership()"));
        require(resolver.owner() == address(0), "Safe renunciation");
    }

    function testActualSafeCannotBypassOwnerOrArtistRights() public {
        _makeSafe();
        bytes memory data = abi.encodeCall(
            IStreamRevenueResolver.clearPrimaryAssignment, (CLASS, uint8(1), uint256(1))
        );
        _reject(data, abi.encodeWithSignature("Error(string)", "Ownable: caller is not the owner"));
        resolver.transferOwnership(address(safe));
        artists.setBinding(1, keccak256("binding"), ARTIST);
        _reject(
            data,
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1)
        );
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == initialHash,
            "Safe authority cannot replace artist consent"
        );
    }

    function testActualSafeExecutesEveryResolverReadSelector() public {
        _makeSafe();
        _read(abi.encodeWithSignature("SCHEMA_VERSION()"));
        _read(abi.encodeWithSignature("TEMPLATE_VERSION()"));
        _read(abi.encodeWithSignature("MAX_TEMPLATE_ENTRIES()"));
        _read(abi.encodeWithSignature("MAX_DYNAMIC_ACCOUNT_SOURCES()"));
        _read(abi.encodeWithSignature("SHARE_DENOMINATOR_PPM()"));
        _read(abi.encodeWithSignature("SCOPE_DEFAULT()"));
        _read(abi.encodeWithSignature("SCOPE_COLLECTION()"));
        _read(abi.encodeWithSignature("SCOPE_TOKEN()"));
        _read(abi.encodeWithSignature("ASSIGNMENT_TYPE_PROFILE()"));
        _read(abi.encodeWithSignature("ASSIGNMENT_TYPE_TEMPLATE()"));
        _read(abi.encodeWithSignature("ACCOUNT_SOURCE_SALE_POSTER()"));
        _read(abi.encodeWithSignature("splitFactoryContract()"));
        _read(abi.encodeWithSignature("splitFactory()"));
        _read(abi.encodeWithSignature("core()"));
        _read(abi.encodeWithSignature("artistRegistry()"));
        _read(abi.encodeWithSignature("coreCodeHash()"));
        _read(abi.encodeWithSignature("artistRegistryCodeHash()"));
        _read(abi.encodeWithSignature("owner()"));
        _read(abi.encodeWithSignature("isStreamRevenueResolver()"));
        _read(abi.encodeCall(IStreamRevenueResolver.resolvePrimaryAssignment, (1, 77, CLASS)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplate, (template)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplateEntryCount, (template)));
        _read(abi.encodeCall(IStreamRevenueResolver.primaryTemplateEntry, (template, 0)));
        _read(
            abi.encodeCall(
                IStreamRevenueResolver.primaryAssignmentHash,
                (CLASS, uint8(1), uint256(1), uint8(1), profile, bytes32(0), bytes32(0), false)
            )
        );
    }

    function _makeSafe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        keys.push(owners[0]);
        keys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 122);
    }

    function _read(bytes memory data) private {
        (bool baselineOk, bytes memory expected) = address(resolver).staticcall(data);
        vm.prank(address(safe));
        (bool safeOk, bytes memory actual) = address(resolver).staticcall(data);
        require(
            baselineOk && safeOk && expected.length != 0
                && keccak256(actual) == keccak256(expected),
            "Safe read result matches public result"
        );
        _exec(data);
    }

    function _exec(bytes memory data) private {
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, address(resolver), 0, data, 0), "actual Safe call failed");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "Safe success event and nonce");
        emit SafeSelectorObserved(address(resolver), bytes4(data), 1);
    }

    function _reject(bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = address(resolver).call(data);
        require(!ok && keccak256(reason) == keccak256(expected), "exact target rejection");
        uint256 nonce = safe.nonce();
        bytes32 digest = safe.getTransactionHash(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory signature = safeThresholdSignature(keys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), signature
        );
        require(safe.nonce() == nonce, "failed Safe call preserves nonce");
        emit SafeSelectorObserved(address(resolver), bytes4(data), 2);
    }

    function _assertClosed(uint8 scope, uint256 id) private {
        bytes memory reason =
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1);
        vm.expectRevert(reason);
        resolver.setPrimaryProfileAssignment(CLASS, scope, id, replacement, bytes32(0));
        vm.expectRevert(reason);
        resolver.setPrimaryTemplateAssignment(CLASS, scope, id, template, bytes32(0));
        vm.expectRevert(reason);
        resolver.clearPrimaryAssignment(CLASS, scope, id);
        vm.expectRevert(reason);
        resolver.freezePrimaryAssignment(CLASS, scope, id);
    }

    function _expectInvalidPointer(address selected) private {
        bytes memory reason = abi.encodeWithSelector(
            IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, selected
        );
        vm.expectRevert(reason);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        vm.expectRevert(reason);
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, replacement, bytes32(0));
        vm.expectRevert(reason);
        resolver.resolvePrimaryAssignment(1, 0, CLASS);
    }

    function _expectUnsupported(uint256 collectionId, uint256 tokenId) private {
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnsupportedArtistPrimaryAssignment.selector, collectionId
            )
        );
        resolver.resolvePrimaryAssignment(collectionId, tokenId, CLASS);
    }

    function _profile(address recipient, bytes32 metadata) private returns (bytes32 id) {
        IStreamSplitWallet.SplitEntry[] memory entries = new IStreamSplitWallet.SplitEntry[](1);
        entries[0] = IStreamSplitWallet.SplitEntry(recipient, 1_000_000, keccak256("artist"));
        (id,) = factory.createProfile(entries, metadata);
    }

    function _templateEntries()
        private
        view
        returns (IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries)
    {
        entries = new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), resolver.ACCOUNT_SOURCE_SALE_POSTER(), 1_000_000, keccak256("poster")
        );
    }
}
