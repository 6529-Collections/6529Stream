# Deployment Scripts

Foundry deployment and rehearsal scripts live in this directory.

Current scripts:

- `RehearseDeployment.s.sol`: deploys and wires a local non-production
  6529Stream stack, creates a sample collection, configures sample admin
  ceremony state, revokes the temporary deployment admin, and transfers Ownable
  control to the configured Safe placeholder.

Run the local rehearsal with:

```bash
forge script script/RehearseDeployment.s.sol:RehearseDeployment --sig "run()" --via-ir
```

This is an Anvil/local simulation gate, not a production broadcast. Gate E still
requires fork/testnet dry runs, real manifest generation from broadcast outputs,
contract verification inputs, ABI checksums, and dry-run mint/auction
ceremonies before public beta.
