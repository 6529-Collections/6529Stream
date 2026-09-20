// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedRenderCriticalTokenFixture.sol";

contract StreamScopedRenderCriticalTokensTest is ScopedRenderCriticalTokenFixture {
    function testActualMembershipOrdinalKeepsOriginalSerialAndBurnedIdentity() public {
        _prepare();
        (uint256 actual, Tokens.Original memory original) = Tokens.sourceAt(deps, context, 0);
        (
            uint256 savedToken,
            uint256 cid,
            uint256 serial,
            bool burned,
            uint8 lifecycle,
            uint64 ordinal
        ) = abi.decode(original.identity, (uint256, uint256, uint256, bool, uint8, uint64));
        require(
            actual == token && savedToken == token && cid == 1 && serial == 2 && !burned
                && lifecycle == 2 && ordinal == 0,
            "permanent identity not ordinal"
        );
        Inventory.Item[] memory rows = Tokens.tokenItems(deps, context, 0, payload);
        require(
            rows.length == 10
                && keccak256(rows[1].digest) == keccak256(abi.encodePacked(keccak256(json))),
            "full JSON row"
        );
        core.setToken(token, 1, serial, 3);
        (, original) = Tokens.sourceAt(deps, context, 0);
        (,,, burned, lifecycle,) =
            abi.decode(original.identity, (uint256, uint256, uint256, bool, uint8, uint64));
        require(burned && lifecycle == 3, "retained burned identity");
    }

    function testFullOutputDriftCannotBorrowUnchangedCompactBytes() public {
        _prepare();
        Tokens.tokenItems(deps, context, 0, payload);
        route.set("tokenJSON(uint256)", abi.encode("changed full output"));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
        route.set("tokenJSON(uint256)", abi.encode(string(json)));
        Tokens.tokenItems(deps, context, 0, payload);
        payload.tokenId += 1;
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
    }

    function testExplicitProfileByteBoundsDoNotTrustMatchingOversizedLeaf() public {
        _prepare();
        _outputs(new bytes(65536), new bytes(40960));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(new bytes(65537), bytes("html"));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(route)));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(bytes("json"), new bytes(40961));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InventoryRead.selector, address(route)));
        Tokens.tokenItems(deps, context, 0, payload);
        _outputs(bytes("json"), bytes("html"));
        payload.image = new bytes(2049);
        output.leaf.imageHash = keccak256(payload.image);
        content.set("outputAt(bytes32,uint256)", abi.encode(output));
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Tokens.tokenItems(deps, context, 0, payload);
    }

    function testInlineScriptAndAbsentLibraryAreExactOriginalSourceRows() public {
        _prepare();
        Inventory.Item[] memory rows = Scripts.items(deps, context, 0, false);
        require(
            rows.length == 1 && rows[0].byteSize == bytes(rawSource.script).length
                && keccak256(rows[0].digest)
                    == keccak256(abi.encodePacked(keccak256(bytes(rawSource.script)))),
            "inline exact bytes"
        );
        rows = Scripts.items(deps, context, 0, true);
        require(rows.length == 1 && rows[0].kind == Inventory.Kind.ABSENT, "no invented library");
        rawSource.script = "substituted script";
        route.set(
            "staticRenderSourceForConfig(uint256,bytes32)", abi.encode(rawSource, config.config)
        );
        vm.expectRevert(abi.encodeWithSelector(Inventory.InvalidInventoryItem.selector));
        Scripts.items(deps, context, 0, false);
    }
}
