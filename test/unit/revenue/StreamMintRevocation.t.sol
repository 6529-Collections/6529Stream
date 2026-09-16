// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";

contract StreamMintRevocationTest is MintRevocationTestBase {
    function testFullTicketVoidSharesManagerLedgerReplayWithoutMintWrites() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(1);
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529STREAM_MINT_TICKET_AUTHORIZATION_V1"),
                StreamMintTicketHash.digest(block.chainid, GATE, t)
            )
        );
        require(id == expected, "full key");
        IStreamMintManager.MintBatch memory b = _batch(id);
        (bytes32 root,) = manager.previewSingleStepMintOperation(b, "");
        vm.recordLogs();
        vm.prank(signer);
        require(manager.voidMintTicket(t, GATE, "") == id, "void result");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 2, "only void events");
        require(
            logs[0].emitter == address(ledger) && logs[0].topics.length == 3
                && logs[0].topics[0]
                    == keccak256("MintLedgerAuthorizationVoided(uint16,bytes32,address)")
                && logs[0].topics[1] == id
                && logs[0].topics[2] == bytes32(uint256(uint160(address(manager))))
                && keccak256(logs[0].data) == keccak256(abi.encode(uint16(1))),
            "ledger event"
        );
        require(
            logs[1].emitter == address(manager) && logs[1].topics.length == 4
                && logs[1].topics[0]
                    == keccak256(
                        "MintAuthorizationVoided(uint16,uint256,bytes32,bytes32,address,address,uint8)"
                    ) && logs[1].topics[1] == bytes32(uint256(1)) && logs[1].topics[2] == PHASE
                && logs[1].topics[3] == id
                && keccak256(logs[1].data)
                    == keccak256(abi.encode(uint16(1), signer, GATE, uint8(0))),
            "manager event"
        );
        require(
            manager.isAuthorizationUsed(id) && !manager.isOperationRootUsed(root)
                && manager.nextOperationNonce() == 0 && core.minted() == 0,
            "void only"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        manager.executeSingleStepMint(b, "");
        require(
            !manager.isOperationRootUsed(root) && manager.nextOperationNonce() == 0
                && core.minted() == 0,
            "mint rollback"
        );
        t.nonce = bytes32(uint256(2));
        bytes32 fresh = manager.mintTicketAuthorizationId(t, GATE);
        manager.executeSingleStepMint(_batch(fresh), "");
        require(core.minted() == 1 && manager.isAuthorizationUsed(fresh), "same phase healthy");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, fresh)
        );
        vm.prank(signer);
        manager.voidMintTicket(t, GATE, "");
    }

    function testExpiredTicketCanBeRelayedWithoutGateOrCoreLiveness() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(3);
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        bytes memory sig = _signature(
            SIGNER_KEY, _revokeDigest(StreamMintTicketHash.domain(block.chainid, GATE), id)
        );
        vm.warp(5000);
        core.setUnavailable(true);
        manager.voidMintTicket(t, GATE, sig);
        require(
            manager.isAuthorizationUsed(id) && manager.nextOperationNonce() == 0, "historical void"
        );
    }

    function testOfferUsesSalesDomainAndRejectsOrdinaryOrCustodyRevocationProofs() public {
        StreamPrivateSaleTypes.SaleOffer memory o = _offer(4);
        bytes32 id = manager.mintOfferAuthorizationId(o);
        bytes32 domain = StreamPrivateSaleHash.domain(block.chainid, ADAPTER);
        bytes memory ordinary = _signature(
            SIGNER_KEY,
            StreamPrivateSaleHash.digest(block.chainid, ADAPTER, StreamPrivateSaleHash.offerBody(o))
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector, signer
            )
        );
        manager.voidMintOffer(o, 1, ordinary);
        bytes memory custody = _signature(
            SIGNER_KEY,
            keccak256(
                abi.encodePacked(
                    bytes2(0x1901),
                    domain,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "SaleOfferRevocation(uint256 chainId,address saleAdapter,bytes32 offerDigest)"
                            ),
                            block.chainid,
                            ADAPTER,
                            StreamPrivateSaleHash.digest(
                                block.chainid, ADAPTER, StreamPrivateSaleHash.offerBody(o)
                            )
                        )
                    )
                )
            )
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector, signer
            )
        );
        manager.voidMintOffer(o, 1, custody);
        bytes memory good = _signature(SIGNER_KEY, _revokeDigest(domain, id));
        vm.warp(5000);
        manager.voidMintOffer(o, 1, good);
        require(manager.isAuthorizationUsed(id), "new revocation tuple");
        IStreamMintManager.MintBatch memory batch = _batch(id);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        manager.executeSingleStepMint(batch, "");
    }

    function testBindingAndKindRejectionsDoNotConsumeCorrectedSamePayload() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(5);
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        t.manager = address(0xBAD);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidBinding.selector
            )
        );
        vm.prank(signer);
        manager.voidMintTicket(t, GATE, "");
        t.manager = address(manager);
        t.authorizerKind = 3;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationUnsupportedKind.selector, uint8(3)
            )
        );
        vm.prank(signer);
        manager.voidMintTicket(t, GATE, "");
        t.authorizerKind = 1;
        vm.prank(signer);
        manager.voidMintTicket(t, GATE, "");
        require(manager.isAuthorizationUsed(id), "healthy original");
    }

    function testLedgerWriterCannotVoidAnotherManagerScopeAndZeroOrRepeatedReject() public {
        ledger.setLedgerWriter(address(this), true);
        bytes32 id = keccak256("raw independently scoped key");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerRevocation.InvalidAuthorizationManager.selector,
                address(manager),
                address(this)
            )
        );
        ledger.voidAuthorization(address(manager), id);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintLedgerRevocation.InvalidAuthorizationId.selector, bytes32(0)
            )
        );
        ledger.voidAuthorization(address(this), 0);
        ledger.voidAuthorization(address(this), id);
        require(
            ledger.isManagerAuthorizationUsed(address(this), id)
                && !manager.isAuthorizationUsed(id),
            "own map"
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.AuthorizationAlreadyConsumed.selector, id)
        );
        ledger.voidAuthorization(address(this), id);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamMintLedger.UnauthorizedLedgerWriter.selector, signer)
        );
        vm.prank(signer);
        ledger.voidAuthorization(signer, id);
    }
}
