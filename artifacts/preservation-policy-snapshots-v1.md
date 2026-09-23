# Preservation snapshot source checkpoint

Base: `81aa9db91c24bd9dd808391d869c27182e5fb074`.
This batch follows [ADR 0054](../docs/adr/0054-explicit-non-sanction-preservation-rendering.md)
and adds the snapshot portion of the preservation consumer pipeline.

## Scope

- COLLECTION snapshot: exact current covered manifest, complete frozen policies,
  original Artist identity and current canonical root with all 19 preservation
  binding words. The root still precedes the snapshot.
- TOKEN/RELEASE/SEASON snapshot: exact current covered manifest, full ordered
  membership, complete frozen policies and actual scoped source-factory route.
  The snapshot still precedes its root.
- Both retain original publication grants, immutable history, predecessor/chain
  checks, payload/chunk verification and class-2 locks. New capabilities, hash
  domains and exact schema documents identify their separate interpretations.
- Closed graph/factory and provider-binding interfaces for later construction.
  This batch implements no factory, provider, inventory or shared Router writer.

The two test hosts contain 23 authored cases: nine COLLECTION and fourteen
scoped. They use the new complete checkpoint and covered output with original
membership, source policy, schema/store and coverage components. Producer,
Registry admission, Artist and COLLECTION prior-root boundaries are identified
in the fixtures. All original test bodies survived fixture-helper extraction.
These boundaries do not prove B's actual governed producer or the real root
writer. Both hosts include actual 2-of-2 Safe late-failure/identical-retry cases.

## Validation and dependencies

ABI-only capture: `artifacts/art27-gap3/preservation-snapshots-interfaces-final`.

- Solidity 0.8.19: 484 imported sources, zero errors.
- Input SHA-256:
  `4c57bcd34b433b4a7c30d33e9ee9bea298820798b260914ffd7fbf81a622a026`.
- Output SHA-256:
  `c1b2935c0b4d3ced698c238d5ded31c7d6245449033b27f654c70f8a6eea3c21`.
- All 481 non-borrowed captured sources match staged Git blobs exactly;
  `index-bridge.json` records the three borrowed raw pins below.
- Independent source review covered both snapshot families and their tests.
  The combined check caught and corrected a new COLLECTION import alias
  collision before freezing this capture.
- Formatting, exact schema literal/document parity, documentation links and
  Windows whitespace checks pass.

Borrowed interfaces and schema helpers belong to their producer/writer owners
and are deliberately excluded from this commit. The captured closure includes:

| Borrowed source | Raw SHA-256 |
| --- | --- |
| `IStreamPreservationRegistryV1.sol` | `ca12e63188ef8874a60ddfe488d62ca42a7eeba2d21dc4090490d265e173df5f` |
| `IStreamPreservationPolicyContentRootPublicationV1.sol` | `18e18a23acf84e815815d980016e25c584bd706d82be2339561e145638878a6b` |
| `StreamPreservationPolicyContentRootSchemasV1.sol` | `97b531ff9f1571dc3dfd479c71999832adcef4798b2dff6fd787d49c189aec3b` |

Integration must include those exact compatible definitions and their governed
implementations. ABI compilation generates no executable bytecode. Native test
execution, fuzz execution, linked bytecode sizes, gas and the complete real
sanction/archive/finalization/confirmation ceremony remain pending. The separately
frozen original `71ff` 27-case native run cannot validate this new source.

The [consumer guide](../docs/integrations/preservation-policy-consumers-v1.md)
records the stable ABI and remaining reference, inventory, factory and provider
work. No deployment, broadcast or release-evidence regeneration is included.
