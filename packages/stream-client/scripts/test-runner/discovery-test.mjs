// Registration metadata only: callbacks, suites and hooks are never invoked here.
const state = globalThis[Symbol.for('6529Stream.testDiscovery')];
if (!state) throw Error('Test discovery was not initialized');
function registration(kind, forced, ...args) {
  let name, options = {}, callback;
  for (const value of args) {
    if (typeof value === 'string' && name === undefined) name = value;
    else if (typeof value === 'function') callback = value;
    else if (value && typeof value === 'object') options = value;
  }
  name ??= callback?.name || '<anonymous>';
  if (!callback) throw Error('Test discovery requires an explicit callback');
  if (!name || /[\r\n\0]/.test(name)) throw Error('Unsupported test name');
  state.registrations.push({ name, kind, skip: Boolean(forced.skip ?? options.skip), todo: Boolean(forced.todo ?? options.todo), only: Boolean(forced.only ?? options.only) });
  if (kind === 'suite' || callback?.length || forced.only || options.only) state.wholeFile = true;
  return Promise.resolve();
}
function api(kind) {
  const fn = (...args) => registration(kind, {}, ...args);
  for (const option of ['skip', 'todo', 'only']) fn[option] = (...args) => registration(kind, { [option]: true }, ...args);
  return fn;
}
export const test = api('test');
export const it = test;
export const suite = api('suite');
export const describe = suite;
export const before = () => { state.wholeFile = true; };
export const after = before;
export const beforeEach = before;
export const afterEach = before;
Object.assign(test, { test, it, suite, describe, before, after, beforeEach, afterEach });
export default test;
