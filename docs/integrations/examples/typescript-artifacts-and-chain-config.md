# TypeScript Artifact And Chain Config Snippets

Baseline record — not a specification. This document describes as-built
or operational state; the normative target is the specification set
indexed in [`docs/spec-policy.md`](../../spec-policy.md), and where this
document conflicts with a specification home, the specification wins.

These INT-013 TypeScript snippets show how a 6529.io-style React, Next,
mobile, Electron, indexer, or operator UI codebase can perform artifact loading
for 6529Stream release artifacts and build fail-closed chain config. They are
pre-audit guidance for the local baseline, not production-ready, not a security
claim, not a generated SDK, and not a maintained package.

Use these snippets with the broader
[frontend reference architecture](../frontend-reference-architecture.md) and
the integration entrypoint in [docs/integrations/README.md](../README.md).

## Maturity And Scope

These snippets do not replace fork/testnet/live evidence, external audit
evidence, production signatures, explorer verification, marketplace evidence,
or reviewed production signer custody. Public beta and production consumers
must still consult [docs/release-readiness.md](../../release-readiness.md),
[docs/public-beta-evidence.md](../../public-beta-evidence.md), and
[docs/non-local-release-evidence.md](../../non-local-release-evidence.md).

The snippets intentionally avoid package imports and framework bootstrapping.
They show validation shape only. A product team may implement them with viem,
wagmi, ethers, TanStack Query, a server-side loader, or a generated internal
client, but the source of truth remains the committed release artifacts.

## Source Of Truth

Release artifact loading must use reviewed artifacts instead of hardcoding
contract addresses, ABI hashes, chain IDs, or deployment versions.

- [release-artifacts/latest/release-manifest.json](../../../release-artifacts/latest/release-manifest.json)
- [release-artifacts/latest/release-checksums.json](../../../release-artifacts/latest/release-checksums.json)
- [release-artifacts/latest/SHA256SUMS](../../../release-artifacts/latest/SHA256SUMS)
- [release-artifacts/latest/abi-checksums.json](../../../release-artifacts/latest/abi-checksums.json)
- [release-artifacts/latest/event-topic-catalog.json](../../../release-artifacts/latest/event-topic-catalog.json)
- [release-artifacts/latest/interface-ids.json](../../../release-artifacts/latest/interface-ids.json)
- [release-artifacts/latest/bytecode-release-proof.json](../../../release-artifacts/latest/bytecode-release-proof.json)
- [release-artifacts/latest/public-beta-evidence.json](../../../release-artifacts/latest/public-beta-evidence.json)
- [deployments/schema/address-book.schema.json](../../../deployments/schema/address-book.schema.json)
- [deployments/schema/deployment-manifest.schema.json](../../../deployments/schema/deployment-manifest.schema.json)
- [deployments/address-books/anvil-6529stream-v0.1.0-001.json](../../../deployments/address-books/anvil-6529stream-v0.1.0-001.json)
- [deployments/examples/anvil-6529stream-v0.1.0-001.json](../../../deployments/examples/anvil-6529stream-v0.1.0-001.json)
- [release-artifacts/README.md](../../../release-artifacts/README.md)

Raw ABIs are generated under ignored `out/` after `forge build`. A frontend can
import generated local ABIs during development, but release review should use
the ABI surface baseline, ABI checksums, protocol surface report, event topic
catalog, interface IDs, release manifest, checksum bundle, and
bytecode-to-release proof.

## Public Environment Shape

Keep public runtime configuration small and explicit.

```ts
type StreamPublicEnv = {
  NEXT_PUBLIC_STREAM_CHAIN_ID: string;
  NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION: string;
  NEXT_PUBLIC_STREAM_RELEASE_MANIFEST_URL: string;
  NEXT_PUBLIC_STREAM_ADDRESS_BOOK_URL: string;
  NEXT_PUBLIC_STREAM_EXPECTED_RELEASE_MANIFEST_SHA256?: string;
};

function readPublicStreamEnv(env: Record<string, string | undefined>): StreamPublicEnv {
  assertNoSecretShapedPublicEnv(env);

  return {
    NEXT_PUBLIC_STREAM_CHAIN_ID: requireEnv(env, "NEXT_PUBLIC_STREAM_CHAIN_ID"),
    NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION: requireEnv(
      env,
      "NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION",
    ),
    NEXT_PUBLIC_STREAM_RELEASE_MANIFEST_URL: requireEnv(
      env,
      "NEXT_PUBLIC_STREAM_RELEASE_MANIFEST_URL",
    ),
    NEXT_PUBLIC_STREAM_ADDRESS_BOOK_URL: requireEnv(
      env,
      "NEXT_PUBLIC_STREAM_ADDRESS_BOOK_URL",
    ),
    NEXT_PUBLIC_STREAM_EXPECTED_RELEASE_MANIFEST_SHA256:
      env.NEXT_PUBLIC_STREAM_EXPECTED_RELEASE_MANIFEST_SHA256,
  };
}
```

Never place private keys, seed phrases, signer-service credentials, bearer
tokens, private RPC credentials, WalletConnect pairing URI values, session
topics, raw signatures, unreleased drop payloads, or admin credentials in
`NEXT_PUBLIC_*`, mobile telemetry, Electron renderer logs, crash reports, or
support bundles.

## Artifact Types

Keep the boundary between public release artifacts and app-local convenience
types obvious.

```ts
type Sha256Hex = `sha256:${string}`;
type HexAddress = `0x${string}`;

type ReleaseManifest = {
  schema_version: string;
  release_artifacts: Record<string, unknown>;
  deployment_artifacts: Record<string, unknown>;
  governance_docs: Array<{ path: string; sha256: Sha256Hex }>;
};

type AddressBook = {
  schema_version: string;
  deployment_version: string;
  network: {
    chain_id: number;
    name: string;
  };
  contracts: Record<string, { address: HexAddress }>;
  source?: {
    deployment_manifest_sha256?: Sha256Hex;
    release_manifest_sha256?: Sha256Hex;
  };
};

type DeploymentManifest = {
  schema_version: string;
  deployment_version: string;
  chain_id: number;
  contracts: Record<string, { address: HexAddress }>;
};
```

Treat these as snippet-level shapes, not replacement schemas. The committed
schemas remain the source of truth.

## Fetch And Digest Helpers

Compute digests over the exact bytes the app consumes. Do not normalize JSON
before hashing unless the release process explicitly says to do so.

```ts
async function fetchJsonWithDigest<T>(url: string): Promise<{ value: T; sha256: Sha256Hex }> {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) {
    throw new Error(`failed to load artifact ${url}: ${response.status}`);
  }

  const bytes = new Uint8Array(await response.arrayBuffer());
  const digest = await sha256(bytes);
  const text = new TextDecoder().decode(bytes);
  return { value: JSON.parse(text) as T, sha256: digest };
}

async function sha256(bytes: Uint8Array): Promise<Sha256Hex> {
  const hash = await crypto.subtle.digest("SHA-256", bytes);
  const hex = [...new Uint8Array(hash)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
  return `sha256:${hex}`;
}
```

Server-side loaders can use Node crypto, but browser, mobile WebView, and
Electron renderer code should still keep the no-secret boundary.

## Release Manifest Loader

Load the release manifest first. If an expected release manifest hash is
configured, fail closed when it does not match.

```ts
async function loadReleaseManifest(env: StreamPublicEnv) {
  const artifact = await fetchJsonWithDigest<ReleaseManifest>(
    env.NEXT_PUBLIC_STREAM_RELEASE_MANIFEST_URL,
  );

  const expected = env.NEXT_PUBLIC_STREAM_EXPECTED_RELEASE_MANIFEST_SHA256;
  if (expected && artifact.sha256 !== expected) {
    throw new Error("release manifest hash mismatch");
  }

  requireSchema(artifact.value, "6529stream.release-manifest.v1");
  return {
    manifest: artifact.value,
    releaseManifestHash: artifact.sha256,
  };
}
```

Pinning the manifest hash is strongly preferred for public beta and production
builds. Unpinned local builds are developer convenience only.

## Address Book Loader

The address book must agree with the selected chain ID, deployment version,
and release manifest hash before any contract read, transaction simulation,
WalletConnect prompt, EIP-712 prompt, or Safe transaction proposal.

```ts
async function loadAddressBook(
  env: StreamPublicEnv,
  releaseManifestHash: Sha256Hex,
) {
  const artifact = await fetchJsonWithDigest<AddressBook>(
    env.NEXT_PUBLIC_STREAM_ADDRESS_BOOK_URL,
  );
  const addressBook = artifact.value;

  requireSchema(addressBook, "6529stream.address-book.v1");
  assertNumberEquals(
    addressBook.network.chain_id,
    Number(env.NEXT_PUBLIC_STREAM_CHAIN_ID),
    "address-book chain ID",
  );
  assertStringEquals(
    addressBook.deployment_version,
    env.NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION,
    "address-book deployment version",
  );
  if (addressBook.source?.release_manifest_sha256) {
    assertStringEquals(
      addressBook.source.release_manifest_sha256,
      releaseManifestHash,
      "address-book release manifest hash",
    );
  }

  return { addressBook, addressBookHash: artifact.sha256 };
}
```

If the address book and wallet chain disagree, stop before the wallet prompt.

## Deployment Manifest Cross-Checks

Use the deployment manifest when it is available to prove that the address book
and release artifact set describe the same deployment.

```ts
function assertDeploymentManifestMatchesAddressBook(
  deploymentManifest: DeploymentManifest,
  addressBook: AddressBook,
) {
  requireSchema(deploymentManifest, "6529stream.deployment-manifest.v1");
  assertNumberEquals(
    deploymentManifest.chain_id,
    addressBook.network.chain_id,
    "deployment manifest chain ID",
  );
  assertStringEquals(
    deploymentManifest.deployment_version,
    addressBook.deployment_version,
    "deployment manifest deployment version",
  );

  for (const [name, addressRecord] of Object.entries(addressBook.contracts)) {
    const manifestRecord = deploymentManifest.contracts[name];
    if (!manifestRecord) throw new Error(`missing deployment manifest contract: ${name}`);
    assertAddressEquals(manifestRecord.address, addressRecord.address, name);
  }
}
```

Do not infer production readiness from this local check. Live bytecode,
explorer verification, and retained deployment evidence are separate gates.

## Chain Config Builder

Build one app-level chain config from validated artifacts. Do not let
components construct independent contract maps.

```ts
type StreamChainConfig = {
  chainId: number;
  deploymentVersion: string;
  releaseManifestHash: Sha256Hex;
  addressBookHash: Sha256Hex;
  contracts: {
    StreamCore: HexAddress;
    StreamDrops: HexAddress;
    StreamAuctions: HexAddress;
    StreamCuratorsPool: HexAddress;
    StreamContractMetadata?: HexAddress;
  };
};

function makeStreamChainConfig(input: {
  env: StreamPublicEnv;
  releaseManifestHash: Sha256Hex;
  addressBookHash: Sha256Hex;
  addressBook: AddressBook;
}): StreamChainConfig {
  return {
    chainId: Number(input.env.NEXT_PUBLIC_STREAM_CHAIN_ID),
    deploymentVersion: input.env.NEXT_PUBLIC_STREAM_DEPLOYMENT_VERSION,
    releaseManifestHash: input.releaseManifestHash,
    addressBookHash: input.addressBookHash,
    contracts: {
      StreamCore: requiredAddress(input.addressBook, "StreamCore"),
      StreamDrops: requiredAddress(input.addressBook, "StreamDrops"),
      StreamAuctions: requiredAddress(input.addressBook, "StreamAuctions"),
      StreamCuratorsPool: requiredAddress(input.addressBook, "StreamCuratorsPool"),
      StreamContractMetadata: optionalAddress(
        input.addressBook,
        "StreamContractMetadata",
      ),
    },
  };
}
```

Cache keys should include `chainId`, `deploymentVersion`,
`releaseManifestHash`, contract address, function name, arguments, block tag,
metadata schema version, event source, and transaction hash as relevant.

## ABI And Contract Lookup

Raw ABI JSON should come from the local build output or an app-owned generated
type pipeline. The app still needs to compare the selected ABI to the tracked
ABI checksum or ABI surface before making release claims.

```ts
function requiredAddress(addressBook: AddressBook, name: string): HexAddress {
  const address = addressBook.contracts[name]?.address;
  if (!address || !/^0x[0-9a-fA-F]{40}$/.test(address)) {
    throw new Error(`missing or invalid contract address: ${name}`);
  }
  return address as HexAddress;
}

function optionalAddress(addressBook: AddressBook, name: string): HexAddress | undefined {
  const address = addressBook.contracts[name]?.address;
  return address ? requiredAddress(addressBook, name) : undefined;
}
```

Do not paste ABI arrays into application source without a documented generation
or checksum process.

`optionalAddress` only treats an absent contract as optional. A present but
malformed optional address still throws through `requiredAddress`, which is the
intended fail-closed behavior for reviewed address books.

## Fail-Closed Preflight

Run preflight before any wallet prompt, Safe proposal, typed-data signature,
fixed-price mint, auction bid, curator claim, withdrawal, metadata refresh, or
operator transaction.

```ts
function assertWalletCanUseStreamConfig(input: {
  walletChainId: number;
  chainConfig: StreamChainConfig;
  expectedContract?: HexAddress;
}) {
  assertNumberEquals(input.walletChainId, input.chainConfig.chainId, "wallet chain ID");

  if (input.expectedContract) {
    const known = Object.values(input.chainConfig.contracts)
      .filter(Boolean)
      .map((address) => address.toLowerCase());
    if (!known.includes(input.expectedContract.toLowerCase())) {
      throw new Error("contract address is not in the active 6529Stream address book");
    }
  }
}
```

For EIP-712 signing, the domain still needs the expected chain ID and verifying
contract. Replay protection comes from on-chain consumed/cancelled/signer-epoch
state, not TypeScript, WalletConnect, or EIP-712 alone.

## React Integration Pattern

Load artifacts once per environment and feed the validated config into query,
transaction, metadata, and event layers.

```ts
async function loadStreamRuntime(envRecord: Record<string, string | undefined>) {
  const env = readPublicStreamEnv(envRecord);
  const { manifest, releaseManifestHash } = await loadReleaseManifest(env);
  const { addressBook, addressBookHash } = await loadAddressBook(
    env,
    releaseManifestHash,
  );

  const deploymentManifest = selectDeploymentManifest(manifest, addressBook);
  if (deploymentManifest) {
    assertDeploymentManifestMatchesAddressBook(deploymentManifest, addressBook);
  }

  return makeStreamChainConfig({
    env,
    releaseManifestHash,
    addressBookHash,
    addressBook,
  });
}
```

React Query, wagmi, viem, mobile shells, Electron preload bridges, and indexer
workers should consume this same validated object rather than reloading or
reconstructing contract addresses independently.

## Testing And Fixtures

At minimum, test these cases in the consuming application:

- Correct local Anvil artifact set loads.
- Missing release manifest URL fails before rendering transaction controls.
- Wrong chain ID fails before wallet prompts.
- Wrong deployment version fails before reads or writes.
- Wrong release manifest hash fails closed.
- Address-book contract typo fails closed.
- Deployment manifest/address-book mismatch fails closed.
- Secret-shaped `NEXT_PUBLIC_*` variables fail closed.
- Wallet chain switch invalidates read and transaction state.
- Release manifest hash change invalidates cached contract clients.

Use [docs/integrations/contract-flows.md](../contract-flows.md),
[docs/integrations/auction-flows.md](../auction-flows.md),
[docs/integrations/wallets-and-signatures.md](../wallets-and-signatures.md),
[docs/integrations/events-and-indexing.md](../events-and-indexing.md),
[docs/integrations/metadata-rendering.md](../metadata-rendering.md),
[docs/integrations/mobile-walletconnect.md](../mobile-walletconnect.md), and
[docs/integrations/electron-security-wallets.md](../electron-security-wallets.md)
for transaction, wallet, indexer, metadata, mobile, and desktop behavior.

## Validation Commands

```sh
python scripts/test_typescript_artifact_chain_config.py
python scripts/check_typescript_artifact_chain_config.py
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
make typescript-artifact-chain-config-check
make check
powershell -ExecutionPolicy Bypass -File scripts\check.ps1
```

## Maintenance

Update this guide whenever release artifact schema versions, address-book
fields, deployment manifest fields, contract names, checksum policy, ABI
generation policy, or public environment names change. Keep snippets
framework-light and preserve the fail-closed order: environment, release
manifest, address book, deployment manifest, chain config, wallet preflight,
then read/write/signature flow.
