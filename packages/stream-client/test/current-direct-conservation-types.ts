import type { Address, Hex } from "../src/generated/contracts.js";
import type { UnsignedCall } from "../src/binding.js";
import type { SigningPayload } from "../src/signing.js";
import * as d from "../src/current-direct-conservation.js";

declare const coordinates: d.DirectConservationCoordinates;
declare const floor: d.DirectConservationFloorCoordinates;
declare const caller: Address;
declare const hash: Hex;
declare const native: d.DirectConservationNativeAuthorization;
declare const erc20: d.DirectConservationERC20Authorization;
declare const auction: d.DirectConservationAuctionAuthorization;
declare const config: d.DirectConservationERC20Config;
declare const saleRecord: d.DirectConservationERC20SaleRecord;
declare const intent: d.DirectConservationPaymentIntent;
declare const receipt: d.DirectConservationReceipt;
declare const bindings: d.DirectConservationBindings;
declare const floorReceipt: d.DirectConservationFloorReceipt;
declare const firstSale: d.DirectConservationFirstSaleReceipt;
declare const release: d.DirectConservationReleaseReceipt;

const signedData = { tokenData: hash, platformSignature: "0x", artistSignature: hash } as const;
const calls: readonly d.DirectConservationCall[] = [
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "native-fixed",
    kind: "buy",
    authorization: native,
    ...signedData
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed",
    kind: "buy",
    authorization: erc20,
    ...signedData,
    intent,
    payerSignature: "0x"
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction",
    kind: "createAuction",
    authorization: auction,
    ...signedData
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed", kind: "registerSale", config
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed", kind: "cancelSale", saleId: hash
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "native-fixed", kind: "cancelAuthorization", nonce: hash
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed", kind: "cancelAuthorization", nonce: hash
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "cancelAuthorization", nonce: hash
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed", kind: "revokePaymentIntent", nonce: hash
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "erc20-fixed",
    kind: "revokePaymentIntentBySignature",
    payer: caller,
    nonce: hash,
    deadline: 1n,
    signature: "0x"
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "bid", tokenId: 1n, recipient: caller, amount: 20n
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "settle", tokenId: 1n
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "cancel", tokenId: 1n
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "setDeliveryRecipient", tokenId: 1n, recipient: caller
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "claimNoBidNFT", tokenId: 1n, recipient: caller
  }),
  d.prepareDirectConservationCall(coordinates, caller, {
    productKind: "english-auction", kind: "withdrawRefund", recipient: caller
  })
];

for (const plan of calls) {
  const normalized: d.DirectConservationCall = d.normalizeDirectConservationCall(plan);
  const ordinary: UnsignedCall = normalized.call;
  const actualCaller: Address = normalized.caller;
  const unverified: false = normalized.factsVerified;
  if (plan.request.kind === "buy" && plan.request.productKind === "erc20-fixed") {
    const separatePayerProof: Hex = plan.request.payerSignature;
    const originalConfigHash: Hex = plan.request.authorization.saleConfigHash;
    void separatePayerProof;
    void originalConfigHash;
  }
  if (plan.request.kind === "buy" && plan.request.productKind === "native-fixed") {
    const amount: bigint = plan.request.authorization.price;
    // @ts-expect-error Native purchases do not have payer intents or ERC20 transport.
    plan.request.intent;
    void amount;
  }
  // @ts-expect-error Prepared call values are immutable.
  normalized.call.value = 0n;
  // @ts-expect-error The actual caller is an immutable snapshot.
  normalized.caller = caller;
  void ordinary;
  void actualCaller;
  void unverified;
}

const nativePayload: SigningPayload<d.DirectConservationNativeAuthorization> =
  d.directConservationNativeTypedData(coordinates, native);
const erc20Payload: SigningPayload<d.DirectConservationERC20Authorization> =
  d.directConservationERC20TypedData(coordinates, erc20);
const auctionPayload: SigningPayload<d.DirectConservationAuctionAuthorization> =
  d.directConservationAuctionTypedData(coordinates, auction);
d.directConservationPaymentIntentTypedData(coordinates, intent);
d.directConservationPaymentRevocationTypedData(coordinates, { payer: caller, nonce: hash, deadline: 1n });

const batch: d.DirectConservationMintBatch = d.directConservationMintBatch(calls[0]!, saleRecord);
const initialRecipients: readonly Address[] = batch.initialRecipients;
const commitments: readonly Hex[] = batch.mintCommitments;
const originalPayer: Address = batch.payer;
// @ts-expect-error Mint arrays cannot be changed after planning.
batch.initialRecipients.push(caller);
// @ts-expect-error Full-width collection IDs are bigints.
d.normalizeDirectConservationNativeAuthorization({ ...native, collectionId: 1 });
// @ts-expect-error Enum-like product names are closed.
d.normalizeDirectConservationCoordinates({ ...coordinates, productKind: "universal" });
// @ts-expect-error Native original schema is not ERC20 original schema.
d.directConservationERC20TypedData(coordinates, native);
// @ts-expect-error ERC20 cannot use auction transports.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "erc20-fixed", kind: "bid", tokenId: 1n, recipient: caller, amount: 1n });
// @ts-expect-error Native schema must be supplied for native buy.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "native-fixed", kind: "buy", authorization: erc20, ...signedData });
// @ts-expect-error No arbitrary wallet floor receipt writer exists.
d.prepareDirectConservationFloorRead(floor, { kind: "recordDirectPrimarySale", authorizationId: hash });
// @ts-expect-error Exact native call request has no universal candidate.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "native-fixed", kind: "buy", authorization: native, ...signedData, candidate: hash });
// @ts-expect-error Explicit bid amount cannot be a JS number.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "english-auction", kind: "bid", tokenId: 1n, recipient: caller, amount: 1 });

const history: d.DirectConservationHistory = d.validateDirectConservationHistory(floor, floorReceipt, firstSale, release);
const historicalRelease: d.DirectConservationReleaseReceipt | null = history.release;
const fullWidthAmount: bigint = history.receipt.sale.amount;
// @ts-expect-error Nested historical data is readonly.
history.receipt.bindings.core = caller;
// @ts-expect-error Historical receipt timestamp remains uint64 bigint.
d.normalizeDirectConservationReceipt({ ...receipt, createdAt: 12 });
d.directConservationReceiptHash(bindings, caller, hash, receipt);
d.directConservationReceiptLookupHash(bindings, caller, hash, receipt);
d.directConservationKey(bindings, caller, hash);
d.directConservationFloorReceiptHash(floor, floorReceipt);
d.directConservationFirstSaleReceiptHash(floor, firstSale);
d.directConservationReleaseReceiptHash(floor, release);
d.directConservationReleaseKey(coordinates.chainId, coordinates.core, 1n, release.context);
d.decodeDirectConservationFloorReceipt(d.encodeDirectConservationFloorReceipt(floorReceipt));
d.decodeDirectConservationReceipt(d.encodeDirectConservationReceipt(receipt));
d.decodeDirectConservationBindings(d.encodeDirectConservationBindings(bindings));
d.directConservationERC20SaleId(coordinates, 1n, hash, 0n);
d.directConservationERC20ConfigHash(hash, config);
const lane: "caller" | "signature" | null = d.validateDirectConservationExecutionTerms(
  calls[0]!, { timestamp: 1n, signerEpoch: 1n }, saleRecord
).paymentLane;
d.validateDirectConservationAdmission("english-auction", 1n, 1n, {
  status: 2n, registeredAt: 1n, statusUpdatedAt: 2n, revision: 2n, timestamp: 3n
});
const reads: readonly UnsignedCall[] = [
  d.prepareDirectConservationRead(coordinates, { kind: "directPrimaryBindings" }),
  d.prepareDirectConservationRead(coordinates, { kind: "directPrimarySaleReceipt", authorizationId: hash }),
  d.prepareDirectConservationRead(coordinates, { kind: "authorizationDigest", authorization: native }),
  d.prepareDirectConservationRead(coordinates, { kind: "saleRecord", saleId: hash }),
  d.prepareDirectConservationRead(coordinates, { kind: "paymentIntentDigest", intent }),
  d.prepareDirectConservationRead(coordinates, { kind: "minimumBid", tokenId: 0n }),
  d.prepareDirectConservationFloorRead(floor, { kind: "firstSale", collectionId: 0n }),
  d.prepareDirectConservationFloorRead(floor, { kind: "releaseFloorReceipt", releaseKey: hash }),
  d.prepareDirectConservationFloorRead(floor, { kind: "directPrimarySaleFloorReceipt", directKey: hash }),
  d.prepareDirectConservationFloorRead(floor, { kind: "sourceAt", sourceId: 1n })
];
void nativePayload;
void erc20Payload;
void auctionPayload;
void initialRecipients;
void commitments;
void originalPayer;
void historicalRelease;
void fullWidthAmount;
void lane;
void reads;

declare const controlState: d.DirectConservationControlState;
const controlCalls: d.DirectConservationCall[] = [];
for (const productKind of ["native-fixed", "erc20-fixed", "english-auction"] as const) {
  const controls: readonly d.DirectConservationCommonControlRequest[] = [
    { kind: "setPaused", paused: false },
    { kind: "setPlatformSigner", signer: caller },
    { kind: "transferOwnership", newOwner: caller },
    { kind: "renounceOwnership" }
  ];
  for (const request of controls) {
    controlCalls.push(d.prepareDirectConservationCall(coordinates, caller, { productKind, ...request }));
  }
  d.normalizeDirectConservationControlState(productKind, controlState);
  for (const kind of ["owner", "paused", "platformSigner", "signerEpoch"] as const) {
    const controlRead: UnsignedCall = d.prepareDirectConservationRead(coordinates, { kind });
    void controlRead;
  }
}
controlCalls.push(d.prepareDirectConservationCall(coordinates, caller, {
  productKind: "erc20-fixed",
  kind: "raiseSignatureGasLimit",
  value: (1n << 64n) - 1n
}));
d.prepareDirectConservationRead(coordinates, { kind: "signatureGasLimit" });
for (const plan of controlCalls) {
  const transition: d.DirectConservationControlTransition = d.directConservationControlTransition(plan, controlState);
  const before: d.DirectConservationControlState = transition.before;
  const after: d.DirectConservationControlState = transition.after;
  const unverified: false = transition.factsVerified;
  const gasLimit: bigint | null = after.signatureGasLimit;
  const event: d.DirectConservationControlEvent = transition.expectedEvent;
  if (event.name === "OwnershipTransferred") {
    const oldOwner: Address = event.args[0];
    const newOwner: Address = event.args[1];
    void oldOwner;
    void newOwner;
  }
  if (event.name === "SignatureGasLimitRaised") {
    const previous: bigint = event.args[0];
    const current: bigint = event.args[1];
    void previous;
    void current;
  }
  if (d.isDirectConservationControlRequest(plan.request)) {
    const control: d.DirectConservationControlRequest = plan.request;
    if (control.kind === "raiseSignatureGasLimit") {
      const onlyERC20: "erc20-fixed" = control.productKind;
      const preciseValue: bigint = control.value;
      void onlyERC20;
      void preciseValue;
    }
  }
  // @ts-expect-error The supplied state is frozen before asynchronous observation.
  transition.before.owner = caller;
  // @ts-expect-error Expected event arguments are readonly tuples.
  event.args[0] = caller;
  // @ts-expect-error Control state is not a live authority assertion.
  const verified: true = transition.factsVerified;
  void before;
  void after;
  void unverified;
  void gasLimit;
  void verified;
}

// @ts-expect-error Pausing requires an actual boolean.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "native-fixed", kind: "setPaused", paused: 1n });
// @ts-expect-error The original signer setter has no synthetic expected epoch guard.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "english-auction", kind: "setPlatformSigner", signer: caller, expectedSignerEpoch: 1n });
// @ts-expect-error Only ERC20 has the original signature-gas setter.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "native-fixed", kind: "raiseSignatureGasLimit", value: 400001n });
// @ts-expect-error Original uint256 arguments require bigint, not number.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "erc20-fixed", kind: "raiseSignatureGasLimit", value: 400001 });
// @ts-expect-error Original ownership is one-step and has no acceptance method.
d.prepareDirectConservationCall(coordinates, caller, { productKind: "erc20-fixed", kind: "acceptOwnership" });
// @ts-expect-error Control observations do not have pending-owner state.
d.normalizeDirectConservationControlState("native-fixed", { ...controlState, pendingOwner: caller });
