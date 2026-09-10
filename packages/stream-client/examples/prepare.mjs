// Offline: prints a reviewable payload; never prompts a wallet or submits a transaction.
import { readFile } from "node:fs/promises";
import { typedDataFromJSON, toJSON } from "../dist/index.js";
if (process.argv.length !== 3) throw Error("Usage: npm run example -- path/to/signing-request.json");
const request = JSON.parse(await readFile(process.argv[2], "utf8"));
console.log(toJSON(typedDataFromJSON(request)));
