// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentStackFixture.sol";
import "../helpers/OfficialSafeFixture.sol";
import {
    IStreamArtistContentAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import {
    StreamArtistContentTypes as Content
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Actual artist owners, metadata host, governance and subsequent paid mint composition.
/// @dev The external entropy service is the only substituted protocol boundary.
contract StreamCurrentContentTest is StreamCurrentStackFixture, OfficialSafeFixture {
    OfficialSafe private artistSafe;
    OfficialSafe private buyerSafe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0xC017E01);
        keys.push(0xC017E02);
        SafeComponents memory components = deploySafeComponents("1.4.1");
        artistSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 11);
        buyerSafe = createOfficialSafe(components, safeOwnerAddresses(keys), 2, 12);
        _deployCurrentStack(address(artistSafe), vm.addr(PLATFORM_KEY));
        vm.deal(address(buyerSafe), 1 ether);
    }

    function _artistProof(bytes32 digest) internal override returns (bytes memory) {
        return safeThresholdSignature(keys, safeMessageDigest(artistSafe, abi.encode(digest)));
    }

    function testSafeContentApprovalExecutesQueuedWriteAndPreservesRealMintEligibility() public {
        string memory script = "document.body.dataset.artwork='artist approved revision';";
        bytes memory data = abi.encodeCall(router.setCollectionScript, (uint256(1), script));
        bytes32 actionId = _scheduleScript(data);
        (, bytes32 beforeState) = router.currentArtistContentState(1);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentAuthorizationRequired.selector, 1
            )
        );
        executor.executeGovernanceAction(actionId, data);
        (, bytes32 afterRejectedWrite) = router.currentArtistContentState(1);
        require(afterRejectedWrite == beforeState, "unauthorized write rolled back");

        Content.Consent memory consent = Content.Consent(
            1, address(router), keccak256("SCRIPT"), router.previewArtistScriptState(1, script)
        );
        IStreamArtistContentAuthority authority = IStreamArtistContentAuthority(address(artists));
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(authority.recordContentConsent, (consent, _nextAuthorization())),
                0
            ),
            "actual Safe records content consent"
        );
        bytes32 record = authority.contentConsentEvidence(1, consent.familyId, consent.newStateHash);
        require(
            record != 0 && !router.consumedArtistContentConsent(record), "unused actual consent"
        );
        executor.executeGovernanceAction(actionId, data);
        require(router.consumedArtistContentConsent(record), "host consumed exact record");
        (bool supported, bytes32 familyState) = router.artistContentFamilyState(1, consent.familyId);
        require(supported && familyState == consent.newStateHash, "actual content reached target");
        (bytes32 ratification, bytes32 evolvedState) = router.artistContentEvolution(1);
        (bool ratified,, bytes32 operativeRecord) = artists.firstReleaseRatification(1);
        (, bytes32 afterApprovedWrite) = router.currentArtistContentState(1);
        require(
            ratified && ratification != 0 && ratification == operativeRecord
                && evolvedState != beforeState && evolvedState == afterApprovedWrite,
            "actual ratification-linked evolution"
        );
        _mintAndReveal();
    }

    function testActualArtistFreezeAppliedByDifferentSafePreservesMintAndRejectsWrites() public {
        bytes32[] memory locks = new bytes32[](3);
        locks[0] = keccak256("SCRIPT");
        locks[1] = keccak256("MEDIA_MANIFEST");
        locks[2] = keccak256("BASE_URI");
        for (uint256 i = 1; i < locks.length; ++i) {
            for (uint256 j = i; j > 0 && locks[j - 1] > locks[j]; --j) {
                (locks[j - 1], locks[j]) = (locks[j], locks[j - 1]);
            }
        }
        Content.Freeze memory freeze =
            Content.Freeze(1, address(router), locks, router.artistContentFreezeState(1));
        IStreamArtistContentAuthority authority = IStreamArtistContentAuthority(address(artists));
        require(
            executeSafe(
                artistSafe,
                keys,
                address(artists),
                0,
                abi.encodeCall(
                    authority.authorizeArtistContentFreeze, (freeze, _nextAuthorization())
                ),
                0
            ),
            "actual Safe authorizes defensive freeze"
        );
        (bool authorized, bytes32 record) = authority.isContentFreezeAuthorized(1, locks[0]);
        require(authorized && record != 0, "actual owner freeze evidence");
        require(
            executeSafe(
                buyerSafe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.applyArtistContentFreeze, (uint256(1), record)),
                0
            ),
            "different Safe permissionlessly applies all locks"
        );
        for (uint256 i; i < locks.length; ++i) {
            (bool supported, bool locked) = router.artistContentLockState(1, locks[i]);
            require(supported && locked, "actual one-way host lock");
        }
        require(
            router.artistContentFreezeState(1) == freeze.expectedStateHash,
            "freeze preserves content"
        );
        bytes memory data = abi.encodeCall(router.setCollectionScript, (uint256(1), "changed"));
        bytes32 actionId = _scheduleScript(data);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentLocked.selector, 1, keccak256("SCRIPT")
            )
        );
        executor.executeGovernanceAction(actionId, data);
        _mintAndReveal();
    }

    function _nextAuthorization() private view returns (T.Authorization memory) {
        uint256 nonce =
            IStreamArtistIdentityOwner(artistSuite.owners[2]).identity(fixtureArtistId).nonceHint;
        return T.Authorization(nonce, uint64(block.timestamp + 1 days), "");
    }

    function _scheduleScript(bytes memory data) private returns (bytes32 actionId) {
        GovernanceActionRequest memory request = GovernanceActionRequest(
            1,
            address(router),
            0,
            router.setCollectionScript.selector,
            data,
            bytes32(0),
            bytes32(0),
            bytes32(0),
            uint64(block.timestamp + 48 hours),
            uint64(block.timestamp + 9 days),
            keccak256("current content integration"),
            "urn:6529stream:test:current-content",
            DEPLOYMENT_HASH
        );
        bytes memory result = governanceRoot.execute(
            address(executor), 0, abi.encodeCall(executor.scheduleGovernanceAction, (request))
        );
        actionId = abi.decode(result, (bytes32));
        vm.warp(request.notBefore);
    }

    function _mintAndReveal() private {
        artists.requireMintConsent(1, PHASE, manager.phasePolicyHash(1, PHASE));
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
                mintCommitment: keccak256("content evolution paid mint"),
                mintPolicyHash: manager.phasePolicyHash(1, PHASE),
                price: 0.01 ether,
                nonce: keccak256("content evolution sale"),
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
            "actual Safe paid mint after content operation"
        );
        uint256 tokenId = core.lastAllocatedTokenId();
        require(
            core.ownerOf(tokenId) == address(buyerSafe) && wallet.balance == a.price,
            "custody and payment"
        );
        (, uint256 requestId) = entropy.requestEntropy(tokenId);
        provider.fulfill(requestId, keccak256("actual content composition entropy"));
        (, bool finalized) = entropy.tokenSeed(tokenId);
        require(finalized && bytes(core.tokenURI(tokenId)).length != 0, "actual final metadata");
    }
}
