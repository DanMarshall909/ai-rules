# JavaScript and TypeScript Environment Module

Use this module when changed production areas are built or tested through a
JavaScript package manager.

## Detect and resolve the environment

Inspect `package.json`, the committed lockfile, workspace configuration,
runtime/version files, TypeScript configuration, test and coverage config,
Stryker config, repository scripts, hooks, and CI. Use the package manager named
by `packageManager` or implied by the lockfile. Do not run a command that may
download a missing package without authorization.

Use repository scripts as the canonical interface. `src/`, `lib/`, tests,
fixtures, generated output, browser bundles, server packages, and workspaces may
have different production boundaries; derive them from package configuration
and project instructions.

## Tests and coverage

Use the configured runner—commonly Jest, Vitest, Mocha, Jasmine, Karma,
CucumberJS, Tap, or a project wrapper—and its supported exact-test filtering.
Record the package/workspace, config, environment, test identity, and machine-
readable result. Widen from the owning test or package to the workspace's fast
suite and then its complete CI-equivalent suite.

Use the configured coverage provider and report format. Istanbul-compatible
coverage is common but not universal. Attribute coverage to the owning package
and include relevant browser or server execution when production behaviour
depends on it. Snapshot files, transforms, loaders, generated sources, and
source maps can invalidate naive line-level conclusions.

## StrykerJS

Prefer a checked-in `@stryker-mutator/core` development dependency, versioned
configuration, and package script. With the dependency already installed, the
official direct form is:

```text
npx stryker run
```

Use the repository's package-manager script or exec form instead when provided.

For fast iteration, current StrykerJS supports:

```text
npx stryker run --incremental
```

Incremental mode stores prior results in an incremental report (by default
`reports/stryker-incremental.json`), reruns affected mutants, and still produces
a full mutation report. Unlike Stryker.NET `--since`, it is report-reuse rather
than a changed-subset-only score.

Incremental correctness depends on the runner's ability to report test files and
locations. Jest, Vitest, and CucumberJS currently provide full location support;
other runners may provide only file names, test names, or no mapping. StrykerJS
also cannot automatically detect every dependency, environment, configuration,
snapshot, or generated-file change. Invalidate or force results when those
inputs could affect a mutant.

To force selected mutants while retaining the incremental report, current
StrykerJS supports a combination such as:

```text
npx stryker run --incremental --force --mutate <pattern>
```

Before completion review, run the project-approved full mutation command without
incremental reuse, unless the repository has separately validated an
authoritative baseline protocol. Retain the JSON report and inspect killed,
survived, timeout, no-coverage, ignored, and error buckets. Verify that the
configured runner discovered the intended tests and that attribution is real.

Calibrate the harness by applying one representative fault, proving the source
actually changed, and watching a named test reject it. Restore the source and
verify the diff afterward. Be alert for module caches, shared fixtures, hot
reload, browser state, or memoized outputs that prevent the mutated code from
being re-driven.

Official references:

- <https://stryker-mutator.io/docs/stryker-js/incremental/>
- <https://stryker-mutator.io/docs/stryker-js/configuration/>

## Completion evidence

Retain the runtime and package-manager versions, lockfile identity, build and
typecheck results, exact package/test commands, machine-readable test and
coverage output, Stryker configuration and reports, incremental invalidation
decision, and relevant browser/server evidence. Thresholds and exclusions are
project policy; do not invent or lower them in this module.
