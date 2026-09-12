# Stream contract interfaces

Start with the interface for the operation you need. These caller contracts
share addresses with their domain implementations; selecting an interface does
not select a different contract or grant a caller additional authority.

| Operation | Import | Implementation |
| --- | --- | --- |
| Token ownership and complete permanent Core API | [core/IStreamCore.sol](core/IStreamCore.sol) | [StreamCore](../../core/StreamCore.sol) |
| Native fixed-price mint | [mint/IStreamFixedPriceSaleAdapter.sol](mint/IStreamFixedPriceSaleAdapter.sol) | [StreamFixedPriceSaleAdapter](../../domains/mint/StreamFixedPriceSaleAdapter.sol) |
| Current shared-settlement native sales and price programs | [IStreamNativeFixedPriceSaleAdapter](mint/IStreamNativeFixedPriceSaleAdapter.sol), [IStreamNativePricePrograms](mint/IStreamNativePricePrograms.sol) | [StreamNativeFixedPriceSaleAdapter](../../domains/mint/StreamNativeFixedPriceSaleAdapter.sol) |
| Current shared-settlement ERC-20 sale authorization | [IStreamUniversalFixedPriceSaleAdapter](mint/IStreamUniversalFixedPriceSaleAdapter.sol) | [StreamUniversalFixedPriceSaleAdapter](../../domains/mint/StreamUniversalFixedPriceSaleAdapter.sol) |
| Sale signing-domain discovery | [IERC5267](../standards/IERC5267.sol), [IStreamNativePriceProgramDomain](mint/IStreamNativePriceProgramDomain.sol) | The documented sale consumer and signature family; see [domain selection](../../../docs/integrations/sale-signing-domains.md) |
| ERC-20 fixed-price mint and payer consent | [IStreamERC20FixedPriceSaleAdapter](mint/IStreamERC20FixedPriceSaleAdapter.sol), [IStreamPaymentIntentVerifier](revenue/IStreamPaymentIntentVerifier.sol) | [StreamERC20FixedPriceSaleAdapter](../../domains/mint/StreamERC20FixedPriceSaleAdapter.sol) |
| Mint execution, phase administration, and reads | [IStreamMintExecution](mint/IStreamMintExecution.sol), [IStreamMintAdmin](mint/IStreamMintAdmin.sol), [IStreamMintReads](mint/IStreamMintReads.sol) | [StreamMintManager](../../domains/mint/StreamMintManager.sol) |
| Durable counters and replay protection | [mint/IStreamMintLedger.sol](mint/IStreamMintLedger.sol) | [StreamMintLedger](../../domains/mint/StreamMintLedger.sol) |
| Optional eligibility gate | [mint/IStreamMintGate.sol](mint/IStreamMintGate.sol) | A registered gate module |
| Auction custody, bidding, and settlement | [auctions/IStreamEnglishAuctionHouse.sol](auctions/IStreamEnglishAuctionHouse.sol) | [StreamEnglishAuctionHouse](../../domains/auctions/StreamEnglishAuctionHouse.sol) |
| Modular artist onboarding and mandatory mint consent | [IStreamArtistOnboarding](artist/IStreamArtistOnboarding.sol), [IStreamArtistMintConsent](artist/IStreamArtistMintConsent.sol) | [StreamArtistOnboardingRegistry](../../domains/artist/StreamArtistOnboardingRegistry.sol) |
| Artist attribution reads | [IStreamArtistAttribution](artist/IStreamArtistAttribution.sol) | The selected artist facade |
| Prospective artist economics and defensive royalty authorization | [IStreamArtistEconomicsAuthority](artist/IStreamArtistEconomicsAuthority.sol) | The same modular artist facade |
| Preview primary/royalty economics or apply an authorized royalty freeze | [IStreamArtistPrimaryFacts](artist/IStreamArtistPrimaryFacts.sol), [IStreamArtistRoyaltyPreview](artist/IStreamArtistRoyaltyPreview.sol), [IStreamRoyaltyFreeze](revenue/IStreamRoyaltyFreeze.sol) | The respective primary or royalty resolver |
| Earlier collection nomination and acceptance | [artist/IStreamCollectionArtistRegistry.sol](artist/IStreamCollectionArtistRegistry.sol) | [StreamCollectionArtistRegistry](../../domains/artist/StreamCollectionArtistRegistry.sol), the RC1 artist line |
| Entropy registration and requests | [entropy/IStreamEntropyCoordinator.sol](entropy/IStreamEntropyCoordinator.sol) | [StreamEntropyCoordinator](../../domains/entropy/StreamEntropyCoordinator.sol) |
| Entropy status and final seed | [entropy/IStreamEntropyView.sol](entropy/IStreamEntropyView.sol) | The token's coordinator at mint |
| External randomness provider | [entropy/IStreamEntropyProvider.sol](entropy/IStreamEntropyProvider.sol) | [StreamEntropyProviderVRF](../../domains/entropy/StreamEntropyProviderVRF.sol) |
| Token metadata routing | [metadata/IStreamMetadataRouter.sol](metadata/IStreamMetadataRouter.sol) | [StreamMetadataRouter](../../domains/metadata/StreamMetadataRouter.sol) |
| Immutable split profiles and withdrawals | [IStreamSplitFactory](revenue/IStreamSplitFactory.sol), [IStreamSplitWallet](revenue/IStreamSplitWallet.sol) | [StreamSplitFactory](../../domains/revenue/StreamSplitFactory.sol) and its wallets |
| Royalty receiver and rate | [revenue/IStreamRoyaltyResolver.sol](revenue/IStreamRoyaltyResolver.sol) | [StreamRoyaltyResolver](../../domains/revenue/StreamRoyaltyResolver.sol), exposed through Core's ERC-2981 API |
| Governance action lifecycle | [governance/IStreamGovernanceExecution.sol](governance/IStreamGovernanceExecution.sol) | [StreamGovernanceExecutor](../../domains/governance/StreamGovernanceExecutor.sol) |
| Governed control-plane administration | [governance/IStreamGovernanceAdmin.sol](governance/IStreamGovernanceAdmin.sol) | The same Executor |
| Governance state and current execution context | [governance/IStreamGovernanceReads.sol](governance/IStreamGovernanceReads.sol) | The same Executor |
| One-time genesis and append-only catalog changes | [IStreamGenesisInitializer](governance/IStreamGenesisInitializer.sol), [IStreamGovernanceCatalog](governance/IStreamGovernanceCatalog.sol) | The same Executor, with each operation's distinct authority and timing rules |
| State-export discovery, publication and history | [IStreamStateExportPublisher](governance/IStreamStateExportPublisher.sol), [IStreamStateExportOperations](governance/IStreamStateExportOperations.sol), [IStreamStateExportHistory](governance/IStreamStateExportHistory.sol) | The same Executor; operational publisher role for writes, public challenges |
| Installed module eligibility | [modules/IStreamModuleRegistry.sol](modules/IStreamModuleRegistry.sol) | [StreamModuleRegistry](../../domains/modules/StreamModuleRegistry.sol) |
| Published deployment inventory | [governance/IStreamSystemManifest.sol](governance/IStreamSystemManifest.sol) | [StreamSystemManifest](../../domains/governance/StreamSystemManifest.sol) |

## Core capabilities

[IStreamCore](core/IStreamCore.sol) reexports its nine capability interfaces and
[shared lifecycle types](core/StreamCoreTypes.sol). Import a capability directly
when a contract needs only that responsibility:

- [Collection reads](core/IStreamCoreCollectionView.sol) and [collection management](core/IStreamCoreCollectionManagement.sol).
- [Token identity](core/IStreamCoreIdentity.sol) and [global enumeration](core/IStreamCoreEnumeration.sol).
- [Manager mint hooks](core/IStreamCoreMint.sol) and [burn operations](core/IStreamCoreBurn.sol).
- [Satellite pointers](core/IStreamCorePointers.sol), [gas parameters](core/IStreamCoreGasParameters.sol), and [metadata events](core/IStreamCoreMetadataEmitters.sol).

## ABI and discovery compatibility

[IStreamMintManager](mint/IStreamMintManager.sol) and
[IStreamGovernanceExecutor](governance/IStreamGovernanceExecutor.sol) remain the
original aggregate protocol APIs. IStreamMintReads also exposes the manager's
existing Core, ledger, and registry deployment bindings, which are not part of
the original aggregate discovery interface. Original function declarations remain on those
interfaces because Solidity's `type(I).interfaceId` excludes inherited
functions. Turning these aggregates into empty inheritance-only interfaces
would silently change their existing discovery IDs.

The Execution, Admin, and Reads interfaces are caller subsets. They do not add
ERC165 claims to an implementation. Use the aggregate interface required by the
module registry for discovery. Core capability extraction likewise does not
change which interfaces Core advertises.

Mint requests and policy types retain their `IStreamMintManager.TypeName` and
`IStreamMintLedger.TypeName` ownership for existing Solidity callers.
[StreamGovernanceTypes](governance/StreamGovernanceTypes.sol) owns governance
records and is reexported by the aggregate. Events and custom errors remain
with the existing aggregate or capability that originally owned them.

## Additional and historical surfaces

The `finality/`, `preservation/`, `records/`, `parameters/`, and additional
artist/component interfaces describe their own domains. Presence in this map
does not mean a component is installed in a deployment. Read the installed
module inventory and supported-flow evidence before enabling a feature.

The previous sale and randomness stack is explicitly under `legacy/mint/`,
`legacy/auctions/`, and `legacy/entropy/`. Its requests are not interchangeable
with the current paid-mint or entropy APIs. The old mint-only registry is under
[mint/compatibility](mint/compatibility/IStreamMintModuleRegistry.sol). The current
Manager requires the canonical registry in `modules/` and the selected modular
artist mint-consent capability; the old vocabulary does not supply those checks.
