import { Interface, ParamType, ZeroHash } from "ethers";
import type { Address, Hex } from "./generated/contracts.js";
import type {
  ArtistHydrationSnapshot,
  ArtistHydrationSuite,
} from "./current-artist-authority-hydration.js";
import * as consent from "./current-artist-recovered-consent-hydration.js";
import {
  createRecoveredHydrationWorkflow,
  type ArtistRecoveredHydrationCapture,
  type ArtistRecoveredHydrationSimulation,
  type ArtistRecoveredHydrationReader,
} from "./internal/artist-recovered-hydration-workflow.js";

export type {
  ArtistRecoveredHydrationCodePin as ArtistRecoveredConsentHydrationCodePin,
  ArtistRecoveredHydrationSuitePins as ArtistRecoveredConsentHydrationSuitePins,
  ArtistRecoveredHydrationDeployment as ArtistRecoveredConsentHydrationDeployment,
  ArtistRecoveredHydrationReader as ArtistRecoveredConsentHydrationReader,
  ArtistRecoveredHydrationReceiptReader as ArtistRecoveredConsentHydrationReceiptReader,
  ArtistRecoveredHydrationObservation as ArtistRecoveredConsentHydrationObservation,
  ArtistRecoveredHydrationPayloadRow as ArtistRecoveredConsentHydrationPayloadRow,
  ArtistRecoveredHydrationPayloadCatalog as ArtistRecoveredConsentHydrationPayloadCatalog,
  ArtistRecoveredHydrationReceiptOptions as ArtistRecoveredConsentHydrationReceiptOptions,
  ArtistRecoveredHydrationOwnerObservation as ArtistRecoveredConsentHydrationOwnerObservation,
  ArtistRecoveredHydrationReceipt as ArtistRecoveredConsentHydrationReceipt,
} from "./internal/artist-recovered-hydration-workflow.js";

export type ArtistRecoveredConsentHydrationCapture =
  ArtistRecoveredHydrationCapture<consent.ArtistRecoveredConsentHydrationCall>;

export type ArtistRecoveredConsentHydrationSimulation =
  ArtistRecoveredHydrationSimulation<consent.ArtistRecoveredConsentHydrationCall>;

const CONTENT_TERMS = "tuple(uint256 collectionId,address metadataContract,bytes32 familyId,bytes32 newStateHash)";
const CONTENT_RECORD = `tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,${CONTENT_TERMS} terms,uint8 authorityClass)`;
const ROYALTY_TERMS = "tuple(address resolver,uint256 collectionId,bytes32 revenueClass,bytes32 expectedAssignmentHash)";
const ROYALTY_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration)";
const FREEZE_RECORD = "tuple(bytes32 recordHash,bytes32 artistId,uint64 bindingGeneration,address metadataContract,bytes32[] lockClasses,bytes32 expectedStateHash,uint8 authorityClass)";

const abi = new Interface([
  `function contentConsentRecord(bytes32 recordHash) view returns(${CONTENT_RECORD})`,
  `function contentConsentAt(${CONTENT_TERMS} p,uint64 generation) view returns(${CONTENT_RECORD})`,
  `function royaltyFreezeRecord(${ROYALTY_TERMS} p,bytes32 artistId,uint64 bindingGeneration) view returns(${ROYALTY_RECORD})`,
  `function contentFreezeRecord(bytes32 recordHash) view returns(${FREEZE_RECORD})`,
  `function contentFreezeAt(uint256 collectionId,uint64 generation,address metadata,bytes32 lockClass) view returns(${FREEZE_RECORD})`,
  "function recordDelegation(bytes32 recordHash) view returns(bytes32)",
]);

function plain(type: ParamType, value: any): any {
  if (type.baseType === "array") {
    return Array.from(value, item => plain(type.arrayChildren!, item));
  }
  if (type.baseType === "tuple") {
    return Object.fromEntries(type.components!.map((field, index) => [
      field.name,
      plain(field, value[index]),
    ]));
  }
  return value;
}

function same(left: unknown, right: unknown): boolean {
  const canonical = (value: unknown): string => JSON.stringify(value, (_key, item) => {
    if (typeof item === "bigint") return item.toString();
    if (typeof item === "string" && item.startsWith("0x")) return item.toLowerCase();
    return item;
  });
  return canonical(left) === canonical(right);
}

async function read(
  reader: ArtistRecoveredHydrationReader,
  owner: Address,
  method: string,
  args: readonly unknown[],
  blockTag: number,
): Promise<any> {
  const fragment = abi.getFunction(method)!;
  const raw = await reader.call({ to: owner, data: abi.encodeFunctionData(fragment, args), blockTag });
  if (typeof raw !== "string" || !/^0x(?:[0-9a-fA-F]{2})*$/.test(raw)
    || (raw.length - 2) / 2 > 16_777_216) {
    throw Error("Invalid bounded original consent return bytes");
  }
  const result = abi.decodeFunctionResult(fragment, raw);
  if (abi.encodeFunctionResult(fragment, result).toLowerCase() !== raw.toLowerCase()) {
    throw Error("Noncanonical original consent return");
  }
  return plain(fragment.outputs[0]!, result[0]);
}

function bundle(certificate: consent.ArtistRecoveredConsentHydrationPrepared) {
  const decoded = consent.decodeArtistRecoveredConsentHydrationOwnerPayload(certificate.data[6].typedState, 6);
  if ((decoded.header.requiredFeatures & 256n) === 0n) return null;
  return consent.decodeArtistRecoveredConsentHydrationContentBundle(
    decoded.payload.semanticState,
    certificate.query,
    decoded.payload.provenance,
  );
}

/** These are fixed-owner historical maps, not current Metadata/Resolver admission. */
async function contentRows(
  reader: ArtistRecoveredHydrationReader,
  owner: Address,
  certificate: consent.ArtistRecoveredConsentHydrationPrepared,
  blockTag: number,
  requireLatest: boolean,
): Promise<void> {
  const rows = bundle(certificate);
  if (!rows) return;
  for (const record of rows.consents) {
    const retained = await read(reader, owner, "contentConsentRecord", [record.recordHash], blockTag);
    const association = await read(reader, owner, "recordDelegation", [record.recordHash], blockTag);
    if (!same(retained, record) || association !== ZeroHash) {
      throw Error("Original operation17 content record or principal association differs");
    }
    if (requireLatest) {
      const latest = rows.consents.filter(candidate => same(candidate.terms, record.terms)).at(-1)!;
      if (!same(await read(reader, owner, "contentConsentAt", [record.terms, 1n], blockTag), latest)) {
        throw Error("Original operation17 latest scope head differs");
      }
    }
  }
  for (const row of rows.royalties) {
    const retained = await read(reader, owner, "royaltyFreezeRecord", [
      row.terms,
      rows.original.artistId,
      1n,
    ], blockTag);
    const association = await read(reader, owner, "recordDelegation", [row.item.recordHash], blockTag);
    if (!same(retained, row.item) || !same(association, row.grant)) {
      throw Error("Original operation20 scope record or historical grant association differs");
    }
  }
  for (const record of rows.freezes) {
    const retained = await read(reader, owner, "contentFreezeRecord", [record.recordHash], blockTag);
    const association = await read(reader, owner, "recordDelegation", [record.recordHash], blockTag);
    if (!same(retained, record) || association !== ZeroHash) {
      throw Error("Original operation21 freeze record or principal association differs");
    }
    if (requireLatest) {
      for (const lockClass of record.lockClasses) {
        const latest = rows.freezes.filter(candidate => same(candidate.metadataContract, record.metadataContract)
          && candidate.lockClasses.some(lock => same(lock, lockClass))).at(-1)!;
        if (!same(await read(reader, owner, "contentFreezeAt", [
          rows.original.collectionId,
          1n,
          record.metadataContract,
          lockClass,
        ], blockTag), latest)) {
          throw Error("Original operation21 per-lock latest head differs");
        }
      }
    }
  }
}

const current = createRecoveredHydrationWorkflow<
  consent.ArtistRecoveredConsentHydrationInput,
  consent.ArtistRecoveredConsentHydrationCall
>({
  normalizeInputDraft: consent.normalizeArtistRecoveredConsentHydrationInputDraft,
  request: input => input.request,
  finalizeInput: (input, inventory) => consent.normalizeArtistRecoveredConsentHydrationInput({
    request: { ...input.request, expectedSemanticInventory: inventory },
    royaltyFreezes: input.royaltyFreezes,
  }),
  inputFromCall: call => ({ request: call.request, royaltyFreezes: call.royaltyFreezes }),
  prepareCall: consent.prepareArtistRecoveredConsentHydrationCall,
  normalizeCall: consent.normalizeArtistRecoveredConsentHydrationCall,
  preparationCalldata: consent.artistRecoveredConsentHydrationPreparationCalldata,
  normalizePrepared: consent.normalizeArtistRecoveredConsentHydrationPrepared,
  decodeOwnerPayload: consent.decodeArtistRecoveredConsentHydrationOwnerPayload,
  semanticInventory: consent.artistRecoveredConsentHydrationSemanticInventory,
  commitment: consent.artistRecoveredConsentHydrationCommitment,
  ownerAfter: consent.artistRecoveredConsentHydrationOwnerAfter,
  profileEvidence: consent.encodeArtistRecoveredConsentHydrationProfileEvidence,
  validateInput: consent.validateArtistRecoveredConsentHydrationInput,
  validateSource: (
    reader: ArtistRecoveredHydrationReader,
    source: ArtistHydrationSuite,
    _input: consent.ArtistRecoveredConsentHydrationInput,
    certificate: consent.ArtistRecoveredConsentHydrationPrepared,
    blockTag: number,
  ) => contentRows(reader, source.owners[6], certificate, blockTag, true),
  validateReceipt: (
    reader: ArtistRecoveredHydrationReader,
    capture: ArtistRecoveredConsentHydrationCapture,
    snapshots: readonly ArtistHydrationSnapshot[],
    blockTag: number,
  ) => contentRows(reader, capture.destinationSuite.owners[6], capture.certificate, blockTag,
    // Later operations may move scope heads while these retained records remain immutable.
    snapshots[6]!.revision === capture.after[6]!.revision),
});

export const captureArtistRecoveredConsentHydration = current.capture;
export const simulateArtistRecoveredConsentHydration = current.simulate;
export const reconcileArtistRecoveredConsentHydrationReceipt = current.reconcile;
