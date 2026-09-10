import test from "node:test";
import assert from "node:assert/strict";
import { mkdtemp, mkdir, readFile, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { render, targets } from "../scripts/generate.mjs";

test("projection is deterministic and rejects changed artifacts or compiler input", async () => {
  const first = await render(), second = await render();
  assert.deepEqual(first, second);
  const temp = await mkdtemp(join(tmpdir(), "stream-client-export-"));
  try {
    await mkdir(join(temp, "artifacts"));
    const source = new URL("../../../release-artifacts/current/", import.meta.url);
    const files = ["manifest.json", "compiler-input.json", ...Object.values(targets).map(x => `artifacts/${x}.json`)];
    for (const file of files) await writeFile(join(temp, file), await readFile(new URL(file, source)));
    assert.deepEqual(await render(temp), first);
    const path = join(temp, "artifacts/StreamCore.json"), bytes = await readFile(path);
    await writeFile(path, Buffer.concat([bytes, Buffer.from("\n")]));
    await assert.rejects(render(temp), /artifact digest/);
    await writeFile(path, bytes);
    await writeFile(join(temp, "compiler-input.json"), "{}");
    await assert.rejects(render(temp), /Compiler input digest/);
  } finally { await rm(temp, { recursive: true, force: true }); }
});
