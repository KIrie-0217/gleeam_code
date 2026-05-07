# gleeam_code

A Gleam CLI tool for solving LeetCode problems.
Write solutions in Gleam, compile to Erlang, and submit to LeetCode.

## Installation

### Nix (recommended)

```sh
nix profile install github:KIrie-0217/gleeam_code
```

Or add to your `flake.nix`:
```nix
inputs.gleeam_code.url = "github:KIrie-0217/gleeam_code";
# then: gleeam_code.packages.${system}.default
```

### From source

Requires [Gleam](https://gleam.run/) >= 1.0 and Erlang/OTP >= 26.

```sh
git clone --recurse-submodules https://github.com/KIrie-0217/gleeam_code.git
cd gleeam_code
gleam run -m gleescript    # produces ./gleeam_code
mv gleeam_code ~/.local/bin/glc
```

### GitHub Releases

Download the `glc` escript from [Releases](https://github.com/KIrie-0217/gleeam_code/releases). Requires Erlang/OTP on the host.

## Usage

```sh
glc init                    # Initialize project
glc auth                    # Save LeetCode session cookie
glc fetch two-sum           # Fetch problem (by slug or number)
glc fetch 14
glc test two-sum            # Run tests for a problem
glc submit two-sum          # Submit solution to LeetCode
glc --version               # Show version
```

### Global options

```sh
glc -C /path/to/project fetch two-sum
```

### Development mode

If running from source without building the escript:

```sh
gleam run -- fetch two-sum
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
gleam test              # Run all unit tests
gleam build             # Build the project
gleam run -m gleescript # Build standalone escript
nix build              # Build via Nix
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
