import gleam/erlang/atom.{type Atom}
import gleam/list
import gleam/result
import gleam/string
import gleeam_code/internal/file

pub fn run(
  base_dir: String,
  target: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  use module_name <- result.try(resolve_module(base_dir, target))

  let test_module_str =
    "solutions@" <> module_name <> "@solution_test"

  print("Running tests for: " <> target)

  let module_atom = atom.create(test_module_str)
  case run_eunit(module_atom) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error("Tests failed")
  }
}

fn resolve_module(base_dir: String, target: String) -> Result(String, String) {
  let test_solutions_dir = base_dir <> "/test/solutions"
  case list_directory(test_solutions_dir) {
    Error(_) ->
      Error("No solutions found. Run 'glc fetch' first.")
    Ok(entries) ->
      case find_matching_entry(entries, target) {
        Ok(name) -> Ok(name)
        Error(_) ->
          Error(
            "Problem not found: "
            <> target
            <> ". Run 'glc fetch "
            <> target
            <> "' first.",
          )
      }
  }
}

fn find_matching_entry(
  entries: List(String),
  target: String,
) -> Result(String, Nil) {
  let snake_target = string.replace(target, "-", "_")
  list.find(entries, fn(entry) {
    case is_numeric_target(target) {
      True -> matches_number(entry, target)
      False -> matches_slug(entry, snake_target)
    }
  })
}

fn matches_number(entry: String, number: String) -> Bool {
  let padded = string.pad_start(number, 4, "0")
  string.starts_with(entry, "p" <> padded <> "_")
}

fn matches_slug(entry: String, snake_slug: String) -> Bool {
  case string.split_once(entry, "_") {
    Ok(#(_, slug_part)) -> slug_part == snake_slug
    Error(_) -> False
  }
}

fn is_numeric_target(s: String) -> Bool {
  case string.to_graphemes(s) {
    [] -> False
    chars ->
      list.all(chars, fn(c) {
        case c {
          "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
          _ -> False
        }
      })
  }
}

@external(erlang, "gleeam_code_test_runner_ffi", "run_eunit")
fn run_eunit(module: Atom) -> Result(Nil, Nil)

fn list_directory(path: String) -> Result(List(String), Nil) {
  case file.dir_exists(path) {
    False -> Error(Nil)
    True -> do_list_directory(path)
  }
}

@external(erlang, "gleeam_code_test_cmd_ffi", "list_directory")
fn do_list_directory(path: String) -> Result(List(String), Nil)
