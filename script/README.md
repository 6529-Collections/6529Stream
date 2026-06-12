# Deployment Scripts

Foundry deployment and rehearsal scripts live in this directory.

Current scripts:

- `RehearseDeployment.s.sol`: deploys and wires a local non-production
  6529Stream stack, creates a sample collection, configures sample admin
  ceremony state, revokes the temporary deployment admin, and transfers Ownable
  control to the configured Safe placeholder.
- `RehearseMetadataBrowser.s.sol`: builds on the local stack, registers a
  deterministic metadata dependency, mints through the EIP-712 drop
  authorization path, finalizes token metadata inputs, and returns generated
  on-chain metadata evidence for the browser sandbox checker.
- `RehearseAuctionCeremony.s.sol`: builds on the local stack, signs and mints
  an auction drop through EIP-712 authorization, bids, settles, withdraws
  poster/protocol/curator proceeds, and returns local accounting evidence.
- `RehearseEmergencyRedeployment.s.sol`: deploys an impacted local stack and a
  replacement stack with a distinct deployment version, proves immutable
  redeployment evidence, confirms the admin ceremony on both stacks, and mints a
  fixed-price smoke token on the replacement deployment.

Run the local rehearsal with:

```bash
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
forge script script/RehearseAuctionCeremony.s.sol:RehearseAuctionCeremony --sig "run()" --via-ir
forge script script/RehearseEmergencyRedeployment.s.sol:RehearseEmergencyRedeployment --sig "run()" --via-ir
```

Run the local metadata browser rehearsal with:

```bash
python scripts/test_rehearsal_metadata_browser_sandbox.py
python scripts/check_rehearsal_metadata_browser_sandbox.py
```

This is an Anvil/local simulation gate, not a production broadcast. Gate E still
requires fork/testnet dry runs, production metadata browser evidence, real
manifest generation from broadcast outputs, contract verification inputs, ABI
checksums, retained live-ceremony evidence, and retained live emergency
redeployment evidence before public beta.
