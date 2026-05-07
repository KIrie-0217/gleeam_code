# gleeam_code

A Gleam CLI tool for solving LeetCode problems.
Write solutions in Gleam, compile to Erlang, and submit to LeetCode.

## Requirements

- [Gleam](https://gleam.run/) >= 1.0
- Erlang/OTP >= 26

## Setup

```sh
git clone --recurse-submodules https://github.com/KIrie-0217/gleeam_code.git
cd gleeam_code
gleam build
```

## Usage

```sh
# Initialize project (creates src/solutions/ and test/solutions/)
gleam run -- init

# Save your LeetCode session cookie
gleam run -- auth

# Fetch a problem (by slug or number)
gleam run -- fetch two-sum
gleam run -- fetch 14

# Run tests for a specific problem
gleam run -- test two-sum

# Submit solution to LeetCode
gleam run -- submit two-sum
```

### Global options

```sh
gleam run -- -C /path/to/project fetch two-sum
```

## How it works

1. `glc fetch` retrieves the problem from LeetCode's GraphQL API and generates:
   - `src/solutions/p0001_two_sum/solution.gleam` — function stub with problem URL
   - `test/solutions/p0001_two_sum/solution_test.gleam` — example test cases
2. You implement the solution in Gleam
3. `glc test` runs EUnit on that specific problem's test module
4. `glc submit` compiles to Erlang, strips compiler directives, and submits to LeetCode

## Authentication

LeetCode session cookie is resolved in this order:

1. Session file `~/.gleeam/session` (saved by `glc auth`)
2. Environment variable `LEETCODE_SESSION` (fallback)

Free problems can be fetched without authentication.

## Development

```sh
gleam test    # Run all unit tests
gleam build   # Build the project
```

### Contributing

This project includes a [Gleam LLM Wiki](docs/gleam-wiki/) as a submodule
for AI-assisted development. If contributing with an LLM agent, initialize
the submodule and point your agent at `docs/gleam-wiki/AGENTS.md` for
Gleam language reference.

```sh
git submodule update --init
```

## License

MIT
