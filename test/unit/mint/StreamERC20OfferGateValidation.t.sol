// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../../smart-contracts/domains/mint/StreamERC20OfferGateValidation.sol";

/// @dev Transport fixture: signature and content admission are covered by the actual gate suites.
contract ERC20OfferResultGate {
    bytes private response;
    bool private fail;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintGate).interfaceId
            || id == type(IStreamERC20OfferGate).interfaceId;
    }

    function set(bytes calldata raw, bool shouldFail) external {
        response = raw;
        fail = shouldFail;
    }

    fallback() external {
        require(!fail, "gate failed");
        bytes memory raw = response;
        assembly ("memory-safe") { return(add(raw, 32), mload(raw)) }
    }
}

contract ERC20OfferResultRegistry {
    bool public active = true;

    function setActive(bool value) external {
        active = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IERC165).interfaceId || id == type(IStreamMintModuleRegistry).interfaceId;
    }

    function moduleInfo(address gate)
        external
        view
        returns (IStreamMintModuleRegistry.MintModuleInfo memory)
    {
        return IStreamMintModuleRegistry.MintModuleInfo(
            active
                ? IStreamMintModuleRegistry.ModuleStatus.ACTIVE
                : IStreamMintModuleRegistry.ModuleStatus.BLOCKED,
            type(IStreamMintGate).interfaceId,
            1,
            gate.codehash,
            keccak256("metadata"),
            300_000
        );
    }
}

contract ERC20OfferGateValidationHarness {
    function gasParameter(bytes32) external pure returns (uint256) {
        return 300_000;
    }

    function validate(
        IStreamMintManager.MintBatch calldata batch,
        StreamERC20OfferMintTypes.GateData calldata data,
        IStreamMintManager.MintGateConfig calldata gate,
        address registry
    ) external view returns (StreamMintOperationIdentity.MintAuthorization memory) {
        return StreamERC20OfferGateValidation.validate(batch, data, gate, registry);
    }
}

contract StreamERC20OfferGateValidationTest is CharacterizationTestBase {
    ERC20OfferResultGate private gate;
    ERC20OfferResultRegistry private registry;
    ERC20OfferGateValidationHarness private host;
    IStreamMintManager.MintBatch private batch;
    StreamERC20OfferMintTypes.GateData private data;
    IStreamMintManager.MintGateConfig private config;

    function setUp() public {
        gate = new ERC20OfferResultGate();
        registry = new ERC20OfferResultRegistry();
        host = new ERC20OfferGateValidationHarness();
        batch.authorizationId = keccak256("ticket");
        batch.authorizer = address(0xB);
        data.buyerSignature.authorizer = batch.authorizer;
        data.buyerSignature.kind = 2;
        config = IStreamMintManager.MintGateConfig(
            address(gate),
            keccak256("config"),
            address(gate).codehash,
            keccak256("metadata"),
            1,
            300_000
        );
        gate.set(abi.encode(_result()), false);
    }

    function _result() private view returns (IStreamMintGate.GateResult memory r) {
        r.authorizationId = batch.authorizationId;
        r.authorizer = batch.authorizer;
        r.authorizerKind = 2;
        r.nullifiers = new bytes32[](0);
        r.maxQuantity = 1;
        r.gateHash = keccak256("selected evidence");
    }

    function testDedicatedCanonicalResultPreservesVerifiedBuyerAndTicket() public view {
        StreamMintOperationIdentity.MintAuthorization memory a =
            host.validate(batch, data, config, address(registry));
        require(
            a.authorizationId == batch.authorizationId && a.authorizer == batch.authorizer,
            "identities"
        );
        require(a.authorizerKind == IStreamMintManager.AuthorizerKind.ERC1271_712, "kind");
        require(
            a.maxQuantity == 1 && a.nullifiers.length == 0 && a.gateHash == _result().gateHash,
            "evidence"
        );
    }

    function testUnselectedProfileKeepsSignerWithExactlyZeroGate() public view {
        IStreamMintManager.MintGateConfig memory empty;
        StreamMintOperationIdentity.MintAuthorization memory a =
            host.validate(batch, data, empty, address(registry));
        require(
            a.authorizer == batch.authorizer && a.authorizationId == batch.authorizationId,
            "signer ticket"
        );
        require(a.gateHash == 0 && a.maxQuantity == 1, "unselected");
    }

    function testRejectsGateFailureAndShortOrOversizedResult() public {
        gate.set(abi.encode(_result()), true);
        _reject();
        gate.set(new bytes(255), false);
        _reject();
        gate.set(new bytes(257), false);
        _reject();
    }

    function testRejectsNoncanonicalDynamicOffsetsAndNullifiers() public {
        bytes memory raw = abi.encode(_result());
        assembly ("memory-safe") { mstore(add(raw, 32), 64) }
        gate.set(raw, false);
        _reject();
        raw = abi.encode(_result());
        assembly ("memory-safe") { mstore(add(raw, 96), 160) }
        gate.set(raw, false);
        _reject();
        raw = abi.encode(_result());
        assembly ("memory-safe") { mstore(add(raw, 256), 1) }
        gate.set(raw, false);
        _reject();
    }

    function testRejectsDifferentTicketSignerKindQuantityOrEvidence() public {
        IStreamMintGate.GateResult memory r = _result();
        r.authorizationId = keccak256("different");
        gate.set(abi.encode(r), false);
        _reject();
        r = _result();
        r.authorizer = address(0xC);
        gate.set(abi.encode(r), false);
        _reject();
        r = _result();
        r.authorizerKind = 1;
        gate.set(abi.encode(r), false);
        _reject();
        r = _result();
        r.maxQuantity = 0;
        gate.set(abi.encode(r), false);
        _reject();
        r = _result();
        r.gateHash = 0;
        gate.set(abi.encode(r), false);
        _reject();
    }

    function testBlockedRegistryAndChangedCodePinFailClosed() public {
        registry.setActive(false);
        vm.expectRevert();
        host.validate(batch, data, config, address(registry));
        registry.setActive(true);
        config.gateCodehash = keccak256("different");
        vm.expectRevert();
        host.validate(batch, data, config, address(registry));
    }

    function testUnselectedRejectsResidualGateConfiguration() public {
        IStreamMintManager.MintGateConfig memory empty;
        empty.gateConfigHash = keccak256("not zero");
        vm.expectRevert();
        host.validate(batch, data, empty, address(registry));
    }

    function _reject() private {
        vm.expectRevert(
            abi.encodeWithSelector(StreamERC20OfferGateValidation.InvalidERC20OfferGate.selector)
        );
        host.validate(batch, data, config, address(registry));
    }
}
