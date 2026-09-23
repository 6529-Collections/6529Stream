import {
  AbiCoder,
  Interface,
  ParamType,
  TypedDataEncoder,
  ZeroAddress as Z_ADDRESS,
  ZeroHash as Z_HASH,
  getAddress,
  id,
  isHexString,
  keccak256,
  toUtf8Bytes,
  type Provider
} from 'ethers';
import type { Address, Hex } from './generated/contracts.js';
import { requireSafeExecution } from './safe.js';
import * as direct from './current-direct-conservation.js';

const ZeroAddress = Z_ADDRESS as Address;
const ZeroHash = Z_HASH as Hex;
const coder = AbiCoder.defaultAbiCoder();
export interface DirectConservationCodePin {
  readonly address: Address;
  readonly codeHash: Hex;
}

export interface DirectConservationDeployment {
  readonly chainId: bigint;
  readonly product: DirectConservationCodePin;
  readonly core: DirectConservationCodePin;
  readonly manager: DirectConservationCodePin;
  readonly moduleRegistry: DirectConservationCodePin;
}

export interface DirectConservationBlock {
  readonly blockNumber: number;
  readonly blockHash: Hex;
  readonly timestamp: bigint;
}

export interface DirectConservationAdmission {
  readonly status: bigint;
  readonly registeredAt: bigint;
  readonly statusUpdatedAt: bigint;
  readonly revision: bigint;
}

export interface DirectConservationMintOrigin {
  readonly authorizationId: Hex;
  readonly authorizationDigest: Hex;
  readonly collectionId: bigint;
  readonly operationRoot: Hex;
  readonly operationId: Hex;
  readonly boundMintPolicyHash: Hex;
  readonly primaryPolicyHash: Hex;
  readonly profileId: Hex;
  readonly wallet: Address;
  readonly artist: Address;
}

export interface DirectConservationCapture {
  readonly deployment: DirectConservationDeployment;
  readonly prepared: direct.DirectConservationCall;
  readonly observed: DirectConservationBlock;
  readonly bindings: direct.DirectConservationBindings;
  readonly admission: DirectConservationAdmission | null;
  readonly floor: DirectConservationCodePin | null;
  readonly mint: DirectConservationMintOrigin | null;
  readonly sale: direct.DirectConservationERC20SaleRecord | null;
  readonly auction: direct.DirectConservationAuction | null;
  readonly paymentIntent: "exempt-literal-caller" | "signed-intent" | null;
  readonly refundCredit: bigint | null;
  readonly nextSaleNonce: bigint | null;
  readonly dependencies: readonly DirectConservationCodePin[];
  /** Present only for original local owner controls; no commerce admission is inferred. */
  readonly control?: direct.DirectConservationControlState;
  readonly captureHash: Hex;
  readonly admissionAuthority: "original-product-call-simulation";
}

export interface DirectConservationSimulation {
  readonly capture: DirectConservationCapture;
  readonly returnData: Hex;
  readonly tokenId: bigint | null;
  readonly operationRoot: Hex | null;
}

export interface DirectConservationFloorHistory {
  readonly chainId: bigint;
  readonly floor: DirectConservationCodePin;
  readonly core: Address;
  readonly observed: DirectConservationBlock;
  readonly receipt: direct.DirectConservationFloorReceipt;
  readonly firstSale: direct.DirectConservationFirstSaleReceipt;
  readonly release: direct.DirectConservationReleaseReceipt | null;
}

type Reader = Pick<Provider, "getNetwork" | "getBlock" | "getCode" | "call">;
type ReceiptReader = Reader & Pick<Provider, "getTransaction" | "getTransactionReceipt">;
const abi = new Interface(
  [
    "function directPrimaryBindings() view returns ((address core, bytes32 coreCodeHash, address mintManager, bytes32 mintManagerCodeHash, uint256 deploymentChainId, bytes32 productKind))",
    "function directPrimarySaleReceipt(bytes32 authorizationId) view returns ((bytes32 authorizationDigest, uint256 collectionId, uint256 tokenId, bytes32 operationRoot, bytes32 operationId, bytes32 boundMintPolicyHash, bytes32 expectedPrimaryPolicyHash, bytes32 profileId, address wallet, uint64 createdAt, bool escrowed, address payer, uint64 registryRevision, address beneficiary, address asset, uint256 amount))",
    "function directPrimarySaleReceiptHash(bytes32 authorizationId) view returns (bytes32)",
    "function authorizationUsed(address, bytes32) view returns (bool)",
    "function authorizationDigest((uint256 collectionId, bytes32 phaseId, address payer, address recipient, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 price, bytes32 nonce, uint64 deadline, uint64 signerEpoch) sale) view returns (bytes32)",
    "function authorizationId(address artist, bytes32 nonce) view returns (bytes32)",
    "function primaryPolicy(uint256 collectionId) view returns (bytes32 policyHash, bytes32 profileId, address wallet)",
    "function paused() view returns (bool)",
    "function signerEpoch() view returns (uint64)",
    "function platformSigner() view returns (address)",
    "function artistRegistry() view returns (address)",
    "function artistRegistryCodeHash() view returns (bytes32)",
    "function revenueResolver() view returns (address)",
    "function splitFactory() view returns (address)",
    "function revenueEscrow() view returns (address)",
    "function fundingFactoryCodeHash() view returns (bytes32)",
    "function fundingEscrowCodeHash() view returns (bytes32)",
    "function supportsInterface(bytes4 interfaceId) view returns (bool)",
    "function authorizationDigest((bytes32 saleId, bytes32 saleConfigHash, address payer, address recipient, address artist, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization) view returns (bytes32)",
    "function primaryPolicy(uint256 collectionId, bytes32 revenueClass) view returns (bytes32 policyHash, bytes32 profileId, address wallet)",
    "function saleRecord(bytes32 saleId) view returns (((uint256 collectionId, bytes32 phaseId, address asset, bytes32 revenueClass, uint256 price, bytes32 mintPolicyHash, bytes32 expectedPrimaryPolicyHash, uint64 startsAt, uint64 endsAt) config, uint256 saleNonce, bytes32 configHash, bool cancelled))",
    "function nextSaleNonce() view returns (uint256)",
    "function saleIdFor(uint256 collectionId, bytes32 phaseId, uint256 saleNonce) view returns (bytes32)",
    "function owner() view returns (address)",
    "function assetPolicyRegistry() view returns (address)",
    "function isPaymentIntentNonceUsed(address payer, bytes32 nonce) view returns (bool)",
    "function paymentIntentDigest((address payer, address asset, uint256 maxAmount, bytes32 saleRef, bytes32 expectedPrimaryPolicyHash, bytes32 nonce, uint64 deadline) intent) view returns (bytes32)",
    "function authorizationDigest((uint256 collectionId, bytes32 phaseId, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 reservePrice, uint64 startTime, uint64 endTime, uint32 extensionWindow, uint16 minBidIncrementBps, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization) view returns (bytes32)",
    "function auction(uint256 tokenId) view returns ((address artist, address wallet, bytes32 profileId, uint256 reservePrice, uint64 startTime, uint64 endTime, uint32 extensionWindow, uint16 minBidIncrementBps, address highestBidder, address deliveryRecipient, uint256 highestBid, bool settled, bool cancelled, address pendingNoBidNftClaimant, bytes32 authorizationId, bytes32 operationRoot, bytes32 primaryPolicyHash))",
    "function auctionStatus(uint256 tokenId) view returns (uint8)",
    "function minimumBid(uint256 tokenId) view returns (uint256)",
    "function refundCredit(address) view returns (uint256)",
    "function totalBidEscrow() view returns (uint256)",
    "function totalRefundOwed() view returns (uint256)",
    "function core() view returns (address)",
    "function moduleRegistry() view returns (address)",
    "function previewSingleStepMintOperation((uint256 collectionId, bytes32 phaseId, address payer, address authorizer, address[] initialRecipients, address[] beneficiaries, bytes[] tokenData, bytes32[] mintCommitments, bytes32 expectedPolicyHash, bytes32 authorizationId, bytes32 contextHash, bytes resolverData) batch, bytes gateData) view returns (bytes32 operationRoot, bytes32[] operationIds)",
    "function isOperationRootUsed(bytes32 operationRoot) view returns (bool)",
    "function isAuthorizationUsed(bytes32 authorizationId) view returns (bool)",
    "function getSatellitePointer(bytes32 pointerType) view returns (address target, bytes32 codeHash, bool frozen, bytes32 moduleType, bytes4 interfaceId, address registry, uint8 registryStatus, bytes32 moduleManifestHash, bytes32 deploymentManifestHash, uint64 revision)",
    "function conservationFloor() view returns (address ledger, bytes32 runtimeCodeHash)",
    "function collectionExists(uint256 collectionId) view returns (bool)",
    "function tokenCollectionIdentity(uint256 tokenId) view returns (bool mappingExists, uint256 collectionId, uint256 collectionSerial, bool burned)",
    "function tokenLifecycle(uint256 tokenId) view returns (uint8 lifecycle)",
    "function moduleRecord(address module) view returns ((uint8 status, bytes32 moduleType, bytes32 moduleVersion, bytes4 interfaceId, uint32 moduleGasLimit, bytes32 runtimeCodeHash, bytes32 deploymentManifestHash, bytes32 moduleManifestHash, string moduleManifestURI, uint64 registeredAt, uint64 statusUpdatedAt, uint64 revision))",
    "function deploymentChainId() view returns (uint256)",
    "function directPrimarySaleFloorReceipt(bytes32 key) view returns ((bytes32 receiptHash, address adapter, bytes32 adapterCodeHash, bytes32 directKey, bytes32 authorizationId, bytes32 originalReceiptHash, (address core, bytes32 coreCodeHash, address mintManager, bytes32 mintManagerCodeHash, uint256 deploymentChainId, bytes32 productKind) bindings, (bytes32 authorizationDigest, uint256 collectionId, uint256 tokenId, bytes32 operationRoot, bytes32 operationId, bytes32 boundMintPolicyHash, bytes32 expectedPrimaryPolicyHash, bytes32 profileId, address wallet, uint64 createdAt, bool escrowed, address payer, uint64 registryRevision, address beneficiary, address asset, uint256 amount) sale, bytes32 effectiveTier, bytes32 firstSaleReceiptHash, bytes32 releaseReceiptHash, uint64 recordedAt))",
    "function firstSale(uint256 cid) view returns ((bytes32 receiptHash, uint256 collectionId, bytes32 effectiveTier, address recorder, bytes32 settlementKey, uint64 recordedAt, uint64 sourceId, bytes32 sourceSetHash, (bytes32 artistId, bytes32 identityRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsRecordHash, bytes32 personhoodEvidenceHash, bool platformWorks) facts))",
    "function releaseFloorReceipt(bytes32 key) view returns ((bytes32 receiptHash, bytes32 releaseKey, uint256 collectionId, bytes32 effectiveTier, address recorder, bytes32 settlementKey, uint64 recordedAt, uint64 sourceId, bytes32 sourceSetHash, (bytes32 scopeSubject, bytes32 membershipHash, bytes32 mediaInventoryHash, bytes32 scriptSourceHash, bytes32 sourceContextHash, bool scriptWork) context, (bytes32 sourceContextHash, bytes32 mediaEvidenceHash, bytes32 referenceEvidenceHash) facts))",
    "function settlementReceipt(bytes32 key) view returns ((bytes32 receiptHash, address recorder, bytes32 recorderCodeHash, bytes32 settlementKey, bytes32 candidatePayloadHash, bytes32 candidateCommitment, bytes32 resultHash, uint256 collectionId, uint256 tokenId, bytes32 effectiveTier, bytes32 firstSaleReceiptHash, bytes32 releaseReceiptHash, uint64 recordedAt))",
    "function gasParameter(bytes32 parameterId) view returns (uint256 value)",
    "event DirectPrimarySaleRecorded(bytes32 indexed authorizationId, bytes32 indexed receiptHash, uint256 indexed tokenId, (bytes32 authorizationDigest, uint256 collectionId, uint256 tokenId, bytes32 operationRoot, bytes32 operationId, bytes32 boundMintPolicyHash, bytes32 expectedPrimaryPolicyHash, bytes32 profileId, address wallet, uint64 createdAt, bool escrowed, address payer, uint64 registryRevision, address beneficiary, address asset, uint256 amount) receipt, uint16 schemaVersion)",
    "event NativeSaleSettled(bytes32 indexed authorizationId, bytes32 indexed operationRoot, uint256 indexed tokenId, bytes32 authorizationDigest, bytes32 profileId, address wallet, uint256 amount)",
    "event SaleAuthorizationCancelled(address indexed artist, bytes32 indexed nonce)",
    "event SaleParticipants(bytes32 indexed authorizationId, uint256 indexed collectionId, address indexed artist, address payer, address recipient)",
    "event SaleRevenueFunded(uint16 schemaVersion, bytes32 indexed authorizationId, bytes32 indexed operationRoot, bytes32 indexed profileId, address wallet, address asset, uint256 amount, bool escrowed)",
    "event ERC20SaleParticipants(bytes32 indexed authorizationId, address indexed artist, address indexed payer, address recipient, bytes32 primaryPolicyHash)",
    "event ERC20SaleSettled(bytes32 indexed saleId, bytes32 indexed operationRoot, uint256 indexed tokenId, bytes32 authorizationId, bytes32 authorizationDigest, bytes32 profileId, address wallet, address asset, uint256 amount)",
    "event PaymentIntentConsumed(address indexed payer, bytes32 indexed saleRef, bytes32 indexed nonce, uint16 schemaVersion, address asset, uint256 amount)",
    "event PaymentIntentRevoked(address indexed payer, bytes32 indexed nonce, uint16 schemaVersion)",
    "event SaleCancelled(bytes32 indexed saleId)",
    "event SaleConfigured(bytes32 indexed saleId, uint256 indexed collectionId, bytes32 indexed phaseId, uint256 saleNonce, bytes32 saleConfigHash)",
    "event AuctionAuthorizationCancelled(address indexed artist, bytes32 indexed nonce)",
    "event AuctionBidPlaced(uint256 indexed tokenId, address indexed bidder, address recipient, uint256 amount, uint64 endTime)",
    "event AuctionCancelled(uint256 indexed tokenId, address indexed recipient)",
    "event AuctionCreated(uint256 indexed tokenId, address indexed artist, bytes32 indexed authorizationId, bytes32 operationRoot, bytes32 authorizationDigest, bytes32 profileId, address wallet)",
    "event AuctionRecipientChanged(uint256 indexed tokenId, address indexed recipient)",
    "event AuctionRefundCredited(address indexed bidder, uint256 indexed tokenId, uint256 amount)",
    "event AuctionRefundWithdrawn(address indexed bidder, address indexed recipient, uint256 amount)",
    "event AuctionSettled(uint256 indexed tokenId, address indexed bidder, address indexed recipient, address wallet, uint256 amount)",
    "event AuctionTerms(uint256 indexed tokenId, uint256 reservePrice, uint64 startTime, uint64 endTime, uint32 extensionWindow, uint16 minBidIncrementBps)",
    "event NoBidAuctionNFTClaimPending(uint256 indexed tokenId, address indexed claimant)",
    "event ConservationDirectPrimarySaleRecorded(bytes32 indexed directKey, bytes32 indexed receiptHash, (bytes32 receiptHash, address adapter, bytes32 adapterCodeHash, bytes32 directKey, bytes32 authorizationId, bytes32 originalReceiptHash, (address core, bytes32 coreCodeHash, address mintManager, bytes32 mintManagerCodeHash, uint256 deploymentChainId, bytes32 productKind) bindings, (bytes32 authorizationDigest, uint256 collectionId, uint256 tokenId, bytes32 operationRoot, bytes32 operationId, bytes32 boundMintPolicyHash, bytes32 expectedPrimaryPolicyHash, bytes32 profileId, address wallet, uint64 createdAt, bool escrowed, address payer, uint64 registryRevision, address beneficiary, address asset, uint256 amount) sale, bytes32 effectiveTier, bytes32 firstSaleReceiptHash, bytes32 releaseReceiptHash, uint64 recordedAt) receipt, uint16 schemaVersion)",
    "event ConservationFirstSaleRecorded(uint256 indexed collectionId, bytes32 indexed receiptHash, (bytes32 receiptHash, uint256 collectionId, bytes32 effectiveTier, address recorder, bytes32 settlementKey, uint64 recordedAt, uint64 sourceId, bytes32 sourceSetHash, (bytes32 artistId, bytes32 identityRecordHash, bytes32 intentRecordHash, bytes32 intentWaiverRecordHash, bytes32 interviewEvidenceHash, bytes32 rightsRecordHash, bytes32 personhoodEvidenceHash, bool platformWorks) facts) receipt, uint16 schemaVersion)",
    "event ConservationPrimarySalePrepared(bytes32 indexed preparationHash, address indexed recorder, bytes32 indexed settlementKey, bytes32 collectionEvidenceHash, bytes32 releaseEvidenceHash, uint16 schemaVersion)",
    "event ConservationReleaseFloorRecorded(bytes32 indexed releaseKey, bytes32 indexed receiptHash, (bytes32 receiptHash, bytes32 releaseKey, uint256 collectionId, bytes32 effectiveTier, address recorder, bytes32 settlementKey, uint64 recordedAt, uint64 sourceId, bytes32 sourceSetHash, (bytes32 scopeSubject, bytes32 membershipHash, bytes32 mediaInventoryHash, bytes32 scriptSourceHash, bytes32 sourceContextHash, bool scriptWork) context, (bytes32 sourceContextHash, bytes32 mediaEvidenceHash, bytes32 referenceEvidenceHash) facts) receipt, uint16 schemaVersion)",
    "event ConservationSettlementRecorded(bytes32 indexed settlementKey, bytes32 indexed receiptHash, (bytes32 receiptHash, address recorder, bytes32 recorderCodeHash, bytes32 settlementKey, bytes32 candidatePayloadHash, bytes32 candidateCommitment, bytes32 resultHash, uint256 collectionId, uint256 tokenId, bytes32 effectiveTier, bytes32 firstSaleReceiptHash, bytes32 releaseReceiptHash, uint64 recordedAt) receipt, uint16 schemaVersion)",
    "event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)",
    "event SalePlatformSignerChanged(address indexed signer, uint64 epoch)",
    "event SalesPauseChanged(bool paused)",
    "event PlatformSignerChanged(address indexed signer, uint64 epoch)",
    "event SignatureGasLimitRaised(uint256 previousValue, uint256 value)",
    "event AuctionPlatformSignerChanged(address indexed signer, uint64 epoch)",
    "event AuctionsPauseChanged(bool paused)",
    "function signatureGasLimit() view returns (uint256)"
  ]
);

function keys(value: unknown, required: readonly string[], optional: readonly string[] = []): void {
  if (!value || typeof value !== 'object' || Array.isArray(value)
    || Reflect.ownKeys(value).some(key => typeof key !== 'string' || ![...required, ...optional].includes(key))
    || required.some(key => !Object.hasOwn(value, key))) {
    throw Error('Missing or unknown properties');
  }
}

function address(value: unknown, zero = false): Address {
  if (typeof value !== 'string') throw Error('Expected address');
  const result = getAddress(value) as Address;
  if (!zero && result === ZeroAddress) throw Error('Zero address');
  return result;
}

function hash(value: unknown, zero = false): Hex {
  if (typeof value !== 'string' || !isHexString(value, 32)
    || (!zero && value.toLowerCase() === ZeroHash)) throw Error('Expected bytes32');
  return value.toLowerCase() as Hex;
}

function bytes(value: unknown, maximum = 65536): Hex {
  if (typeof value !== 'string' || !isHexString(value, true)
    || (value.length - 2) / 2 > maximum) throw Error('Malformed or oversized bytes');
  return value.toLowerCase() as Hex;
}

function uint(value: unknown, bits = 256): bigint {
  if (typeof value !== 'bigint' || value < 0n || value >= 1n << BigInt(bits)) {
    throw Error('Expected bounded unsigned bigint');
  }
  return value;
}

function integer(value: unknown): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) {
    throw Error('Expected concrete block number or log index');
  }
  return value;
}

function freeze<T>(value: T): T {
  if (value && typeof value === 'object') {
    for (const child of Object.values(value)) freeze(child);
    Object.freeze(value);
  }
  return value;
}

function tagged(value: unknown): unknown {
  if (value === null) return ['null'];
  if (typeof value === 'bigint') return ['bigint', value.toString()];
  if (typeof value === 'string') return ['string', value];
  if (typeof value === 'boolean') return ['boolean', value];
  if (typeof value === 'number' && Number.isSafeInteger(value)) return ['number', value];
  if (Array.isArray(value)) {
    if (Object.keys(value).length !== value.length) throw Error('Sparse or extended array');
    return ['array', value.map(tagged)];
  }
  if (value && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype) {
    return ['object', Object.keys(value).sort().map(key => [key, tagged((value as Record<string, unknown>)[key])])];
  }
  throw Error('Unsupported observation value');
}

function fingerprint(value: unknown): Hex {
  return keccak256(toUtf8Bytes(JSON.stringify(tagged(value)))) as Hex;
}

function equal(actual: unknown, expected: unknown, label: string): void {
  if (fingerprint(actual) !== fingerprint(expected)) throw Error(`${label} differs`);
}

function same(actual: unknown, expected: unknown, label: string): void {
  if (typeof actual !== 'string' || typeof expected !== 'string'
    || actual.toLowerCase() !== expected.toLowerCase()) throw Error(`${label} differs`);
}

function pin(value: DirectConservationCodePin): DirectConservationCodePin {
  keys(value, ['address', 'codeHash']);
  return { address: address(value.address), codeHash: hash(value.codeHash) };
}

function deployment(value: DirectConservationDeployment): DirectConservationDeployment {
  keys(value, ['chainId', 'product', 'core', 'manager', 'moduleRegistry']);
  return freeze({
    chainId: uint(value.chainId), product: pin(value.product), core: pin(value.core),
    manager: pin(value.manager), moduleRegistry: pin(value.moduleRegistry)
  });
}

async function header(provider: Reader, tag: number, chainId: bigint): Promise<DirectConservationBlock> {
  const [network, block] = await Promise.all([provider.getNetwork(), provider.getBlock(tag)]);
  if (network.chainId !== chainId || !block || block.number !== tag) throw Error('Wrong chain or block');
  return freeze({ blockNumber: tag, blockHash: hash(block.hash), timestamp: uint(BigInt(block.timestamp), 64) });
}

function runtime(value: unknown): Hex {
  const code = bytes(value, 131072);
  if (code === '0x' || (code.length === 48 && code.startsWith('0xef0100'))) {
    throw Error('Empty or delegated runtime');
  }
  return code;
}

async function pinned(provider: Reader, expected: DirectConservationCodePin, tag: number): Promise<void> {
  same(keccak256(runtime(await provider.getCode(expected.address, tag))), expected.codeHash, 'Runtime pin');
}

function plain(parameter: ParamType, value: any): any {
  if (parameter.baseType === 'array') return Array.from(value, item => plain(parameter.arrayChildren!, item));
  if (parameter.baseType === 'tuple') {
    return Object.fromEntries(parameter.components!.map((component, index) => [component.name, plain(component, value[index])]));
  }
  return parameter.type === 'address' ? address(value, true) : value;
}

function decoded(contract: Interface, method: string, raw: unknown): any[] {
  const encoded = bytes(raw);
  const fragment = contract.getFunction(method)!;
  const result = contract.decodeFunctionResult(fragment, encoded);
  same(contract.encodeFunctionResult(fragment, result), encoded, 'Canonical ABI return');
  return fragment.outputs.map((output, index) => plain(output, result[index]));
}

async function read(
  provider: Reader,
  target: Address,
  method: string,
  args: readonly unknown[],
  tag: number,
  from?: Address
): Promise<any[]> {
  const fragment = abi.getFunction(method)!;
  return decoded(abi, method, await provider.call({
    to: target, data: abi.encodeFunctionData(fragment, args), blockTag: tag, ...(from === undefined ? {} : { from })
  }));
}

function captured(value: DirectConservationCapture): DirectConservationCapture {
  keys(value, [
    'deployment', 'prepared', 'observed', 'bindings', 'admission', 'floor', 'mint', 'sale',
    'auction', 'paymentIntent', 'refundCredit', 'nextSaleNonce', 'dependencies', 'captureHash', 'admissionAuthority'
  ], ['control']);
  const copy = {
    ...structuredClone(value),
    deployment: deployment(value.deployment),
    prepared: direct.normalizeDirectConservationCall(value.prepared)
  };
  const { captureHash, ...body } = copy;
  same(fingerprint(body), hash(captureHash), 'Capture integrity');
  return freeze(copy);
}

function productKind(kind: direct.DirectConservationCoordinates['productKind']): Hex {
  return id(kind === 'native-fixed' ? '6529STREAM_DIRECT_NATIVE_FIXED_PRICE_V1'
    : kind === 'erc20-fixed' ? '6529STREAM_DIRECT_ERC20_FIXED_PRICE_V1'
      : '6529STREAM_DIRECT_ENGLISH_AUCTION_V1') as Hex;
}

function checkBindings(
  d: DirectConservationDeployment,
  prepared: direct.DirectConservationCall,
  b: direct.DirectConservationBindings
): void {
  same(b.core, d.core.address, 'Bound Core');
  same(b.coreCodeHash, d.core.codeHash, 'Bound Core runtime');
  same(b.mintManager, d.manager.address, 'Bound Manager');
  same(b.mintManagerCodeHash, d.manager.codeHash, 'Bound Manager runtime');
  same(b.productKind, productKind(prepared.coordinates.productKind), 'Product kind');
  if (b.deploymentChainId !== d.chainId || prepared.coordinates.chainId !== d.chainId) throw Error('Deployment chain differs');
  same(prepared.coordinates.core, d.core.address, 'Prepared Core');
  same(prepared.coordinates.product, d.product.address, 'Prepared product');
}

async function admission(
  provider: Reader,
  d: DirectConservationDeployment,
  block: DirectConservationBlock,
  immediate: boolean
): Promise<DirectConservationAdmission> {
  const tag = block.blockNumber;
  await Promise.all([pinned(provider, d.core, tag), pinned(provider, d.manager, tag), pinned(provider, d.moduleRegistry, tag)]);
  const pointer = await read(provider, d.core.address, 'getSatellitePointer', [id('MODULE_REGISTRY')], tag);
  same(pointer[0], d.moduleRegistry.address, 'Selected ModuleRegistry');
  same(pointer[1], d.moduleRegistry.codeHash, 'Selected registry runtime');
  same(pointer[3], id('MODULE_REGISTRY'), 'Registry pointer type');
  same(pointer[4], '0xefc33fae', 'Registry pointer interface');
  same(pointer[5], d.moduleRegistry.address, 'Registry pointer admission');
  hash(pointer[7]);
  hash(pointer[8]);
  if (pointer[6] !== 1n || pointer[9] === 0n) throw Error('Registry pointer is not active');
  const [[core], [registry], [row], [supported], [erc165], [invalid]] = await Promise.all([
    read(provider, d.manager.address, 'core', [], tag),
    read(provider, d.manager.address, 'moduleRegistry', [], tag),
    read(provider, d.moduleRegistry.address, 'moduleRecord', [d.product.address], tag),
    read(provider, d.product.address, 'supportsInterface', ['0xf9f99b4b'], tag),
    read(provider, d.product.address, 'supportsInterface', ['0x01ffc9a7'], tag),
    read(provider, d.product.address, 'supportsInterface', ['0xffffffff'], tag)
  ]);
  same(core, d.core.address, 'Manager Core');
  same(registry, d.moduleRegistry.address, 'Manager registry');
  same(row.moduleType, direct.DIRECT_CONSERVATION_MODULE_TYPE, 'DIRECT module type');
  same(row.moduleVersion, direct.DIRECT_CONSERVATION_MODULE_VERSION, 'DIRECT module version');
  same(row.interfaceId, '0xf9f99b4b', 'DIRECT receipt capability');
  same(row.runtimeCodeHash, d.product.codeHash, 'Registered product runtime');
  hash(row.deploymentManifestHash);
  hash(row.moduleManifestHash);
  if (toUtf8Bytes(row.moduleManifestURI).length > 3648) throw Error('Module record exceeds bounded read');
  if (!supported || !erc165 || invalid || ![1n, 2n].includes(row.status)
    || (immediate && row.status !== 1n) || row.registeredAt === 0n
    || row.registeredAt > block.timestamp || row.statusUpdatedAt < row.registeredAt
    || row.statusUpdatedAt > block.timestamp || row.revision === 0n) {
    throw Error('DIRECT product admission unavailable');
  }
  return freeze({ status: row.status, registeredAt: row.registeredAt, statusUpdatedAt: row.statusUpdatedAt, revision: row.revision });
}

async function selectedFloor(
  provider: Reader,
  d: DirectConservationDeployment,
  tag: number
): Promise<DirectConservationCodePin> {
  const [target, codeHash] = await read(provider, d.core.address, 'conservationFloor', [], tag);
  const result = pin({ address: target, codeHash });
  await pinned(provider, result, tag);
  const [limit] = await read(provider, result.address, 'gasParameter', [id('6529STREAM_GGP_CONSERVATION_FLOOR_CALL_GAS')], tag);
  if (limit === 0n || limit > ((1n << 256n) - 1n) / 64n) throw Error('Invalid floor call gas');
  return result;
}

/** Local immutable history; does not re-admit former products, Core, Manager or providers. */
export async function inspectDirectConservationFloorHistory(
  provider: Reader,
  input: { readonly chainId: bigint; readonly core: Address; readonly floor: DirectConservationCodePin; readonly key: Hex },
  options: { readonly blockTag: number; readonly releaseKey?: Hex }
): Promise<DirectConservationFloorHistory> {
  keys(input, ['chainId', 'core', 'floor', 'key']);
  keys(options, ['blockTag'], ['releaseKey']);
  const chainId = uint(input.chainId);
  const core = address(input.core);
  const floor = pin(input.floor);
  const key = hash(input.key);
  const tag = integer(options.blockTag);
  const releaseKey = options.releaseKey === undefined ? null : hash(options.releaseKey);
  const observed = await header(provider, tag, chainId);
  await pinned(provider, floor, tag);
  const [[actualCore], [actualChain], [raw], [universal]] = await Promise.all([
    read(provider, floor.address, 'core', [], tag),
    read(provider, floor.address, 'deploymentChainId', [], tag),
    read(provider, floor.address, 'directPrimarySaleFloorReceipt', [key], tag),
    read(provider, floor.address, 'settlementReceipt', [key], tag)
  ]);
  same(actualCore, core, 'Floor Core');
  if (actualChain !== chainId) throw Error('Floor deployment chain differs');
  const receipt = direct.normalizeDirectConservationFloorReceipt(raw);
  paidTuple(receipt.bindings, receipt.authorizationId, receipt.sale);
  const coordinates = { chainId, core, floor: floor.address };
  same(receipt.directKey, key, 'DIRECT key');
  same(direct.directConservationKey(receipt.bindings, receipt.adapter, receipt.authorizationId), key, 'Original DIRECT key');
  same(
    direct.directConservationReceiptHash(receipt.bindings, receipt.adapter, receipt.authorizationId, receipt.sale),
    receipt.originalReceiptHash,
    'Original receipt hash'
  );
  same(direct.directConservationFloorReceiptHash(coordinates, receipt), receipt.receiptHash, 'Floor receipt hash');
  if (receipt.recordedAt === 0n || receipt.recordedAt > observed.timestamp || receipt.sale.amount === 0n) throw Error('Missing paid floor history');
  for (const value of Object.values(universal)) {
    if (value !== 0n && value !== ZeroHash && value !== ZeroAddress) throw Error('DIRECT key has universal settlement history');
  }
  const [rawFirst] = await read(provider, floor.address, 'firstSale', [receipt.sale.collectionId], tag);
  const firstSale = direct.normalizeDirectConservationFirstSaleReceipt(rawFirst);
  same(direct.directConservationFirstSaleReceiptHash(coordinates, firstSale), firstSale.receiptHash, 'First-sale preimage');
  same(firstSale.receiptHash, receipt.firstSaleReceiptHash, 'First-sale link');
  if (firstSale.collectionId !== receipt.sale.collectionId || firstSale.recordedAt === 0n
    || firstSale.recordedAt > receipt.recordedAt) throw Error('Contradictory first-sale history');
  let release: direct.DirectConservationReleaseReceipt | null = null;
  if (receipt.releaseReceiptHash !== ZeroHash) {
    if (releaseKey === null) throw Error('Retained releaseKey locator required');
    const [rawRelease] = await read(provider, floor.address, 'releaseFloorReceipt', [releaseKey], tag);
    release = direct.normalizeDirectConservationReleaseReceipt(rawRelease);
    same(release.releaseKey, releaseKey, 'Release locator');
    same(direct.directConservationReleaseReceiptHash(coordinates, release), release.receiptHash, 'Release preimage');
    same(release.receiptHash, receipt.releaseReceiptHash, 'Release link');
    same(direct.directConservationReleaseKey(chainId, core, release.collectionId, release.context), releaseKey, 'Semantic release key');
    if (release.collectionId !== receipt.sale.collectionId || release.recordedAt === 0n
      || release.recordedAt > receipt.recordedAt) throw Error('Contradictory release history');
  } else if (releaseKey !== null) {
    throw Error('Unexpected release locator');
  }
  direct.validateDirectConservationHistory(coordinates, receipt, firstSale, release);
  const tiers = [id('MUSEUM_GRADE'), id('MUSEUM_GRADE_LITE'), id('CONSERVATION_WAIVED')];
  if (!tiers.includes(receipt.effectiveTier)
    || (receipt.effectiveTier === tiers[2]) !== (release === null)) throw Error('Invalid retained conservation tier or release presence');
  equal(await header(provider, tag, chainId), observed, 'Historical block');
  return freeze({ chainId, floor, core, observed, receipt, firstSale, release });
}

const productAbis = {
  "native-fixed": new Interface([
    "function authorizationDigest((uint256 collectionId, bytes32 phaseId, address payer, address recipient, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 price, bytes32 nonce, uint64 deadline, uint64 signerEpoch) sale) view returns (bytes32)",
    "function buy((uint256 collectionId, bytes32 phaseId, address payer, address recipient, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 price, bytes32 nonce, uint64 deadline, uint64 signerEpoch) sale, bytes tokenData, bytes platformSignature, bytes artistSignature) payable returns (uint256 tokenId, bytes32 operationRoot)",
    "function cancelAuthorization(bytes32 nonce)",
    "function primaryPolicy(uint256 collectionId) view returns (bytes32 policyHash, bytes32 profileId, address wallet)",
    "function setPaused(bool paused_)",
    "function setPlatformSigner(address signer)",
    "function transferOwnership(address newOwner)",
    "function renounceOwnership()"
  ]),
  "erc20-fixed": new Interface([
    "function authorizationDigest((bytes32 saleId, bytes32 saleConfigHash, address payer, address recipient, address artist, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization) view returns (bytes32)",
    "function buy((bytes32 saleId, bytes32 saleConfigHash, address payer, address recipient, address artist, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization, bytes tokenData, bytes platformSignature, bytes artistSignature, (address payer, address asset, uint256 maxAmount, bytes32 saleRef, bytes32 expectedPrimaryPolicyHash, bytes32 nonce, uint64 deadline) intent, bytes payerSignature) returns (uint256 tokenId, bytes32 operationRoot)",
    "function cancelAuthorization(bytes32 nonce)",
    "function cancelSale(bytes32 saleId)",
    "function primaryPolicy(uint256 collectionId, bytes32 revenueClass) view returns (bytes32 policyHash, bytes32 profileId, address wallet)",
    "function registerSale((uint256 collectionId, bytes32 phaseId, address asset, bytes32 revenueClass, uint256 price, bytes32 mintPolicyHash, bytes32 expectedPrimaryPolicyHash, uint64 startsAt, uint64 endsAt) config) returns (bytes32 saleId)",
    "function revokePaymentIntent(bytes32 nonce)",
    "function revokePaymentIntentBySignature(address payer, bytes32 nonce, uint64 deadline, bytes signature)",
    "function setPaused(bool value)",
    "function setPlatformSigner(address signer)",
    "function transferOwnership(address newOwner)",
    "function renounceOwnership()",
    "function raiseSignatureGasLimit(uint256 value)"
  ]),
  "english-auction": new Interface([
    "function authorizationDigest((uint256 collectionId, bytes32 phaseId, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 reservePrice, uint64 startTime, uint64 endTime, uint32 extensionWindow, uint16 minBidIncrementBps, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization) view returns (bytes32)",
    "function bid(uint256 tokenId, address recipient) payable",
    "function cancel(uint256 tokenId)",
    "function cancelAuthorization(bytes32 nonce)",
    "function claimNoBidNFT(uint256 tokenId, address recipient)",
    "function createAuction((uint256 collectionId, bytes32 phaseId, address artist, bytes32 profileId, bytes32 expectedPrimaryPolicyHash, bytes32 tokenDataHash, bytes32 mintCommitment, bytes32 mintPolicyHash, uint256 reservePrice, uint64 startTime, uint64 endTime, uint32 extensionWindow, uint16 minBidIncrementBps, bytes32 nonce, uint64 deadline, uint64 signerEpoch) authorization, bytes tokenData, bytes platformSignature, bytes artistSignature) returns (uint256 tokenId)",
    "function primaryPolicy(uint256 collectionId) view returns (bytes32 policyHash, bytes32 profileId, address wallet)",
    "function setDeliveryRecipient(uint256 tokenId, address recipient)",
    "function settle(uint256 tokenId)",
    "function withdrawRefund(address recipient)",
    "function setPaused(bool paused_)",
    "function setPlatformSigner(address signer)",
    "function transferOwnership(address newOwner)",
    "function renounceOwnership()"
  ]),
};

function argumentsOf(
  prepared: direct.DirectConservationCall
): { method: string; args: any[]; contract: Interface } {
  const contract = productAbis[prepared.coordinates.productKind];
  const fragment = contract.getFunction(prepared.call.data.slice(0, 10))!;
  const result = contract.decodeFunctionData(fragment, prepared.call.data);
  same(contract.encodeFunctionData(fragment, result), prepared.call.data, 'Prepared call encoding');
  return { method: fragment.name, args: fragment.inputs.map((input, index) => plain(input, result[index])), contract };
}

async function productRead(
  provider: Reader,
  prepared: direct.DirectConservationCall,
  method: string,
  args: readonly unknown[],
  tag: number
): Promise<any[]> {
  const contract = productAbis[prepared.coordinates.productKind];
  return decoded(contract, method, await provider.call({
    to: prepared.coordinates.product, data: contract.encodeFunctionData(method, args), blockTag: tag
  }));
}

function isControl(method: string): boolean {
  return ['setPaused', 'setPlatformSigner', 'transferOwnership', 'renounceOwnership',
    'raiseSignatureGasLimit'].includes(method);
}

async function controlState(
  provider: Reader,
  prepared: direct.DirectConservationCall,
  tag: number
): Promise<direct.DirectConservationControlState> {
  const target = prepared.coordinates.product;
  const [[owner], [paused], [platformSigner], [signerEpoch]] = await Promise.all([
    read(provider, target, 'owner', [], tag),
    read(provider, target, 'paused', [], tag),
    read(provider, target, 'platformSigner', [], tag),
    read(provider, target, 'signerEpoch', [], tag)
  ]);
  let signatureGasLimit: bigint | null = null;
  if (prepared.coordinates.productKind === 'erc20-fixed') {
    [signatureGasLimit] = await read(provider, target, 'signatureGasLimit', [], tag);
  }
  address(platformSigner);
  if (signerEpoch === 0n || (signatureGasLimit !== null
    && (signatureGasLimit < 400_000n || signatureGasLimit >= 1n << 64n))) {
    throw Error('Impossible original control state');
  }
  return direct.normalizeDirectConservationControlState(prepared.coordinates.productKind, {
    owner, paused, platformSigner, signerEpoch, signatureGasLimit
  });
}

/** Read-only preflight. Signature, payment, callback and nested floor admission require simulation. */
export async function captureDirectConservation(
  provider: Reader,
  inputDeployment: DirectConservationDeployment,
  inputCall: direct.DirectConservationCall,
  options: { readonly blockTag: number }
): Promise<DirectConservationCapture> {
  keys(options, ['blockTag']);
  const d = deployment(inputDeployment);
  const prepared = direct.normalizeDirectConservationCall(inputCall);
  bytes(prepared.call.data, 131072);
  const tag = integer(options.blockTag);
  const observed = await header(provider, tag, d.chainId);
  await pinned(provider, d.product, tag);
  const [rawBindings] = await read(provider, d.product.address, 'directPrimaryBindings', [], tag);
  const bindings = direct.normalizeDirectConservationBindings(rawBindings);
  checkBindings(d, prepared, bindings);
  const { method, args } = argumentsOf(prepared);
  const kind = prepared.coordinates.productKind;
  let row: DirectConservationAdmission | null = null;
  let floor: DirectConservationCodePin | null = null;
  let mint: DirectConservationMintOrigin | null = null;
  let sale: direct.DirectConservationERC20SaleRecord | null = null;
  let auction: direct.DirectConservationAuction | null = null;
  let paymentIntent: DirectConservationCapture['paymentIntent'] = null;
  let refundCredit: bigint | null = null;
  let nextSaleNonce: bigint | null = null;
  let control: direct.DirectConservationControlState | undefined;
  const dependencies: DirectConservationCodePin[] = [];
  const minting = method === 'buy' || method === 'createAuction';
  if (isControl(method)) {
    control = await controlState(provider, prepared, tag);
    direct.directConservationControlTransition(prepared, control);
  } else if (minting) {
    await Promise.all([pinned(provider, d.core, tag), pinned(provider, d.manager, tag)]);
    const authorization = args[0];
    const [[paused], [epoch], [used], [onchainId], [onchainDigest], [signer]] = await Promise.all([
      read(provider, d.product.address, 'paused', [], tag),
      read(provider, d.product.address, 'signerEpoch', [], tag),
      read(provider, d.product.address, 'authorizationUsed', [authorization.artist, authorization.nonce], tag),
      read(provider, d.product.address, 'authorizationId', [authorization.artist, authorization.nonce], tag),
      productRead(provider, prepared, 'authorizationDigest', [authorization], tag),
      read(provider, d.product.address, 'platformSigner', [], tag)
    ]);
    address(signer);
    if (paused || used || epoch !== authorization.signerEpoch || observed.timestamp > authorization.deadline) {
      throw Error('Mint authorization unavailable');
    }
    const typed = kind === 'native-fixed' ? direct.directConservationNativeTypedData(prepared.coordinates, authorization)
      : kind === 'erc20-fixed' ? direct.directConservationERC20TypedData(prepared.coordinates, authorization)
        : direct.directConservationAuctionTypedData(prepared.coordinates, authorization);
    const authorizationDigest = TypedDataEncoder.hash(typed.domain, typed.types, typed.message) as Hex;
    const authorizationId = direct.directConservationAuthorizationId(prepared.coordinates, authorization.artist, authorization.nonce);
    same(onchainId, authorizationId, 'Original authorization ID');
    same(onchainDigest, authorizationDigest, 'Original authorization digest');
    let collectionId = authorization.collectionId as bigint;
    let boundPolicy = authorization.mintPolicyHash as Hex;
    let expectedPrimary = authorization.expectedPrimaryPolicyHash as Hex;
    let price = authorization.price as bigint;
    if (kind === 'erc20-fixed') {
      const [raw] = await read(provider, d.product.address, 'saleRecord', [authorization.saleId], tag);
      sale = direct.normalizeDirectConservationERC20SaleRecord(raw);
      if (sale.saleNonce === 0n || sale.cancelled || observed.timestamp < sale.config.startsAt
        || observed.timestamp > sale.config.endsAt) throw Error('ERC20 sale unavailable');
      same(sale.configHash, direct.directConservationERC20ConfigHash(authorization.saleId, sale.config), 'Sale configuration preimage');
      same(sale.configHash, authorization.saleConfigHash, 'Signed sale configuration');
      same(
        authorization.saleId,
        direct.directConservationERC20SaleId(prepared.coordinates, sale.config.collectionId, sale.config.phaseId, sale.saleNonce),
        'Sale identifier'
      );
      collectionId = sale.config.collectionId;
      boundPolicy = sale.config.mintPolicyHash;
      expectedPrimary = sale.config.expectedPrimaryPolicyHash;
      price = sale.config.price;
      const intent = args[4] as direct.DirectConservationPaymentIntent;
      paymentIntent = prepared.caller === authorization.payer && args[5] === '0x' ? 'exempt-literal-caller' : 'signed-intent';
      if (paymentIntent === 'signed-intent') {
        same(intent.payer, authorization.payer, 'Payer intent');
        same(intent.asset, sale.config.asset, 'Intent asset');
        same(intent.saleRef, authorization.saleId, 'Intent sale');
        same(intent.expectedPrimaryPolicyHash, expectedPrimary, 'Intent primary policy');
        const [[intentUsed], [intentDigest]] = await Promise.all([
          read(provider, d.product.address, 'isPaymentIntentNonceUsed', [intent.payer, intent.nonce], tag),
          read(provider, d.product.address, 'paymentIntentDigest', [intent], tag)
        ]);
        const signed = direct.directConservationPaymentIntentTypedData(prepared.coordinates, intent);
        same(intentDigest, TypedDataEncoder.hash(signed.domain, signed.types, signed.message), 'Payer digest');
        if (intentUsed || intent.maxAmount < price || observed.timestamp > intent.deadline) throw Error('Payer intent unavailable');
      }
    }
    const policyArgs = kind === 'erc20-fixed' ? [collectionId, sale!.config.revenueClass] : [collectionId];
    const [policyHash, profileId, wallet] = await productRead(provider, prepared, 'primaryPolicy', policyArgs, tag);
    same(policyHash, expectedPrimary, 'Original primary policy');
    if (kind !== 'erc20-fixed') same(profileId, authorization.profileId, 'Signed profile');
    address(wallet);
    const batch = direct.directConservationMintBatch(prepared, sale ?? undefined);
    direct.validateDirectConservationExecutionTerms(prepared, { timestamp: observed.timestamp, signerEpoch: epoch }, sale ?? undefined);
    const [operationRoot, operationIds] = await read(provider, d.manager.address, 'previewSingleStepMintOperation', [batch, '0x'], tag, d.product.address);
    if (operationIds.length !== 1) throw Error('Original single-step operation vector differs');
    hash(operationRoot);
    hash(operationIds[0]);
    const [[rootUsed], [idUsed]] = await Promise.all([
      read(provider, d.manager.address, 'isOperationRootUsed', [operationRoot], tag),
      read(provider, d.manager.address, 'isAuthorizationUsed', [authorizationId], tag)
    ]);
    if (rootUsed || idUsed) throw Error('Manager authorization already consumed');
    mint = {
      authorizationId, authorizationDigest, collectionId, operationRoot, operationId: operationIds[0],
      boundMintPolicyHash: boundPolicy, primaryPolicyHash: policyHash, profileId, wallet, artist: authorization.artist
    };
    // Actual product getters identify these dependencies; the whole original call enforces their detailed policies.
    for (const getter of ['artistRegistry', 'revenueResolver', 'splitFactory', 'revenueEscrow']) {
      const [target] = await read(provider, d.product.address, getter, [], tag);
      const dependency = { address: address(target), codeHash: keccak256(runtime(await provider.getCode(target, tag))) as Hex };
      if (getter === 'artistRegistry') {
        const [expected] = await read(provider, d.product.address, 'artistRegistryCodeHash', [], tag);
        same(dependency.codeHash, expected, 'Artist runtime');
      } else if (getter === 'splitFactory' || getter === 'revenueEscrow') {
        const [expected] = await read(provider, d.product.address,
          getter === 'splitFactory' ? 'fundingFactoryCodeHash' : 'fundingEscrowCodeHash', [], tag);
        same(dependency.codeHash, expected, 'Funding runtime');
      }
      dependencies.push(dependency);
    }
    if (method === 'createAuction' || price > 0n) row = await admission(provider, d, observed, true);
    if (method === 'buy' && price > 0n) floor = await selectedFloor(provider, d, tag);
  } else if (kind === 'english-auction' && !['withdrawRefund', 'cancelAuthorization'].includes(method)) {
    const [raw] = await read(provider, d.product.address, 'auction', [args[0]], tag);
    auction = direct.normalizeDirectConservationAuction(raw);
    if (auction.settled) throw Error('Auction already settled');
    if (['settle', 'cancel', 'claimNoBidNFT'].includes(method)) await pinned(provider, d.core, tag);
    if (method === 'bid') {
      const [[paused], [minimum]] = await Promise.all([
        read(provider, d.product.address, 'paused', [], tag),
        read(provider, d.product.address, 'minimumBid', [args[0]], tag)
      ]);
      if (minimum !== direct.directConservationMinimumBid(auction)) throw Error('Original minimum bid differs');
      if (paused || observed.timestamp < auction.startTime || observed.timestamp >= auction.endTime
        || prepared.call.value < minimum) throw Error('Auction bid unavailable');
    } else if (method === 'settle') {
      if (observed.timestamp < auction.endTime) throw Error('Auction has not ended');
      await pinned(provider, d.core, tag);
      if (auction.highestBid > 0n) {
        row = await admission(provider, d, observed, false);
        floor = await selectedFloor(provider, d, tag);
      }
    } else if (method === 'cancel') {
      same(prepared.caller, auction.artist, 'Auction cancellation caller');
      if (auction.highestBid !== 0n || observed.timestamp >= auction.endTime) throw Error('Auction cannot cancel');
    } else if (method === 'claimNoBidNFT') {
      same(prepared.caller, address(auction.pendingNoBidNftClaimant), 'No-bid claimant');
    } else if (method === 'setDeliveryRecipient') {
      same(prepared.caller, auction.highestBidder === ZeroAddress ? auction.artist : auction.highestBidder, 'Delivery authority');
    }
  } else if (method === 'withdrawRefund') {
    [refundCredit] = await read(provider, d.product.address, 'refundCredit', [prepared.caller], tag);
    if (refundCredit === 0n) throw Error('No refund credit');
  } else if (method === 'cancelAuthorization') {
    const [used] = await read(provider, d.product.address, 'authorizationUsed', [prepared.caller, args[0]], tag);
    if (used) throw Error('Authorization already consumed');
  } else if (method === 'revokePaymentIntent' || method === 'revokePaymentIntentBySignature') {
    const payer = method === 'revokePaymentIntent' ? prepared.caller : args[0];
    const nonce = method === 'revokePaymentIntent' ? args[0] : args[1];
    const [used] = await read(provider, d.product.address, 'isPaymentIntentNonceUsed', [payer, nonce], tag);
    if (used || (method === 'revokePaymentIntentBySignature' && observed.timestamp > args[2])) throw Error('Intent revocation unavailable');
  } else if (method === 'registerSale' || method === 'cancelSale') {
    const [owner] = await read(provider, d.product.address, 'owner', [], tag);
    same(owner, prepared.caller, 'Sale administration caller');
    if (method === 'registerSale') {
      [nextSaleNonce] = await read(provider, d.product.address, 'nextSaleNonce', [], tag);
    } else {
      const [raw] = await read(provider, d.product.address, 'saleRecord', [args[0]], tag);
      sale = direct.normalizeDirectConservationERC20SaleRecord(raw);
      if (sale.saleNonce === 0n || sale.cancelled) throw Error('Sale unavailable');
    }
  }
  equal(await header(provider, tag, d.chainId), observed, 'Capture block');
  const body = {
    deployment: d, prepared, observed, bindings, admission: row, floor, mint, sale, auction,
    paymentIntent, refundCredit, nextSaleNonce, dependencies,
    ...(control === undefined ? {} : { control }),
    admissionAuthority: 'original-product-call-simulation' as const
  };
  return freeze({ ...body, captureHash: fingerprint(body) });
}

export async function simulateDirectConservation(
  provider: Reader,
  input: DirectConservationCapture,
  options: { readonly blockTag: number; readonly gasLimit: bigint }
): Promise<DirectConservationSimulation> {
  keys(options, ['blockTag', 'gasLimit']);
  const saved = captured(input);
  const tag = integer(options.blockTag);
  const gasLimit = uint(options.gasLimit);
  if (gasLimit === 0n || gasLimit > 100_000_000n) throw Error('Simulation gas bound exceeded');
  if (tag < saved.observed.blockNumber) throw Error('Simulation predates capture');
  equal(await captureDirectConservation(provider, saved.deployment, saved.prepared, { blockTag: saved.observed.blockNumber }), saved, 'Historical capture');
  const current = await captureDirectConservation(provider, saved.deployment, saved.prepared, { blockTag: tag });
  if (saved.control !== undefined) {
    equal(current.control, saved.control, 'Reviewed control prestate changed; recapture');
  }
  const { method, contract } = argumentsOf(current.prepared);
  const returnData = bytes(await provider.call({ ...current.prepared.call, from: current.prepared.caller, blockTag: tag, gasLimit }));
  const values = decoded(contract, method, returnData);
  let tokenId: bigint | null = null;
  let operationRoot: Hex | null = null;
  if (method === 'buy' || method === 'createAuction') {
    tokenId = uint(values[0]);
    operationRoot = method === 'buy' ? hash(values[1]) : current.mint!.operationRoot;
    if (tokenId === 0n) throw Error('Original mint returned zero token');
    same(operationRoot, current.mint!.operationRoot, 'Simulated mint operation');
  }
  equal(await header(provider, tag, saved.deployment.chainId), current.observed, 'Simulation block');
  return freeze({ capture: current, returnData, tokenId, operationRoot });
}

export type DirectConservationTransport =
  | { readonly execution: 'direct' }
  | { readonly execution: 'safe'; readonly expectedSafeTxHash: Hex };

export interface DirectConservationAuctionCreation {
  readonly capture: DirectConservationCapture;
  readonly transactionHash: Hex;
  readonly transport: DirectConservationTransport;
}

export type DirectConservationReceiptOptions = DirectConservationTransport & {
  readonly releaseKey?: Hex;
  readonly auctionCreation?: DirectConservationAuctionCreation;
};

export interface DirectConservationTransactionReceipt {
  readonly capture: DirectConservationCapture;
  readonly transactionHash: Hex;
  readonly observed: DirectConservationBlock;
  readonly tokenId: bigint | null;
  readonly mint: DirectConservationMintOrigin | null;
  readonly paidReceipt: direct.DirectConservationReceipt | null;
  readonly floorHistory: DirectConservationFloorHistory | null;
  readonly auction: direct.DirectConservationAuction | null;
  readonly control?: direct.DirectConservationControlState;
  readonly outcome:
    | 'paid'
    | 'free-mint'
    | 'auction-created'
    | 'bid'
    | 'pending-no-bid'
    | 'delivered-no-bid'
    | 'cancelled'
    | 'recipient-updated'
    | 'refund'
    | 'authorization-cancelled'
    | 'intent-revoked'
    | 'sale-configured'
    | 'sale-cancelled'
    | 'control-updated';
  readonly requiredLogIndices: readonly number[];
}

interface SavedLog {
  readonly address: Address;
  readonly topics: readonly Hex[];
  readonly data: Hex;
  readonly index: number;
}

const safeAbi = new Interface([
  'function execTransaction(address to,uint256 value,bytes data,uint8 operation,uint256 safeTxGas,uint256 baseGas,uint256 gasPrice,address gasToken,address refundReceiver,bytes signatures) payable returns (bool success)',
  'event ExecutionSuccess(bytes32 txHash,uint256 payment)',
  'event ExecutionFailure(bytes32 txHash,uint256 payment)',
  'event ExecutionSuccess(bytes32 indexed txHash,uint256 payment)',
  'event ExecutionFailure(bytes32 indexed txHash,uint256 payment)'
]);

function transport(value: DirectConservationTransport): DirectConservationTransport {
  if (value.execution === 'direct') {
    keys(value, ['execution']);
    return { execution: 'direct' };
  }
  keys(value, ['execution', 'expectedSafeTxHash']);
  if (value.execution !== 'safe') throw Error('Unsupported receipt transport');
  return { execution: 'safe', expectedSafeTxHash: hash(value.expectedSafeTxHash) };
}

function logsOf(receipt: any): SavedLog[] {
  if (!Array.isArray(receipt.logs) || receipt.logs.length > 2048) throw Error('Receipt log bound exceeded');
  const logs = receipt.logs.map((log: any): SavedLog => {
    if (log.removed === true) throw Error('Removed receipt log');
    if (log.transactionHash !== undefined) same(log.transactionHash, receipt.hash, 'Log transaction');
    if (log.blockHash !== undefined) same(log.blockHash, receipt.blockHash, 'Log block');
    if (log.blockNumber !== undefined && log.blockNumber !== receipt.blockNumber) throw Error('Log block number differs');
    if (!Array.isArray(log.topics) || log.topics.length > 4) throw Error('Malformed log topics');
    return { address: address(log.address), topics: log.topics.map((topic: unknown) => hash(topic, true)), data: bytes(log.data, 32768), index: integer(log.index) };
  });
  if (new Set(logs.map((log: SavedLog) => log.index)).size !== logs.length) throw Error('Duplicate log index');
  for (let i = 1;i < logs.length;i++) if (logs[i - 1]!.index >= logs[i]!.index) throw Error('Unordered receipt logs');
  return freeze(logs);
}

function matcher(logs: readonly SavedLog[], refs: number[]) {
  function found(target: Address, name: string): { log: SavedLog; args: Record<string, any> }[] {
    const event = abi.getEvent(name)!;
    return logs.filter(log => log.address === target && log.topics[0] === event.topicHash).map(log => {
      const values = abi.decodeEventLog(event, log.data, [...log.topics]);
      const encoded = abi.encodeEventLog(event, values);
      same(encoded.data, log.data, 'Canonical event data');
      equal(encoded.topics.map(topic => topic.toLowerCase()), log.topics, 'Canonical event topics');
      return { log, args: Object.fromEntries(event.inputs.map((input, index) => [input.name, plain(input, values[index])])) };
    });
  }
  function one(target: Address, name: string, expected: Record<string, unknown> = {}) {
    const matches = found(target, name);
    if (matches.length !== 1) throw Error(`Missing or duplicate ${name}`);
    const match = matches[0]!;
    for (const [key, value] of Object.entries(expected)) equal(match.args[key], value, `${name}.${key}`);
    refs.push(match.log.index);
    return match;
  }
  return { found, one };
}

async function completedToken(
  provider: Reader,
  d: DirectConservationDeployment,
  mint: DirectConservationMintOrigin,
  tokenId: bigint,
  tag: number
): Promise<void> {
  await Promise.all([pinned(provider, d.core, tag), pinned(provider, d.manager, tag)]);
  const [[rootUsed], [idUsed], identity, [lifecycle]] = await Promise.all([
    read(provider, d.manager.address, 'isOperationRootUsed', [mint.operationRoot], tag),
    read(provider, d.manager.address, 'isAuthorizationUsed', [mint.authorizationId], tag),
    read(provider, d.core.address, 'tokenCollectionIdentity', [tokenId], tag),
    read(provider, d.core.address, 'tokenLifecycle', [tokenId], tag)
  ]);
  if (!rootUsed || !idUsed || !identity[0] || identity[1] !== mint.collectionId || identity[2] === 0n
    || ![2n, 3n].includes(lifecycle) || identity[3] !== (lifecycle === 3n)) {
    throw Error('Completed mint identity or Manager replay differs');
  }
}

function noPaidEvents(m: ReturnType<typeof matcher>, product: Address): void {
  if (m.found(product, 'DirectPrimarySaleRecorded').length !== 0) throw Error('Unpaid operation emitted DIRECT receipt');
}

async function emptyPaidReceipt(
  provider: Reader,
  product: Address,
  authorizationId: Hex,
  tag: number
): Promise<void> {
  const [[raw], [savedHash]] = await Promise.all([
    read(provider, product, 'directPrimarySaleReceipt', [authorizationId], tag),
    read(provider, product, 'directPrimarySaleReceiptHash', [authorizationId], tag)
  ]);
  same(savedHash, ZeroHash, 'Unpaid receipt hash');
  for (const value of Object.values(raw)) {
    if (value !== 0n && value !== false && value !== ZeroHash && value !== ZeroAddress) throw Error('Unpaid receipt is not empty');
  }
}

/** Reconciles one original product CALL. Requires a strictly later block and an exact prior-block prestate. */
export async function reconcileDirectConservationReceipt(
  provider: ReceiptReader,
  input: DirectConservationCapture,
  inputTransactionHash: Hex,
  inputOptions: DirectConservationReceiptOptions
): Promise<DirectConservationTransactionReceipt> {
  if (inputOptions.execution !== 'direct' && inputOptions.execution !== 'safe') {
    throw Error('Unsupported receipt transport');
  }
  keys(inputOptions, inputOptions.execution === 'safe' ? ['execution', 'expectedSafeTxHash'] : ['execution'], ['releaseKey', 'auctionCreation']);
  const saved = captured(input);
  const transactionHash = hash(inputTransactionHash);
  if (inputOptions.auctionCreation !== undefined) {
    keys(inputOptions.auctionCreation, ['capture', 'transactionHash', 'transport']);
  }
  const selectedTransport = transport(inputOptions.execution === 'safe'
    ? { execution: 'safe', expectedSafeTxHash: inputOptions.expectedSafeTxHash }
    : { execution: 'direct' });
  let releaseKey = inputOptions.releaseKey === undefined ? undefined : hash(inputOptions.releaseKey);
  const originInput = inputOptions.auctionCreation === undefined ? null : {
    capture: captured(inputOptions.auctionCreation.capture),
    transactionHash: hash(inputOptions.auctionCreation.transactionHash),
    transport: transport(inputOptions.auctionCreation.transport)
  };
  const d = saved.deployment;
  const [{ }, txValue, receiptValue] = await Promise.all([
    header(provider, saved.observed.blockNumber, d.chainId),
    provider.getTransaction(transactionHash), provider.getTransactionReceipt(transactionHash)
  ]);
  if (!txValue || !receiptValue || receiptValue.status !== 1) throw Error('Missing or failed transaction');
  const logs = logsOf(receiptValue);
  const tx = {
    hash: hash(txValue.hash), from: address(txValue.from), to: address(txValue.to),
    data: bytes(txValue.data, 262144), value: uint(txValue.value),
    blockNumber: integer(txValue.blockNumber), blockHash: hash(txValue.blockHash)
  };
  const receipt = { hash: hash(receiptValue.hash), blockNumber: integer(receiptValue.blockNumber), blockHash: hash(receiptValue.blockHash) };
  same(tx.hash, transactionHash, 'Transaction hash');
  same(receipt.hash, transactionHash, 'Receipt hash');
  if (tx.blockNumber !== receipt.blockNumber || receipt.blockNumber <= saved.observed.blockNumber) throw Error('Receipt must be strictly later than capture');
  const tag = receipt.blockNumber;
  const observed = await header(provider, tag, d.chainId);
  same(tx.blockHash, observed.blockHash, 'Transaction block');
  same(receipt.blockHash, observed.blockHash, 'Receipt block');
  equal(await captureDirectConservation(provider, d, saved.prepared, { blockTag: saved.observed.blockNumber }), saved, 'Historical capture');
  const before = await captureDirectConservation(provider, d, saved.prepared, { blockTag: tag - 1 });
  if (saved.control !== undefined) {
    equal(before.control, saved.control, 'Reviewed control prestate changed; recapture');
  }
  await pinned(provider, d.product, tag);
  const call = saved.prepared.call;
  if (selectedTransport.execution === 'direct') {
    same(tx.from, saved.prepared.caller, 'Actual direct caller');
    same(tx.to, call.to, 'Direct target');
    same(tx.data, call.data, 'Direct calldata');
    if (tx.value !== call.value) throw Error('Direct payment value differs');
  } else {
    same(tx.to, saved.prepared.caller, 'Safe actual caller');
    if (tx.value !== 0n) throw Error('Only zero-outer-value Safe transport is supported');
    const parsed = safeAbi.decodeFunctionData('execTransaction', tx.data);
    same(safeAbi.encodeFunctionData('execTransaction', parsed), tx.data, 'Canonical Safe calldata');
    same(parsed[0], call.to, 'Safe target');
    same(parsed[2], call.data, 'Safe inner calldata');
    if (parsed[1] !== call.value || parsed[3] !== 0n) throw Error('Safe must use exact CALL and inner value');
    bytes(parsed[9], 16384);
  }
  const refs: number[] = [];
  const m = matcher(logs, refs);
  const { method, args } = argumentsOf(saved.prepared);
  let mint = before.mint;
  let tokenId: bigint | null = null;
  let paidReceipt: direct.DirectConservationReceipt | null = null;
  let floorHistory: DirectConservationFloorHistory | null = null;
  let auction: direct.DirectConservationAuction | null = null;
  let control: direct.DirectConservationControlState | undefined;
  let outcome: DirectConservationTransactionReceipt['outcome'];
  let lastSettlement = -1;
  let settlementIndex = -1;
  let intentIndex = -1;
  let amount = 0n;
  let payer = ZeroAddress;
  let beneficiary = ZeroAddress;
  let asset = ZeroAddress;
  let createdAt = observed.timestamp;
  let creationRevision = before.admission?.revision ?? 0n;
  const product = d.product.address;
  if (isControl(method)) {
    if (before.control === undefined) throw Error('Missing reviewed control prestate');
    const transition = direct.directConservationControlTransition(saved.prepared, before.control);
    const event = abi.getEvent(transition.expectedEvent.name)!;
    const expected = Object.fromEntries(event.inputs.map((input, index) => [
      input.name, transition.expectedEvent.args[index]
    ]));
    m.one(product, transition.expectedEvent.name, expected);
    control = await controlState(provider, saved.prepared, tag);
    equal(control, transition.after, 'Original control poststate');
    outcome = 'control-updated';
  } else if (method === 'buy') {
    const authorization = args[0];
    direct.validateDirectConservationExecutionTerms(saved.prepared, { timestamp: observed.timestamp, signerEpoch: authorization.signerEpoch }, before.sale ?? undefined);
    const kind = saved.prepared.coordinates.productKind;
    const name = kind === 'native-fixed' ? 'NativeSaleSettled' : 'ERC20SaleSettled';
    const settled = m.one(product, name, {
      authorizationId: mint!.authorizationId, authorizationDigest: mint!.authorizationDigest,
      operationRoot: mint!.operationRoot, profileId: mint!.profileId, wallet: mint!.wallet
    });
    tokenId = uint(settled.args.tokenId);
    settlementIndex = settled.log.index;
    if (tokenId === 0n) throw Error('Zero minted token');
    amount = kind === 'native-fixed' ? authorization.price : before.sale!.config.price;
    payer = authorization.payer;
    beneficiary = authorization.recipient;
    asset = kind === 'native-fixed' ? ZeroAddress : before.sale!.config.asset;
    equal(settled.args.amount, amount, 'Settled payment');
    if (kind === 'erc20-fixed') {
      same(settled.args.saleId, authorization.saleId, 'Settled sale ID');
      same(settled.args.asset, asset, 'Settled asset');
    }
    const participants = m.one(product, kind === 'native-fixed' ? 'SaleParticipants' : 'ERC20SaleParticipants', {
      authorizationId: mint!.authorizationId, artist: authorization.artist, payer, recipient: beneficiary,
      ...(kind === 'native-fixed' ? { collectionId: mint!.collectionId } : { primaryPolicyHash: mint!.primaryPolicyHash })
    });
    if (participants.log.index <= settled.log.index) throw Error('Participants precede settlement');
    lastSettlement = participants.log.index;
    if (before.paymentIntent === 'signed-intent') {
      const intent = args[4];
      const consumed = m.one(product, 'PaymentIntentConsumed', {
        payer, saleRef: authorization.saleId, nonce: intent.nonce, schemaVersion: 1n, asset, amount
      });
      if (consumed.log.index >= settled.log.index) throw Error('Intent consumption after settlement');
      intentIndex = consumed.log.index;
      const [used] = await read(provider, product, 'isPaymentIntentNonceUsed', [payer, intent.nonce], tag);
      if (!used) throw Error('Payer intent not consumed');
    } else if (m.found(product, 'PaymentIntentConsumed').length) throw Error('Exempt caller consumed payer intent');
    const [used] = await read(provider, product, 'authorizationUsed', [authorization.artist, authorization.nonce], tag);
    if (!used) throw Error('Commercial authorization not consumed');
    await completedToken(provider, d, mint!, tokenId, tag);
    outcome = amount > 0n ? 'paid' : 'free-mint';
  } else if (method === 'createAuction') {
    const authorization = args[0];
    direct.validateDirectConservationExecutionTerms(saved.prepared, { timestamp: observed.timestamp, signerEpoch: authorization.signerEpoch });
    equal(await admission(provider, d, observed, true), before.admission, 'Auction creation admission');
    const created = m.one(product, 'AuctionCreated', {
      artist: mint!.artist, authorizationId: mint!.authorizationId, operationRoot: mint!.operationRoot,
      authorizationDigest: mint!.authorizationDigest, profileId: mint!.profileId, wallet: mint!.wallet
    });
    tokenId = uint(created.args.tokenId);
    const terms = m.one(product, 'AuctionTerms', {
      tokenId, reservePrice: authorization.reservePrice, startTime: authorization.startTime,
      endTime: authorization.endTime, extensionWindow: authorization.extensionWindow,
      minBidIncrementBps: authorization.minBidIncrementBps
    });
    if (terms.log.index <= created.log.index) throw Error('Auction terms precede creation');
    const [raw] = await read(provider, product, 'auction', [tokenId], tag);
    auction = direct.normalizeDirectConservationAuction(raw);
    equal(auction, {
      artist: authorization.artist, wallet: mint!.wallet, profileId: mint!.profileId,
      reservePrice: authorization.reservePrice, startTime: authorization.startTime, endTime: authorization.endTime,
      extensionWindow: authorization.extensionWindow, minBidIncrementBps: authorization.minBidIncrementBps,
      highestBidder: ZeroAddress, deliveryRecipient: authorization.artist, highestBid: 0n,
      settled: false, cancelled: false, pendingNoBidNftClaimant: ZeroAddress,
      authorizationId: mint!.authorizationId, operationRoot: mint!.operationRoot, primaryPolicyHash: mint!.primaryPolicyHash
    }, 'Auction creation state');
    const [used] = await read(provider, product, 'authorizationUsed', [authorization.artist, authorization.nonce], tag);
    if (!used) throw Error('Auction authorization not consumed');
    await completedToken(provider, d, mint!, tokenId, tag);
    await emptyPaidReceipt(provider, product, mint!.authorizationId, tag);
    noPaidEvents(m, product);
    outcome = 'auction-created';
  } else if (before.auction) {
    tokenId = args[0];
    const prior = before.auction;
    if (['settle', 'cancel', 'claimNoBidNFT'].includes(method)) await pinned(provider, d.core, tag);
    const [raw] = await read(provider, product, 'auction', [tokenId], tag);
    auction = direct.normalizeDirectConservationAuction(raw);
    let expected = { ...prior };
    if (method === 'bid') {
      if (observed.timestamp < prior.startTime || observed.timestamp >= prior.endTime) throw Error('Bid outside mined window');
      const endTime = prior.endTime - observed.timestamp < prior.extensionWindow ? observed.timestamp + prior.extensionWindow : prior.endTime;
      expected = { ...prior, highestBidder: saved.prepared.caller, deliveryRecipient: args[1], highestBid: call.value, endTime };
      const bid = m.one(product, 'AuctionBidPlaced', { tokenId, bidder: saved.prepared.caller, recipient: args[1], amount: call.value, endTime });
      if (prior.highestBid > 0n) {
        const refund = m.one(product, 'AuctionRefundCredited', { bidder: prior.highestBidder, tokenId, amount: prior.highestBid });
        if (refund.log.index >= bid.log.index) throw Error('Refund credit after new bid');
      } else if (m.found(product, 'AuctionRefundCredited').length) throw Error('Unexpected refund credit');
      outcome = 'bid';
    } else if (method === 'setDeliveryRecipient') {
      expected.deliveryRecipient = args[1];
      m.one(product, 'AuctionRecipientChanged', { tokenId, recipient: args[1] });
      outcome = 'recipient-updated';
    } else if (method === 'cancel') {
      if (observed.timestamp >= prior.endTime) throw Error('Cancellation after auction end');
      expected = { ...prior, settled: true, cancelled: true };
      m.one(product, 'AuctionCancelled', { tokenId, recipient: prior.deliveryRecipient });
      outcome = 'cancelled';
    } else {
      if (method === 'settle' && observed.timestamp < prior.endTime) throw Error('Settlement before auction end');
      const pending = method === 'settle' && prior.highestBid === 0n
        && bytes(await provider.getCode(prior.deliveryRecipient, tag - 1), 131072) !== '0x';
      if (pending) {
        expected.pendingNoBidNftClaimant = prior.artist;
        if (prior.pendingNoBidNftClaimant === ZeroAddress) m.one(product, 'NoBidAuctionNFTClaimPending', { tokenId, claimant: prior.artist });
        else if (m.found(product, 'NoBidAuctionNFTClaimPending').length) throw Error('Eventless no-bid retry emitted first event');
        if (m.found(product, 'AuctionSettled').length) throw Error('Pending no-bid claim falsely settled');
        outcome = 'pending-no-bid';
      } else {
        beneficiary = method === 'claimNoBidNFT' ? args[1] : prior.deliveryRecipient;
        expected = { ...prior, settled: true, pendingNoBidNftClaimant: ZeroAddress, deliveryRecipient: beneficiary };
        amount = prior.highestBid;
        payer = prior.highestBidder;
        const settled = m.one(product, 'AuctionSettled', { tokenId, bidder: payer, recipient: beneficiary, wallet: prior.wallet, amount });
        lastSettlement = settled.log.index;
        settlementIndex = settled.log.index;
        outcome = amount > 0n ? 'paid' : 'delivered-no-bid';
        if (amount > 0n) {
          if (!originInput || argumentsOf(originInput.capture.prepared).method !== 'createAuction') throw Error('Authenticated auction creation receipt required');
          equal(originInput.capture.deployment, d, 'Auction creation deployment');
          const origin = await reconcileDirectConservationReceipt(provider, originInput.capture, originInput.transactionHash, originInput.transport);
          if (origin.outcome !== 'auction-created' || origin.tokenId !== tokenId || origin.observed.blockNumber >= tag) throw Error('Wrong auction creation witness');
          mint = origin.mint;
          same(mint!.authorizationId, prior.authorizationId, 'Auction origin authorization');
          same(mint!.operationRoot, prior.operationRoot, 'Auction origin operation');
          same(mint!.primaryPolicyHash, prior.primaryPolicyHash, 'Auction origin policy');
          same(mint!.wallet, prior.wallet, 'Auction origin wallet');
          same(mint!.profileId, prior.profileId, 'Auction origin profile');
          createdAt = origin.observed.timestamp;
          creationRevision = origin.capture.admission!.revision;
          await completedToken(provider, d, mint!, tokenId!, tag);
        }
      }
    }
    equal(auction, expected, 'Auction poststate');
    if (amount === 0n) {
      noPaidEvents(m, product);
      await emptyPaidReceipt(provider, product, prior.authorizationId, tag);
    }
  } else if (method === 'withdrawRefund') {
    m.one(product, 'AuctionRefundWithdrawn', { bidder: saved.prepared.caller, recipient: args[0], amount: before.refundCredit! });
    const [credit] = await read(provider, product, 'refundCredit', [saved.prepared.caller], tag);
    if (credit !== 0n) throw Error('Refund credit not cleared');
    outcome = 'refund';
  } else if (method === 'cancelAuthorization') {
    const event = saved.prepared.coordinates.productKind === 'english-auction'
      ? 'AuctionAuthorizationCancelled' : 'SaleAuthorizationCancelled';
    m.one(product, event, { artist: saved.prepared.caller, nonce: args[0] });
    const [used] = await read(provider, product, 'authorizationUsed', [saved.prepared.caller, args[0]], tag);
    if (!used) throw Error('Cancellation not retained');
    outcome = 'authorization-cancelled';
  } else if (method === 'revokePaymentIntent' || method === 'revokePaymentIntentBySignature') {
    const payer = method === 'revokePaymentIntent' ? saved.prepared.caller : args[0];
    const nonce = method === 'revokePaymentIntent' ? args[0] : args[1];
    if (method === 'revokePaymentIntentBySignature' && observed.timestamp > args[2]) throw Error('Revocation expired at execution');
    m.one(product, 'PaymentIntentRevoked', { payer, nonce, schemaVersion: 1n });
    const [used] = await read(provider, product, 'isPaymentIntentNonceUsed', [payer, nonce], tag);
    if (!used) throw Error('Intent revocation not retained');
    outcome = 'intent-revoked';
  } else if (method === 'registerSale') {
    const config = args[0];
    if (config.endsAt < observed.timestamp) throw Error('Registered sale ended before execution');
    const saleId = direct.directConservationERC20SaleId(saved.prepared.coordinates, config.collectionId, config.phaseId, before.nextSaleNonce!);
    const configHash = direct.directConservationERC20ConfigHash(saleId, config);
    m.one(product, 'SaleConfigured', {
      saleId,
      collectionId: config.collectionId,
      phaseId: config.phaseId,
      saleNonce: before.nextSaleNonce!,
      saleConfigHash: configHash
    });
    const [raw] = await read(provider, product, 'saleRecord', [saleId], tag);
    equal(direct.normalizeDirectConservationERC20SaleRecord(raw), { config, saleNonce: before.nextSaleNonce!, configHash, cancelled: false }, 'Registered sale');
    outcome = 'sale-configured';
  } else if (method === 'cancelSale') {
    m.one(product, 'SaleCancelled', { saleId: args[0] });
    const [raw] = await read(provider, product, 'saleRecord', [args[0]], tag);
    equal(direct.normalizeDirectConservationERC20SaleRecord(raw), { ...before.sale!, cancelled: true }, 'Cancelled sale');
    outcome = 'sale-cancelled';
  } else throw Error('Unsupported original receipt method');
  if (amount > 0n) {
    const currentAdmission = await admission(provider, d, observed, method === 'buy');
    if (createdAt < currentAdmission.registeredAt || createdAt > observed.timestamp
      || creationRevision === 0n || creationRevision > currentAdmission.revision
      || (method === 'buy' && creationRevision !== currentAdmission.revision)
      || (currentAdmission.status === 2n && (createdAt >= currentAdmission.statusUpdatedAt || creationRevision >= currentAdmission.revision))) {
      throw Error('Paid receipt admission timing or revision differs');
    }
    const expected = {
      authorizationDigest: mint!.authorizationDigest, collectionId: mint!.collectionId, tokenId: tokenId!,
      operationRoot: mint!.operationRoot, operationId: mint!.operationId,
      boundMintPolicyHash: mint!.boundMintPolicyHash, expectedPrimaryPolicyHash: mint!.primaryPolicyHash,
      profileId: mint!.profileId, wallet: mint!.wallet, createdAt, payer, registryRevision: creationRevision,
      beneficiary, asset, amount
    };
    const [[rawPaid], [savedHash]] = await Promise.all([
      read(provider, product, 'directPrimarySaleReceipt', [mint!.authorizationId], tag),
      read(provider, product, 'directPrimarySaleReceiptHash', [mint!.authorizationId], tag)
    ]);
    paidReceipt = direct.normalizeDirectConservationReceipt(rawPaid);
    equal(paidReceipt, { ...expected, escrowed: paidReceipt.escrowed }, 'Paid original receipt');
    const receiptHash = direct.directConservationReceiptHash(before.bindings, product, mint!.authorizationId, paidReceipt);
    same(savedHash, receiptHash, 'Paid original receipt hash');
    const paidEvent = m.one(product, 'DirectPrimarySaleRecorded', {
      authorizationId: mint!.authorizationId, receiptHash, tokenId: tokenId!, receipt: paidReceipt, schemaVersion: 1n
    });
    const floor = await selectedFloor(provider, d, tag);
    if (!before.floor) throw Error('Missing prior floor');
    equal(floor, before.floor, 'Receipt floor selection');
    const key = direct.directConservationKey(before.bindings, product, mint!.authorizationId);
    const floorEvent = m.one(floor.address, 'ConservationDirectPrimarySaleRecorded', { directKey: key, schemaVersion: 1n });
    if (releaseKey === undefined) {
      const releases = m.found(floor.address, 'ConservationReleaseFloorRecorded')
        .filter(event => event.args.receipt?.settlementKey === key);
      if (releases.length === 1) releaseKey = hash(releases[0]!.args.releaseKey);
    }
    floorHistory = await inspectDirectConservationFloorHistory(provider, {
      chainId: d.chainId, core: d.core.address, floor, key
    }, { blockTag: tag, ...(releaseKey === undefined ? {} : { releaseKey }) });
    const history = floorHistory.receipt;
    equal(history.sale, paidReceipt, 'Floor original paid tuple');
    equal(history.bindings, before.bindings, 'Floor original bindings');
    same(history.adapter, product, 'Floor adapter');
    same(history.adapterCodeHash, d.product.codeHash, 'Floor adapter runtime');
    same(history.authorizationId, mint!.authorizationId, 'Floor original authorization');
    same(history.originalReceiptHash, receiptHash, 'Floor original receipt link');
    if (history.recordedAt !== observed.timestamp) throw Error('Floor receipt execution time differs');
    equal(floorEvent.args.receipt, history, 'Floor event tuple');
    same(floorEvent.args.receiptHash, history.receiptHash, 'Floor event hash');
    if (floorEvent.log.index >= paidEvent.log.index || paidEvent.log.index >= settlementIndex
      || intentIndex >= floorEvent.log.index) throw Error('Intent, floor, DIRECT and settlement events misordered');
    let previousFloorIndex = intentIndex;
    for (const [name, record] of [
      ['ConservationFirstSaleRecorded', floorHistory.firstSale],
      ['ConservationReleaseFloorRecorded', floorHistory.release]
    ] as const) {
      if (record && record.settlementKey === key) {
        const original = m.one(floor.address, name, { receiptHash: record.receiptHash, receipt: record, schemaVersion: 1n });
        if (original.log.index >= floorEvent.log.index || original.log.index <= previousFloorIndex) throw Error('Floor prerequisite events misordered');
        previousFloorIndex = original.log.index;
      }
    }
    const funded = m.one(product, 'SaleRevenueFunded', {
      schemaVersion: 1n, authorizationId: mint!.authorizationId, operationRoot: mint!.operationRoot,
      profileId: mint!.profileId, wallet: mint!.wallet, asset, amount, escrowed: paidReceipt.escrowed
    });
    if (funded.log.index <= lastSettlement) throw Error('Funding event precedes settlement or participants');
  } else {
    noPaidEvents(m, product);
    if (method === 'buy') {
      await emptyPaidReceipt(provider, product, mint!.authorizationId, tag);
      const funded = m.one(product, 'SaleRevenueFunded', {
        schemaVersion: 1n, authorizationId: mint!.authorizationId, operationRoot: mint!.operationRoot,
        profileId: mint!.profileId, wallet: mint!.wallet, asset: ZeroAddress, amount: 0n, escrowed: false
      });
      if (funded.log.index <= lastSettlement) throw Error('Free funding event precedes settlement');
    } else if (m.found(product, 'SaleRevenueFunded').length) throw Error('Unpaid operation emitted revenue funding');
  }
  if (selectedTransport.execution === 'safe') {
    const successTopic = id('ExecutionSuccess(bytes32,uint256)');
    const failureTopic = id('ExecutionFailure(bytes32,uint256)');
    const successes = logs.filter(log => log.address === saved.prepared.caller && log.topics[0] === successTopic);
    const failures = logs.filter(log => log.address === saved.prepared.caller && log.topics[0] === failureTopic);
    if (successes.length !== 1 || failures.length !== 0) throw Error('Missing Safe success or observed failure');
    const success = successes[0]!;
    if (success.index <= Math.max(-1, ...refs)) throw Error('Safe success precedes required product evidence');
    if (!((success.topics.length === 1 && success.data.length === 130)
      || (success.topics.length === 2 && success.data.length === 66))) throw Error('Malformed Safe success');
    requireSafeExecution({
      status: 1,
      logs: logs.map(log => ({ address: log.address, topics: [...log.topics], data: log.data }))
    }, saved.prepared.caller, selectedTransport.expectedSafeTxHash);
    refs.push(success.index);
  }
  equal(await header(provider, tag, d.chainId), observed, 'Receipt block');
  return freeze({
    capture: before, transactionHash, observed, tokenId, mint, paidReceipt, floorHistory, auction,
    ...(control === undefined ? {} : { control }),
    outcome, requiredLogIndices: [...new Set(refs)].sort((a, b) => a - b)
  });
}

export interface DirectConservationProductHistory {
  readonly chainId: bigint;
  readonly product: DirectConservationCodePin;
  readonly authorizationId: Hex;
  readonly observed: DirectConservationBlock;
  readonly bindings: direct.DirectConservationBindings;
  readonly receipt: direct.DirectConservationReceipt | null;
  readonly receiptHash: Hex;
}

/** Immutable product receipt read. Empty means no paid receipt, not an unused commercial nonce. */
export async function inspectDirectConservationReceipt(
  provider: Reader,
  input: {
    readonly chainId: bigint;
    readonly product: DirectConservationCodePin;
    readonly authorizationId: Hex;
  },
  options: { readonly blockTag: number }
): Promise<DirectConservationProductHistory> {
  keys(input, ['chainId', 'product', 'authorizationId']);
  keys(options, ['blockTag']);
  const chainId = uint(input.chainId);
  const product = pin(input.product);
  const authorizationId = hash(input.authorizationId, true);
  const tag = integer(options.blockTag);
  const observed = await header(provider, tag, chainId);
  await pinned(provider, product, tag);
  const [[rawBindings], [rawReceipt], [rawHash]] = await Promise.all([
    read(provider, product.address, 'directPrimaryBindings', [], tag),
    read(provider, product.address, 'directPrimarySaleReceipt', [authorizationId], tag),
    read(provider, product.address, 'directPrimarySaleReceiptHash', [authorizationId], tag)
  ]);
  const bindings = direct.normalizeDirectConservationBindings(rawBindings);
  const retained = direct.normalizeDirectConservationReceipt(rawReceipt);
  address(bindings.core);
  address(bindings.mintManager);
  hash(bindings.coreCodeHash);
  hash(bindings.mintManagerCodeHash);
  if (!Object.values(direct.DIRECT_CONSERVATION_PRODUCT_KINDS).includes(bindings.productKind)) throw Error('Unknown original product kind');
  if (bindings.deploymentChainId !== chainId) throw Error('Product history deployment differs');
  let receipt: direct.DirectConservationReceipt | null = retained;
  if (retained.amount === 0n) {
    for (const value of Object.values(retained)) {
      if (value !== 0n && value !== false && value !== ZeroAddress && value !== ZeroHash) throw Error('Noncanonical empty product receipt');
    }
    same(rawHash, ZeroHash, 'Empty product receipt hash');
    receipt = null;
  } else {
    paidTuple(bindings, authorizationId, retained);
    same(rawHash, direct.directConservationReceiptHash(bindings, product.address, authorizationId, retained), 'Retained product receipt hash');
    if (retained.createdAt > observed.timestamp) throw Error('Product receipt is from the future');
  }
  equal(await header(provider, tag, chainId), observed, 'Product history block');
  return freeze({ chainId, product, authorizationId, observed, bindings, receipt, receiptHash: hash(rawHash, true) });
}

function paidTuple(
  bindings: direct.DirectConservationBindings,
  authorizationId: Hex,
  receipt: direct.DirectConservationReceipt
): void {
  hash(authorizationId);
  address(bindings.core);
  address(bindings.mintManager);
  hash(bindings.coreCodeHash);
  hash(bindings.mintManagerCodeHash);
  if (!Object.values(direct.DIRECT_CONSERVATION_PRODUCT_KINDS).includes(bindings.productKind)) throw Error('Unknown original product kind');
  for (const value of [receipt.authorizationDigest, receipt.operationRoot, receipt.operationId,
  receipt.boundMintPolicyHash, receipt.expectedPrimaryPolicyHash, receipt.profileId]) hash(value);
  for (const value of [receipt.wallet, receipt.payer, receipt.beneficiary]) address(value);
  if (receipt.collectionId === 0n || receipt.tokenId === 0n || receipt.createdAt === 0n
    || receipt.registryRevision === 0n || receipt.amount === 0n) throw Error('Invalid paid original receipt');
  if (bindings.productKind === direct.DIRECT_CONSERVATION_PRODUCT_KINDS['erc20-fixed']) address(receipt.asset);
  else same(receipt.asset, ZeroAddress, 'Native original asset');
}
