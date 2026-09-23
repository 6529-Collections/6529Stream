# Current-stack operational observations

`python -m tools.operations.current_health` collects one read-only observation
of an explicitly pinned deployment block and reproduces its report offline.
See the [operator guide](../../docs/current-stack-monitoring.md) for inputs,
commands, coverage and limitations.

Run the offline regressions after installing the repository's existing
[Museum Python dependencies](../museum/requirements.txt):

```sh
python -m unittest tools.operations.test_current_health -v
```

The tests use transport doubles and a real genesis role profile. Their tiny
compiler/deployment fixtures are test data, not deployed-contract evidence.
Actual current-stack and testnet monitoring rehearsals remain pending.
