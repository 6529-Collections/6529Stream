// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopeMembershipPublicationFixture.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @dev Actual Metadata, schema/store, inventory and membership; Core and governance are named
/// fixture boundaries. Safe cases use original upstream proxy bytecode and threshold signatures.
contract StreamMetadataPublishedScopeSubjectTest is
    ScopeMembershipPublicationFixture,
    OfficialSafeFixture
{
    bytes32 private constant NOTE = keccak256("SCOPED_RECORD_REGRESSION");
    event MetadataScopeSubjectRegistered(
        bytes32 indexed subjectId,
        uint256 indexed collectionId,
        bytes32 indexed membershipRecordHash,
        uint8 scopeType,
        bytes32 scopeId
    );

    function testAllThreePublishedFamiliesBecomeWritableUnderExistingGrant() public {
        for (uint8 kind = 2; kind <= 4; ++kind) {
            (bytes32 record, StreamFinalityScope memory scope) = _source(kind, "ipfs://scope");
            bytes32 subject = _subject(scope);
            (IStreamPreservationRecords.CollectionRecord memory note, bytes memory payload) =
                _note(subject);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamCollectionMetadataV1.UnknownMetadataSubject.selector, subject
                )
            );
            metadata.recordCollectionRecordWithPayload(1, note, payload);
            vm.expectEmit(true, true, true, true);
            emit MetadataScopeSubjectRegistered(subject, 1, record, kind, scope.scopeId);
            require(metadata.registerScopeSubject(record) == subject, "canonical subject");
            bytes32 saved = metadata.recordCollectionRecordWithPayload(1, note, payload);
            (
                IStreamPreservationRecords.CollectionRecord memory read,
                IStreamCollectionMetadataV1.RecordReceipt memory receipt
            ) = metadata.collectionRecord(saved);
            require(
                read.subjectId == subject && receipt.collectionId == 1
                    && receipt.authorizationClass == 7,
                "original append and authority"
            );
        }
    }

    function testRegistrationDoesNotClaimMembershipCompletionAndCanPrecedeFinalityDeployment()
        public
    {
        (bytes32 record, StreamFinalityScope memory scope) = _source(2, "ipfs://before-membership");
        metadata.registerScopeSubject(record);
        vm.expectRevert();
        membership.requireScopeMembership(scope);
        StreamFinalityScope memory admitted = membership.beginScopeMembership(record);
        require(
            keccak256(abi.encode(admitted)) == keccak256(abi.encode(scope)), "same producer grammar"
        );
        vm.expectRevert();
        membership.requireScopeMembership(scope);
        membership.continueScopeMembership(scope, 1);
        require(
            membership.requireScopeMembership(scope).scopeSubject == _subject(scope),
            "independent complete membership"
        );
    }

    function testPermissionlessIdempotentNamingDoesNotGrantWritingAuthority() public {
        (bytes32 record, StreamFinalityScope memory scope) = _source(3, "ipfs://no-authority");
        vm.prank(address(0xBEEF));
        require(metadata.registerScopeSubject(record) == _subject(scope));
        require(metadata.registerScopeSubject(record) == _subject(scope));
        (bool enabled, uint64 revision) =
            metadata.familyWriter(1, StreamRecordFamilies.IDENTITY, 7, address(0xBEEF));
        require(!enabled && revision == 0, "no implicit grant");
        (IStreamPreservationRecords.CollectionRecord memory note, bytes memory payload) =
            _note(_subject(scope));
        vm.expectRevert();
        vm.prank(address(0xBEEF));
        metadata.recordCollectionRecordWithPayload(1, note, payload);
        metadata.recordCollectionRecordWithPayload(1, note, payload);
    }

    function testUnknownRecordCannotRegisterArbitrarySubject() public {
        vm.expectRevert();
        metadata.registerScopeSubject(bytes32(uint256(991)));
        vm.expectRevert();
        metadata.registerScopeSubject(bytes32(0));
    }

    function testOtherRecordTypeCannotBeReinterpretedAsMembership() public {
        bytes32 subject = _subject(StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0));
        (IStreamPreservationRecords.CollectionRecord memory note, bytes memory payload) =
            _note(subject);
        bytes32 record = metadata.recordCollectionRecordWithPayload(1, note, payload);
        vm.expectRevert();
        metadata.registerScopeSubject(record);
    }

    function testSourceRuntimeDriftRefusesRegistration() public {
        (bytes32 record,) = _source(2, "ipfs://runtime");
        vm.etch(address(store), hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataDependencyChanged.selector, address(store)
            )
        );
        metadata.registerScopeSubject(record);
    }

    function testWrongChainManifestCannotCreateSubject() public {
        uint256[] memory ids = _tokens(1);
        StreamScopeMembershipManifest memory manifest = _manifest(2, ids);
        manifest.chainId = block.chainid + 1;
        bytes32 record = _publish(manifest, "ipfs://wrong-chain");
        vm.expectRevert();
        metadata.registerScopeSubject(record);
    }

    function testScopeRecordIdentityAndFamilyCannotAlias() public {
        (bytes32 first, StreamFinalityScope memory a) = _source(2, "ipfs://first");
        (bytes32 second, StreamFinalityScope memory b) = _source(2, "ipfs://second");
        bytes32 subjectA = metadata.registerScopeSubject(first);
        bytes32 subjectB = metadata.registerScopeSubject(second);
        require(subjectA != subjectB && a.scopeId != b.scopeId, "record-qualified identity");
        b.scopeType = StreamFinalityScopeType.SEASON;
        bytes32 forged = _subject(b);
        (IStreamPreservationRecords.CollectionRecord memory note, bytes memory payload) =
            _note(forged);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.UnknownMetadataSubject.selector, forged
            )
        );
        metadata.recordCollectionRecordWithPayload(1, note, payload);
    }

    function testNewInterfacePreservesOriginalMetadataInterfaceAndTokenRegistration() public {
        require(metadata.supportsInterface(type(IStreamCollectionMetadataV1).interfaceId));
        require(metadata.supportsInterface(type(IStreamMetadataPublishedScopeSubject).interfaceId));
        require(!metadata.supportsInterface(0xffffffff));
        uint256[] memory ids = _tokens(1);
        require(
            metadata.registerTokenSubject(ids[0])
                == _subject(StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, ids[0], 0))
        );
    }

    function testSafe130CanRegisterAndUseExistingWriterGrant() public {
        _safeFlow("1.3.0");
    }

    function testSafe141CanRegisterAndUseExistingWriterGrant() public {
        _safeFlow("1.4.1");
    }

    function _safeFlow(string memory version) private {
        (bytes32 record, StreamFinalityScope memory scope) = _source(4, "ipfs://safe-scope");
        uint256[] memory keys = new uint256[](2);
        keys[0] = 6121;
        keys[1] = 6122;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents(version), safeOwnerAddresses(keys), 2, 71);
        require(
            executeSafe(
                account,
                keys,
                address(metadata),
                0,
                abi.encodeCall(metadata.registerScopeSubject, (record)),
                0
            )
        );
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(account), true);
        (IStreamPreservationRecords.CollectionRecord memory note, bytes memory payload) =
            _note(_subject(scope));
        bytes32 expected = metadata.deriveCollectionRecordHashFor(address(account), 1, note);
        require(
            executeSafe(
                account,
                keys,
                address(metadata),
                0,
                abi.encodeCall(
                    metadata.recordCollectionRecordWithPayload, (uint256(1), note, payload)
                ),
                0
            )
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(expected);
        require(
            receipt.recorder == address(account) && receipt.authorizationClass == 7
                && account.nonce() == 2,
            "real Safe and original grant"
        );
    }

    function _source(uint8 kind, string memory uri)
        private
        returns (bytes32 record, StreamFinalityScope memory scope)
    {
        uint256[] memory ids = _tokens(1);
        (uint256 count,) = inventory.collectionInventoryState(1);
        if (count == 0) _index(ids, 0, 1);
        record = _publish(_manifest(kind, ids), uri);
        scope = StreamFinalityScope(
            StreamFinalityScopeType(kind),
            1,
            0,
            StreamScopeMembershipEncoding.scopeId(block.chainid, address(core), 1, kind, record)
        );
    }

    function _subject(StreamFinalityScope memory scope) private view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(block.chainid, address(core), scope);
    }

    function _note(bytes32 subject)
        private
        returns (IStreamPreservationRecords.CollectionRecord memory record, bytes memory payload)
    {
        if (!metadata.recordPolicy(NOTE).admitted) {
            _admit(NOTE, StreamRecordFamilies.IDENTITY, 384);
        }
        uint256[] memory ids = new uint256[](0);
        (record, payload) = _record(_manifest(2, ids), "ipfs://scoped-record");
        record.recordType = NOTE;
        record.subjectId = subject;
    }
}
