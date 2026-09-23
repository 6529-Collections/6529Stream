// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StreamFinalityDiscoveryTypes {
    struct Configuration {
        address core;
        address metadata;
        address router;
        address provider;
        address membership;
        address entropyFactory;
        address metadataAdapter;
        address referenceRender;
        address artist;
        address finalityRegistry;
        // Constructor-only storage, not a runtime immutable: the later Registry may itself
        // pin this discovery's runtime without creating a reciprocal runtime-hash equation.
        bytes32 finalityRegistryCodeHash;
        // Metadata Router, renderer, context, media, script, dependencies, in this fixed order.
        address[6] routerAdapters;
        uint32 readGas;
        uint32 componentGas;
        uint32 entropyGas;
    }
}
