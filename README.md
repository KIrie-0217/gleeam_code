# gleeam_code

A Gleam CLI tool for solving LeetCode problems.
Write solutions in Gleam, compile to Erlang, and submit to LeetCode.

- Gleam standard library auto-bundled into submissions
- TreeNode / ListNode problems supported with automatic record conversion
- Problem tracking with difficulty and status filters

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

## Quick Start

```sh
glc init                    # Initialize project (run once)
glc auth                    # Save your LeetCode session cookie
glc fetch two-sum           # Fetch problem and generate files
# ... implement src/solutions/p0001_two_sum/solution.gleam ...
glc test two-sum            # Run local tests
glc submit two-sum          # Submit to LeetCode
```

## Commands

| Command | Description |
|---|---|
| `glc init` | Initialize project directories and type definitions |
| `glc auth` | Prompt and save LeetCode session cookie to `~/.gleeam/session` |
| `glc fetch <slug-or-number>` | Fetch problem from LeetCode, generate solution stub and tests |
| `glc test <slug-or-number>` | Run EUnit on the problem's test module |
| `glc submit <slug-or-number>` | Build, bundle stdlib, convert to Erlang, submit |
| `glc list [options]` | List fetched problems with status |
| `glc --version` | Show version |

### `glc list` filters

```sh
glc list --easy --unsolved  # Easy problems not yet Accepted
glc list --medium --hard    # Medium and Hard problems
glc list --solved           # All Accepted problems
```

### Global options

```sh
glc -C /path/to/project fetch two-sum   # Run in a different directory
```

### Authentication

Session cookie is resolved in this order:

1. `~/.gleeam/session` (saved by `glc auth`)
2. `LEETCODE_SESSION` environment variable (fallback)

Free problems can be fetched without authentication.

## Development

```sh
gleam run -- fetch two-sum  # Run from source without escript
gleam test                  # Run all unit tests
gleam build                 # Build the project
gleam run -m gleescript     # Build standalone escript
nix build                   # Build via Nix
```

### Contributing

This project includes a [Gleam LLM Wiki](https://github.com/KIrie-0217/gleam-llm-wiki) as a submodule
for AI-assisted development. If contributing with an LLM agent, initialize
the submodule and point your agent at `docs/gleam-wiki/AGENTS.md` for
Gleam language reference.

```sh
git submodule update --init
```

## License

MIT
