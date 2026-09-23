// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityViewEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    IStreamFinalityScopedEntropyPolicySourceFactoryV2 as Factory
} from "../../interfaces/stream/finality/IStreamFinalityScopedEntropyPolicySourceFactoryV2.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicyReads
} from "./StreamFinalityCoordinatorPolicyReadsV2.sol";

/// @notice Existing combined provider plus constructor-owned adopted VIEW V2 policy source.
/// @dev Declaration/adoption/serving capability only; VIEW finality remains refused until the
/// distinct full output/snapshot/reference/inventory profile is implemented and admitted.
contract StreamFinalityPolicyViewEvidenceProvider is
    StreamFinalityViewEvidenceProvider,
    IStreamViewPolicySourceBindingV2
{
    address public immutable override viewPolicySourceFactoryV2;
    bytes32 public immutable override viewPolicySourceFactoryV2CodeHash;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        StreamFinalityNativeProviderReads.Config memory policy,
        address outputManifest,
        bytes32 outputManifestHash,
        V.Binding memory binding,
        address factory,
        bytes32 factoryHash
    )
        StreamFinalityViewEvidenceProvider(
            original, scoped, policy, outputManifest, outputManifestHash, binding
        )
    {
        ViewRead.pin(factory, factoryHash);
        if (
            ViewRead.word(
                        factory,
                        abi.encodeCall(IERC165.supportsInterface, (type(Factory).interfaceId)),
                        binding.readGas
                    ) != 1
                || bytes32(
                        ViewRead.word(
                            factory,
                            abi.encodeCall(Factory.scopedPolicyFactoryProfile, ()),
                            binding.readGas
                        )
                    ) != keccak256("6529STREAM_SCOPED_ENTROPY_POLICY_SOURCE_FACTORY_V2")
        ) revert V.InvalidViewAdoption();
        bytes memory raw =
            ViewRead.read(factory, abi.encodeCall(Factory.dependencies, ()), 352, binding.readGas);
        PolicyReads.Dependencies memory d = abi.decode(raw, (PolicyReads.Dependencies));
        if (
            keccak256(raw) != keccak256(abi.encode(d)) || d.chainId != original.chainId
                || d.targets[0] != original.targets[0] || d.codeHashes[0] != original.codeHashes[0]
                || d.targets[1] != original.targets[1] || d.codeHashes[1] != original.codeHashes[1]
                || d.targets[2] != original.targets[3] || d.codeHashes[2] != original.codeHashes[3]
        ) revert V.InvalidViewAdoption();
        viewPolicySourceFactoryV2 = factory;
        viewPolicySourceFactoryV2CodeHash = factoryHash;
    }

    function supportsInterface(bytes4 id) public pure override returns (bool) {
        return
            id == type(IStreamViewPolicySourceBindingV2).interfaceId || super.supportsInterface(id);
    }
}
