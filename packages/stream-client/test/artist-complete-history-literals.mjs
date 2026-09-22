import { readFileSync } from 'node:fs';
import ts from 'typescript';

/** Read only ABI literals, without executing production code or normalizers. */
export function literalReader(url, cache = new Map()) {
  if (cache.has(url.href)) return cache.get(url.href);
  const source = ts.createSourceFile(url.href, readFileSync(url, 'utf8'), ts.ScriptTarget.Latest, true);
  const declarations = new Map(), imported = new Map(), namespaces = new Map();
  const target = specifier => new URL(specifier.replace(/\.js$/, '.ts'), url);
  const read = name => {
    if (imported.has(name)) {
      const entry = imported.get(name); return literalReader(entry.url, cache)(entry.name);
    }
    return value(declarations.get(name));
  };
  cache.set(url.href, read);
  for (const statement of source.statements) {
    if (ts.isVariableStatement(statement)) for (const row of statement.declarationList.declarations) {
      if (ts.isIdentifier(row.name)) declarations.set(row.name.text, row.initializer);
    }
    if (ts.isExportDeclaration(statement) && statement.moduleSpecifier && statement.exportClause && ts.isNamedExports(statement.exportClause)) {
      for (const row of statement.exportClause.elements) imported.set(row.name.text, { url: target(statement.moduleSpecifier.text), name: row.propertyName?.text ?? row.name.text });
    }
    if (ts.isImportDeclaration(statement) && statement.moduleSpecifier.text.startsWith('.')) {
      const bindings = statement.importClause?.namedBindings, child = target(statement.moduleSpecifier.text);
      if (bindings && ts.isNamespaceImport(bindings)) namespaces.set(bindings.name.text, child);
      else if (bindings && ts.isNamedImports(bindings)) for (const row of bindings.elements) {
        imported.set(row.name.text, { url: child, name: row.propertyName?.text ?? row.name.text });
      }
    }
  }
  function value(node) {
    if (!node) throw Error(`Missing literal in ${url.pathname}`);
    if (ts.isAsExpression(node) || ts.isSatisfiesExpression(node) || ts.isParenthesizedExpression(node)) return value(node.expression);
    if (ts.isStringLiteral(node) || ts.isNoSubstitutionTemplateLiteral(node)) return node.text;
    if (ts.isIdentifier(node)) return read(node.text);
    if (ts.isTemplateExpression(node)) return node.head.text + node.templateSpans.map(span => value(span.expression) + span.literal.text).join('');
    if (ts.isArrayLiteralExpression(node)) return node.elements.flatMap(row => ts.isSpreadElement(row) ? value(row.expression) : [value(row)]);
    if (ts.isObjectLiteralExpression(node)) return Object.fromEntries(node.properties.map(row => {
      if (!ts.isPropertyAssignment(row)) throw Error('Nonliteral ABI property');
      return [row.name.text, value(row.initializer)];
    }));
    if (ts.isPropertyAccessExpression(node) && ts.isIdentifier(node.expression) && namespaces.has(node.expression.text)) {
      return literalReader(namespaces.get(node.expression.text), cache)(node.name.text);
    }
    if (ts.isPropertyAccessExpression(node)) return value(node.expression)[node.name.text];
    if (ts.isElementAccessExpression(node)) return value(node.expression)[value(node.argumentExpression)];
    if (ts.isBinaryExpression(node) && node.operatorToken.kind === ts.SyntaxKind.PlusToken) {
      const left = value(node.left), right = value(node.right);
      if (typeof left !== 'string' || typeof right !== 'string') throw Error('Non-string ABI concatenation');
      return left + right;
    }
    if (ts.isNewExpression(node) && node.expression.getText(source) === 'Interface') return value(node.arguments[0]);
    if (ts.isCallExpression(node) && node.expression.getText(source) === 'Object.freeze') return value(node.arguments[0]);
    throw Error(`Nonliteral ABI expression: ${node.getText(source)}`);
  }
  return read;
}
