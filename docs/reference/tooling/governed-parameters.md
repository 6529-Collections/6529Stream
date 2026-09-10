# Governed Parameters reference

This is detailed maintainer reference. Start everyday work with the
[developer commands](../../tooling.md); run aggregate release validation only when
preparing the corresponding evidence. Commands below run from the repository root.

## Governed Parameter Identifier Catalog

Run the closed-world GGP/GTP identifier gate with:

```bash
make governed-parameter-identifiers-check
```

The target runs:

```bash
python -m tools.protocol.test_governed_parameter_identifiers
python -m tools.protocol.check_governed_parameter_identifiers
```

The checker pins the launch catalog to exactly 22 GGP names and three GTP
names in the [LTA-GGP]/[LTA-GTP] inventories and their target-architecture
mirror rows. It requires the unique governed-identifier section and rejects
every malformed or extra table row. It verifies row order, `GGP_`/`GTP_`
catalog labels, canonical string preimages, recomputed Ethereum Keccak hashes,
identifier schema version, exact target Owner/Inputs cells, exact LTA
host/normative-home cells, the GTP coordinator home, and exactly one live
generic host derivation using each canonical `6529STREAM_GGP_` and
`6529STREAM_GTP_` prefix after stripping Solidity comments. The generic hosts do not
declare one Solidity constant per parameter ID; the checked guarantee is exact
prefix derivation plus the closed-world inventory/mirror correspondence.

The focused regression suite rejects hash drift, unilateral inventory
deletion, coordinated catalog deletion, malformed/extra rows, owner/home/input
drift, missing section identity, host-prefix drift, and commented-out canonical
derivations. The gate is wired into `make check`, both aggregate shell wrappers,
the release-manifest dependency chain, and CI.


## Governed Parameter Production Inventory

Run the schema-validated launch-inventory gate with:

```bash
make governed-parameter-inventory-check
```

The target runs:

```bash
python -m tools.protocol.test_governed_parameter_inventory
python -m tools.protocol.check_governed_parameter_inventory
```

The checker validates
[`release-artifacts/governed-parameter-inventory.json`](../../../release-artifacts/governed-parameter-inventory.json)
against
[`governed-parameter-inventory.v1.schema.json`](../../../release-artifacts/schema/governed-parameter-inventory.v1.schema.json).
It recomputes the exact 22 GGP and three GTP IDs, requires complete logical-row
coverage and all 50 profile-host bindings, and pins raise-only policy plus the
absence of standalone parameter probe contracts and probe bindings,
immutable-floor requirements, failure classes or cadence rules, evidence
bindings, guarded-consumer inventories, and known fixed-stipend compatibility.
Multi-host rows are exact: the four adapter-only sale parameters bind all four
launch sale adapters, `DELEGATE_REGISTRY_GAS_LIMIT` binds the delegate gate
plus those four adapters, and
`VRF_CALLBACK_GAS_LIMIT` binds both the primary VRF provider and whichever
ARRNG-or-Pyth callback provider the genesis profile selects. The shared
`ROYALTY_RETURN_GAS_BUFFER` policy covers Core completion after
`royaltyInfo()`, `tokenURI()`, and `contractURI()` and requires floor/evidence
for the worst measured parent-side work across those paths. Its dedicated
`shared_buffer_planning` record binds the issue #671 target-fixture checksum,
1,460,000 planning floor, 2,910,000 planning genesis value, 64-byte royalty and
65,536-byte metadata limits, class-1 delayed independent raise-chain semantics,
and the explicit candidate fixed-stipend production conflict.

The committed artifact uses explicit `not_available` candidate bindings where
concrete deployment facts or reviewed evidence do not exist. That is valid for
the ordinary aggregate check and is not a readiness claim. Each current
`guarded_consumers.status` is likewise `planning`: the named consumers are
review seeds, not an assertion that every call site has been found. The
production decision runs:

```bash
python -m tools.protocol.check_governed_parameter_inventory --require-complete
```

Strict mode rejects every unavailable or incomplete candidate binding,
including a missing required host instance, candidate value/floor, evidence
digest/status, non-complete guarded-consumer inventory, or fixed-stipend
compatibility decision. The schema reserves exact candidate-instance, source,
address, runtime-code-hash, immutable-authority, host-local value/floor,
failure/cadence, revision, and source-verification facts. The checker still
rejects every self-reported `complete` candidate until issue #656 supplies the
structured production-candidate model and reconciliation checker; no opaque
file can clear that boundary. Complete measurement/cadence and fixed-stipend
evidence is likewise categorically rejected until issue #684 adds exact
candidate-instance binding, recomputable results, reproduction artifacts, and
reachable raise-chain semantics. It is called directly by production release
mode; public-beta mode remains non-strict.
`check_release_mode.py` accepts
`--governed-parameter-inventory PATH` for a reviewed candidate artifact and
defaults to the canonical file; the path must remain inside
`release-artifacts/`, and the production phase always passes
`require_complete=True` to its validator. The artifact, schema, checker, and
tests are checksum-covered, and release-manifest generation/check depends on
the ordinary inventory target so stale policy cannot enter the generated tail.
The offline release verifier additionally requires the release manifest and
candidate lockfile to carry matching canonical inventory records.


## Governance V2 Action Policy

Run the closed-world action/native-value gate with:

```bash
make governance-action-policy-check
```

The target runs:

```bash
python -m tools.protocol.test_governance_action_policy
python -m tools.protocol.check_governance_action_policy
```

The checker validates
[`release-artifacts/governance-action-policy.json`](../../../release-artifacts/governance-action-policy.json)
and its
[`governance-action-policy.v1.schema.json`](../../../release-artifacts/schema/governance-action-policy.v1.schema.json)
schema. It pins the exact source-level action-class, target-profile, and selector
lookup key and all three ABI/Keccak domains, requires the exact zero-value
limit/hash default, rejects generic proxy, multicall, fallback-dispatch,
delegatecall, and unregistered-module routes, and verifies that the Executor
compares the catalog against the separately stored manifest
candidate/catalog/count commitment and validates every selected entry hash at
scheduling and execution. Validation is proportional to selected calls rather
than the catalog's recorded 1,024-entry ceiling. The release manifest binds both
the policy and its exact schema identity, digest, and size.
For a complete candidate it also requires policy-key ordering, rejects routes
that do not expand from the reviewed source/native catalogs, and independently
recomputes the ABI-encoded onchain catalog commitment from the chain ID, exact
Executor address, candidate profile, target addresses, runtime code hashes, and
value-policy rows.
Candidate binding remains honestly unavailable until issue #656 supplies exact
addresses and runtime hashes. The ordinary gate accepts that explicit blocker
but rejects a fabricated or commitment-inconsistent complete candidate;
`RISK-GOV-003` cannot close until
candidate deployment, rehearsal, monitoring, and independent-review evidence
are linked.


## External-Call Gas Inventory

Run the deterministic external-call gas policy gate with:

```bash
make external-call-gas-inventory-check
```

The gate runs `tools/protocol/test_external_call_gas_inventory.py` and
`tools/protocol/check_external_call_gas_inventory.py` across every Solidity source
under `smart-contracts/`. It masks comments and strings, inventories every
high-level Solidity call-option gas expression, and inventories every Yul call
gas argument except the exact Yul `gas()` builtin. A high-level function named
`gas` or `gasleft`, and a Yul helper named `gasleft`, therefore cannot imitate
the builtin exception. The checker exact-matches literal integer `constant` or
`immutable` gas-cap/reserve declarations, including constructor-assigned
immutables. It also rejects direct numeric assignments and numeric
struct-literal fields that feed an inventoried identifier or member-valued
call-gas argument. Parentheses and integer casts around one literal are
normalized; arithmetic literal initializers fail closed because their
effective value cannot be represented by the exact lexical inventory.
Solidity `.transfer(...)` and `.send(...)` calls, including whitespace- or
comment-separated spellings, are rejected because their implicit native-value
stipend is another fixed external-call gas policy. New sites, added uses,
removed sites whose inventory row was not retired, literal-value drift, and
missing inventory all fail.

The canonical inventory is
[`ops/EXTERNAL_CALL_GAS_INVENTORY.json`](../../../ops/EXTERNAL_CALL_GAS_INVENTORY.json).
Its finality, minting, revenue, and entropy rows are temporary open remediation work
tied to issue #669. They are not accepted-risk exceptions and must be removed
or connected to the Global Gas Parameter system in later focused slices. The
call-row taxonomy reserves `artist-authority` under the controlling
successor-architecture taxonomy decision for one exact future
`smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol`
`_validateSignerProof` low-level `staticcall` call option: expression
`context.erc1271GasCap`, count `1`, `user-path`, issue `#669`, and
`open-remediation-required`. ADR 0022 and its interface packet remain Proposed
and do not authorize implementation. The source and row remain absent; a future
successor source slice may add them only after architecture and packet
acceptance. Either the reserved path or lane activates exact-field validation,
while literal-declaration rows cannot use the
`artist-authority` lane. The scanner assigns a low-level operation only to the
explicit built-in address conversion forms
`address(<receiver-expression>).call{gas: ...}`,
`address(<receiver-expression>).delegatecall{gas: ...}`, and
`address(<receiver-expression>).staticcall{gas: ...}`. Uncast members and typed
interface methods, including a method named `staticcall`, remain
`external-call`. The exact historical `StreamMintGateValidator._callGate`
source and `external-call` inventory row therefore remain unchanged without a
compatibility rebind; an inventory operation change, row removal, or paired
uncast source/row operation drift fails closed. This reservation does not prove
GGP provenance,
candidate deployment binding, a safe parent reserve, or ERC-1271
gas-exhaustion behavior; those remain required #669/#684 remediation and
evidence. The inventory is strict duplicate-free I-JSON: object keys are
exact, floats,
non-finite values, unsafe integers, and Unicode surrogates fail closed. The
v1 `explicit_probe_call_gas_expressions` member is retained for schema
compatibility but must be exactly empty; the checker rejects every attempted
exception row. Because this is a lexical policy gate rather than a Solidity
data-flow engine, normal review and focused behavioral tests remain required
when gas is computed through helper functions or structured state.

