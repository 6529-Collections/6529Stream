# TypeScript Event Decoding And Indexer Ingestion Snippets

These INT-015 TypeScript snippets show how a 6529.io-style React, Next,
mobile, Electron, indexer, analytics, or operator UI codebase can load the
6529Stream event topic catalog, decode logs, normalize event identities, and
queue read-after-event reconciliation. They are pre-audit guidance for the
local baseline, not production-ready, not a security claim, not a generated
SDK, not an indexer service, and not retained marketplace/indexer evidence.

Use these snippets with [docs/integrations/events-and-indexing.md](../events-and-indexing.md),
[docs/integrations/frontend-reference-architecture.md](../frontend-reference-architecture.md),
[docs/integrations/examples/react-viem.md](react-viem.md), and
[docs/integrations/examples/typescript-artifacts-and-chain-config.md](typescript-artifacts-and-chain-config.md).

## Maturity And Scope

These snippets cover local event decoding and ingestion shape only. They do
not replace fork/testnet/live replay evidence, marketplace evidence, external
audit evidence, explorer verification, release signatures, production
deployment manifests, or reviewed production indexer operations. Public beta
and production remain governed by
[docs/release-readiness.md](../../release-readiness.md),
[docs/public-beta-evidence.md](../../public-beta-evidence.md), and
[docs/non-local-release-evidence.md](../../non-local-release-evidence.md).

The intended boundary is:

- load release artifacts and address books before decoding;
- verify chain ID, deployment version, contract address, ABI checksum, and
  event topic catalog before processing logs;
- fail closed on wrong deployment, wrong chain, unknown emitter, unknown
  `topic0`, ABI/topic drift, malformed logs, reorgs outside policy, and
  secret-shaped diagnostic fields;
- store idempotent log identities before applying entity updates;
- use read-after-event queues for state that cannot be reconstructed from a
  single event; and
- treat optimistic logs as reversible until confirmation depth is reached.

## Source Of Truth

- [docs/integrations/events-and-indexing.md](../events-and-indexing.md)
- [docs/integrations/README.md](../README.md)
- [docs/integrations/contract-flows.md](../contract-flows.md)
- [docs/integrations/auction-flows.md](../auction-flows.md)
- [docs/integrations/wallets-and-signatures.md](../wallets-and-signatures.md)
- [docs/integrations/metadata-rendering.md](../metadata-rendering.md)
- [docs/integrations/marketplace-indexer-evidence.md](../marketplace-indexer-evidence.md)
- [docs/release-readiness.md](../../release-readiness.md)
- [docs/public-beta-evidence.md](../../public-beta-evidence.md)
- [docs/non-local-release-evidence.md](../../non-local-release-evidence.md)
- [release-artifacts/latest/release-manifest.json](../../../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/release-checksums.json](../../../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/SHA256SUMS](../../../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/abi-checksums.json](../../../release-artifacts/latest/abi-checksums.json)
- [release-artifacts/latest/event-topic-catalog.json](../../../release-artifacts/latest/event-topic-catalog.json)
- [release-artifacts/baselines/v0.1.0/abi-surface.json](../../../release-artifacts/baselines/v0.1.0/abi-surface.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [deployments/examples/anvil-6529stream-v0.1.0-001.json](../../../deployments/examples/anvil-6529stream-v0.1.0-001.json)
- [test/StreamEventReconstructability.t.sol](../../../test/StreamEventReconstructability.t.sol)
- [test/StreamMinterEvents.t.sol](../../../test/StreamMinterEvents.t.sol)
- [test/StreamMetadataEvents.t.sol](../../../test/StreamMetadataEvents.t.sol)

Raw ABIs under ignored `out/` are local build products. A product team may
generate viem or ethers clients from those ABIs, but release review should
still compare the selected ABI surface, ABI checksums, event topic catalog,
address book, deployment manifest, release manifest, and checksum bundle.

## Event Catalog Types

Keep catalog types small at the integration boundary. The committed catalog is
the source of truth; these shapes are snippet-level helpers.

```ts
type Hex = `0x${string}`;
type HexAddress = `0x${string}`;
type Sha256Hex = `sha256:${string}`;

type EventTopicCatalogEntry = {
  name: string;
  signature: string;
  topic0: Hex;
  inputs: Array<{ name: string; type: string; indexed: boolean }>;
  emitted_by: string[];
};

type EventTopicCatalog = {
  schema_version: string;
  generated_by: string;
  topics: EventTopicCatalogEntry[];
};

const EXPECTED_EVENT_TOPIC_CATALOG_GENERATOR = "scripts/generate_release_artifacts.py:1";

type StreamChainConfig = {
  chainId: number;
  deploymentVersion: string;
  releaseManifestHash: Sha256Hex;
  eventTopicCatalogHash: Sha256Hex;
  abiChecksumsHash: Sha256Hex;
  contracts: Record<string, HexAddress>;
};
```

Do not hardcode event signatures or contract addresses in handlers. Build
dispatch tables from reviewed artifacts.

## Artifact Preflight

Run artifact preflight before subscriptions, historical backfills, transaction
receipt decoding, or operator dashboards.

```ts
function assertEventArtifactPreflight(input: {
  chainConfig: StreamChainConfig;
  catalog: EventTopicCatalog;
  expectedChainId: number;
}) {
  if (input.chainConfig.chainId !== input.expectedChainId) {
    throw new Error("wrong chain ID for event decoding");
  }
  if (input.catalog.schema_version !== "6529stream.event-topic-catalog.v1") {
    throw new Error("unsupported event topic catalog schema");
  }
  if (input.catalog.generated_by !== EXPECTED_EVENT_TOPIC_CATALOG_GENERATOR) {
    throw new Error("unexpected event topic catalog generator");
  }
  if (!input.chainConfig.eventTopicCatalogHash.startsWith("sha256:")) {
    throw new Error("missing event topic catalog digest");
  }
}
```

ABI checksum validation and event topic catalog validation are different
checks. ABI checksums prove the ABI bundle selected by the application.
`topic0` dispatch proves that a log belongs to a known event in the selected
release catalog. Both should pass before entity writes.

## Topic Dispatch

Create a dispatch table keyed by lowercased emitter and `topic0`. This guards
against same-signature events emitted by a contract that is not in the selected
address book.

```ts
type DispatchKey = `${Lowercase<HexAddress>}:${Lowercase<Hex>}`;

type EventHandler = (log: StreamRawLog, decoded: DecodedEvent) => IngestionAction[];

function makeDispatchTable(input: {
  chainConfig: StreamChainConfig;
  catalog: EventTopicCatalog;
  handlers: Record<string, EventHandler>;
}): Map<DispatchKey, { entry: EventTopicCatalogEntry; handler: EventHandler }> {
  const table = new Map<DispatchKey, { entry: EventTopicCatalogEntry; handler: EventHandler }>();
  for (const entry of input.catalog.topics) {
    for (const contractName of entry.emitted_by) {
      const address = input.chainConfig.contracts[contractName];
      if (!address) throw new Error(`missing address for event contract ${contractName}`);
      const handler = input.handlers[`${contractName}.${entry.name}`];
      if (!handler) throw new Error(`missing handler for ${contractName}.${entry.name}`);
      table.set(dispatchKey(address, entry.topic0), { entry, handler });
    }
  }
  return table;
}

function dispatchKey(address: HexAddress, topic0: Hex): DispatchKey {
  return `${address.toLowerCase() as Lowercase<HexAddress>}:${topic0.toLowerCase() as Lowercase<Hex>}`;
}
```

Unknown emitter addresses, unknown `topic0` values, and known `topic0` values
from the wrong contract should fail closed or land in an explicit quarantine
queue. They should not update product-visible entities.

## Log Identity

Persist log identity before applying event effects. This is the idempotency key
and the rollback handle.

```ts
type StreamRawLog = {
  chainId: number;
  address: HexAddress;
  blockNumber: bigint;
  blockHash: Hex;
  transactionHash: Hex;
  transactionIndex: number;
  logIndex: number;
  topics: Hex[];
  data: Hex;
  removed?: boolean;
};

type NormalizedLogIdentity = {
  namespace: string;
  confirmedKey: string;
  optimisticKey: string;
  blockNumber: bigint;
  blockHash: Hex;
  transactionHash: Hex;
  logIndex: number;
};

function normalizeLogIdentity(input: {
  chainConfig: StreamChainConfig;
  log: StreamRawLog;
}): NormalizedLogIdentity {
  if (input.log.chainId !== input.chainConfig.chainId) {
    throw new Error("log chain ID does not match active stream config");
  }

  const namespace = [
    input.chainConfig.chainId,
    input.chainConfig.deploymentVersion,
    input.log.address.toLowerCase(),
  ].join(":");

  return {
    namespace,
    confirmedKey: [
      namespace,
      input.log.blockHash,
      input.log.transactionHash,
      input.log.logIndex,
    ].join(":"),
    optimisticKey: [namespace, input.log.transactionHash, input.log.logIndex].join(":"),
    blockNumber: input.log.blockNumber,
    blockHash: input.log.blockHash,
    transactionHash: input.log.transactionHash,
    logIndex: input.log.logIndex,
  };
}
```

Duplicate logs must be idempotent. Replays should not double-count credits,
bids, token supply, randomizer state, provenance records, or metadata refresh
tasks when the same confirmed log appears twice.

## Decode Log Boundary

Keep ABI decoding behind one boundary. The example assumes a viem-like
`decodeLog` function, but the same shape applies to ethers or generated
internal clients.

```ts
type DecodedEvent = {
  eventName: string;
  args: Record<string, unknown>;
};

type DecodeLog = (input: {
  abi: unknown[];
  topics: Hex[];
  data: Hex;
}) => DecodedEvent;

function decodeStreamLog(input: {
  log: StreamRawLog;
  dispatchTable: Map<DispatchKey, { entry: EventTopicCatalogEntry; handler: EventHandler }>;
  abiByAddress: Record<Lowercase<HexAddress>, unknown[]>;
  decodeLog: DecodeLog;
}) {
  const topic0 = input.log.topics[0];
  if (!topic0) throw new Error("log is missing topic0");

  const dispatch = input.dispatchTable.get(dispatchKey(input.log.address, topic0));
  if (!dispatch) throw new Error("unknown stream event topic or emitter");

  const abi = input.abiByAddress[input.log.address.toLowerCase() as Lowercase<HexAddress>];
  if (!abi) throw new Error(`missing ABI for ${input.log.address}`);

  const decoded = input.decodeLog({
    abi,
    topics: input.log.topics,
    data: input.log.data,
  });

  if (decoded.eventName !== dispatch.entry.name) {
    throw new Error("decoded event name does not match event topic catalog");
  }

  return { entry: dispatch.entry, decoded, handler: dispatch.handler };
}
```

Malformed logs, wrong ABI selection, and name/topic mismatches should be
observable ingestion errors, not silent skips.

## Ingestion Actions

Handlers should produce explicit actions. Keep direct entity writes,
read-after-event calls, cache invalidation, and quarantine separate.

```ts
type IngestionAction =
  | { kind: "upsert"; entity: string; key: string; value: Record<string, unknown> }
  | { kind: "readAfterEvent"; target: string; blockNumber: bigint; args: Record<string, unknown> }
  | { kind: "invalidate"; cacheKey: string; reason: string }
  | { kind: "quarantine"; reason: string; details: Record<string, unknown> };

function handleDropAuthorizationConsumed(
  log: StreamRawLog,
  decoded: DecodedEvent,
): IngestionAction[] {
  const dropId = requireHex(decoded.args.dropId, "dropId");
  return [
    {
      kind: "upsert",
      entity: "DropExecution",
      key: `${log.chainId}:${log.address.toLowerCase()}:${dropId}`,
      value: {
        dropId,
        signer: requireAddress(decoded.args.signer, "signer"),
        poster: requireAddress(decoded.args.poster, "poster"),
        recipient: requireAddress(decoded.args.recipient, "recipient"),
        saleMode: Number(decoded.args.saleMode),
        signerEpoch: String(decoded.args.signerEpoch),
        transactionHash: log.transactionHash,
      },
    },
    {
      kind: "readAfterEvent",
      target: "StreamDrops.isDropConsumed",
      blockNumber: log.blockNumber,
      args: { dropId },
    },
  ];
}
```

Read-after-event actions should carry the triggering block number so archive
RPC clients can read historical state. If historical reads are unavailable,
record the repair task instead of filling the entity with current-state guesses.

The snippet-level `requireHex`, `requireAddress`, and assertion helpers are
assumed to live in the consuming application's validation layer. They should
fail closed and should not coerce malformed decoded fields into usable entity
keys.

## Confirmation And Reorg Handling

Use optimistic state for fresh logs and promote only after confirmation depth.
The reorg rollback path must be tested as a first-class ingestion flow, not
treated as an operator-only repair.

```ts
type ReorgPolicy = {
  confirmationDepth: bigint;
  rollbackWindow: bigint;
};

function classifyLogFinality(input: {
  logBlockNumber: bigint;
  currentBlockNumber: bigint;
  policy: ReorgPolicy;
}): "optimistic" | "confirmed" {
  const confirmations = input.currentBlockNumber - input.logBlockNumber;
  return confirmations >= input.policy.confirmationDepth ? "confirmed" : "optimistic";
}

function shouldRollbackFromBlock(input: {
  firstDivergentBlock: bigint;
  currentBlockNumber: bigint;
  policy: ReorgPolicy;
}) {
  const age = input.currentBlockNumber - input.firstDivergentBlock;
  if (age > input.policy.rollbackWindow) {
    throw new Error("reorg exceeds configured rollback window");
  }
  return true;
}
```

On block-hash mismatch, roll back all logs at and after the first divergent
block, remove optimistic entities, replay from the last confirmed ancestor, and
re-run read-after-event reconciliation for affected entities.

## Read-After-Event Queue

Events are the trigger; reads are the state reconciliation boundary.

```ts
type ReadAfterEventTask = {
  id: string;
  chainId: number;
  contract: string;
  contractAddress: HexAddress;
  functionName: string;
  args: Record<string, unknown>;
  blockNumber: bigint;
  sourceLogKey: string;
};

function makeReadAfterEventTask(input: {
  chainConfig: StreamChainConfig;
  contract: string;
  functionName: string;
  args: Record<string, unknown>;
  blockNumber: bigint;
  sourceLogKey: string;
}): ReadAfterEventTask {
  const contractAddress = input.chainConfig.contracts[input.contract];
  if (!contractAddress) throw new Error(`unknown read-after-event contract ${input.contract}`);
  return {
    id: [
      input.chainConfig.chainId,
      input.contract,
      input.functionName,
      input.sourceLogKey,
    ].join(":"),
    chainId: input.chainConfig.chainId,
    contract: input.contract,
    contractAddress,
    functionName: input.functionName,
    args: input.args,
    blockNumber: input.blockNumber,
    sourceLogKey: input.sourceLogKey,
  };
}
```

Important read-after-event surfaces include `ownerOf`, `tokenURI`,
`contractURI()`, `contractURIHash()`, collection metadata and freeze views,
drop consumed/cancelled state, signer epoch, auction records, bid/proceeds
credits, total owed views, randomizer request state, curator roots, pause
domains, and admin role reads.

## No-Secret Logging

Ingestion diagnostics may include public values:

- chain ID;
- deployment version;
- release manifest hash;
- event topic catalog hash;
- contract name and address;
- event name and `topic0`;
- block number, transaction hash, and log index;
- normalized entity key;
- decoded custom error name; and
- read-after-event task ID.

Do not log private keys, seed phrases, signer-service credentials, bearer
tokens, private RPC credentials, WalletConnect pairing URIs, WalletConnect
session topics, raw signatures, unreleased token data, admin credentials,
collector private data, or unreleased drop payloads.

## Testing And Fixtures

Consuming applications and indexers should test at least:

- correct local Anvil event topic catalog loads;
- wrong chain ID fails before subscriptions;
- wrong deployment version fails before entity writes;
- missing address-book contract fails closed;
- ABI checksum mismatch fails closed;
- event topic catalog hash mismatch fails closed;
- unknown emitter fails closed;
- unknown `topic0` fails closed;
- known `topic0` from the wrong contract fails closed;
- malformed log fails closed;
- decoded event name mismatch fails closed;
- duplicate confirmed log is idempotent;
- optimistic log rolls back on block-hash mismatch;
- confirmed log promotes only after confirmation depth;
- read-after-event task is queued for state that cannot be derived from one
  event;
- failed read-after-event creates a repair task;
- metadata update invalidates token or collection cache without implying
  marketplace ingestion;
- randomizer lifecycle distinguishes pending, fulfilled, stale, failed, and
  retry-failed; and
- diagnostics redact raw signatures, raw token data, private RPC credentials,
  WalletConnect session topics, and bearer tokens.

## Validation Commands

```sh
python scripts/test_typescript_event_decoding_indexer.py
python scripts/check_typescript_event_decoding_indexer.py
python scripts/test_events_and_indexing.py
python scripts/check_events_and_indexing.py
python scripts/test_integrations_readme.py
python scripts/check_integrations_readme.py
python scripts/test_react_next_reference.py
python scripts/check_react_next_reference.py
python scripts/test_release_manifest.py
python scripts/generate_release_manifest.py --check
python scripts/test_bytecode_release_proof.py
python scripts/generate_bytecode_release_proof.py --check
python scripts/test_release_checksums.py
python scripts/generate_release_checksums.py --check
python scripts/check_changelog.py
make typescript-event-decoding-indexer-check
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update these snippets whenever the event topic catalog schema, ABI checksum
policy, address-book schema, deployment manifest schema, event signatures,
indexed fields, emitting contracts, read-after-event views, confirmation depth
policy, reorg policy, metadata cache policy, randomizer lifecycle, auction
state model, credit accounting, or marketplace/indexer evidence posture
changes. Keep examples framework-light and preserve the order: artifact
preflight, topic dispatch, log identity, decode boundary, ingestion actions,
confirmation/reorg policy, read-after-event queue, then no-secret diagnostics.
