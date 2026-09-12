// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistSanctionReads.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegation.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";

import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboarding.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Fixed facade-only sanction and finality composition.
contract StreamArtistRegistryFinalityReadExtension {
    error ExtensionWrongHost(address actual);
    address private immutable _host;
    address private immutable operationCoordinator;

    constructor(address host_, address coordinator_) {
        if (
            host_ == address(0) || coordinator_ == address(0) || host_ == coordinator_
                || host_ == address(this)
        ) revert T.InvalidBinding();
        _host = host_;
        operationCoordinator = coordinator_;
    }

    modifier onlyHost() {
        if (msg.sender != _host) revert ExtensionWrongHost(msg.sender);
        _;
    }

    function prepareArtistSanction(Q.Request calldata p)
        external
        view
        onlyHost
        returns (Q.Prepared memory)
    {
        return IStreamArtistSanctionCoordinator(operationCoordinator).prepareArtistSanction(p);
    }

    function sanctionRecord(bytes32 hash) external view onlyHost returns (S.Record memory) {
        return IStreamArtistSanctionOwner(_contentSuite().owners[6]).sanctionRecord(hash);
    }

    function sanctionArchiveBytes(bytes32 hash) external view onlyHost returns (bytes memory) {
        return IStreamArtistSanctionOwner(_contentSuite().owners[6]).sanctionArchiveBytes(hash);
    }

    function sanctionArchiveFacts(bytes32 hash)
        external
        view
        onlyHost
        returns (IStreamArtistSanctionArchiveFacts.Facts memory)
    {
        return IStreamArtistSanctionOwner(_contentSuite().owners[6]).sanctionArchiveFacts(hash);
    }

    function collectionSanctionComponentType(uint256 collectionId)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistSanctionReads.componentType(_contentSuite(), collectionId);
    }

    function verifySanctionForSubject(
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 subject
    ) external view onlyHost returns (bool, bytes32, address, uint8) {
        return StreamArtistSanctionReads.verify(
            _contentSuite(), scopeType, collectionId, tokenId, scopeId, subject
        );
    }

    function finalityState(uint256 collectionId)
        external
        view
        onlyHost
        returns (StreamFinalityComponentState memory)
    {
        return StreamArtistSanctionReads.component(
            _contentSuite(),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        onlyHost
        returns (StreamFinalityComponentState memory)
    {
        return StreamArtistSanctionReads.component(_contentSuite(), scope);
    }

    function sanctionDigest(S.Terms calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistSanctionHashes.digest(_environment(), p, a);
    }

    function finalityRegistry() external view onlyHost returns (address) {
        return address(
            uint160(uint256(_finalityPin(IStreamArtistFinalityBinding.finalityRegistry.selector)))
        );
    }

    function finalityRegistryCodeHash() external view onlyHost returns (bytes32) {
        return _finalityPin(IStreamArtistFinalityBinding.finalityRegistryCodeHash.selector);
    }

    function _finalityPin(bytes4 selector) private view returns (bytes32 value) {
        address target = operationCoordinator;
        if (target.code.length == 0) revert T.InvalidBinding();
        bytes memory input = abi.encodeWithSelector(selector);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            let out := mload(0x40)
            ok := staticcall(gas(), target, add(input, 32), mload(input), out, 32)
            size := returndatasize()
            value := mload(out)
        }
        if (
            !ok || size != 32 || value == 0
                || (selector == IStreamArtistFinalityBinding.finalityRegistry.selector
                    && uint256(value) >> 160 != 0)
        ) revert T.InvalidBinding();
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        T.SuiteConfiguration memory s = _contentSuite();
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(operationCoordinator).deploymentChainId(),
            _host,
            s.core,
            s.mintManager
        );
    }

    function _contentSuite() private view returns (T.SuiteConfiguration memory) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
    }

    function saleConsentDigest(Sale.Consent calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistSaleHashes.digest(_environment(), p, a);
    }

    function contentConsentDigest(Content.Consent calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistContentHashes.consentDigest(_environment(), p, a);
    }

    function contentFreezeDigest(Content.Freeze calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistContentHashes.freezeDigest(_environment(), p, a);
    }
}
