# Entropy provider epochs and request records

`StreamEntropyCoordinator` exposes the additive
[`IStreamEntropyEpochs`](../smart-contracts/interfaces/stream/entropy/IStreamEntropyEpochs.sol)
read interface. Existing coordinator, token entropy, configuration and request
getters keep their argument and return shapes.

A collection starts at epoch zero before configuration. Its first valid provider
configuration becomes epoch one. Replacing the provider or changing its declared
configuration hash increments the epoch, including when returning to an earlier
provider. Repeating the same provider/configuration does not increment it. Timing,
request-access, funding and pre-mint salt changes do not by themselves change the
provider epoch. Salt still participates in the frozen policy and final seed.
`CollectionEntropyEpochConfigured` reports the epoch and configuration hash
alongside the retained configuration event.

The first token or scope registration still locks the collection policy. Core
collection freeze and the existing authority checks still apply. These epochs
track permitted pre-mint revisions; they do not add migration after mint, fallback
requests, fresh-randomness recovery or instant entropy.

Before calling the provider, the coordinator records the provider address and
code hash, epoch, provider configuration hash, collection salt, subject input
commitment and attempt number under the canonical request key. Read that record
with `requestPolicySnapshot`. Unknown or reverted requests return zeros. Provider
submission failures roll the record back with the rest of the request.

Provider context, token/scope request keys and derived seeds use the recorded
epoch. Fulfillment derives the seed from the saved request inputs, and
`tokenEntropy` reports those saved facts after submission. Later changes in a
provider's own configuration do not rewrite an accepted request's inputs. The
existing provider authentication, revocation and one-result checks still apply.

Epoch-one request, seed and finality-policy preimages remain unchanged. A
collection that changes provider identity before registration uses the explicit
`6529STREAM_ENTROPY_PREMINT_EPOCHS_NO_FRESH_RECOVERY_V1` finality profile with its
actual epoch. Both profiles commit to the absence of fresh recovery.

The focused [epoch tests](../test/unit/entropy/StreamEntropyEpochs.t.sol) cover
revision ordering, literal provider contexts and key/seed/policy preimages,
authority and registration locks, rollback, token and scope callbacks, and
bounded fuzzing of repeated revisions. They use the actual coordinator/provider
with a typed Core fixture. Whole-system activation, Safe composition and release
acceptance remain part of consolidated validation.
