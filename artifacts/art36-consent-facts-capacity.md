# Recovered combined consent facts capacity

Base: `836b9c64e1f0630d4e79e6cee831450059616fd7`.
Branch: `codex/recovered-consent-facts-capacity`.

## Change and consumer boundary

The combined delegated-consent and attestation validators exceeded the runtime
limit. Their public entry points now project only consumed fields into separate
linked row validators. The complete original validator bodies, constants and
helpers are retained in those workers. Independent mechanical and source review
confirms projection completeness and semantic check order.

PreparationJoins calls three fixed public Combined selectors: `badf15eb` for the
five-argument delegated join, `0760763f` for its attestation overload and
`df5790fd` for the content overload. Its separate attestation call uses
`c5615551`. All four nominal selectors and return shapes remain unchanged.
Typed source calls and externally consumed Registry/Prepared/client interfaces
remain unchanged. Client source evidence is not refreshed by this change.

The first overload starts with no additional uses. The second adds original
operation 24 uses before the base join. The third checks original operation 20
uses, then operation 24, sums them and runs the base join. Complete grant-use
counts, policy/economics/sale grant checks, sale admission chronology, attestation
record/signature/nonce checks, replacement and revocation ordering all remain.
No storage transition or authorization policy changes.

## Selected native evidence

The final capture uses the frozen four-file working source over the base above,
with Solidity 0.8.19, viaIR, optimizer 200, Paris, no CBOR and no bytecode hash.
It compiles the exact 78-source import closure and selects these six products.
Compilation completed in 32.078 seconds with zero errors.

| Product | Runtime bytes | Bare creation bytes |
| --- | ---: | ---: |
| DelegationConsentFacts public facade | 9,650 | 9,682 |
| DelegationConsentFactRows | 8,424 | 8,456 |
| AttestationFacts public facade | 5,197 | 5,229 |
| AttestationFactRows | 13,323 | 13,355 |
| ContentConsentFactRows | 8,235 | 8,267 |
| HydrationChronology | 5,416 | 5,448 |

Every selected runtime is below 24,576 bytes, and every selected bare creation
is below 49,152 bytes. The compiler confirms all four public nominal selectors.
Capture: `artifacts/selected-workers/combined-attestation-calldata-v2`.
Input SHA256:
`bd72f5b2bd14d080c7d5f9bc4dd5561b9c587df876e610a28ed000cb7b370f26`.
Output SHA256:
`163b75232bd0d8c12d83bbe2693be74a820b469522acc6facb13fea3e8e47743`.

Independent artifact review verifies all 78 source bytes and hashes, exact import
closure membership, the six selected/output/result products, every reported
bytecode length, nominal selectors and compiler settings. There are no warnings
or errors and stderr is empty. Linked-address placeholders are included in the
measured lengths. This selection is not a complete deployment graph:
AttestationFactRows also links DelegationState and RecoveredHydrationProvenance,
and DelegationConsentFactRows links DelegationState. Their source is captured,
but their bytecode and further dependencies remain separate size evidence.
Separate ABI-only compilation covers 1,143 sources with zero errors.
Input SHA256:
`0d965a966858917264f5e547ee661609e600b8638596d353fd49597cc9d64460`.
Output SHA256:
`fbfb7089abc1060801261627798f63ae5a6849c9ce0d865aa53caf9835a8bc49`.
Existing source tests cover all three combined call shapes and the attestation
facade, including mixed counts, chronology and malformed consumed fields.
Their runtime execution at this later source remains pending integration.

Frozen source SHA256 values:

- DelegationConsentFacts:
  `eaccba1c94eb5164d6399c6efbd0c4456dbad874d478426b27307e7431a9d1c0`
- DelegationConsentFactRows:
  `1cf58ce016f4fb3e3a04c81421c69bbeb16d3451587d3e3acaae101a136a75940`
- AttestationFacts:
  `c734120192fef2778da7521c3897c23d204fa383c7688e8afba5e8504b54346e`
- AttestationFactRows:
  `2fcfe75dbab305677304801209465d4a4056f744293664d4fcddb4312f1fb0b9`

## Canonical input qualification

Changing a public parameter from memory to calldata can change rejection of
malformed unused ABI fields. An invalid bool in an unused Identity head need
not be deeply decoded by the projection. This applies to every calldata facade
variant. Semantic checks and their order for canonical typed input remain the
same; unconditional malformed raw-calldata parity or decoder-versus-semantic
error-order parity is not claimed.

Independent review of the Prepared owner's current source verifies that Identity
bytes originate only from the fixed IdentityRead/Source pipeline. The pipeline
authenticates the original owner/code hash and original records. Transport
constructs the bundle through Export.exportBundle and abi.encode. Request has
no raw Identity argument. Joins reframes those canonical tuples without changing
nested values. This qualification concerns that checked fixed-producer flow,
not an arbitrary standalone pure-library call.

## Retained failed trial

An initial internal facade was not adopted after the Prepared owner identified
its public-library calls. The first public calldata trial still materialized the
full Identity tuple through the existing Content/Attestation helpers. Its
78-source native capture had zero compiler errors, but the Combined facade was
46,995 bytes and AttestationFacts was 33,371 bytes. Both exceeded the limit.
The final source instead projects directly into the separate slim workers.

Failed-trial input SHA256:
`71f89833e55d3364642ec46c8b72dba84759f415b77f25f90e89f177206b4ee2`.
Output SHA256:
`baff40f94878102b0a3c0c7a978f16f4d2c324e356f60b284c3d5e1f1bb80b0c`.
No size acceptance follows from that retained earlier trial.

## Ownership and evidence limits

ExternalGuards, IdentityHydrationSource and Prepared remain with their assigned
owners. No shared Owner, OwnerPayload, Commit or ApplyGuards changes are included.
Generation feature integration remains separate.

The Content 35-case component capture is frozen on earlier source and cannot
validate this later Combined/Attestation refactor. Its first run stopped before
execution on an imported economics fixture's viaIR stack exception; the test-only
repair and retry have separate evidence. Selected bytecode sizes exclude
constructor arguments, runtime tests, full graph, actual operation 60, gas, full
CI and release acceptance. No release readiness claim follows from this work.
