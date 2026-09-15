// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";
import "../../mocks/MockVRFCoordinatorV2Plus.sol";
import "../../../smart-contracts/domains/entropy/StreamEntropyProviderVRF.sol";

/// @notice The subscription-funded provider's optional quote is independent of request context.
contract StreamEntropyProviderFeeQuoteTest is CharacterizationTestBase, OfficialSafeFixture {
    StreamEntropyProviderVRF private provider;
    OfficialSafe private safe;
    uint256[] private keys;

    function setUp() public {
        keys.push(0x5AFE01);
        keys.push(0x5AFE02);
        safe = createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 172);
        provider = new StreamEntropyProviderVRF(
            StreamEntropyProviderVRF.Config(
                address(this),
                address(this),
                address(new MockVRFCoordinatorV2Plus()),
                1,
                keccak256("key"),
                3,
                500_000,
                2_500_000,
                true
            ),
            keccak256("manifest"),
            "urn:stream:fixture:fee-quote",
            keccak256("module")
        );
    }

    function testFuzzSubscriptionQuoteIsZeroForEveryContext(bytes calldata context) public view {
        require(
            provider.supportsInterface(type(IStreamEntropyProviderFeeQuote).interfaceId)
                && !provider.supportsInterface(0xffffffff)
                && provider.contextIndependentRequestFee() == 0
                && provider.quoteRequest(context) == 0
                && provider.quoteRequest(abi.encode(uint256(42), address(safe), bytes32(0))) == 0,
            "subscription funding has no caller-paid native request fee"
        );
    }

    function testSafeCanExecuteQuoteGetterWithoutChangingEntropyIdentity() public {
        bytes32 identity = provider.streamEntropyProviderConfigHash();
        require(
            executeSafe(
                safe,
                keys,
                address(provider),
                0,
                abi.encodeCall(provider.contextIndependentRequestFee, ()),
                0
            ),
            "Safe getter execution"
        );
        require(provider.streamEntropyProviderConfigHash() == identity, "quote preserves identity");
    }
}
