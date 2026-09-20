// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentFullPolicyArchiveFixture.sol";
import "./StreamCurrentFullPolicyPublicationBase.sol";

/// @notice Genuine STATIC artwork preparation before any selection/output checkpoint.
/// @dev Original description/waiver/locks use their admitted writers and the Artist/governor
/// threshold Safes. Renderer analysis documents remain explicitly synthetic fixture evidence;
/// current golden vectors use historical output plus an independent literal citation insertion.
abstract contract StreamCurrentFullPolicyPreparationFixture is
    StreamCurrentFullPolicyArchiveFixture
{
    using Strings for uint256;
    uint256[2] internal fullPolicyTokens;
    bytes32 internal fullPolicyStaticConfig;
    bytes32 internal fullPolicyRendererConsent;
    bytes32 internal fullPolicyFirstRatification;
    bytes32 internal assemblyWorkRecord;
    bytes32 internal assemblyRightsRecord;
    bytes32 internal assemblyWaiverRecord;
    bytes32 internal assemblyWaiverAuthorization;
    StreamWorkRecordTypes.Description internal assemblyWorkDescription;
    StreamRightsRecordTypes.Statement internal assemblyRightsStatement;
    StreamConservationRecordTypes.IntentWaiver internal assemblyIntentWaiver;
    string internal constant FULL_POLICY_SCRIPT =
        "document.body.style.margin='0';const c=document.createElement('canvas');c.width=64;c.height=64;document.body.appendChild(c);const x=c.getContext('2d');x.fillStyle='#123456';x.fillRect(0,0,64,64);x.fillStyle=tokenId===1?'#ff0000':'#00ff00';x.fillRect(8,8,16,16);";

    /// @dev Call after _constructFullPolicyPublication. This override has deferred only the
    /// first content ratification, so STATIC activation still precedes both ratification and mint.
    function _prepareFullPolicyArtwork() internal {
        require(fullPolicyTokens[0] == 0 && assemblyArtistId != 0, "fresh prepared artwork");
        _configureFullPolicyStatic();
        _raiseFullPolicyRouterRenderBudget();
        _fullPolicyRatifyInitialContent();
        _configurePreparedFullPolicyPhase(PHASE, address(sale));
        _configurePreparedFullPolicyPhase(AUCTION_PHASE, address(auction));
        fullPolicyTokens[0] = _fullPolicyMint(1);
        fullPolicyTokens[1] = _fullPolicyMint(2);
        require(
            fullPolicyTokens[0] != fullPolicyTokens[1] && core.collectionMintedEver(1) == 2,
            "two actual original mints"
        );
        _assemblyPrepareDescriptionDefinitions();
        _assemblySelectDescriptionsAndWaiver();
        _freezeFullPolicyStatic();
        _assemblyLockContent();
        _assemblyCloseAndFreezeCore();
        _admitFullPolicyCurrentCitation();
        _assertFullPolicyPrepared();
    }

    function _assemblyPrepareDescriptionDefinitions() internal {
        require(
            assemblySchemas.document(assemblySchemas.RAW_BYTES()).exists,
            "original RAW_BYTES definition"
        );
        string[14] memory names = [
            "STREAM_WORK_DESCRIPTION_V1",
            "STREAM_WORK_DESCRIPTION_JSON_PROFILE_V1",
            "STREAM_WORK_FORMAT_CATALOG_V1",
            "STREAM_WORK_FORMAT_CATALOG_JSON_PROFILE_V1",
            "STREAM_RIGHTS_V1",
            "STREAM_RIGHTS_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_V1",
            "STREAM_ARTIST_INTENT_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTENT_WAIVER_V1",
            "STREAM_ARTIST_INTENT_WAIVER_JSON_PROFILE_V1",
            "STREAM_ARTIST_INTERVIEW_V1",
            "STREAM_ARTIST_INTERVIEW_JSON_PROFILE_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_V1",
            "STREAM_CONSERVATION_FORMAT_CATALOG_JSON_PROFILE_V1"
        ];
        _assemblyRegisterDocument(
            "RFC8785_JCS",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(assemblyVm.readFile("schemas/museum/account-profile/RFC8785_JCS.json")),
            assemblySchemas.RAW_BYTES()
        );
        // Each document has an independent immutable identifier; all share one actual delayed action.
        GenesisBatch memory definitions;
        definitions.actionClass = 1;
        definitions.calls = new GovernanceCall[](names.length);
        definitions.callDatas = new bytes[](names.length);
        for (uint256 i; i < names.length; ++i) {
            bytes memory raw =
                bytes(assemblyVm.readFile(string.concat("schemas/records/", names[i], ".json")));
            bytes32[] memory chunks = _assemblyUpload(raw);
            IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CATALOG,
                keccak256(raw),
                assemblySchemas.RAW_BYTES(),
                bytes32(0),
                "",
                uint32(raw.length)
            );
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                assemblySchemas.registrationTransition(spec, chunks);
            definitions.callDatas[i] =
                abi.encodeCall(assemblySchemas.registerDocument, (spec, chunks));
            definitions.calls[i] = StreamCurrentStackPlan.call(
                address(assemblySchemas), definitions.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(definitions);
        _assemblyGovernance(
            definitions, "https://fixtures.example.invalid/native-assembly/description-definitions"
        );
        _assemblyAdmitRecordType(
            keccak256("WORK_DESCRIPTION"), StreamRecordFamilies.CURATOR, 0x010a
        );
        _assemblyAdmitRecordType(keccak256("RIGHTS_STATEMENT"), StreamRecordFamilies.RIGHTS, 0x0180);
        _assemblyAdmitRecordType(keccak256("ARTIST_INTENT"), StreamRecordFamilies.ARTIST, 2);
        _assemblyAdmitRecordType(keccak256("ARTIST_INTENT_WAIVER"), StreamRecordFamilies.ARTIST, 2);
        _assemblyAdmitRecordType(keccak256("ARTIST_STATEMENT"), StreamRecordFamilies.ARTIST, 2);
        _assemblyGrantFamily(StreamRecordFamilies.CURATOR, 3, address(this));
        _assemblyGrantFamily(StreamRecordFamilies.RIGHTS, 7, address(this));
        _assemblyGrantFamily(StreamRecordFamilies.IDENTITY, 7, address(this));
        _assemblyRaisePublicationReadBudget();
    }

    function _assemblyRaisePublicationReadBudget() private {
        IStreamGasParameterHost host = IStreamGasParameterHost(address(assemblyArtists));
        bytes32 id = keccak256("6529STREAM_GGP_ARTIST_RECORD_PUBLICATION_READ_GAS");
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(
            value == 400000 && floor == 150000 && failure == 2 && revision == 1,
            "original publication read budget"
        );
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        uint256 next = 800000;
        bytes32 oldHash = keccak256(abi.encode(domain, scope, value, floor, failure, revision));
        bytes32 newHash = keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1));
        _assemblyGovernanceCall(
            1,
            address(host),
            abi.encodeCall(host.raiseGasParameter, (id, next)),
            scope,
            oldHash,
            newHash
        );
        (uint256 saved, uint256 savedFloor, uint8 savedFailure, uint64 savedRevision) =
            host.gasParameterInfo(id);
        require(
            saved == next && savedFloor == floor && savedFailure == failure
                && savedRevision == revision + 1,
            "actual governed publication cap and revision"
        );
    }

    function _assemblyAdmitRecordType(bytes32 kind, bytes32 family, uint16 mask) private {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            assemblyMetadata.recordTypeTransition(kind, family, mask);
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(assemblyMetadata.admitRecordType, (kind, family, mask)),
            scope,
            oldHash,
            newHash
        );
    }

    function _assemblySubject() internal view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid, address(assemblyCore), _assemblyScope()
        );
    }

    function _assemblyOriginalRecord(bytes32 kind, bytes32 schema, bytes memory raw)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory record)
    {
        record.recordType = kind;
        record.subjectId = _assemblySubject();
        record.schemaId = schema;
        record.effectiveAt = uint64(block.timestamp);
        record.uri = "https://fixtures.example.invalid/native-assembly/original-preservation-record";
        record.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encodePacked(keccak256(raw)), keccak256("RFC8785_JCS")
        );
    }

    function _assemblySelectDescriptionsAndWaiver() internal {
        T.Binding memory binding_ = IStreamArtistBindingOwner(assemblySuite.owners[0]).binding(1);
        assemblyWorkDescription.subjectId = _assemblySubject();
        assemblyWorkDescription.profileHash = StreamWorkRecordDefinitions.PROFILE_HASH;
        assemblyWorkDescription.full.title = "Native current-stack original artwork";
        assemblyWorkDescription.full.creator.kind = StreamWorkRecordTypes.CreatorKind.ARTIST;
        assemblyWorkDescription.full.creator.artistId = binding_.artistId;
        assemblyWorkDescription.full.creator.bindingGeneration = binding_.generation;
        assemblyWorkDescription.full.creator.bindingHash = binding_.bindingHash;
        assemblyWorkDescription.full.creation.start = 20240229;
        assemblyWorkDescription.full.medium = "Generative instructions";
        assemblyWorkDescription.full.measurements.kind =
        StreamWorkRecordTypes.MeasurementKind.DIMENSIONLESS_GENERATIVE;
        assemblyWorkDescription.full.creditLine = "Original actual Artist/Safe record";
        bytes memory raw = StreamWorkRecordJson.serialize(assemblyWorkDescription);
        IStreamPreservationRecords.CollectionRecord memory record = _assemblyOriginalRecord(
            keccak256("WORK_DESCRIPTION"), StreamWorkRecordDefinitions.SCHEMA_ID, raw
        );
        assemblyWorkRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyWork.selectCurrent(
            1,
            _assemblySubject(),
            assemblyWorkRecord,
            0,
            0,
            IStreamWorkRecordSelection.Witness(record, assemblyWorkDescription)
        );
        assemblyRightsStatement.subjectId = _assemblySubject();
        assemblyRightsStatement.profileHash = StreamRightsRecordDefinitions.PROFILE_HASH;
        assemblyRightsStatement.licensor.kind = StreamRightsRecordTypes.LicensorKind.ACCOUNT;
        assemblyRightsStatement.licensor.account = address(this);
        assemblyRightsStatement.startDate = 20240229;
        assemblyRightsStatement.openEnd = true;
        raw = StreamRightsRecordJson.serialize(assemblyRightsStatement);
        record = _assemblyOriginalRecord(
            keccak256("RIGHTS_STATEMENT"), StreamRightsRecordDefinitions.SCHEMA_ID, raw
        );
        assemblyRightsRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, raw);
        assemblyRights.selectCurrent(
            1, _assemblySubject(), assemblyRightsRecord, 0, 0, assemblyRightsStatement
        );
        assemblyIntentWaiver.subjectId = _assemblySubject();
        assemblyIntentWaiver.profileHash = StreamConservationDefinitions.WAIVER_PROFILE_HASH;
        assemblyIntentWaiver.artist = StreamConservationRecordTypes.ArtistClaim(
            binding_.artistId,
            binding_.generation,
            binding_.bindingHash,
            StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        assemblyIntentWaiver.waiverStatement = _assemblyStatementReference(
            "https://fixtures.example.invalid/native-assembly/explicit-intent-waiver"
        );
        assemblyIntentWaiver.interview.status = StreamConservationRecordTypes.InterviewStatus.WAIVED;
        assemblyIntentWaiver.interview.waiverStatement = _assemblyStatementReference(
            "https://fixtures.example.invalid/native-assembly/explicit-interview-waiver"
        );
        raw = StreamArtistIntentWaiverJson.serialize(assemblyIntentWaiver);
        record = _assemblyOriginalRecord(
            keccak256("ARTIST_INTENT_WAIVER"), StreamConservationDefinitions.WAIVER_SCHEMA_ID, raw
        );
        assemblyWaiverRecord = _assemblyPublishArtistRecord(record, raw);
        IStreamConservationRecordSelection.WaiverWitness memory witness;
        witness.original = record;
        witness.waiver = assemblyIntentWaiver;
        assemblyConservation.adoptWaiver(1, _assemblySubject(), assemblyWaiverRecord, 0, 0, witness);
        _assemblySealDescriptions();
        uint256 safeNonce = assemblyArtist.nonce();
        require(
            executeSafe(
                assemblyArtist,
                assemblyArtistKeys,
                address(assemblyConservation),
                0,
                abi.encodeCall(
                    assemblyConservation.lockArtistIntent,
                    (1, _assemblySubject(), assemblyWaiverRecord, uint64(1))
                ),
                0
            ),
            "actual original Artist Safe seals intent"
        );
        IStreamConservationRecordSelection.IntentLock memory locked =
            assemblyConservation.intentLock(1, _assemblySubject());
        require(
            assemblyArtist.nonce() == safeNonce + 1 && locked.locked
                && locked.locker == address(assemblyArtist) && locked.artistId == binding_.artistId
                && locked.identityRecordHash == binding_.identityRecordHash
                && locked.bindingHash == binding_.bindingHash
                && locked.bindingGeneration == binding_.generation
                && locked.recordHash == assemblyWaiverRecord && locked.revision == 1
                && locked.lockedAt == block.timestamp,
            "original intent selection and Safe authority retained"
        );
    }

    function _assemblyStatementReference(string memory uri)
        private
        pure
        returns (StreamConservationRecordTypes.Reference memory result)
    {
        result.algorithm = 1;
        result.canonicalizationId = keccak256("RAW_BYTES");
        result.digest = abi.encodePacked(keccak256(bytes(uri)));
        result.uri = uri;
    }

    function _assemblyPublishArtistRecord(
        IStreamPreservationRecords.CollectionRecord memory record,
        bytes memory raw
    ) private returns (bytes32 recordHash) {
        (bytes32 payloadHash, address payloadPointer) = assemblyStore.publishChunk(raw);
        (address savedPointer, uint32 savedLength) = assemblyStore.chunk(payloadHash);
        bytes memory savedRaw = assemblyStore.readChunk(payloadHash);
        require(
            payloadHash == keccak256(raw) && payloadPointer != address(0)
                && savedPointer == payloadPointer && savedLength == raw.length
                && savedRaw.length == raw.length && keccak256(savedRaw) == keccak256(raw),
            "exact permissionless original waiver payload before candidate admission"
        );
        AssemblyPublication.Publication memory publication;
        publication.metadataHost = address(assemblyMetadata);
        publication.recorder = address(assemblyArtist);
        publication.collectionId = 1;
        publication.subjectId = _assemblySubject();
        publication.recordType = record.recordType;
        publication.schemaId = record.schemaId;
        publication.canonicalizationId = record.contentHash.canonicalizationId;
        publication.payloadAlgorithm = 1;
        publication.payloadHash = keccak256(raw);
        publication.uriHash = keccak256(bytes(record.uri));
        publication.effectiveAt = record.effectiveAt;
        publication.candidateRecordHash =
            assemblyMetadata.deriveCollectionRecordHashFor(address(assemblyArtist), 1, record);
        bytes memory statement = abi.encode(uint16(1), publication);
        T.Attestation memory attestation = T.Attestation(
            1,
            7,
            _assemblySubject(),
            publication.candidateRecordHash,
            keccak256("6529STREAM_ARTIST_RECORD_PUBLICATION_V1"),
            keccak256(statement),
            record.uri
        );
        T.Authorization memory authorization = _assemblyAuthorization(true);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.attestationDigest(attestation, authorization));
        assemblyWaiverAuthorization =
            assemblyArtists.recordArtistAttestation(attestation, authorization, statement);
        AssemblyPublication.Evidence memory evidence =
            assemblyArtists.requireRecordPublication(assemblyWaiverAuthorization, publication);
        require(
            evidence.attestationRecordHash == assemblyWaiverAuthorization
                && evidence.artistId == assemblyArtistId
                && evidence.signer == address(assemblyArtist) && evidence.authorityClass == 1
                && evidence.requiredCapability == 64 && evidence.signedAt == authorization.time
                && evidence.publicationHash == keccak256(abi.encode(publication)),
            "actual op24 original Safe publication evidence"
        );
        IStreamArtistRecordPublicationOwner.Record memory savedPublication = IStreamArtistRecordPublicationOwner(
                assemblySuite.owners[4]
            ).publicationAttestation(assemblyWaiverAuthorization);
        require(
            keccak256(abi.encode(savedPublication.publication))
                    == keccak256(abi.encode(publication))
                && keccak256(abi.encode(savedPublication.evidence))
                    == keccak256(abi.encode(evidence))
                && savedPublication.metadataHostCodeHash == address(assemblyMetadata).codehash,
            "exact original owner publication and authority evidence"
        );
        recordHash = assemblyMetadata.recordArtistCollectionRecordWithPayload(
            address(assemblyArtist), 1, record, raw, assemblyWaiverAuthorization
        );
        require(
            recordHash == publication.candidateRecordHash, "exact original artist record candidate"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory savedRecord,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = assemblyMetadata.collectionRecord(recordHash);
        require(
            keccak256(abi.encode(savedRecord)) == keccak256(abi.encode(record))
                && receipt.collectionId == 1 && receipt.recorder == address(assemblyArtist)
                && receipt.authorizationClass == 1
                && receipt.artistAuthorization == assemblyWaiverAuthorization
                && receipt.recordIndex == 0 && receipt.recordChainHash != 0
                && assemblyMetadata.consumedArtistAuthorization(assemblyWaiverAuthorization)
                && assemblyMetadata.latestCollectionRecordHashFor(
                    1, record.recordType, record.subjectId, address(assemblyArtist)
                ) == recordHash,
            "original Safe recorder, class1 lane and consumed authorization backlink"
        );
    }

    function _assemblySealDescriptions() private {
        IStreamRecordSelectionLock[2] memory selectors = [
            IStreamRecordSelectionLock(address(assemblyWork)),
            IStreamRecordSelectionLock(address(assemblyRights))
        ];
        bytes32[2] memory records = [assemblyWorkRecord, assemblyRightsRecord];
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](2);
        batch.callDatas = new bytes[](2);
        for (uint256 i; i < 2; ++i) {
            (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
                selectors[i].selectionLockTransition(1, _assemblySubject(), records[i], 1);
            batch.callDatas[i] = abi.encodeCall(
                selectors[i].lockSelection, (1, _assemblySubject(), records[i], uint64(1))
            );
            batch.calls[i] = StreamCurrentStackPlan.call(
                address(selectors[i]), batch.callDatas[i], scope, oldHash, newHash
            );
        }
        _admitAssemblyBatch(batch);
        bytes32 action = _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/seal-original-work-rights"
        );
        for (uint256 i; i < 2; ++i) {
            IStreamRecordSelectionLock.SelectionLock memory seal =
                selectors[i].selectionLock(1, _assemblySubject());
            require(
                seal.locked && seal.recordHash == records[i] && seal.revision == 1
                    && seal.actionId == action && seal.executor == address(assemblyExecutor)
                    && seal.governanceRoot == address(assemblyRoot),
                "actual class2 original selected-head seal"
            );
        }
    }

    function _assemblyLockContent() internal {
        GenesisBatch memory locks;
        locks.actionClass = 1;
        locks.calls = new GovernanceCall[](2);
        locks.callDatas = new bytes[](2);
        locks.callDatas[0] = abi.encodeCall(assemblyRouter.lockDisplayMetadata, (1));
        locks.callDatas[1] = abi.encodeCall(assemblyRouter.lockArtistIdentity, (1));
        for (uint256 i; i < 2; ++i) {
            locks.calls[i] = StreamCurrentStackPlan.call(
                address(assemblyRouter),
                locks.callDatas[i],
                keccak256(abi.encode(address(assemblyRouter), locks.callDatas[i])),
                bytes32(0),
                keccak256(locks.callDatas[i])
            );
        }
        _admitAssemblyBatch(locks);
        _assemblyGovernance(
            locks, "https://fixtures.example.invalid/native-assembly/original-presentation-locks"
        );
        bytes32[] memory classes = new bytes32[](3);
        classes[0] = keccak256("SCRIPT");
        classes[1] = keccak256("MEDIA_MANIFEST");
        classes[2] = keccak256("BASE_URI");
        for (uint256 i; i < classes.length; ++i) {
            for (uint256 j = i + 1; j < classes.length; ++j) {
                if (classes[j] < classes[i]) (classes[i], classes[j]) = (classes[j], classes[i]);
            }
        }
        AssemblyContent.Freeze memory freeze = AssemblyContent.Freeze(
            1, address(assemblyRouter), classes, assemblyRouter.artistContentFreezeState(1)
        );
        T.Authorization memory authorization = _assemblyAuthorization(false);
        authorization.signature =
            _assemblyArtistProof(assemblyArtists.contentFreezeDigest(freeze, authorization));
        bytes32 originalFreeze = assemblyArtists.authorizeArtistContentFreeze(freeze, authorization);
        assemblyRouter.applyArtistContentFreeze(1, originalFreeze);
        IStreamMetadataServingFacts.ServingFacts memory serving =
            assemblyRouter.collectionServingFacts(1);
        require(
            serving.scriptLocked && serving.mediaLocked && serving.baseURILocked
                && serving.dependenciesLocked && serving.artistIdentityLocked
                && serving.displayMetadataLocked,
            "all original serving locks applied"
        );
    }

    function _assemblyCloseAndFreezeCore() internal {
        require(
            !assemblyCore.collectionFreezeStatus(1) && !assemblyCore.collectionBurnsBlocked(1)
                && assemblyCore.collectionStatus(1) == 0
                && assemblyCore.collectionMintedEver(1) == 2,
            "original completed live collection before terminal sealing"
        );
        bytes32 scope = _assemblySubject();
        bytes32 configDomain = 0x854c83f82b7677e58c61a2482a7a430a8318d765d99a95d3fbce5c84be6cc2b5;
        bytes32 burnsDomain = 0x0a834b49bdbe94b7d08a85a25431e3405b397e5f84bf90a90107edb2a58013ec;
        bytes32 freezeDomain = 0xa54d2564d797e7eec4b1cd68d067d7c297bfae640f401ff3b8fde47441079692;
        uint8 supply = assemblyCore.collectionSupplyMode(1);
        bool capped = assemblyCore.collectionHasMaxSupply(1);
        uint256 maximum = assemblyCore.collectionMaxSupply(1);
        GenesisBatch memory batch;
        batch.actionClass = 2;
        batch.calls = new GovernanceCall[](3);
        batch.callDatas = new bytes[](3);
        batch.callDatas[0] = abi.encodeCall(assemblyCore.setCollectionStatus, (1, uint8(2)));
        batch.calls[0] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[0],
            scope,
            keccak256(abi.encode(configDomain, scope, true, supply, uint8(0), capped, maximum)),
            keccak256(abi.encode(configDomain, scope, true, supply, uint8(2), capped, maximum))
        );
        batch.callDatas[1] = abi.encodeCall(assemblyCore.blockCollectionBurns, (1));
        batch.calls[1] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[1],
            scope,
            keccak256(abi.encode(burnsDomain, scope, false)),
            keccak256(abi.encode(burnsDomain, scope, true))
        );
        batch.callDatas[2] = abi.encodeCall(assemblyCore.freezeCollection, (1));
        batch.calls[2] = StreamCurrentStackPlan.call(
            address(assemblyCore),
            batch.callDatas[2],
            scope,
            keccak256(abi.encode(freezeDomain, scope, false)),
            keccak256(abi.encode(freezeDomain, scope, true))
        );
        _admitAssemblyBatch(batch);
        _assemblyGovernance(
            batch, "https://fixtures.example.invalid/native-assembly/close-burn-seal-freeze"
        );
        require(
            assemblyCore.collectionStatus(1) == 2 && assemblyCore.collectionBurnsBlocked(1)
                && assemblyCore.collectionFreezeStatus(1),
            "three original Core terminal transitions"
        );
    }

    function _onboardFixtureArtist(address artist_) internal override {
        bytes memory document = bytes("current-stack artist identity");
        T.BindingProposal memory p;
        p.artistAddress = artist_;
        p.identityRecordHash = keccak256(document);
        p.identityRecordURI = "urn:6529stream:fixture:artist-identity";
        p.consentMode = 1;
        p.saleConsentScope = _fixtureSaleConsentScope();
        p.collaborators = new T.CollaboratorRecord[](0);
        p.capabilityPolicyOverrides = new T.CapabilityPolicyOverride[](0);
        (fixtureArtistId,) = artists.proposeArtistBinding(1, p, document, "Stream Artist");
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.acceptanceDigest(1, a));
        artists.acceptArtistBinding(1, a);
        T.PayoutDesignation memory payout =
            T.PayoutDesignation(fixtureArtistId, artist_, bytes32(0));
        a = _artistAuthorization(true);
        a.signature = _artistProof(artists.payoutDesignationDigest(payout, a));
        artists.recordPayoutDesignation(payout, a);
        (T.AssignmentFact memory primary, T.AssignmentFact memory royalty) =
            artistCoordinator.reads().currentAssignments(1);
        _preparationEconomics(primary);
        _preparationEconomics(royalty);
        // Deliberately defer the original ratification until the actual STATIC activation.
        // Every other original admission below, including kind9/10 op24, retains its producer/order.
        T.Binding memory binding_ = IStreamArtistBindingOwner(artistSuite.owners[0]).binding(1);
        bytes32 facts = StreamArtistHashes.deploymentFacts(
            StreamArtistHashes.Environment(
                block.chainid, address(artists), artistSuite.core, artistSuite.mintManager
            ),
            1,
            binding_
        );
        _preparationAttestation(
            9,
            bytes32(uint256(uint160(artistSuite.core))),
            facts,
            keccak256("6529STREAM_ARTIST_DEPLOYMENT_ATTESTATION_V1")
        );
        _preparationAttestation(
            10,
            fixtureArtistId,
            binding_.identityRecordHash,
            keccak256("6529STREAM_ARTIST_PERSONHOOD_WAIVER_V1")
        );
    }

    function _preparationEconomics(T.AssignmentFact memory fact) private {
        T.EconomicsConsent memory p = T.EconomicsConsent(
            1, fact.resolver, fact.revenueClass, fact.scope, fact.scopeId, fact.assignmentHash
        );
        T.Authorization memory a = _artistAuthorization(false);
        a.signature = _artistProof(artists.economicsConsentDigest(p, a));
        artists.recordEconomicsConsent(p, a);
    }

    function _preparationAttestation(uint8 kind, bytes32 subject, bytes32 state, bytes32 schema)
        private
    {
        bytes memory statement = abi.encode(kind, subject, state, schema);
        T.Attestation memory p = T.Attestation(
            1,
            kind,
            subject,
            state,
            schema,
            keccak256(statement),
            "urn:6529stream:fixture:statement"
        );
        T.Authorization memory a = _artistAuthorization(true);
        a.signature = _artistProof(artists.attestationDigest(p, a));
        artists.recordArtistAttestation(p, a, statement);
    }

    /// @dev Initial Stack configuration must await the actual STATIC first ratification.
    /// The original Manager handoff still occurs; later writes use its real Executor owner.
    function _configureMintPhase(bytes32 phase, address phaseExecutor) internal override {
        require(
            fullPolicyFirstRatification == 0
                && ((phase == PHASE && phaseExecutor == address(sale))
                    || (phase == AUCTION_PHASE && phaseExecutor == address(auction))),
            "only defer original two unratified phases"
        );
        (bool exists,) = manager.phase(1, phase);
        require(!exists, "phase not registered before genuine first ratification");
    }

    function _configurePreparedFullPolicyPhase(bytes32 phase, address phaseExecutor) private {
        require(
            fullPolicyFirstRatification != 0 && manager.owner() == address(executor),
            "actual ratified authority and original Manager owner"
        );
        bytes32[] memory counters = new bytes32[](1);
        counters[0] = keccak256("supply");
        IStreamMintManager.MintCounterConfig[] memory configs =
            new IStreamMintManager.MintCounterConfig[](1);
        configs[0] = IStreamMintManager.MintCounterConfig(
            true,
            IStreamMintManager.CounterKeyMode.CONSTANT,
            IStreamMintLedger.CounterCapMode.STATIC,
            IStreamMintLedger.CounterDeltaMode.STATIC,
            _fixtureSupplyLimit(),
            1,
            keccak256("counter")
        );
        IStreamMintManager.MintGateConfig memory gate;
        IStreamMintManager.MintPhaseConfig memory config = IStreamMintManager.MintPhaseConfig(
            false, 0, 0, 1, keccak256("phase"), keccak256("metadata")
        );
        address[] memory executors = new address[](0);
        _recordFixturePolicy(
            phase,
            manager.previewPhasePolicyHash(1, phase, config, gate, counters, configs, executors)
        );
        bytes memory data =
            abi.encodeCall(manager.configurePhase, (1, phase, config, gate, counters, configs));
        _assemblyGovernanceCall(
            1,
            address(manager),
            data,
            keccak256(abi.encode(address(manager), data)),
            0,
            keccak256(data)
        );
        executors = new address[](1);
        executors[0] = phaseExecutor;
        _recordFixturePolicy(
            phase,
            manager.previewPhasePolicyHash(1, phase, config, gate, counters, configs, executors)
        );
        data = abi.encodeCall(manager.setPhaseExecutor, (1, phase, phaseExecutor, true));
        _assemblyGovernanceCall(
            1,
            address(manager),
            data,
            keccak256(abi.encode(address(manager), data)),
            0,
            keccak256(data)
        );
        require(manager.phaseExecutor(1, phase, phaseExecutor), "original authorized sale executor");
    }

    function _configureFullPolicyStatic() internal {
        (bool ratified,,) = artists.firstReleaseRatification(1);
        require(
            !ratified && core.collectionMintedEver(1) == 0, "activation before original release"
        );
        bytes memory scriptCall =
            abi.encodeCall(router.setCollectionScript, (1, FULL_POLICY_SCRIPT));
        _assemblyGovernanceCall(
            1,
            address(router),
            scriptCall,
            keccak256(abi.encode(address(router), scriptCall)),
            0,
            keccak256(scriptCall)
        );
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            assemblyMetadata.familyWriterTransition(0, family, 8, address(assemblyRoot), true);
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.setFamilyWriter,
                (uint256(0), family, uint8(8), address(assemblyRoot), true)
            ),
            scope,
            before_,
            after_
        );
        _assemblyGrantFamily(family, 7, address(assemblyRoot));
        _preparationRootCall(
            address(router), abi.encodeCall(router.setDefaultMetadataConfig, (_input()))
        );
        bytes32 default_ = router.defaultMetadataConfig().recordHash;
        _preparationRootCall(
            address(router), abi.encodeCall(router.activateStaticMetadata, (1, default_))
        );
        StaticRouter.ConfigRecord memory r = router.collectionMetadataConfig(1);
        require(
            r.recordHash != 0 && r.previous == default_ && r.collectionId == 1 && r.tokenId == 0
                && r.revision == 1 && r.defaultRevision == 1 && r.level == 3
                && r.sourceSnapshotHash == 0 && !r.config.frozen
                && r.selection.registry == address(products.rendering.versions)
                && r.selection.versionKey == versionKey,
            "actual captured original default"
        );
        fullPolicyStaticConfig = r.recordHash;
    }

    /// @dev Original optional attribution reserves 8m inside the renderer; the Router's
    /// default 8m marketplace frame cannot reproduce the admitted 20m golden output.
    /// This explicit governed fixture cap matches the high-budget ceremony, not launch limits.
    function _raiseFullPolicyRouterRenderBudget() private {
        IStreamGasParameterHost host = IStreamGasParameterHost(address(router));
        bytes32 id = keccak256("6529STREAM_GGP_ROUTER_BUNDLE_RENDER_GAS");
        (uint256 value, uint256 floor, uint8 failure, uint64 revision) = host.gasParameterInfo(id);
        require(
            value == 8000000 && failure == 2 && revision == 1, "original Router marketplace budget"
        );
        uint256 next = 16000000;
        bytes32 scope = keccak256(
            abi.encode(
                keccak256("6529STREAM_GAS_PARAMETER_SCOPE_V2"), block.chainid, address(host), id
            )
        );
        bytes32 domain = keccak256("6529STREAM_GAS_PARAMETER_STATE_V2");
        _assemblyGovernanceCall(
            1,
            address(host),
            abi.encodeCall(host.raiseGasParameter, (id, next)),
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failure, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failure, revision + 1))
        );
        (uint256 saved,,, uint64 savedRevision) = host.gasParameterInfo(id);
        require(saved == next && savedRevision == revision + 1, "actual governed Router budget");
    }

    function _fullPolicyRatifyInitialContent() private {
        (, bytes32 contentState) = router.currentArtistContentState(1);
        T.Ratification memory p = T.Ratification(1, address(router), contentState);
        T.Authorization memory a = _assemblyAuthorization(false);
        a.signature = _assemblyArtistProof(artists.contentRatificationDigest(p, a));
        fullPolicyFirstRatification = artists.recordContentRatification(p, a);
        (bool ratified,,) = artists.firstReleaseRatification(1);
        require(
            ratified && fullPolicyFirstRatification != 0 && core.collectionMintedEver(1) == 0,
            "real first ratification after STATIC and before mint"
        );
    }

    function _freezeFullPolicyStatic() internal {
        StaticRouter.ConfigInput memory input = _input();
        input.config.frozen = true;
        AssemblyContent.Consent memory p = AssemblyContent.Consent(
            1,
            address(router),
            keccak256("RENDERER_CONFIG"),
            router.previewStaticMetadataConfig(1, 0, input)
        );
        T.Authorization memory a = _assemblyAuthorization(false);
        a.signature = _assemblyArtistProof(artists.contentConsentDigest(p, a));
        fullPolicyRendererConsent = artists.recordContentConsent(p, a);
        require(
            fullPolicyRendererConsent != 0
                && !router.consumedArtistContentConsent(fullPolicyRendererConsent),
            "fresh original renderer op17 consent"
        );
        _preparationRootCall(
            address(router), abi.encodeCall(router.setCollectionMetadataConfig, (1, input))
        );
        StaticRouter.ConfigRecord memory r = router.collectionMetadataConfig(1);
        require(
            r.recordHash != fullPolicyStaticConfig && r.config.frozen && r.sourceSnapshotHash != 0
                && r.collectionId == 1 && r.tokenId == 0 && r.revision == 2 && r.level == 1
                && router.consumedArtistContentConsent(fullPolicyRendererConsent),
            "frozen STATIC op17 applied"
        );
        fullPolicyStaticConfig = r.recordHash;
        (StaticRouter.RawSource memory source,) =
            router.staticRenderSourceForConfig(1, r.recordHash);
        require(
            keccak256(bytes(source.script)) == keccak256(bytes(FULL_POLICY_SCRIPT))
                && r.sourceSnapshotHash
                    == keccak256(
                        abi.encode(keccak256("6529STREAM_STATIC_SOURCE_SNAPSHOT_V1"), source)
                    ),
            "exact retained STATIC source"
        );
    }

    function _preparationRootCall(address target, bytes memory data) private {
        uint256 nonce = assemblyRoot.nonce();
        require(
            executeSafe(assemblyRoot, assemblyRootKeys, target, 0, data, 0),
            "real governor family writer"
        );
        require(assemblyRoot.nonce() == nonce + 1, "original Safe call consumed exactly once");
    }

    function _admitFullPolicyCurrentCitation() internal {
        Versions.Target[] memory targets = _targets();
        Versions.Read[] memory reads_ = new Versions.Read[](declaredReads.length + 1);
        for (uint256 i; i < declaredReads.length; ++i) {
            reads_[i] = declaredReads[i];
        }
        TokenCitationRegistry.CurrentRegistration memory r;
        r.versionKey = versionKey;
        r.profile = keccak256("6529STREAM_CURRENT_BASE_CITATION_V1");
        r.selector = TokenCitationRenderer.renderCurrent.selector;
        (r.encoding, r.encodingRuntimeHash) = products.rendering.renderer.encodingBinding();
        uint16 encoder;
        bool found;
        for (uint16 i; i < targets.length; ++i) {
            if (targets[i].target == r.encoding) {
                require(!found, "one original encoding target");
                found = true;
                encoder = i;
            }
        }
        require(found, "original registry roster retains encoder");
        reads_[declaredReads.length] = Versions.Read(
            encoder, StreamStaticRenderEncoding.renderCurrent.selector, 16777216, false
        );
        for (uint256 i = 1; i < reads_.length; ++i) {
            for (uint256 j = i; j > 0 && _readOrder(reads_[j - 1]) > _readOrder(reads_[j]); --j) {
                (reads_[j - 1], reads_[j]) = (reads_[j], reads_[j - 1]);
            }
        }
        bytes32 oldVersion = keccak256(abi.encode(products.rendering.versions.version(versionKey)));
        bytes32 oldGolden = products.rendering.versions.registration(versionKey).goldenDocument;
        bytes32 readHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_RENDERER_READ_SET_V1"), keccak256(abi.encode(targets)), reads_
            )
        );
        TokenCitationRegistry.CurrentAnalysis memory analysis = TokenCitationRegistry.CurrentAnalysis(
            keccak256("6529STREAM_CURRENT_BASE_CITATION_ANALYSIS_ABI_V1"),
            r.profile,
            r.selector,
            address(products.rendering.renderer),
            address(products.rendering.renderer).codehash,
            r.encoding,
            r.encodingRuntimeHash,
            readHash,
            products.rendering.versions.version(versionKey).registrationHash,
            keccak256("SYNTHETIC FIXTURE: no transitive opcode analysis executed"),
            keccak256("SYNTHETIC FIXTURE: original partial roster plus current encoding selector"),
            true
        );
        r.analysisDocument = _document(
            "FULL_POLICY_CURRENT_CITATION_ANALYSIS_FIXTURE",
            Schema.DocumentKind.CATALOG,
            abi.encode(analysis)
        );
        TokenCitationRegistry.CurrentGoldenVector[] memory vectors =
            new TokenCitationRegistry.CurrentGoldenVector[](6);
        for (uint256 i; i < 2; ++i) {
            Render.RenderRequest memory request = _fullPolicyRenderRequest(fullPolicyTokens[i]);
            string memory historical = products.rendering.renderer.renderView(request, 0);
            string memory historicalFull = products.rendering.renderer.renderView(request, 2);
            string memory current = _preparationInsertCitation(historical, fullPolicyTokens[i]);
            string memory currentFull =
                _preparationInsertCitation(historicalFull, fullPolicyTokens[i]);
            vectors[3 * i] =
                TokenCitationRegistry.CurrentGoldenVector(request, 0, keccak256(bytes(current)));
            vectors[3 * i + 1] = TokenCitationRegistry.CurrentGoldenVector(
                request,
                1,
                keccak256(
                    bytes(
                        string.concat(
                            "data:application/json;base64,", Base64.encode(bytes(current))
                        )
                    )
                )
            );
            vectors[3 * i + 2] = TokenCitationRegistry.CurrentGoldenVector(
                request, 2, keccak256(bytes(currentFull))
            );
        }
        r.goldenDocument = _document(
            "FULL_POLICY_CURRENT_CITATION_TWO_TOKEN_GOLDEN_FIXTURE",
            Schema.DocumentKind.CATALOG,
            abi.encode(vectors)
        );
        (bytes32 scope, bytes32 before_, bytes32 after_) =
            products.rendering.versions.currentCitationTransition(r, reads_);
        _assemblyGovernanceCall(
            1,
            address(products.rendering.versions),
            abi.encodeCall(TokenCitationRegistry.registerCurrentCitation, (r, reads_)),
            scope,
            before_,
            after_
        );
        TokenCitationRegistry.CurrentRecord memory saved =
            products.rendering.versions.currentCitationRecord(versionKey);
        require(
            saved.registrationHash
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_CURRENT_CITATION_REGISTRATION_V1"),
                            block.chainid,
                            address(products.rendering.versions),
                            address(assemblySchemas),
                            address(assemblySchemas).codehash,
                            keccak256(abi.encode(targets)),
                            products.rendering.versions.version(versionKey).registrationHash,
                            r,
                            reads_
                        )
                    ) && saved.readSetHash == readHash
                && saved.analysisHash == keccak256(abi.encode(analysis))
                && saved.goldenHash == keccak256(abi.encode(vectors)) && saved.actionId != 0,
            "original current citation evidence admitted"
        );
        require(
            oldVersion == keccak256(abi.encode(products.rendering.versions.version(versionKey)))
                && oldGolden == products.rendering.versions.registration(versionKey).goldenDocument,
            "historical renderer admission preserved"
        );
        for (uint256 i; i < 2; ++i) {
            require(
                keccak256(bytes(router.tokenURI(address(core), fullPolicyTokens[i])))
                        == vectors[3 * i + 1].outputHash
                    && keccak256(bytes(router.tokenJSON(fullPolicyTokens[i])))
                        == vectors[3 * i + 2].outputHash,
                "actual Router current outputs match independent citation bytes"
            );
        }
    }

    function _fullPolicyRenderRequest(uint256 token)
        internal
        view
        returns (Render.RenderRequest memory r)
    {
        (bool exists, uint256 collection, uint256 serial, bool burned) =
            core.tokenCollectionIdentity(token);
        (uint8 status, bytes32 seed, address selectedProvider) =
            entropy.staticTokenRenderFacts(token);
        require(
            exists && collection == 1 && !burned && status == 5 && seed != 0
                && selectedProvider == address(provider),
            "genuine finalized original token"
        );
        r = Render.RenderRequest(
            address(core),
            token,
            collection,
            serial,
            seed,
            Render.TokenRenderState.FROZEN,
            Render.MetadataMode.ONCHAIN,
            core.collectionSupplyMode(1),
            core.collectionStatus(1),
            0,
            0,
            fullPolicyStaticConfig
        );
    }

    /// @dev Literal test-only insertion at the unique original context/provenance boundary;
    /// neither the production citation serializer nor renderCurrent supplies expected bytes.
    function _preparationInsertCitation(string memory historical, uint256 token)
        private
        view
        returns (string memory)
    {
        bytes memory source = bytes(historical);
        bytes memory needle = bytes('},"provenance":{"attribution":');
        bytes memory replacement = abi.encodePacked(
            ',"citation":"eip155:',
            block.chainid.toString(),
            "/erc721:",
            uint256(uint160(address(core))).toHexString(20),
            "/",
            token.toString(),
            '"',
            needle
        );
        uint256 position;
        uint256 matches;
        for (uint256 i; i + needle.length <= source.length; ++i) {
            bool same = true;
            for (uint256 j; j < needle.length; ++j) {
                if (source[i + j] != needle[j]) {
                    same = false;
                    break;
                }
            }
            if (same) {
                position = i;
                ++matches;
            }
        }
        require(matches == 1, "one literal historical context boundary");
        bytes memory out = new bytes(source.length + replacement.length - needle.length);
        for (uint256 i; i < position; ++i) {
            out[i] = source[i];
        }
        for (uint256 i; i < replacement.length; ++i) {
            out[position + i] = replacement[i];
        }
        for (uint256 i = position + needle.length; i < source.length; ++i) {
            out[i + replacement.length - needle.length] = source[i];
        }
        return string(out);
    }

    function _assertFullPolicyPrepared() internal view {
        require(
            core.collectionMintedEver(1) == 2 && core.collectionStatus(1) == 2
                && core.collectionBurnsBlocked(1) && core.collectionFreezeStatus(1),
            "terminal original Core before checkpoint"
        );
        require(
            assemblyWorkRecord != 0 && assemblyRightsRecord != 0 && assemblyWaiverRecord != 0
                && assemblyWaiverAuthorization != 0 && fullPolicyFirstRatification != 0,
            "original selected descriptions retained"
        );
        for (uint256 i; i < 2; ++i) {
            require(
                router.resolvedMetadataConfig(fullPolicyTokens[i]).recordHash
                    == fullPolicyStaticConfig,
                "both original tokens select same frozen config"
            );
        }
    }
}
