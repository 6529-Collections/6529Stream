# Public Stream interfaces

These paths are the import surface for applications and other contracts. The
table identifies the current working path; presence of another interface in
this directory does not mean the full implementation is complete.

| Need | Interface | Primary implementation |
| --- | --- | --- |
| Collections, token identity and mint hooks | [IStreamCore](IStreamCore.sol) | [StreamCore](../../core/StreamCore.sol) |
| Signed fixed-price purchase | [IStreamFixedPriceSaleAdapter](IStreamFixedPriceSaleAdapter.sol) | [StreamFixedPriceSaleAdapter](../../domains/mint/StreamFixedPriceSaleAdapter.sol) |
| Mint phases and execution | [IStreamMintManager](IStreamMintManager.sol) | [StreamMintManager](../../domains/mint/StreamMintManager.sol) |
| Counters and consumed authorizations | [IStreamMintLedger](IStreamMintLedger.sol) | [StreamMintLedger](../../domains/mint/StreamMintLedger.sol) |
| Optional mint eligibility | [IStreamMintGate](IStreamMintGate.sol) | Registered gate modules |
| Module discovery and eligibility | [IStreamModuleRegistry](IStreamModuleRegistry.sol) | [StreamModuleRegistry](../../domains/modules/StreamModuleRegistry.sol) |
| Entropy requests and callbacks | [IStreamEntropyCoordinator](IStreamEntropyCoordinator.sol) | [StreamEntropyCoordinator](../../domains/entropy/StreamEntropyCoordinator.sol) |
| Entropy state and final seed | [IStreamEntropyView](IStreamEntropyView.sol) | The token's coordinator at mint |
| External randomness adapter | [IStreamEntropyProvider](IStreamEntropyProvider.sol) | Provider adapters |
| Metadata routing | [IStreamMetadataRouter](IStreamMetadataRouter.sol) | [StreamMetadataRouter](../../domains/metadata/StreamMetadataRouter.sol) |
| Split creation and withdrawals | [IStreamSplitFactory](IStreamSplitFactory.sol), [IStreamSplitWallet](IStreamSplitWallet.sol) | [StreamSplitFactory](../../domains/revenue/StreamSplitFactory.sol) and its wallets |
| Governed changes | [IStreamGovernanceExecutor](IStreamGovernanceExecutor.sol) | [StreamGovernanceExecutor](../../domains/governance/StreamGovernanceExecutor.sol) |
| One-time initialization | [IStreamGenesisInitializer](IStreamGenesisInitializer.sol) | The same governance executor |
| Deployed system discovery | [IStreamSystemManifest](IStreamSystemManifest.sol) | [StreamSystemManifest](../../domains/governance/StreamSystemManifest.sol) |

`IStreamMintModuleRegistry` is the older mint-only registry vocabulary. New
deployments use `IStreamModuleRegistry`; the manager retains compatibility for
the earlier regression suite. `IStreamDrops`, `IStreamMinter`, `IStreamAuctions`
and the earlier randomizer interfaces describe the older sale/entropy stack.
Do not combine their deployment scripts with the current Core by name alone.

Artist V2 directory interfaces describe immutable component commitments. They
do not by themselves implement the artist operations those components will
own. Use the current deployment's installed module list and supported-flow
tests when deciding which features an application can call.
