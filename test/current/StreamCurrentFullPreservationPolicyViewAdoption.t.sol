// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../helpers/StreamCurrentFullPreservationPolicyViewAdoptionFixture.sol";

/// @notice Actual declaration/adoption in the original mutable window of the complete graph.
/// @dev No mocked authority, token, Coordinator, Registry or checkpoint. Renderer analysis
/// reports remain explicitly synthetic fixture documents. Source-authored; execution, gas,
/// independent admission analysis and a complete finality ceremony are separate evidence.
contract StreamCurrentFullPreservationPolicyViewAdoptionTest is
    StreamCurrentFullPreservationPolicyViewAdoptionFixture
{
    bool private _testPreservationAdmission;

    function testActualViewDeclarationMembershipAndSafeAdoptionPrecedeCoreFreeze() public {
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        _assertFullPolicyViewAdoption();
        bytes32 registryRead = keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
        require(
            fullPolicyViewRegistry.gasParameter(registryRead) == 4000000
                && products.rendering.versions.gasParameter(registryRead) == 2000000,
            "new late Registry outer budget, original Registry unchanged"
        );
        require(
            router.gasParameter(keccak256("6529STREAM_GGP_ROUTER_BUNDLE_READ_GAS")) == 2000000
                && assemblyViewPreservationCheckpoint.configuration().servingGas == 9000000,
            "original Router and C nested budgets unchanged"
        );
        require(core.collectionFreezeStatus(1), "normal collection preparation still completes");
        require(fullPolicyViewOriginal.source.membership.tokenCount == 2);
        require(
            fullPolicyViewOriginal.source.renderer.registry == address(fullPolicyViewRegistry)
                && fullPolicyViewOriginal.source.renderer.renderer
                    == address(fullPolicyViewRenderer)
                && address(fullPolicyViewRegistry) != address(products.rendering.versions),
            "actual late registry without altering original roster"
        );
        require(fullPolicyViewOriginal.input.viewRecordHash == fullPolicyViewDeclaration);
        (VDeclarations.CollectionViewManifest memory m, VDeclarations.ViewReceipt memory receipt,) =
            assemblyViewDeclarations.viewRecord(fullPolicyViewDeclaration);
        require(
            m.contentHash == keccak256(fullPolicyViewPayload) && m.schemaId == VPayload.SCHEMA_ID
                && receipt.recorder == address(this) && receipt.authorizationClass == 7
                && receipt.revision == 1
        );
        (bytes32 selected, bool locked) =
            assemblyViewDeclarations.selectedViewRecord(1, fullPolicyViewId);
        require(locked && selected == fullPolicyViewDeclaration);
        VA.Aggregate memory a = VRouter(address(router)).viewAdoptionAggregate(1);
        require(
            a.revision == 1 && a.transitionChain == fullPolicyViewOriginal.aggregate.transitionChain
        );
        VP.Binding memory p = fullPolicyViewRenderer.policyViewBinding();
        require(
            p.inventoryPlan == fullPolicyViewInventoryPlan && p.sourceSet == fullPolicyViewSourceSet
                && p.policyCount == 1
                && p.membership.membershipHash
                    == fullPolicyViewOriginal.source.membership.membershipHash
        );
        // Immutable selected membership contains every actual minted token, not a sampled subset.
        for (uint256 i; i < 2; ++i) {
            require(assemblyMembership.scopeTokenAt(fullPolicyViewScope, i) == fullPolicyTokens[i]);
            require(assemblyMembership.scopeCoversToken(fullPolicyViewScope, fullPolicyTokens[i]));
            string memory html = VRouter(address(router))
                .historicalTokenHTMLForView(fullPolicyTokens[i], fullPolicyViewAdoption);
            require(
                bytes(html).length != 0, "actual original renderer validates saved token and policy"
            );
        }
        require(
            !assemblyFinality.collectionFinalityRecord(1).finalized,
            "adoption does not confer finality"
        );
    }

    function testActualViewMissingArtistConsentRollsBackSafeAndIdenticalSignedRetry() public {
        fullPolicyViewProbeMissingConsent = true;
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        // The helper captures the exact Safe transaction before op17, checks GS013 and the
        // unchanged Safe nonce/head/aggregate, then reuses those same bytes after real consent.
        require(fullPolicyViewRetryCalldataHash != 0 && fullPolicyViewConsent != 0);
        require(fullPolicyViewOriginal.artistConsent == fullPolicyViewConsent);
        require(
            fullPolicyViewOriginal.actor == address(assemblyRoot)
                && fullPolicyViewOriginal.revision == 1
        );
        _assertFullPolicyViewAdoption();
    }

    function testActualViewWrongSourceFailsAfterValidPreflightAndFrozenWriteCannotReplaceHead()
        public
    {
        fullPolicyViewProbeBadSource = true;
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        bytes memory original = VRouter(address(router)).viewAdoptionEncoded(fullPolicyViewAdoption);
        VA.Input memory p = fullPolicyViewInput;
        p.expectedPrevious = fullPolicyViewAdoption;
        (bool ok, bytes memory error) = address(router)
            .staticcall(
                abi.encodeCall(VPolicyRouter.previewPolicyViewAdoption, (p, address(assemblyRoot)))
            );
        bytes32 subject = VSubjects.scopeSubject(block.chainid, address(core), fullPolicyViewScope);
        require(
            !ok
                && keccak256(error)
                    == keccak256(abi.encodeWithSelector(VA.ViewAdoptionFrozen.selector, subject)),
            "original Core freeze remains authoritative"
        );
        require(
            VRouter(address(router)).viewAdoptionHead(fullPolicyViewScope) == fullPolicyViewAdoption
                && keccak256(VRouter(address(router)).viewAdoptionEncoded(fullPolicyViewAdoption))
                    == keccak256(original)
        );
    }

    function testActualViewPreservationAdmissionUsesOriginalVersionAndAllFourGoldenModes() public {
        _testPreservationAdmission = true;
        _constructFullPolicyPublication();
        _prepareFullPolicyArtwork();
        VPreservationRegistry.PreservationRecord memory saved =
        fullPolicyViewPreservationRegistration;
        require(
            saved.registrationHash != 0 && saved.actionId != 0 && fullPolicyViewPreservationKey != 0
        );
        require(
            saved.registration.versionKey == fullPolicyViewVersionKey
                && saved.registration.binding.liveRenderer == address(fullPolicyViewRenderer)
                && saved.registration.binding.producer == address(assemblyViewPreservationRenderer)
        );
        VPreservationRegistry.PreservationGoldenVector[] memory vectors = abi.decode(
            assemblySchemas.documentBytes(saved.registration.goldenDocument),
            (VPreservationRegistry.PreservationGoldenVector[])
        );
        require(vectors.length == 8 && saved.goldenHash == keccak256(abi.encode(vectors)));
        for (uint256 i; i < vectors.length; ++i) {
            require(
                vectors[i].tokenId == fullPolicyTokens[i / 4] && vectors[i].mode == uint8(2 + i % 4)
                    && vectors[i].adoptionRecord == fullPolicyViewAdoption
                    && keccak256(abi.encode(vectors[i].scope))
                        == keccak256(abi.encode(fullPolicyViewScope))
            );
        }
        require(
            fullPolicyViewRegistry.version(fullPolicyViewVersionKey).exists
                && products.rendering.versions.version(versionKey).exists,
            "original marketplace and adopted VIEW versions coexist"
        );
    }

    function _publishFullPolicyViewBeforeFreeze() internal override {
        require(!core.collectionFreezeStatus(1) && fullPolicyViewAdoption != 0);
        if (_testPreservationAdmission) _admitFullPolicyViewPreservation();
    }
}
