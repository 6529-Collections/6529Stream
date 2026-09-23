"""Explicit native-capture format dispatch; never infer provenance from filenames."""
from pathlib import Path


def validate_capture_options(kind: str, provenance: Path | None, admission: Path | None):
    if kind not in ('scoped-paired', 'partition-native'):
        raise ValueError('Unknown native capture kind')
    if kind == 'partition-native':
        if provenance is None or admission is not None:
            raise ValueError('Partition capture requires provenance and forbids compiler admission')
    elif provenance is not None:
        raise ValueError('Partition provenance requires partition-native capture kind')


def native_filenames(kind: str) -> tuple[str, str]:
    if kind == 'scoped-paired':
        return 'codegen-input.json', 'codegen-output.json'
    if kind == 'partition-native':
        return 'input.json', 'output.json'
    raise ValueError('Unknown native capture kind')


def bind_native_capture(build: dict, folder: Path, *, kind: str = 'scoped-paired',
                        provenance: Path | None = None, admission: Path | None = None):
    validate_capture_options(kind, provenance, admission)
    if kind == 'partition-native':
        from tools.build.partition_native_capture import bind_partition_build_capture
        return bind_partition_build_capture(build, folder, provenance=provenance)
    from tools.build.scoped_standard_json import bind_build_capture
    return bind_build_capture(build, folder, admission=admission)
