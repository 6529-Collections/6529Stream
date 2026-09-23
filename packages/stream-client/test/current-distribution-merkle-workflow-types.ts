import type { Provider } from "ethers";
import type { Address, Hex } from "../src/generated/contracts.js";
import type { OperatorDistributionManifest } from "../src/current-distribution.js";
import {
  prepareDistributionMerkleClaim,
  type DistributionMerkleContext,
  type DistributionMerklePreparedCall,
} from "../src/current-distribution-merkle.js";
import {
  captureDistributionMerkle,
  inspectDistributionMerkleClaim,
  inspectDistributionMerkleProgram,
  reconcileDistributionMerkleReceipt,
  revalidateDistributionMerkle,
  simulateDistributionMerkle,
  type DistributionMerkleCapture,
  type DistributionMerkleDeployment,
  type DistributionMerkleReceiptOptions,
  type DistributionMerkleReconciliation,
} from "../src/current-distribution-merkle-workflow.js";

declare const provider: Provider;
declare const deployment: DistributionMerkleDeployment;
declare const context: DistributionMerkleContext;
declare const prepared: DistributionMerklePreparedCall;
declare const manifest: OperatorDistributionManifest;
declare const saved: DistributionMerkleCapture;
declare const caller: Address;
declare const hash: Hex;

async function examples(): Promise<void> {
  const program = await inspectDistributionMerkleProgram(provider, deployment, manifest, hash, { blockTag: 10 });
  const phaseAdmitted: false = program.phaseAdmissionChecked;
  const local = await inspectDistributionMerkleClaim(provider, deployment, 0n, { blockTag: 10 });
  const originalBeneficiary: Address = local.claim.beneficiary;
  const calls = [prepared,
    prepareDistributionMerkleClaim(context, caller, { kind: "claimNft", tokenId: 1n, receiver: caller }),
    prepareDistributionMerkleClaim(context, caller, { kind: "claimNftFor", tokenId: 1n, walletWide: true, delegationIndex: 0n }),
  ];
  for (const call of calls) {
    const capture = await captureDistributionMerkle(provider, deployment, call, { blockTag: 10 });
    const current = await revalidateDistributionMerkle(provider, capture, { blockTag: 11 });
    const simulation = await simulateDistributionMerkle(provider, current, { blockTag: 11, gasLimit: 5_000_000n });
    const delivered: boolean | null = simulation.delivered;
    const root: Hex | null = simulation.operationRoot;
    const options: DistributionMerkleReceiptOptions = { execution: "safe", expectedSafeTxHash: hash };
    const receipt: DistributionMerkleReconciliation = await reconcileDistributionMerkleReceipt(provider, capture, hash, options);
    const claimOutcome: "completed" | "retained" | null = receipt.claimOutcome;
    const noReturnAttribution: false = receipt.functionReturnObserved;
    const quantity: bigint | undefined = capture.preview?.quantity;
    const authority: "original-distributor-call-simulation" = capture.admissionAuthority;
    const pins = capture.deployment.delegationLinkedDependencies;
    const grantExpiry: bigint | undefined = capture.delegation?.[3];
    const allTokens: boolean | undefined = capture.delegation?.[4];
    // @ts-expect-error reviewed pins cannot be replaced through capture
    pins[0]!.codeHash = hash;
    // @ts-expect-error original call and caller remain immutable
    capture.prepared.caller = caller;
    // @ts-expect-error the proof/current inventory is immutable
    capture.counters.push(capture.counters[0]!);
    // @ts-expect-error receipt outcomes cannot imply observed EVM false/true return
    const observedReturn: boolean = receipt.delivered;
    // @ts-expect-error raw integer observations preserve bigint precision
    const approximate: number | undefined = quantity;
    void [delivered, root, claimOutcome, noReturnAttribution, quantity, authority, observedReturn, approximate, grantExpiry, allTokens];
  }
  // @ts-expect-error concrete fixed block required
  await captureDistributionMerkle(provider, deployment, prepared, { blockTag: "latest" });
  // @ts-expect-error simulation requires explicit gas
  await simulateDistributionMerkle(provider, saved, { blockTag: 10 });
  // @ts-expect-error exact expected Safe hash cannot be inferred from its event
  await reconcileDistributionMerkleReceipt(provider, saved, hash, { execution: "safe" });
  // @ts-expect-error delegatecall is not an original operation transport
  await reconcileDistributionMerkleReceipt(provider, saved, hash, { execution: "delegatecall" });
  // @ts-expect-error arbitrary raw call cannot replace prepared semantic request
  await captureDistributionMerkle(provider, deployment, prepared.call, { blockTag: 10 });
  void [phaseAdmitted, originalBeneficiary];
}
void examples;
