// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import {
    StreamArtistRotationTypes as R
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistRotationTypes.sol";

/// @notice Actual Core, artist owners, governance, mint, and threshold Safe presentation composition.
/// @dev Canonical Executor uses governance actor fixtures; artist/current-next/buyer use Safes.
///      The external entropy service is substituted by the current-stack fixture.
contract StreamCurrentStablePresentationTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private nextSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;
    uint256[] private nextKeys;

    function setUp() public {
        keys.push(0x57AB1E01);
        keys.push(0x57AB1E02);
        nextKeys.push(0x57AB1E03);
        nextKeys.push(0x57AB1E04);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 71);
        nextSafe = createOfficialSafe(components, safeOwnerAddresses(nextKeys), 2, 72);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 73);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function _additionalOperatingPolicies()
        internal
        view
        override
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        rows = new GovernanceActionPolicyEntry[](2);
        rows[0] = GovernanceActionPolicyEntry(
            2,
            address(router),
            router.lockArtistIdentity.selector,
            address(router).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(router))),
            1,
            0,
            0,
            0
        );
        rows[1] = GovernanceActionPolicyEntry(
            2,
            address(router),
            router.lockDisplayMetadata.selector,
            address(router).codehash,
            keccak256(abi.encode(DEPLOYMENT_HASH, address(router))),
            1,
            0,
            0,
            0
        );
    }

    function _lock(bytes memory data, bytes4 selector) private {
        GovernanceActionRequest memory request = GovernanceActionRequest(
            2,
            address(router),
            0,
            selector,
            data,
            0,
            0,
            0,
            uint64(block.timestamp + executor.minimumDelay(2)),
            uint64(block.timestamp + 30 days),
            keccak256(data),
            "urn:6529stream:stable-presentation",
            DEPLOYMENT_HASH
        );
        bytes32 actionId = abi.decode(
            governanceRoot.execute(
                address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
            ),
            (bytes32)
        );
        vm.warp(request.notBefore);
        executor.executeGovernanceAction(actionId, data);
    }

    function _lockBoth() private {
        _lock(abi.encodeCall(router.lockArtistIdentity, (1)), router.lockArtistIdentity.selector);
        _lock(abi.encodeCall(router.lockDisplayMetadata, (1)), router.lockDisplayMetadata.selector);
    }

    function _mint() private returns (uint256 tokenId) {
        IStreamFixedPriceSaleAdapter.SaleAuthorization memory a =
            IStreamFixedPriceSaleAdapter.SaleAuthorization({
                collectionId: 1,
                phaseId: PHASE,
                payer: address(buyerSafe),
                recipient: address(buyerSafe),
                artist: address(artistSafe),
                profileId: profile,
                expectedPrimaryPolicyHash: _nativePrimaryPolicyHash(),
                tokenDataHash: keccak256(TOKEN_DATA),
                mintCommitment: keccak256("stable presentation mint"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("stable presentation purchase"),
                deadline: uint64(block.timestamp + 1 days),
                signerEpoch: sale.signerEpoch()
            });
        bytes32 digest = sale.authorizationDigest(a);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(PLATFORM_KEY, digest);
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(sale),
                a.price,
                abi.encodeCall(
                    sale.buy, (a, TOKEN_DATA, abi.encodePacked(r, s, v), _artistProof(digest))
                ),
                0
            ),
            "actual Safe purchase"
        );
        tokenId = core.lastAllocatedTokenId();
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("stable presentation entropy"));
        require(
            core.ownerOf(tokenId) == address(buyerSafe) && wallet.balance == a.price,
            "actual mint custody and payment"
        );
    }

    function testCurrentSafeRotationPreservesPresentationAndKeepsNewAuthorityLive() public {
        uint256 tokenId = _mint();
        bytes32 beforeHash = keccak256(bytes(router.tokenMetadataJSON(address(core), tokenId)));
        _lockBoth();
        IStreamMetadataServingFacts.ArtistPresentation memory saved = router.artistPresentation(1);
        require(
            saved.nominatedArtist == address(artistSafe) && saved.artistId == fixtureArtistId,
            "actual nominated identity"
        );
        R.Rotation memory terms = R.Rotation(
            fixtureArtistId, address(artistSafe), address(nextSafe), keccak256("rotation"), 0
        );
        uint256 oldNonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        T.Authorization memory oldA =
            T.Authorization(oldNonce, uint64(block.timestamp + 1 days), "");
        oldA.signature = _artistProof(artists.rotationDigest(terms, oldA));
        (, uint256 newNonce) =
            artists.rotationAcceptanceNonceState(fixtureArtistId, address(nextSafe), 0);
        T.Authorization memory newA =
            T.Authorization(newNonce, uint64(block.timestamp + 1 days), "");
        newA.signature = safeThresholdSignature(
            nextKeys,
            safeMessageDigest(nextSafe, abi.encode(artists.rotationAcceptanceDigest(terms, newA)))
        );
        bytes32 rotation = artists.rotateArtistAddress(terms, oldA, newA);
        R.RotationRecord memory record = artists.rotationRecord(rotation);
        vm.warp(record.transition.contestEndsAt);
        artists.executeArtistRotation(fixtureArtistId, rotation);
        require(artists.acceptedArtist(1) == address(nextSafe), "actual live authority changed");
        IStreamMetadataServingFacts.LiveArtistStatus memory live =
            router.collectionLiveArtistStatus(1);
        require(
            live.attributionState == 2 && live.authorityStatus == 1
                && live.currentAuthority == address(nextSafe),
            "actual typed live facts"
        );
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(router.artistPresentation(1))),
            "historical snapshot untouched"
        );
        require(
            keccak256(bytes(router.tokenMetadataJSON(address(core), tokenId))) == beforeHash,
            "exact served JSON survives rotation"
        );
        require(
            keccak256(bytes(core.tokenURI(tokenId)))
                == keccak256(
                    bytes(
                        StreamMetadataTokenRenderer.dataURI(
                            router.historicalTokenMetadataJSON(address(core), tokenId)
                        )
                    )
                ),
            "actual Core serves the same bound presentation"
        );
        artists.requireMintConsent(1, PHASE, manager.phasePolicyHash(1, PHASE));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.attemptOldSafeConsent();
        StreamArtistContentTypes.Consent memory p = _contentTerms();
        T.Authorization memory a = _nextAuthorization();
        require(
            executeSafe(
                nextSafe,
                nextKeys,
                address(artists),
                0,
                abi.encodeCall(artists.recordContentConsent, (p, a)),
                0
            ),
            "new Safe retains live content authority"
        );
        require(
            artists.contentConsentEvidence(1, p.familyId, p.newStateHash) != 0,
            "actual new authority evidence"
        );
    }

    function _contentTerms() private view returns (StreamArtistContentTypes.Consent memory) {
        return StreamArtistContentTypes.Consent(
            1,
            address(router),
            keccak256("SCRIPT"),
            router.previewArtistScriptState(1, "document.body.textContent='new authority';")
        );
    }

    function _nextAuthorization() private view returns (T.Authorization memory) {
        return T.Authorization(
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint,
            uint64(block.timestamp + 1 days),
            ""
        );
    }

    function attemptOldSafeConsent() external {
        require(msg.sender == address(this), "test wrapper");
        executeSafe(
            artistSafe,
            keys,
            address(artists),
            0,
            abi.encodeCall(artists.recordContentConsent, (_contentTerms(), _nextAuthorization())),
            0
        );
    }

    function testCurrentSafeBurnRetainsFinalizedArtworkButERC721URIStillRejects() public {
        uint256 tokenId = _mint();
        _lockBoth();
        bytes32 beforeHash = keccak256(bytes(router.tokenMetadataJSON(address(core), tokenId)));
        bytes32 dataHash = keccak256(core.tokenData(tokenId));
        require(
            executeSafe(buyerSafe, keys, address(core), 0, abi.encodeCall(core.burn, (tokenId)), 0),
            "actual Safe burn"
        );
        (bool exists, uint256 collectionId,, bool burned) = core.tokenCollectionIdentity(tokenId);
        require(
            exists && collectionId == 1 && burned && core.tokenLifecycle(tokenId) == 3,
            "actual permanent burned identity"
        );
        require(keccak256(core.tokenData(tokenId)) == dataHash, "actual token data retained");
        require(
            keccak256(bytes(router.historicalTokenMetadataJSON(address(core), tokenId)))
                == beforeHash,
            "burned final artwork exact"
        );
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "ERC721: invalid token ID"));
        core.tokenURI(tokenId);
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRouter.InvalidToken.selector, tokenId));
        router.tokenURI(address(core), tokenId);
    }
}
