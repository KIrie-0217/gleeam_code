import gleam/list
import gleam/string
import gleeam_code/internal/char
import gleeam_code/internal/file

pub fn resolve_module(
  base_dir: String,
  target: String,
) -> Result(String, String) {
  let test_solutions_dir = base_dir <> "/test/solutions"
  case list_directory(test_solutions_dir) {
    Error(_) -> Error("No solutions found. Run 'glc fetch' first.")
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

pub fn is_numeric(s: String) -> Bool {
  case string.to_graphemes(s) {
    [] -> False
    chars -> list.all(chars, char.is_digit)
  }
}

fn find_matching_entry(
  entries: List(String),
  target: String,
) -> Result(String, Nil) {
  let snake_target = string.replace(target, "-", "_")
  case is_numeric(target) {
    True -> find_by_number(entries, target)
    False -> find_by_slug(entries, snake_target)
  }
}

fn find_by_number(entries: List(String), number: String) -> Result(String, Nil) {
  let padded = string.pad_start(number, 4, "0")
  list.find(entries, fn(entry) {
    string.starts_with(entry, "p" <> padded <> "_")
  })
}

fn find_by_slug(
  entries: List(String),
  snake_slug: String,
) -> Result(String, Nil) {
  list.find(entries, fn(entry) {
    case string.split_once(entry, "_") {
      Ok(#(_, slug_part)) -> slug_part == snake_slug
      Error(_) -> False
    }
  })
}

fn list_directory(path: String) -> Result(List(String), Nil) {
  case file.dir_exists(path) {
    False -> Error(Nil)
    True ->
      case file.list_directory(path) {
        Ok(entries) -> Ok(entries)
        Error(_) -> Error(Nil)
      }
  }
}
