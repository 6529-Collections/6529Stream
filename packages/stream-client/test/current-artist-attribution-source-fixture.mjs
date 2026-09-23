import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { fixture } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";

// The compiler capture remains bd4. This separate bridge pins original operation
// producers at c715 and explicitly records changed recovery/hydration dependencies.
export { fixture, compiledABI, compiledInterfaces, compiledLibraryEvents, libraryValueABI, compiledLibraryValueInterface } from "./current-artist-recovered-multiple-attestation-hydration-source-fixture.mjs";
export const attributionSourceProfile = JSON.parse(readFileSync(new URL("./fixtures/current-artist-attribution-source-profile.json", import.meta.url), "utf8"));
export function attributionSource(path) {
  const row = attributionSourceProfile.sources[path];
  const text = attributionSourceProfile.sourceOverrides[path] ?? fixture.sourceTexts[path];
  if (!row || typeof text !== "string" || createHash("sha256").update(text).digest("hex") !== row.sha256) throw Error(`Missing or inconsistent current source: ${path}`);
  return text;
}
