import gleam/list
import gleam/string
import gleeam_code/internal/char
import gleeam_code/internal/file
import gleeam_code/internal/stdlib_extractor
import gleeam_code/internal/stdlib_scanner.{type StdlibCall, StdlibCall}

pub fn bundle(erl_code: String, stdlib_dir: String) -> String {
  let calls = stdlib_scanner.scan(erl_code)
  case calls {
    [] -> erl_code
    _ -> {
      let all_calls = resolve_transitive(calls, stdlib_dir, calls)
      let bundled_code = extract_and_rename(all_calls, stdlib_dir)
      let renamed_solution = rename_calls_in_code(erl_code, all_calls)
      bundled_code <> "\n" <> renamed_solution
    }
  }
}

fn resolve_transitive(
  worklist: List(StdlibCall),
  stdlib_dir: String,
  resolved: List(StdlibCall),
) -> List(StdlibCall) {
  case worklist {
    [] -> resolved
    _ -> {
      let new_calls =
        worklist
        |> list.flat_map(fn(call) { find_deps_of(call, stdlib_dir) })
        |> list.filter(fn(c) { !list.contains(resolved, c) })
        |> list.unique
      case new_calls {
        [] -> resolved
        _ ->
          resolve_transitive(
            new_calls,
            stdlib_dir,
            list.append(resolved, new_calls),
          )
      }
    }
  }
}

fn find_deps_of(call: StdlibCall, stdlib_dir: String) -> List(StdlibCall) {
  let module_file = module_to_path(call.module, stdlib_dir)
  case file.read(module_file) {
    Error(_) -> []
    Ok(source) ->
      case stdlib_extractor.extract_function(source, call.function) {
        Error(_) -> []
        Ok(func_body) -> {
          let inner_calls = stdlib_scanner.scan(func_body)
          let local_calls = find_local_calls(func_body, call.module, source)
          list.append(inner_calls, local_calls)
        }
      }
  }
}

fn find_local_calls(
  func_body: String,
  module: String,
  module_source: String,
) -> List(StdlibCall) {
  let exported = stdlib_extractor.list_exported(module_source)
  let all_identifiers = extract_called_identifiers(func_body)
  all_identifiers
  |> list.filter(fn(name) { !list.contains(exported, name) })
  |> list.filter(fn(name) { is_defined_in_source(name, module_source) })
  |> list.map(fn(name) { StdlibCall(module: module, function: name) })
}

fn extract_called_identifiers(body: String) -> List(String) {
  body
  |> string.to_graphemes
  |> scan_for_local_calls([], [])
  |> list.unique
}

fn scan_for_local_calls(
  chars: List(String),
  current: List(String),
  acc: List(String),
) -> List(String) {
  case chars {
    [] -> acc
    [c, ..rest] ->
      case is_local_call_start(c, current) {
        True -> scan_for_local_calls(rest, [c, ..current], acc)
        False ->
          case c {
            "(" -> {
              let name = string.concat(list.reverse(current))
              case name {
                "" -> scan_for_local_calls(rest, [], acc)
                _ ->
                  case
                    string.contains(name, ":") || string.contains(name, "@")
                  {
                    True -> scan_for_local_calls(rest, [], acc)
                    False -> scan_for_local_calls(rest, [], [name, ..acc])
                  }
              }
            }
            _ -> scan_for_local_calls(rest, [], acc)
          }
      }
  }
}

fn is_local_call_start(c: String, current: List(String)) -> Bool {
  case current {
    [] -> char.is_lowercase(c) || c == "_"
    _ -> char.is_identifier(c)
  }
}

fn is_defined_in_source(name: String, source: String) -> Bool {
  string.contains(source, "\n" <> name <> "(")
}

fn extract_and_rename(calls: List(StdlibCall), stdlib_dir: String) -> String {
  let grouped = group_by_module(calls)
  grouped
  |> list.map(fn(group) {
    let #(module, func_names) = group
    let module_file = module_to_path(module, stdlib_dir)
    case file.read(module_file) {
      Error(_) -> ""
      Ok(source) -> {
        let extracted = stdlib_extractor.extract_functions(source, func_names)
        rename_in_extracted(extracted, module, calls)
      }
    }
  })
  |> list.filter(fn(s) { s != "" })
  |> string.join("\n\n")
}

fn rename_in_extracted(
  code: String,
  current_module: String,
  all_calls: List(StdlibCall),
) -> String {
  let code1 = rename_external_calls(code, all_calls)
  rename_local_calls(code1, current_module, all_calls)
}

fn rename_local_calls(
  code: String,
  current_module: String,
  all_calls: List(StdlibCall),
) -> String {
  let local_funcs =
    all_calls
    |> list.filter(fn(c) { c.module == current_module })
    |> list.map(fn(c) { c.function })
    |> list.unique
  list.fold(local_funcs, code, fn(acc, func_name) {
    let renamed = make_local_name(current_module, func_name) <> "("
    rename_bare_calls(acc, func_name, renamed)
  })
}

fn rename_bare_calls(
  code: String,
  func_name: String,
  replacement: String,
) -> String {
  let target = func_name <> "("
  do_rename_bare(string.split(code, target), func_name, replacement)
}

fn do_rename_bare(
  parts: List(String),
  func_name: String,
  replacement: String,
) -> String {
  case parts {
    [] -> ""
    [only] -> only
    [first, ..rest] -> {
      let should_rename = case string.last(first) {
        Ok(c) -> !char.is_identifier_no_at(c)
        Error(_) -> True
      }
      case should_rename {
        True ->
          first <> replacement <> do_rename_bare(rest, func_name, replacement)
        False ->
          first
          <> func_name
          <> "("
          <> do_rename_bare(rest, func_name, replacement)
      }
    }
  }
}

fn rename_external_calls(code: String, calls: List(StdlibCall)) -> String {
  list.fold(calls, code, fn(acc, call) {
    let original = call.module <> ":" <> call.function <> "("
    let renamed = make_local_name(call.module, call.function) <> "("
    string.replace(acc, original, renamed)
  })
}

fn rename_calls_in_code(code: String, calls: List(StdlibCall)) -> String {
  list.fold(calls, code, fn(acc, call) {
    let original = call.module <> ":" <> call.function <> "("
    let renamed = make_local_name(call.module, call.function) <> "("
    string.replace(acc, original, renamed)
  })
}

fn make_local_name(module: String, function: String) -> String {
  let safe_module =
    module
    |> string.replace("@", "_")
    |> string.replace(".", "_")
  safe_module <> "__" <> function
}

fn module_to_path(module: String, stdlib_dir: String) -> String {
  stdlib_dir <> "/" <> module <> ".erl"
}

fn group_by_module(calls: List(StdlibCall)) -> List(#(String, List(String))) {
  calls
  |> list.fold([], fn(acc, call) {
    add_to_group(acc, call.module, call.function)
  })
}

fn add_to_group(
  groups: List(#(String, List(String))),
  module: String,
  func: String,
) -> List(#(String, List(String))) {
  case groups {
    [] -> [#(module, [func])]
    [#(m, funcs), ..rest] ->
      case m == module {
        True ->
          case list.contains(funcs, func) {
            True -> [#(m, funcs), ..rest]
            False -> [#(m, [func, ..funcs]), ..rest]
          }
        False -> [#(m, funcs), ..add_to_group(rest, module, func)]
      }
  }
}
