// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract StreamMintRevocationSafeTest is MintRevocationTestBase, OfficialSafeFixture {
    OfficialSafe private account;
    uint256[] private keys;

    function setUp() public override {
        super.setUp();
        keys = new uint256[](2);
        keys[0] = 0xAB01;
        keys[1] = 0xAB02;
        uint256[] memory allKeys = new uint256[](3);
        allKeys[0] = keys[0];
        allKeys[1] = keys[1];
        allKeys[2] = 0xAB03;
        account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(allKeys), 2, 1);
    }

    function _execute(address target, bytes memory data) private {
        require(executeSafe(account, keys, target, 0, data, 0), "Safe call");
    }

    function executeVoid(address target, bytes calldata data) external {
        require(msg.sender == address(this), "test only");
        _execute(target, data);
    }

    function testActualSafeDirectTicketAndOfferVoidPlusAllAdditiveReadSelectors() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(30);
        t.authorizer = address(account);
        t.authorizerKind = 2;
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        _execute(address(manager), abi.encodeCall(manager.mintTicketAuthorizationId, (t, GATE)));
        _execute(
            address(manager), abi.encodeCall(manager.GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT, ())
        );
        _execute(
            address(manager),
            abi.encodeCall(
                manager.supportsInterface, (type(IStreamMintAuthorizationRevocation).interfaceId)
            )
        );
        _execute(
            address(ledger),
            abi.encodeCall(
                ledger.supportsInterface, (type(IStreamMintLedgerRevocation).interfaceId)
            )
        );
        _execute(address(manager), abi.encodeCall(manager.voidMintTicket, (t, GATE, bytes(""))));
        require(manager.isAuthorizationUsed(id), "Safe ticket");
        StreamPrivateSaleTypes.SaleOffer memory o = _offer(31);
        o.buyer = address(account);
        bytes32 offerId = manager.mintOfferAuthorizationId(o);
        _execute(address(manager), abi.encodeCall(manager.mintOfferAuthorizationId, (o)));
        _execute(address(manager), abi.encodeCall(manager.voidMintOffer, (o, uint8(2), bytes(""))));
        require(manager.isAuthorizationUsed(offerId), "Safe offer");
        uint256 nonce = account.nonce();
        bytes memory directLedger =
            abi.encodeCall(ledger.voidAuthorization, (address(manager), bytes32(uint256(9))));
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.executeVoid(address(ledger), directLedger);
        require(account.nonce() == nonce, "direct ledger rejected");
    }

    function testActualSafeWrappedRevocationAcceptsLargeEnvelopeAfterRawDigestRejection() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(32);
        t.authorizer = address(account);
        t.authorizerKind = 2;
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        bytes32 digest = _revokeDigest(StreamMintTicketHash.domain(block.chainid, GATE), id);
        bytes memory raw = safeThresholdSignature(keys, digest);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                address(account)
            )
        );
        manager.voidMintTicket(t, GATE, raw);
        bytes memory proof = bytes.concat(
            safeThresholdSignature(keys, safeMessageDigest(account, abi.encode(digest))),
            new bytes(65536)
        );
        bytes memory data = abi.encodeCall(manager.voidMintTicket, (t, GATE, proof));
        (bool ok, bytes memory result) = address(manager).call{ gas: 450000 }(data);
        require(
            !ok
                && bytes4(result)
                    == IStreamMintAuthorizationRevocation.MintRevocationInsufficientGas.selector
                && !manager.isAuthorizationUsed(id),
            "large parent fails atomically"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                address(account)
            )
        );
        manager.voidMintTicket(t, GATE, proof);
        require(!manager.isAuthorizationUsed(id), "admitted Safe OOG also atomic");
        // Large trailing-envelope stress, not a declared maximum supported signature length.
        // Target-side governed context is a fixture; the separate suite executes real delayed raises.
        bytes32 parameter = manager.GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT();
        _raise(parameter, 800000);
        _raise(parameter, 1600000);
        manager.voidMintTicket(t, GATE, proof);
        require(manager.isAuthorizationUsed(id), "actual Safe same large proof");
    }

    function testActualSafeAndEOADirectMutableLibraryCallsReject() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(33);
        t.authorizer = address(account);
        t.authorizerKind = 2;
        StreamPrivateSaleTypes.SaleOffer memory o = _offer(33);
        o.buyer = address(account);
        StreamMintRevocation.Context memory c =
            StreamMintRevocation.Context(address(core), address(ledger), 400000);
        bytes[2] memory data = [
            abi.encodeWithSelector(StreamMintRevocation.voidTicket.selector, c, t, GATE, bytes("")),
            abi.encodeWithSelector(
                StreamMintRevocation.voidOffer.selector, c, o, uint8(2), bytes("")
            )
        ];
        for (uint256 i; i < 2; i++) {
            (bool ok, bytes memory result) = address(StreamMintRevocation).call(data[i]);
            require(!ok && result.length == 0, "direct library CALL");
            uint256 nonce = account.nonce();
            vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
            this.executeVoid(address(StreamMintRevocation), data[i]);
            require(account.nonce() == nonce, "Safe library CALL rollback");
        }
        _execute(
            address(StreamMintRevocation),
            abi.encodeWithSelector(StreamMintRevocation.ticketId.selector, t, GATE)
        );
        _execute(
            address(StreamMintRevocation),
            abi.encodeWithSelector(StreamMintRevocation.offerId.selector, o)
        );
        _execute(address(manager), abi.encodeCall(manager.voidMintTicket, (t, GATE, bytes(""))));
        require(
            manager.isAuthorizationUsed(manager.mintTicketAuthorizationId(t, GATE)),
            "consumer control"
        );
    }
}
