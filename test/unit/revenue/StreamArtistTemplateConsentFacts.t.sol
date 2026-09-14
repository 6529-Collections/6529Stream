// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/RevenueV1TestBase.sol";
import "../../helpers/RevenueResolverTestMocks.sol";
import "../../../smart-contracts/domains/revenue/StreamRevenueResolver.sol";

/// @dev Typed Artist boundary only. Actual operation-15 signatures and archival evidence belong
///      to the Artist integration suite; this fixture enforces the full resolver/key association.
contract TemplateConsentArtistFixture is IStreamArtistAttribution, IStreamArtistBeneficiaryFacts {
    address public immutable override core;
    bool public failReads;
    bool public expanded = true;
    address public payout = address(0xA11CE);
    mapping(uint256 => uint64) public generation;
    mapping(bytes32 => bool) private _consent;

    constructor(address source) {
        core = source;
    }

    function bind(uint256 collection) external {
        ++generation[collection];
    }

    function setFailure(bool value) external {
        failReads = value;
    }

    function setExpanded(bool value) external {
        expanded = value;
    }

    function setPayout(address value) external {
        payout = value;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || (expanded && id == type(IStreamArtistTemplateEconomicsAuthority).interfaceId);
    }

    function acceptedArtist(uint256 collection) external view returns (address) {
        require(!failReads, "artist read");
        return generation[collection] == 0 ? address(0) : address(0xA0);
    }

    function attribution(uint256 collection)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        require(!failReads, "artist read");
        if (generation[collection] != 0) {
            a.artist = address(0xA0);
            a.nominationHash = keccak256(abi.encode(collection, generation[collection]));
            a.acceptanceHash = keccak256("accepted");
        }
    }

    function collectionArtistBeneficiary(uint256 collection)
        external
        view
        returns (bytes32, address, bytes32)
    {
        require(!failReads && generation[collection] != 0, "artist payout");
        return (keccak256("identity"), payout, keccak256(abi.encode(payout)));
    }

    function approve(address resolver, uint256 collection, bytes32 hash, bool value) external {
        _consent[_key(resolver, collection, keccak256("PRIMARY_SALE"), 1, collection, hash)] = value;
    }

    function requireEconomicsConsent(
        uint256 collection,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 hash
    ) external view {
        require(
            !failReads
                && _consent[_key(msg.sender, collection, revenueClass, scope, scopeId, hash)],
            "exact consent"
        );
    }

    function _key(
        address resolver,
        uint256 collection,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 hash
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                resolver, collection, generation[collection], revenueClass, scope, scopeId, hash
            )
        );
    }
}

    contract StreamArtistTemplateConsentFactsTest is RevenueV1TestBase {
        bytes32 private constant CLASS = keccak256("PRIMARY_SALE");
        StreamRevenueResolver private resolver;
        StreamSplitFactory private factory;
        RevenueResolverCoreMock private source;
        TemplateConsentArtistFixture private artists;
        bytes32 private template;

        function setUp() public {
            StreamAssetPolicyRegistry policy =
                new StreamAssetPolicyRegistry(address(_revenueAuthority()));
            factory = new StreamSplitFactory(policy, address(revenueAuthority), _walletGasConfigs());
            source = new RevenueResolverCoreMock();
            artists = new TemplateConsentArtistFixture(address(source));
            source.selectArtist(address(artists), address(artists).codehash);
            resolver = new StreamRevenueResolver(
                IStreamCore(address(source)),
                factory,
                address(revenueAuthority),
                artists,
                IStreamGasParameterHost.GasParameterConfig(
                    "ARTIST_BENEFICIARY_READ_GAS", 200000, 50000, 2
                )
            );
            vm.prank(address(revenueAuthority));
            resolver.transferOwnership(address(this));
            template = resolver.createPrimaryTemplate(_entries(100000), keccak256("terms"));
        }

        function testProspectivePositiveFactsDoNotRequireConsentOrPayoutAndKeepOldFloor() public {
            artists.bind(1);
            artists.setFailure(true);
            (bytes32 entries, bytes32 metadata, uint32 share) =
                resolver.primaryTemplateConsentFacts(template);
            (bool exists, bytes32 storedEntries, bytes32 storedMetadata) =
                resolver.primaryTemplate(template);
            require(
                exists && entries == storedEntries && metadata == storedMetadata && share == 100000,
                "actual immutable positive terms"
            );
            StreamArtistOnboardingTypes.AssignmentFact memory fact =
                resolver.previewArtistPrimaryTemplateConsentAssignment(1, template, 0, false);
            require(
                fact.resolver == address(resolver) && fact.revenueClass == CLASS && fact.scope == 1
                    && fact.scopeId == 1 && fact.assignmentHash != 0 && factory.profileCount() == 0,
                "prospective context without recursive authority or payout"
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector,
                    template
                )
            );
            resolver.primaryTemplateEconomicsFacts(template);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector,
                    template
                )
            );
            resolver.previewArtistPrimaryTemplateAssignment(1, template, 0, false);
        }

        function testBoundSetRequiresOriginalKeyAndOwnerWhileFreezeAndClearStayClosed() public {
            artists.bind(1);
            bytes32 expected =
                resolver.previewArtistPrimaryTemplateConsentAssignment(1, template, 0, false)
            .assignmentHash;
            bytes memory data = abi.encodeCall(
                resolver.setPrimaryTemplateAssignment,
                (CLASS, uint8(1), uint256(1), template, bytes32(0))
            );
            (bool ok,) = address(resolver).call(data);
            require(
                !ok && !resolver.primaryEconomicsFacts(1, 1, 1).exists,
                "missing consent has no write"
            );
            artists.approve(address(resolver), 1, bytes32(uint256(999)), true);
            (ok,) = address(resolver).call(data);
            require(!ok, "different original hash is not authority");
            artists.approve(address(resolver), 1, expected, true);
            vm.prank(address(0xBAD));
            (ok,) = address(resolver).call(data);
            require(!ok, "artist consent is not governance authority");
            vm.recordLogs();
            bytes memory raw;
            (ok, raw) = address(resolver).call(data);
            require(ok && abi.decode(raw, (bytes32)) == expected, "identical set request retries");
            Vm.Log[] memory logs = vm.getRecordedLogs();
            bytes32 topic = keccak256(
                "PrimaryAssignmentSet(bytes32,uint8,uint256,uint8,bytes32,bytes32,bytes32,bytes32,address)"
            );
            uint256 count;
            for (uint256 i; i < logs.length; ++i) {
                if (logs[i].emitter != address(resolver) || logs[i].topics[0] != topic) continue;
                ++count;
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == CLASS
                        && logs[i].topics[2] == bytes32(uint256(1))
                        && logs[i].topics[3] == bytes32(uint256(1))
                        && keccak256(logs[i].data)
                            == keccak256(
                                abi.encode(
                                    uint8(2),
                                    bytes32(0),
                                    template,
                                    bytes32(0),
                                    expected,
                                    address(this)
                                )
                            ),
                    "full original assignment event"
                );
            }
            require(
                count == 1
                    && resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == expected,
                "actual current exact consent"
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1
                )
            );
            resolver.freezePrimaryAssignment(CLASS, 1, 1);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueResolver.PrimaryArtistConsentRequired.selector, 1
                )
            );
            resolver.clearPrimaryAssignment(CLASS, 1, 1);
        }

        function testCurrentLowTakeRequiresFreshBindingConsentIncludingTokenZero() public {
            bytes32 expected = resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, 0);
            artists.bind(1);
            (bool ok,) = address(resolver)
                .staticcall(abi.encodeCall(resolver.resolvePrimaryAssignment, (1, 0, CLASS)));
            require(!ok, "preconfigured low take is not a consent bypass");
            artists.approve(address(resolver), 1, expected, true);
            require(
                resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == expected,
                "approved exact current key"
            );
            (bytes32 first, address oldWallet,) =
                resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
            artists.setPayout(address(0xBEEF));
            (bytes32 next, address nextWallet,) =
                resolver.materializeCollectionPrimaryProfile(template, 1, address(0), true);
            require(
                first != next && oldWallet != nextWallet
                    && resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash == expected,
                "payout rotation preserves consent identity and changes concrete payout"
            );
            artists.bind(1);
            (ok,) = address(resolver)
                .staticcall(abi.encodeCall(resolver.resolvePrimaryAssignment, (1, 0, CLASS)));
            require(!ok, "old association cannot authorize corrected binding");
            artists.approve(address(resolver), 1, expected, true);
            source.setToken(7, 1, false);
            require(
                resolver.resolvePrimaryAssignment(1, 7, CLASS).assignmentHash == expected,
                "real token mapping same collection key"
            );
            artists.approve(address(resolver), 1, expected, false);
            (ok,) = address(resolver)
                .staticcall(abi.encodeCall(resolver.resolvePrimaryAssignment, (1, 7, CLASS)));
            require(!ok, "token context retains fresh consent requirement");
        }

        function testUnsupportedStructuralTermsAndWrongContextRemainClosed() public {
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
                new IStreamRevenueResolver.PrimaryTemplateEntry[](1);
            entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0xB0B), 0, 1000000, keccak256("protocol")
            );
            bytes32 noArtist = resolver.createPrimaryTemplate(entries, 0);
            _unsupported(noArtist);
            entries = _entries(100000);
            entries[0].accountSource = keccak256("SALE_POSTER");
            _unsupported(resolver.createPrimaryTemplate(entries, 0));
            entries[0].accountSource = 0;
            entries[0].account = address(0xA0);
            _unsupported(resolver.createPrimaryTemplate(entries, 0));
            _unsupported(bytes32(uint256(999)));
            vm.expectRevert(
                abi.encodeWithSelector(IStreamRevenueResolver.InvalidPrimaryPolicyHash.selector)
            );
            resolver.previewArtistPrimaryTemplateConsentAssignment(
                1, template, bytes32(uint256(1)), false
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueResolver.InvalidPrimaryCollection.selector, 1001
                )
            );
            resolver.previewArtistPrimaryTemplateConsentAssignment(1001, template, 0, false);
            source.selectArtist(address(0), 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamRevenueResolver.InvalidPrimaryArtistRegistry.selector, address(0)
                )
            );
            resolver.primaryTemplateConsentFacts(template);
        }

        function testFuzzPositiveShareExactCanonicalHashAndOldFloor(uint32 seed) public {
            uint32 share = 1 + seed % 499999;
            IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries = _entries(share);
            bytes32 id = resolver.createPrimaryTemplate(entries, bytes32(uint256(seed)));
            (bytes32 hash,, uint32 actual) = resolver.primaryTemplateConsentFacts(id);
            require(
                actual == share && hash == keccak256(abi.encode(entries)),
                "canonical retained positive rows"
            );
            bytes32 preview =
                resolver.previewArtistPrimaryTemplateConsentAssignment(1, id, 0, false)
            .assignmentHash;
            require(
                resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, id, 0) == preview,
                "original hash setter parity"
            );
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, id
                )
            );
            resolver.primaryTemplateEconomicsFacts(id);
        }

        function _unsupported(bytes32 id) private {
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, id
                )
            );
            resolver.primaryTemplateConsentFacts(id);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamArtistPrimaryTemplateFacts.UnsupportedArtistPrimaryTemplate.selector, id
                )
            );
            resolver.previewArtistPrimaryTemplateConsentAssignment(1, id, 0, false);
        }

        function _entries(uint32 share)
            private
            pure
            returns (IStreamRevenueResolver.PrimaryTemplateEntry[] memory rows)
        {
            rows = new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
            rows[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
            );
            rows[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0xB0B), 0, 1000000 - share, keccak256("protocol")
            );
        }
    }
