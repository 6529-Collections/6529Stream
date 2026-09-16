import {
  AbiCoder,
  Interface,
  ZeroAddress,
  getAddress,
  id,
  isHexString,
  keccak256,
} from "ethers";
import type { Provider } from "ethers";
import type { UnsignedCall } from "./client.js";
import type { Address, Hex } from "./generated/contracts.js";
import {
  curatedContentLeaf,
  curatedPurchaseId,
  curatedSaleId,
  curatedSelectionCommitment,
  normalizeCuratedContentSelection,
  normalizeCuratedDelegationWitness,
  normalizeCuratedSelection,
  validateCuratedSaleConfiguration,
  verifyCuratedContentProof,
} from "./current-curated-content.js";
import type {
  CuratedContentSelection,
  CuratedDelegationWitness,
  CuratedSaleConfiguration,
  CuratedSelection,
} from "./current-curated-content.js";

export const CURATED_FIXED_COMMIT_REVEAL = 0n;
export const CURATED_FIXED_PUBLIC = 1n;

export interface CuratedFixedSelectionWindows {
  readonly commitOpen: bigint;
  readonly commitClose: bigint;
  readonly revealOpen: bigint;
  readonly revealClose: bigint;
  readonly absoluteEscape: bigint;
}

export interface CuratedFixedConfiguration {
  readonly sale: CuratedSaleConfiguration;
  readonly mode: bigint;
  readonly differentiatedContent: boolean;
  readonly publicSelectionDisclosure: boolean;
  readonly windows: CuratedFixedSelectionWindows;
}

export interface CuratedFixedSaleRecord {
  readonly saleNonce: bigint;
  readonly saleKind: bigint;
  readonly configHash: Hex;
  readonly saleCreatedAt: bigint;
  readonly saleAdapterRegistryRevision: bigint;
  readonly artistId: Hex;
  readonly bindingGeneration: bigint;
  readonly bindingHash: Hex;
  readonly gate: Address;
  readonly gateCodeHash: Hex;
  readonly gateConfigHash: Hex;
  readonly manifestHash: Hex;
  readonly contentCounterId: Hex;
  readonly contentCounterConfigHash: Hex;
  readonly status: bigint;
}

export interface CuratedFixedWindowView {
  readonly commitOpen: bigint;
  readonly commitClose: bigint;
  readonly revealOpen: bigint;
  readonly revealClose: bigint;
  readonly commitToll: bigint;
  readonly revealToll: bigint;
  readonly commitLive: boolean;
  readonly revealLive: boolean;
  readonly commitMatured: boolean;
  readonly matured: boolean;
  readonly escapeReached: boolean;
  readonly globalPaused: boolean;
  readonly localPaused: boolean;
  readonly collectionStopped: boolean;
}

export interface CuratedFixedExecutionRecord {
  readonly saleId: Hex;
  readonly buyer: Address;
  readonly recipient: Address;
  readonly purchaseNonce: bigint;
  readonly authorizationId: Hex;
  readonly authorizationDigest: Hex;
  readonly contentLeaf: Hex;
  readonly tokenDataHash: Hex;
  readonly mintCommitment: Hex;
  readonly price: bigint;
  readonly tokenId: bigint;
  readonly settlementKey: Hex;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
}

export interface PreparedCuratedFixedRegistration {
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly expectedNonce: bigint;
  readonly configuration: CuratedFixedConfiguration;
  readonly expectedSaleId: Hex;
  readonly configurationHash: Hex;
  readonly call: UnsignedCall;
}

export interface PreparedCuratedPublicPurchase {
  readonly kind: "public";
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly saleId: Hex;
  readonly configuration: CuratedFixedConfiguration;
  readonly selection: CuratedSelection;
  readonly revealFeeAllowance: bigint;
  readonly expectedContentLeaf: Hex;
  readonly expectedPurchaseId: Hex;
  readonly call: UnsignedCall;
}

export interface PreparedCuratedSelectionCommit {
  readonly kind: "commit";
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly saleId: Hex;
  readonly configuration: CuratedFixedConfiguration;
  readonly content: CuratedContentSelection;
  readonly salt: Hex;
  readonly purchaseNonce: bigint;
  readonly contentLeaf: Hex;
  readonly commitment: Hex;
  readonly expectedPurchaseId: Hex;
  readonly call: UnsignedCall;
}

export interface PreparedCuratedSelectionReveal {
  readonly kind: "reveal";
  readonly chainId: bigint;
  readonly adapter: Address;
  readonly caller: Address;
  readonly saleId: Hex;
  readonly configuration: CuratedFixedConfiguration;
  readonly selection: CuratedSelection;
  readonly salt: Hex;
  readonly revealFeeAllowance: bigint;
  readonly contentLeaf: Hex;
  readonly commitment: Hex;
  readonly expectedPurchaseId: Hex;
  readonly call: UnsignedCall;
}

export interface CuratedSelectionDepositInspection {
  readonly amount: bigint;
  readonly committedBlock: bigint;
  readonly status: bigint;
  readonly purchaseId: Hex;
  readonly purchaseNonce: bigint;
}

export interface PreparedCuratedFixedAction {
  readonly kind:
    | "maturity-unlock"
    | "reason-unlock"
    | "selection-claim"
    | "selection-delegated-claim"
    | "excess-claim"
    | "excess-delegated-claim"
    | "cancel"
    | "contest-sync";
  readonly adapter: Address;
  readonly caller: Address;
  readonly call: UnsignedCall;
}

const coder = AbiCoder.defaultAbiCoder();
const ZERO32 = `0x${"00".repeat(32)}` as Hex;
const saleTuple = "tuple(uint256 collectionId,bytes32 phaseId,uint256 price,address poster,uint64 startsAt,uint64 endsAt,bytes32 mintPolicyHash,bytes32 expectedPrimaryPolicyHash,uint8 primaryPolicyMode,bytes32 contentManifestRoot)";
const windowsTuple = "tuple(uint64 commitOpen,uint64 commitClose,uint64 revealOpen,uint64 revealClose,uint64 absoluteEscape)";
const fixedTuple = `tuple(${saleTuple} sale,uint8 mode,bool differentiatedContent,bool publicSelectionDisclosure,${windowsTuple} windows)`;
const contentTuple = "tuple(bytes32 contentId,bytes32 tokenDataHash,bytes32[] proof)";
const selectionTuple = `tuple(${contentTuple} content,bytes tokenData,bytes32 mintCommitment,address recipient,uint256 purchaseNonce)`;
const lifecycleTuple = "tuple(uint64 saleCreatedAt,uint64 saleAdapterRegistryRevision)";
const saleRecordTuple = `tuple(${saleTuple} config,uint256 saleNonce,uint8 saleKind,bytes32 configHash,${lifecycleTuple} lifecycle,bytes32 artistId,uint64 bindingGeneration,bytes32 bindingHash,address gate,bytes32 gateCodeHash,bytes32 gateConfigHash,bytes32 manifestHash,bytes32 contentCounterId,bytes32 contentCounterConfigHash,uint8 status)`;
const executionTuple = "tuple(bytes32 saleId,address buyer,address recipient,uint256 purchaseNonce,bytes32 authorizationId,bytes32 authorizationDigest,bytes32 contentLeaf,bytes32 tokenDataHash,bytes32 mintCommitment,uint256 price,uint256 tokenId,bytes32 settlementKey,bytes32 operationRoot,bytes32 operationId)";
const windowViewTuple = "tuple(uint64 commitOpen,uint64 commitClose,uint64 revealOpen,uint64 revealClose,uint64 commitToll,uint64 revealToll,bool commitLive,bool revealLive,bool commitMatured,bool matured,bool escapeReached,bool globalPaused,bool localPaused,bool collectionStopped)";
const witnessTuple = "tuple(bool walletWide,uint256 index)";
const quoteTuple = "tuple(address coordinator,bytes32 coordinatorCodeHash,tuple(bool declared,uint8 requestMode,bytes32 revealOwnerRole,uint64 requestSLOBlocks,uint256 revealFeePerTokenWei) policy)";

const fixedAbi = new Interface([
  `function fixedConfigurationHash(${fixedTuple}) view returns (bytes32)`,
  `function registerCuratedFixedSale(${fixedTuple}) returns (bytes32)`,
  `function fixedSaleConfiguration(bytes32) view returns (${fixedTuple})`,
  "function owner() view returns (address)",
  "function nextSaleNonce() view returns (uint256)",
  "function saleIdFor(uint8,uint256,bytes32,uint256) view returns (bytes32)",
  `function saleRecord(bytes32) view returns (${saleRecordTuple})`,
  `function purchaseSelectedContent(bytes32,${selectionTuple}) payable returns (${executionTuple})`,
  "function commitSelection(bytes32,bytes32,uint256) payable returns (bytes32)",
  `function revealSelection(bytes32,${selectionTuple},bytes32) payable returns (${executionTuple})`,
  "function selectionCommitment(bytes32,address,bytes32,bytes32) view returns (bytes32)",
  "function selectionDeposit(bytes32,address,bytes32) view returns (tuple(uint256 amount,uint256 committedBlock,uint8 status),bytes32,uint256)",
  `function selectionWindows(bytes32) view returns (${windowViewTuple})`,
  "function nextPurchaseNonce(bytes32,address) view returns (uint256)",
  "function purchaseIdFor(bytes32,address,uint256) view returns (bytes32)",
  `function saleRevealQuote(bytes32) view returns (${quoteTuple})`,
  `function executionRecord(bytes32) view returns (${executionTuple})`,
  "function unlockSelectionRefund(bytes32,address,bytes32) returns (uint256)",
  `function unlockSelectionRefundForReason(bytes32,address,bytes32,${selectionTuple},bytes32,uint8) returns (uint256)`,
  "function selectionRefundCredit(bytes32,address) view returns (uint256)",
  "function claimSelectionRefund(bytes32,address) returns (uint256)",
  `function claimSelectionRefundDelegated(bytes32,address,${witnessTuple}) returns (uint256)`,
  "function refundableBalance(bytes32,address) view returns (uint256)",
  "function claimRefund(bytes32,address) returns (uint256)",
  `function claimRefundFor(bytes32,address,${witnessTuple}) returns (uint256)`,
  "function cancelSale(bytes32)",
  "function syncCollectionContest(uint256)",
  "function core() view returns (address)",
  "function mintManager() view returns (address)",
  "function revenueResolver() view returns (address)",
  "function artistRegistry() view returns (address)",
  "function moduleRegistry() view returns (address)",
]);

function exactKeys(
  value: unknown,
  expected: readonly string[],
  label: string,
): asserts value is Record<string, unknown> {
  if (
    value === null
    || typeof value !== "object"
    || Array.isArray(value)
    || Object.keys(value).sort().join(",") !== [...expected].sort().join(",")
  ) {
    throw new Error(`${label} contains missing or unknown properties`);
  }
}

function uint(value: unknown, bits: number, label: string, positive = false): bigint {
  if (
    typeof value !== "bigint"
    || value < 0n
    || value >= 1n << BigInt(bits)
    || (positive && value === 0n)
  ) {
    throw new Error(`${label} must be a ${positive ? "positive" : "nonnegative"} uint${bits} bigint`);
  }
  return value;
}

function address(value: unknown, label: string): Address {
  if (typeof value !== "string") {
    throw new Error(`${label} must be an address string`);
  }
  const normalized = getAddress(value) as Address;
  if (normalized === ZeroAddress) {
    throw new Error(`${label} must be nonzero`);
  }
  return normalized;
}

function hash(value: unknown, label: string, allowZero = false): Hex {
  if (
    typeof value !== "string"
    || !isHexString(value, 32)
    || (!allowZero && value.toLowerCase() === ZERO32)
  ) {
    throw new Error(`${label} must be ${allowZero ? "a" : "a nonzero"} bytes32`);
  }
  return value.toLowerCase() as Hex;
}

function bool(value: unknown, label: string): boolean {
  if (typeof value !== "boolean") {
    throw new Error(`${label} must be boolean`);
  }
  return value;
}

function block(value: unknown): number {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    throw new Error("A concrete nonnegative block number is required");
  }
  return value;
}

async function blockTimestamp(
  provider: Pick<Provider, "getBlock">,
  blockTag: number,
): Promise<bigint> {
  const value = await provider.getBlock(blockTag);
  if (
    value === null
    || typeof value.timestamp !== "number"
    || !Number.isSafeInteger(value.timestamp)
    || value.timestamp < 0
  ) {
    throw new Error("Pinned block timestamp is unavailable");
  }
  return BigInt(value.timestamp);
}

function same(left: unknown, right: string): boolean {
  return typeof left === "string" && left.toLowerCase() === right.toLowerCase();
}

function render(value: unknown): string {
  return JSON.stringify(value, (_, item) => typeof item === "bigint" ? item.toString() : item);
}

function unsignedCall(
  adapter: Address,
  method: string,
  args: readonly unknown[],
  value = 0n,
): UnsignedCall {
  return Object.freeze({
    to: address(adapter, "adapter"),
    data: fixedAbi.encodeFunctionData(method, args) as Hex,
    value: uint(value, 256, "call value"),
  });
}

function normalizeWindows(value: CuratedFixedSelectionWindows): CuratedFixedSelectionWindows {
  exactKeys(
    value,
    ["commitOpen", "commitClose", "revealOpen", "revealClose", "absoluteEscape"],
    "curated fixed windows",
  );
  return Object.freeze({
    commitOpen: uint(value.commitOpen, 64, "commitOpen"),
    commitClose: uint(value.commitClose, 64, "commitClose"),
    revealOpen: uint(value.revealOpen, 64, "revealOpen"),
    revealClose: uint(value.revealClose, 64, "revealClose"),
    absoluteEscape: uint(value.absoluteEscape, 64, "absoluteEscape"),
  });
}

export function normalizeCuratedFixedConfiguration(
  value: CuratedFixedConfiguration,
): CuratedFixedConfiguration {
  exactKeys(
    value,
    ["sale", "mode", "differentiatedContent", "publicSelectionDisclosure", "windows"],
    "curated fixed configuration",
  );
  const sale = validateCuratedSaleConfiguration(value.sale);
  const mode = uint(value.mode, 8, "selection mode");
  const differentiatedContent = bool(
    value.differentiatedContent,
    "differentiatedContent",
  );
  const publicSelectionDisclosure = bool(
    value.publicSelectionDisclosure,
    "publicSelectionDisclosure",
  );
  const windows = normalizeWindows(value.windows);
  if (mode === CURATED_FIXED_PUBLIC) {
    const nonzeroWindow = Object.values(windows).some(item => item !== 0n);
    if (
      sale.primaryPolicyMode !== 0n
      || differentiatedContent
      || !publicSelectionDisclosure
      || nonzeroWindow
    ) {
      throw new Error("PUBLIC curated fixed configuration has invalid policy or disclosure terms");
    }
  } else if (mode === CURATED_FIXED_COMMIT_REVEAL) {
    if (
      sale.primaryPolicyMode !== 1n
      || publicSelectionDisclosure
      || windows.commitOpen !== sale.startsAt
      || windows.revealClose !== sale.endsAt
      || windows.commitOpen >= windows.commitClose
      || windows.commitClose > windows.revealOpen
      || windows.revealOpen >= windows.revealClose
      || windows.absoluteEscape < windows.revealClose
    ) {
      throw new Error("COMMIT_REVEAL curated fixed configuration has invalid policy or windows");
    }
  } else {
    throw new Error("Curated fixed selection mode must be COMMIT_REVEAL 0 or PUBLIC 1");
  }
  return Object.freeze({
    sale,
    mode,
    differentiatedContent,
    publicSelectionDisclosure,
    windows,
  });
}

export function curatedFixedConfigurationHash(
  chainId: bigint,
  adapter: Address,
  configuration: CuratedFixedConfiguration,
): Hex {
  const encoded = coder.encode(
    ["bytes32", "uint256", "address", fixedTuple],
    [
      id("6529STREAM_NATIVE_CURATED_FIXED_CONFIG_V1"),
      uint(chainId, 256, "chainId", true),
      address(adapter, "adapter"),
      normalizeCuratedFixedConfiguration(configuration),
    ],
  );
  return keccak256(encoded) as Hex;
}

function normalizeContentForSale(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  configuration: CuratedFixedConfiguration,
  content: CuratedContentSelection,
): { readonly content: CuratedContentSelection; readonly leaf: Hex } {
  const normalized = normalizeCuratedContentSelection(content);
  if (
    !verifyCuratedContentProof(
      chainId,
      adapter,
      saleId,
      configuration.sale.contentManifestRoot,
      normalized,
    )
  ) {
    throw new Error("Selected content proof does not match the registered manifest root");
  }
  return Object.freeze({
    content: normalized,
    leaf: curatedContentLeaf(
      chainId,
      adapter,
      saleId,
      normalized.contentId,
      normalized.tokenDataHash,
    ),
  });
}

function normalizeSelectionForSale(
  chainId: bigint,
  adapter: Address,
  saleId: Hex,
  configuration: CuratedFixedConfiguration,
  selection: CuratedSelection,
): { readonly selection: CuratedSelection; readonly leaf: Hex } {
  const normalized = normalizeCuratedSelection(selection);
  if (same(normalized.recipient, adapter)) {
    throw new Error("Curated selection recipient cannot be the adapter");
  }
  const content = normalizeContentForSale(
    chainId,
    adapter,
    saleId,
    configuration,
    normalized.content,
  );
  return Object.freeze({ selection: normalized, leaf: content.leaf });
}

export function prepareCuratedFixedRegistration(
  chainId: bigint,
  adapter: Address,
  owner: Address,
  expectedNonce: bigint,
  configuration: CuratedFixedConfiguration,
): PreparedCuratedFixedRegistration {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedOwner = address(owner, "owner");
  const nonce = uint(expectedNonce, 256, "expectedNonce", true);
  const normalizedConfiguration = normalizeCuratedFixedConfiguration(configuration);
  const expectedSaleId = curatedSaleId(
    normalizedChainId,
    normalizedAdapter,
    0n,
    normalizedConfiguration.sale.collectionId,
    normalizedConfiguration.sale.phaseId,
    nonce,
  );
  const configurationHash = curatedFixedConfigurationHash(
    normalizedChainId,
    normalizedAdapter,
    normalizedConfiguration,
  );
  return Object.freeze({
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedOwner,
    expectedNonce: nonce,
    configuration: normalizedConfiguration,
    expectedSaleId,
    configurationHash,
    call: unsignedCall(
      normalizedAdapter,
      "registerCuratedFixedSale",
      [normalizedConfiguration],
    ),
  });
}

export function prepareCuratedPublicPurchase(
  chainId: bigint,
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  configuration: CuratedFixedConfiguration,
  selection: CuratedSelection,
  revealFeeAllowance: bigint,
): PreparedCuratedPublicPurchase {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedBuyer = address(buyer, "buyer");
  const normalizedSaleId = hash(saleId, "saleId");
  const normalizedConfiguration = normalizeCuratedFixedConfiguration(configuration);
  if (normalizedConfiguration.mode !== CURATED_FIXED_PUBLIC) {
    throw new Error("Public purchase requires a PUBLIC curated fixed configuration");
  }
  const normalizedSelection = normalizeSelectionForSale(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedConfiguration,
    selection,
  );
  const allowance = uint(revealFeeAllowance, 256, "revealFeeAllowance");
  return Object.freeze({
    kind: "public",
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedBuyer,
    saleId: normalizedSaleId,
    configuration: normalizedConfiguration,
    selection: normalizedSelection.selection,
    revealFeeAllowance: allowance,
    expectedContentLeaf: normalizedSelection.leaf,
    expectedPurchaseId: curatedPurchaseId(
      normalizedChainId,
      normalizedAdapter,
      normalizedSaleId,
      normalizedBuyer,
      normalizedSelection.selection.purchaseNonce,
    ),
    call: unsignedCall(
      normalizedAdapter,
      "purchaseSelectedContent",
      [normalizedSaleId, normalizedSelection.selection],
      normalizedConfiguration.sale.price + allowance,
    ),
  });
}

export function prepareCuratedSelectionCommit(
  chainId: bigint,
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  configuration: CuratedFixedConfiguration,
  content: CuratedContentSelection,
  salt: Hex,
  purchaseNonce: bigint,
): PreparedCuratedSelectionCommit {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedBuyer = address(buyer, "buyer");
  const normalizedSaleId = hash(saleId, "saleId");
  const normalizedConfiguration = normalizeCuratedFixedConfiguration(configuration);
  if (normalizedConfiguration.mode !== CURATED_FIXED_COMMIT_REVEAL) {
    throw new Error("Selection commitment requires a COMMIT_REVEAL configuration");
  }
  const normalizedContent = normalizeContentForSale(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedConfiguration,
    content,
  );
  const normalizedSalt = hash(salt, "salt", true);
  const nonce = uint(purchaseNonce, 256, "purchaseNonce", true);
  const commitment = curatedSelectionCommitment(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedBuyer,
    normalizedContent.leaf,
    normalizedSalt,
  );
  return Object.freeze({
    kind: "commit",
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedBuyer,
    saleId: normalizedSaleId,
    configuration: normalizedConfiguration,
    content: normalizedContent.content,
    salt: normalizedSalt,
    purchaseNonce: nonce,
    contentLeaf: normalizedContent.leaf,
    commitment,
    expectedPurchaseId: curatedPurchaseId(
      normalizedChainId,
      normalizedAdapter,
      normalizedSaleId,
      normalizedBuyer,
      nonce,
    ),
    call: unsignedCall(
      normalizedAdapter,
      "commitSelection",
      [normalizedSaleId, commitment, nonce],
      normalizedConfiguration.sale.price,
    ),
  });
}

export function prepareCuratedSelectionReveal(
  chainId: bigint,
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  configuration: CuratedFixedConfiguration,
  selection: CuratedSelection,
  salt: Hex,
  revealFeeAllowance: bigint,
): PreparedCuratedSelectionReveal {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedBuyer = address(buyer, "buyer");
  const normalizedSaleId = hash(saleId, "saleId");
  const normalizedConfiguration = normalizeCuratedFixedConfiguration(configuration);
  if (normalizedConfiguration.mode !== CURATED_FIXED_COMMIT_REVEAL) {
    throw new Error("Selection reveal requires a COMMIT_REVEAL configuration");
  }
  const normalizedSelection = normalizeSelectionForSale(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedConfiguration,
    selection,
  );
  const normalizedSalt = hash(salt, "salt", true);
  const allowance = uint(revealFeeAllowance, 256, "revealFeeAllowance");
  const commitment = curatedSelectionCommitment(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedBuyer,
    normalizedSelection.leaf,
    normalizedSalt,
  );
  return Object.freeze({
    kind: "reveal",
    chainId: normalizedChainId,
    adapter: normalizedAdapter,
    caller: normalizedBuyer,
    saleId: normalizedSaleId,
    configuration: normalizedConfiguration,
    selection: normalizedSelection.selection,
    salt: normalizedSalt,
    revealFeeAllowance: allowance,
    contentLeaf: normalizedSelection.leaf,
    commitment,
    expectedPurchaseId: curatedPurchaseId(
      normalizedChainId,
      normalizedAdapter,
      normalizedSaleId,
      normalizedBuyer,
      normalizedSelection.selection.purchaseNonce,
    ),
    call: unsignedCall(
      normalizedAdapter,
      "revealSelection",
      [normalizedSaleId, normalizedSelection.selection, normalizedSalt],
      allowance,
    ),
  });
}

function samePreparedRegistration(
  value: PreparedCuratedFixedRegistration,
): PreparedCuratedFixedRegistration {
  exactKeys(
    value,
    [
      "chainId",
      "adapter",
      "caller",
      "expectedNonce",
      "configuration",
      "expectedSaleId",
      "configurationHash",
      "call",
    ],
    "prepared curated fixed registration",
  );
  const rebuilt = prepareCuratedFixedRegistration(
    value.chainId,
    value.adapter,
    value.caller,
    value.expectedNonce,
    value.configuration,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared curated fixed registration differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedPublic(
  value: PreparedCuratedPublicPurchase,
): PreparedCuratedPublicPurchase {
  exactKeys(
    value,
    [
      "kind",
      "chainId",
      "adapter",
      "caller",
      "saleId",
      "configuration",
      "selection",
      "revealFeeAllowance",
      "expectedContentLeaf",
      "expectedPurchaseId",
      "call",
    ],
    "prepared curated public purchase",
  );
  const rebuilt = prepareCuratedPublicPurchase(
    value.chainId,
    value.adapter,
    value.caller,
    value.saleId,
    value.configuration,
    value.selection,
    value.revealFeeAllowance,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared curated public purchase differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedCommit(
  value: PreparedCuratedSelectionCommit,
): PreparedCuratedSelectionCommit {
  exactKeys(
    value,
    [
      "kind",
      "chainId",
      "adapter",
      "caller",
      "saleId",
      "configuration",
      "content",
      "salt",
      "purchaseNonce",
      "contentLeaf",
      "commitment",
      "expectedPurchaseId",
      "call",
    ],
    "prepared curated selection commitment",
  );
  const rebuilt = prepareCuratedSelectionCommit(
    value.chainId,
    value.adapter,
    value.caller,
    value.saleId,
    value.configuration,
    value.content,
    value.salt,
    value.purchaseNonce,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared curated selection commitment differs from canonical reconstruction");
  }
  return rebuilt;
}

function samePreparedReveal(
  value: PreparedCuratedSelectionReveal,
): PreparedCuratedSelectionReveal {
  exactKeys(
    value,
    [
      "kind",
      "chainId",
      "adapter",
      "caller",
      "saleId",
      "configuration",
      "selection",
      "salt",
      "revealFeeAllowance",
      "contentLeaf",
      "commitment",
      "expectedPurchaseId",
      "call",
    ],
    "prepared curated selection reveal",
  );
  const rebuilt = prepareCuratedSelectionReveal(
    value.chainId,
    value.adapter,
    value.caller,
    value.saleId,
    value.configuration,
    value.selection,
    value.salt,
    value.revealFeeAllowance,
  );
  if (render(value) !== render(rebuilt)) {
    throw new Error("Prepared curated selection reveal differs from canonical reconstruction");
  }
  return rebuilt;
}

async function rpc(
  provider: Pick<Provider, "call">,
  target: Address,
  method: string,
  args: readonly unknown[],
  blockTag: number,
): Promise<readonly unknown[]> {
  const raw = await provider.call({
    to: target,
    data: fixedAbi.encodeFunctionData(method, args),
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error(`Malformed ${method} return`);
  }
  const decoded = fixedAbi.decodeFunctionResult(method, raw);
  const canonical = fixedAbi.encodeFunctionResult(method, decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error(`Noncanonical ${method} return`);
  }
  return decoded;
}

function tuple(value: unknown, label: string): Record<string, unknown> {
  if (value === null || typeof value !== "object") {
    throw new Error(`Malformed ${label} tuple`);
  }
  return value as Record<string, unknown>;
}

function decodedSale(value: unknown): CuratedSaleConfiguration {
  const sale = tuple(value, "curated sale configuration");
  return validateCuratedSaleConfiguration({
    collectionId: BigInt(sale.collectionId as bigint),
    phaseId: hash(sale.phaseId, "phaseId"),
    price: BigInt(sale.price as bigint),
    poster: address(sale.poster, "poster"),
    startsAt: BigInt(sale.startsAt as bigint),
    endsAt: BigInt(sale.endsAt as bigint),
    mintPolicyHash: hash(sale.mintPolicyHash, "mintPolicyHash"),
    expectedPrimaryPolicyHash: hash(
      sale.expectedPrimaryPolicyHash,
      "expectedPrimaryPolicyHash",
    ),
    primaryPolicyMode: BigInt(sale.primaryPolicyMode as bigint),
    contentManifestRoot: hash(sale.contentManifestRoot, "contentManifestRoot"),
  });
}

function decodedFixed(value: unknown): CuratedFixedConfiguration {
  const fixed = tuple(value, "curated fixed configuration");
  const windows = tuple(fixed.windows, "curated selection windows");
  return normalizeCuratedFixedConfiguration({
    sale: decodedSale(fixed.sale),
    mode: BigInt(fixed.mode as bigint),
    differentiatedContent: Boolean(fixed.differentiatedContent),
    publicSelectionDisclosure: Boolean(fixed.publicSelectionDisclosure),
    windows: {
      commitOpen: BigInt(windows.commitOpen as bigint),
      commitClose: BigInt(windows.commitClose as bigint),
      revealOpen: BigInt(windows.revealOpen as bigint),
      revealClose: BigInt(windows.revealClose as bigint),
      absoluteEscape: BigInt(windows.absoluteEscape as bigint),
    },
  });
}

function decodedSaleRecord(value: unknown): {
  readonly configuration: CuratedSaleConfiguration;
  readonly record: CuratedFixedSaleRecord;
} {
  const source = tuple(value, "curated fixed sale record");
  const lifecycle = tuple(source.lifecycle, "curated sale lifecycle");
  return Object.freeze({
    configuration: decodedSale(source.config),
    record: Object.freeze({
      saleNonce: uint(BigInt(source.saleNonce as bigint), 256, "saleNonce"),
      saleKind: uint(BigInt(source.saleKind as bigint), 8, "saleKind"),
      configHash: hash(source.configHash, "configHash"),
      saleCreatedAt: uint(
        BigInt(lifecycle.saleCreatedAt as bigint),
        64,
        "saleCreatedAt",
      ),
      saleAdapterRegistryRevision: uint(
        BigInt(lifecycle.saleAdapterRegistryRevision as bigint),
        64,
        "saleAdapterRegistryRevision",
      ),
      artistId: hash(source.artistId, "artistId"),
      bindingGeneration: uint(
        BigInt(source.bindingGeneration as bigint),
        64,
        "bindingGeneration",
      ),
      bindingHash: hash(source.bindingHash, "bindingHash"),
      gate: address(source.gate, "gate"),
      gateCodeHash: hash(source.gateCodeHash, "gateCodeHash"),
      gateConfigHash: hash(source.gateConfigHash, "gateConfigHash"),
      manifestHash: hash(source.manifestHash, "manifestHash"),
      contentCounterId: hash(source.contentCounterId, "contentCounterId"),
      contentCounterConfigHash: hash(
        source.contentCounterConfigHash,
        "contentCounterConfigHash",
      ),
      status: uint(BigInt(source.status as bigint), 8, "status"),
    }),
  });
}

function decodedWindows(value: unknown): CuratedFixedWindowView {
  const source = tuple(value, "curated fixed window view");
  return Object.freeze({
    commitOpen: uint(BigInt(source.commitOpen as bigint), 64, "commitOpen"),
    commitClose: uint(BigInt(source.commitClose as bigint), 64, "commitClose"),
    revealOpen: uint(BigInt(source.revealOpen as bigint), 64, "revealOpen"),
    revealClose: uint(BigInt(source.revealClose as bigint), 64, "revealClose"),
    commitToll: uint(BigInt(source.commitToll as bigint), 64, "commitToll"),
    revealToll: uint(BigInt(source.revealToll as bigint), 64, "revealToll"),
    commitLive: Boolean(source.commitLive),
    revealLive: Boolean(source.revealLive),
    commitMatured: Boolean(source.commitMatured),
    matured: Boolean(source.matured),
    escapeReached: Boolean(source.escapeReached),
    globalPaused: Boolean(source.globalPaused),
    localPaused: Boolean(source.localPaused),
    collectionStopped: Boolean(source.collectionStopped),
  });
}

function decodedExecution(value: unknown): CuratedFixedExecutionRecord {
  const source = tuple(value, "curated fixed execution");
  return Object.freeze({
    saleId: hash(source.saleId, "execution saleId"),
    buyer: address(source.buyer, "execution buyer"),
    recipient: address(source.recipient, "execution recipient"),
    purchaseNonce: uint(
      BigInt(source.purchaseNonce as bigint),
      256,
      "execution purchaseNonce",
      true,
    ),
    authorizationId: hash(source.authorizationId, "authorizationId"),
    authorizationDigest: hash(source.authorizationDigest, "authorizationDigest"),
    contentLeaf: hash(source.contentLeaf, "contentLeaf"),
    tokenDataHash: hash(source.tokenDataHash, "tokenDataHash"),
    mintCommitment: hash(source.mintCommitment, "mintCommitment"),
    price: uint(BigInt(source.price as bigint), 256, "execution price", true),
    tokenId: uint(BigInt(source.tokenId as bigint), 256, "tokenId", true),
    settlementKey: hash(source.settlementKey, "settlementKey"),
    operationRoot: hash(source.operationRoot, "operationRoot"),
    operationId: hash(source.operationId, "operationId"),
  });
}

function assertRecord(
  recordValue: unknown,
  configurationValue: unknown,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly expectedNonce: bigint | null;
    readonly configuration: CuratedFixedConfiguration;
    readonly configurationHash: Hex;
  },
): CuratedFixedSaleRecord {
  const fixed = decodedFixed(configurationValue);
  const decoded = decodedSaleRecord(recordValue);
  const computedSaleId = curatedSaleId(
    expected.chainId,
    expected.adapter,
    0n,
    expected.configuration.sale.collectionId,
    expected.configuration.sale.phaseId,
    decoded.record.saleNonce,
  );
  if (
    render(fixed) !== render(expected.configuration)
    || render(decoded.configuration) !== render(expected.configuration.sale)
    || (expected.expectedNonce !== null && decoded.record.saleNonce !== expected.expectedNonce)
    || decoded.record.saleKind !== 0n
    || !same(decoded.record.configHash, expected.configurationHash)
    || !same(computedSaleId, expected.saleId)
    || decoded.record.status !== 1n
  ) {
    throw new Error("Stored curated fixed sale differs from the reviewed configuration");
  }
  return decoded.record;
}

function revealFee(value: unknown): bigint {
  const quote = tuple(value, "curated reveal quote");
  address(quote.coordinator, "reveal coordinator");
  hash(quote.coordinatorCodeHash, "reveal coordinator code hash");
  const policy = tuple(quote.policy, "curated reveal policy");
  if (!Boolean(policy.declared) || BigInt(policy.requestMode as bigint) > 1n) {
    throw new Error("Missing or unsupported curated reveal policy");
  }
  return uint(
    BigInt(policy.revealFeePerTokenWei as bigint),
    256,
    "revealFeePerTokenWei",
  );
}

function assertExecution(
  value: unknown,
  prepared: PreparedCuratedPublicPurchase | PreparedCuratedSelectionReveal,
): CuratedFixedExecutionRecord {
  const execution = decodedExecution(value);
  const contentLeaf = prepared.kind === "public"
    ? prepared.expectedContentLeaf
    : prepared.contentLeaf;
  if (
    !same(execution.saleId, prepared.saleId)
    || !same(execution.buyer, prepared.caller)
    || !same(execution.recipient, prepared.selection.recipient)
    || execution.purchaseNonce !== prepared.selection.purchaseNonce
    || !same(execution.contentLeaf, contentLeaf)
    || !same(execution.tokenDataHash, prepared.selection.content.tokenDataHash)
    || !same(execution.mintCommitment, prepared.selection.mintCommitment)
    || execution.price !== prepared.configuration.sale.price
  ) {
    throw new Error("Curated execution differs from the reviewed purchase");
  }
  return execution;
}

const inspectionLimitations = Object.freeze([
  "numeric block pin has no reorg hash check",
  "read-only facts do not establish consent, runtime identity, gate state, proof authority or live Manager admission",
  "simulation does not establish Safe authority, transaction inclusion or future-state acceptance",
]);

async function readDependencies(
  provider: Pick<Provider, "call">,
  adapter: Address,
  blockTag: number,
): Promise<{
  readonly core: Address;
  readonly mintManager: Address;
  readonly revenueResolver: Address;
  readonly artistRegistry: Address;
  readonly moduleRegistry: Address;
}> {
  const [[core], [manager], [resolver], [artists], [modules]] = await Promise.all([
    rpc(provider, adapter, "core", [], blockTag),
    rpc(provider, adapter, "mintManager", [], blockTag),
    rpc(provider, adapter, "revenueResolver", [], blockTag),
    rpc(provider, adapter, "artistRegistry", [], blockTag),
    rpc(provider, adapter, "moduleRegistry", [], blockTag),
  ]);
  return Object.freeze({
    core: address(core, "core"),
    mintManager: address(manager, "mintManager"),
    revenueResolver: address(resolver, "revenueResolver"),
    artistRegistry: address(artists, "artistRegistry"),
    moduleRegistry: address(modules, "moduleRegistry"),
  });
}

async function readAndAssertSale(
  provider: Pick<Provider, "call">,
  expected: {
    readonly chainId: bigint;
    readonly adapter: Address;
    readonly saleId: Hex;
    readonly expectedNonce: bigint | null;
    readonly configuration: CuratedFixedConfiguration;
  },
  blockTag: number,
): Promise<CuratedFixedSaleRecord> {
  const [[record], [configuration]] = await Promise.all([
    rpc(provider, expected.adapter, "saleRecord", [expected.saleId], blockTag),
    rpc(
      provider,
      expected.adapter,
      "fixedSaleConfiguration",
      [expected.saleId],
      blockTag,
    ),
  ]);
  return assertRecord(record, configuration, {
    ...expected,
    configurationHash: curatedFixedConfigurationHash(
      expected.chainId,
      expected.adapter,
      expected.configuration,
    ),
  });
}

export async function inspectCuratedFixedRegistration(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedCuratedFixedRegistration,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedCuratedFixedRegistration;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = block(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from curated fixed registration coordinates");
  }
  const [[owner], [nonce], [saleId], [configurationHash], dependencies, timestamp] = await Promise.all([
    rpc(provider, prepared.adapter, "owner", [], blockTag),
    rpc(provider, prepared.adapter, "nextSaleNonce", [], blockTag),
    rpc(
      provider,
      prepared.adapter,
      "saleIdFor",
      [
        0n,
        prepared.configuration.sale.collectionId,
        prepared.configuration.sale.phaseId,
        prepared.expectedNonce,
      ],
      blockTag,
    ),
    rpc(
      provider,
      prepared.adapter,
      "fixedConfigurationHash",
      [prepared.configuration],
      blockTag,
    ),
    readDependencies(provider, prepared.adapter, blockTag),
    blockTimestamp(provider, blockTag),
  ]);
  if (!same(owner, prepared.caller)) {
    throw new Error("Prepared caller is not the current curated fixed owner");
  }
  if (BigInt(nonce as bigint) !== prepared.expectedNonce) {
    throw new Error("Live curated fixed sale nonce differs from the reviewed preimage");
  }
  if (!same(saleId, prepared.expectedSaleId)) {
    throw new Error("Curated fixed sale ID getter differs from the reviewed preimage");
  }
  if (!same(configurationHash, prepared.configurationHash)) {
    throw new Error("Curated fixed configuration getter differs from local recomputation");
  }
  if (timestamp >= prepared.configuration.sale.startsAt) {
    throw new Error("Curated fixed registration requires a strictly future sale start");
  }
  return Object.freeze({
    prepared,
    dependencies,
    checked: Object.freeze([
      "RPC chain, owner, next sale nonce and fixed sale ID",
      "exact fixed configuration hash and configured dependency addresses",
    ]),
    limitations: inspectionLimitations,
  });
}

export async function simulateCuratedFixedRegistration(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedCuratedFixedRegistration,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = block(options.blockTag);
  const inspected = await inspectCuratedFixedRegistration(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed curated fixed registration simulation return");
  }
  const decoded = fixedAbi.decodeFunctionResult("registerCuratedFixedSale", raw);
  const canonical = fixedAbi.encodeFunctionResult("registerCuratedFixedSale", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical curated fixed registration simulation return");
  }
  const saleId = hash(decoded[0], "registered curated fixed saleId");
  if (!same(saleId, prepared.expectedSaleId)) {
    throw new Error("Curated fixed registration returned an unexpected sale ID");
  }
  return saleId;
}

export async function inspectRegisteredCuratedFixedSale(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedFixedRegistration,
  options: { readonly blockTag: number },
): Promise<CuratedFixedSaleRecord> {
  const prepared = samePreparedRegistration(preparedInput);
  const blockTag = block(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from curated fixed registration coordinates");
  }
  return readAndAssertSale(provider, {
    chainId: prepared.chainId,
    adapter: prepared.adapter,
    saleId: prepared.expectedSaleId,
    expectedNonce: prepared.expectedNonce,
    configuration: prepared.configuration,
  }, blockTag);
}

async function inspectEntryBase(
  provider: Pick<Provider, "getNetwork" | "call">,
  prepared: PreparedCuratedPublicPurchase | PreparedCuratedSelectionCommit,
  blockTag: number,
): Promise<{
  readonly record: CuratedFixedSaleRecord;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
}> {
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from curated fixed entry coordinates");
  }
  const [record, [nextNonce], [purchaseId], dependencies] = await Promise.all([
    readAndAssertSale(provider, {
      chainId: prepared.chainId,
      adapter: prepared.adapter,
      saleId: prepared.saleId,
      expectedNonce: null,
      configuration: prepared.configuration,
    }, blockTag),
    rpc(
      provider,
      prepared.adapter,
      "nextPurchaseNonce",
      [prepared.saleId, prepared.caller],
      blockTag,
    ),
    rpc(
      provider,
      prepared.adapter,
      "purchaseIdFor",
      [
        prepared.saleId,
        prepared.caller,
        prepared.kind === "public"
          ? prepared.selection.purchaseNonce
          : prepared.purchaseNonce,
      ],
      blockTag,
    ),
    readDependencies(provider, prepared.adapter, blockTag),
  ]);
  const expectedNonce = prepared.kind === "public"
    ? prepared.selection.purchaseNonce
    : prepared.purchaseNonce;
  if (BigInt(nextNonce as bigint) !== expectedNonce) {
    throw new Error("Live curated buyer purchase nonce differs from the reviewed entry");
  }
  if (!same(purchaseId, prepared.expectedPurchaseId)) {
    throw new Error("Curated purchase ID getter differs from local recomputation");
  }
  return Object.freeze({ record, dependencies });
}

export async function inspectCuratedPublicPurchase(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedCuratedPublicPurchase,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedCuratedPublicPurchase;
  readonly record: CuratedFixedSaleRecord;
  readonly revealFeePerTokenWei: bigint;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedPublic(preparedInput);
  const blockTag = block(options.blockTag);
  const [base, [quote], timestamp] = await Promise.all([
    inspectEntryBase(provider, prepared, blockTag),
    rpc(provider, prepared.adapter, "saleRevealQuote", [prepared.saleId], blockTag),
    blockTimestamp(provider, blockTag),
  ]);
  const fee = revealFee(quote);
  if (prepared.revealFeeAllowance < fee) {
    throw new Error("Curated public reveal fee allowance is below the pinned quote");
  }
  if (prepared.call.value !== prepared.configuration.sale.price + prepared.revealFeeAllowance) {
    throw new Error("Curated public call value differs from price plus fee allowance");
  }
  if (
    timestamp < prepared.configuration.sale.startsAt
    || timestamp >= prepared.configuration.sale.endsAt
  ) {
    throw new Error("Curated PUBLIC sale is outside its half-open purchase window");
  }
  return Object.freeze({
    prepared,
    record: base.record,
    revealFeePerTokenWei: fee,
    dependencies: base.dependencies,
    checked: Object.freeze([
      "stored fixed sale/configuration, purchase nonce and original purchase ID",
      "current reveal quote, exact public call value and configured dependency addresses",
    ]),
    limitations: inspectionLimitations,
  });
}

async function simulateExecution(
  provider: Pick<Provider, "call">,
  prepared: PreparedCuratedPublicPurchase | PreparedCuratedSelectionReveal,
  method: "purchaseSelectedContent" | "revealSelection",
  blockTag: number,
): Promise<CuratedFixedExecutionRecord> {
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error(`Malformed ${method} simulation return`);
  }
  const decoded = fixedAbi.decodeFunctionResult(method, raw);
  const canonical = fixedAbi.encodeFunctionResult(method, decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error(`Noncanonical ${method} simulation return`);
  }
  return assertExecution(decoded[0], prepared);
}

export async function simulateCuratedPublicPurchase(
  provider: Pick<Provider, "getNetwork" | "getBlock" | "call">,
  preparedInput: PreparedCuratedPublicPurchase,
  options: { readonly blockTag: number },
): Promise<CuratedFixedExecutionRecord> {
  const blockTag = block(options.blockTag);
  const inspected = await inspectCuratedPublicPurchase(
    provider,
    preparedInput,
    { blockTag },
  );
  return simulateExecution(
    provider,
    inspected.prepared,
    "purchaseSelectedContent",
    blockTag,
  );
}

export async function inspectCuratedSelectionCommit(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedSelectionCommit,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedCuratedSelectionCommit;
  readonly record: CuratedFixedSaleRecord;
  readonly windows: CuratedFixedWindowView;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedCommit(preparedInput);
  const blockTag = block(options.blockTag);
  const [base, [commitment], [windowsValue]] = await Promise.all([
    inspectEntryBase(provider, prepared, blockTag),
    rpc(
      provider,
      prepared.adapter,
      "selectionCommitment",
      [prepared.saleId, prepared.caller, prepared.contentLeaf, prepared.salt],
      blockTag,
    ),
    rpc(provider, prepared.adapter, "selectionWindows", [prepared.saleId], blockTag),
  ]);
  if (!same(commitment, prepared.commitment)) {
    throw new Error("Curated selection commitment getter differs from local recomputation");
  }
  const windows = decodedWindows(windowsValue);
  if (!windows.commitLive) {
    throw new Error("Curated selection commit window is not live at the pinned block");
  }
  if (prepared.call.value !== prepared.configuration.sale.price) {
    throw new Error("Curated selection commitment must attach exactly the immutable price");
  }
  return Object.freeze({
    prepared,
    record: base.record,
    windows,
    dependencies: base.dependencies,
    checked: Object.freeze([
      "stored fixed sale/configuration, purchase nonce, purchase ID and commitment digest",
      "effective commit window and exact price-only deposit",
    ]),
    limitations: inspectionLimitations,
  });
}

export async function simulateCuratedSelectionCommit(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedSelectionCommit,
  options: { readonly blockTag: number },
): Promise<Hex> {
  const blockTag = block(options.blockTag);
  const inspected = await inspectCuratedSelectionCommit(
    provider,
    preparedInput,
    { blockTag },
  );
  const prepared = inspected.prepared;
  const raw = await provider.call({
    ...prepared.call,
    from: prepared.caller,
    blockTag,
  });
  if (typeof raw !== "string" || !isHexString(raw, true)) {
    throw new Error("Malformed curated selection commitment simulation return");
  }
  const decoded = fixedAbi.decodeFunctionResult("commitSelection", raw);
  const canonical = fixedAbi.encodeFunctionResult("commitSelection", decoded);
  if (canonical.toLowerCase() !== raw.toLowerCase()) {
    throw new Error("Noncanonical curated selection commitment simulation return");
  }
  const purchaseId = hash(decoded[0], "committed purchaseId");
  if (!same(purchaseId, prepared.expectedPurchaseId)) {
    throw new Error("Curated selection commitment returned an unexpected purchase ID");
  }
  return purchaseId;
}

export async function inspectCuratedSelectionDeposit(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedSelectionCommit,
  options: { readonly blockTag: number },
): Promise<CuratedSelectionDepositInspection> {
  const prepared = samePreparedCommit(preparedInput);
  const blockTag = block(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from curated selection commitment coordinates");
  }
  const [recordValue, purchaseIdValue, nonceValue] = await rpc(
    provider,
    prepared.adapter,
    "selectionDeposit",
    [prepared.saleId, prepared.caller, prepared.commitment],
    blockTag,
  );
  const record = tuple(recordValue, "selection deposit");
  const inspection = Object.freeze({
    amount: uint(BigInt(record.amount as bigint), 256, "selection deposit amount"),
    committedBlock: uint(
      BigInt(record.committedBlock as bigint),
      256,
      "selection committed block",
    ),
    status: uint(BigInt(record.status as bigint), 8, "selection deposit status"),
    purchaseId: hash(purchaseIdValue, "selection deposit purchaseId"),
    purchaseNonce: uint(
      BigInt(nonceValue as bigint),
      256,
      "selection deposit purchaseNonce",
      true,
    ),
  });
  if (
    inspection.amount !== prepared.configuration.sale.price
    || inspection.status !== 1n
    || !same(inspection.purchaseId, prepared.expectedPurchaseId)
    || inspection.purchaseNonce !== prepared.purchaseNonce
  ) {
    throw new Error("Stored curated selection deposit differs from the reviewed commitment");
  }
  return inspection;
}

export async function inspectCuratedSelectionReveal(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedSelectionReveal,
  options: { readonly blockTag: number },
): Promise<{
  readonly prepared: PreparedCuratedSelectionReveal;
  readonly record: CuratedFixedSaleRecord;
  readonly deposit: CuratedSelectionDepositInspection;
  readonly windows: CuratedFixedWindowView;
  readonly revealFeePerTokenWei: bigint;
  readonly dependencies: Awaited<ReturnType<typeof readDependencies>>;
  readonly checked: readonly string[];
  readonly limitations: readonly string[];
}> {
  const prepared = samePreparedReveal(preparedInput);
  const blockTag = block(options.blockTag);
  const network = await provider.getNetwork();
  if (network.chainId !== prepared.chainId) {
    throw new Error("RPC chain differs from curated selection reveal coordinates");
  }
  const [record, [depositValue, purchaseIdValue, nonceValue], [commitment], [windowsValue], [quote], dependencies] = await Promise.all([
    readAndAssertSale(provider, {
      chainId: prepared.chainId,
      adapter: prepared.adapter,
      saleId: prepared.saleId,
      expectedNonce: null,
      configuration: prepared.configuration,
    }, blockTag),
    rpc(
      provider,
      prepared.adapter,
      "selectionDeposit",
      [prepared.saleId, prepared.caller, prepared.commitment],
      blockTag,
    ),
    rpc(
      provider,
      prepared.adapter,
      "selectionCommitment",
      [prepared.saleId, prepared.caller, prepared.contentLeaf, prepared.salt],
      blockTag,
    ),
    rpc(provider, prepared.adapter, "selectionWindows", [prepared.saleId], blockTag),
    rpc(provider, prepared.adapter, "saleRevealQuote", [prepared.saleId], blockTag),
    readDependencies(provider, prepared.adapter, blockTag),
  ]);
  const rawDeposit = tuple(depositValue, "selection deposit");
  const deposit = Object.freeze({
    amount: uint(BigInt(rawDeposit.amount as bigint), 256, "selection deposit amount"),
    committedBlock: uint(
      BigInt(rawDeposit.committedBlock as bigint),
      256,
      "selection committed block",
    ),
    status: uint(BigInt(rawDeposit.status as bigint), 8, "selection deposit status"),
    purchaseId: hash(purchaseIdValue, "selection deposit purchaseId"),
    purchaseNonce: uint(
      BigInt(nonceValue as bigint),
      256,
      "selection deposit purchaseNonce",
      true,
    ),
  });
  const windows = decodedWindows(windowsValue);
  const fee = revealFee(quote);
  if (
    deposit.amount !== prepared.configuration.sale.price
    || deposit.status !== 1n
    || deposit.committedBlock >= BigInt(blockTag)
    || !same(deposit.purchaseId, prepared.expectedPurchaseId)
    || deposit.purchaseNonce !== prepared.selection.purchaseNonce
    || !same(commitment, prepared.commitment)
  ) {
    throw new Error("Stored curated selection deposit differs from the reviewed reveal");
  }
  if (!windows.revealLive) {
    throw new Error("Curated selection reveal window is not live at the pinned block");
  }
  if (prepared.revealFeeAllowance < fee || prepared.call.value !== prepared.revealFeeAllowance) {
    throw new Error("Curated selection reveal fee-only allowance is below the pinned quote");
  }
  return Object.freeze({
    prepared,
    record,
    deposit,
    windows,
    revealFeePerTokenWei: fee,
    dependencies,
    checked: Object.freeze([
      "stored fixed sale/configuration and exact pending price deposit",
      "commitment, original purchase nonce/ID, later block and effective reveal window",
      "current reveal quote and fee-only attached value",
    ]),
    limitations: inspectionLimitations,
  });
}

export async function simulateCuratedSelectionReveal(
  provider: Pick<Provider, "getNetwork" | "call">,
  preparedInput: PreparedCuratedSelectionReveal,
  options: { readonly blockTag: number },
): Promise<CuratedFixedExecutionRecord> {
  const blockTag = block(options.blockTag);
  const inspected = await inspectCuratedSelectionReveal(
    provider,
    preparedInput,
    { blockTag },
  );
  return simulateExecution(provider, inspected.prepared, "revealSelection", blockTag);
}

export async function readCuratedFixedExecution(
  provider: Pick<Provider, "call">,
  adapter: Address,
  purchaseId: Hex,
  options: { readonly blockTag: number },
): Promise<CuratedFixedExecutionRecord> {
  const blockTag = block(options.blockTag);
  const [execution] = await rpc(
    provider,
    address(adapter, "adapter"),
    "executionRecord",
    [hash(purchaseId, "purchaseId")],
    blockTag,
  );
  return decodedExecution(execution);
}

function preparedAction(
  kind: PreparedCuratedFixedAction["kind"],
  adapter: Address,
  caller: Address,
  method: string,
  args: readonly unknown[],
): PreparedCuratedFixedAction {
  const normalizedAdapter = address(adapter, "adapter");
  return Object.freeze({
    kind,
    adapter: normalizedAdapter,
    caller: address(caller, "caller"),
    call: unsignedCall(normalizedAdapter, method, args),
  });
}

export function prepareCuratedMaturityUnlock(
  adapter: Address,
  caller: Address,
  saleId: Hex,
  buyer: Address,
  commitment: Hex,
): PreparedCuratedFixedAction {
  return preparedAction(
    "maturity-unlock",
    adapter,
    caller,
    "unlockSelectionRefund",
    [
      hash(saleId, "saleId"),
      address(buyer, "buyer"),
      hash(commitment, "commitment"),
    ],
  );
}

export function prepareCuratedReasonUnlock(
  chainId: bigint,
  adapter: Address,
  caller: Address,
  saleId: Hex,
  buyer: Address,
  configuration: CuratedFixedConfiguration,
  selection: CuratedSelection,
  salt: Hex,
  reason: bigint,
): PreparedCuratedFixedAction {
  const normalizedChainId = uint(chainId, 256, "chainId", true);
  const normalizedAdapter = address(adapter, "adapter");
  const normalizedSaleId = hash(saleId, "saleId");
  const normalizedBuyer = address(buyer, "buyer");
  const normalizedConfiguration = normalizeCuratedFixedConfiguration(configuration);
  if (normalizedConfiguration.mode !== CURATED_FIXED_COMMIT_REVEAL) {
    throw new Error("Reason unlock requires a COMMIT_REVEAL configuration");
  }
  const normalizedSelection = normalizeSelectionForSale(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedConfiguration,
    selection,
  );
  const normalizedSalt = hash(salt, "salt", true);
  const normalizedReason = uint(reason, 8, "unlock reason", true);
  if (normalizedReason > 5n) {
    throw new Error("Curated selection unlock reason must be 1 through 5");
  }
  const commitment = curatedSelectionCommitment(
    normalizedChainId,
    normalizedAdapter,
    normalizedSaleId,
    normalizedBuyer,
    normalizedSelection.leaf,
    normalizedSalt,
  );
  return preparedAction(
    "reason-unlock",
    normalizedAdapter,
    caller,
    "unlockSelectionRefundForReason",
    [
      normalizedSaleId,
      normalizedBuyer,
      commitment,
      normalizedSelection.selection,
      normalizedSalt,
      normalizedReason,
    ],
  );
}

function recipient(value: Address, adapter: Address): Address {
  const normalized = address(value, "recipient");
  if (same(normalized, adapter)) {
    throw new Error("Curated refund recipient cannot be the adapter");
  }
  return normalized;
}

export function prepareCuratedSelectionRefundClaim(
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  claimRecipient: Address,
): PreparedCuratedFixedAction {
  const normalizedAdapter = address(adapter, "adapter");
  return preparedAction(
    "selection-claim",
    normalizedAdapter,
    buyer,
    "claimSelectionRefund",
    [hash(saleId, "saleId"), recipient(claimRecipient, normalizedAdapter)],
  );
}

export function prepareCuratedSelectionRefundDelegatedClaim(
  adapter: Address,
  delegate: Address,
  saleId: Hex,
  buyer: Address,
  witness: CuratedDelegationWitness,
): PreparedCuratedFixedAction {
  return preparedAction(
    "selection-delegated-claim",
    adapter,
    delegate,
    "claimSelectionRefundDelegated",
    [
      hash(saleId, "saleId"),
      address(buyer, "buyer"),
      normalizeCuratedDelegationWitness(witness),
    ],
  );
}

export function prepareCuratedExcessRefundClaim(
  adapter: Address,
  buyer: Address,
  saleId: Hex,
  claimRecipient: Address,
): PreparedCuratedFixedAction {
  const normalizedAdapter = address(adapter, "adapter");
  return preparedAction(
    "excess-claim",
    normalizedAdapter,
    buyer,
    "claimRefund",
    [hash(saleId, "saleId"), recipient(claimRecipient, normalizedAdapter)],
  );
}

export function prepareCuratedExcessRefundDelegatedClaim(
  adapter: Address,
  delegate: Address,
  saleId: Hex,
  buyer: Address,
  witness: CuratedDelegationWitness,
): PreparedCuratedFixedAction {
  return preparedAction(
    "excess-delegated-claim",
    adapter,
    delegate,
    "claimRefundFor",
    [
      hash(saleId, "saleId"),
      address(buyer, "buyer"),
      normalizeCuratedDelegationWitness(witness),
    ],
  );
}

export function prepareCuratedFixedCancel(
  adapter: Address,
  owner: Address,
  saleId: Hex,
): PreparedCuratedFixedAction {
  return preparedAction(
    "cancel",
    adapter,
    owner,
    "cancelSale",
    [hash(saleId, "saleId")],
  );
}

export function prepareCuratedContestSync(
  adapter: Address,
  caller: Address,
  collectionId: bigint,
): PreparedCuratedFixedAction {
  return preparedAction(
    "contest-sync",
    adapter,
    caller,
    "syncCollectionContest",
    [uint(collectionId, 256, "collectionId", true)],
  );
}

async function readCredit(
  provider: Pick<Provider, "call">,
  method: "selectionRefundCredit" | "refundableBalance",
  adapter: Address,
  saleId: Hex,
  buyer: Address,
  options: { readonly blockTag: number },
): Promise<bigint> {
  const blockTag = block(options.blockTag);
  const [amount] = await rpc(
    provider,
    address(adapter, "adapter"),
    method,
    [hash(saleId, "saleId"), address(buyer, "buyer")],
    blockTag,
  );
  return uint(BigInt(amount as bigint), 256, `${method} amount`);
}

export async function readCuratedSelectionRefundCredit(
  provider: Pick<Provider, "call">,
  adapter: Address,
  saleId: Hex,
  buyer: Address,
  options: { readonly blockTag: number },
): Promise<bigint> {
  return readCredit(
    provider,
    "selectionRefundCredit",
    adapter,
    saleId,
    buyer,
    options,
  );
}

export async function readCuratedExcessRefundCredit(
  provider: Pick<Provider, "call">,
  adapter: Address,
  saleId: Hex,
  buyer: Address,
  options: { readonly blockTag: number },
): Promise<bigint> {
  return readCredit(provider, "refundableBalance", adapter, saleId, buyer, options);
}
