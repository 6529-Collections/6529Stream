import { ZeroAddress, ZeroHash, id } from "ethers";
import {
  delegateGateConfigHash, delegateMintAuthorizationId, delegateMintRequest,
  mintAllowlistAuthorizationBinding, mintAllowlistAuthorizationId, mintAllowlistGateConfigHash,
  mintAllowlistProofValuesHash, mintAllowlistResolverData, mintBatchHashes,
  mintTicketAuthorizationId, mintTicketForBatch, mintTicketSafeMessageBytes, mintTicketTypedData,
} from "../dist/current-mint-gates.js";

// Offline illustrative coordinates. Nothing below signs, sends, or establishes live eligibility.
const A = n => `0x${BigInt(n).toString(16).padStart(40, "0")}`;
const chainId = 1n, manager = A(1), ledger = A(2), executor = A(3), payer = A(4), signerSafe = A(5), ticketGate = A(6);
const batch = { collectionId: 6529n, phaseId: id("phase"), payer, authorizer: signerSafe,
  initialRecipients: [A(7)], beneficiaries: [A(8)], tokenData: ["0x1234"], mintCommitments: [id("mint")],
  expectedPolicyHash: id("policy"), authorizationId: ZeroHash, contextHash: id("context"), resolverData: "0x" };
const ticket = mintTicketForBatch({ chainId, manager, ledger, executor, authorizerKind: 2n,
  nonce: id("ticket nonce"), deadline: 2_000_000_000n }, batch);
const signing = mintTicketTypedData(chainId, ticketGate, ticket);
const ticketAuthorizationId = mintTicketAuthorizationId(signing.digest);
const safeMessageBytes = mintTicketSafeMessageBytes(signing.digest);

const vault = A(9), delegateGate = A(10), core = A(11), registry = A(12), usecase = id("delegate usecase");
const delegateConfig = delegateGateConfigHash(chainId, core, registry, id("registry runtime"), usecase);
const delegateBatch = { ...batch, authorizer: ZeroAddress, initialRecipients: [vault], beneficiaries: [vault] };
const delegateRequest = delegateMintRequest(manager, executor, delegateBatch, vault, id("delegate nonce"));
const delegateAuthorizationId = delegateMintAuthorizationId(chainId, delegateGate, delegateConfig, delegateRequest);

const allowlistGate = A(13), counterId = id("recipient cap"), root = id("illustrative Merkle root");
const proof = { maxCount: 3n, hasPriceOverride: false, priceOverride: 0n, proof: [id("sibling")] };
const resolverData = mintAllowlistResolverData([[proof]]);
const proofValuesHash = mintAllowlistProofValuesHash([counterId], [[proof]]);
const allowlistBatch = { ...batch, authorizer: ZeroAddress, resolverData };
const allowlistConfig = mintAllowlistGateConfigHash(root, counterId);
const allowlistBinding = mintAllowlistAuthorizationBinding(manager, ledger, executor, allowlistBatch, proofValuesHash, id("allowlist nonce"));
const allowlistAuthorizationId = mintAllowlistAuthorizationId(chainId, allowlistGate, allowlistConfig, allowlistBinding);

console.log(JSON.stringify({ batchHashes: mintBatchHashes(batch), ticket, signing, ticketAuthorizationId, safeMessageBytes,
  delegateRequest, delegateAuthorizationId, allowlistBinding, allowlistAuthorizationId,
  next: "Obtain the required signature or live eligibility proof, assemble the Manager request, and preview it against current state." },
(_key, value) => typeof value === "bigint" ? value.toString() : value, 2));
