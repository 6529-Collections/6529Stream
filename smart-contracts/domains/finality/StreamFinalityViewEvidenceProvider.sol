// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityPolicyMultiScopeEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import { StreamViewAdoptionReads as ViewRead } from "../metadata/StreamViewAdoptionReads.sol";

/// @notice Existing combined finality profiles plus immutable authentic VIEW declaration sources.
/// @dev This source capability alone does not admit VIEW finality; inherited VIEW refusal remains
/// until the separate adopted-view output/snapshot/reference/inventory profile is implemented.
contract StreamFinalityViewEvidenceProvider is
    StreamFinalityPolicyMultiScopeEvidenceProvider,
    IStreamViewSourceBinding
{
    V.Binding private _view;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        StreamFinalityNativeProviderReads.Config memory policy,
        address outputManifest,
        bytes32 outputManifestHash,
        V.Binding memory binding
    )
        StreamFinalityPolicyMultiScopeEvidenceProvider(
            original, scoped, policy, outputManifest, outputManifestHash
        )
    {
        if (
            binding.membership != original.targets[3]
                || binding.membershipCodeHash != original.codeHashes[3] || binding.readGas < 50000
                || binding.sourceGas < binding.readGas
        ) revert V.InvalidViewAdoption();
        ViewRead.pin(binding.views, binding.viewsCodeHash);
        ViewRead.pin(binding.membership, binding.membershipCodeHash);
        if (
            ViewRead.addr(
                        binding.views,
                        abi.encodeCall(IStreamCollectionViews.core, ()),
                        binding.readGas
                    ) != original.targets[0]
                || ViewRead.addr(
                        binding.views,
                        abi.encodeCall(IStreamCollectionViews.metadataHost, ()),
                        binding.readGas
                    ) != original.targets[1]
                || ViewRead.addr(
                        binding.views,
                        abi.encodeCall(IStreamCollectionViews.schemaRegistry, ()),
                        binding.readGas
                    ) != original.targets[4]
                || ViewRead.addr(
                        binding.views,
                        abi.encodeCall(IStreamCollectionViews.chunkStore, ()),
                        binding.readGas
                    ) != original.targets[5]
        ) revert V.InvalidViewAdoption();
        _view = binding;
    }

    function viewSourceBinding() external view override returns (V.Binding memory) {
        return _view;
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return id == type(IStreamViewSourceBinding).interfaceId || super.supportsInterface(id);
    }
}
