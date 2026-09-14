# .NET Environment Module

Use this module when changed production areas are built by the .NET SDK.

## Detect and resolve the environment

Inspect `global.json`, `*.sln` or `*.slnx`, `*.csproj`, central package files,
`dotnet-tools.json`, test project references, coverage configuration, Stryker
configuration, repository scripts, hooks, and CI. Resolve the pinned SDK and
local tools before running commands. Do not replace a repository wrapper with
raw `dotnet test` or `dotnet stryker`.

Treat the repository's architectural production path as the promotion boundary.
Typical `src/` and `tests/` names are clues, not universal rules. Generated,
vendored, prototype, migration, and tool projects follow the repository's own
classification.

## Tests and coverage

Prefer the checked-in wrapper or package-specific script. If none exists,
derive commands from the solution and test projects rather than guessing a
framework. VSTest, Microsoft Test Platform, xUnit, NUnit, MSTest, TUnit,
Coverlet, and built-in coverage have different filtering and artifact details.

Record exact test identities and retain TRX or the project's equivalent
machine-readable result. Widen from the owning test project to the fast unit
selection, then the complete solution. Collect coverage for the production
assembly that owns the changed behaviour; a solution-wide aggregate can hide
which project was actually exercised.

## Stryker.NET

Prefer a checked-in local tool manifest and versioned `stryker-config.json` or
YAML configuration. The official basic invocation runs from a test project:

```text
dotnet stryker
```

Use the repository wrapper when it has one, especially when multiple production
assemblies need distinct test projects or configurations.

For fast iteration, current Stryker.NET supports:

```text
dotnet stryker --since:<accepted-base-committish>
```

This reports only mutants in code considered changed since the target. It is a
changed-subset result, not a full-project mutation score. Changes in test project
files may expand the affected mutant set; ignored files can make the result less
accurate. Use an explicit accepted base and inspect whether any mutants were
actually tested.

Stryker.NET also has experimental baseline reuse:

```text
dotnet stryker --with-baseline:<accepted-base-committish>
```

It reuses saved results for unaffected mutants and returns a full report.
`with-baseline` and `since` are mutually exclusive, and baseline identity and
storage must be proven before reuse is accepted. The default provider is local
disk; Dashboard, Azure, and S3 providers introduce credentials, privacy, cost,
and lifecycle decisions requiring project authority.

Before completion review, run the project's unfiltered configured mutation
command once for every eligible changed production assembly. Retain JSON or
another machine-readable report and inspect survivor, timeout, no-coverage, and
test-attribution details—not just the headline score.

Calibrate the harness by applying one representative fault, proving it reached
the intended source, and watching the named test reject it. Restore the source
and verify the diff afterward. Confirm both that configured tests were
discovered and that the tests used as evidence actually cover or kill relevant
mutants.

Official reference: <https://stryker-mutator.io/docs/stryker-net/configuration/>.

## Completion evidence

Retain the resolved SDK/tool versions, build result, exact targeted and full test
commands, machine-readable test results, owning coverage reports, Stryker
configuration and reports, and any discrepancy between terminal and report
totals. Thresholds and exclusions are project policy; do not invent or lower
them in this module.
