# Artist authority implementation

`StreamArtistOnboardingRegistry` is the ingress for the first executable artist
profile. Its address is the identity used in artist IDs, EIP712 domains, binding
records, owner configuration, and archive evidence. `StreamArtistRegistryV2`
remains the earlier immutable directory; it does not own these new records.

The supported profile is `ARTIST_SIGNED_POLICY`, `PRIMARY_ONLY`, no collaborators
or capability overrides, and operator-set sale parameters. Operations 1, 2, 14,
15, 18, 24, and 52 have typed entrypoints. The full 57-operation API is not
advertised, and this implementation does not provide recovery, delegation,
estate administration, platform works, collaborator changes, or terminal
finality operations.

Use the caller interfaces under `interfaces/stream/artist/`:

| Caller need | Interface |
| --- | --- |
| Propose, accept, and record the supported artist authorizations | `IStreamArtistOnboarding` |
| Manager consent checks and dependency reads | `IStreamArtistMintConsent` |
| Accepted attribution for metadata and other readers | `IStreamArtistAttribution` |
| Existing content ratification | `IStreamArtistContentRatification` |
| Immutable owner identity, snapshot, and replay cell | `IStreamArtistOwner` |
| Each domain's typed reads and coordinator-only writes | The seven `IStreamArtist*Owner` interfaces |

`StreamArtistOnboardingTypes` owns the shared payloads. The `Authorization.time`
field is a deadline for acceptance, policy, economics, and ratification; it is
the signed timestamp for payout and attestations. These ABI tuples preserve the
specified EIP712 field order inside each digest. The EIP712 name is
`6529StreamArtistRegistry`, version `1`.

The immutable coordinator authenticates the original caller, obtains typed
facts, and runs the ordered owner actions. Binding, Collaborator, Identity,
Acceptance, Attribution, Payout, and ConsentFinality are separate owners in that
order. Each checks its own prior snapshot before a mutation. The final ArchiveV2
append is atomic with every owner write and nonce consumption. The archive is
evidence storage, not a current-state authority. Identity reuse across a second
collection validates the existing identity without re-registering it or changing
its liveness; Binding and Attribution own the new collection records.

All floors are required both at phase registration and before mint effects:

- Accepted binding and consent over the exact prospective Manager policy hash.
- Operative artist payout designation.
- Consent over both actual collection-level primary and ERC2981 assignments.
- Ratification matching the currently selected router's live content commitment.
- Deployment attestation matching the current binding generation.
- Personhood evidence or an explicit waiver bound to the operative identity record.

A waiver records the absence of evidence. It does not certify a person. Fixed
split profiles must actually pay the designated artist account when economics
consent is recorded. A later payout designation does not rewrite an existing
fixed split wallet. Unknown or dynamic assignment modes are rejected by this
initial profile.

Policy consent can be recorded before Manager registration. Use
`IStreamMintReads.previewPhasePolicyHash` with the intended executor set. Manager
pause is outside the policy hash and never calls the artist registry or
re-registers the Ledger. Content ratification does not authorize a later content
write: the separate typed content-consent operation is required before that
mutation can be supported.

EOA signatures use canonical ECDSA. Contract signatures remain opaque, bounded
ERC1271 proof bytes. For a Safe, threshold owners sign the handler's SafeMessage
wrapping of the Stream digest, or approve that message through the real Safe
SignMessageLib. An approved empty proof is a valid relayed contract proof. A
direct artist call with empty proof consumes the current unused allocator nonce;
long-lived records must supply the current block timestamp. A Safe owner's EOA
has no implicit authority belonging to the Safe.

The focused onboarding tests use real owners, archive, split factory, primary
resolver, Manager, Ledger, and official Safe 1.4.1 bytecode. Their explicitly
named Core, metadata, royalty, registry, and governance doubles isolate protocol
boundaries. Those tests are not substitutes for the separate real current-Core
integration and governed-provider tests.
