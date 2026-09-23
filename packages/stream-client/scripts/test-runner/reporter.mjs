// A second native Node reporter; the ordinary TAP reporter remains the full log.
export default async function* report(events) {
  for await (const event of events) {
    if (event.type !== 'test:pass' && event.type !== 'test:fail') continue;
    const { name, nesting, skip, todo, details } = event.data;
    yield JSON.stringify({ name, nesting, status: event.type === 'test:pass' ? 'pass' : 'fail',
      skip: Boolean(skip), todo: Boolean(todo), durationMs: details?.duration_ms ?? null,
      error: details?.error ? String(details.error.stack || details.error.message || details.error) : null }) + '\n';
  }
}
