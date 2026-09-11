// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/ArtistTemplateTestMocks.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

contract StreamArtistTemplateEconomicsFactsTest is RevenueV1TestBase, OfficialSafeFixture {
    bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
    bytes32 private constant SOURCE = keccak256("COLLECTION_ARTIST");
    bytes32 private constant ARTIST = keccak256("artist");
    StreamRevenueResolver private resolver;
    StreamSplitFactory private factory;
    ArtistTemplateFactsMock private artists;
    RevenueResolverCoreMock private coreFixture;
    bytes32 private template;
    bytes32 private configuredHash;
    address private constant PAYEE = address(0xA11CE);
    OfficialSafe private safe;
    uint256[] private keys;

    function setUp() public {
        StreamAssetPolicyRegistry policy =
            new StreamAssetPolicyRegistry(address(_revenueAuthority()));
        factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
        coreFixture = new RevenueResolverCoreMock();
        artists = new ArtistTemplateFactsMock(address(coreFixture), PAYEE);
        coreFixture.selectArtist(address(artists), address(artists).codehash);
        resolver = new StreamRevenueResolver(
            IStreamCore(address(coreFixture)),
            factory,
            address(revenueAuthority),
            artists,
            IStreamGasParameterHost.GasParameterConfig(
                "ARTIST_BENEFICIARY_READ_GAS", 200_000, 50_000, 2
            )
        );
        vm.prank(address(revenueAuthority));
        resolver.transferOwnership(address(this));
        template = resolver.createPrimaryTemplate(_entries(900_000), keccak256("terms"));
        configuredHash = resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, bytes32(0));
        artists.setBinding(1, keccak256("binding"), address(0xA0));
    }

    function testActualCanonicalFactsAndCurrentAssignmentEqualExactPreview() public view {
        (bytes32 entries, bytes32 metadata, uint32 share) =
            resolver.primaryTemplateEconomicsFacts(template);
        (bool exists, bytes32 storedEntries, bytes32 storedMetadata) =
            resolver.primaryTemplate(template);
        require(
            exists && entries == storedEntries && metadata == storedMetadata && share == 900_000,
            "facts derive actual immutable template"
        );
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            resolver.previewArtistPrimaryTemplateAssignment(1, template, bytes32(0), false);
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory current =
            resolver.resolvePrimaryAssignment(1, 0, CLASS);
        require(
            fact.resolver == address(resolver) && fact.revenueClass == CLASS && fact.scope == 1
                && fact.scopeId == 1,
            "exact provider context"
        );
        require(
            fact.assignmentHash == configuredHash && current.assignmentHash == configuredHash
                && current.assignmentType == 2 && current.templateId == template
                && current.profileId == bytes32(0),
            "typed template identity not profile alias"
        );
    }

    function testFactsNeverCallPayoutConsentOrMaterialization() public {
        artists.setReadFailure(true);
        artists.setMode(1);
        (,, uint32 share) = resolver.primaryTemplateEconomicsFacts(template);
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            resolver.previewArtistPrimaryTemplateAssignment(1, template, bytes32(0), false);
        require(
            share == 900_000 && fact.assignmentHash == configuredHash
                && factory.profileCount() == 0,
            "no recursive consent/payout/cache dependency"
        );
    }

    function testCurrentTemplateResolutionDoesNotOpenBoundMutation() public {
        bytes memory reason =
            abi.encodeWithSelector(IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1);
        vm.expectRevert(reason);
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, bytes32(0));
        vm.expectRevert(reason);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
        vm.expectRevert(reason);
        resolver.freezePrimaryAssignment(CLASS, 1, 1);
        require(
            resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == configuredHash,
            "no same-value bypass or erased rights"
        );
    }

    function testUnsupportedArtistSourcesAndBelowFloorRemainClosed() public {
        bytes32 low = resolver.createPrimaryTemplate(_entries(499_999), bytes32(uint256(1)));
        _unsupported(low);
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries(900_000);
        entries[0].account = PAYEE;
        entries[0].accountSource = bytes32(0);
        bytes32 fixedArtist = resolver.createPrimaryTemplate(entries, bytes32(uint256(2)));
        _unsupported(fixedArtist);
        entries[0].account = address(0);
        entries[0].accountSource = keccak256("SALE_POSTER");
        bytes32 poster = resolver.createPrimaryTemplate(entries, bytes32(uint256(3)));
        _unsupported(poster);
        entries = _entries(900_000);
        entries[1].account = address(0);
        entries[1].accountSource = keccak256("SALE_POSTER");
        bytes32 mixed = resolver.createPrimaryTemplate(entries, bytes32(uint256(4)));
        _unsupported(mixed);
        _unsupported(bytes32(uint256(999)));
    }

    function testExactlyHalfArtistShareIsSupportedAndTemplateStateImmutable() public {
        bytes32 t = resolver.createPrimaryTemplate(_entries(500_000), bytes32(0));
        (bytes32 beforeHash, bytes32 metadata, uint32 share) =
            resolver.primaryTemplateEconomicsFacts(t);
        require(share == 500_000, "inclusive supported floor");
        artists.setFacts(artists.identity(), address(0xDAD), keccak256("new payout"));
        (bytes32 afterHash, bytes32 same, uint32 sameShare) =
            resolver.primaryTemplateEconomicsFacts(t);
        require(
            beforeHash == afterHash && metadata == same && sameShare == share,
            "payout record is not immutable template identity"
        );
    }

    function testPayoutRevisionChangesConcreteProfileNotConsentedTemplateHash() public {
        (bytes32 first, address old,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        artists.setFacts(artists.identity(), address(0xDAD), keccak256("new payout"));
        (bytes32 second, address next,) =
            resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
        require(
            first != second && old != next
                && resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == configuredHash,
            "future payout resolution keeps immutable assignment commitment"
        );
        require(
            IStreamSplitWallet(old).aggregateSharePpm(PAYEE) == 900_000
                && IStreamSplitWallet(next).aggregateSharePpm(address(0xDAD)) == 900_000,
            "separate immutable rights"
        );
    }

    function testUnsupportedPreconfiguredTemplateCannotBecomeBoundResolvedRights() public {
        bytes32 low = resolver.createPrimaryTemplate(_entries(499_999), bytes32(0));
        resolver.setPrimaryTemplateAssignment(CLASS, 1, 2, low, bytes32(0));
        artists.setBinding(2, keccak256("second binding"), address(0xA0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, low
            )
        );
        resolver.resolvePrimaryAssignment(2, 0, CLASS);
    }

    function testTemplateInheritanceAndOtherClassCannotBypassExplicitCollectionProfile() public {
        resolver.setPrimaryTemplateAssignment(CLASS, 0, 0, template, bytes32(0));
        artists.setBinding(3, keccak256("third binding"), address(0xA0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnsupportedArtistPrimaryAssignment.selector, 3
            )
        );
        resolver.resolvePrimaryAssignment(3, 0, CLASS);
        bytes32 other = keccak256("OTHER");
        resolver.setPrimaryTemplateAssignment(other, 1, 4, template, bytes32(0));
        artists.setBinding(4, keccak256("fourth binding"), address(0xA0));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamRevenueResolver.UnsupportedArtistPrimaryAssignment.selector, 4
            )
        );
        resolver.resolvePrimaryAssignment(4, 0, other);
    }

    function testPreviewRejectsPolicyWrongCollectionAndSelectedPointerDrift() public {
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
        );
        resolver.previewArtistPrimaryTemplateAssignment(1, template, bytes32(uint256(1)), false);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryCollection.selector, 1001)
        );
        resolver.previewArtistPrimaryTemplateAssignment(1001, template, bytes32(0), false);
        coreFixture.selectArtist(address(0), bytes32(0));
        bytes memory reason = abi.encodeWithSelector(
            IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
        );
        vm.expectRevert(reason);
        resolver.previewArtistPrimaryTemplateAssignment(1, template, bytes32(0), false);
        vm.expectRevert(reason);
        resolver.primaryTemplateEconomicsFacts(template);
    }

    function testActualSafeReadsBothProviderFactsAndCannotTurnPreviewIntoWrite() public {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x101;
        owners[1] = 0x102;
        owners[2] = 0x103;
        keys.push(owners[0]);
        keys.push(owners[1]);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 918);
        _read(
            abi.encodeCall(
                IStreamArtistPrimaryTemplateFacts.primaryTemplateEconomicsFacts, (template)
            )
        );
        _read(
            abi.encodeCall(
                IStreamArtistPrimaryTemplateFacts.previewArtistPrimaryTemplateAssignment,
                (1, template, bytes32(0), true)
            )
        );
        _read(
            abi.encodeWithSignature(
                "supportsInterface(bytes4)", type(IStreamArtistPrimaryTemplateFacts).interfaceId
            )
        );
        resolver.transferOwnership(address(safe));
        bytes memory data = abi.encodeCall(
            IStreamRevenueResolver.freezePrimaryAssignment, (CLASS, uint8(1), uint256(1))
        );
        vm.prank(address(safe));
        (bool ok, bytes memory reason) = address(resolver).call(data);
        require(
            !ok
                && keccak256(reason)
                    == keccak256(
                        abi.encodeWithSelector(
                            IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1
                        )
                    ),
            "exact owner-safe target rejection"
        );
        uint256 nonce = safe.nonce();
        bytes32 digest =
            safe.getTransactionHash(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), address(0), nonce
        );
        bytes memory sig = safeThresholdSignature(keys, digest);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        safe.execTransaction(
            address(resolver), 0, data, 0, 0, 0, 0, address(0), payable(address(0)), sig
        );
        require(
            safe.nonce() == nonce && !resolver.resolvePrimaryAssignment(1, 0, CLASS).frozen,
            "preview did not grant write authority"
        );
    }

    function testFuzzTemplateFactsBindActualShares(uint32 seed) public {
        uint32 artistShare = 500_000 + seed % 500_000;
        bytes32 t = resolver.createPrimaryTemplate(_entries(artistShare), bytes32(uint256(seed)));
        (,, uint32 actual) = resolver.primaryTemplateEconomicsFacts(t);
        require(actual == artistShare, "exact actual aggregate");
        StreamArtistOnboardingTypes.AssignmentFact memory fact =
            resolver.previewArtistPrimaryTemplateAssignment(2, t, bytes32(0), false);
        bytes32 assigned = resolver.setPrimaryTemplateAssignment(CLASS, 1, 2, t, bytes32(0));
        require(assigned == fact.assignmentHash, "exact preview/write parity before binding");
    }

    function _unsupported(bytes32 t) private {
        bytes memory reason = abi.encodeWithSelector(
            IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, t
        );
        vm.expectRevert(reason);
        resolver.primaryTemplateEconomicsFacts(t);
        vm.expectRevert(reason);
        resolver.previewArtistPrimaryTemplateAssignment(1, t, bytes32(0), false);
    }

    function _entries(uint32 share)
        private
        pure
        returns (IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries)
    {
        entries = new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(address(0), SOURCE, share, ARTIST);
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xB0B), bytes32(0), 1_000_000 - share, keccak256("protocol")
        );
    }

    function _read(bytes memory data) private {
        (bool ok, bytes memory expected) = address(resolver).staticcall(data);
        vm.prank(address(safe));
        (bool sameOk, bytes memory actual) = address(resolver).staticcall(data);
        require(ok && sameOk && keccak256(expected) == keccak256(actual), "real Safe read parity");
        uint256 nonce = safe.nonce();
        vm.recordLogs();
        require(executeSafe(safe, keys, address(resolver), 0, data, 0), "real Safe execution");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool success;
        for (uint256 i; i < logs.length; ++i) {
            if (
                logs[i].emitter == address(safe) && logs[i].topics.length != 0
                    && logs[i].topics[0] == keccak256("ExecutionSuccess(bytes32,uint256)")
            ) success = true;
        }
        require(success && safe.nonce() == nonce + 1, "Safe success+nonce");
    }
}
