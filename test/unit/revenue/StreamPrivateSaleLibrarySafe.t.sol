// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

contract StreamPrivateSaleLibrarySafeTest is PrivateSaleTestBase, OfficialSafeFixture {
    OfficialSafe private safe;
    uint256[] private keys;

    function _safe() private {
        uint256[] memory owners = new uint256[](3);
        owners[0] = 0x551;
        owners[1] = 0x552;
        owners[2] = 0x553;
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(owners), 2, 910);
        keys = new uint256[](2);
        keys[0] = owners[0];
        keys[1] = owners[2];
    }

    function attempt(address target, bytes calldata data) external {
        require(msg.sender == address(this));
        require(executeSafe(safe, keys, target, 0, data, 0));
    }

    function _reject(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory result) = target.call(data);
        require(!ok && keccak256(result) == keccak256(expected), "exact direct CALL error");
        uint256 nonce = safe.nonce();
        (ok, result) = address(this).call(abi.encodeCall(this.attempt, (target, data)));
        require(
            !ok && keccak256(result) == keccak256(abi.encodeWithSignature("Error(string)", "GS013"))
        );
        require(safe.nonce() == nonce);
    }

    function _read(address target, bytes memory data, bytes memory expected) private {
        vm.prank(address(safe));
        (bool ok, bytes memory result) = target.staticcall(data);
        require(ok && keccak256(result) == keccak256(expected), "exact direct read result");
        uint256 nonce = safe.nonce();
        require(executeSafe(safe, keys, target, 0, data, 0));
        require(safe.nonce() == nonce + 1);
    }

    function _context() private view returns (StreamPrivateSaleSupport.Context memory) {
        return StreamPrivateSaleSupport.Context(
            address(core), address(registry), address(core).codehash, address(registry).codehash
        );
    }

    function testAllEightMutableLibrarySelectorsRejectActualSafeAndConsumerCustodyStillWorks()
        external
    {
        _safe();
        StreamPrivateSaleSupport.Context memory c = _context();
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        StreamPrivateSaleTypes.SaleCustodyGrant memory grant = _grant(1, id);
        _reject(
            address(StreamPrivateSaleCustody),
            abi.encodeWithSelector(
                StreamPrivateSaleCustody.enter.selector,
                c,
                uint256(0),
                uint256(0),
                uint256(0),
                id,
                grant,
                uint8(1),
                bytes(""),
                uint256(400000)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleCustody),
            abi.encodeWithSelector(
                StreamPrivateSaleCustody.deliverClaim.selector,
                c,
                uint256(0),
                uint256(0),
                id,
                buyer,
                uint256(300000)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleAccounting),
            abi.encodeWithSelector(
                StreamPrivateSaleAccounting.settleRoyalty.selector,
                uint256(0),
                c,
                uint256(0),
                id,
                uint256(100000)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleAccounting),
            abi.encodeWithSelector(
                StreamPrivateSaleAccounting.claim.selector, uint256(0), id, buyer
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleAccounting),
            abi.encodeWithSelector(
                StreamPrivateSaleAccounting.retryRoyalty.selector,
                uint256(0),
                uint256(0),
                id,
                uint256(100000)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleSupport),
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.takeCustody.selector, c, consignor, uint256(1)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleSupport),
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.deliverNft.selector, c, uint256(1), buyer, uint256(300000)
            ),
            ""
        );
        _reject(
            address(StreamPrivateSaleSupport),
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.deliverRoyalty.selector,
                buyer,
                uint256(100),
                uint256(100000)
            ),
            ""
        );
        require(core.ownerOf(1) == consignor && sale.totalLiabilities() == 0);
        _deposit(id);
        _purchase(id, 1000);
        require(core.ownerOf(1) == buyer && sale.refundableBalance(id, consignor) == 900);
    }

    function testAllElevenLinkedSupportReadSelectorsHaveExplicitSafeResultOrContextControls()
        external
    {
        _safe();
        address helper = address(StreamPrivateSaleSupport);
        StreamPrivateSaleSupport.Context memory c = _context();
        IStreamPrivateSaleAdapter.SaleConfig memory config = _config(5, 1, buyer, 0);
        bytes32 id = sale.registerSale(config);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        // Direct library reads have their own address context, never consumer authorization authority.
        _reject(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.requireAdmission.selector, c, uint64(0), uint64(0)
            ),
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.PrivateSaleModuleNotAdmitted.selector)
        );
        _read(
            helper,
            abi.encodeWithSelector(StreamPrivateSaleSupport.ownerOf.selector, c, uint256(1)),
            abi.encode(consignor)
        );
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.requireToken.selector, c, uint256(1), uint256(1)
            ),
            ""
        );
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.royalty.selector, c, uint256(1), uint256(1000)
            ),
            abi.encode(address(royalty), uint256(100))
        );
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.validSignature.selector,
                consignor,
                uint8(1),
                bytes32(uint256(7)),
                _signature(OWNER_KEY, bytes32(uint256(7))),
                uint256(400000)
            ),
            abi.encode(true)
        );
        IStreamPrivateSaleAdapter.CollectionSigner memory signer =
            IStreamPrivateSaleAdapter.CollectionSigner(
                config.signerEvidenceHash, config.signerRevision, true, config.signerAuthority
            );
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.validateConfig.selector, config, signer
            ),
            ""
        );
        _reject(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.authorizationFields.selector, config, a
            ),
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.InvalidPrivateSale.selector)
        );
        IStreamPrivateSaleAdapter.Signature memory proof = _platformProof(a);
        _reject(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.authorizationProof.selector,
                config,
                a,
                proof,
                platform,
                uint256(400000)
            ),
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.InvalidPrivateSale.selector)
        );
        StreamPrivateSaleTypes.SaleOffer memory offer = _offer(1, buyer, 1000);
        config.saleKind = 6;
        config.offerDigest = sale.offerDigest(offer);
        proof = IStreamPrivateSaleAdapter.Signature(
            buyer, 1, _signature(BUYER_KEY, config.offerDigest)
        );
        _reject(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.offerProof.selector,
                config,
                address(core),
                offer,
                proof,
                uint256(400000)
            ),
            abi.encodeWithSelector(IStreamPrivateSaleAdapter.InvalidPrivateSale.selector)
        );
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.directOrSignature.selector,
                address(safe),
                uint8(2),
                bytes32(uint256(8)),
                bytes(""),
                uint256(400000)
            ),
            ""
        );
        bytes32 role = keccak256("ROLE_PAUSE_GUARDIAN");
        roles.grant(role, address(safe));
        _read(
            helper,
            abi.encodeWithSelector(
                StreamPrivateSaleSupport.requireRole.selector,
                address(roles),
                address(roles).codehash,
                address(authority),
                role
            ),
            ""
        );
    }
}
