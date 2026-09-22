// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../smart-contracts/domains/metadata/StreamMetadataRenderer.sol";

/// @notice Native URI regression for future local owner captures; no hosted fixture claim.
contract StreamOwnerFixtureUriRegressionTest {
    function testEmbeddedFixtureAllowsEmptyOptionalUri() public pure {
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", "", 2048, true);
        require(StreamMetadataRenderer.isSafeContentUri("", true), "empty optional URI");
    }

    function testFormerFixtureUrnIsNotAnAllowedContentUri() public pure {
        require(
            !StreamMetadataRenderer.isSafeContentUri("urn:stream:public-local-owner-fixture", true),
            "fixture URN must not be published"
        );
    }
}
