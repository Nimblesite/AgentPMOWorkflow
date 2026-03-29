# {{REPO_NAME}} — Claude Instructions

> Read this entire file before writing any code.
> These rules are NON-NEGOTIABLE. Violations will be rejected in review.

## Project Overview

{{One paragraph describing what this repo is and does.}}

**Primary language(s):** {{languages}}
**Build command:** `make ci`
**Test command:** `make test`
**Lint command:** `make lint`

## Too Many Cooks (Multi-Agent Coordination)

If the TMC server is available:
1. Register immediately: descriptive name, intent, files you will touch
2. Before editing any file: lock it via TMC
3. Broadcast your plan before starting work
4. Check messages every few minutes
5. Release locks immediately when done
6. Never edit a locked file — wait or find another approach

## Hard Rules — Universal (no exceptions)

- **DO NOT use git commands.** No `git add`, `git commit`, `git push`, `git checkout`, `git merge`, `git rebase`, or any other git command. CI and GitHub Actions handle git.
- **ZERO DUPLICATION.** Before writing any code, search the codebase for existing implementations. Move code, don't copy it.
- **NO THROWING EXCEPTIONS.** Return `Result<T,E>`, `Option<T>`, or the language equivalent. Exceptions are only for unrecoverable bugs (panic-level).
- **NO REGEX on structured data.** Never parse JSON, YAML, TOML, code, or any structured format with regex. Use proper parsers, AST tools, or library functions.
- **NO PLACEHOLDERS.** If something isn't implemented, leave a loud compilation error (`todo!()`, `raise NotImplementedError`, `failwith "TODO"`). Never write code that silently does nothing.
- **Functions < 20 lines.** Refactor aggressively. If a function exceeds 20 lines, split it.
- **Files < 500 lines.** If a file exceeds 500 lines, extract modules.
- **100% test coverage is the goal.** Never delete or skip tests. Never remove assertions.
- **Prefer E2E/integration tests.** Unit tests are acceptable only for pure transformation functions.
- **Heavy logging everywhere.** See Logging Standards section below.
- **No suppressing linter warnings.** Fix the code, not the linter.
- **Pure functions** over statements

## Logging Standards

- **Use a structured logging library.** Never use `print`, `console.log`, `println!`, or `Debug.WriteLine` for diagnostics. Use a proper structured logging library appropriate to the language (see table below).
- **Log at entry/exit of all significant operations.** Use appropriate levels: `error`, `warn`, `info`, `debug`, `trace`.
- **Logging must be throughout the app.** Every service, handler, and non-trivial operation should log. Silent failures are forbidden.
- **VS Code extensions:** Write detailed logs to a file in the extension's state folder (`.vsixname/` in the workspace root). Basic errors and diagnostics MUST also appear in the extension's VS Code Output Channel so users can see them without hunting for files.
- **SaaS / server apps:** Log to the database for persistence and queryability. Log calls that write to the database or file MUST be async or run on a background thread — never block the request path with I/O logging.
- **NEVER log personal data.** No names, emails, addresses, phone numbers, IP addresses (unless required for security audit with explicit consent), or any PII.
- **NEVER log secrets.** No API keys, tokens, passwords, connection strings, or credentials. If you need to confirm a key is loaded, log a truncated hash or just `"API key: present"`.
- **Structured fields over string interpolation.** Log `{ "userId": 42, "action": "checkout" }` not `"User 42 performed checkout"`. This enables filtering and aggregation.

### Logging Libraries by Language

| Language | Library | Notes |
|----------|---------|-------|
| Rust | `tracing` | With `tracing-subscriber` for output |
| TypeScript/Node | `pino` | JSON structured logging; use `pino-pretty` for dev |
| Python | `structlog` | Wraps stdlib `logging` with structured output |
| Dart/Flutter | `dart_logging` | Mandatory package (see Dart section) |
| C# | `Microsoft.Extensions.Logging` + `Serilog` | Serilog for structured sinks |
| F# | `Microsoft.Extensions.Logging` + `Serilog` | Same as C# |
| Go | `log/slog` | stdlib structured logging (Go 1.21+) |

## Hard Rules — Language-Specific

### Rust
- No `unwrap()` — use `?` or explicit `match`
- No `expect()` in production code (tests may use it)
- No `panic!()`, `todo!()`, `unimplemented!()`, `unreachable!()` in production code
- No `unsafe {}` blocks without documented justification reviewed by a human
- No `allow(clippy::...)` attributes without documented justification
- All public items must have doc comments (`///`)
- Use `thiserror` for error types; `anyhow` only in application code (not libraries)

### TypeScript
- No `any` — use `unknown` and narrow explicitly
- No `!` (non-null assertion) — use optional chaining or explicit guards
- No implicit `any` — all function parameters and return types must be annotated
- No `// @ts-ignore` or `// @ts-nocheck`
- No `as Type` casts without a comment explaining why it's safe
- Strict mode always on (`tsconfig.json` must have `"strict": true`)
- No throwing — return `Result<T, E>` using a Result type library or discriminated union

### Dart/Flutter
- No `late` keyword — it hides null-safety violations
- No `!` (bang operator) — use `?` and handle the null case
- No `dynamic` — use proper types or generics
- No `as Type` casts — use `is` checks and smart casts
- No `.then()` on futures — use `async`/`await`
- State management: SUDF (Single Unidirectional Data Flow) only (No Provider, Riverpod or Bloc)
- For complex interdependent reactive observability, use the Signals package
- Tests: write tests that double as integration tests AND widget tests. The test headers should point to shared test code. Follow [this guide](https://www.christianfindlay.com/blog/flutter-integration-tests). In widget testing mode, some tests should produce goldens, and you need to inject mocks for network calls etc.
- Only use unit tests for isolating issues.

#### Mandatory Packages
- **Logging**: [dart_logging](https://pub.dev/packages/dart_logging)
- **Linting**: [austerity](https://pub.dev/packages/austerity) configure it in the analysis options
- **Results/Monads**: [nadz package](https://pub.dev/packages/nadz) (Result<T,E>)
- **State Management**: [reflux](https://pub.dev/packages/reflux) or [ioc_container](https://pub.dev/packages/ioc_container)

### C# / F#
- No throwing exceptions — return `Result<T,E>` or `Option<T>`
- No `!` null-forgiving operator
- No `as` casts — use pattern matching
- No `dynamic`
- Nullable reference types enabled everywhere
- C#: records for immutable data
- F#: prefer discriminated unions, pipe operators, computation expressions
- Install common packages in the build props
- Avoid classes. Use static methods as pure functions

#### Mandatory Packages (C# Only)
- **Results/Monads**: [Outcome](https://www.nuget.org/packages/Outcome) (Result<T,E>) and the Exhaustion analyzer package that comes with it
- Always include these 3 in the Directory.Build.props
```xml
<ItemGroup>
    <!-- Microsoft .NET Analyzers -->
    <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="9.0.0">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
    </PackageReference>

    <!-- Result types for Railway Oriented Programming -->
    <PackageReference Include="Outcome" Version="1.0.0" />

    <!-- Exhaustive pattern matching analyzer -->
    <PackageReference Include="Exhaustion" Version="1.0.0">
        <PrivateAssets>all</PrivateAssets>
        <IncludeAssets>runtime; build; native; contentfiles; analyzers</IncludeAssets>
    </PackageReference>
</ItemGroup>
```

### Python
- No `Any` in type annotations — use specific types
- Type annotations on every function parameter and return type
- No bare `except:` — always catch specific exception types
- No global mutable state
- Use `Result[T, E]` pattern (returns tuple or custom type) — no raising

#### Mandatory Linting
- **Basilisk**: [Type Checker Configuration](https://basilisk-python.dev/docs/configuration/)

## Testing Rules

- **Never delete a failing test.** Fix the code or fix the test expectation — never delete.
- **Never skip a test** (`@pytest.mark.skip`, `xit`, `test.skip`, `#[ignore]`) without a ticket number and expiry date in the skip reason.
- **Assertions must be specific.** `assert True` or `assert.ok(true)` without a condition is illegal.
- **No try/catch in tests** that swallows the exception and asserts success.
- **Tests must be deterministic.** No sleep(), no relying on timing, no random state.
- **E2E tests: black-box only.** Only interact via public APIs, UI commands, or CLI. Never call internal methods or manipulate internal state from a test.
- **VSCode extension E2E:** interact only via `vscode.commands.executeCommand`. Never call provider methods directly.

## Skills

Follow these carefully

[https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)

[https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf)

# Website (If One Exists)

**Optimise for SEO and AI**: always pay attention to this then when writing content

[Top ways to ensure your content performs well in Google's AI experiences on Search](https://developers.google.com/search/blog/2025/05/succeeding-in-ai-search)

[Search Engine Optimization (SEO) Starter Guide](https://developers.google.com/search/docs/fundamentals/seo-starter-guide)

## Build Commands (exact — cross-platform via GNU Make)

All `make` targets work on Linux, macOS, and Windows. The Makefile uses OS detection to select portable commands. On Windows, install GNU Make via `choco install make` or use the one bundled with Git for Windows.

```bash
make build          # compile everything
make test           # run tests with coverage
make lint           # run all linters
make fmt            # format all code
make fmt-check      # check formatting (CI uses this)
make clean          # remove build artifacts
make check          # lint + test (pre-commit)
make ci             # lint + test + build (full CI simulation)
make coverage       # generate and open coverage report
make coverage-check # assert coverage thresholds
make website-build  # build the website/static site
make website-run    # run the website locally (dev server)
make setup          # post-create dev environment setup
```

## Architecture

```
{{repo_root}/
├── .claude/
│   └── skills/          # Claude skills (see §10)
├── .devcontainer/       # Dev container config
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   ├── release.yml
│   │   └── deploy-pages.yml  (if applicable)
│   └── pull_request_template.md
├── [...]                # Source code
├── .gitignore
├── CLAUDE.md
└── Makefile
```

{{Add repo-specific architecture notes below}}
