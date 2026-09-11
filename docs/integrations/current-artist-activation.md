# Activate a new modular artist deployment

This guide covers the developing full-v1 deployment line. The published
[RC1](https://github.com/6529-Collections/6529Stream/releases/tag/testnet/current-rc-1)
has its own contracts, scripts and evidence. Do not use a new ABI or activation
plan against that retained deployment.

`DeployCurrentStack` now deploys the artist facade, coordinator, archive and
seven semantic owners, alongside the actual metadata and revenue providers.
Committed genesis selects the modules and admits the native sale, ERC-20 sale
and auction as exact revenue-escrow producers.

After genesis, deployment publishes and schedules one governance batch that
grants the deployer `ROLE_ARTIST_REGISTRY_ADMIN` and raises the Manager's artist
read budget from 150,000 to 300,000. Both changes use their ordinary governed
transitions. The minimum delay is 48 hours. The script defaults to 49 hours to
allow time for submission; `STREAM_ARTIST_ACTIVATION_NOT_BEFORE` can pin the exact
Unix timestamp before simulation. Use the same pinned value for broadcast. The
action expires seven days after its saved execution time.

Retain `activationActionId`, `activationNotBefore` and the exact ABI-encoded
`activationPlan` from `DeploymentAddresses`, together with the deployment
addresses and receipts. A plan prepared for another chain or set of contracts
is not interchangeable. After scheduling, use those retained bytes rather than
rebuilding transition hashes from the changed role or parameter state.

## Execute or resume the saved authority batch

`ActivateCurrentArtistAuthority.s.sol` accepts these public environment values:

| Variable | Retained value |
| --- | --- |
| `STREAM_EXECUTOR` | Governance Executor address |
| `STREAM_ROLE_REGISTRY` | Its RoleRegistry address |
| `STREAM_MINT_MANAGER` | Manager address |
| `STREAM_ARTIST_ADMINISTRATOR` | The administrator named in the scheduled grant |
| `STREAM_ACTIVATION_ACTION_ID` | `activationActionId` |
| `STREAM_ACTIVATION_PLAN` | `activationPlan`, including its `0x` prefix |
| `STREAM_ACTIVATION_SENDER` | Account submitting the permissionless execution |

The entry point accepts Anvil and Sepolia. It does not read a private key.
Supply a Foundry signer or an unlocked local account using the deployment
environment's existing signing workflow.

```powershell
$env:FOUNDRY_PROFILE = 'current'
forge script script/current/ActivateCurrentArtistAuthority.s.sol:ActivateCurrentArtistAuthority --via-ir --skip test --rpc-url $env:STREAM_RPC_URL --sender $env:STREAM_ACTIVATION_SENDER
```

This command simulates. Broadcast only the retained, reviewed transaction using
the operator's signer. On Anvil, its clock may advance to the saved execution
time. Sepolia must reach that time normally. An early, cancelled, expired or
otherwise invalid action cannot execute.

The consumer checks the exact target, selector, calldata hash, administrator,
parameter change and stored action commitment. After execution it reads the
actual role and read budget. Repeating a completed call verifies those facts
without scheduling another action. Mismatched saved calldata is rejected even
when the action is already executed.

## What remains after authority activation

Authority activation enables artist setup; it does not establish mint eligibility.
The artist must accept the exact binding and record payout, economics, content
ratification and mandatory attestations. Each phase needs prospective consent
before both its initial configuration and its executor admission. The Manager
stays deployer-owned until this setup is complete, then ownership must transfer
to the governance Executor and be read back.

The [phase setup planner](current-mint-setup.md) prepares the exact subsequent
artist-consent, Manager configuration and final ownership-transfer calls for an
EOA or Safe. Seven actual-current tests pass, including real Safe calls, resumed
setup, final ownership readback and paid minting. The identity
onboarding consumer and older PowerShell runners are still being migrated on
this development branch. Use the frozen RC1 checkout
for its demonstrated workflow. A new release will require its own complete
deployment, setup and mint evidence.

Artist transactions may come from an EOA or a Safe. Generate each next call
from the confirmed preceding state. Direct payout and attestation calls use
the supported zero timestamp sentinel for their eventual inclusion time;
relayed proofs retain their signed timestamp. Safe integrations must inspect
`ExecutionSuccess` or `ExecutionFailure` and the actual protocol result: an
outer successful receipt alone does not establish that its target call worked.
