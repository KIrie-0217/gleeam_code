# gleeam_code

> A Gleam CLI tool for solving LeetCode problems.
> Write solutions in Gleam, auto-compile to Erlang, and submit to LeetCode.

## Specification

See [docs/dev/spec.md](docs/dev/spec.md) for the full specification including:
- Command details (auth, fetch, test, submit)
- LeetCode API integration
- Erlang conversion strategy
- Type mapping and phased implementation plan

## Gleam Knowledge Base

This project includes a Gleam LLM Wiki as a submodule:

- Location: `docs/gleam-wiki/`
- Entry point: `docs/gleam-wiki/AGENTS.md`
- Wiki pages: `docs/gleam-wiki/wiki/`

When writing or reviewing Gleam code, consult the wiki for language rules,
conventions, and anti-patterns. Read `docs/gleam-wiki/wiki/index.md` to find
relevant pages.

### When to consult the wiki

Read the relevant wiki pages **before** writing code, not after encountering
problems. In particular:

- Before writing any FFI code, read `wiki/conventions/anti-patterns.md` and
  `wiki/reference/ffi-guide.md`
- Before designing module APIs, read `wiki/conventions/coding-patterns.md`
- Before using external types, read `wiki/concepts/externals.md`

## Project Overview

- CLI command: `glc`
- Package name: `gleeam_code`
- Language: Gleam (compiles to Erlang/BEAM)
- Purpose: fetch, test, and submit LeetCode solutions written in Gleam

### Key workflow

```
glc init                        # Initialize project (requires gleam.toml)
glc auth                        # Save LeetCode session cookie
glc fetch <slug-or-number>      # Fetch problem + generate Gleam template
glc test <slug-or-number>       # Build + run local tests with sample cases
glc submit <slug-or-number>     # Build + convert to Erlang + submit to LeetCode
```

### Erlang conversion strategy

Gleam source is compiled via `gleam build --target erlang`, then the generated
`.erl` file is post-processed to match LeetCode's expected Erlang format:
- Strip `-module`, `-export`, `-compile`, `-define`, `-file` directives
- Extract the target function's `-spec` and body
- LeetCode adds `-module(solution)` and `-export` automatically

## Development Guidelines

### Development flow

For each module: write implementation → write tests → pass tests → move on.
Do not create multiple modules before testing any of them.

### Erlang FFI

When writing `@external` bindings to Erlang functions:

1. Check the function's return type in the
   [Erlang official documentation](https://www.erlang.org/doc/apps/kernel/).
   Many Erlang functions return bare `ok` (an atom), not `{ok, Value}` (a tuple).
   Gleam's `Result` type maps to `{ok, V} | {error, E}`, so bare `ok` requires
   an Erlang FFI wrapper that converts `ok` to `{ok, nil}`.
2. Verify actual return values by running `erl -noshell -eval '...'` before
   writing the binding.
3. Place Erlang FFI files in `src/` with the naming convention
   `<module_path>_ffi.erl` (e.g., `gleeam_code_file_ffi.erl`).

### Dependency evaluation

Before adding a third-party dependency, evaluate it with this checklist:

1. **Source**: Is it from the `gleam-lang` org or the Gleam author (lpil)?
   Prefer official packages.
2. **License**: Check `gleam.toml` in the repo and hex.pm. A missing LICENSE
   file in the GitHub repo does not mean unlicensed — check hex.pm metadata.
3. **Maintenance**: Check open issues, PRs, and last release date on GitHub.
4. **Dependants**: Check hex.pm dependants count for ecosystem adoption.
5. **Self-implementation cost**: Estimate how many lines of code a self-
   implementation would require. If the needed functionality is small and the
   Erlang stdlib provides the primitives, prefer a thin FFI wrapper.
6. **Clean room**: If you have read a library's source code, do not copy from
   it. Implement from the Erlang official documentation and first principles.

### Improving this document

This AGENTS.md is a living document. When development encounters rework,
wrong assumptions, or avoidable mistakes:

1. Identify the root cause — what information or process was missing?
2. Add a guideline that describes **how to check**, not what the answer is.
   Facts become stale; processes remain useful.
3. Reference this improvement cycle in commit messages so the rationale is
   traceable.
