# Current Artist ceremony packets

`6529 Stream Artist Ceremony` version `0.1.0` captures a human-readable review
packet for the eight typed families currently exposed by `current-artist.ts`:
Artist binding acceptance, policy consent, economics consent, payout designation,
Artist attestation, content ratification, collaborator identity acceptance, and
collaborator binding acceptance.

Every signed field needs a label, a human-readable meaning, and a public source.
Known hash commitments such as `policyHash`, `assignmentHash`, `bindingHash`, and
content or statement hashes also need their UTF-8 or raw hex preimage. Raw
identifiers such as `phaseId`, `subjectId`, `schemaId`, `role`, and `shareLabelId`
instead need their reviewed representation; the client does not pretend that an
arbitrary identifier is a keccak hash. It hashes actual commitment preimages
locally and independently recomputes the EIP-712 digest. A packet
cannot be prepared for submission if any signed field, schema coordinate, or
commitment changed after review.

Before presenting the packet to a wallet, call `inspectCurrentArtistCeremony`.
It pins one block, checks the RPC chain and facade digest, applies the contract's
deadline or `signedAt` rule, and reads the applicable replay lane. Direct calls
must use the current allocator hint. Relayed calls may use another still-unused
nonce. Collaborator identity acceptance uses its distinct persistent account
nonce lane.

For collaborator binding acceptance, the `artist` authority locator is the
collaborator's own registered Artist identity returned by `activeIdentity` for
the signed collaborator account. It is distinct from the collection's primary
Artist identity. The current ABI does not expose a combined lookup-and-replay
read, so callers must resolve and display that identity before review.

```js
const reviewed = await reviewCurrentArtistCeremony(provider, {
  kind: "artistPolicyConsent",
  chainId: "11155111",
  registry: artistRegistry,
  message: { core, mintManager, collectionId, phaseId, policyHash, nonce, deadline },
  context: {
    signer: artistSafe,
    walletClass: "safe-erc1271",
    executionMode: "direct",
    authority: { kind: "artist", artistId },
    facts: [
      // One entry for every signed field. Hash entries include the exact preimage.
    ],
  },
});
```

The disclosed wallet classes are `eoa` and `safe-erc1271`; both may use direct
or relayed authorization where the current contract permits it. For policy and
economics consent, call `assertCurrentArtistConsentCurrent` with a freshly
recomputed `policyHash` or `assignmentHash` immediately before signing. If it
changed, discard the packet and present the changed facts as a new ceremony.

Direct payout designation and direct attestation use the current facade's zero
`signedAt` sentinel. The writer replaces zero with the transaction block time,
so the preflight getter proves only the submitted sentinel tuple and schema; it
cannot know the effective digest or record hash before execution. The observation
marks this as `execution-time-sentinel` and applies nonce/revocation checks that
do not depend on that future digest. Relayed payout and attestation instead need
an explicit nonzero `signedAt`, and their observed digest is exact.

This helper performs no transaction, nonce reservation, signer-authority proof,
or write simulation. Passing its read checks does not establish mint readiness
or successful execution. It does not yet cover the other Artist signature
families, record hashes, `bindingHash`, `sanctionSubjectHash`, measured ceremony
latencies, acknowledgment capture, or the full onboarding-to-sanction rehearsal
required by `AA-TOOLING`.

The two replay reads are a compiler-selected fixture, not handwritten ABI. Rebuild
or verify it from the retained compiler artifacts with:

```sh
node scripts/generate-current-artist-ceremony-fixture.mjs \
  /path/to/abi-input.json /path/to/abi-output.json 0d7c1b57 --check
```

The generator hashes the exact compiler input/output bytes and the source text
embedded in the compiler input. The retained source text uses the same bytes as
the current checkout (`sha256:d662c96043e4fd1809bba76da045e05ce8df921b2e8c6dc2fe05b05ed22fe994`),
so no CRLF-normalized surrogate is used for provenance.
