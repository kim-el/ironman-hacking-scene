# Verify — Verification Engineering Harness

Execute a 5-phase verification loop. Do not skip phases. Execute in order. Fix bugs found — do not just report them.

## Input

User provides a file or directory. Default to current working directory if not specified.

## Phase 0: Language Detection

1. Scan file extensions in target path
2. Map to framework:

| Extension | Language | Property Framework | Install |
|-----------|----------|-------------------|---------|
| `.rs` | Rust | `proptest = "1"` | add to Cargo.toml dev-deps |
| `.py` | Python | `hypothesis` | `pip install hypothesis` |
| `.ts`, `.tsx` | TypeScript | `fast-check` | `npm install --save-dev fast-check` |
| `.go` | Go | `rapid` | `go get pgregory.net/rapid` |

Process each language independently, aggregate at the end.

## Phase 1: Property-Based Tests

For each source file, generate a companion test file.

### Rust
- Create `<name>_proptest.rs` in same directory
- Add `#[cfg(test)] mod proptest_tests { use proptest::prelude::*; use super::*; ... }`
- For each public function: define invariants, generate random inputs with `proptest!`
- Common patterns: round-trip for parsers, commutativity for operations, idempotence for setters
- Always include edge case strategies: empty collections, max/min values, None variants

### Python
- Create `test_<name>.py`
- Use `from hypothesis import given, strategies as st`
- Decorate with `@given(...)` and `@settings(max_examples=200)`

### TypeScript
- Create `<name>.test.ts`
- Use `import fc from 'fast-check';`
- `fc.assert(fc.property(fc.integer(), ..., (x) => check(x)))`

### Go
- Create `<name>_test.go`
- Use `rapid.Check(t, func(t *rapid.T) { ... })`

**Minimum**: 3 distinct property categories per file. Do NOT write trivial tests that always pass.

## Phase 1.5: Interaction Matrix

Map the public API surface and test compositions.

### Step 1: Extract signatures
List every public function with its input types and return type. For each, note:
- Name, file:line
- Parameter types
- Return type (including Option/Result variants)
- Whether it mutates state (takes &mut self, writes to global, etc.)

### Step 2: Build compatibility pairs
For each pair of functions (A, B): could A's return type reasonably feed into B's first parameter?
- Exact match → automatically compatible
- A returns `Result<T, E>`, B takes `T` → compatible (unwrap on success path)
- A returns `Option<T>`, B takes `T` → compatible (test with Some variant)
- A returns `Vec<T>`, B takes `&[T]` → compatible
- No type relation → skip this pair

Do NOT test incompatible pairs — let the type system catch those.

### Step 3: Generate pipeline tests
For each compatible pair (A, B):
1. Generate random valid input for A
2. Call A with that input
3. If A succeeds, feed A's output directly to B
4. Verify: no panic, no hang, no undefined behavior
5. If the pipeline has a semantic invariant (e.g., "validate then execute should not crash"), assert it

For triples (A, B, C): sample randomly — test the 10 most likely chains, not all N³.

### Step 4: Sequence testing (stateful modules only)
If the module has a struct/class with methods that mutate state:
1. Generate 20 random sequences of method calls (length 3-8)
2. After each sequence, verify invariants hold
3. Test ordering dependencies: what if close() is called before open()? What if init() is skipped?

### Step 5: Shared state detection
If two functions access the same global, mutex, or file:
1. Generate interleaved call patterns
2. Verify no deadlocks, no data races, no corruption

**Cost estimate**: For a 20-function module, Phase 1.5 takes <10 seconds. Type filtering eliminates 70-80% of pairs. Random sampling keeps triples manageable.

## Phase 2: Test Execution + Fix Loop

Loop up to MAX_RETRIES=3:

1. **Run all tests** generated in Phases 1 and 1.5
   - Rust: `cargo test`
   - Python: `python -m pytest -v`
   - TypeScript: `npx vitest run` or `npx jest`
   - Go: `go test ./...`

2. **If PASS**: record and exit this phase.

3. **If FAIL**: Read the failure output carefully.
   - **Test bug** (test is wrong, assertion doesn't match reality): Fix the test. Increment `test_fixes`.
   - **Code bug** (test correctly reveals a real issue): Fix the source code. Increment `code_fixes`.
   - Document each fix: file:line, what was wrong, what was changed.
   - Re-run tests.

4. If MAX_RETRIES exhausted: record remaining failures and proceed to Phase 3. Do NOT exit early.

Track in a structured log:
```
Phase 2 Results:
- Iteration 1: FAIL — off-by-one in parse_line:87, fixed <= to <
- Iteration 2: PASS
- Fixes: 1 code, 0 test
```

## Phase 3: Adversarial Sub-Agent

Spawn a Verification agent. Prompt template (fill bracketed values):

```
You are an adversarial code verifier. Your mission is to BREAK this code.

Target: [absolute file path(s)]
Language: [language]
Existing tests: [list generated test files]

Look for bugs that property-based tests and interaction tests might miss:

1. EDGE CASES
   - Empty strings, nulls, undefined, NaN, Infinity, -0
   - Extremely large inputs (overflow, allocation exhaustion)
   - Unicode/special characters, binary data
   - Zero-length arrays, single-element collections

2. BOUNDARY CONDITIONS
   - Off-by-one in loops and indexing
   - Integer overflow/underflow (especially in release mode for Rust)
   - Floating point precision and comparison
   - Maximum recursion depth

3. CONCURRENCY (if applicable)
   - Shared state corruption under parallel access
   - Race conditions in async code
   - Lock ordering and deadlock potential

4. INJECTION AND INPUT VALIDATION
   - Can crafted input cause unintended behavior?
   - Path traversal, command injection, format string vulnerabilities
   - SQL/NoSQL injection if database access exists

5. ERROR HANDLING
   - Resource leaks on error paths (files, sockets, memory)
   - Unwrap/panic points — are they reachable from user input?
   - Error recovery — does the system end in a valid state after errors?

6. STATE MACHINE INVARIANTS
   - Find sequences of operations leading to invalid states
   - Test double-free, use-after-free, use-before-init patterns

For each bug found:
- Write a minimal reproducing test
- Fix the bug in the source code
- Document: severity (LOW/MEDIUM/HIGH/CRITICAL), file:line, description, reproduction steps, fix applied

If NO bugs found after thorough analysis: report NO_BUGS_FOUND.

Be thorough. The property tests already caught obvious issues. Your job is to find what they missed.
```

Use: `Agent(description="Adversarial verification", subagent_type="general-purpose", prompt="<the prompt above>")`

Wait for completion. Parse output for bug descriptions, fixes, and line numbers.

## Phase 4: Report

Output a structured report:

```
══════════════════════════════════════════
  VERIFICATION REPORT
══════════════════════════════════════════
Target:    [path]
Language:  [language]

── Phase 2: Property + Interaction Tests ──
Tests generated: [count files] ([count property groups])
Interaction pairs tested: [compatible pairs / total pairs]
Iterations:  [count]
  [1] FAIL — [description of failure and fix]
  [2] PASS
Code fixes: [count]
Test fixes: [count]
Status: PASS/FAIL

── Phase 3: Adversarial Analysis ──
Bugs found: [count]
  [1] MEDIUM — [file:line]
      Description: [what]
      Reproduction: [how to trigger]
      Fix: [what changed]
  [2] LOW — [file:line]
      ...
Status: [N bugs fixed / NO_BUGS_FOUND]

── Verdict: PASS / FAIL ──
[summary: what passed, what was fixed, what remains]
```

**PASS requires**: All property tests pass, all interaction tests pass, all adversarial bugs fixed, zero unfixed bugs remain.

## Key Rules

- Execute all 5 phases in order. Never skip.
- Fix bugs found — do not just report and move on.
- Max 3 retries in Phase 2. After that, record failures and continue to Phase 3.
- The adversarial agent gets full access: read any file, run commands, search web.
- Write all test files to disk before running them.
- Keep a running fix log. Every change documented.
- Install dependencies without asking (pip install, npm install, cargo add).
- If no public functions exist in the target, report and exit cleanly.
