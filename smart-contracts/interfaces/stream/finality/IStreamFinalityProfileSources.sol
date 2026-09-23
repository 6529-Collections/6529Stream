// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamFinalityScope } from "./StreamArtworkFinalityTypes.sol";

/// @notice Immutable source catalogue and current canonical scope selection for one provider.
/// @dev This selects source identities, not accepted evidence. No statement, finality manifest,
/// inventory, reference currentness, or component-state callback participates in selection.
interface IStreamFinalityProfileSources {
    struct Profile {
        bytes32 profileHash;
        address referenceRender;
        bytes32 referenceRenderCodeHash;
        address snapshots;
        bytes32 snapshotsCodeHash;
        address entropyFactory;
        bytes32 entropyFactoryCodeHash;
        bytes32 configurationHash;
    }

    struct Sources {
        StreamFinalityScope scope;
        Profile profile;
    }
    // Fixed indexes: original COLLECTION V1, scoped STATIC V1, policy COLLECTION V2.
    function finalitySourceProfile(uint8 index) external view returns (Profile memory);
    function finalitySourceConfigurationHash() external view returns (bytes32);
    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        returns (Sources memory);
}
