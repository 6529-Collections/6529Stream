import { register } from 'node:module';
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import ts from 'typescript';

const [file, output] = process.argv.slice(2);
if (!file || !output) throw Error('Usage: discover.mjs TEST_FILE OUTPUT_JSON');
const target = pathToFileURL(resolve(file)).href;
const state = { registrations: [], wholeFile: false };
globalThis[Symbol.for('6529Stream.testDiscovery')] = state;

// Keep complex registration structures together. Splitting is an optimization;
// conservative fallback executes the original complete file without name filters.
const source = ts.createSourceFile(file, readFileSync(file, 'utf8'), ts.ScriptTarget.Latest, true, ts.ScriptKind.JS);
const bindings = new Set();
for (const node of source.statements) if (ts.isImportDeclaration(node) && node.moduleSpecifier.text === 'node:test') {
  if (node.importClause?.name) bindings.add(node.importClause.name.text);
  if (node.importClause?.namedBindings) {
    if (ts.isNamespaceImport(node.importClause.namedBindings)) state.wholeFile = true;
    else for (const name of node.importClause.namedBindings.elements) bindings.add(name.name.text);
  }
}
function inspect(node, inFunction = false) {
  const nested = inFunction || ts.isFunctionLike(node);
  if (ts.isCallExpression(node) && inFunction && ts.isIdentifier(node.expression) && bindings.has(node.expression.text)) state.wholeFile = true;
  ts.forEachChild(node, child => inspect(child, nested));
}
inspect(source);
register(new URL('./discovery-loader.mjs', import.meta.url), { data: { target } });
await import(target);
if (!state.registrations.length) throw Error(`No top-level test registrations in ${file}`);
writeFileSync(output, JSON.stringify(state) + '\n', 'utf8');
