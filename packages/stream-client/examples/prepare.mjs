// Offline: prints a reviewable payload; never prompts a wallet or submits a transaction.
import { readFile } from "node:fs/promises";
import { typedDataFromJSON, toJSON, walletTypedData } from "../dist/index.js";
const args = process.argv.slice(2);
const rpc = args[0] === "--rpc";
if (rpc) args.shift();
if (args.length !== 1 || args[0].startsWith("--")) throw Error("Usage: npm run example -- [--rpc] path/to/signing-request.json");
const request = JSON.parse(await readFile(args[0], "utf8"));
const payload = typedDataFromJSON(request);
console.log(toJSON(rpc ? walletTypedData(payload) : payload));
