# Historical local Anvil inputs

These files are exact Git blob copies from
`330ac1d40b1a0d385399ca68423503c892ea0c04`, before the developer-layout
reorganization. They preserve the two local ceremony/randomizer envelopes and
all fourteen inputs those envelopes hash. The original relative paths are
retained beneath this directory; Solidity and Markdown inputs have an added
`.txt` suffix so they are read as evidence, not runnable sources or current
documentation.

The two envelopes under `deployments/ceremony-evidence/` and
`deployments/randomizer-operations/` now resolve their file references here.
Their hashes, placeholder source commit, commands and local result statuses
remain unchanged. Their added operator note describes that relocation. The
original envelopes in this snapshot retain their exact bytes and old path
spellings; validate the relocated envelopes from the repository root.

This is historical local-only evidence. The records carry a zero source commit
and placeholder Anvil participants/providers. Retaining them does not prove a
new run, today's source behavior, a public deployment, or independent review.
Current examples and the current stack can evolve without rewriting these
inputs. Each of the sixteen copied files is hash-bound by the current source
layout manifest; do not refresh these copies from newly generated artifacts.
