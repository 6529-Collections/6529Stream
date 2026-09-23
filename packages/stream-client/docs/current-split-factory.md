# Current split profiles and clone wallets

The current factory creates version-4 wallets through a dedicated implementation
deployed by each factory. This client binds that actual implementation, rebuilds
the original profile identity and predicts its wallet address. It also prepares
the three original public factory calls and checks their direct or Safe receipts.

The contract source is frozen at
[`73823279`](https://github.com/6529-Collections/6529Stream/tree/7382327933c90638e8552fc8dd0340e9de53c449).
Historical version-3 fixtures and generated release-candidate exports retain
their original evidence. A current factory must be inspected with its own code
and implementation pins.

## Capture the actual factory

Supply trusted chain, address and runtime-code-hash coordinates for the factory,
asset-policy registry and singleton implementation:

```ts
import {
  captureSplitFactory, prepareSplitProfile, inspectSplitFactoryProfile,
  prepareSplitFactoryOperation, simulateSplitFactoryOperation,
  inspectSplitFactoryOperationReceipt,
} from "@6529/stream-client";

const blockNumber = await provider.getBlockNumber();
const capture = await captureSplitFactory(provider, {
  chainId,
  factory: { address: factoryAddress, codeHash: factoryCodeHash },
  assetPolicy: { address: assetPolicyAddress, codeHash: assetPolicyCodeHash },
  implementation: { address: implementationAddress, codeHash: implementationCodeHash },
}, { blockTag: blockNumber });
```

Pass a concrete block number. The capture pins that block and checks the chain, runtime code, original factory
and additive implementation interfaces, profile domain, schema, wallet version,
entry bounds, denominator and asset-policy binding. The implementation must be
the factory's locked singleton with no user profile. The client reconstructs
the exact 52-byte clone runtime and 62-byte creation code containing that
implementation address and compares both factory-returned hashes.

The singleton is the implementation recorded for genesis role 6. It is never a
recipient's split wallet. Registration, release signatures and wallet inspection
must use the relevant profile and its individual wallet.

Capture establishes these observed bindings; live factory admission is checked
by simulating the intended write from its actual caller. State can change after
that simulation.

## Build and inspect a profile

```ts
const profile = prepareSplitProfile(capture.snapshot.context, [
  { account: artist, sharePpm: 900_000n, labelId: artistLabel },
  { account: collaborator, sharePpm: 100_000n, labelId: collaboratorLabel },
], metadataURIHash);

const observation = await inspectSplitFactoryProfile(provider, capture, profile, {
  blockTag: await provider.getBlockNumber(),
});
```

Profiles contain 1–64 nonzero-share entries totaling exactly 1,000,000 parts per
million. Sorting follows account, label and share; duplicate account/label pairs
are rejected. Multiple labels for one account remain distinct entries and their
shares are aggregated for payment. A zero metadata hash or label is permitted.

The profile hash preserves this original ordered preimage:

```text
PROFILE_DOMAIN, chainId, factory, schemaVersion, walletVersion,
initCodeHash, runtimeCodeHash, assetPolicyRegistry, entriesHash, metadataURIHash
```

The wallet uses CREATE2 with the factory as deployer and the profile ID as salt.
Two factories can have different implementation addresses and therefore
different clone hashes, even when their recipient terms match. A predicted
address alone does not establish registration or successful initialization.

`inspectSplitFactoryProfile` distinguishes `unregistered`, `registered` and
`initialized`. It compares the profile identity, every canonical factory entry
and account aggregate, and, when deployed, the exact clone bytes and wallet
storage. Wrong code, incomplete initialization or inconsistent metadata fails
closed. It repeats the pinned-block and implementation checks.

The pure context/hash helpers can reproduce original version-3 identities using
their supplied historical hashes. The RPC workflow is specifically for the
verified version-4 clone factory; it does not reinterpret a v3 deployment as v4.

## Register, create or deploy

| Kind | Original call | Result |
| --- | --- | --- |
| `register-profile` | `registerProfile(entries, metadataURIHash)` | Registers immutable terms and returns the predicted wallet; deployment is optional. |
| `create-profile` | `createProfile(entries, metadataURIHash)` | Registers terms and deploys/initializes the wallet in the same transaction. |
| `deploy-wallet` | `deployWallet(profileId)` | Deploys/initializes a previously registered profile's wallet. |

```ts
const operation = prepareSplitFactoryOperation(capture, profile, "create-profile", caller);
await simulateSplitFactoryOperation(provider, operation, { blockTag: await provider.getBlockNumber() });
// Review operation.call, then submit it from caller with your existing signer.
const result = await inspectSplitFactoryOperationReceipt(provider, operation, {
  transactionHash, execution: "direct", // use "safe" for a Safe transaction
});
```

Every call carries zero native value. The client does not prepare direct wallet
initialization. Registration and creation enforce the contract's active runtime
admission even on repeats. The original lazy-deployment path has its own checks
and does not add that registration admission requirement.

The [Safe example](../examples/current-split-factory.mjs) returns one ordinary
Safe CALL, a decoded transaction plan and the canonical recipient terms. Pass
the current compiled factory ABI. The workflow simulates from the actual Safe
address and checks the Safe success event, exact target, calldata and zero value
when inspecting the receipt. No helper signs or broadcasts.

Receipt inspection binds the transaction and its relevant events, checks a
strictly later receipt block than the saved capture, and separately reports
state observed at the end of that block. Another transaction can deploy an
already registered profile later in the same block; that observed deployment
must not be attributed to a registration transaction. The result retains both
`prior` and `observed` profile inspections. Intact eventless retries require
the matching registered or initialized state in the preceding block. A profile
created earlier in the receipt block cannot satisfy that proof; transaction
trace reconciliation for that case is outside this helper.

## Release signing remains wallet-specific

`splitWalletReleaseTypedData(snapshot, profile, authorization)` and
`splitWalletReleaseRevocationTypedData(snapshot, profile, revocation)` construct
the original complete messages using the profile's individual wallet as the
verifier. The EIP-712 name remains `6529StreamSplitWallet` and its signing-domain
version remains `1`, including for wallet implementation version `4`.

These are pure signing-payload helpers. They do not prove a wallet is deployed,
reserve a nonce, check asset policy or guarantee the signed releasable amount.
Inspect the initialized wallet and obtain its current amount, nonce and
authorization facts before signing or submitting a release. Never substitute
the factory or singleton implementation as the signing verifier.

## Frozen evidence

The [ABI fixture](../test/fixtures/current-split-factory-abi.json) contains 215
compiler entries from the retained 31-source `split-clones-abi2` capture. All
production sources and 30 of the 31 total sources match the frozen commit byte
for byte. The one test source predates a final fix that caches the profile ID
before changing implementation code; the fixture records that exception.

```sh
node scripts/generate-current-split-factory-fixture.mjs INPUT.json OUTPUT.json --check
```

The compiler capture is not the final native-test input. Source, ABI and
controlled client tests establish encoding and observation behavior; actual
current-stack and Safe execution, complete genesis, gas and release acceptance
remain separate evidence.
