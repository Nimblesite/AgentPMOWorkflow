# spec-check

> **Portable skill.** This skill adapts to the current repository. The agent MUST inspect the repo structure and use judgment to apply these instructions appropriately.

Audit spec/plan documents against the codebase. Ensures every spec section has implementing code, tests, and that the code logic matches the spec.

## Arguments

- `$ARGUMENTS` — optional spec name or ID to check (e.g., `SPEC-001` or `repo-standards`). If empty, check ALL specs.

## Instructions

Follow these steps exactly. Be strict and pedantic. Stop on the first failure.

---

### Step 1: Find all spec/plan documents

Search for markdown files that contain spec sections with IDs. Look in these locations:

- `docs/*.md`
- `docs/**/*.md`
- `SPEC.md`
- `PLAN.md`
- `specs/*.md`

Use Glob to find candidate files, then use Grep to confirm they contain spec IDs.

**Spec ID patterns** — IDs appear in square brackets, typically at the start of a heading or section line. Match this regex pattern:

```
\[([A-Z][A-Z0-9]*(-[A-Z0-9]+)*-\d+)\]
```

Examples of valid spec IDs:
- `[SPEC-001]`
- `[FEAT-AUTH-01]`
- `[REQ-003]`
- `[REPO-STD-001]`
- `[PMO-DASH-12]`
- `[CI-004]`

For each file, extract every spec ID and its associated section title (the heading text after the ID) and the full section content (everything until the next heading of equal or higher level).

---

### Step 2: Filter specs

- If `$ARGUMENTS` is non-empty, filter the discovered specs:
  - If it matches a spec ID exactly (e.g., `SPEC-001`), check only that spec.
  - If it matches a partial name (e.g., `repo-standards`), check all specs in files whose path contains that string.
- If `$ARGUMENTS` is empty, process ALL discovered specs.

If filtering produces zero specs, report an error:
```
ERROR: No specs found matching "$ARGUMENTS". Discovered spec files: [list them]
```

---

### Step 3: Check each spec section

For EACH spec section that has an ID, perform checks A, B, and C below. **Stop on the first failure.**

#### Check A: Code references the spec ID

Search the entire codebase for the spec ID string, **excluding** these directories:
- `docs/`
- `node_modules/`
- `.git/`
- `*.md` files (markdown is docs, not code)

Use Grep with the literal spec ID (e.g., `[SPEC-001]`) to find references in code files.

Code files should contain comments referencing the spec ID. The search must catch **all** comment styles across languages:

**C-style `//` comments** (JavaScript, TypeScript, Rust, C#, F#, Java, Kotlin, Go, Swift, Dart):
- `// Implements [SPEC-001]`
- `// [SPEC-001]`
- `// Tests [SPEC-001]` (also counts as a code reference)
- `/// Implements [SPEC-001]` (doc comments)

**Hash `#` comments** (Python, Ruby, Shell/Bash, YAML, TOML):
- `# Implements [SPEC-001]`
- `# [SPEC-001]`
- `# Tests [SPEC-001]`

**HTML/XML comments** (HTML, CSS, SVG, XML, XAML, JSX templates):
- `<!-- Implements [SPEC-001] -->`
- `<!-- [SPEC-001] -->`

**ML-style comments** (F#, OCaml):
- `(* Implements [SPEC-001] *)`

**Lua comments:**
- `-- Implements [SPEC-001]`

**CSS comments:**
- `/* Implements [SPEC-001] */`

**The key rule:** any comment in any language containing the exact spec ID string (e.g., `[SPEC-001]`) counts as a valid code reference. The Grep search uses the literal spec ID string, so it naturally matches all comment styles. Do NOT restrict the search to specific comment prefixes — just search for the spec ID string itself.

**If NO code files reference the spec ID:**

```
SPEC VIOLATION: [SPEC-001] "Section Title" has no implementing code.

Every spec section must have at least one code file that references it via a comment
containing the spec ID (e.g., `// Implements [SPEC-001]`).

ACTION REQUIRED: Add a comment referencing [SPEC-001] in the file(s) that implement
this spec section, then re-run spec-check.
```

**STOP HERE. Do not continue to other checks.**

#### Check B: Tests reference the spec ID

Search test files for the spec ID. Test files are found in:
- `test/`
- `tests/`
- `**/*.test.*`
- `**/*.spec.*`
- `**/*_test.*`
- `**/test_*.*`
- `**/*Tests.*`
- `**/*Test.*`

Use Grep to search these locations for the literal spec ID string.

Tests should contain the spec ID in comments, test names, or annotations. The search must catch **all** test frameworks across languages:

**JavaScript/TypeScript** (Jest, Mocha, Vitest, Playwright):
- `// Tests [SPEC-001]`
- `describe('[SPEC-001] Authentication flow', () => ...)`
- `test('[SPEC-001] should verify token', () => ...)`
- `it('[SPEC-001] verifies token', () => ...)`

**Python** (pytest, unittest):
- `# Tests [SPEC-001]`
- `def test_spec_001_authentication_flow():`
- `class TestSpec001AuthFlow:`

**Rust:**
- `// Tests [SPEC-001]`
- `#[test] // Tests [SPEC-001]`

**C#** (xUnit, NUnit, MSTest):
- `// Tests [SPEC-001]`
- `[Fact] // Tests [SPEC-001]`
- `[Test] // Tests [SPEC-001]`
- `[TestMethod] // Tests [SPEC-001]`

**F#** (xUnit, Expecto):
- `// Tests [SPEC-001]`
- `[<Fact>] // Tests [SPEC-001]`
- `testCase "[SPEC-001] description" <| fun () ->`

**Java/Kotlin** (JUnit, TestNG):
- `// Tests [SPEC-001]`
- `@Test // Tests [SPEC-001]`

**Go:**
- `// Tests [SPEC-001]`
- `func TestSpec001(t *testing.T) { // Tests [SPEC-001]`

**Swift** (XCTest):
- `// Tests [SPEC-001]`
- `func testSpec001() { // Tests [SPEC-001]`

**Dart** (flutter_test):
- `// Tests [SPEC-001]`
- `test('[SPEC-001] description', () { ... });`

**Ruby** (RSpec, Minitest):
- `# Tests [SPEC-001]`
- `describe '[SPEC-001] Authentication' do`
- `it '[SPEC-001] verifies token' do`

**Shell** (bats, shunit2):
- `# Tests [SPEC-001]`
- `@test "[SPEC-001] description" {`

**The key rule:** same as Check A — search for the literal spec ID string in test files. Any occurrence of the exact spec ID in a test file counts. Do NOT restrict to specific patterns — just search for the spec ID string itself.

**If NO test files reference the spec ID:**

```
SPEC VIOLATION: [SPEC-001] "Section Title" has no tests.

Every spec section must have corresponding tests that reference the spec ID.

ACTION REQUIRED: Add tests for [SPEC-001] with a comment or test name containing
the spec ID, then re-run spec-check.
```

**STOP HERE. Do not continue to other checks.**

#### Check C: Code logic matches the spec

This is the most critical check. You must:

1. **Read the spec section content carefully.** Understand exactly what behavior, logic, ordering, conditions, and constraints the spec describes.

2. **Read the implementing code.** Use the references found in Check A to locate the implementing files. Read the relevant functions/sections.

3. **Compare spec vs. code.** Be SENSITIVE and PEDANTIC. Check for:
   - **Ordering violations** — If the spec says A happens before B, the code must do A before B.
   - **Missing conditions** — If the spec says "only when X", the code must have that condition.
   - **Extra behavior** — If the code does something the spec doesn't mention, flag it only if it contradicts the spec.
   - **Wrong logic** — If the spec says "greater than" but code uses "greater than or equal", that's a violation.
   - **Missing steps** — If the spec describes 5 steps but code only implements 3, that's a violation.
   - **Wrong defaults** — If the spec says "default to X" but code defaults to Y, that's a violation.

4. **If the code deviates from the spec**, report a detailed error:

```
SPEC VIOLATION: [SPEC-001] Code does not match spec.

SPEC SAYS:
> "The authentication flow must verify the token expiry before checking permissions"
> (from docs/specs/AUTH-SPEC.md, line 42)

CODE DOES:
> `if (hasPermission(user)) { verifyToken(token); }` (src/auth.ts:42)

DEVIATION: The code checks permissions BEFORE verifying token expiry.
The spec explicitly requires token expiry verification FIRST.

ACTION REQUIRED: Reorder the logic in src/auth.ts to verify token expiry
before checking permissions, as specified in [SPEC-001].
```

**STOP HERE. Do not continue to other specs.**

5. **If the code matches the spec**, this check passes. Move to the next spec.

---

### Step 4: Report results

#### On failure (any check fails):

Output ONLY the first violation found. Use the exact error format shown above. Do not summarize other specs. Do not offer to fix the code. Just report the violation.

End with:
```
spec-check FAILED. Fix the violation above and re-run.
```

#### On success (all specs pass):

Output a summary table:

```
spec-check PASSED. All specs verified.

| Spec ID        | Title                    | Code References | Test References | Logic Match |
|----------------|--------------------------|-----------------|-----------------|-------------|
| [SPEC-001]     | Authentication flow      | src/auth.ts     | tests/auth.test.ts | PASS     |
| [SPEC-002]     | Rate limiting            | src/rate.ts     | tests/rate.test.ts | PASS     |
| ...            | ...                      | ...             | ...             | ...         |

Checked N spec sections across M files. All have implementing code, tests, and matching logic.
```

---

## Search strategy summary

1. **Find spec files:** Glob for `docs/**/*.md`, `SPEC.md`, `PLAN.md`, `specs/**/*.md`
2. **Extract spec IDs:** Grep for `\[[A-Z][A-Z0-9]*(-[A-Z0-9]+)*-\d+\]` in those files
3. **Find code refs:** Grep for the literal spec ID in all files, excluding `docs/`, `node_modules/`, `.git/`, `*.md`
4. **Find test refs:** Grep for the literal spec ID in test directories and test file patterns
5. **Read and compare:** Read the spec section content and the implementing code, compare logic

## Key principles

- **Fail fast.** Stop on the first violation. One fix at a time.
- **Be pedantic.** If the spec says it, the code must do it. No "close enough".
- **Quote everything.** Always quote the spec text and the code in error messages so the developer sees exactly what's wrong.
- **Be actionable.** Every error must tell the developer what file to change and what to do.
- **Exclude docs from code search.** Markdown files are documentation, not implementation. Only search actual code files for spec references.
