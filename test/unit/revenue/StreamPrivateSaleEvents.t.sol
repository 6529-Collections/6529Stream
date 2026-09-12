// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/PrivateSaleTestBase.sol";

contract StreamPrivateSaleEventsTest is PrivateSaleTestBase {
    function testCanonicalSaleIdentityNamedConfigurationAndIndexedConfiguredEvent() external {
        IStreamPrivateSaleAdapter.SaleConfig memory c = _config(5, 1, buyer, 0);
        bytes32 expectedId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_V1"),
                block.chainid,
                address(sale),
                uint8(5),
                uint256(1),
                bytes32(0),
                uint256(1)
            )
        );
        bytes memory prefix = abi.encode(
            keccak256("6529STREAM_NATIVE_CONSIGNMENT_CONFIG_V1"),
            block.chainid,
            address(sale),
            uint256(1),
            platform
        );
        bytes memory first = abi.encode(
            c.saleKind,
            c.collectionId,
            c.tokenId,
            c.consignor,
            c.buyer,
            c.price,
            c.startTime,
            c.deadline
        );
        bytes memory last = abi.encode(
            c.offerDigest,
            c.signerEvidenceHash,
            c.signerRevision,
            c.signerAuthority,
            c.secondaryConsignment,
            c.expectedPrimaryPolicyHash
        );
        bytes32 expectedConfig = keccak256(bytes.concat(prefix, first, last));
        vm.recordLogs();
        bytes32 id = sale.registerSale(c);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            id == expectedId && sale.saleDetails(id).configHash == expectedConfig
                && logs.length == 1
        );
        require(logs[0].emitter == address(sale) && logs[0].topics.length == 4);
        require(
            logs[0].topics[0]
                == keccak256(
                    "SaleConfigured(uint16,bytes32,uint256,bytes32,uint8,address,bytes32,bytes32,uint8)"
                )
        );
        require(
            logs[0].topics[1] == id && logs[0].topics[2] == bytes32(uint256(1))
                && logs[0].topics[3] == 0
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(
                        uint16(1), uint8(5), address(0), expectedConfig, bytes32(0), uint8(0)
                    )
                )
        );
    }

    function testExactConsignmentAuthorizationRoyaltyAndPrivateExecutionEvents() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        StreamPrivateSaleTypes.SaleAuthorization memory a = _authorization(id, buyer, 1000);
        bytes32 digest = sale.authorizationDigest(a);
        vm.recordLogs();
        _purchase(id, 1007);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 auth;
        uint256 settled;
        uint256 executed;
        uint256 royaltyPaid;
        uint256 nft;
        for (uint256 i; i < logs.length; ++i) {
            Vm.Log memory l = logs[i];
            if (l.emitter != address(sale)) continue;
            if (
                l.topics[0]
                    == keccak256("SaleAuthorizationConsumed(uint16,bytes32,bytes32,address)")
            ) {
                ++auth;
                require(l.topics.length == 3 && l.topics[1] == id && l.topics[2] == digest);
                require(keccak256(l.data) == keccak256(abi.encode(uint16(1), platform)));
            } else if (
                l.topics[0]
                    == keccak256(
                        "ConsignmentSettled(uint16,bytes32,uint256,address,uint256,uint256,address,address)"
                    )
            ) {
                ++settled;
                require(
                    l.topics.length == 4 && l.topics[1] == id && l.topics[2] == bytes32(uint256(1))
                        && l.topics[3] == bytes32(uint256(uint160(buyer)))
                );
                require(
                    keccak256(l.data)
                        == keccak256(
                            abi.encode(
                                uint16(1), uint256(1000), uint256(100), address(royalty), consignor
                            )
                        )
                );
            } else if (
                l.topics[0]
                    == keccak256(
                        "PrivateSaleExecuted(uint16,bytes32,address,uint256,uint256,address)"
                    )
            ) {
                ++executed;
                require(
                    l.topics.length == 3 && l.topics[1] == id
                        && l.topics[2] == bytes32(uint256(uint160(buyer)))
                );
                require(
                    keccak256(l.data)
                        == keccak256(abi.encode(uint16(1), uint256(1), uint256(1000), address(0)))
                );
            } else if (
                l.topics[0]
                    == keccak256("ConsignmentRoyaltyDelivery(uint16,bytes32,address,uint256,bool)")
            ) {
                ++royaltyPaid;
                require(
                    l.topics.length == 3 && l.topics[1] == id
                        && l.topics[2] == bytes32(uint256(uint160(address(royalty))))
                );
                require(keccak256(l.data) == keccak256(abi.encode(uint16(1), uint256(100), true)));
            } else if (
                l.topics[0]
                    == keccak256("PrivateSaleNftDelivery(uint16,bytes32,uint256,address,bool)")
            ) {
                ++nft;
                require(
                    l.topics.length == 4 && l.topics[1] == id && l.topics[2] == bytes32(uint256(1))
                        && l.topics[3] == bytes32(uint256(uint160(buyer)))
                );
                require(keccak256(l.data) == keccak256(abi.encode(uint16(1), true)));
            } else {
                revert("unexpected adapter event");
            }
        }
        require(auth == 1 && settled == 1 && executed == 1 && royaltyPaid == 1 && nft == 1);
    }

    function testExactFullCreditClaimAndExpiryStatusEventsRemainSaleBound() external {
        bytes32 id = sale.registerSale(_config(5, 1, buyer, 0));
        _deposit(id);
        _purchase(id, 1017);
        address recipient = address(0x771);
        vm.recordLogs();
        vm.prank(buyer);
        sale.claimRefund(id, recipient);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1);
        require(
            logs[0].topics.length == 4 && logs[0].topics[1] == id
                && logs[0].topics[2] == bytes32(uint256(uint160(buyer)))
                && logs[0].topics[3] == bytes32(uint256(uint160(recipient)))
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "PrivateSaleCreditClaimed(uint16,bytes32,address,address,address,uint256)"
                )
        );
        require(
            keccak256(logs[0].data) == keccak256(abi.encode(uint16(1), address(0), uint256(17)))
        );
        core.mint(consignor, 2);
        bytes32 second = sale.registerSale(_config(5, 2, buyer, 0));
        _deposit(second);
        vm.warp(2001);
        vm.recordLogs();
        sale.expireSale(second);
        logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].topics.length == 2 && logs[0].topics[1] == second);
        require(
            logs[0].topics[0] == keccak256("SaleStatusChanged(uint16,bytes32,uint8,uint8,bytes32)")
        );
        require(
            keccak256(logs[0].data)
                == keccak256(
                    abi.encode(uint16(1), uint8(2), uint8(5), keccak256("PRIVATE_SALE_EXPIRED"))
                )
        );
        require(
            sale.refundableBalance(id, consignor) == 900 && sale.saleDetails(second).nftClaim == 2
        );
    }
}
