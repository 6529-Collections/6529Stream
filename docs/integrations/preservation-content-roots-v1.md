# Preservation content roots V1

The Router exposes separate preservation publication interfaces for COLLECTION
and TOKEN/RELEASE/SEASON. These implement the explicit output interpretation in
[ADR 0054](../adr/0054-explicit-non-sanction-preservation-rendering.md).
The existing original and policy V2 interfaces retain their byte rules.

## Calls and ordering

| Scope | Preview | Publish | Historical binding |
| --- | --- | --- | --- |
| COLLECTION | `previewPreservationPolicyContentRootPublication` | `publishVerifiedPreservationPolicyContentRoot` | `preservationPolicyContentRootBinding` |
| TOKEN, RELEASE, SEASON | `previewScopedPreservationPolicyContentRootPublication` | `publishScopedPreservationPolicyContentRootPublication` | `scopedPreservationPolicyContentRootBinding` |

Use the [collection interface](../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol)
or [scoped interface](../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicyContentRootPublicationV1.sol).
Each is separately advertised by the Router through ERC-165. These calls are
nonpayable and accept the existing corresponding `Publication` tuple. A Safe
may be the publisher using ordinary CALL; the original writer grants and
Artist consent requirements still apply to its address.

For COLLECTION, publish a verified preservation output manifest, preview the
root for the actual publisher, obtain the original operation-17 CONTENT_ROOT
authorization, then publish the root. Its snapshot follows the root. For scoped
publication, the preservation snapshot precedes the root. See
[the consumer guide](preservation-policy-consumers-v1.md) for these dependencies.

The preview commits the next collection-wide CONTENT_ROOT family, including
the existing scoped aggregate. A publisher needs the existing class-7 or
class-8 SNAPSHOT grant. This grant alone cannot consume Artist consent: the
existing shared content authorization verifies the exact next family and
records its application after publication. Sources are checked again inside
publication, so late changes revert the whole transaction and consent use.

## Read semantics

Collection bindings have 19 ABI words (608 bytes); scoped bindings have 25
(800 bytes). They include the exact Router and preservation output profile.
Their complete ordered output root binds each member's admitted producer,
runtime and evidence. A zero binding profile means this historical record has
no binding in that particular preservation namespace.

The common heads and historical records remain in the original Router storage
and share the original predecessor and consumed-consent books. Common root
reads return `STREAM_PRESERVATION_POLICY_TOKEN_CONTENT_LEAF_V1` for these
preservation records. Original V1 and V2 roots retain their own leaf schemas.
An empty root has no leaf schema; scoped reads reject mismatched scope or
ambiguous preservation interpretation. Historical record retrieval remains
available after a successor publication without asserting currentness.

Preservation root events use common schema version 3 and companion binding
event version 1. This identifies the interpretation explicitly; live rendering
continues to include sanctions, which require separate archive evidence.

## Verification boundary

The shared facade, dispatcher and reads have an integrated ABI/type check.
Sixteen authored writer cases now exercise the actual shared dispatch and
authorization sequence; eight additional read cases cover literal leaf schemas,
binding widths, namespace isolation, immutable history, refusals and fuzzed
payloads. Their execution against this combined source remains pending.
The writer fixtures explicitly model Artist consent and validated evidence;
they do not constitute full Router, original op17 signature, Safe, finality,
maximum-scope gas or linked deployment acceptance. VIEW has its own worker and
binding and is not covered by these interfaces.
