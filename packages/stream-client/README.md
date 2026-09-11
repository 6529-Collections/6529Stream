# Stream client

Typed calls, receipt decoding and EIP-712 payloads for the **retained testnet RC1
export**. The ongoing v1 contracts have changed; their ABIs and signing payloads
must be exported and verified before using this client against that new stack.
This private development package is not published to npm. It contains
no wallet keys, RPC credentials, deployment defaults or automatic transactions.

From this directory, with Node.js 22 or newer:

```sh
npm ci --ignore-scripts
npm test
```

`npm run build` emits JavaScript and declarations into `dist/`. Import
`dist/index.js` from a local app, or use this directory as a local package
dependency. The only runtime dependency is ethers 6.17.0; TypeScript 5.9.3 is a
build dependency. Both are pinned in the lockfile.

See the [integration guide](../../docs/integrations/typescript-client.md) for
configuration, signing, transaction simulation, examples and limitations.

`npm run generate` projects ABI and call types from the exact retained
`release-artifacts/current` export. `npm run generate:check` verifies the
projection without writing. Generation does not compile Solidity or update
release evidence. A source export update requires reviewing the client diff and
rechecking its onchain digest vectors; the client is not a source-verification
or deployment-attestation tool.

`toSafeCall` preserves any prepared call's target, calldata and native value for
a Safe transaction builder. `requireSafeExecution` checks the expected Safe and
its independently verified transaction hash against actual execution success,
including the different event layouts in Safe 1.3.0, 1.4.1 and 1.5.0. Applications
also verify the expected Stream events and resulting state. See the
[Safe workflow](../../docs/integrations/typescript-client.md#submit-through-a-safe).

The examples are executable functions accepting caller-supplied ethers wallets:

- `examples/native-purchase.mjs`: platform and artist signatures, payer submission.
- `examples/erc20-purchase.mjs`: separate payer intent, relayer submission.
- `examples/artist-acceptance.mjs`: unfunded artist acceptance through a relayer.
- `examples/auction.mjs`: signed creation and escrow; bidding/settlement are separate.
- `examples/prepare.mjs`: offline JSON payload construction.
- `examples/check-digests.mjs`: read-only comparison against deployed digest methods.
- `examples/snapshot.mjs`: pinned-block capture, readable inspection, offline verification and chain readback.

The supported-state exporter creates a deterministic package for **explicitly
selected** collections, tokens, ERC-20 sales and mint phases. It is compatible
with the current publisher's export/manifest hash fields. It does not reconstruct
all history, expose private mappings, host files or publish a transaction. See
the [snapshot workflow](../../docs/integrations/typescript-client.md#capture-and-verify-supported-state).

The committed digest fixtures were observed on a local current-stack deployment.
Their addresses are encoding-vector inputs, not an address book or live launch
evidence. No test or example imports their addresses as defaults.
