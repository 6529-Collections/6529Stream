// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentFinalityArtifacts,
    CurrentGraphArtifactVm
} from "../../script/current/StreamCurrentFinalityArtifacts.sol";

/// @dev Test-only linked copy of the complete current-script artifact verifier.
/// Script defaults remain unchanged. This library performs no CREATE or writes.
library StreamCurrentTestRuntime {
    CurrentGraphArtifactVm private constant graphVm =
        CurrentGraphArtifactVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function runtime(
        string memory artifactPath,
        string[] memory declarationArtifacts,
        bytes memory linkedCreation,
        StreamCurrentFinalityArtifacts.RuntimeValue[] memory values
    ) public view returns (bytes memory runtime) {
        string memory artifact = graphVm.readFile(artifactPath);
        bytes memory patched;
        (runtime, patched) = linkRuntime(artifact, linkedCreation);
        string[] memory ids =
            graphVm.parseJsonKeys(artifact, ".deployedBytecode.immutableReferences");
        string[] memory declarationContents = new string[](declarationArtifacts.length);
        if (ids.length != 0) {
            for (uint256 i; i < declarationArtifacts.length; ++i) {
                declarationContents[i] = _equal(declarationArtifacts[i], artifactPath)
                    ? artifact
                    : graphVm.readFile(declarationArtifacts[i]);
            }
        }
        for (uint256 i; i < values.length; ++i) {
            for (uint256 j; j < i; ++j) {
                require(
                    !_equal(values[i].source, values[j].source)
                        || !_equal(values[i].contractName, values[j].contractName)
                        || !_equal(values[i].variable, values[j].variable),
                    "unique constructor value declarations"
                );
            }
        }
        for (uint256 i; i < ids.length; ++i) {
            StreamCurrentFinalityArtifacts.RuntimeValue memory declaration =
                _declaration(declarationContents, _decimal(ids[i]));
            bool found;
            bytes32 value;
            for (uint256 j; j < values.length; ++j) {
                if (
                    _equal(values[j].source, declaration.source)
                        && _equal(values[j].contractName, declaration.contractName)
                        && _equal(values[j].variable, declaration.variable)
                ) {
                    require(!found, "duplicate immutable value");
                    found = true;
                    value = values[j].value;
                }
            }
            require(found, "missing constructor-derived immutable");
            StreamCurrentFinalityArtifacts.RuntimeRange[] memory sites = abi.decode(
                graphVm.parseJson(
                    artifact, string.concat('.deployedBytecode.immutableReferences["', ids[i], '"]')
                ),
                (StreamCurrentFinalityArtifacts.RuntimeRange[])
            );
            require(sites.length != 0, "empty immutable reference");
            for (uint256 j; j < sites.length; ++j) {
                StreamCurrentFinalityArtifacts.RuntimeRange memory site = sites[j];
                require(site.length == 32 && site.start + 32 <= runtime.length, "immutable range");
                for (uint256 k; k < 32; ++k) {
                    require(patched[site.start + k] == 0, "duplicate or overlapping runtime site");
                    patched[site.start + k] = 0x01;
                    require(runtime[site.start + k] == 0, "unpatched immutable template");
                    runtime[site.start + k] = value[k];
                }
            }
        }
    }

    function linkRuntime(string memory artifact, bytes memory linkedCreation)
        public
        view
        returns (bytes memory, bytes memory)
    {
        bytes memory creationHex = bytes(graphVm.parseJsonString(artifact, ".bytecode.object"));
        bytes memory runtimeHex =
            bytes(graphVm.parseJsonString(artifact, ".deployedBytecode.object"));
        bytes memory creationPatched = new bytes(linkedCreation.length);
        uint256 runtimePrefix =
            runtimeHex.length >= 2 && runtimeHex[0] == "0" && runtimeHex[1] == "x" ? 2 : 0;
        bytes memory runtimePatched = new bytes((runtimeHex.length - runtimePrefix) / 2);
        string[] memory sources = graphVm.parseJsonKeys(artifact, ".bytecode.linkReferences");
        for (uint256 i; i < sources.length; ++i) {
            string memory sourcePath = string.concat('.bytecode.linkReferences["', sources[i], '"]');
            string[] memory libraries = graphVm.parseJsonKeys(artifact, sourcePath);
            for (uint256 j; j < libraries.length; ++j) {
                StreamCurrentFinalityArtifacts.RuntimeRange[] memory sites = abi.decode(
                    graphVm.parseJson(
                        artifact, string.concat(sourcePath, '["', libraries[j], '"]')
                    ),
                    (StreamCurrentFinalityArtifacts.RuntimeRange[])
                );
                require(
                    sites.length != 0 && sites[0].length == 20
                        && sites[0].start + 20 <= linkedCreation.length,
                    "creation library reference"
                );
                bytes memory addressBytes = new bytes(20);
                for (uint256 k; k < 20; ++k) {
                    addressBytes[k] = linkedCreation[sites[0].start + k];
                }
                address libraryAddress;
                assembly ("memory-safe") { libraryAddress := shr(96, mload(add(addressBytes, 32))) }
                require(
                    libraryAddress.code.length != 0 && libraryAddress.code.length <= 24576,
                    "actual deployable linked library"
                );
                for (uint256 k; k < sites.length; ++k) {
                    require(
                        sites[k].length == 20 && sites[k].start + 20 <= linkedCreation.length,
                        "creation library range"
                    );
                    for (uint256 z; z < 20; ++z) {
                        require(
                            linkedCreation[sites[k].start + z] == addressBytes[z],
                            "consistent actual library links"
                        );
                    }
                    _patchHex(creationHex, sites[k].start, addressBytes, creationPatched);
                }
                string memory runtimePath = string.concat(
                    '.deployedBytecode.linkReferences["', sources[i], '"]["', libraries[j], '"]'
                );
                if (graphVm.keyExistsJson(artifact, runtimePath)) {
                    StreamCurrentFinalityArtifacts.RuntimeRange[] memory runtimeSites = abi.decode(
                        graphVm.parseJson(artifact, runtimePath),
                        (StreamCurrentFinalityArtifacts.RuntimeRange[])
                    );
                    for (uint256 k; k < runtimeSites.length; ++k) {
                        require(runtimeSites[k].length == 20, "runtime library width");
                        _patchHex(runtimeHex, runtimeSites[k].start, addressBytes, runtimePatched);
                    }
                }
            }
        }
        require(
            keccak256(_decodeHex(creationHex)) == keccak256(linkedCreation),
            "exact original linked creation template"
        );
        // Any unaccounted library placeholder fails hex decoding instead of receiving a default.
        return (_decodeHex(runtimeHex), runtimePatched);
    }

    function _declaration(string[] memory artifacts, uint256 id)
        private
        view
        returns (StreamCurrentFinalityArtifacts.RuntimeValue memory result)
    {
        bool found;
        string memory compilationHash = graphVm.parseJsonString(artifacts[0], ".compilationHash");
        for (uint256 i; i < artifacts.length; ++i) {
            string memory artifact = artifacts[i];
            require(
                _equal(compilationHash, graphVm.parseJsonString(artifact, ".compilationHash")),
                "same exact native compilation for immutable declarations"
            );
            string memory field = string.concat('.immutableDeclarations["', _uintString(id), '"]');
            if (!graphVm.keyExistsJson(artifact, field)) continue;
            require(
                !found && graphVm.parseJsonUint(artifact, string.concat(field, ".id")) == id
                    && _equal(
                        compilationHash,
                        graphVm.parseJsonString(artifact, string.concat(field, ".compilationHash"))
                    )
                    && _equal(
                        graphVm.parseJsonString(artifact, string.concat(field, ".nodeType")),
                        "VariableDeclaration"
                    )
                    && _equal(
                        graphVm.parseJsonString(artifact, string.concat(field, ".mutability")),
                        "immutable"
                    ),
                "exact immutable AST declaration"
            );
            found = true;
            result.source = graphVm.parseJsonString(artifact, string.concat(field, ".source"));
            result.contractName =
                graphVm.parseJsonString(artifact, string.concat(field, ".contractName"));
            result.variable = graphVm.parseJsonString(artifact, string.concat(field, ".variable"));
        }
        require(found, "unknown immutable AST id");
    }

    function _patchHex(bytes memory text, uint256 offset, bytes memory value, bytes memory patched)
        private
        pure
    {
        uint256 prefix = text.length >= 2 && text[0] == "0" && text[1] == "x" ? 2 : 0;
        require(prefix + 2 * (offset + value.length) <= text.length, "hex patch range");
        bytes16 digits = "0123456789abcdef";
        for (uint256 i; i < value.length; ++i) {
            require(patched[offset + i] == 0, "duplicate or overlapping library site");
            patched[offset + i] = 0x01;
            text[prefix + (offset + i) * 2] = digits[uint8(value[i]) >> 4];
            text[prefix + (offset + i) * 2 + 1] = digits[uint8(value[i]) & 15];
        }
    }

    function _decodeHex(bytes memory text) private pure returns (bytes memory result) {
        uint256 prefix = text.length >= 2 && text[0] == "0" && text[1] == "x" ? 2 : 0;
        require((text.length - prefix) % 2 == 0, "hex length");
        result = new bytes((text.length - prefix) / 2);
        for (uint256 i; i < result.length; ++i) {
            result[i] =
                bytes1(_nibble(text[prefix + i * 2]) * 16 + _nibble(text[prefix + i * 2 + 1]));
        }
    }

    function _nibble(bytes1 c) private pure returns (uint8) {
        uint8 n = uint8(c);
        if (n >= 48 && n <= 57) return n - 48;
        if (n >= 97 && n <= 102) return n - 87;
        if (n >= 65 && n <= 70) return n - 55;
        revert("unlinked or invalid hex");
    }

    function _decimal(string memory text) private pure returns (uint256 value) {
        bytes memory data = bytes(text);
        require(data.length != 0, "empty numeric AST id");
        for (uint256 i; i < data.length; ++i) {
            require(data[i] >= "0" && data[i] <= "9", "invalid numeric AST id");
            value = value * 10 + uint8(data[i]) - 48;
        }
    }

    function _uintString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 n = value;
        uint256 length;
        while (n != 0) {
            ++length;
            n /= 10;
        }
        bytes memory result = new bytes(length);
        while (value != 0) {
            result[--length] = bytes1(uint8(48 + value % 10));
            value /= 10;
        }
        return string(result);
    }

    function _equal(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
