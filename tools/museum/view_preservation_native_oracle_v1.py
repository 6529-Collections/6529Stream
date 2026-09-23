"""Read-only bridge from two frozen native traces to preservation wire codecs."""
import argparse
from pathlib import Path
import sys

from . import view_preservation_checkpoint_oracle_v1 as checkpoint
from . import view_preservation_manifest_oracle_v1 as manifest
from .canonical import MuseumError, dumps
from .independent_wire import require

FIXTURES = Path(__file__).with_name('fixtures')


def verify(trace_directory=None):
    reports = {}
    for name, module in (('checkpoint', checkpoint), ('manifest', manifest)):
        vector = (FIXTURES / ('view-preservation-native-' + name + '-v1.json')).read_bytes()
        if trace_directory is None:
            reports[name] = module.verify_vector(vector)
        else:
            path = Path(trace_directory) / (name + '.log')
            require(path.stat().st_size <= module.MAX_TRACE, 'native oracle external trace byte bound')
            raw = path.read_bytes()
            require(module.extract_trace(raw) == vector, 'native oracle committed vector differs from trace')
            reports[name] = module.verify_trace(raw)
    return {'format': 'STREAM_VIEW_PRESERVATION_NATIVE_ORACLE_V1',
        'nativeSource': checkpoint.NATIVE_REVISION, 'consumerSource': checkpoint.CONSUMER_REVISION,
        'mode': 'authenticated_traces' if trace_directory is not None else 'supplied_vectors',
        'checkpoint': reports['checkpoint'], 'manifest': reports['manifest'],
        'qualification': 'Two separate component cases, not one joined protocol capture. '
            'The manifest case uses its own typed checkpoint; its roots are not the checkpoint case roots. '
            '7701 native Registry predates e8 preservation registration. No e8 Registry ceremony, '
            'snapshot, Router root, governance, finality or complete acquisition is verified.'}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--vectors', action='store_true', help='check committed extracted vector consistency only')
    mode.add_argument('--trace-directory', type=Path, help='authenticate original checkpoint.log and manifest.log')
    args = parser.parse_args(argv)
    try:
        print(dumps(verify(args.trace_directory)).decode('utf-8'))
    except (MuseumError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
