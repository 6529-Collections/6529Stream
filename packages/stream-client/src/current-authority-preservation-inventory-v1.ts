import { AbiCoder, Interface, ParamType, ZeroAddress, ZeroHash, getAddress, id, isHexString, keccak256, toUtf8Bytes } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type { UnsignedCall } from "./binding.js";
import * as old from "./current-scoped-policy-inventory-v2.js";
import * as output from "./current-token-preservation-output-v2.js";
import * as snapshot from "./current-token-preservation-snapshot-v2.js";
import * as reference from "./current-token-preservation-reference-v2.js";

/** ABI146 supplied-fact helpers. Codecs and locators confer no source or signing authority. */
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SOURCE = "9381dd999075693a4f63092d9924856a0dd72834";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PROFILE = id("6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_RENDER_CRITICAL_INVENTORY_V1") as Hex;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PROFILE = id("6529STREAM_CURRENT_AUTHORITY_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_INVENTORY_V1") as Hex;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_PROFILE = id("6529STREAM_ARTIST_CURRENT_AUTHORITY_V1") as Hex;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE = id("6529STREAM_ARTIST_ARCHIVE_ORIGIN_V1") as Hex;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_FAMILY = id("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2") as Hex;
/** Client allocation limits, not protocol-wide token/catalog limits. */
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_BYTES = 2097152;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_ROWS = 8192;
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_ORIGINS = 17;
export type CurrentAuthorityPreservationInventoryV1Kind = "collection" | "scoped";
export interface CurrentAuthorityPreservationInventoryV1Coordinates {
  readonly chainId: bigint;
  readonly core: Address;
  readonly inventory: Address;
  readonly scopeKind: CurrentAuthorityPreservationInventoryV1Kind;
}

export type CurrentAuthorityPreservationInventoryV1Dependencies = old.ScopedPolicyInventoryV2Dependencies;

export type CurrentAuthorityPreservationInventoryV1OriginDependencies = {
  readonly worker: Address;
  readonly workerCodeHash: Hex;
  readonly originGas: bigint;
  readonly profile: Hex;
};

export type CurrentAuthorityPreservationInventoryV1AuthorityDependencies = {
  readonly resolver: Address;
  readonly resolverCodeHash: Hex;
  readonly resolverGas: bigint;
};

export type CurrentAuthorityPreservationInventoryV1AuthorityAnchors = {
  readonly targets: readonly [Address, Address, Address, Address, Address];
  readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex];
  readonly finalityRegistry: Address;
  readonly chainId: bigint;
  readonly readGas: bigint;
};

export type CurrentAuthorityPreservationInventoryV1OriginEnvironment = {
  readonly chainId: bigint;
  readonly registry: Address;
  readonly coordinator: Address;
  readonly archive: Address;
  readonly owners: readonly [Address, Address, Address, Address, Address, Address, Address];
  readonly ownerCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
  readonly core: Address;
  readonly manager: Address;
  readonly suiteConfigurationHash: Hex;
};

export type CurrentAuthorityPreservationInventoryV1Origin = {
  readonly environment: {
    readonly chainId: bigint;
    readonly registry: Address;
    readonly coordinator: Address;
    readonly archive: Address;
    readonly owners: readonly [Address, Address, Address, Address, Address, Address, Address];
    readonly ownerCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
    readonly core: Address;
    readonly manager: Address;
    readonly suiteConfigurationHash: Hex;
  };
  readonly registryCodeHash: Hex;
  readonly coordinatorCodeHash: Hex;
  readonly archiveCodeHash: Hex;
};

export type CurrentAuthorityPreservationInventoryV1Selection = {
  readonly origin: {
    readonly environment: {
      readonly chainId: bigint;
      readonly registry: Address;
      readonly coordinator: Address;
      readonly archive: Address;
      readonly owners: readonly [Address, Address, Address, Address, Address, Address, Address];
      readonly ownerCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
      readonly core: Address;
      readonly manager: Address;
      readonly suiteConfigurationHash: Hex;
    };
    readonly registryCodeHash: Hex;
    readonly coordinatorCodeHash: Hex;
    readonly archiveCodeHash: Hex;
  };
  readonly completion: Hex;
  readonly selectionHash: Hex;
};

export type CurrentAuthorityPreservationInventoryV1Capture = {
  readonly dependencies: {
    readonly targets: readonly [Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address, Address];
    readonly codeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex, Hex];
    readonly artistTargets: readonly [Address, Address, Address, Address, Address];
    readonly artistCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex];
    readonly artistContentOwner: Address;
    readonly artistContentOwnerCodeHash: Hex;
    readonly chainId: bigint;
    readonly readGas: bigint;
    readonly sourceGas: bigint;
    readonly selectionGas: bigint;
    readonly snapshotGas: bigint;
    readonly referenceGas: bigint;
  };
  readonly selection: {
    readonly origin: {
      readonly environment: {
        readonly chainId: bigint;
        readonly registry: Address;
        readonly coordinator: Address;
        readonly archive: Address;
        readonly owners: readonly [Address, Address, Address, Address, Address, Address, Address];
        readonly ownerCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
        readonly core: Address;
        readonly manager: Address;
        readonly suiteConfigurationHash: Hex;
      };
      readonly registryCodeHash: Hex;
      readonly coordinatorCodeHash: Hex;
      readonly archiveCodeHash: Hex;
    };
    readonly completion: Hex;
    readonly selectionHash: Hex;
  };
};

export type CurrentAuthorityPreservationInventoryV1RecordOrigin = {
  readonly producer: {
    readonly environment: {
      readonly chainId: bigint;
      readonly registry: Address;
      readonly coordinator: Address;
      readonly archive: Address;
      readonly owners: readonly [Address, Address, Address, Address, Address, Address, Address];
      readonly ownerCodeHashes: readonly [Hex, Hex, Hex, Hex, Hex, Hex, Hex];
      readonly core: Address;
      readonly manager: Address;
      readonly suiteConfigurationHash: Hex;
    };
    readonly registryCodeHash: Hex;
    readonly coordinatorCodeHash: Hex;
    readonly archiveCodeHash: Hex;
  };
  readonly occurrence: {
    readonly position: {
      readonly point: {
        readonly environmentHash: Hex;
        readonly ownerIndex: bigint;
        readonly ownerRevision: bigint;
      };
      readonly nativeIndex: bigint;
    };
    readonly receipt: {
      readonly operation: bigint;
      readonly artistId: Hex;
      readonly collectionId: bigint;
      readonly recordHash: Hex;
    };
  };
  readonly importCommitment: Hex;
  readonly importedAtRevision: bigint;
  readonly actor: Address;
  readonly semanticRecordHash: Hex;
  readonly role: Hex;
  readonly sourceContextHash: Hex;
};

export type CurrentAuthorityPreservationInventoryV1ReceiptWitness = {
  readonly lane: bigint;
  readonly index: bigint;
};

export type CurrentAuthorityPreservationInventoryV1Item = old.ScopedPolicyInventoryV2Item;

export type CurrentAuthorityPreservationInventoryV1Segment = old.ScopedPolicyInventoryV2Segment;

export type CurrentAuthorityPreservationInventoryV1CollectionPlan = old.ScopedPolicyInventoryV2Progress;

export type CurrentAuthorityPreservationInventoryV1ScopedPlan = old.ScopedPolicyInventoryV2Plan;

export type CurrentAuthorityPreservationInventoryV1TokenProgress = old.ScopedPolicyInventoryV2TokenProgress;

export type CurrentAuthorityPreservationInventoryV1CollectionEvidence = old.ScopedPolicyInventoryV2OriginalEvidence;

export type CurrentAuthorityPreservationInventoryV1ScopedEvidence = old.ScopedPolicyInventoryV2Evidence;

export type CurrentAuthorityPreservationInventoryV1CollectionContext = {
  readonly records: {
    readonly collectionId: bigint;
    readonly subject: Hex;
    readonly artistId: Hex;
    readonly snapshot: {
      readonly recordHash: Hex;
      readonly collectionId: bigint;
      readonly snapshotId: Hex;
      readonly predecessor: Hex;
      readonly revision: bigint;
      readonly recordChainHash: Hex;
      readonly manifestHash: Hex;
      readonly manifestBytes: bigint;
      readonly sourceHash: Hex;
      readonly inventoryPlan: Hex;
      readonly publisher: Address;
      readonly authorizationClass: bigint;
      readonly grantRevision: bigint;
      readonly displayAuthorizationClass: bigint;
      readonly displayGrantRevision: bigint;
      readonly effectiveAt: bigint;
      readonly recordedAt: bigint;
      readonly reasonHash: Hex;
      readonly schemaDefinitionHash: Hex;
      readonly profileDefinitionHash: Hex;
      readonly canonicalizationDefinitionHash: Hex;
    };
    readonly referenceRender: {
      readonly recordHash: Hex;
      readonly recordChainHash: Hex;
      readonly collectionId: bigint;
      readonly referenceId: Hex;
      readonly predecessor: Hex;
      readonly revision: bigint;
      readonly payloadHash: Hex;
      readonly payloadBytes: bigint;
      readonly sourcesHash: Hex;
      readonly snapshotRecordHash: Hex;
      readonly snapshotRevision: bigint;
      readonly recorder: Address;
      readonly authorizationClass: bigint;
      readonly grantRevision: bigint;
      readonly effectiveAt: bigint;
      readonly recordedAt: bigint;
      readonly reasonHash: Hex;
      readonly schemaHash: Hex;
      readonly profileHash: Hex;
      readonly canonicalizationHash: Hex;
    };
    readonly descriptions: {
      readonly scopeSubject: Hex;
      readonly workDescriptionRecordHash: Hex;
      readonly rightsStatementRecordHash: Hex;
      readonly workPayloadHash: Hex;
      readonly rightsPayloadHash: Hex;
      readonly workSelectionHash: Hex;
      readonly rightsSelectionHash: Hex;
      readonly workRevision: bigint;
      readonly rightsRevision: bigint;
    };
    readonly conservation: {
      readonly record: {
        readonly recordHash: Hex;
        readonly kind: bigint;
        readonly payloadHash: Hex;
        readonly recorder: Address;
        readonly recordedAt: bigint;
        readonly recordIndex: bigint;
        readonly recordChainHash: Hex;
        readonly receiptHash: Hex;
        readonly publication: {
          readonly attestationRecordHash: Hex;
          readonly artistId: Hex;
          readonly bindingHash: Hex;
          readonly bindingGeneration: bigint;
          readonly signer: Address;
          readonly authorityClass: bigint;
          readonly requiredCapability: bigint;
          readonly signedAt: bigint;
          readonly publicationHash: Hex;
        };
        readonly publicationEvidenceHash: Hex;
      };
      readonly association: {
        readonly artistId: Hex;
        readonly bindingHash: Hex;
        readonly generation: bigint;
        readonly identityRecordHash: Hex;
      };
      readonly origin: bigint;
      readonly interviewStatus: bigint;
      readonly interview: {
        readonly recordHash: Hex;
        readonly kind: bigint;
        readonly payloadHash: Hex;
        readonly recorder: Address;
        readonly recordedAt: bigint;
        readonly recordIndex: bigint;
        readonly recordChainHash: Hex;
        readonly receiptHash: Hex;
        readonly publication: {
          readonly attestationRecordHash: Hex;
          readonly artistId: Hex;
          readonly bindingHash: Hex;
          readonly bindingGeneration: bigint;
          readonly signer: Address;
          readonly authorityClass: bigint;
          readonly requiredCapability: bigint;
          readonly signedAt: bigint;
          readonly publicationHash: Hex;
        };
        readonly publicationEvidenceHash: Hex;
      };
      readonly interviewArchiveReferenceHash: Hex;
      readonly interviewPayloadCorrespondence: bigint;
      readonly predecessor: Hex;
      readonly submitter: Address;
      readonly revision: bigint;
      readonly selectedAt: bigint;
      readonly catalogsHash: Hex;
      readonly selectionHash: Hex;
    };
    readonly interviewEvidenceHash: Hex;
    readonly nativeHash: Hex;
    readonly rootRecordHash: Hex;
    readonly tokenInventoryHash: Hex;
    readonly checkpointHash: Hex;
    readonly tokenCount: bigint;
  };
  readonly snapshot: {
    readonly recordHash: Hex;
    readonly scopeSubject: Hex;
    readonly predecessor: Hex;
    readonly revision: bigint;
    readonly chainHash: Hex;
    readonly manifestHash: Hex;
    readonly manifestBytes: bigint;
    readonly sourceHash: Hex;
    readonly publisher: Address;
    readonly authorizationClass: bigint;
    readonly grantRevision: bigint;
    readonly displayAuthorizationClass: bigint;
    readonly displayGrantRevision: bigint;
    readonly recordedAt: bigint;
    readonly schemaHash: Hex;
    readonly profileHash: Hex;
    readonly canonicalizationHash: Hex;
  };
  readonly referenceRender: {
    readonly scopeSubject: Hex;
    readonly observation: {
      readonly recordHash: Hex;
      readonly recordChainHash: Hex;
      readonly collectionId: bigint;
      readonly referenceId: Hex;
      readonly predecessor: Hex;
      readonly revision: bigint;
      readonly payloadHash: Hex;
      readonly payloadBytes: bigint;
      readonly sourcesHash: Hex;
      readonly snapshotRecordHash: Hex;
      readonly snapshotRevision: bigint;
      readonly recorder: Address;
      readonly authorizationClass: bigint;
      readonly grantRevision: bigint;
      readonly effectiveAt: bigint;
      readonly recordedAt: bigint;
      readonly reasonHash: Hex;
      readonly schemaHash: Hex;
      readonly profileHash: Hex;
      readonly canonicalizationHash: Hex;
    };
  };
  readonly source: {
    readonly scope: {
      readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
      readonly collectionId: bigint;
      readonly tokenId: bigint;
      readonly scopeId: Hex;
    };
    readonly membership: {
      readonly scopeSubject: Hex;
      readonly scopeManifestHash: Hex;
      readonly sourceRecordHash: Hex;
      readonly tokenCount: bigint;
      readonly tokenListHash: Hex;
      readonly membershipHash: Hex;
      readonly inventoryCount: bigint;
      readonly inventoryPrefixHash: Hex;
    };
    readonly artist: {
      readonly locked: boolean;
      readonly registry: Address;
      readonly registryCodeHash: Hex;
      readonly artistId: Hex;
      readonly bindingGeneration: bigint;
      readonly bindingHash: Hex;
      readonly nominatedArtist: Address;
      readonly identityRecordHash: Hex;
      readonly acceptanceRecordHash: Hex;
      readonly acceptedAt: bigint;
      readonly lockedAt: bigint;
      readonly snapshotHash: Hex;
    };
    readonly selection: {
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly membershipHash: Hex;
      readonly collectionStateHash: Hex;
      readonly tokenCount: bigint;
      readonly nextIndex: bigint;
      readonly selectionRoot: Hex;
    };
    readonly content: {
      readonly selectionId: Hex;
      readonly selectionHash: Hex;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly tokenCount: bigint;
      readonly nextIndex: bigint;
      readonly leafChainHash: Hex;
      readonly contentRoot: Hex;
      readonly outputRoot: Hex;
      readonly preservationProfile: Hex;
    };
    readonly outputs: {
      readonly checkpointHash: Hex;
      readonly checkpointStateHash: Hex;
      readonly entropySourceSet: Address;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly metadataRouter: Address;
      readonly preservationProfile: Hex;
      readonly artifactHash: Hex;
      readonly coverageHash: Hex;
      readonly artistId: Hex;
      readonly contentRoot: Hex;
      readonly outputRoot: Hex;
      readonly manifestHash: Hex;
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly tokenCount: bigint;
      readonly byteLength: bigint;
    };
    readonly root: {
      readonly publication: {
        readonly collectionId: bigint;
        readonly expectedPredecessor: Hex;
        readonly verifiedManifestRecordHash: Hex;
        readonly manifestURI: string;
      };
      readonly contentRoot: Hex;
      readonly leafCount: bigint;
      readonly manifestHash: Hex;
      readonly artistId: Hex;
      readonly bindingGeneration: bigint;
      readonly bindingHash: Hex;
      readonly publisher: Address;
      readonly authorizationClass: bigint;
      readonly grantRevision: bigint;
      readonly routeHash: Hex;
      readonly stateHash: Hex;
      readonly artistConsent: Hex;
      readonly publishedAt: bigint;
    };
    readonly rootBinding: {
      readonly profileId: Hex;
      readonly outputManifest: Address;
      readonly outputManifestCodeHash: Hex;
      readonly checkpoint: Address;
      readonly checkpointCodeHash: Hex;
      readonly checkpointHash: Hex;
      readonly checkpointStateHash: Hex;
      readonly entropySourceSet: Address;
      readonly entropySourceSetCodeHash: Hex;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly outputRoot: Hex;
      readonly outputSchemaHash: Hex;
      readonly outputCanonicalizationHash: Hex;
      readonly leafSchemaHash: Hex;
      readonly rootSchemaHash: Hex;
      readonly rootCanonicalizationHash: Hex;
      readonly metadataRouter: Address;
      readonly preservationOutputProfile: Hex;
    };
    readonly entropy: {
      readonly planId: Hex;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly policyCount: bigint;
      readonly allFrozen: boolean;
      readonly policies: readonly ({
        readonly coordinator: Address;
        readonly indexedCodeHash: Hex;
        readonly firstTokenIndex: bigint;
        readonly frozen: boolean;
        readonly moduleVersion: Hex;
        readonly moduleManifestHash: Hex;
        readonly moduleSchemaHash: Hex;
        readonly deploymentManifestHash: Hex;
        readonly policyHash: Hex;
        readonly provider: Address;
        readonly epoch: bigint;
        readonly salt: Hex;
        readonly componentDataHash: Hex;
        readonly explicitPolicy: boolean;
        readonly collectionPolicy: {
          readonly configured: boolean;
          readonly explicitPolicy: boolean;
          readonly frozen: boolean;
          readonly mode: bigint;
          readonly securityClass: bigint;
          readonly renderRequirement: bigint;
          readonly revision: bigint;
          readonly providerEpoch: bigint;
          readonly policyHash: Hex;
          readonly contentStateHash: Hex;
          readonly lastActionId: Hex;
          readonly artistConsentRecord: Hex;
        };
      })[];
    };
  };
  readonly referenceSourceHash: Hex;
};

export type CurrentAuthorityPreservationInventoryV1ScopedContext = {
  readonly scope: {
    readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
    readonly collectionId: bigint;
    readonly tokenId: bigint;
    readonly scopeId: Hex;
  };
  readonly subject: Hex;
  readonly artistId: Hex;
  readonly snapshot: {
    readonly recordHash: Hex;
    readonly scopeSubject: Hex;
    readonly predecessor: Hex;
    readonly revision: bigint;
    readonly chainHash: Hex;
    readonly manifestHash: Hex;
    readonly manifestBytes: bigint;
    readonly sourceHash: Hex;
    readonly publisher: Address;
    readonly authorizationClass: bigint;
    readonly grantRevision: bigint;
    readonly displayAuthorizationClass: bigint;
    readonly displayGrantRevision: bigint;
    readonly recordedAt: bigint;
    readonly schemaHash: Hex;
    readonly profileHash: Hex;
    readonly canonicalizationHash: Hex;
  };
  readonly snapshotSource: {
    readonly scope: {
      readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
      readonly collectionId: bigint;
      readonly tokenId: bigint;
      readonly scopeId: Hex;
    };
    readonly membership: {
      readonly scopeSubject: Hex;
      readonly scopeManifestHash: Hex;
      readonly sourceRecordHash: Hex;
      readonly tokenCount: bigint;
      readonly tokenListHash: Hex;
      readonly membershipHash: Hex;
      readonly inventoryCount: bigint;
      readonly inventoryPrefixHash: Hex;
    };
    readonly artist: {
      readonly locked: boolean;
      readonly registry: Address;
      readonly registryCodeHash: Hex;
      readonly artistId: Hex;
      readonly bindingGeneration: bigint;
      readonly bindingHash: Hex;
      readonly nominatedArtist: Address;
      readonly identityRecordHash: Hex;
      readonly acceptanceRecordHash: Hex;
      readonly acceptedAt: bigint;
      readonly lockedAt: bigint;
      readonly snapshotHash: Hex;
    };
    readonly selection: {
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly membershipHash: Hex;
      readonly collectionStateHash: Hex;
      readonly tokenCount: bigint;
      readonly nextIndex: bigint;
      readonly selectionRoot: Hex;
    };
    readonly content: {
      readonly selectionId: Hex;
      readonly selectionHash: Hex;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly tokenCount: bigint;
      readonly nextIndex: bigint;
      readonly leafChainHash: Hex;
      readonly contentRoot: Hex;
      readonly outputRoot: Hex;
      readonly preservationProfile: Hex;
    };
    readonly outputs: {
      readonly checkpointHash: Hex;
      readonly checkpointStateHash: Hex;
      readonly entropySourceSet: Address;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly metadataRouter: Address;
      readonly preservationProfile: Hex;
      readonly artifactHash: Hex;
      readonly coverageHash: Hex;
      readonly artistId: Hex;
      readonly contentRoot: Hex;
      readonly outputRoot: Hex;
      readonly manifestHash: Hex;
      readonly scope: {
        readonly scopeType: CurrentAuthorityPreservationInventoryV1Scope["scopeType"];
        readonly collectionId: bigint;
        readonly tokenId: bigint;
        readonly scopeId: Hex;
      };
      readonly tokenCount: bigint;
      readonly byteLength: bigint;
    };
    readonly sourceFactory: Address;
    readonly sourceFactoryCodeHash: Hex;
    readonly factoryDependenciesHash: Hex;
    readonly entropy: {
      readonly planId: Hex;
      readonly inventoryHash: Hex;
      readonly policyChainHash: Hex;
      readonly policyCount: bigint;
      readonly allFrozen: boolean;
      readonly policies: readonly ({
        readonly coordinator: Address;
        readonly indexedCodeHash: Hex;
        readonly firstTokenIndex: bigint;
        readonly frozen: boolean;
        readonly moduleVersion: Hex;
        readonly moduleManifestHash: Hex;
        readonly moduleSchemaHash: Hex;
        readonly deploymentManifestHash: Hex;
        readonly policyHash: Hex;
        readonly provider: Address;
        readonly epoch: bigint;
        readonly salt: Hex;
        readonly componentDataHash: Hex;
        readonly explicitPolicy: boolean;
        readonly collectionPolicy: {
          readonly configured: boolean;
          readonly explicitPolicy: boolean;
          readonly frozen: boolean;
          readonly mode: bigint;
          readonly securityClass: bigint;
          readonly renderRequirement: bigint;
          readonly revision: bigint;
          readonly providerEpoch: bigint;
          readonly policyHash: Hex;
          readonly contentStateHash: Hex;
          readonly lastActionId: Hex;
          readonly artistConsentRecord: Hex;
        };
      })[];
    };
  };
  readonly referenceRender: {
    readonly scopeSubject: Hex;
    readonly observation: {
      readonly recordHash: Hex;
      readonly recordChainHash: Hex;
      readonly collectionId: bigint;
      readonly referenceId: Hex;
      readonly predecessor: Hex;
      readonly revision: bigint;
      readonly payloadHash: Hex;
      readonly payloadBytes: bigint;
      readonly sourcesHash: Hex;
      readonly snapshotRecordHash: Hex;
      readonly snapshotRevision: bigint;
      readonly recorder: Address;
      readonly authorizationClass: bigint;
      readonly grantRevision: bigint;
      readonly effectiveAt: bigint;
      readonly recordedAt: bigint;
      readonly reasonHash: Hex;
      readonly schemaHash: Hex;
      readonly profileHash: Hex;
      readonly canonicalizationHash: Hex;
    };
  };
  readonly descriptions: {
    readonly scopeSubject: Hex;
    readonly workDescriptionRecordHash: Hex;
    readonly rightsStatementRecordHash: Hex;
    readonly workPayloadHash: Hex;
    readonly rightsPayloadHash: Hex;
    readonly workSelectionHash: Hex;
    readonly rightsSelectionHash: Hex;
    readonly workRevision: bigint;
    readonly rightsRevision: bigint;
  };
  readonly conservation: {
    readonly record: {
      readonly recordHash: Hex;
      readonly kind: bigint;
      readonly payloadHash: Hex;
      readonly recorder: Address;
      readonly recordedAt: bigint;
      readonly recordIndex: bigint;
      readonly recordChainHash: Hex;
      readonly receiptHash: Hex;
      readonly publication: {
        readonly attestationRecordHash: Hex;
        readonly artistId: Hex;
        readonly bindingHash: Hex;
        readonly bindingGeneration: bigint;
        readonly signer: Address;
        readonly authorityClass: bigint;
        readonly requiredCapability: bigint;
        readonly signedAt: bigint;
        readonly publicationHash: Hex;
      };
      readonly publicationEvidenceHash: Hex;
    };
    readonly association: {
      readonly artistId: Hex;
      readonly bindingHash: Hex;
      readonly generation: bigint;
      readonly identityRecordHash: Hex;
    };
    readonly origin: bigint;
    readonly interviewStatus: bigint;
    readonly interview: {
      readonly recordHash: Hex;
      readonly kind: bigint;
      readonly payloadHash: Hex;
      readonly recorder: Address;
      readonly recordedAt: bigint;
      readonly recordIndex: bigint;
      readonly recordChainHash: Hex;
      readonly receiptHash: Hex;
      readonly publication: {
        readonly attestationRecordHash: Hex;
        readonly artistId: Hex;
        readonly bindingHash: Hex;
        readonly bindingGeneration: bigint;
        readonly signer: Address;
        readonly authorityClass: bigint;
        readonly requiredCapability: bigint;
        readonly signedAt: bigint;
        readonly publicationHash: Hex;
      };
      readonly publicationEvidenceHash: Hex;
    };
    readonly interviewArchiveReferenceHash: Hex;
    readonly interviewPayloadCorrespondence: bigint;
    readonly predecessor: Hex;
    readonly submitter: Address;
    readonly revision: bigint;
    readonly selectedAt: bigint;
    readonly catalogsHash: Hex;
    readonly selectionHash: Hex;
  };
  readonly interviewEvidenceHash: Hex;
  readonly nativeHash: Hex;
  readonly rootRecordHash: Hex;
  readonly tokenInventoryHash: Hex;
  readonly checkpointHash: Hex;
  readonly outputManifestRecord: Hex;
  readonly selectionId: Hex;
  readonly selectionHash: Hex;
  readonly tokenCount: bigint;
};

export type CurrentAuthorityPreservationInventoryV1Scope = output.TokenPreservationOutputV2Scope;

export type CurrentAuthorityPreservationInventoryV1Work = old.ScopedPolicyInventoryV2Work;

export type CurrentAuthorityPreservationInventoryV1Rights = old.ScopedPolicyInventoryV2Rights;

export type CurrentAuthorityPreservationInventoryV1Intent = old.ScopedPolicyInventoryV2Intent;

export type CurrentAuthorityPreservationInventoryV1IntentWaiver = old.ScopedPolicyInventoryV2IntentWaiver;

export type CurrentAuthorityPreservationInventoryV1Interview = old.ScopedPolicyInventoryV2Interview;

export type CurrentAuthorityPreservationInventoryV1Payload = output.TokenPreservationOutputV2Payload;

export type CurrentAuthorityPreservationInventoryV1Aggregate = old.ScopedPolicyInventoryV2Aggregate;

export type CurrentAuthorityPreservationInventoryV1Context = CurrentAuthorityPreservationInventoryV1CollectionContext | CurrentAuthorityPreservationInventoryV1ScopedContext;
export type CurrentAuthorityPreservationInventoryV1Plan = CurrentAuthorityPreservationInventoryV1CollectionPlan | CurrentAuthorityPreservationInventoryV1ScopedPlan;
export type CurrentAuthorityPreservationInventoryV1Evidence = CurrentAuthorityPreservationInventoryV1CollectionEvidence | CurrentAuthorityPreservationInventoryV1ScopedEvidence;
export type CurrentAuthorityPreservationInventoryV1Progress = CurrentAuthorityPreservationInventoryV1CollectionPlan;

export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE = "(address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE = "(address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE = "(address resolver, bytes32 resolverCodeHash, uint256 resolverGas)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_ANCHORS_TUPLE = "(address[5] targets, bytes32[5] codeHashes, address finalityRegistry, uint256 chainId, uint256 readGas)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_ENVIRONMENT_TUPLE = "(uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE = "((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SELECTION_TUPLE = "(((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_CAPTURE_TUPLE = "((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) dependencies, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash) selection)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE = "(((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) producer, (((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, uint256 nativeIndex) position, (uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash) receipt) occurrence, bytes32 importCommitment, uint64 importedAtRevision, address actor, bytes32 semanticRecordHash, bytes32 role, bytes32 sourceContextHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECEIPT_WITNESS_TUPLE = "(uint8 lane, uint256 index)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE = "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE = "(bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PLAN_TUPLE = "(uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PLAN_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE = "(uint8 phase, uint64 row, uint64 count)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE = "(bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_CONTEXT_TUPLE = "((uint256 collectionId, bytes32 subject, bytes32 artistId, (bytes32 recordHash, uint256 collectionId, bytes32 snapshotId, bytes32 predecessor, uint64 revision, bytes32 recordChainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, bytes32 inventoryPlan, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaDefinitionHash, bytes32 profileDefinitionHash, bytes32 canonicalizationDefinitionHash) snapshot, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, uint64 tokenCount) records, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, ((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) root, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) rootBinding, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) source, bytes32 referenceSourceHash)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_CONTEXT_TUPLE = "((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE = "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_WORK_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RIGHTS_TUPLE = "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE = "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_PAYLOAD_TUPLE = "(uint256 tokenId, address producer, bytes image, bytes animation)";
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AGGREGATE_TUPLE = "(uint64 revision, bytes32 transitionChain)";

export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_ABI = Object.freeze([
  "error InvalidArchiveOrigin()",
  "error InvalidInventorySegment()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event InventoryCompleted(bytes32 indexed planId, bytes32 indexed renderCriticalEvidenceHash, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) evidence)",
  "event InventorySegmentRecorded(bytes32 indexed planId, uint64 indexed index, (bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash) segment, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[] items)",
  "event InventoryStarted(bytes32 indexed planId, uint256 indexed collectionId, bytes32 sourceContextHash)",
  "function appendCurrentProfile(bytes32 id)",
  "function appendDefinition(bytes32 id)",
  "function appendIntent(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address, (uint8 lane, uint256 index))",
  "function appendIntentWaiver(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address, (uint8 lane, uint256 index))",
  "function appendInterview(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures), address, (uint8 lane, uint256 index))",
  "function appendInterviewWaiver(bytes32 id)",
  "function appendLibrary(bytes32 id)",
  "function appendNative(bytes32 id)",
  "function appendOriginRuntime(bytes32 id)",
  "function appendReference(bytes32 id)",
  "function appendRenderer(bytes32 id)",
  "function appendRights(bytes32 id, (bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor))",
  "function appendRootAuthorization(bytes32 id, address actor, uint64 observedAt, (uint64 revision, bytes32 transitionChain) originalAggregate, (uint8 lane, uint256 index) receipt)",
  "function appendScript(bytes32 id)",
  "function appendToken(bytes32 id, (uint256 tokenId, address producer, bytes image, bytes animation) payload)",
  "function appendTokenPreservation(bytes32 id)",
  "function appendWork(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence), address, (uint8 lane, uint256 index))",
  "function artifactCoverage() view returns (address)",
  "function artistArchiveOrigin(bytes32 id, bytes32 itemHash) view returns ((((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) producer, (((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, uint256 nativeIndex) position, (uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash) receipt) occurrence, bytes32 importCommitment, uint64 importedAtRevision, address actor, bytes32 semanticRecordHash, bytes32 role, bytes32 sourceContextHash) original)",
  "function authorityDependencies() view returns ((address resolver, bytes32 resolverCodeHash, uint256 resolverGas))",
  "function authoritySelection(bytes32 id) view returns (((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) dependencies, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash) selection) captured)",
  "function beginInventory(uint256 collectionId) returns (bytes32 id)",
  "function core() view returns (address)",
  "function coreCodeHash() view returns (bytes32)",
  "function dependencies() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function dependencyHash() view returns (bytes32)",
  "function deploymentChainId() view returns (uint256)",
  "function externalCoverage() view returns (address)",
  "function inventoryEvidence(bytes32 id) view returns ((bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) result)",
  "function inventorySegment(bytes32 id, uint64 index) view returns ((bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash))",
  "function metadataCodeHash() view returns (bytes32)",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function originAt(bytes32 id, uint256 index) view returns (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash))",
  "function originCount(bytes32 id) view returns (uint256)",
  "function originDependencies() view returns ((address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile))",
  "function originProfile() pure returns (bytes32)",
  "function originRuntimeCursor(bytes32 id) view returns (uint256)",
  "function originSetHash(bytes32 id) view returns (bytes32)",
  "function originalAnchor() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function plan(bytes32 id) view returns ((uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash))",
  "function preservationPolicyInventoryProfile() pure returns (bytes32)",
  "function referencePublisher() view returns (address)",
  "function requireCurrent(uint256 collectionId) view returns ((bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) result)",
  "function requireFullDefinitionBytes(bytes32 id) view",
  "function sealInventory(bytes32 id) returns ((bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash))",
  "function snapshots() view returns (address)",
  "function sourceContext(bytes32 id) view returns (((uint256 collectionId, bytes32 subject, bytes32 artistId, (bytes32 recordHash, uint256 collectionId, bytes32 snapshotId, bytes32 predecessor, uint64 revision, bytes32 recordChainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, bytes32 inventoryPlan, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaDefinitionHash, bytes32 profileDefinitionHash, bytes32 canonicalizationDefinitionHash) snapshot, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, uint64 tokenCount) records, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, ((uint256 collectionId, bytes32 expectedPredecessor, bytes32 verifiedManifestRecordHash, string manifestURI) publication, bytes32 contentRoot, uint64 leafCount, bytes32 manifestHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address publisher, uint8 authorizationClass, uint64 grantRevision, bytes32 routeHash, bytes32 stateHash, bytes32 artistConsent, uint64 publishedAt) root, (bytes32 profileId, address outputManifest, bytes32 outputManifestCodeHash, address checkpoint, bytes32 checkpointCodeHash, bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 entropySourceSetCodeHash, bytes32 inventoryHash, bytes32 policyChainHash, bytes32 outputRoot, bytes32 outputSchemaHash, bytes32 outputCanonicalizationHash, bytes32 leafSchemaHash, bytes32 rootSchemaHash, bytes32 rootCanonicalizationHash, address metadataRouter, bytes32 preservationOutputProfile) rootBinding, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) source, bytes32 referenceSourceHash))",
  "function supportsInterface(bytes4 interfaceId) pure returns (bool)",
  "function tokenProgress(bytes32 id) view returns ((uint8 phase, uint64 row, uint64 count))",
] as const);

export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_ABI = Object.freeze([
  "error InvalidArchiveOrigin()",
  "error InvalidInventorySegment()",
  "error InventoryIncomplete()",
  "error InventoryRead(address target)",
  "error InventorySourceChanged()",
  "event ScopedInventoryCompleted(uint16 schemaVersion, bytes32 indexed id, bytes32 indexed evidenceHash, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "event ScopedInventorySegmentRecorded(uint16 schemaVersion, bytes32 indexed id, uint64 indexed index, (bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash) segment, (uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)[] items)",
  "event ScopedInventoryStarted(uint16 schemaVersion, bytes32 indexed id, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 contextHash)",
  "function appendDefinition(bytes32 id)",
  "function appendIntent(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) scale, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) timing, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) color, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) interaction, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) motion, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) frameRate) display, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) variabilityTolerances, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) dependencyAging, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) significantProperties, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address, (uint8 lane, uint256 index))",
  "function appendIntentWaiver(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin) artist, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement, (uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement) interview), address, (uint8 lane, uint256 index))",
  "function appendInterview(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, (uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document) instrument, (uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)[] participants, uint32 interviewDate, string[] languages, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) transcript, (uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)[] captures), address, (uint8 lane, uint256 index))",
  "function appendInterviewWaiver(bytes32 id)",
  "function appendNative(bytes32 id, uint64 maximum)",
  "function appendOriginRuntime(bytes32 id)",
  "function appendReference(bytes32 id, uint64 maximum)",
  "function appendRights(bytes32 id, (bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor))",
  "function appendRootAuthorization(bytes32 id, address actor, uint64 observedAt, (uint64 revision, bytes32 transitionChain) originalAggregate, bytes32 originalLegacyFamilyHash, (uint8 lane, uint256 index) receipt)",
  "function appendTokenCitation(bytes32 id)",
  "function appendTokenLibrary(bytes32 id)",
  "function appendTokenOutput(bytes32 id, (uint256 tokenId, address producer, bytes image, bytes animation) payload)",
  "function appendTokenPreservation(bytes32 id)",
  "function appendTokenRenderer(bytes32 id)",
  "function appendTokenScript(bytes32 id)",
  "function appendWork(bytes32 id, (bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence), address, (uint8 lane, uint256 index))",
  "function artifactCoverage() view returns (address)",
  "function artistArchiveOrigin(bytes32 id, bytes32 itemHash) view returns ((((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) producer, (((bytes32 environmentHash, uint8 ownerIndex, uint64 ownerRevision) point, uint256 nativeIndex) position, (uint16 operation, bytes32 artistId, uint256 collectionId, bytes32 recordHash) receipt) occurrence, bytes32 importCommitment, uint64 importedAtRevision, address actor, bytes32 semanticRecordHash, bytes32 role, bytes32 sourceContextHash) original)",
  "function authorityDependencies() view returns ((address resolver, bytes32 resolverCodeHash, uint256 resolverGas))",
  "function authoritySelection(bytes32 id) view returns (((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas) dependencies, (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash) origin, bytes32 completion, bytes32 selectionHash) selection) captured)",
  "function beginInventory((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) returns (bytes32 id)",
  "function core() view returns (address)",
  "function dependencies() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function dependencyHash() view returns (bytes32)",
  "function externalCoverage() view returns (address)",
  "function inventoryEvidence(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function inventorySegment(bytes32 id, uint64 index) view returns ((bytes32 key, uint64 itemCount, bytes32 firstLink, bytes32 sourceWitnessHash))",
  "function metadataHost() view returns (address)",
  "function metadataRouter() view returns (address)",
  "function originAt(bytes32 id, uint256 index) view returns (((uint256 chainId, address registry, address coordinator, address archive, address[7] owners, bytes32[7] ownerCodeHashes, address core, address manager, bytes32 suiteConfigurationHash) environment, bytes32 registryCodeHash, bytes32 coordinatorCodeHash, bytes32 archiveCodeHash))",
  "function originCount(bytes32 id) view returns (uint256)",
  "function originDependencies() view returns ((address worker, bytes32 workerCodeHash, uint256 originGas, bytes32 profile))",
  "function originProfile() pure returns (bytes32)",
  "function originRuntimeCursor(bytes32 id) view returns (uint256)",
  "function originSetHash(bytes32 id) view returns (bytes32)",
  "function originalAnchor() view returns ((address[12] targets, bytes32[12] codeHashes, address[5] artistTargets, bytes32[5] artistCodeHashes, address artistContentOwner, bytes32 artistContentOwnerCodeHash, uint256 chainId, uint256 readGas, uint256 sourceGas, uint256 selectionGas, uint256 snapshotGas, uint256 referenceGas))",
  "function plan(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (uint256 collectionId, bytes32 subject, bytes32 artistId, bytes32 sourceContextHash, uint64 tokenCount, uint64 nextToken, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, uint16 completedStages, bytes32 renderCriticalEvidenceHash) progress, uint64 nativeCursor, uint64 nativeCount, uint64 referenceCursor, uint64 referenceCount))",
  "function referencePublisher() view returns (address)",
  "function requireCurrent((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) e)",
  "function requireFullDefinitionBytes(bytes32 id) view",
  "function scopedPreservationPolicyInventoryProfile() pure returns (bytes32)",
  "function sealInventory(bytes32 id) returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 planId, uint256 collectionId, bytes32 scopeSubject, bytes32 artistId, (bytes32 rootRecordHash, bytes32 snapshotRecordHash, bytes32 referenceRenderRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsStatementRecordHash, bytes32 workDescriptionRecordHash) originals, bytes32 sourceContextHash, bytes32 tokenInventoryHash, uint64 tokenCount, uint64 segmentCount, uint64 itemCount, bytes32 segmentChainHash, bytes32 renderCriticalEvidenceHash) inventory) evidence)",
  "function snapshots() view returns (address)",
  "function sourceContext(bytes32 id) view returns (((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 subject, bytes32 artistId, (bytes32 recordHash, bytes32 scopeSubject, bytes32 predecessor, uint64 revision, bytes32 chainHash, bytes32 manifestHash, uint32 manifestBytes, bytes32 sourceHash, address publisher, uint8 authorizationClass, uint64 grantRevision, uint8 displayAuthorizationClass, uint64 displayGrantRevision, uint64 recordedAt, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) snapshot, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, (bytes32 scopeSubject, bytes32 scopeManifestHash, bytes32 sourceRecordHash, uint256 tokenCount, bytes32 tokenListHash, bytes32 membershipHash, uint256 inventoryCount, bytes32 inventoryPrefixHash) membership, (bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash) artist, ((uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, bytes32 membershipHash, bytes32 collectionStateHash, uint64 tokenCount, uint64 nextIndex, bytes32 selectionRoot) selection, (bytes32 selectionId, bytes32 selectionHash, bytes32 inventoryHash, bytes32 policyChainHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 nextIndex, bytes32 leafChainHash, bytes32 contentRoot, bytes32 outputRoot, bytes32 preservationProfile) content, (bytes32 checkpointHash, bytes32 checkpointStateHash, address entropySourceSet, bytes32 inventoryHash, bytes32 policyChainHash, address metadataRouter, bytes32 preservationProfile, bytes32 artifactHash, bytes32 coverageHash, bytes32 artistId, bytes32 contentRoot, bytes32 outputRoot, bytes32 manifestHash, (uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId) scope, uint64 tokenCount, uint64 byteLength) outputs, address sourceFactory, bytes32 sourceFactoryCodeHash, bytes32 factoryDependenciesHash, (bytes32 planId, bytes32 inventoryHash, bytes32 policyChainHash, uint256 policyCount, bool allFrozen, (address coordinator, bytes32 indexedCodeHash, uint256 firstTokenIndex, bool frozen, bytes32 moduleVersion, bytes32 moduleManifestHash, bytes32 moduleSchemaHash, bytes32 deploymentManifestHash, bytes32 policyHash, address provider, uint32 epoch, bytes32 salt, bytes32 componentDataHash, bool explicitPolicy, (bool configured, bool explicitPolicy, bool frozen, uint8 mode, uint8 securityClass, uint8 renderRequirement, uint64 revision, uint32 providerEpoch, bytes32 policyHash, bytes32 contentStateHash, bytes32 lastActionId, bytes32 artistConsentRecord) collectionPolicy)[] policies) entropy) snapshotSource, (bytes32 scopeSubject, (bytes32 recordHash, bytes32 recordChainHash, uint256 collectionId, bytes32 referenceId, bytes32 predecessor, uint64 revision, bytes32 payloadHash, uint32 payloadBytes, bytes32 sourcesHash, bytes32 snapshotRecordHash, uint64 snapshotRevision, address recorder, uint8 authorizationClass, uint64 grantRevision, uint64 effectiveAt, uint64 recordedAt, bytes32 reasonHash, bytes32 schemaHash, bytes32 profileHash, bytes32 canonicalizationHash) observation) referenceRender, (bytes32 scopeSubject, bytes32 workDescriptionRecordHash, bytes32 rightsStatementRecordHash, bytes32 workPayloadHash, bytes32 rightsPayloadHash, bytes32 workSelectionHash, bytes32 rightsSelectionHash, uint64 workRevision, uint64 rightsRevision) descriptions, ((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash) conservation, bytes32 interviewEvidenceHash, bytes32 nativeHash, bytes32 rootRecordHash, bytes32 tokenInventoryHash, bytes32 checkpointHash, bytes32 outputManifestRecord, bytes32 selectionId, bytes32 selectionHash, uint64 tokenCount))",
  "function supportsInterface(bytes4 id) pure returns (bool)",
  "function tokenProgress(bytes32 id) view returns ((uint8 phase, uint64 row, uint64 count))",
] as const);

const coder = AbiCoder.defaultAbiCoder();
const collectionInterface = new Interface(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_ABI);
const scopedInterface = new Interface(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_ABI);
const enumFields: Readonly<Record<string, Readonly<Record<string, number>>>> = {
  "(uint8 kind, bytes32 role, address source, bytes32 sourceRecord, uint256 sourceIndex, uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri, uint64 byteSize, bytes32 schemaId, bytes32 formatId, bytes32 catalogId, bytes32 catalogHash, bytes32 objectHash, bytes32 originalCoverageHash, bytes32 provenanceHash)": {
    "kind": 11
  },
  "(bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, uint8 origin)": {
    "origin": 1
  },
  "(uint8 status, (uint256 chainId, address core, address host, bytes32 recordHash, bytes32 schemaId, bytes32 profileHash, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) payload) record, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) waiverStatement)": {
    "status": 1
  },
  "(uint8 lane, uint256 index)": {
    "lane": 1
  },
  "(uint8 kind, string name, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) document)": {
    "kind": 1
  },
  "(uint8 role, string otherRole, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) identity)": {
    "role": 2
  },
  "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog)": {
    "kind": 1
  },
  "(bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)": {
    "kind": 1
  },
  "(uint8 kind, ((uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) content, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (uint16 algorithm, bytes32 canonicalizationId, bytes digest, string uri) specification)[] entries, bytes32 selectedEntryId) catalog) format) payload)": {
    "kind": 1
  },
  "(bytes32 subjectId, bytes32 profileHash, uint8 basis, (uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest) licensor, ((uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) aiTraining, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) derivative, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) exhibition, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) print, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) publication, (uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension) reproduction) grants, uint32 startDate, uint32 endDate, bool openEnd, (bool exists, string uri, bytes32 digest) instrument, bool hasAiTrainingPermission, uint8 aiTrainingPermission, bytes32 predecessor)": {
    "basis": 5,
    "aiTrainingPermission": 3
  },
  "(uint8 kind, bytes32 artistId, string name, address account, bytes32 instrumentDigest)": {
    "kind": 3
  },
  "(uint8 status, (uint8 kind, string text, (bool exists, string uri, bytes32 digest) document) conditions, string extension)": {
    "status": 3
  },
  "(uint8 kind, string text, (bool exists, string uri, bytes32 digest) document)": {
    "kind": 2
  },
  "(bytes32 subjectId, bytes32 profileHash, bytes32 predecessor, uint8 form, (string title, (uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name) creator, (uint8 kind, uint32 start, uint32 end) creation, string medium, (uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog) format, (uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds) measurements, (uint8 kind, uint256 number, uint256 total, string statement) edition, string creditLine, bool hasInscription, string inscription, string[] alternateTitles, (uint8 field, uint8 alternateTitleIndex, string language, string value)[] languageVariants, (uint8 role, uint8 authority, string identifier)[] authorityReferences) full, (string reason, uint32 date) absence)": {
    "form": 1
  },
  "(uint8 kind, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, string name)": {
    "kind": 1
  },
  "(uint8 kind, uint32 start, uint32 end)": {
    "kind": 1
  },
  "(uint8 kind, bytes32 formatId, string puid, (string name, (bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)[] entries, bytes32 selectedEntryId) catalog)": {
    "kind": 2
  },
  "(bytes32 entryId, uint8 kind, string puid, (string uri, bytes32 digest) specification)": {
    "kind": 1
  },
  "(uint8 kind, bool hasPixels, uint256 width, uint256 height, bool hasAspectRatio, (uint256 numerator, uint256 denominator) aspectRatio, bool hasDuration, (uint256 numerator, uint256 denominator) durationSeconds)": {
    "kind": 1
  },
  "(uint8 kind, uint256 number, uint256 total, string statement)": {
    "kind": 2
  },
  "(uint8 field, uint8 alternateTitleIndex, string language, string value)": {
    "field": 5
  },
  "(uint8 role, uint8 authority, string identifier)": {
    "role": 2,
    "authority": 3
  },
  "(bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash)": {
    "kind": 2
  },
  "((bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) record, (bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash) association, uint8 origin, uint8 interviewStatus, (bytes32 recordHash, uint8 kind, bytes32 payloadHash, address recorder, uint64 recordedAt, uint64 recordIndex, bytes32 recordChainHash, bytes32 receiptHash, (bytes32 attestationRecordHash, bytes32 artistId, bytes32 bindingHash, uint64 bindingGeneration, address signer, uint8 authorityClass, uint32 requiredCapability, uint64 signedAt, bytes32 publicationHash) publication, bytes32 publicationEvidenceHash) interview, bytes32 interviewArchiveReferenceHash, uint8 interviewPayloadCorrespondence, bytes32 predecessor, address submitter, uint64 revision, uint64 selectedAt, bytes32 catalogsHash, bytes32 selectionHash)": {
    "origin": 1,
    "interviewStatus": 1,
    "interviewPayloadCorrespondence": 2
  },
  "(uint8 scopeType, uint256 collectionId, uint256 tokenId, bytes32 scopeId)": {
    "scopeType": 4
  }
};


function kind(value: CurrentAuthorityPreservationInventoryV1Kind): CurrentAuthorityPreservationInventoryV1Kind {
  if (value !== "collection" && value !== "scoped") throw Error("Unknown inventory scope kind");
  return value;
}
function exact(value: unknown, keys: readonly string[]): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)
    || Reflect.ownKeys(value).length !== keys.length
    || keys.some(key => !Object.hasOwn(value, key))) throw Error("Unexpected inventory fields");
}
function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== "bigint" || value < 0n || value >= (1n << BigInt(bits))) throw Error(`Invalid uint${bits}`);
  return value;
}
function bytes(value: unknown, size?: number): Hex {
  if (typeof value !== "string" || !isHexString(value) || value.length % 2 !== 0
    || (size !== undefined && value.length !== 2 + size * 2)
    || (value.length - 2) / 2 > CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Invalid inventory bytes");
  return value.toLowerCase() as Hex;
}
function address(value: unknown, nonzero = false): Address {
  if (typeof value !== "string") throw Error("Invalid inventory address");
  const result = getAddress(value) as Address;
  if (nonzero && result === ZeroAddress) throw Error("Zero inventory address");
  return result;
}
function hash(value: unknown, nonzero = false): Hex {
  const result = bytes(value, 32);
  if (nonzero && result === ZeroHash) throw Error("Zero inventory hash");
  return result;
}
function text(value: unknown): string {
  if (typeof value !== "string" || /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/u.test(value)
    || toUtf8Bytes(value).length > CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_BYTES) throw Error("Invalid inventory text");
  return value;
}
function dense(value: unknown, size = -1): readonly unknown[] {
  if (!Array.isArray(value) || value.length > CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_ROWS
    || (size >= 0 && value.length !== size) || Reflect.ownKeys(value).length !== value.length + 1
    || Array.from({ length: value.length }, (_, i) => i).some(i => !Object.hasOwn(value, i))) throw Error("Invalid inventory array");
  return value;
}
function tupleKey(p: ParamType): string {
  return "(" + p.components!.map(c => (c.baseType === "tuple" ? tupleKey(c)
    : c.baseType === "array" && c.arrayChildren!.baseType === "tuple"
      ? tupleKey(c.arrayChildren!) + c.type.slice(c.type.lastIndexOf("[")) : c.type) + " " + c.name).join(", ") + ")";
}
function walk(p: ParamType, value: unknown, decoded = false): unknown {
  if (p.baseType === "array") {
    const values = decoded ? Array.from(value as readonly unknown[]) : dense(value, p.arrayLength!);
    if (values.length > CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_MAX_ROWS) throw Error("Inventory array limit");
    return Object.freeze(values.map(v => walk(p.arrayChildren!, v, decoded)));
  }
  if (p.baseType === "tuple") {
    const components = p.components!;
    if (!decoded) exact(value, components.map(c => c.name));
    const result: Record<string, unknown> = {};
    const limits = enumFields[tupleKey(p)];
    components.forEach((c, i) => {
      result[c.name] = walk(c, decoded ? (value as readonly unknown[])[i] : (value as Record<string, unknown>)[c.name], decoded);
      if (limits?.[c.name] !== undefined && (result[c.name] as bigint) > BigInt(limits[c.name]!)) throw Error("Unknown original enum");
    });
    return Object.freeze(result);
  }
  if (p.type.startsWith("uint")) return uint(value, Number(p.type.slice(4)));
  if (p.type === "address") return address(value);
  if (p.type === "bool") {
    if (typeof value !== "boolean") throw Error("Invalid inventory boolean");
    return value;
  }
  if (p.type === "string") return text(value);
  if (p.type.startsWith("bytes")) return bytes(value, p.type === "bytes" ? undefined : Number(p.type.slice(5)));
  throw Error("Unsupported inventory ABI value");
}
function normalized<T>(tuple: string, value: T): T {
  return walk(ParamType.from(tuple), value) as T;
}
function encoded<T>(tuple: string, value: T): Hex {
  return bytes(coder.encode([tuple], [normalized(tuple, value)]));
}
function decoded<T>(tuple: string, value: Hex): T {
  const raw = bytes(value);
  const result = walk(ParamType.from(tuple), coder.decode([tuple], raw)[0], true) as T;
  if (encoded(tuple, result) !== raw) throw Error("Noncanonical inventory ABI bytes");
  return result;
}
function h(types: readonly string[], values: readonly unknown[]): Hex {
  return keccak256(coder.encode(types, values)) as Hex;
}
function equal(actual: unknown, expected: unknown, label: string): void {
  if (JSON.stringify(actual, (_, v) => typeof v === "bigint" ? v.toString() : v).toLowerCase()
    !== JSON.stringify(expected, (_, v) => typeof v === "bigint" ? v.toString() : v).toLowerCase()) throw Error(label);
}
export function currentAuthorityPreservationInventoryV1Profile(scopeKind: CurrentAuthorityPreservationInventoryV1Kind): Hex {
  return kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PROFILE
    : CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PROFILE;
}
export function currentAuthorityPreservationInventoryV1Interface(scopeKind: CurrentAuthorityPreservationInventoryV1Kind): Interface {
  return new Interface(kind(scopeKind) === "collection" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_ABI
    : CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_ABI);
}
export function normalizeCurrentAuthorityPreservationInventoryV1Coordinates(
  value: CurrentAuthorityPreservationInventoryV1Coordinates,
): CurrentAuthorityPreservationInventoryV1Coordinates {
  exact(value, ["chainId", "core", "inventory", "scopeKind"]);
  const chainId = uint(value.chainId);
  if (chainId === 0n) throw Error("Zero inventory chain");
  return Object.freeze({ chainId, core: address(value.core, true), inventory: address(value.inventory, true), scopeKind: kind(value.scopeKind) });
}
export const validateCurrentAuthorityPreservationInventoryV1Scope = output.validateTokenPreservationOutputV2Scope;
export const currentAuthorityPreservationInventoryV1ScopeSubject = snapshot.tokenPreservationSnapshotV2ScopeSubject;

export function normalizeCurrentAuthorityPreservationInventoryV1Dependencies(value: CurrentAuthorityPreservationInventoryV1Dependencies): CurrentAuthorityPreservationInventoryV1Dependencies {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Dependencies(value: CurrentAuthorityPreservationInventoryV1Dependencies): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Dependencies(value: Hex): CurrentAuthorityPreservationInventoryV1Dependencies {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies(value: CurrentAuthorityPreservationInventoryV1OriginDependencies): CurrentAuthorityPreservationInventoryV1OriginDependencies {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1OriginDependencies(value: CurrentAuthorityPreservationInventoryV1OriginDependencies): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1OriginDependencies(value: Hex): CurrentAuthorityPreservationInventoryV1OriginDependencies {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(value: CurrentAuthorityPreservationInventoryV1AuthorityDependencies): CurrentAuthorityPreservationInventoryV1AuthorityDependencies {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(value: CurrentAuthorityPreservationInventoryV1AuthorityDependencies): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(value: Hex): CurrentAuthorityPreservationInventoryV1AuthorityDependencies {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(value: CurrentAuthorityPreservationInventoryV1AuthorityAnchors): CurrentAuthorityPreservationInventoryV1AuthorityAnchors {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_ANCHORS_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(value: CurrentAuthorityPreservationInventoryV1AuthorityAnchors): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_ANCHORS_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(value: Hex): CurrentAuthorityPreservationInventoryV1AuthorityAnchors {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_ANCHORS_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1OriginEnvironment(value: CurrentAuthorityPreservationInventoryV1OriginEnvironment): CurrentAuthorityPreservationInventoryV1OriginEnvironment {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_ENVIRONMENT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1OriginEnvironment(value: CurrentAuthorityPreservationInventoryV1OriginEnvironment): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_ENVIRONMENT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1OriginEnvironment(value: Hex): CurrentAuthorityPreservationInventoryV1OriginEnvironment {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_ENVIRONMENT_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Origin(value: CurrentAuthorityPreservationInventoryV1Origin): CurrentAuthorityPreservationInventoryV1Origin {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Origin(value: CurrentAuthorityPreservationInventoryV1Origin): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Origin(value: Hex): CurrentAuthorityPreservationInventoryV1Origin {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Selection(value: CurrentAuthorityPreservationInventoryV1Selection): CurrentAuthorityPreservationInventoryV1Selection {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SELECTION_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Selection(value: CurrentAuthorityPreservationInventoryV1Selection): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SELECTION_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Selection(value: Hex): CurrentAuthorityPreservationInventoryV1Selection {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SELECTION_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Capture(value: CurrentAuthorityPreservationInventoryV1Capture): CurrentAuthorityPreservationInventoryV1Capture {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_CAPTURE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Capture(value: CurrentAuthorityPreservationInventoryV1Capture): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_CAPTURE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Capture(value: Hex): CurrentAuthorityPreservationInventoryV1Capture {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_CAPTURE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(value: CurrentAuthorityPreservationInventoryV1RecordOrigin): CurrentAuthorityPreservationInventoryV1RecordOrigin {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1RecordOrigin(value: CurrentAuthorityPreservationInventoryV1RecordOrigin): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1RecordOrigin(value: Hex): CurrentAuthorityPreservationInventoryV1RecordOrigin {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1ReceiptWitness(value: CurrentAuthorityPreservationInventoryV1ReceiptWitness): CurrentAuthorityPreservationInventoryV1ReceiptWitness {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECEIPT_WITNESS_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1ReceiptWitness(value: CurrentAuthorityPreservationInventoryV1ReceiptWitness): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECEIPT_WITNESS_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1ReceiptWitness(value: Hex): CurrentAuthorityPreservationInventoryV1ReceiptWitness {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECEIPT_WITNESS_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Item(value: CurrentAuthorityPreservationInventoryV1Item): CurrentAuthorityPreservationInventoryV1Item {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Item(value: CurrentAuthorityPreservationInventoryV1Item): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Item(value: Hex): CurrentAuthorityPreservationInventoryV1Item {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ITEM_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Segment(value: CurrentAuthorityPreservationInventoryV1Segment): CurrentAuthorityPreservationInventoryV1Segment {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Segment(value: CurrentAuthorityPreservationInventoryV1Segment): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Segment(value: Hex): CurrentAuthorityPreservationInventoryV1Segment {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SEGMENT_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1CollectionPlan(value: CurrentAuthorityPreservationInventoryV1CollectionPlan): CurrentAuthorityPreservationInventoryV1CollectionPlan {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PLAN_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1CollectionPlan(value: CurrentAuthorityPreservationInventoryV1CollectionPlan): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PLAN_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1CollectionPlan(value: Hex): CurrentAuthorityPreservationInventoryV1CollectionPlan {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_PLAN_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1ScopedPlan(value: CurrentAuthorityPreservationInventoryV1ScopedPlan): CurrentAuthorityPreservationInventoryV1ScopedPlan {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PLAN_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1ScopedPlan(value: CurrentAuthorityPreservationInventoryV1ScopedPlan): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PLAN_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1ScopedPlan(value: Hex): CurrentAuthorityPreservationInventoryV1ScopedPlan {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_PLAN_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1TokenProgress(value: CurrentAuthorityPreservationInventoryV1TokenProgress): CurrentAuthorityPreservationInventoryV1TokenProgress {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1TokenProgress(value: CurrentAuthorityPreservationInventoryV1TokenProgress): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1TokenProgress(value: Hex): CurrentAuthorityPreservationInventoryV1TokenProgress {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_TOKEN_PROGRESS_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value: CurrentAuthorityPreservationInventoryV1CollectionEvidence): CurrentAuthorityPreservationInventoryV1CollectionEvidence {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value: CurrentAuthorityPreservationInventoryV1CollectionEvidence): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value: Hex): CurrentAuthorityPreservationInventoryV1CollectionEvidence {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value: CurrentAuthorityPreservationInventoryV1ScopedEvidence): CurrentAuthorityPreservationInventoryV1ScopedEvidence {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value: CurrentAuthorityPreservationInventoryV1ScopedEvidence): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value: Hex): CurrentAuthorityPreservationInventoryV1ScopedEvidence {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1CollectionContext(value: CurrentAuthorityPreservationInventoryV1CollectionContext): CurrentAuthorityPreservationInventoryV1CollectionContext {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_CONTEXT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1CollectionContext(value: CurrentAuthorityPreservationInventoryV1CollectionContext): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_CONTEXT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1CollectionContext(value: Hex): CurrentAuthorityPreservationInventoryV1CollectionContext {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_CONTEXT_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1ScopedContext(value: CurrentAuthorityPreservationInventoryV1ScopedContext): CurrentAuthorityPreservationInventoryV1ScopedContext {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_CONTEXT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1ScopedContext(value: CurrentAuthorityPreservationInventoryV1ScopedContext): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_CONTEXT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1ScopedContext(value: Hex): CurrentAuthorityPreservationInventoryV1ScopedContext {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_CONTEXT_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Scope(value: CurrentAuthorityPreservationInventoryV1Scope): CurrentAuthorityPreservationInventoryV1Scope {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Scope(value: CurrentAuthorityPreservationInventoryV1Scope): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Scope(value: Hex): CurrentAuthorityPreservationInventoryV1Scope {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Work(value: CurrentAuthorityPreservationInventoryV1Work): CurrentAuthorityPreservationInventoryV1Work {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_WORK_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Work(value: CurrentAuthorityPreservationInventoryV1Work): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_WORK_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Work(value: Hex): CurrentAuthorityPreservationInventoryV1Work {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_WORK_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Rights(value: CurrentAuthorityPreservationInventoryV1Rights): CurrentAuthorityPreservationInventoryV1Rights {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RIGHTS_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Rights(value: CurrentAuthorityPreservationInventoryV1Rights): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RIGHTS_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Rights(value: Hex): CurrentAuthorityPreservationInventoryV1Rights {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RIGHTS_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Intent(value: CurrentAuthorityPreservationInventoryV1Intent): CurrentAuthorityPreservationInventoryV1Intent {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Intent(value: CurrentAuthorityPreservationInventoryV1Intent): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Intent(value: Hex): CurrentAuthorityPreservationInventoryV1Intent {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1IntentWaiver(value: CurrentAuthorityPreservationInventoryV1IntentWaiver): CurrentAuthorityPreservationInventoryV1IntentWaiver {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1IntentWaiver(value: CurrentAuthorityPreservationInventoryV1IntentWaiver): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1IntentWaiver(value: Hex): CurrentAuthorityPreservationInventoryV1IntentWaiver {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Interview(value: CurrentAuthorityPreservationInventoryV1Interview): CurrentAuthorityPreservationInventoryV1Interview {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Interview(value: CurrentAuthorityPreservationInventoryV1Interview): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Interview(value: Hex): CurrentAuthorityPreservationInventoryV1Interview {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Payload(value: CurrentAuthorityPreservationInventoryV1Payload): CurrentAuthorityPreservationInventoryV1Payload {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_PAYLOAD_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Payload(value: CurrentAuthorityPreservationInventoryV1Payload): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_PAYLOAD_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Payload(value: Hex): CurrentAuthorityPreservationInventoryV1Payload {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_PAYLOAD_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Aggregate(value: CurrentAuthorityPreservationInventoryV1Aggregate): CurrentAuthorityPreservationInventoryV1Aggregate {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AGGREGATE_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Aggregate(value: CurrentAuthorityPreservationInventoryV1Aggregate): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AGGREGATE_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Aggregate(value: Hex): CurrentAuthorityPreservationInventoryV1Aggregate {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AGGREGATE_TUPLE, value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Context(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Context): CurrentAuthorityPreservationInventoryV1Context {
  return kind(scopeKind) === "collection" ? normalizeCurrentAuthorityPreservationInventoryV1CollectionContext(value as CurrentAuthorityPreservationInventoryV1CollectionContext)
    : normalizeCurrentAuthorityPreservationInventoryV1ScopedContext(value as CurrentAuthorityPreservationInventoryV1ScopedContext);
}
export function encodeCurrentAuthorityPreservationInventoryV1Context(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Context): Hex {
  return kind(scopeKind) === "collection" ? encodeCurrentAuthorityPreservationInventoryV1CollectionContext(value as CurrentAuthorityPreservationInventoryV1CollectionContext)
    : encodeCurrentAuthorityPreservationInventoryV1ScopedContext(value as CurrentAuthorityPreservationInventoryV1ScopedContext);
}
export function decodeCurrentAuthorityPreservationInventoryV1Context(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: Hex): CurrentAuthorityPreservationInventoryV1Context {
  return kind(scopeKind) === "collection" ? decodeCurrentAuthorityPreservationInventoryV1CollectionContext(value) : decodeCurrentAuthorityPreservationInventoryV1ScopedContext(value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Plan(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Plan): CurrentAuthorityPreservationInventoryV1Plan {
  return kind(scopeKind) === "collection" ? normalizeCurrentAuthorityPreservationInventoryV1CollectionPlan(value as CurrentAuthorityPreservationInventoryV1CollectionPlan)
    : normalizeCurrentAuthorityPreservationInventoryV1ScopedPlan(value as CurrentAuthorityPreservationInventoryV1ScopedPlan);
}
export function encodeCurrentAuthorityPreservationInventoryV1Plan(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Plan): Hex {
  return kind(scopeKind) === "collection" ? encodeCurrentAuthorityPreservationInventoryV1CollectionPlan(value as CurrentAuthorityPreservationInventoryV1CollectionPlan)
    : encodeCurrentAuthorityPreservationInventoryV1ScopedPlan(value as CurrentAuthorityPreservationInventoryV1ScopedPlan);
}
export function decodeCurrentAuthorityPreservationInventoryV1Plan(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: Hex): CurrentAuthorityPreservationInventoryV1Plan {
  return kind(scopeKind) === "collection" ? decodeCurrentAuthorityPreservationInventoryV1CollectionPlan(value) : decodeCurrentAuthorityPreservationInventoryV1ScopedPlan(value);
}

export function normalizeCurrentAuthorityPreservationInventoryV1Evidence(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Evidence): CurrentAuthorityPreservationInventoryV1Evidence {
  return kind(scopeKind) === "collection" ? normalizeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value as CurrentAuthorityPreservationInventoryV1CollectionEvidence)
    : normalizeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value as CurrentAuthorityPreservationInventoryV1ScopedEvidence);
}
export function encodeCurrentAuthorityPreservationInventoryV1Evidence(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Evidence): Hex {
  return kind(scopeKind) === "collection" ? encodeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value as CurrentAuthorityPreservationInventoryV1CollectionEvidence)
    : encodeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value as CurrentAuthorityPreservationInventoryV1ScopedEvidence);
}
export function decodeCurrentAuthorityPreservationInventoryV1Evidence(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: Hex): CurrentAuthorityPreservationInventoryV1Evidence {
  return kind(scopeKind) === "collection" ? decodeCurrentAuthorityPreservationInventoryV1CollectionEvidence(value) : decodeCurrentAuthorityPreservationInventoryV1ScopedEvidence(value);
}

/** Includes all original gas fields. A supplied digest is not a runtime pin check. */
export function currentAuthorityPreservationInventoryV1DependencyHash(
  scopeKind: CurrentAuthorityPreservationInventoryV1Kind,
  anchor: CurrentAuthorityPreservationInventoryV1Dependencies,
  origin: CurrentAuthorityPreservationInventoryV1OriginDependencies,
  authority: CurrentAuthorityPreservationInventoryV1AuthorityDependencies,
): Hex {
  return h(["bytes32", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_DEPENDENCIES_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_DEPENDENCIES_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_DEPENDENCIES_TUPLE],
  [currentAuthorityPreservationInventoryV1Profile(scopeKind), normalizeCurrentAuthorityPreservationInventoryV1Dependencies(anchor),
    normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies(origin), normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(authority)]);
}
export function currentAuthorityPreservationInventoryV1SelectionHash(
  anchors: CurrentAuthorityPreservationInventoryV1AuthorityAnchors,
  origin: CurrentAuthorityPreservationInventoryV1Origin,
  completion: Hex,
): Hex {
  return h(["bytes32", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_ANCHORS_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE, "bytes32"],
  [CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_AUTHORITY_PROFILE,
    normalizeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(anchors), normalizeCurrentAuthorityPreservationInventoryV1Origin(origin), hash(completion)]);
}
export function currentAuthorityPreservationInventoryV1OriginEnvironmentHash(
  value: CurrentAuthorityPreservationInventoryV1OriginEnvironment,
): Hex {
  return h(["bytes32", "uint16", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_ENVIRONMENT_TUPLE],
    [id("6529STREAM_ARTIST_RECOVERED_HYDRATION_ORIGIN_V1"), 1n, normalizeCurrentAuthorityPreservationInventoryV1OriginEnvironment(value)]);
}
export function currentAuthorityPreservationInventoryV1OriginPinHash(value: CurrentAuthorityPreservationInventoryV1Origin): Hex {
  return h(["bytes32", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_TUPLE],
    [CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE, normalizeCurrentAuthorityPreservationInventoryV1Origin(value)]);
}
export function currentAuthorityPreservationInventoryV1RecordOriginHash(value: CurrentAuthorityPreservationInventoryV1RecordOrigin): Hex {
  return h(["bytes32", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RECORD_ORIGIN_TUPLE],
    [id("6529STREAM_ARTIST_ARCHIVE_RECORD_ORIGIN_V1"), normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(value)]);
}
export function currentAuthorityPreservationInventoryV1EvidenceId(value: CurrentAuthorityPreservationInventoryV1RecordOrigin): Hex {
  const r = normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(value);
  return h(["bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"],
    [id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), r.producer.environment.chainId,
      r.producer.environment.registry, r.producer.environment.coordinator, r.occurrence.receipt.operation, r.actor, r.occurrence.receipt.recordHash]);
}
export function currentAuthorityPreservationInventoryV1AppendOrigin(previous: Hex, index: bigint, origin: CurrentAuthorityPreservationInventoryV1Origin): Hex {
  return h(["bytes32", "bytes32", "uint256", "bytes32"],
    [id("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_ITEM_V1"), hash(previous), uint(index), currentAuthorityPreservationInventoryV1OriginPinHash(origin)]);
}
export function currentAuthorityPreservationInventoryV1SealedOriginSetHash(count: bigint, chain: Hex): Hex {
  const n = uint(count);
  if (n === 0n || n > 17n) throw Error("Origin set limit");
  return h(["bytes32", "uint256", "bytes32"], [id("6529STREAM_ARTIST_ARCHIVE_ORIGIN_SET_V1"), n, hash(chain, true)]);
}
/** Ordered table construction only. It cannot establish ancestral admission or deployed code. */
export function currentAuthorityPreservationInventoryV1Origins(
  values: readonly CurrentAuthorityPreservationInventoryV1Origin[],
): readonly CurrentAuthorityPreservationInventoryV1Origin[] {
  const result: CurrentAuthorityPreservationInventoryV1Origin[] = [];
  const seen = new Map<Hex, Hex>();
  for (const value of dense(values)) {
    const origin = normalizeCurrentAuthorityPreservationInventoryV1Origin(value as CurrentAuthorityPreservationInventoryV1Origin);
    const environment = currentAuthorityPreservationInventoryV1OriginEnvironmentHash(origin.environment);
    const pin = currentAuthorityPreservationInventoryV1OriginPinHash(origin);
    const prior = seen.get(environment);
    if (prior !== undefined) {
      if (prior !== pin) throw Error("Conflicting pins for original environment");
      continue;
    }
    if (result.length === 17) throw Error("Origin set limit");
    seen.set(environment, pin);
    result.push(origin);
  }
  return Object.freeze(result);
}
export function currentAuthorityPreservationInventoryV1OriginSetHash(values: readonly CurrentAuthorityPreservationInventoryV1Origin[]): Hex {
  const rows = currentAuthorityPreservationInventoryV1Origins(values);
  let chain = ZeroHash as Hex;
  rows.forEach((row, i) => { chain = currentAuthorityPreservationInventoryV1AppendOrigin(chain, BigInt(i), row); });
  return currentAuthorityPreservationInventoryV1SealedOriginSetHash(BigInt(rows.length), chain);
}
export function currentAuthorityPreservationInventoryV1CaptureDependencies(
  anchor: CurrentAuthorityPreservationInventoryV1Dependencies,
  selection: CurrentAuthorityPreservationInventoryV1Selection,
): CurrentAuthorityPreservationInventoryV1Dependencies {
  const a = normalizeCurrentAuthorityPreservationInventoryV1Dependencies(anchor);
  const o = normalizeCurrentAuthorityPreservationInventoryV1Selection(selection).origin;
  return normalizeCurrentAuthorityPreservationInventoryV1Dependencies({ ...a,
    artistTargets: [o.environment.registry, o.environment.coordinator, o.environment.owners[2], o.environment.owners[4], o.environment.archive],
    artistCodeHashes: [o.registryCodeHash, o.coordinatorCodeHash, o.environment.ownerCodeHashes[2], o.environment.ownerCodeHashes[4], o.archiveCodeHash],
    artistContentOwner: o.environment.owners[6], artistContentOwnerCodeHash: o.environment.ownerCodeHashes[6] });
}
export function currentAuthorityPreservationInventoryV1TypedContextHash(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Context): Hex {
  return keccak256(encodeCurrentAuthorityPreservationInventoryV1Context(scopeKind, value)) as Hex;
}
export function currentAuthorityPreservationInventoryV1ContextHash(capture: CurrentAuthorityPreservationInventoryV1Capture, typedContextHash: Hex, lineageHash: Hex): Hex {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Capture(capture);
  return h(["bytes32", "bytes32", "bytes32", "bytes32", "bytes32"],
    [id("6529STREAM_CURRENT_AUTHORITY_INVENTORY_CONTEXT_V1"), c.selection.selectionHash,
      keccak256(encodeCurrentAuthorityPreservationInventoryV1Dependencies(c.dependencies)), hash(typedContextHash), hash(lineageHash)]);
}
export function currentAuthorityPreservationInventoryV1PlanId(coordinates: CurrentAuthorityPreservationInventoryV1Coordinates, dependencyHash: Hex, contextHash: Hex): Hex {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  return h(["bytes32", "uint256", "address", "bytes32", "bytes32"],
    [currentAuthorityPreservationInventoryV1Profile(c.scopeKind), c.chainId, c.inventory, hash(dependencyHash), hash(contextHash)]);
}
export function currentAuthorityPreservationInventoryV1EvidenceHash(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates, dependencyHash: Hex, selectionHash: Hex,
  evidence: CurrentAuthorityPreservationInventoryV1Evidence, originRoot: Hex, originCount: bigint,
): Hex {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const e = normalizeCurrentAuthorityPreservationInventoryV1Evidence(c.scopeKind, evidence);
  const preimage = c.scopeKind === "collection" ? { ...e, renderCriticalEvidenceHash: ZeroHash }
    : { ...e, inventory: { ...(e as CurrentAuthorityPreservationInventoryV1ScopedEvidence).inventory, renderCriticalEvidenceHash: ZeroHash } };
  return h(["bytes32", "uint256", "address", "bytes32", "bytes32", c.scopeKind === "collection"
    ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_COLLECTION_EVIDENCE_TUPLE : CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_SCOPED_EVIDENCE_TUPLE, "bytes32", "uint256"],
  [currentAuthorityPreservationInventoryV1Profile(c.scopeKind), c.chainId, c.inventory, hash(dependencyHash), hash(selectionHash), preimage, hash(originRoot), uint(originCount)]);
}
/** Exact byte-equivalent original item/segment preimages; source-derived membership is separate. */
export function currentAuthorityPreservationInventoryV1ItemHash(value: CurrentAuthorityPreservationInventoryV1Item): Hex {
  return old.scopedPolicyInventoryV2ItemHash(normalizeCurrentAuthorityPreservationInventoryV1Item(value));
}
export function currentAuthorityPreservationInventoryV1Link(key: Hex, count: bigint, index: bigint, value: CurrentAuthorityPreservationInventoryV1Item, next: Hex): Hex {
  return old.scopedPolicyInventoryV2Link(key, count, index, normalizeCurrentAuthorityPreservationInventoryV1Item(value), next);
}
export function currentAuthorityPreservationInventoryV1Segment(key: Hex, witness: Hex, values: readonly CurrentAuthorityPreservationInventoryV1Item[]): CurrentAuthorityPreservationInventoryV1Segment {
  const rows = dense(values).map(v => normalizeCurrentAuthorityPreservationInventoryV1Item(v as CurrentAuthorityPreservationInventoryV1Item));
  return old.scopedPolicyInventoryV2Segment(key, witness, rows);
}
export const validateCurrentAuthorityPreservationInventoryV1Segment = old.validateScopedPolicyInventoryV2Segment;
export function currentAuthorityPreservationInventoryV1AppendSegment(previous: Hex, index: bigint, value: CurrentAuthorityPreservationInventoryV1Segment): Hex {
  return old.scopedPolicyInventoryV2AppendSegment(previous, index, normalizeCurrentAuthorityPreservationInventoryV1Segment(value));
}
export function currentAuthorityPreservationInventoryV1SegmentKey(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, planId: Hex, index: bigint): Hex {
  return h(["bytes32", "bytes32", "uint64"], [id(kind(scopeKind) === "collection" ? "6529STREAM_RENDER_CRITICAL_SEGMENT_V1"
    : "6529STREAM_SCOPED_PRESERVATION_POLICY_RENDER_CRITICAL_SEGMENT_V1"), hash(planId), uint(index, 64)]);
}
export const currentAuthorityPreservationInventoryV1CursorWitness = old.scopedPolicyInventoryV2CursorWitness;

export type CurrentAuthorityPreservationInventoryV1ArtistPresentation = CurrentAuthorityPreservationInventoryV1ScopedContext["snapshotSource"]["artist"];
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ARTIST_PRESENTATION_TUPLE = "(bool locked, address registry, bytes32 registryCodeHash, bytes32 artistId, uint64 bindingGeneration, bytes32 bindingHash, address nominatedArtist, bytes32 identityRecordHash, bytes32 acceptanceRecordHash, uint64 acceptedAt, uint64 lockedAt, bytes32 snapshotHash)";
export function normalizeCurrentAuthorityPreservationInventoryV1ArtistPresentation(value: CurrentAuthorityPreservationInventoryV1ArtistPresentation): CurrentAuthorityPreservationInventoryV1ArtistPresentation {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ARTIST_PRESENTATION_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1ArtistPresentation(value: CurrentAuthorityPreservationInventoryV1ArtistPresentation): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ARTIST_PRESENTATION_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1ArtistPresentation(value: Hex): CurrentAuthorityPreservationInventoryV1ArtistPresentation {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ARTIST_PRESENTATION_TUPLE, value);
}

export type CurrentAuthorityPreservationInventoryV1Association = CurrentAuthorityPreservationInventoryV1ScopedContext["conservation"]["association"];
export const CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ASSOCIATION_TUPLE = "(bytes32 artistId, bytes32 bindingHash, uint64 generation, bytes32 identityRecordHash)";
export function normalizeCurrentAuthorityPreservationInventoryV1Association(value: CurrentAuthorityPreservationInventoryV1Association): CurrentAuthorityPreservationInventoryV1Association {
  return normalized(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ASSOCIATION_TUPLE, value);
}
export function encodeCurrentAuthorityPreservationInventoryV1Association(value: CurrentAuthorityPreservationInventoryV1Association): Hex {
  return encoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ASSOCIATION_TUPLE, value);
}
export function decodeCurrentAuthorityPreservationInventoryV1Association(value: Hex): CurrentAuthorityPreservationInventoryV1Association {
  return decoded(CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ASSOCIATION_TUPLE, value);
}

export function currentAuthorityPreservationInventoryV1PresentationHash(
  dependencies: CurrentAuthorityPreservationInventoryV1Dependencies,
  collectionId: bigint,
  presented: CurrentAuthorityPreservationInventoryV1ArtistPresentation,
): Hex {
  const d = normalizeCurrentAuthorityPreservationInventoryV1Dependencies(dependencies);
  const p = normalizeCurrentAuthorityPreservationInventoryV1ArtistPresentation(presented);
  return h(["bytes32", "uint256", "address", "address", "uint256", "address", "bytes32", "bytes32", "uint64", "bytes32", "address", "bytes32", "bytes32", "uint64", "uint64"],
    [id("6529STREAM_ROUTER_ARTIST_PRESENTATION_V1"), d.chainId, d.targets[0], d.targets[4], uint(collectionId),
      p.registry, p.registryCodeHash, p.artistId, p.bindingGeneration, p.bindingHash, p.nominatedArtist,
      p.identityRecordHash, p.acceptanceRecordHash, p.acceptedAt, p.lockedAt]);
}
/** Supplied immutable presentation facts only; ancestor and association getter admission remain onchain. */
export function currentAuthorityPreservationInventoryV1LineageHash(
  dependencies: CurrentAuthorityPreservationInventoryV1Dependencies,
  collectionId: bigint,
  presented: CurrentAuthorityPreservationInventoryV1ArtistPresentation,
  association: CurrentAuthorityPreservationInventoryV1Association,
  current: CurrentAuthorityPreservationInventoryV1Origin,
  original: CurrentAuthorityPreservationInventoryV1Origin,
): Hex {
  const d = normalizeCurrentAuthorityPreservationInventoryV1Dependencies(dependencies);
  return h(["bytes32", "uint256", "address", "address", "uint256", CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ARTIST_PRESENTATION_TUPLE,
    CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ASSOCIATION_TUPLE, "bytes32", "bytes32"],
  [id("6529STREAM_ARTIST_ARCHIVE_PRESENTATION_LINEAGE_V1"), d.chainId, d.targets[0], d.targets[4], uint(collectionId),
    normalizeCurrentAuthorityPreservationInventoryV1ArtistPresentation(presented), normalizeCurrentAuthorityPreservationInventoryV1Association(association),
    currentAuthorityPreservationInventoryV1OriginPinHash(current), currentAuthorityPreservationInventoryV1OriginPinHash(original)]);
}
/** Constructor/selection value predicates; no eth_getCode or interface observation is inferred. */
export function validateCurrentAuthorityPreservationInventoryV1Dependencies(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates,
  dependencies: CurrentAuthorityPreservationInventoryV1Dependencies,
  originDependencies: CurrentAuthorityPreservationInventoryV1OriginDependencies,
  authorityDependencies: CurrentAuthorityPreservationInventoryV1AuthorityDependencies,
): CurrentAuthorityPreservationInventoryV1Dependencies {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const d = normalizeCurrentAuthorityPreservationInventoryV1Dependencies(dependencies);
  const o = normalizeCurrentAuthorityPreservationInventoryV1OriginDependencies(originDependencies);
  const a = normalizeCurrentAuthorityPreservationInventoryV1AuthorityDependencies(authorityDependencies);
  equal([d.chainId, d.targets[0]], [c.chainId, c.core], "Original inventory coordinates");
  for (const target of [...d.targets, ...d.artistTargets, d.artistContentOwner, o.worker, a.resolver]) address(target, true);
  for (const codeHash of [...d.codeHashes, ...d.artistCodeHashes, d.artistContentOwnerCodeHash, o.workerCodeHash, a.resolverCodeHash]) hash(codeHash, true);
  if (d.readGas < 50000n || [d.sourceGas, d.selectionGas, d.snapshotGas, d.referenceGas].some(v => v < d.readGas)
    || o.originGas < 50000n || o.originGas > (1n << 64n) - 1n || a.resolverGas < 50000n || a.resolverGas > (1n << 64n) - 1n
    || o.profile !== CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_ORIGIN_PROFILE) throw Error("Original inventory dependency bounds");
  return d;
}
export function validateCurrentAuthorityPreservationInventoryV1Capture(
  anchor: CurrentAuthorityPreservationInventoryV1Dependencies,
  anchors: CurrentAuthorityPreservationInventoryV1AuthorityAnchors,
  value: CurrentAuthorityPreservationInventoryV1Capture,
): CurrentAuthorityPreservationInventoryV1Capture {
  const d = normalizeCurrentAuthorityPreservationInventoryV1Dependencies(anchor);
  const a = normalizeCurrentAuthorityPreservationInventoryV1AuthorityAnchors(anchors);
  const c = normalizeCurrentAuthorityPreservationInventoryV1Capture(value);
  equal([a.chainId, a.targets.slice(0, 4), a.codeHashes.slice(0, 4)],
    [d.chainId, [d.targets[0], d.targets[1], d.targets[4], d.artistTargets[0]], [d.codeHashes[0], d.codeHashes[1], d.codeHashes[4], d.artistCodeHashes[0]]], "Original resolver anchors");
  if (a.readGas < 50000n || a.readGas > (1n << 64n) - 1n) throw Error("Original resolver gas");
  address(a.targets[4], true);
  hash(a.codeHashes[4], true);
  address(a.finalityRegistry, true);
  hash(c.selection.selectionHash, true);
  equal(c.selection.selectionHash, currentAuthorityPreservationInventoryV1SelectionHash(a, c.selection.origin, c.selection.completion), "Original authority selection hash");
  equal([c.selection.origin.environment.chainId, c.selection.origin.environment.core], [d.chainId, d.targets[0]], "Selected origin coordinates");
  equal(c.dependencies, currentAuthorityPreservationInventoryV1CaptureDependencies(d, c.selection), "Only original Artist dependency projection may change");
  return c;
}
export function validateCurrentAuthorityPreservationInventoryV1Origin(
  chainId: bigint,
  value: CurrentAuthorityPreservationInventoryV1Origin,
): CurrentAuthorityPreservationInventoryV1Origin {
  const o = normalizeCurrentAuthorityPreservationInventoryV1Origin(value);
  if (o.environment.chainId !== uint(chainId)) throw Error("Original origin chain");
  for (const target of [o.environment.core, o.environment.manager, o.environment.registry, o.environment.coordinator, o.environment.archive, ...o.environment.owners]) address(target, true);
  for (const pin of [o.environment.suiteConfigurationHash, o.registryCodeHash, o.coordinatorCodeHash, o.archiveCodeHash, ...o.environment.ownerCodeHashes]) hash(pin, true);
  return o;
}
/** This is the source's conditional legacy Work branch, not a signature or receipt verifier. */
export function validateCurrentAuthorityPreservationInventoryV1WorkActor(
  actor: Address, attestationRecordHash: Hex, receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness,
): Address {
  const a = address(actor);
  const r = normalizeCurrentAuthorityPreservationInventoryV1ReceiptWitness(receipt);
  if (hash(attestationRecordHash) === ZeroHash) {
    if (a !== ZeroAddress || r.lane !== 0n || r.index !== 0n) throw Error("Legacy Work requires zero actor and native zero locator");
  } else address(a, true);
  return a;
}
export function validateCurrentAuthorityPreservationInventoryV1Payload(value: CurrentAuthorityPreservationInventoryV1Payload): CurrentAuthorityPreservationInventoryV1Payload {
  const p = normalizeCurrentAuthorityPreservationInventoryV1Payload(value);
  address(p.producer, true);
  if (p.tokenId === 0n || p.animation === "0x" || (p.image.length - 2) / 2 > 2048 || (p.animation.length - 2) / 2 > 40960) throw Error("Original inventory image/HTML bounds");
  return p;
}
export function validateCurrentAuthorityPreservationInventoryV1RecordOrigin(
  sourceContextHash: Hex, item: CurrentAuthorityPreservationInventoryV1Item,
  original: CurrentAuthorityPreservationInventoryV1RecordOrigin, expectedReceipt: Hex, actor: Address, role: Hex,
): CurrentAuthorityPreservationInventoryV1RecordOrigin {
  const r = normalizeCurrentAuthorityPreservationInventoryV1RecordOrigin(original);
  const row = normalizeCurrentAuthorityPreservationInventoryV1Item(item);
  const context = hash(sourceContextHash, true), a = address(actor, true), receipt = hash(expectedReceipt), expectedRole = hash(role);
  hash(r.semanticRecordHash, true);
  hash(r.occurrence.receipt.recordHash, true);
  hash(row.provenanceHash, true);
  equal([r.sourceContextHash, r.actor, r.role, r.occurrence.position.point.environmentHash],
    [context, a, expectedRole, currentAuthorityPreservationInventoryV1OriginEnvironmentHash(r.producer.environment)], "Original record origin context");
  if (receipt !== ZeroHash && r.occurrence.receipt.recordHash !== receipt) throw Error("Original receipt locator mismatch");
  // STATE_BUNDLE is the original enum value 6; no new origin or signature authority is derived.
  equal([row.kind, row.role, row.source, row.sourceRecord, row.sourceIndex],
    [6n, expectedRole, r.producer.environment.archive, currentAuthorityPreservationInventoryV1EvidenceId(r), 1n], "Original state bundle origin");
  return r;
}

export interface CurrentAuthorityPreservationInventoryV1Definition {
  readonly index: bigint;
  readonly id: Hex;
  readonly hash: Hex;
  readonly byteLength: bigint;
}

const COLLECTION_DEFINITIONS: readonly CurrentAuthorityPreservationInventoryV1Definition[] = Object.freeze([
  Object.freeze({ index: 0n, id: "0x5bb3543c4c007f4396474b74ec81dd8bca13028b6d945020e4b48ff236b26a3c" as Hex, hash: "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88" as Hex, byteLength: 11481n }),
  Object.freeze({ index: 1n, id: "0x5cbe99f46b06fb16351501c9c1c69f98912cf8534a5ee647d0312ef1de7ebaa0" as Hex, hash: "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353" as Hex, byteLength: 2350n }),
  Object.freeze({ index: 2n, id: "0x613d837a313512b0f404a66b152b282d5f309c97bf3d6c4dc98aff573a3fa4cc" as Hex, hash: "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed" as Hex, byteLength: 1720n }),
  Object.freeze({ index: 3n, id: "0x32861d4583bc08f7afbeb7e4e376e3d22dcfc5ebf25ac0e7c8c045c2cfacbbb9" as Hex, hash: "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514" as Hex, byteLength: 957n }),
  Object.freeze({ index: 4n, id: "0xdfdea1c86219c12e182b4023d399be35bd5602461ef1dc727784c18d7742b967" as Hex, hash: "0xccb6e9813b29689628095bd2eaaf2b62bdbdfd7e971d14784a9dc419688a33e8" as Hex, byteLength: 14613n }),
  Object.freeze({ index: 5n, id: "0x2d4a7482b51b8267e36531e068971cd09ccdcb230d5945f2899812bc57183120" as Hex, hash: "0x15df3f552f58b0a0e8ba75bc4679d6ef3c3c1034fd065646a518bb63edb27174" as Hex, byteLength: 1335n }),
  Object.freeze({ index: 6n, id: "0x2f2a18b3a8b160296c5ef1b1b3385dcaa88d07c066a663d8561771400e666802" as Hex, hash: "0x733ff58eb9521aedd7d74c0b53620306095720e5688cbe5b7d94228665f9a009" as Hex, byteLength: 10223n }),
  Object.freeze({ index: 7n, id: "0xc1faa012c451d83b645154b1d5c6bedd3123e2f2fe8c49807501f32f1747e458" as Hex, hash: "0x1522f0f9498ac4a0f652ff201b0681a3711234a15189713cf5e71f71ba53c9c6" as Hex, byteLength: 3814n }),
  Object.freeze({ index: 8n, id: "0x9e029e12429716112002c57124a77e9da820c0baaef00eb3ca5298afb24c0130" as Hex, hash: "0xbd017f973eb0c21bc4c1e57bebafd7e48774e8dc91b2424a14597b96a5edfc93" as Hex, byteLength: 4927n }),
  Object.freeze({ index: 9n, id: "0x3f91b8592bb904265b23cb522d0f799dc098cfd0eef0fdee7cdaa4ae977ce388" as Hex, hash: "0xdce44685b162b745cde2e4611d571612c3dc40ab890bedc73436bcd2408f41e1" as Hex, byteLength: 3828n }),
  Object.freeze({ index: 10n, id: "0x12d539ad0aa5da43e241ab876b93cd215e2f2fa9be43f4c6ad3e49a109a45273" as Hex, hash: "0x826e7082f5ddcdb972c22411bca7adfd71b7feac7980eaabeb5dc5ec79eb3963" as Hex, byteLength: 11052n }),
  Object.freeze({ index: 11n, id: "0xe3bda9449d86cbbc77bcd7db0558cfc5e1b0d89c2d922af24b196649df20c7ac" as Hex, hash: "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf" as Hex, byteLength: 3820n }),
  Object.freeze({ index: 12n, id: "0xdf4e0a436dfb61d24da9e0af8fd645c99bc907d3ea94e3e34df97db4dd61a177" as Hex, hash: "0xb751512d8420de5e72907298460560aa25e274617b9ff25607bf80f1ffa982df" as Hex, byteLength: 2059n }),
  Object.freeze({ index: 13n, id: "0xf69254cd34854f7c450782b73e5736d7bf0f53418bb7e5e9452ce2267e36c2e6" as Hex, hash: "0x5e3712a9d1b640532be098b10855d013323bd7a852cf3b548dfff9babbdb7b3c" as Hex, byteLength: 3842n }),
  Object.freeze({ index: 14n, id: "0xd11f79240dccf3372049d888c61682678bf90a81444b0d3a44e4ba130026de5f" as Hex, hash: "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90" as Hex, byteLength: 2236n }),
  Object.freeze({ index: 15n, id: "0x2669cdd31c4be774315ad6502522200c9fdd24db4934ea7ec77e081547b10db9" as Hex, hash: "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489" as Hex, byteLength: 286n }),
  Object.freeze({ index: 16n, id: "0xc4346603cc517f600a467cc2184e5b94ad7eee5d1d16f8ac4e818770a27e926b" as Hex, hash: "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac" as Hex, byteLength: 351n }),
  Object.freeze({ index: 17n, id: "0x786032a9ce8e89de0e2f6074c852bee6e3800f5b726395590aca2b6256066adb" as Hex, hash: "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03" as Hex, byteLength: 422n }),
  Object.freeze({ index: 18n, id: "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044" as Hex, hash: "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9" as Hex, byteLength: 362n }),
  Object.freeze({ index: 19n, id: "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f" as Hex, hash: "0xcd8112d80b623f930f1df6570b5072d622f9a2aec52ae3cfbecad3f0b65c16e9" as Hex, byteLength: 78n }),
  Object.freeze({ index: 20n, id: "0x3d7b6038d001621290c2020855321b8860b3812732c877be8d2154238a3607b4" as Hex, hash: "0xc134c9c28e87f89ba1bfeb6b1fc2a8da0da95731ae51310f95ee1dd5f5c66df3" as Hex, byteLength: 15067n }),
  Object.freeze({ index: 21n, id: "0x76f26bff78c9b25498a1be4c453ba0fdd0fb13386e666562d5ec2997bc2bbae9" as Hex, hash: "0x35aa9ac3dc7dc9c84d70f1010b26856a2b9cb99090f07e4eeba19497ba0f5069" as Hex, byteLength: 1921n }),
  Object.freeze({ index: 22n, id: "0x5fb3237a99c12b6aef1031c7ee177f7d3f4ddd6a2c7fa0407129992c7696a119" as Hex, hash: "0x8b9344fea9019c2628f43b9fd09361a2fdcf4e59ae858aadba93493316d2e128" as Hex, byteLength: 917n }),
  Object.freeze({ index: 23n, id: "0x420baa0f79f27bf4ff82deef567d1fb5ea145a31afd7cebd95bdfc08fe6a63de" as Hex, hash: "0x015dc229364e4b3b82225ac96d9010c04d570a173dd011bc0db96e860b8d913a" as Hex, byteLength: 29589n }),
  Object.freeze({ index: 24n, id: "0xeafea71e1098b2447590fd588cd2b937a551cfe07f02bb28382a50a999457c7e" as Hex, hash: "0xe2263771b4e5178c556bf9e321f57d4a8b3844b9a2e7577f233720f6fc088bda" as Hex, byteLength: 2029n }),
  Object.freeze({ index: 25n, id: "0x7ee931bdf57f46b3a098c44048f124313345c6883559710da5004e801a5c98d0" as Hex, hash: "0xd2a02feba1926199b5a2b1bd736c0cb6d1f08a8024561d59db224a90c294800d" as Hex, byteLength: 1368n }),
  Object.freeze({ index: 26n, id: "0x92780b5ae914a69f937dd751a5f838cda0ea9e10958c2f82b4789e8a37e0da1c" as Hex, hash: "0xd1b193ece5f16680963db5c976ad49a1eba9682cdb12b549776513fa54bb4a39" as Hex, byteLength: 3298n }),
  Object.freeze({ index: 27n, id: "0x4ed8c2afbb8847f360588a117ea09300496c7f1bc83b6c94ce8eee614a2120f7" as Hex, hash: "0xa16dd3454e3d62faefba17d67c67668a1af003a7114e2491e060f31cea906415" as Hex, byteLength: 1686n }),
  Object.freeze({ index: 28n, id: "0x6a05714fa308bf1c37900091172b5087c27a25e995fb552fdfb57dd9cc424a3f" as Hex, hash: "0xcf38323a527bee9988381fa55c0159d7368b25d7851a06ad6e719095431827a7" as Hex, byteLength: 1072n }),
  Object.freeze({ index: 29n, id: "0x2b774d1e8325af4408a813af507a5cb945d49e8072f5fa92f316cd57d2b9a3ff" as Hex, hash: "0x2817e96bcceff5575257bff35581da3b18819d095f7febbdde3835998ba9928b" as Hex, byteLength: 3554n }),
  Object.freeze({ index: 30n, id: "0xdc7d9eebb863646a13852e2a7a8e4c8c2d403f2647e13888ace2e17161c3bd11" as Hex, hash: "0x2765335632781382541d5ef35c206008ea869752856d57daf3a1a66d5f983c95" as Hex, byteLength: 1610n }),
]);

const SCOPED_DEFINITIONS: readonly CurrentAuthorityPreservationInventoryV1Definition[] = Object.freeze([
  Object.freeze({ index: 0n, id: "0x5bb3543c4c007f4396474b74ec81dd8bca13028b6d945020e4b48ff236b26a3c" as Hex, hash: "0xc534a4212c652d620942266ff32d8699bcc40492aa9a323e0f5b711bbc5bba88" as Hex, byteLength: 11481n }),
  Object.freeze({ index: 1n, id: "0x5cbe99f46b06fb16351501c9c1c69f98912cf8534a5ee647d0312ef1de7ebaa0" as Hex, hash: "0x1c5e8281a5c12e06b334020bc158dc101dd33baaa449feeb8f504e20bd910353" as Hex, byteLength: 2350n }),
  Object.freeze({ index: 2n, id: "0x613d837a313512b0f404a66b152b282d5f309c97bf3d6c4dc98aff573a3fa4cc" as Hex, hash: "0xa2c03300254919dad0436cffd743bc869665f06434123b92ae48c5ff98a284ed" as Hex, byteLength: 1720n }),
  Object.freeze({ index: 3n, id: "0x32861d4583bc08f7afbeb7e4e376e3d22dcfc5ebf25ac0e7c8c045c2cfacbbb9" as Hex, hash: "0x03799bc44aab386d3032a5859e6e7b7f6558bdb279f0e9906d3af535274a6514" as Hex, byteLength: 957n }),
  Object.freeze({ index: 4n, id: "0xdfdea1c86219c12e182b4023d399be35bd5602461ef1dc727784c18d7742b967" as Hex, hash: "0xccb6e9813b29689628095bd2eaaf2b62bdbdfd7e971d14784a9dc419688a33e8" as Hex, byteLength: 14613n }),
  Object.freeze({ index: 5n, id: "0x2d4a7482b51b8267e36531e068971cd09ccdcb230d5945f2899812bc57183120" as Hex, hash: "0x15df3f552f58b0a0e8ba75bc4679d6ef3c3c1034fd065646a518bb63edb27174" as Hex, byteLength: 1335n }),
  Object.freeze({ index: 6n, id: "0x2f2a18b3a8b160296c5ef1b1b3385dcaa88d07c066a663d8561771400e666802" as Hex, hash: "0x733ff58eb9521aedd7d74c0b53620306095720e5688cbe5b7d94228665f9a009" as Hex, byteLength: 10223n }),
  Object.freeze({ index: 7n, id: "0xc1faa012c451d83b645154b1d5c6bedd3123e2f2fe8c49807501f32f1747e458" as Hex, hash: "0x1522f0f9498ac4a0f652ff201b0681a3711234a15189713cf5e71f71ba53c9c6" as Hex, byteLength: 3814n }),
  Object.freeze({ index: 8n, id: "0x9e029e12429716112002c57124a77e9da820c0baaef00eb3ca5298afb24c0130" as Hex, hash: "0xbd017f973eb0c21bc4c1e57bebafd7e48774e8dc91b2424a14597b96a5edfc93" as Hex, byteLength: 4927n }),
  Object.freeze({ index: 9n, id: "0x3f91b8592bb904265b23cb522d0f799dc098cfd0eef0fdee7cdaa4ae977ce388" as Hex, hash: "0xdce44685b162b745cde2e4611d571612c3dc40ab890bedc73436bcd2408f41e1" as Hex, byteLength: 3828n }),
  Object.freeze({ index: 10n, id: "0x12d539ad0aa5da43e241ab876b93cd215e2f2fa9be43f4c6ad3e49a109a45273" as Hex, hash: "0x826e7082f5ddcdb972c22411bca7adfd71b7feac7980eaabeb5dc5ec79eb3963" as Hex, byteLength: 11052n }),
  Object.freeze({ index: 11n, id: "0xe3bda9449d86cbbc77bcd7db0558cfc5e1b0d89c2d922af24b196649df20c7ac" as Hex, hash: "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf" as Hex, byteLength: 3820n }),
  Object.freeze({ index: 12n, id: "0xdf4e0a436dfb61d24da9e0af8fd645c99bc907d3ea94e3e34df97db4dd61a177" as Hex, hash: "0xb751512d8420de5e72907298460560aa25e274617b9ff25607bf80f1ffa982df" as Hex, byteLength: 2059n }),
  Object.freeze({ index: 13n, id: "0xf69254cd34854f7c450782b73e5736d7bf0f53418bb7e5e9452ce2267e36c2e6" as Hex, hash: "0x5e3712a9d1b640532be098b10855d013323bd7a852cf3b548dfff9babbdb7b3c" as Hex, byteLength: 3842n }),
  Object.freeze({ index: 14n, id: "0xd11f79240dccf3372049d888c61682678bf90a81444b0d3a44e4ba130026de5f" as Hex, hash: "0xe09ea65b22dccf9a9528b0ec4c940a831be48a060f0a095157a65aff5b290b90" as Hex, byteLength: 2236n }),
  Object.freeze({ index: 15n, id: "0x2669cdd31c4be774315ad6502522200c9fdd24db4934ea7ec77e081547b10db9" as Hex, hash: "0x06dacccbad9218d04f77cbfdd597dfa61e2cab5b58c0fb8f5a1344ce301cb489" as Hex, byteLength: 286n }),
  Object.freeze({ index: 16n, id: "0xc4346603cc517f600a467cc2184e5b94ad7eee5d1d16f8ac4e818770a27e926b" as Hex, hash: "0xb3cedd289be34a31fcd20d1941c86e28f31723e4c61f11ddf87894cda4903cac" as Hex, byteLength: 351n }),
  Object.freeze({ index: 17n, id: "0x786032a9ce8e89de0e2f6074c852bee6e3800f5b726395590aca2b6256066adb" as Hex, hash: "0x91a426d25d6e00c056cea336611731171bfe84e1b90bf10f7e2e0d0edc6d8c03" as Hex, byteLength: 422n }),
  Object.freeze({ index: 18n, id: "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044" as Hex, hash: "0xbc33af15c6b6374052871a5fdfa255f900f56fa594f650b2d0814c681fdb35a9" as Hex, byteLength: 362n }),
  Object.freeze({ index: 19n, id: "0x220c6deb539ee172cf673a6dd0935cb8f841290a9368519d83add4dbedf24d1f" as Hex, hash: "0xcd8112d80b623f930f1df6570b5072d622f9a2aec52ae3cfbecad3f0b65c16e9" as Hex, byteLength: 78n }),
  Object.freeze({ index: 20n, id: "0x663df8ecfe59f5a22a53b98f238a8a6bab2ec69e3a8e767db300aa62ba894aaa" as Hex, hash: "0xb0111a1674600a858335c07adaf8c14a0808cfc638051d3bced3a37c67e32b94" as Hex, byteLength: 4598n }),
  Object.freeze({ index: 21n, id: "0x767b53e013ddfa25400514e23aa2a9c754aa7cf3d53a6d966943c55bf705caf2" as Hex, hash: "0xb438e9370d61c069c5e04b0418158aaf372c9b5ce801a5bb7f16be09f4dadaa7" as Hex, byteLength: 2192n }),
  Object.freeze({ index: 22n, id: "0xf081f41dd01b5c90b8513c5b875b0f65f1b0a01b99c015776b4ec40741e18975" as Hex, hash: "0xc0b8953b0b6d7ac8c42511add2ef833facd3bb7a01dba83a10a82eba222252a5" as Hex, byteLength: 1009n }),
  Object.freeze({ index: 23n, id: "0x53ebde218f9e68e0431d3a8d6042a00115cc2c06309626b0b682791416b00387" as Hex, hash: "0xaa86ba8fd6a4a9d4eecbee301ee99cea49e9efdecf728f4d57d4a6a6cfc88727" as Hex, byteLength: 28358n }),
  Object.freeze({ index: 24n, id: "0x7a31f82ad9d35eb7c23cb436a8bddb43eaec81ea80fd458d95c7f55896d306b1" as Hex, hash: "0x19764e02e956ee4855d429fd13fa632392d97454b0807eb7a439686a20da6be5" as Hex, byteLength: 3250n }),
  Object.freeze({ index: 25n, id: "0xaef462e03af7e56dbbafe0cdfd4fb1f737bed63852f7e4588bb57403b36f70c3" as Hex, hash: "0xd2149a31cf326579ae91ad48f5cbe10d2721a77c0001082a1b2812fef2f25039" as Hex, byteLength: 2341n }),
  Object.freeze({ index: 26n, id: "0x92780b5ae914a69f937dd751a5f838cda0ea9e10958c2f82b4789e8a37e0da1c" as Hex, hash: "0xd1b193ece5f16680963db5c976ad49a1eba9682cdb12b549776513fa54bb4a39" as Hex, byteLength: 3298n }),
  Object.freeze({ index: 27n, id: "0x4ed8c2afbb8847f360588a117ea09300496c7f1bc83b6c94ce8eee614a2120f7" as Hex, hash: "0xa16dd3454e3d62faefba17d67c67668a1af003a7114e2491e060f31cea906415" as Hex, byteLength: 1686n }),
  Object.freeze({ index: 28n, id: "0x6a05714fa308bf1c37900091172b5087c27a25e995fb552fdfb57dd9cc424a3f" as Hex, hash: "0xcf38323a527bee9988381fa55c0159d7368b25d7851a06ad6e719095431827a7" as Hex, byteLength: 1072n }),
  Object.freeze({ index: 29n, id: "0x6f2c1cb10d9b5474ac7d0271dc53f0cecc9b183732c6d255c5742085214d3587" as Hex, hash: "0x613048a84803f3c00cd6df4016029d02bd1464d27192c9102d820d2da4524a51" as Hex, byteLength: 3688n }),
  Object.freeze({ index: 30n, id: "0x250331c8548c77a1c0844311f32dc7ac0be8dde33d04d4071b97229375cc6c60" as Hex, hash: "0x9a5b21a4397b2be60a25f467250ccb4a0b818d776819c48b24925e82eef2cc21" as Hex, byteLength: 1828n }),
]);

export function currentAuthorityPreservationInventoryV1Definition(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, index: bigint): CurrentAuthorityPreservationInventoryV1Definition {
  const i = uint(index, 64);
  if (i >= 31n) throw Error("Unknown inventory definition");
  return (kind(scopeKind) === "collection" ? COLLECTION_DEFINITIONS : SCOPED_DEFINITIONS)[Number(i)]!;
}
export function currentAuthorityPreservationInventoryV1Definitions(scopeKind: CurrentAuthorityPreservationInventoryV1Kind): readonly CurrentAuthorityPreservationInventoryV1Definition[] {
  return kind(scopeKind) === "collection" ? COLLECTION_DEFINITIONS : SCOPED_DEFINITIONS;
}

function progressOf(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, plan: CurrentAuthorityPreservationInventoryV1Plan): CurrentAuthorityPreservationInventoryV1Progress {
  const p = normalizeCurrentAuthorityPreservationInventoryV1Plan(scopeKind, plan);
  return kind(scopeKind) === "collection" ? p as CurrentAuthorityPreservationInventoryV1CollectionPlan
    : (p as CurrentAuthorityPreservationInventoryV1ScopedPlan).progress;
}
/** Available immutable joins only. Original source workers remain the full admission authority. */
export function validateCurrentAuthorityPreservationInventoryV1Context(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates,
  value: CurrentAuthorityPreservationInventoryV1Context,
): CurrentAuthorityPreservationInventoryV1Context {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const result = normalizeCurrentAuthorityPreservationInventoryV1Context(c.scopeKind, value);
  const v = result as CurrentAuthorityPreservationInventoryV1ScopedContext;
  const collection = result as CurrentAuthorityPreservationInventoryV1CollectionContext;
  const common = c.scopeKind === "collection" ? collection.records : v;
  const source = c.scopeKind === "collection" ? collection.source : v.snapshotSource;
  const scope: CurrentAuthorityPreservationInventoryV1Scope = c.scopeKind === "collection"
    ? { scopeType: 0n, collectionId: collection.records.collectionId, tokenId: 0n, scopeId: ZeroHash as Hex } : v.scope;
  output.validateTokenPreservationOutputV2Scope(c.scopeKind, scope);
  const subject = snapshot.tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, scope);
  equal([common.subject, result.snapshot.scopeSubject, result.referenceRender.scopeSubject, source.membership.scopeSubject, common.descriptions.scopeSubject],
    [subject, subject, subject, subject, subject], "Inventory full-scope subject joins");
  equal([result.referenceRender.observation.collectionId, result.referenceRender.observation.snapshotRecordHash, result.referenceRender.observation.snapshotRevision],
    [scope.collectionId, result.snapshot.recordHash, result.snapshot.revision], "Inventory original snapshot/reference pair");
  equal([source.content.preservationProfile, source.outputs.preservationProfile],
    [CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_FAMILY, CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_FAMILY], "Closed token preservation family");
  equal([source.selection.scope, source.content.scope, source.outputs.scope], [scope, scope, scope], "Inventory retained full scope");
  equal(source.scope, scope, "Inventory source full scope");
  equal([common.artistId, source.artist.artistId, common.conservation.association.artistId],
    [source.artist.artistId, source.artist.artistId, source.artist.artistId], "Inventory Artist identity");
  equal([source.artist.bindingGeneration, source.artist.bindingHash, source.artist.identityRecordHash],
    [common.conservation.association.generation, common.conservation.association.bindingHash, common.conservation.association.identityRecordHash], "Original presentation association");
  hash(common.artistId, true);
  if (common.tokenCount === 0n) throw Error("Empty inventory source");
  equal([source.membership.tokenCount, source.content.tokenCount, source.outputs.tokenCount, source.selection.tokenCount],
    [common.tokenCount, common.tokenCount, common.tokenCount, common.tokenCount], "Inventory token counts");
  const sourceBytes = c.scopeKind === "collection"
    ? snapshot.encodeTokenPreservationSnapshotV2CollectionSource(source as snapshot.TokenPreservationSnapshotV2CollectionSource)
    : snapshot.encodeTokenPreservationSnapshotV2ScopedSource(source as snapshot.TokenPreservationSnapshotV2ScopedSource);
  equal([common.nativeHash, common.tokenInventoryHash, common.checkpointHash],
    [keccak256(sourceBytes), c.scopeKind === "collection" ? source.content.inventoryHash : source.membership.membershipHash, source.outputs.checkpointHash], "Inventory original source commitments");
  if (c.scopeKind === "scoped") {
    hash(v.outputManifestRecord, true);
    equal([v.selectionId, v.selectionHash],
      [source.content.selectionId, source.content.selectionHash], "Scoped inventory selection");
  } else {
    equal(collection.referenceSourceHash, collection.referenceRender.observation.sourcesHash, "Collection reference source hash");
    // Collection preservation sources deliberately leave both legacy receipt slots zero.
    const zero = (x: unknown): boolean => typeof x === "bigint" ? x === 0n : typeof x === "boolean" ? !x
      : typeof x === "string" ? /^0x0*$/.test(x) : !!x && typeof x === "object" && Object.values(x).every(zero);
    if (!zero(collection.records.snapshot) || !zero(collection.records.referenceRender)) throw Error("Legacy receipt slots must remain zero");
  }
  return result;
}
/** Exact original evidence projection from captured context/progress, without live source reads. */
export function currentAuthorityPreservationInventoryV1Evidence(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates, planId: Hex,
  context: CurrentAuthorityPreservationInventoryV1Context, plan: CurrentAuthorityPreservationInventoryV1Plan,
): CurrentAuthorityPreservationInventoryV1Evidence {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const ctx = normalizeCurrentAuthorityPreservationInventoryV1Context(c.scopeKind, context);
  const common = c.scopeKind === "collection" ? (ctx as CurrentAuthorityPreservationInventoryV1CollectionContext).records
    : ctx as CurrentAuthorityPreservationInventoryV1ScopedContext;
  const p = progressOf(c.scopeKind, plan);
  const scope = c.scopeKind === "collection" ? undefined : (ctx as CurrentAuthorityPreservationInventoryV1ScopedContext).scope;
  const e: CurrentAuthorityPreservationInventoryV1CollectionEvidence = {
    planId: hash(planId), collectionId: scope?.collectionId ?? (common as CurrentAuthorityPreservationInventoryV1CollectionContext["records"]).collectionId,
    scopeSubject: common.subject, artistId: common.artistId,
    originals: { rootRecordHash: common.rootRecordHash, snapshotRecordHash: ctx.snapshot.recordHash,
      referenceRenderRecordHash: ctx.referenceRender.observation.recordHash,
      intentRecordHash: common.conservation.record.kind === 1n ? common.conservation.record.recordHash : ZeroHash as Hex,
      intentWaiverRecordHash: common.conservation.record.kind === 2n ? common.conservation.record.recordHash : ZeroHash as Hex,
      interviewEvidenceHash: common.interviewEvidenceHash, rightsStatementRecordHash: common.descriptions.rightsStatementRecordHash,
      workDescriptionRecordHash: common.descriptions.workDescriptionRecordHash },
    sourceContextHash: p.sourceContextHash, tokenInventoryHash: common.tokenInventoryHash, tokenCount: common.tokenCount,
    segmentCount: p.segmentCount, itemCount: p.itemCount, segmentChainHash: p.segmentChainHash, renderCriticalEvidenceHash: ZeroHash as Hex,
  };
  return normalizeCurrentAuthorityPreservationInventoryV1Evidence(c.scopeKind, scope ? { scope, inventory: e } : e);
}
export function validateCurrentAuthorityPreservationInventoryV1Evidence(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates, dependencyHash: Hex, selectionHash: Hex,
  value: CurrentAuthorityPreservationInventoryV1Evidence, originRoot: Hex, originCount: bigint,
): CurrentAuthorityPreservationInventoryV1Evidence {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const e = normalizeCurrentAuthorityPreservationInventoryV1Evidence(c.scopeKind, value);
  const original = c.scopeKind === "collection" ? e as CurrentAuthorityPreservationInventoryV1CollectionEvidence : (e as CurrentAuthorityPreservationInventoryV1ScopedEvidence).inventory;
  const scope: CurrentAuthorityPreservationInventoryV1Scope = c.scopeKind === "collection" ? { scopeType: 0n, collectionId: original.collectionId, tokenId: 0n, scopeId: ZeroHash as Hex }
    : (e as CurrentAuthorityPreservationInventoryV1ScopedEvidence).scope;
  output.validateTokenPreservationOutputV2Scope(c.scopeKind, scope);
  equal([original.collectionId, original.scopeSubject], [scope.collectionId, snapshot.tokenPreservationSnapshotV2ScopeSubject(c.chainId, c.core, scope)], "Evidence full scope");
  for (const x of [original.planId, original.sourceContextHash, original.tokenInventoryHash, original.segmentChainHash, selectionHash, originRoot]) hash(x, true);
  if (original.tokenCount === 0n || original.segmentCount === 0n || originCount === 0n || originCount > 17n) throw Error("Incomplete inventory evidence");
  equal(original.renderCriticalEvidenceHash, currentAuthorityPreservationInventoryV1EvidenceHash(c, dependencyHash, selectionHash, e, originRoot, originCount), "Inventory evidence hash");
  return e;
}

type CommonRequest =
  | { readonly kind: "appendWork"; readonly planId: Hex; readonly witness: CurrentAuthorityPreservationInventoryV1Work; readonly originalActor: Address; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness }
  | { readonly kind: "appendRights"; readonly planId: Hex; readonly witness: CurrentAuthorityPreservationInventoryV1Rights }
  | { readonly kind: "appendIntent"; readonly planId: Hex; readonly witness: CurrentAuthorityPreservationInventoryV1Intent; readonly originalActor: Address; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness }
  | { readonly kind: "appendIntentWaiver"; readonly planId: Hex; readonly witness: CurrentAuthorityPreservationInventoryV1IntentWaiver; readonly originalActor: Address; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness }
  | { readonly kind: "appendInterview"; readonly planId: Hex; readonly witness: CurrentAuthorityPreservationInventoryV1Interview; readonly originalActor: Address; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness }
  | { readonly kind: "appendInterviewWaiver" | "appendDefinition" | "appendTokenPreservation" | "appendOriginRuntime" | "sealInventory"; readonly planId: Hex };
export type CurrentAuthorityPreservationInventoryV1CollectionRequest = CommonRequest
  | { readonly kind: "beginInventory"; readonly collectionId: bigint }
  | { readonly kind: "appendNative" | "appendReference" | "appendScript" | "appendLibrary" | "appendRenderer" | "appendCurrentProfile"; readonly planId: Hex }
  | { readonly kind: "appendToken"; readonly planId: Hex; readonly payload: CurrentAuthorityPreservationInventoryV1Payload }
  | { readonly kind: "appendRootAuthorization"; readonly planId: Hex; readonly originalActor: Address; readonly observedAt: bigint; readonly aggregate: CurrentAuthorityPreservationInventoryV1Aggregate; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness };
export type CurrentAuthorityPreservationInventoryV1ScopedRequest = CommonRequest
  | { readonly kind: "beginInventory"; readonly scope: CurrentAuthorityPreservationInventoryV1Scope }
  | { readonly kind: "appendNative" | "appendReference"; readonly planId: Hex; readonly maxChunks: bigint }
  | { readonly kind: "appendTokenScript" | "appendTokenLibrary" | "appendTokenRenderer" | "appendTokenCitation"; readonly planId: Hex }
  | { readonly kind: "appendTokenOutput"; readonly planId: Hex; readonly payload: CurrentAuthorityPreservationInventoryV1Payload }
  | { readonly kind: "appendRootAuthorization"; readonly planId: Hex; readonly originalActor: Address; readonly observedAt: bigint; readonly aggregate: CurrentAuthorityPreservationInventoryV1Aggregate; readonly originalLegacyFamilyHash: Hex; readonly receipt: CurrentAuthorityPreservationInventoryV1ReceiptWitness };
export type CurrentAuthorityPreservationInventoryV1Request = CurrentAuthorityPreservationInventoryV1CollectionRequest | CurrentAuthorityPreservationInventoryV1ScopedRequest;
export interface CurrentAuthorityPreservationInventoryV1Call {
  readonly coordinates: CurrentAuthorityPreservationInventoryV1Coordinates;
  readonly caller: Address;
  readonly request: CurrentAuthorityPreservationInventoryV1Request;
  readonly call: UnsignedCall;
}
function requestArgs(scopeKind: CurrentAuthorityPreservationInventoryV1Kind, value: CurrentAuthorityPreservationInventoryV1Request): readonly unknown[] {
  const r = value as unknown as Record<string, unknown>;
  const name = r.kind;
  if (name === "beginInventory") return [scopeKind === "collection" ? r.collectionId : r.scope];
  if (name === "appendRootAuthorization") return [r.planId, r.originalActor, r.observedAt, r.aggregate,
    ...(scopeKind === "scoped" ? [r.originalLegacyFamilyHash] : []), r.receipt];
  if (["appendWork", "appendIntent", "appendIntentWaiver", "appendInterview"].includes(String(name))) return [r.planId, r.witness, r.originalActor, r.receipt];
  if (name === "appendRights") return [r.planId, r.witness];
  if (name === "appendToken" || name === "appendTokenOutput") return [r.planId, r.payload];
  if ((name === "appendNative" || name === "appendReference") && scopeKind === "scoped") return [r.planId, r.maxChunks];
  return [r.planId];
}
export function normalizeCurrentAuthorityPreservationInventoryV1Request(
  scopeKind: CurrentAuthorityPreservationInventoryV1Kind,
  value: CurrentAuthorityPreservationInventoryV1Request,
): CurrentAuthorityPreservationInventoryV1Request {
  kind(scopeKind);
  if (!value || typeof value !== "object") throw Error("Invalid inventory request");
  const r = value as unknown as Record<string, unknown>;
  const result: Record<string, unknown> = { kind: r.kind };
  if (r.kind === "beginInventory") {
    exact(r, ["kind", scopeKind === "collection" ? "collectionId" : "scope"]);
    if (scopeKind === "collection") {
      result.collectionId = uint(r.collectionId);
      if (result.collectionId === 0n) throw Error("Zero collection");
    } else result.scope = output.validateTokenPreservationOutputV2Scope("scoped", r.scope as CurrentAuthorityPreservationInventoryV1Scope);
  } else {
    result.planId = hash(r.planId, true);
    let keys = ["kind", "planId"];
    if (["appendWork", "appendRights", "appendIntent", "appendIntentWaiver", "appendInterview"].includes(String(r.kind))) {
      keys.push("witness");
      const tuple = r.kind === "appendWork" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_WORK_TUPLE
        : r.kind === "appendRights" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_RIGHTS_TUPLE
          : r.kind === "appendIntent" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_TUPLE
            : r.kind === "appendIntentWaiver" ? CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTENT_WAIVER_TUPLE : CURRENT_AUTHORITY_PRESERVATION_INVENTORY_V1_INTERVIEW_TUPLE;
      result.witness = normalized(tuple, r.witness);
      if (r.kind !== "appendRights") {
        keys.push("originalActor", "receipt");
        result.originalActor = address(r.originalActor, r.kind !== "appendWork");
        result.receipt = normalizeCurrentAuthorityPreservationInventoryV1ReceiptWitness(r.receipt as CurrentAuthorityPreservationInventoryV1ReceiptWitness);
      }
    } else if (r.kind === "appendRootAuthorization") {
      keys.push("originalActor", "observedAt", "aggregate", "receipt");
      result.originalActor = address(r.originalActor, true);
      result.observedAt = uint(r.observedAt, 64);
      result.aggregate = normalizeCurrentAuthorityPreservationInventoryV1Aggregate(r.aggregate as CurrentAuthorityPreservationInventoryV1Aggregate);
      result.receipt = normalizeCurrentAuthorityPreservationInventoryV1ReceiptWitness(r.receipt as CurrentAuthorityPreservationInventoryV1ReceiptWitness);
      if (scopeKind === "scoped") {
        keys.push("originalLegacyFamilyHash");
        result.originalLegacyFamilyHash = hash(r.originalLegacyFamilyHash);
      }
    } else if (r.kind === (scopeKind === "collection" ? "appendToken" : "appendTokenOutput")) {
      keys.push("payload");
      result.payload = validateCurrentAuthorityPreservationInventoryV1Payload(r.payload as CurrentAuthorityPreservationInventoryV1Payload);
    } else if (r.kind === "appendNative" || r.kind === "appendReference") {
      if (scopeKind === "scoped") {
        keys.push("maxChunks");
        result.maxChunks = uint(r.maxChunks, 64);
        if (result.maxChunks === 0n || (result.maxChunks as bigint) > 64n) throw Error("Original inventory chunk batch 1..64");
      }
    } else {
      const methods = ["appendInterviewWaiver", "appendDefinition", "appendTokenPreservation", "appendOriginRuntime", "sealInventory",
        ...(scopeKind === "collection" ? ["appendScript", "appendLibrary", "appendRenderer", "appendCurrentProfile"]
          : ["appendTokenScript", "appendTokenLibrary", "appendTokenRenderer", "appendTokenCitation"])];
      if (!methods.includes(String(r.kind))) throw Error("Unsupported inventory write");
    }
    exact(r, keys);
  }
  return Object.freeze(result) as unknown as CurrentAuthorityPreservationInventoryV1Request;
}
/** Permissionless materialization only: no Artist signature, origin admission or finality is established. */
export function prepareCurrentAuthorityPreservationInventoryV1Call(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates,
  caller: Address,
  request: CurrentAuthorityPreservationInventoryV1Request,
): CurrentAuthorityPreservationInventoryV1Call {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  const r = normalizeCurrentAuthorityPreservationInventoryV1Request(c.scopeKind, request);
  const data = bytes(currentAuthorityPreservationInventoryV1Interface(c.scopeKind).encodeFunctionData(r.kind, requestArgs(c.scopeKind, r)));
  return Object.freeze({ coordinates: c, caller: address(caller, true), request: r,
    call: Object.freeze({ to: c.inventory, data, value: 0n }) });
}
export function normalizeCurrentAuthorityPreservationInventoryV1Call(value: CurrentAuthorityPreservationInventoryV1Call): CurrentAuthorityPreservationInventoryV1Call {
  exact(value, ["coordinates", "caller", "request", "call"]);
  exact(value.call, ["to", "data", "value"]);
  const rebuilt = prepareCurrentAuthorityPreservationInventoryV1Call(value.coordinates, value.caller, value.request);
  equal([address(value.call.to), bytes(value.call.data), uint(value.call.value)], [rebuilt.call.to, rebuilt.call.data, 0n], "Original inventory call mismatch");
  return rebuilt;
}
/** Progress guards omit all live source/authority/document checks performed by the genuine hosts. */
export function validateCurrentAuthorityPreservationInventoryV1Stage(
  scopeKind: CurrentAuthorityPreservationInventoryV1Kind,
  request: CurrentAuthorityPreservationInventoryV1Request,
  plan: CurrentAuthorityPreservationInventoryV1Plan,
  tokenProgress: CurrentAuthorityPreservationInventoryV1TokenProgress,
  originCount: bigint = 0n,
  originRuntimeCursor: bigint = 0n,
): void {
  const r = normalizeCurrentAuthorityPreservationInventoryV1Request(scopeKind, request);
  const p = progressOf(scopeKind, plan), t = normalizeCurrentAuthorityPreservationInventoryV1TokenProgress(tokenProgress);
  if (r.kind === "beginInventory") return; // Existing begin retries still re-read genuine sources.
  const stages: Readonly<Record<string, bigint>> = { appendNative: 0n, appendReference: 1n, appendWork: 2n, appendRights: 3n,
    appendIntent: 4n, appendIntentWaiver: 4n, appendInterview: 5n, appendInterviewWaiver: 5n, appendRootAuthorization: 6n, appendDefinition: 7n };
  const expected = stages[r.kind] ?? 8n;
  if (p.collectionId === 0n || p.completedStages !== expected || p.renderCriticalEvidenceHash !== ZeroHash) throw Error("Original inventory stage incomplete");
  if (expected !== 8n) return;
  if (r.kind === "appendOriginRuntime" || r.kind === "sealInventory") {
    if (p.nextToken !== p.tokenCount || t.phase !== 0n || t.row !== 0n || t.count !== 0n) throw Error("Original token stages incomplete");
    const count = uint(originCount), cursor = uint(originRuntimeCursor);
    if (count === 0n || count > 17n || (r.kind === "appendOriginRuntime" ? cursor >= count : cursor !== count)) throw Error("Original origin runtime stage incomplete");
    return;
  }
  const phase: Readonly<Record<string, bigint>> = { appendToken: 0n, appendTokenOutput: 0n, appendScript: 1n, appendTokenScript: 1n,
    appendLibrary: 2n, appendTokenLibrary: 2n, appendRenderer: 3n, appendTokenRenderer: 3n, appendCurrentProfile: 4n,
    appendTokenCitation: 4n, appendTokenPreservation: 5n };
  if (p.nextToken >= p.tokenCount || t.phase !== phase[r.kind]) throw Error("Original token phase incomplete");
}

export type CurrentAuthorityPreservationInventoryV1ReadRequest =
  | { readonly kind: "core" | "metadataHost" | "metadataRouter" | "snapshots" | "referencePublisher" | "artifactCoverage" | "externalCoverage" | "dependencies" | "dependencyHash" | "originalAnchor" | "originDependencies" | "authorityDependencies" | "originProfile" | "preservationPolicyInventoryProfile" | "scopedPreservationPolicyInventoryProfile" | "deploymentChainId" | "coreCodeHash" | "metadataCodeHash" }
  | { readonly kind: "supportsInterface"; readonly interfaceId: Hex }
  | { readonly kind: "plan" | "tokenProgress" | "sourceContext" | "inventoryEvidence" | "authoritySelection" | "originCount" | "originRuntimeCursor" | "originSetHash" | "requireFullDefinitionBytes"; readonly planId: Hex }
  | { readonly kind: "inventorySegment" | "originAt"; readonly planId: Hex; readonly index: bigint }
  | { readonly kind: "artistArchiveOrigin"; readonly planId: Hex; readonly itemHash: Hex }
  | { readonly kind: "requireCurrent"; readonly scope: CurrentAuthorityPreservationInventoryV1Scope };
export interface CurrentAuthorityPreservationInventoryV1Read {
  readonly coordinates: CurrentAuthorityPreservationInventoryV1Coordinates;
  readonly request: CurrentAuthorityPreservationInventoryV1ReadRequest;
  readonly call: UnsignedCall;
  readonly requiresCurrentSources: boolean;
}
export function prepareCurrentAuthorityPreservationInventoryV1Read(
  coordinates: CurrentAuthorityPreservationInventoryV1Coordinates,
  request: CurrentAuthorityPreservationInventoryV1ReadRequest,
): CurrentAuthorityPreservationInventoryV1Read {
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(coordinates);
  if (!request || typeof request !== "object") throw Error("Invalid inventory read");
  const input = request as unknown as Record<string, unknown>;
  const r: Record<string, unknown> = { kind: input.kind };
  let args: readonly unknown[] = [];
  const zero = ["core", "metadataHost", "metadataRouter", "snapshots", "referencePublisher", "artifactCoverage", "externalCoverage",
    "dependencies", "dependencyHash", "originalAnchor", "originDependencies", "authorityDependencies", "originProfile",
    ...(c.scopeKind === "collection" ? ["preservationPolicyInventoryProfile", "deploymentChainId", "coreCodeHash", "metadataCodeHash"] : ["scopedPreservationPolicyInventoryProfile"])];
  if (zero.includes(String(input.kind))) exact(input, ["kind"]);
  else if (input.kind === "supportsInterface") {
    exact(input, ["kind", "interfaceId"]);
    r.interfaceId = bytes(input.interfaceId, 4);
    args = [r.interfaceId];
  } else if (input.kind === "requireCurrent") {
    exact(input, ["kind", "scope"]);
    r.scope = output.validateTokenPreservationOutputV2Scope(c.scopeKind, input.scope as CurrentAuthorityPreservationInventoryV1Scope);
    args = [c.scopeKind === "collection" ? (r.scope as CurrentAuthorityPreservationInventoryV1Scope).collectionId : r.scope];
  } else {
    const names = ["plan", "tokenProgress", "sourceContext", "inventoryEvidence", "authoritySelection", "originCount", "originRuntimeCursor", "originSetHash", "requireFullDefinitionBytes", "inventorySegment", "originAt", "artistArchiveOrigin"];
    if (!names.includes(String(input.kind))) throw Error("Unsupported inventory read");
    const extra = input.kind === "inventorySegment" || input.kind === "originAt" ? "index" : input.kind === "artistArchiveOrigin" ? "itemHash" : undefined;
    exact(input, ["kind", "planId", ...(extra ? [extra] : [])]);
    r.planId = hash(input.planId);
    if (extra === "index") r.index = uint(input.index, input.kind === "inventorySegment" ? 64 : 256);
    if (extra === "itemHash") r.itemHash = hash(input.itemHash);
    args = [r.planId, ...(extra ? [r[extra]] : [])];
  }
  const data = bytes(currentAuthorityPreservationInventoryV1Interface(c.scopeKind).encodeFunctionData(String(input.kind), args));
  return Object.freeze({ coordinates: c, request: Object.freeze(r) as unknown as CurrentAuthorityPreservationInventoryV1ReadRequest,
    call: Object.freeze({ to: c.inventory, data, value: 0n }),
    requiresCurrentSources: input.kind === "requireCurrent" || input.kind === "requireFullDefinitionBytes" });
}
export function normalizeCurrentAuthorityPreservationInventoryV1Read(value: CurrentAuthorityPreservationInventoryV1Read): CurrentAuthorityPreservationInventoryV1Read {
  exact(value, ["coordinates", "request", "call", "requiresCurrentSources"]);
  exact(value.call, ["to", "data", "value"]);
  const rebuilt = prepareCurrentAuthorityPreservationInventoryV1Read(value.coordinates, value.request);
  equal([address(value.call.to), bytes(value.call.data), uint(value.call.value), value.requiresCurrentSources],
    [rebuilt.call.to, rebuilt.call.data, 0n, rebuilt.requiresCurrentSources], "Original inventory read mismatch");
  return rebuilt;
}

export interface CurrentAuthorityPreservationInventoryV1HistoryInput {
  readonly coordinates: CurrentAuthorityPreservationInventoryV1Coordinates;
  readonly dependencies: CurrentAuthorityPreservationInventoryV1Dependencies;
  readonly originDependencies: CurrentAuthorityPreservationInventoryV1OriginDependencies;
  readonly authorityDependencies: CurrentAuthorityPreservationInventoryV1AuthorityDependencies;
  readonly authorityAnchors: CurrentAuthorityPreservationInventoryV1AuthorityAnchors;
  readonly capture: CurrentAuthorityPreservationInventoryV1Capture;
  readonly context: CurrentAuthorityPreservationInventoryV1Context;
  readonly lineageHash: Hex;
  readonly plan: CurrentAuthorityPreservationInventoryV1Plan;
  readonly evidence: CurrentAuthorityPreservationInventoryV1Evidence;
  readonly origins: readonly CurrentAuthorityPreservationInventoryV1Origin[];
  readonly segments: readonly CurrentAuthorityPreservationInventoryV1Segment[];
}
/** Authenticate supplied local commitments. This does not establish RPC provenance, ancestry,
 * individual source-derived items, origin runtime segments, or present operative authority. */
export function authenticateCurrentAuthorityPreservationInventoryV1History(
  value: CurrentAuthorityPreservationInventoryV1HistoryInput,
): Readonly<{ planId: Hex; dependencyHash: Hex; sourceContextHash: Hex; originRoot: Hex; evidenceHash: Hex }> {
  exact(value, ["coordinates", "dependencies", "originDependencies", "authorityDependencies", "authorityAnchors", "capture", "context", "lineageHash", "plan", "evidence", "origins", "segments"]);
  const c = normalizeCurrentAuthorityPreservationInventoryV1Coordinates(value.coordinates);
  const d = validateCurrentAuthorityPreservationInventoryV1Dependencies(c, value.dependencies, value.originDependencies, value.authorityDependencies);
  const capture = validateCurrentAuthorityPreservationInventoryV1Capture(d, value.authorityAnchors, value.capture);
  const context = validateCurrentAuthorityPreservationInventoryV1Context(c, value.context);
  const origins = currentAuthorityPreservationInventoryV1Origins(value.origins);
  if (origins.length !== value.origins.length || origins.length === 0) throw Error("Invalid retained origin table");
  equal(origins[0], capture.selection.origin, "First admitted origin is captured authority");
  const source = c.scopeKind === "collection" ? (context as CurrentAuthorityPreservationInventoryV1CollectionContext).source
    : (context as CurrentAuthorityPreservationInventoryV1ScopedContext).snapshotSource;
  const common = c.scopeKind === "collection" ? (context as CurrentAuthorityPreservationInventoryV1CollectionContext).records
    : context as CurrentAuthorityPreservationInventoryV1ScopedContext;
  const cid = c.scopeKind === "collection" ? (context as CurrentAuthorityPreservationInventoryV1CollectionContext).records.collectionId
    : (context as CurrentAuthorityPreservationInventoryV1ScopedContext).scope.collectionId;
  const original = origins.find(o => o.environment.registry.toLowerCase() === source.artist.registry.toLowerCase()
    && o.registryCodeHash === source.artist.registryCodeHash);
  if (!original) throw Error("Missing original presentation origin");
  const initial = currentAuthorityPreservationInventoryV1Origins([capture.selection.origin, original]);
  equal(origins.slice(0, initial.length), initial, "Original origin admission order");
  const lineage = currentAuthorityPreservationInventoryV1LineageHash(capture.dependencies, cid, source.artist, common.conservation.association, capture.selection.origin, original);
  equal(hash(value.lineageHash), lineage, "Retained presentation lineage hash");
  const dependenciesHash = currentAuthorityPreservationInventoryV1DependencyHash(c.scopeKind, d, value.originDependencies, value.authorityDependencies);
  const sourceContextHash = currentAuthorityPreservationInventoryV1ContextHash(capture, currentAuthorityPreservationInventoryV1TypedContextHash(c.scopeKind, context), lineage);
  const planId = currentAuthorityPreservationInventoryV1PlanId(c, dependenciesHash, sourceContextHash);
  const plan = normalizeCurrentAuthorityPreservationInventoryV1Plan(c.scopeKind, value.plan), p = progressOf(c.scopeKind, plan);
  equal([p.collectionId, p.subject, p.artistId, p.sourceContextHash, p.tokenCount], [cid, common.subject, common.artistId, sourceContextHash, common.tokenCount], "Retained plan/context");
  if (p.completedStages !== 8n || p.nextToken !== p.tokenCount) throw Error("Unsealed retained plan");
  if (c.scopeKind === "scoped") equal((plan as CurrentAuthorityPreservationInventoryV1ScopedPlan).scope, (context as CurrentAuthorityPreservationInventoryV1ScopedContext).scope, "Retained plan scope");
  let chain = ZeroHash as Hex, items = 0n;
  const segments = dense(value.segments);
  for (let i = 0; i < segments.length; i++) {
    const segment = normalizeCurrentAuthorityPreservationInventoryV1Segment(segments[i] as CurrentAuthorityPreservationInventoryV1Segment);
    equal(segment.key, currentAuthorityPreservationInventoryV1SegmentKey(c.scopeKind, planId, BigInt(i)), "Retained segment key");
    chain = currentAuthorityPreservationInventoryV1AppendSegment(chain, BigInt(i), segment);
    items += segment.itemCount;
  }
  equal([p.segmentCount, p.itemCount, p.segmentChainHash], [BigInt(segments.length), items, chain], "Retained segment chain");
  const originRoot = currentAuthorityPreservationInventoryV1OriginSetHash(origins);
  const e = validateCurrentAuthorityPreservationInventoryV1Evidence(c, dependenciesHash, capture.selection.selectionHash, value.evidence, originRoot, BigInt(origins.length));
  const projected = currentAuthorityPreservationInventoryV1Evidence(c, planId, context, plan);
  const observed = c.scopeKind === "collection" ? e as CurrentAuthorityPreservationInventoryV1CollectionEvidence : (e as CurrentAuthorityPreservationInventoryV1ScopedEvidence).inventory;
  const expected = c.scopeKind === "collection" ? projected as CurrentAuthorityPreservationInventoryV1CollectionEvidence : (projected as CurrentAuthorityPreservationInventoryV1ScopedEvidence).inventory;
  equal({ ...observed, renderCriticalEvidenceHash: ZeroHash }, expected, "Retained evidence projection");
  equal(p.renderCriticalEvidenceHash, observed.renderCriticalEvidenceHash, "Retained plan seal");
  return Object.freeze({ planId, dependencyHash: dependenciesHash, sourceContextHash, originRoot, evidenceHash: observed.renderCriticalEvidenceHash });
}
