#!/usr/bin/env bash
# Contract tests for the tracked repository resource configuration and schema.

set -euo pipefail
cd "$(dirname "$0")/.."

python3 - <<'PY'
import json
from copy import deepcopy
from pathlib import Path

try:
    from jsonschema import Draft7Validator, FormatChecker
except ImportError as error:
    raise SystemExit('error: install the jsonschema package to run this check') from error

schema = json.loads(Path('schemas/ai-rules.schema.json').read_text())
Draft7Validator.check_schema(schema)
validator = Draft7Validator(schema, format_checker=FormatChecker())

estimated = {
    'schemaVersion': 1,
    'resources': {
        'memory': {
            'reserveMiBPerActiveWorktree': 1024,
            'basis': 'estimated',
            'estimateReason': 'Allowance until a representative run is measured',
        }
    },
}
measured = {
    'schemaVersion': 1,
    'resources': {
        'memory': {
            'reserveMiBPerActiveWorktree': 6144,
            'basis': 'measured',
            'observedPeakMiB': 4999,
            'measurement': {
                'workload': 'scoped mutation run',
                'date': '2026-09-29',
                'evidence': 'path to retained run receipt',
                'completedRunDurationsSeconds': [735],
            },
        }
    },
}

def check(label, value, valid):
    errors = list(validator.iter_errors(value))
    if valid and errors:
        raise AssertionError(f'{label}: {"; ".join(error.message for error in errors)}')
    if not valid and not errors:
        raise AssertionError(f'{label}: accepted unexpectedly')
    print(f'  ok   {label}')

def with_memory(source, **changes):
    updated = deepcopy(source)
    updated['resources']['memory'].update(changes)
    return updated

with_unknown_category = deepcopy(estimated)
with_unknown_category['resources']['cpu'] = {}

check('tracked sample', json.loads(Path('.ai-rules.json').read_text()), True)
check('estimated memory', estimated, True)
check('measured memory', measured, True)
check('empty resources rejected', {'schemaVersion': 1, 'resources': {}}, False)
check('unknown-only resources rejected', {'schemaVersion': 1, 'resources': {'cpu': {}}}, False)
check('unknown category rejected in version 1', with_unknown_category, False)
check('nonpositive reservation rejected', with_memory(estimated, reserveMiBPerActiveWorktree=0), False)
check('measured record needs evidence', with_memory(measured, measurement={}), False)
version_two = deepcopy(estimated)
version_two['schemaVersion'] = 2
version_two['resources']['disk'] = {'workloads': {'checks': {'reserveMiB': 512, 'outputGrowthMiB': 64, 'tempGrowthMiB': 256, 'retainedBudgetMiB': 64, 'basis': 'estimated', 'estimateReason': 'Fixture allowance'}}}
check('version two disk budget', version_two, True)
legacy_disk = deepcopy(version_two)
legacy_disk['schemaVersion'] = 1
check('version one rejects disk category', legacy_disk, False)
missing_growth = deepcopy(version_two)
del missing_growth['resources']['disk']['workloads']['checks']['tempGrowthMiB']
check('disk budget needs separate temp growth', missing_growth, False)
negative_growth = deepcopy(version_two)
negative_growth['resources']['disk']['workloads']['checks']['outputGrowthMiB'] = -1
check('negative disk growth rejected', negative_growth, False)
check('version two requires disk budget', dict(estimated, schemaVersion=2), False)
print('repository resource configuration contract passed')
PY
