// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/MintRevocationTestBase.sol";

contract MintRevocationSignerMock {
    uint256 public mode;
    uint256 public minimumGas;

    function configure(uint256 m, uint256 g) external {
        mode = m;
        minimumGas = g;
    }

    function isValidSignature(bytes32, bytes calldata) external view returns (bytes4) {
        require(gasleft() > minimumGas, "signature gas");
        uint256 m = mode;
        if (m == 1) revert("signature revert");
        if (m == 2) assembly ("memory-safe") { return(0, 0) }
        if (m == 3) {
            assembly ("memory-safe") {
                mstore(0, 0x1626ba7e)
                return(0, 32)
            }
        }
        if (m == 4) {
            assembly ("memory-safe") {
                mstore(0, shl(224, 0x1626ba7e))
                return(0, 4)
            }
        }
        if (m == 5) {
            assembly ("memory-safe") {
                let p := mload(0x40)
                mstore(p, shl(224, 0x1626ba7e))
                return(p, 65536)
            }
        }
        return 0x1626ba7e;
    }
}

contract MintRevocationLedgerMock {
    uint256 public mode;
    mapping(address => mapping(bytes32 => bool)) public stored;
    address public callback;
    bytes public callbackData;
    bytes public callbackResult;

    function configure(uint256 m, address target, bytes calldata data) external {
        mode = m;
        callback = target;
        callbackData = data;
    }

    function isStreamMintLedger() external pure returns (bool) {
        return true;
    }

    function supportsInterface(bytes4) external view returns (bool) {
        if (mode == 1) return false;
        if (mode == 2) {
            assembly ("memory-safe") {
                mstore(0, 1)
                return(0, 64)
            }
        }
        return true;
    }

    function isManagerAuthorizationUsed(address who, bytes32 id) external view returns (bool) {
        if (mode == 3) {
            assembly ("memory-safe") {
                mstore(0, 2)
                return(0, 32)
            }
        }
        if (mode == 6) return false;
        return stored[who][id];
    }

    function voidAuthorization(address who, bytes32 id) external {
        if (mode == 4) revert("ledger unavailable");
        stored[who][id] = true;
        if (callback != address(0)) {
            (bool ok, bytes memory data) = callback.call(callbackData);
            require(!ok, "nested success");
            callbackResult = data;
        }
        if (mode == 5) {
            assembly ("memory-safe") {
                mstore(0, 0)
                return(0, 32)
            }
        }
        if (mode == 7) {
            assembly ("memory-safe") {
                let p := mload(0x40)
                return(p, 65536)
            }
        }
    }
}

contract StreamMintRevocationAdversarialTest is MintRevocationTestBase {
    function testEveryMalformedSignatureRejectsThenIdenticalProofSucceeds() public {
        MintRevocationSignerMock witness = new MintRevocationSignerMock();
        StreamMintTicketTypes.MintTicket memory t = _ticket(20);
        t.authorizer = address(witness);
        t.authorizerKind = 2;
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        for (uint256 mode = 1; mode <= 5; mode++) {
            witness.configure(mode, 0);
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                    address(witness)
                )
            );
            manager.voidMintTicket(t, GATE, hex"0123");
            require(!manager.isAuthorizationUsed(id), "malformed rollback");
        }
        witness.configure(0, 0);
        manager.voidMintTicket(t, GATE, hex"0123");
        require(manager.isAuthorizationUsed(id), "identical healthy proof");
    }

    function testParentAdmissionAfterLargeSignatureCopyRollsBackAndGovernedCapIsObserved() public {
        MintRevocationSignerMock witness = new MintRevocationSignerMock();
        StreamMintTicketTypes.MintTicket memory t = _ticket(21);
        t.authorizer = address(witness);
        t.authorizerKind = 2;
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        bytes memory proof = new bytes(65536);
        bytes memory callData = abi.encodeCall(manager.voidMintTicket, (t, GATE, proof));
        (bool ok, bytes memory reason) = address(manager).call{ gas: 450000 }(callData);
        require(
            !ok
                && bytes4(reason)
                    == IStreamMintAuthorizationRevocation.MintRevocationInsufficientGas.selector
                && !manager.isAuthorizationUsed(id),
            "exact parent admission"
        );
        witness.configure(0, 600000);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamMintAuthorizationRevocation.MintRevocationInvalidSignature.selector,
                address(witness)
            )
        );
        manager.voidMintTicket(t, GATE, proof);
        bytes32 parameter = manager.GGP_MINT_REVOCATION_ERC1271_GAS_LIMIT();
        _raise(parameter, 800000);
        manager.voidMintTicket(t, GATE, proof);
        require(manager.isAuthorizationUsed(id), "raised live cap same proof");
    }

    function testHostileLedgerCapabilityWriteAndReadbackRollbackWithSamePayloadControl() public {
        MintRevocationLedgerMock hostile = new MintRevocationLedgerMock();
        StreamMintManager other = _manager(address(hostile));
        StreamMintTicketTypes.MintTicket memory t = _ticket(22);
        t.manager = address(other);
        t.ledger = address(hostile);
        bytes32 id = other.mintTicketAuthorizationId(t, GATE);
        for (uint256 mode = 1; mode <= 7; mode++) {
            hostile.configure(mode, address(0), "");
            vm.expectRevert(
                abi.encodeWithSelector(
                    IStreamMintAuthorizationRevocation.MintLedgerRevocationUnavailable.selector,
                    address(hostile)
                )
            );
            vm.prank(signer);
            other.voidMintTicket(t, GATE, "");
            require(
                !hostile.stored(address(other), id) && other.nextOperationNonce() == 0,
                "full rollback"
            );
        }
        hostile.configure(
            0, address(other), abi.encodeCall(other.voidMintTicket, (t, GATE, bytes("")))
        );
        vm.prank(signer);
        other.voidMintTicket(t, GATE, "");
        require(
            hostile.stored(address(other), id)
                && keccak256(hostile.callbackResult())
                    == keccak256(abi.encodeWithSelector(bytes4(0x3ee5aeb5))),
            "guard spans write and readback"
        );
    }

    function testExplicitEOAKindAcceptsCompactProofEvenWhenSignerHas7702Marker() public {
        StreamMintTicketTypes.MintTicket memory t = _ticket(23);
        bytes32 id = manager.mintTicketAuthorizationId(t, GATE);
        bytes32 digest = _revokeDigest(StreamMintTicketHash.domain(block.chainid, GATE), id);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, digest);
        bytes memory compact = abi.encodePacked(r, bytes32(uint256(s) | (uint256(v - 27) << 255)));
        vm.etch(signer, abi.encodePacked(bytes3(0xef0100), bytes20(address(0x123))));
        manager.voidMintTicket(t, GATE, compact);
        require(manager.isAuthorizationUsed(id), "explicit kind preserved");
    }
}
