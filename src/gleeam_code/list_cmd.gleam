import gleam/int
import gleam/list
import gleam/result
import gleam/string
import gleeam_code/internal/file

pub type ProblemEntry {
  ProblemEntry(number: Int, slug: String, difficulty: String, status: String)
}

pub type Filter {
  Filter(difficulty: List(String), solved: Option, unsolved: Option)
}

pub type Option {
  On
  Off
}

pub fn parse_filters(args: List(String)) -> Filter {
  do_parse_filters(args, Filter(difficulty: [], solved: Off, unsolved: Off))
}

fn do_parse_filters(args: List(String), acc: Filter) -> Filter {
  case args {
    [] -> acc
    ["--easy", ..rest] ->
      do_parse_filters(
        rest,
        Filter(..acc, difficulty: ["Easy", ..acc.difficulty]),
      )
    ["--medium", ..rest] ->
      do_parse_filters(
        rest,
        Filter(..acc, difficulty: ["Medium", ..acc.difficulty]),
      )
    ["--hard", ..rest] ->
      do_parse_filters(
        rest,
        Filter(..acc, difficulty: ["Hard", ..acc.difficulty]),
      )
    ["--solved", ..rest] -> do_parse_filters(rest, Filter(..acc, solved: On))
    ["--unsolved", ..rest] ->
      do_parse_filters(rest, Filter(..acc, unsolved: On))
    [_, ..rest] -> do_parse_filters(rest, acc)
  }
}

pub fn apply_filters(
  problems: List(ProblemEntry),
  filter: Filter,
) -> List(ProblemEntry) {
  problems
  |> filter_by_difficulty(filter.difficulty)
  |> filter_by_status(filter.solved, filter.unsolved)
}

fn filter_by_difficulty(
  problems: List(ProblemEntry),
  difficulties: List(String),
) -> List(ProblemEntry) {
  case difficulties {
    [] -> problems
    _ ->
      list.filter(problems, fn(p) { list.contains(difficulties, p.difficulty) })
  }
}

fn filter_by_status(
  problems: List(ProblemEntry),
  solved: Option,
  unsolved: Option,
) -> List(ProblemEntry) {
  case solved, unsolved {
    On, Off -> list.filter(problems, fn(p) { p.status == "Accepted" })
    Off, On -> list.filter(problems, fn(p) { p.status != "Accepted" })
    _, _ -> problems
  }
}

pub fn run(
  base_dir: String,
  args: List(String),
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  let filter = parse_filters(args)
  let solutions_dir = base_dir <> "/src/solutions"
  case file.dir_exists(solutions_dir) {
    False -> {
      print("No solutions found. Run `glc fetch` first.")
      Ok(Nil)
    }
    True -> {
      use entries <- result.try(
        file.list_directory(solutions_dir)
        |> result.map_error(fn(err) {
          "Failed to read solutions directory: " <> file.describe_error(err)
        }),
      )

      let problems =
        entries
        |> list.filter_map(fn(entry) { parse_entry(solutions_dir, entry) })
        |> list.sort(fn(a, b) { int.compare(a.number, b.number) })
        |> apply_filters(filter)

      case problems {
        [] -> {
          print("No solutions found. Run `glc fetch` first.")
          Ok(Nil)
        }
        _ -> {
          print(format_header())
          list.each(problems, fn(p) { print(format_row(p)) })
          Ok(Nil)
        }
      }
    }
  }
}

fn parse_entry(
  solutions_dir: String,
  dir_name: String,
) -> Result(ProblemEntry, Nil) {
  let solution_path = solutions_dir <> "/" <> dir_name <> "/solution.gleam"
  let meta_path = solutions_dir <> "/" <> dir_name <> "/.glc_meta"
  case file.read(solution_path) {
    Ok(content) -> parse_solution_header(content, dir_name, meta_path)
    Error(_) -> Error(Nil)
  }
}

fn parse_solution_header(
  content: String,
  dir_name: String,
  meta_path: String,
) -> Result(ProblemEntry, Nil) {
  let lines = string.split(content, "\n")
  use number <- result.try(extract_number(lines))
  let slug = extract_slug(dir_name)
  let difficulty = extract_difficulty(lines)
  let status = read_status(meta_path)
  Ok(ProblemEntry(
    number: number,
    slug: slug,
    difficulty: difficulty,
    status: status,
  ))
}

fn extract_number(lines: List(String)) -> Result(Int, Nil) {
  case lines {
    [] -> Error(Nil)
    [line, ..rest] ->
      case string.starts_with(line, "//// Problem ") {
        True -> {
          let after = string.drop_start(line, string.length("//// Problem "))
          case string.split_once(after, ":") {
            Ok(#(num_str, _)) ->
              num_str |> string.trim |> int.parse |> result.replace_error(Nil)
            Error(_) -> Error(Nil)
          }
        }
        False -> extract_number(rest)
      }
  }
}

fn extract_slug(dir_name: String) -> String {
  case string.split_once(dir_name, "_") {
    Ok(#(_, rest)) -> string.replace(rest, "_", "-")
    Error(_) -> dir_name
  }
}

fn extract_difficulty(lines: List(String)) -> String {
  case lines {
    [] -> "?"
    [line, ..rest] ->
      case string.starts_with(line, "//// Difficulty: ") {
        True ->
          string.drop_start(line, string.length("//// Difficulty: "))
          |> string.trim
        False -> extract_difficulty(rest)
      }
  }
}

fn read_status(meta_path: String) -> String {
  case file.read(meta_path) {
    Ok(content) -> find_meta_value(string.split(content, "\n"), "status")
    Error(_) -> ""
  }
}

fn find_meta_value(lines: List(String), key: String) -> String {
  case lines {
    [] -> ""
    [line, ..rest] ->
      case string.starts_with(line, key <> "=") {
        True ->
          string.drop_start(line, string.length(key) + 1)
          |> string.trim
        False -> find_meta_value(rest, key)
      }
  }
}

fn format_header() -> String {
  pad_right("#", 5)
  <> pad_right("Slug", 30)
  <> pad_right("Difficulty", 12)
  <> "Status"
}

fn format_row(entry: ProblemEntry) -> String {
  pad_right(int.to_string(entry.number), 5)
  <> pad_right(entry.slug, 30)
  <> pad_right(entry.difficulty, 12)
  <> format_status(entry.status)
}

fn format_status(status: String) -> String {
  case status {
    "Accepted" -> "✓ Accepted"
    "" -> ""
    other -> "✗ " <> other
  }
}

fn pad_right(s: String, width: Int) -> String {
  let len = string.length(s)
  case len >= width {
    True -> s
    False -> s <> string.repeat(" ", width - len)
  }
}
