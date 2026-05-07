import gleam/list
import gleam/string

pub fn convert(erl_source: String) -> String {
  erl_source
  |> string.split("\n")
  |> list.filter(fn(line) { !is_directive_line(line) })
  |> drop_leading_empty
  |> string.join("\n")
  |> string.trim_end
  |> fn(s) { s <> "\n" }
}

fn is_directive_line(line: String) -> Bool {
  let trimmed = string.trim_start(line)
  is_module_directive(trimmed)
  || is_compile_directive(trimmed)
  || is_define_directive(trimmed)
  || is_export_directive(trimmed)
  || is_file_directive(trimmed)
  || is_if_directive(trimmed)
  || is_else_endif(trimmed)
  || is_moduledoc_call(trimmed)
}

fn is_module_directive(line: String) -> Bool {
  string.starts_with(line, "-module(")
}

fn is_compile_directive(line: String) -> Bool {
  string.starts_with(line, "-compile(")
}

fn is_define_directive(line: String) -> Bool {
  string.starts_with(line, "-define(")
}

fn is_export_directive(line: String) -> Bool {
  string.starts_with(line, "-export(")
}

fn is_file_directive(line: String) -> Bool {
  string.starts_with(line, "-file(")
}

fn is_if_directive(line: String) -> Bool {
  string.starts_with(line, "-if(")
}

fn is_else_endif(line: String) -> Bool {
  line == "-else." || line == "-endif."
}

fn is_moduledoc_call(line: String) -> Bool {
  string.starts_with(line, "?MODULEDOC(")
  || string.starts_with(line, "?DOC(")
  || is_moduledoc_content(line)
}

fn is_moduledoc_content(line: String) -> Bool {
  // Lines like '    " Problem 1: ...\n"' inside ?MODULEDOC(...)
  let trimmed = string.trim_start(line)
  { string.starts_with(trimmed, "\"") && string.ends_with(trimmed, "\"") }
  || trimmed == ")."
}

fn drop_leading_empty(lines: List(String)) -> List(String) {
  case lines {
    ["", ..rest] -> drop_leading_empty(rest)
    _ -> lines
  }
}
