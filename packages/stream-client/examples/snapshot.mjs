// Read-only capture, offline verification and pinned-chain readback. Never sign or publish.
import { readFile, writeFile, mkdir, mkdtemp, rename, lstat, rm } from "node:fs/promises";
import { resolve, dirname, join } from "node:path";
import { JsonRpcProvider } from "ethers";
import { StreamClient, stackConfigFromJSON, snapshotSelectionFromJSON, captureSupportedState, packageSnapshot, verifySnapshotPackage, verifySnapshotReadback, canonicalJSON, SnapshotReadError } from "../dist/index.js";

const args = process.argv.slice(2), command = args.shift();
const usage = "Usage: snapshot.mjs capture config.json selection.json NEW_DIRECTORY | verify DIRECTORY | inspect DIRECTORY | readback config.json DIRECTORY";
const loadJSON = async path => JSON.parse(await readFile(path, "utf8"));
const loadPackage = async directory => ({ snapshot: await readFile(join(directory, "snapshot.json"), "utf8"), manifest: await readFile(join(directory, "manifest.json"), "utf8"), publication: await readFile(join(directory, "publication.json"), "utf8") });
let provider;
try {
  if ((command === "verify" || command === "inspect") && args.length === 1) {
    const snapshot = verifySnapshotPackage(await loadPackage(resolve(args[0])));
    if (command === "inspect") console.log(JSON.stringify({ chainId: snapshot.chainId, block: snapshot.block, selection: snapshot.selection, coverage: snapshot.coverage, contracts: snapshot.contracts, reads: snapshot.reads.map(({ returnData, ...read }) => read), unavailable: snapshot.unavailable }, null, 2));
    else console.log(canonicalJSON({ status: "PASS", mode: "offline", block: snapshot.block, readCount: snapshot.reads.length }));
  } else if ((command === "capture" && args.length === 3) || (command === "readback" && args.length === 2)) {
    if (!process.env.STREAM_RPC_URL) throw Error("Set STREAM_RPC_URL privately");
    provider = new JsonRpcProvider(process.env.STREAM_RPC_URL);
    const client = new StreamClient(provider, stackConfigFromJSON(await loadJSON(args[0])));
    if (command === "readback") {
      const files = await loadPackage(resolve(args[1]));
      await verifySnapshotReadback(client, files);
      console.log(canonicalJSON({ status: "PASS", mode: "pinned-chain-readback" }));
    } else {
      const destination = resolve(args[2]);
      try { await lstat(destination); throw Error("Snapshot output already exists; choose a new directory"); }
      catch (error) { if (error.code !== "ENOENT") throw error; }
      const snapshot = await captureSupportedState(client, snapshotSelectionFromJSON(await loadJSON(args[1])));
      const files = packageSnapshot(snapshot);
      verifySnapshotPackage(files);
      await mkdir(dirname(destination), { recursive: true });
      const staging = await mkdtemp(join(dirname(destination), ".stream-snapshot-"));
      try {
        for (const [name, content] of Object.entries(files)) await writeFile(join(staging, name + ".json"), content, { encoding: "utf8", flag: "wx" });
        // Recheck destination after network reads; never overwrite an existing snapshot directory.
        try { await lstat(destination); throw Error("Snapshot output appeared during capture"); }
        catch (error) { if (error.code !== "ENOENT") throw error; }
        await rename(staging, destination);
      } catch (error) { await rm(staging, { recursive: true, force: true }); throw error; }
      console.log(canonicalJSON({ status: "PASS", mode: "capture", block: snapshot.block, readCount: snapshot.reads.length, publication: JSON.parse(files.publication) }));
    }
  } else throw Error(usage);
} catch (error) {
  // An RPC transport exception may include its credentialed URL; keep it out of console/logs.
  console.error(provider && !(error instanceof SnapshotReadError) ? "Snapshot operation failed; no capture was published. Check selection, canonical block, supported getters and RPC connectivity." : error.message);
  process.exitCode = 1;
} finally { provider?.destroy(); }
