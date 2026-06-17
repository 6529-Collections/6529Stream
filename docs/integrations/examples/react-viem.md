# React/Viem Pseudocode Examples

These INT-007 examples are non-runnable pseudocode for a 6529.io-style
React/Next frontend. They show architecture shape only. They are not a
generated SDK, not a dependency recommendation, not maintained app code, not
production-ready, and not a security claim.

Use the main guide first:
[docs/integrations/frontend-reference-architecture.md](../frontend-reference-architecture.md).
For more concrete INT-013 TypeScript snippets around release artifact loading,
address book loading, release manifest hash validation, ABI checksum awareness,
deployment manifest checks, wrong-chain guards, and fail-closed chain config,
use
[docs/integrations/examples/typescript-artifacts-and-chain-config.md](typescript-artifacts-and-chain-config.md).
For concrete INT-014 TypeScript EIP-712 payload construction snippets covering
domain construction, `DropAuthorization` message shape, drop ID derivation,
token data hashing, sale-mode validation, signer boundaries, and submission
preflight, use
[docs/integrations/examples/typescript-eip712-drop-authorization.md](typescript-eip712-drop-authorization.md).
For concrete INT-015 TypeScript event decoding and indexer ingestion snippets
covering event topic catalog loading, `topic0` dispatch, normalized log
identity, confirmation depth, reorg rollback, read-after-event queue
construction, idempotent ingestion, and no-secret diagnostics, use
[docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md](typescript-event-decoding-and-indexer-ingestion.md).

## Artifact Loader

```ts
type StreamArtifacts = {
  chainId: number;
  releaseManifestHash: string;
  addressBook: AddressBook;
  deploymentManifest: DeploymentManifest;
  abiChecksums: AbiChecksumCatalog;
  eventTopics: EventTopicCatalog;
  interfaceIds: InterfaceIdCatalog;
};

export async function loadStreamArtifacts(env: PublicStreamEnv) {
  assertNoSecretsInPublicEnv(env);

  const releaseManifest = await fetchJson(env.releaseManifestUrl);
  const addressBook = await fetchJson(env.addressBookUrl);

  assertChainId(env.chainId, addressBook.network.chain_id);
  assertDeploymentVersion(env.deploymentVersion, addressBook.deployment_version);
  assertManifestDigest(releaseManifest, addressBook.source.deployment_manifest_sha256);

  return {
    chainId: env.chainId,
    releaseManifestHash: sha256(releaseManifest),
    addressBook,
    deploymentManifest: releaseManifest.deployment_artifacts.manifests,
    abiChecksums: releaseManifest.release_artifacts.abi_checksums,
    eventTopics: releaseManifest.release_artifacts.event_topic_catalog,
    interfaceIds: releaseManifest.release_artifacts.interface_ids,
  };
}
```

## Contract Clients

```ts
export function makeStreamClients(context: StreamArtifacts, transport: PublicTransport) {
  const publicClient = makePublicClient({
    chainId: context.chainId,
    transport,
  });

  return {
    core: makeContractClient({
      publicClient,
      address: requiredAddress(context.addressBook, "StreamCore"),
      abi: requiredAbi("StreamCore", context.abiChecksums),
    }),
    drops: makeContractClient({
      publicClient,
      address: requiredAddress(context.addressBook, "StreamDrops"),
      abi: requiredAbi("StreamDrops", context.abiChecksums),
    }),
    auctions: makeContractClient({
      publicClient,
      address: requiredAddress(context.addressBook, "StreamAuctions"),
      abi: requiredAbi("StreamAuctions", context.abiChecksums),
    }),
  };
}
```

## Query Keys

```ts
export const streamKeys = {
  contractRead: (chainId, address, functionName, args, blockTag) => [
    "contract-read",
    chainId,
    address,
    functionName,
    stableArgs(args),
    blockTag,
  ],
  metadata: (chainId, coreAddress, tokenId, metadataState, tokenURIHash) => [
    "metadata",
    chainId,
    activeDeploymentVersion,
    activeReleaseManifestHash,
    coreAddress,
    tokenId,
    metadataState,
    activeMetadataSchemaVersion,
    tokenURIHash,
  ],
  transaction: (chainId, transactionHash) => [
    "transaction",
    chainId,
    transactionHash,
  ],
};
```

## Transaction Orchestration

```ts
export async function submitAndConfirm(action: StreamActionContext) {
  assertChainId(action.expectedChainId, action.wallet.chainId);
  assertReleaseManifest(action.releaseManifestHash);
  await action.publicClient.simulate(action.call);

  const hash = await action.walletClient.writeContract(action.call);
  markTransactionPending({ chainId: action.chainId, hash, action: action.name });

  const receipt = await action.publicClient.waitForTransactionReceipt({ hash });
  await waitForConfirmations(action.confirmationDepth, receipt.blockNumber);
  await action.readAfterEvent(receipt);

  markTransactionConfirmed({ chainId: action.chainId, hash });
}
```

## Public Environment Guard

```ts
function assertNoSecretsInPublicEnv(env: Record<string, string | undefined>) {
  const forbidden = [
    "PRIVATE_KEY",
    "MNEMONIC",
    "SIGNER_SECRET",
    "SIGNER_SERVICE_TOKEN",
    "BEARER_TOKEN",
    "SESSION_COOKIE",
    "PRIVATE_RPC_URL",
  ];

  for (const [key, value] of Object.entries(env)) {
    if (!key.startsWith("NEXT_PUBLIC_")) continue;
    if (!value) continue;
    const publicName = key.slice("NEXT_PUBLIC_".length);
    if (forbidden.some((marker) => publicName.includes(marker))) {
      throw new Error(`secret-shaped public env var: ${key}`);
    }
  }
}
```

## Cache Invalidation

```ts
function invalidateFromEvent(queryClient: QueryClientLike, event: StreamEvent) {
  switch (event.name) {
    case "Transfer":
    case "TokenBurned":
      invalidateOwnershipAndTokenState(queryClient, event);
      break;
    case "MetadataUpdate":
    case "BatchMetadataUpdate":
    case "CollectionFrozen":
    case "DependencyVersionPinned":
    case "DependencyVersionCreated":
    case "DependencyVersionDeprecated":
      invalidateMetadataAndAnimation(queryClient, event);
      break;
    default:
      invalidateEntityFromTopic(queryClient, event);
  }
}
```

These snippets deliberately omit package imports, dependency versions, wallet
connector setup, and router code. A production app must wire those choices to
reviewed release artifacts, retained non-local evidence, and the relevant
security reviews before making public beta or production claims.
