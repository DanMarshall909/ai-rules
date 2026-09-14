# Environment Modules

Read this index before choosing implementation-specific build, test, coverage,
or mutation commands. Then read every module matching the changed production
areas:

- [.NET](dotnet.md) — C#, F#, Visual Basic, `dotnet`, VSTest or Microsoft Test
  Platform, common coverage collectors, and Stryker.NET.
- [JavaScript and TypeScript](javascript-typescript.md) — package-manager
  scripts, Jest/Vitest and other runners, common coverage providers, and
  StrykerJS.

Do not load a module merely because the tool is installed globally. Select it
from repository evidence such as project files, manifests, lockfiles, checked-
in tool manifests, and the paths actually being changed. Polyglot work may need
multiple modules.

## Precedence

Use instructions in this order:

1. repository-local instructions and canonical wrapper scripts;
2. repository-local environment modules or skills;
3. these portable modules;
4. official documentation for the exact installed version.

A portable module supplies safe defaults and questions to resolve. It never
authorizes installing a dependency, bypassing a project driver, changing a
threshold, uploading reports, or introducing a hosted service.

## Module contract

Every environment module should define:

- **Detection:** files and configuration proving the module applies.
- **Version resolution:** how to identify the actual SDK, runtime, package
  manager, test runner, coverage collector, and mutation tool versions.
- **Production boundary:** which paths are authoritative production code and
  which remain generated, vendored, experimental, or utility code.
- **Canonical driver:** the project command or wrapper agents must use instead
  of invoking an underlying runner directly.
- **Test identity and layers:** how to name exact tests and widen from owning
  tests through unit, integration, acceptance, and full-suite gates.
- **Coverage:** command, report format, owning package or assembly, exclusions,
  and the distinction between execution and checked behaviour.
- **Mutation:** normal command, fast iteration mode, full completion mode,
  result format, baseline storage, invalidation rules, and calibration method.
- **Build and static gates:** compile, typecheck, lint, formatting,
  architecture, generated-data, and packaging checks that apply.
- **Evidence:** durable logs and machine-readable artifacts needed for review.
- **CI and hooks:** where the same boundaries are enforced automatically.
- **Exceptions:** unsupported runner features, generated code, external-system
  boundaries, and conditions that require a project decision.

## Adding another module

Add a module only after inspecting a real repository and the official tooling
for its installed version. Keep workflow invariants in the parent skill; put
only environment-specific detection, commands, artifacts, and limitations in
the module.

Prefer a project-local module when conventions vary substantially across
repositories. Promote guidance here only when it is transferable, non-obvious,
and supported by more than one use or a high-consequence failure.
