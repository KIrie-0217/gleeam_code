import gleam/erlang/atom.{type Atom}
import gleam/result
import gleeam_code/internal/resolver

pub fn run(
  base_dir: String,
  target: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  use module_name <- result.try(resolver.resolve_module(base_dir, target))

  let test_module_str = "solutions@" <> module_name <> "@solution_test"

  print("Running tests for: " <> target)

  let module_atom = atom.create(test_module_str)
  case run_eunit(module_atom) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Tests failed")
  }
}

@external(erlang, "gleeam_code_test_runner_ffi", "run_eunit")
fn run_eunit(module: Atom) -> Result(Nil, Nil)
