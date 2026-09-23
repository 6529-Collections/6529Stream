// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/RefundWindowTestBase.sol";

/// @dev Gas witness around domain artist facts, constructed before immutable consumer pins.
///      This tests consumer cap propagation, not actual artist op16 execution cost.
contract RefundConsentGasFacade {
    RefundRuntimeArtist public immutable facts;
    uint256 public capabilityMinimum;
    uint256 public consentMinimum;
    address public expectedConsumer;

    constructor(RefundRuntimeArtist target) {
        facts = target;
    }

    function configure(uint256 capabilityGas, uint256 consentGas, address consumer) external {
        capabilityMinimum = capabilityGas;
        consentMinimum = consentGas;
        expectedConsumer = consumer;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        if (id == 0x606af4b9) require(gasleft() >= capabilityMinimum, "capability gas witness");
        return facts.supportsInterface(id);
    }

    function requireSaleConsent(uint256 collectionId, bytes32 saleId, bytes32 configHash)
        external
        view
    {
        require(
            msg.sender == expectedConsumer && gasleft() >= consentMinimum,
            "consumer and consent gas witness"
        );
        facts.requireSaleConsent(collectionId, saleId, configHash);
    }

    fallback(bytes calldata input) external returns (bytes memory output) {
        bool ok;
        (ok, output) = address(facts).call(input);
        if (!ok) assembly ("memory-safe") { revert(add(output, 32), mload(output)) }
    }
}

contract StreamRefundWindowConsentGasTest is RefundWindowTestBase {
    RefundConsentGasFacade private gasFacade;

    function _refundArtistFacade(RefundRuntimeArtist target) internal override returns (address) {
        gasFacade = new RefundConsentGasFacade(target);
        return address(gasFacade);
    }

    function testDeclaredArtistCapLimitsBothCapabilityAndConsentWithGovernedRaise() public {
        IStreamNativeRefundWindowSale.RefundPurchaseData memory d = _purchaseData(1, payer, payer);
        gasFacade.configure(300_000, 0, address(refundSale));
        _reject(d);
        gasFacade.configure(0, 300_000, address(refundSale));
        _reject(d);
        bytes32 parameter = keccak256("6529STREAM_GGP_SALE_ARTIST_AUTHORITY_GAS_LIMIT");
        _raise(parameter, 400_000);
        gasFacade.configure(300_000, 300_000, address(refundSale));
        vm.prank(payer);
        bytes32 id = refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.refundPurchaseRecord(id).status == 1
                && refundSale.nextPurchaseNonce(refundId, payer) == 2,
            "same proof under actual raised cap"
        );
        _atRefundEnd(id);
        refundSale.finalizeRefundWindow(id);
        require(
            refundManager.nonce() == 1 && wallet.balance == 1000,
            "cap applies through finalization before and after effects"
        );
        bytes32[3] memory ids = [
            keccak256("6529STREAM_GGP_SALE_ERC1271_GAS_LIMIT"),
            parameter,
            keccak256("6529STREAM_GGP_REVEAL_ATTEMPT_GAS_LIMIT")
        ];
        for (uint256 i; i < ids.length; ++i) {
            (,, uint8 classification,) = refundSale.gasParameterInfo(ids[i]);
            require(
                classification == 2, "SSA GAS7 fail-closed class including caught reveal attempt"
            );
        }
    }

    function testEveryNewSaleGasRowRejectsForwardingClassInsteadOfFailClosedClass() public {
        for (uint256 i; i < 3; ++i) {
            StreamNativeRefundWindowSale.DeploymentConfig memory d = _deployment();
            d.parameters[i].failureClass = 1;
            vm.expectRevert(
                abi.encodeWithSelector(IStreamNativeRefundWindowSale.InvalidRefundSale.selector)
            );
            new StreamNativeRefundWindowSale(d);
        }
    }

    function _reject(IStreamNativeRefundWindowSale.RefundPurchaseData memory d) private {
        vm.prank(payer);
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamSaleConsent.SaleConsentNotSatisfied.selector,
                address(gasFacade),
                uint256(1),
                refundId
            )
        );
        refundSale.purchaseRefundWindow{ value: 1100 }(d);
        require(
            refundSale.nextPurchaseNonce(refundId, payer) == 1
                && refundSale.totalBuyerLiabilities() == 0
                && !refundSale.purchaseAuthorizationUsed(artist, d.authorization.nonce),
            "cap failure preserves numeric commercial and custody lanes"
        );
    }

    function _raise(bytes32 parameter, uint256 next) private {
        (uint256 value, uint256 floor, uint8 failureClass, uint64 revision) =
            refundSale.gasParameterInfo(parameter);
        bytes32 scope = keccak256(
            abi.encode(
                bytes32(0x9533611d402c2b44cf950a4a8900d25f6829bfac541dc4d5353094f966bb1a71),
                block.chainid,
                address(refundSale),
                parameter
            )
        );
        bytes32 domain = 0x5059a253d3f7dd63b5d9fd1f0568caf72967f501a3db678b31cefe911334159c;
        _context(
            scope,
            keccak256(abi.encode(domain, scope, value, floor, failureClass, revision)),
            keccak256(abi.encode(domain, scope, next, floor, failureClass, revision + 1)),
            1
        );
        vm.prank(address(revenueAuthority));
        refundSale.raiseGasParameter(parameter, next);
        _clearContext();
        require(refundSale.gasParameter(parameter) == next, "actual target-side governed cap raise");
    }
}
