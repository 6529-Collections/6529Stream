// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/ScopeMembershipPublicationFixture.sol";

contract StreamScopeMembershipPublicationTest is ScopeMembershipPublicationFixture {
    function testActualPublishedRecordAllFamiliesExactFactsAndEvents() public {
        uint256[] memory ids = _tokens(3);
        _index(ids, 0, 3);
        bytes32 previous;
        for (uint8 family = 2; family <= 4; ++family) {
            StreamScopeMembershipManifest memory m = _manifest(family, ids);
            bytes32 recordHash = _publish(m, "ipfs://scope");
            vm.recordLogs();
            vm.prank(address(0xa11ce));
            StreamFinalityScope memory s = membership.beginScopeMembership(recordHash);
            bytes32 manifestHash = keccak256(StreamScopeMembershipEncoding.encode(m));
            {
                Vm.Log[] memory admitted = vm.getRecordedLogs();
                require(admitted.length == 1 && admitted[0].emitter == address(membership));
                require(
                    admitted[0].topics[0]
                        == keccak256(
                            "ScopeMembershipAdmitted(bytes32,uint256,uint8,bytes32,bytes32,bytes32,uint256,address,uint8)"
                        )
                );
                require(
                    admitted[0].topics[1] == s.scopeId
                        && admitted[0].topics[2] == bytes32(uint256(1))
                        && admitted[0].topics[3] == bytes32(uint256(family))
                );
                require(
                    keccak256(admitted[0].data)
                        == keccak256(
                            abi.encode(
                                recordHash,
                                manifestHash,
                                m.tokenListHash,
                                uint256(3),
                                address(this),
                                uint8(7)
                            )
                        )
                );
            }
            require(
                s.scopeId
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPE_MEMBERSHIP_ID_V1"),
                            block.chainid,
                            address(core),
                            uint256(1),
                            family,
                            recordHash
                        )
                    )
            );
            require(s.scopeId != previous);
            previous = s.scopeId;
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamFinalityScopeMembership.ScopeMembershipIncomplete.selector, s.scopeId
                )
            );
            membership.requireScopeMembership(s);
            vm.recordLogs();
            vm.prank(address(0xb0b));
            membership.continueScopeMembership(s, 1);
            StreamScopeMembershipFacts memory f = membership.requireScopeMembership(s);
            {
                Vm.Log[] memory sealLogs = vm.getRecordedLogs();
                require(
                    sealLogs.length == 2 && sealLogs[0].emitter == address(membership)
                        && sealLogs[1].emitter == address(membership)
                );
                require(
                    sealLogs[0].topics[0]
                            == keccak256("ScopeMembershipProgressed(bytes32,uint256,uint256)")
                        && sealLogs[0].topics[1] == s.scopeId
                );
                require(
                    keccak256(sealLogs[0].data) == keccak256(abi.encode(uint256(1), uint256(3)))
                );
                require(
                    sealLogs[1].topics[0]
                            == keccak256("ScopeMembershipSealed(bytes32,bytes32,uint256)")
                        && sealLogs[1].topics[1] == s.scopeId
                );
                require(
                    keccak256(sealLogs[1].data)
                        == keccak256(abi.encode(f.membershipHash, uint256(3)))
                );
            }
            require(
                f.scopeSubject
                    == StreamMetadataSubjects.scopeSubject(block.chainid, address(core), s)
            );
            require(
                f.scopeManifestHash == manifestHash && f.sourceRecordHash == recordHash
                    && f.tokenCount == 3 && f.tokenListHash == m.tokenListHash
                    && f.inventoryCount == 0 && f.inventoryPrefixHash == 0
            );
            {
                (bytes32 subject, bytes32 manifest) = membership.requireRecoveryScope(s);
                require(subject == f.scopeSubject && manifest == manifestHash);
            }
            {
                IStreamFinalityScopeMembership.Publication memory p =
                    membership.scopeMembershipPublication(s);
                require(
                    p.recordHash == recordHash && p.receipt.recorder == address(this)
                        && p.receipt.authorizationClass == 7 && p.receipt.recordedAt == 1000
                );
                require(p.payloadPointer.codehash == p.payloadCodeHash && p.effectiveAt == 1000);
            }
            {
                (bool ok, bytes memory raw) = address(membership)
                    .staticcall(abi.encodeCall(membership.requireScopeMembership, (s)));
                require(ok && raw.length == 256 && keccak256(raw) == keccak256(abi.encode(f)));
            }
            for (uint256 i; i < 3; ++i) {
                require(
                    membership.scopeTokenAt(s, i) == ids[i]
                        && membership.scopeCoversToken(s, ids[i])
                );
            }
            require(!membership.scopeCoversToken(s, 777));
            require(
                keccak256(abi.encode(membership.beginScopeMembership(recordHash)))
                    == keccak256(abi.encode(s))
            );
        }
    }

    function testEarlyBeginCannotStrandUnindexedMembersAndCompletePartsAreAtomic() public {
        uint256[] memory ids = _tokens(257);
        _index(ids, 0, 256);
        StreamFinalityScope memory s =
            membership.beginScopeMembership(_publish(_manifest(2, ids), "ipfs://multi"));
        membership.continueScopeMembership(s, 1);
        IStreamFinalityScopeMembership.Progress memory p = membership.scopeMembershipProgress(s);
        require(
            !p.complete && p.processedTokens == 256 && p.totalTokens == 257 && p.processedParts == 1
                && p.totalParts == 2
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipReadFailed.selector,
                address(inventory),
                IStreamCollectionTokenInventory.collectionTokenAt.selector
            )
        );
        membership.continueScopeMembership(s, 1);
        require(
            keccak256(abi.encode(p)) == keccak256(abi.encode(membership.scopeMembershipProgress(s)))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipIncomplete.selector, s.scopeId
            )
        );
        membership.requireRecoveryScope(s);
        _index(ids, 256, 257);
        membership.continueScopeMembership(s, 1);
        require(
            membership.scopeMembershipProgress(s).complete
                && membership.requireScopeMembership(s).tokenCount == 257
        );
        require(membership.scopeTokenAt(s, 256) == ids[256]);
    }

    function testPreparedWrongCollectionDuplicateAndWrongWholeHashRejectWithoutProgress() public {
        uint256[] memory ids = _tokens(3);
        _index(ids, 0, 3);
        uint256[] memory bad = new uint256[](2);
        bad[0] = 3;
        bad[1] = 12;
        core.setToken(12, 1, 4, 1);
        StreamFinalityScope memory prepared =
            membership.beginScopeMembership(_publish(_manifest(2, bad), "ipfs://prepared"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipTokenInvalid.selector, uint256(12)
            )
        );
        membership.continueScopeMembership(prepared, 1);
        require(membership.scopeMembershipProgress(prepared).processedTokens == 0);
        core.setToken(12, 2, 1, 2);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipTokenInvalid.selector, uint256(12)
            )
        );
        membership.continueScopeMembership(prepared, 1);
        bad[1] = 3;
        StreamFinalityScope memory duplicate =
            membership.beginScopeMembership(_publish(_manifest(3, bad), "ipfs://duplicate"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipTokenInvalid.selector, uint256(3)
            )
        );
        membership.continueScopeMembership(duplicate, 1);
        require(membership.scopeMembershipProgress(duplicate).processedTokens == 0);
        StreamScopeMembershipManifest memory m = _manifest(4, ids);
        m.tokenListHash = keccak256("wrong whole");
        StreamFinalityScope memory wrong =
            membership.beginScopeMembership(_publish(m, "ipfs://wrong"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipProgressInvalid.selector
            )
        );
        membership.continueScopeMembership(wrong, 1);
        require(
            !membership.scopeMembershipProgress(wrong).complete
                && membership.scopeMembershipProgress(wrong).processedTokens == 0
        );
        StreamFinalityScope memory good = _seal(4, ids, "ipfs://good");
        require(membership.requireScopeMembership(good).tokenCount == 3);
    }

    function testHistoricalScopeSurvivesBurnLaterMintGrantRevocationAndSchemaRetirement() public {
        uint256[] memory ids = _tokens(3);
        _index(ids, 0, 3);
        StreamScopeMembershipManifest memory m = _manifest(2, ids);
        bytes32 hash = _publish(m, "ipfs://first");
        StreamFinalityScope memory s = membership.beginScopeMembership(hash);
        membership.continueScopeMembership(s, 1);
        bytes32 facts = keccak256(abi.encode(membership.requireScopeMembership(s)));
        bytes32 next = _publish(m, "ipfs://same-set-different-record");
        _grant(1, StreamRecordFamilies.IDENTITY, 7, address(this), false);
        (bytes32 gs, bytes32 go, bytes32 gn) =
            schemas.statusTransition(SCOPE_SCHEMA, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (SCOPE_SCHEMA, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            gs,
            go,
            gn
        );
        StreamFinalityScope memory second = membership.beginScopeMembership(next);
        membership.continueScopeMembership(second, 1);
        require(second.scopeId != s.scopeId);
        core.setToken(3, 1, 1, 3);
        core.setToken(12, 1, 4, 2);
        require(
            keccak256(abi.encode(membership.requireScopeMembership(s))) == facts
                && membership.scopeCoversToken(s, 3) && !membership.scopeCoversToken(s, 12)
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipReadFailed.selector,
                address(inventory),
                IStreamCollectionTokenInventory.requireCompleteCollection.selector
            )
        );
        membership.requireScopeMembership(collection);
        uint256[] memory one = new uint256[](1);
        one[0] = 12;
        inventory.appendCollectionTokens(1, one);
        StreamScopeMembershipFacts memory f = membership.requireScopeMembership(collection);
        require(
            f.tokenCount == 4 && f.inventoryCount == 4 && f.inventoryPrefixHash != 0
                && f.scopeManifestHash == 0 && f.sourceRecordHash == 0 && f.tokenListHash == 0
        );
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 3, 0);
        f = membership.requireScopeMembership(token);
        require(
            f.tokenCount == 1 && f.tokenListHash == keccak256(abi.encode(uint256(3)))
                && f.scopeManifestHash == 0 && f.inventoryCount == 0
        );
        require(membership.scopeTokenAt(token, 0) == 3 && membership.scopeCoversToken(token, 3));
    }

    function testNativePointerPinFailureRestoresAndConstructorRejectsChangedBaseline() public {
        uint256[] memory ids = _tokens(2);
        _index(ids, 0, 2);
        StreamScopeMembershipManifest memory m = _manifest(4, ids);
        StreamFinalityScope memory s = membership.beginScopeMembership(_publish(m, "ipfs://pin"));
        (address pointer,) = store.chunk(m.chunkHashes[0]);
        bytes memory code = pointer.code;
        vm.etch(pointer, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipDependencyChanged.selector, pointer
            )
        );
        membership.continueScopeMembership(s, 1);
        require(membership.scopeMembershipProgress(s).processedTokens == 0);
        vm.etch(pointer, code);
        membership.continueScopeMembership(s, 1);
        bytes32 facts = keccak256(abi.encode(membership.requireScopeMembership(s)));
        vm.etch(pointer, hex"00");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipDependencyChanged.selector, pointer
            )
        );
        membership.requireScopeMembership(s);
        vm.etch(pointer, code);
        require(keccak256(abi.encode(membership.requireScopeMembership(s))) == facts);
        bytes memory coreCode = address(core).code;
        vm.etch(address(core), bytes.concat(coreCode, hex"00"));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.InvalidScopeMembershipConfiguration.selector
            )
        );
        new StreamFinalityScopeMembership(
            address(core),
            address(metadata),
            address(inventory),
            address(executor),
            IStreamGasParameterHost.GasParameterConfig(
                "SCOPE_MEMBERSHIP_READ_GAS", 500000, 50000, 1
            )
        );
        vm.etch(address(core), coreCode);
        require(keccak256(abi.encode(membership.requireScopeMembership(s))) == facts);
    }

    function testPublicationRequiresActualGovernedWriterWhileEmptyScopeOnlyMeansEmpty() public {
        uint256[] memory empty = new uint256[](0);
        StreamScopeMembershipManifest memory m = _manifest(2, empty);
        (IStreamPreservationRecords.CollectionRecord memory r, bytes memory payload) =
            _record(m, "ipfs://empty");
        vm.prank(address(0xbad));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        _grant(1, StreamRecordFamilies.IDENTITY, 8, address(0xb0b), true);
        vm.prank(address(0xb0b));
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        StreamFinalityScope memory s = membership.beginScopeMembership(hash);
        require(!membership.scopeMembershipProgress(s).complete);
        membership.continueScopeMembership(s, 1);
        StreamScopeMembershipFacts memory f = membership.requireScopeMembership(s);
        require(
            f.tokenCount == 0 && f.tokenListHash == keccak256("")
                && membership.scopeMembershipPublication(s).receipt.authorizationClass == 8
        );
        require(!membership.scopeCoversToken(s, 3));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamFinalityScopeMembership.ScopeMembershipIndexOutOfBounds.selector, uint256(0)
            )
        );
        membership.scopeTokenAt(s, 0);
        require(membership.supportsInterface(type(IStreamFinalityScopeMembership).interfaceId));
        require(
            membership.supportsInterface(type(IStreamFinalityRecoveryScopeEvidence).interfaceId)
        );
        require(!membership.supportsInterface(0xffffffff));
        require(address(membership).code.length <= 24576 && address(metadata).code.length <= 24576);
    }
}
