# Read-only public capture recipe for deployed RC1

This recipe targets the actual [September 10 Sepolia deployment](../deployments/current/sepolia-2026-09-10/README.md).
Its retained source and Core ownership ABI support `PublicOwnershipSource`.
The separate `sepolia-current-rc-1` candidate directory contains an earlier
compilation and is not this deployed evidence package.

Preparing the recipe is offline. Running the ownership capture reads the public
chain at one immutable historical block and verifies the result offline. It
requires no signer, transaction, new node or change to the deployed contracts.

## Immutable source and block

| Pin | Value |
| --- | --- |
| RC1 release commit | `569bf87f1fa808787d324f6e1582924b5ccf1d40` |
| Actual deployed source commit | `d636056b835c9c3ed0b1c4fe7951609429a5789c` |
| Deployed source tag | `evidence/sepolia-deployment-2026-09-10` |
| Compiler-input SHA-256 | `5d3fe6538a8dd16675c8a5f5d87675c99bdbaf14516514cdfe8c7a46b9ad2a1f` |
| Chain / collection / token | `11155111` / `1` / `1` |
| Block / timestamp | `11678119` / `1789082640` |
| Block hash | `0x7424b7fea1abd18a11e54b4f95faf2bd74665596613ec2119a05412f31890928` |
| State root | `0x483c399e8df9438db1221c39e0cc1523461d57048badb5e76c85ecdadb7f7475` |
| Core | `0x05914c6f62c819c861f01c5edd4b6b17e935e75b` |
| Core runtime Keccak-256 | `0x6dd45e4e52993c3b5109cfd8f776a9b49232810f3d98a9374462a343bc31aade` |

The source commit retains its exact compiler input and ABI artifacts under
`release-artifacts/current/`. The deployment's
[address inventory](../deployments/current/sepolia-2026-09-10/deployment/addresses.json),
[demonstration header](../deployments/current/sepolia-2026-09-10/demonstration/anchor-block.json)
and [native readbacks](../deployments/current/sepolia-2026-09-10/demonstration/pinned-readbacks.json)
are byte-pinned by the recipe helper. Their original JSON is retained unchanged,
including historical large integer values. The helper writes a separate canonical
anchor and records the evidence pins in `recipe.json`.

## Prepare, capture, verify

Use the isolated [Museum Python environment](../tools/museum/README.md) from the
repository root. The output parent, here `out`, must exist. Every output directory
must be new.

```text
python -m tools.museum.rc1_ownership_recipe --disclosure public --output out/rc1-ownership-recipe
```

This produces `anchor.json` and `recipe.json`, with these exact input pins:

- Anchor Keccak-256:
  `0xfbfa4641dc437a7021a40bafd4fdd040b05566bb52ca94dfbe7de03e1ae8f9b9`.
- Public ownership source profile:
  `0xee8aa538afdbab3e79051ffc52cacbae63fdb26b44557f28e28cf1709319cc6d`.

Admit the retained release/source evidence and configure `STREAM_PUBLIC_RPC`
through the local credential workflow. The provider must serve historical logs
from block zero through 11,678,119, as well as exact hash-pinned state/code and
full receipts. Then run:

```text
python -m tools.museum.public_history_capture capture --kind ownership --anchor out/rc1-ownership-recipe/anchor.json --anchor-hash 0xfbfa4641dc437a7021a40bafd4fdd040b05566bb52ca94dfbe7de03e1ae8f9b9 --source-profile-hash 0xee8aa538afdbab3e79051ffc52cacbae63fdb26b44557f28e28cf1709319cc6d --rpc-env STREAM_PUBLIC_RPC --disclosure public --output out/rc1-ownership-capture

python -m tools.museum.public_history_capture verify out/rc1-ownership-capture --manifest-hash 0x<printed-result-manifest-hash>
```

Retain the printed manifest hash independently. Capture verifies itself offline
before atomic publication. A later verifier reruns every source check using only
the retained transcript. The initial query schedule has 234 windows for this
one-token filter; provider limits can require further subdivision. Returned logs,
receipts and native state must all reconcile. Source provenance and log
completeness retain the explicit [public-history trust boundary](museum-public-history-capture.md).

### Observed provider limitation

On September 20, 2026, a read-only attempt against the public endpoint used by
the repository's Sepolia script failed on the first `eth_getLogs` range
`0..49999`. The provider returned error code `4444` indicating pruned history.
Chain ID and the pinned source header reads had succeeded. No capture directory
was published, so no new RPC capture or offline replay success is claimed here.

The attempt also showed that this endpoint rejected Python's default User-Agent;
the public transport now identifies itself as `6529Stream-readonly-capture/1`.
That HTTP header leaves all transcript and profile definitions unchanged.
Pruned-history failures still abort. Use an admitted provider retaining the full
required range; the recipe does not substitute empty pages or a later start block.

## Why RC1 cannot use the current entropy reader

The original coordinator is
`0x258d07d853be34ac022f24e255f02a21d6d340b5`, with runtime Keccak-256
`0x9d18e73e88de146103a03b1dfc0ec5953b92f825535c50276847602736d73ffb`.
Its retained ABI lacks all four current getters:

- `registeredAtBlock(uint256)`;
- `collectionProviderEpoch(uint256)`;
- `requestPolicySnapshot(bytes32)`;
- `freshRecoveryReceipt(bytes32)`.

RC1 has no `EntropyRecoverySuperseded` producer. Its source fixes epoch and
attempt to one and permits the original request from `REGISTERED`. Shared
interface IDs, tuple layouts and version strings do not supply the later policy
and recovery evidence. The [current public entropy reader](museum-public-mint-entropy.md)
therefore fails on this deployment. A future RC1-specific entropy profile would
need to derive and qualify historical facts from that exact source; it cannot
fabricate current getter returns or establish current-stack acceptance.
