# Scoped full-policy provider and discovery

This additive TOKEN, RELEASE and SEASON consumer path joins the
[fixed publication recipe](scoped-policy-preservation-v2.md) to the existing
finality interfaces. Its source has ABI and review evidence; native execution,
deployment size, transaction gas and complete finality acceptance remain pending.

## Fixed configuration and deployment order

`StreamFinalityScopedPolicyEvidenceProviderV2` retains the original COLLECTION,
scoped V1 and COLLECTION policy V2 configurations. Its additional constructor
argument is `IStreamScopedPolicyPublicationEvidenceBindingV2.FactoryBinding`:

| Field | Meaning |
| --- | --- |
| `factory` | Genuine fixed publication recipe factory |
| `factoryCodeHash` | Exact expected factory runtime |
| `recipeHash` | Factory's immutable recipe identity |
| `sourceFactoryDependenciesHash` | Original scoped entropy factory dependencies |
| `graphGas` | Bounded budget for validating the genuine current graph |
| `configurationHash` | Zero when constructing the provider; computed by that provider |

The provider validates the factory profile, recipe, fixed shared topology and
original source pins. Its configuration hash binds the chain, provider address,
original configuration and all five supplied binding fields. There is no setter
for the factory, recipe, implementation or selected source host.

Read `scopedPolicyPublicationBinding()` after provider deployment. Supply that
complete returned binding, together with `finalitySourceConfigurationHash()`, to
`StreamFinalityScopedPolicyProfileDiscoveryV2`. Discovery verifies the exact
provider binding and factory recipe. Both constructors can precede minted-scope
children: neither asks for a current graph or a scoped publication.

The original reciprocal Registry, Core adapter, Artist, Metadata and Router
configuration requirements remain in force. Their expected deployment identities
must be planned before construction; this addition does not resolve an arbitrary
deployment topology or provide mutable late binding.

For each scope, create the factory's seven children and complete the publication
sequence in the preservation guide. The selected provider can resolve the
genuine snapshot child before a root exists, allowing snapshot publication and
Router root adoption to occur in that order.

## Closed profile selection

The provider retains the three original catalogue entries at indexes 0 through
2. A scope-specific V2 graph is obtained through `finalitySourcesForScope(scope)`;
it is not a fourth fixed catalogue entry.

The actual Router head and explicit interpretation binding select the branch.
Non-COLLECTION selection requires the Router's new scoped-policy content-root
capability, including when retaining scoped V1 behavior. On that capable Router,
an absent scoped head or completely empty V2 binding retains original scoped V1
selection. The exact new profile selects the genuine current factory graph.
Unknown tags or a partially populated empty-tag binding fail closed. COLLECTION
continues through its original selector. VIEW remains a separate route.

Current graph validation checks the exact scope, original source plan, source
runtime, all seven children and their constructor dependencies. The selected
reference and snapshot must be the factory's actual children, and the root must
name that graph's output, checkpoint, source set and source factory. A caller
cannot supply a replacement reference or snapshot host.

Discovery preserves the original component order, independent component checks,
Artist/Registry guards and public interfaces. Its scoped V2 reference pin comes
from the exact genuine graph. Source selection reads identities and topology;
reference, inventory and component evidence are checked in their own later
stages, avoiding a publication dependency cycle.

## Bounded nested reads

Scalar reads and graph validation have different budgets. Provider construction
requires `graphGas` to be at least the original `readGas`, at most `uint32.max`,
and requires:

```text
componentSourceGas > graphGas + graphGas / 63 + readGas + 200000
```

The Router reads the cheap `scopedPolicySnapshotValidationGas(scope)` first,
checks it against the scalar minimum and `uint32.max`, then uses that declared
budget for the scope-specific snapshot address and runtime reads. Existing
provider, Registry, route, profile and reciprocal dependency checks still apply.

Discovery uses its configured `componentGas` for the provider's source-selection
call, and requires `componentGas > graphGas + graphGas / 63 + 100000`. This is a
constructor minimum, not a proof that a chosen budget is sufficient. The actual
provider must materialize its fixed context and validate the graph within the
budget; the caller must also retain the nested call's reserve. Establish usable
settings through native execution and transaction measurements on the final
linked graph.

## Evidence and authorization

The scoped provider checks distinct snapshot, reference, output, checkpoint,
inventory and bundle capabilities before decoding their tuples. Current
inventory and matching archive coverage supply the original ten input fields.
Exact root/snapshot/reference headers and literal scoped Core facts complete the
statement; original manifest registration and canonicalization are retained.

Immutable record projections are used only after the appropriate current source
or lock validation. Each of the six STATIC component families authenticates the
actual snapshot lock before projecting its original source. Metadata facts keep
the original WORK, RIGHTS and conservation requirements. Sanction review retains
ordered canonical PNG identities, Artist identity and the original reference
record. Terminal zero-seed output remains distinct from finalized randomness.

Both prepared provider entry points check the original Registry caller and
runtime before profile selection. Deployment, source selection and a valid
publication graph alone do not authorize finalization.

See the [source handoff evidence](../../artifacts/scoped-policy-finality-v2.md)
for authored test boundaries and validation details.
