// This hook is used only while listing registrations. Test execution does not load it.
let target;
export function initialize(data) { target = data.target; }
export function resolve(specifier, context, nextResolve) {
  if (specifier === 'node:test' && context.parentURL !== target) throw Error('Test helpers importing node:test need explicit discovery support');
  if (specifier === 'node:test' && context.parentURL === target) {
    return { url: new URL('./discovery-test.mjs', import.meta.url).href, shortCircuit: true };
  }
  return nextResolve(specifier, context);
}
