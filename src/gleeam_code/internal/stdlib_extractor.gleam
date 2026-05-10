import gleam/list
import gleam/string

pub type FunctionBlock {
  FunctionBlock(name: String, arity: Int, body: String)
}

pub fn extract_function(
  erl_source: String,
  func_name: String,
) -> Result(String, Nil) {
  let blocks = parse_blocks(erl_source)
  case find_block(blocks, func_name) {
    Ok(block) -> Ok(block.body)
    Error(_) -> Error(Nil)
  }
}

pub fn extract_functions(erl_source: String, func_names: List(String)) -> String {
  let blocks = parse_blocks(erl_source)
  func_names
  |> list.filter_map(fn(name) { find_block(blocks, name) })
  |> list.map(fn(b) { b.body })
  |> string.join("\n\n")
}

pub fn list_exported(erl_source: String) -> List(String) {
  erl_source
  |> string.split("\n")
  |> find_export_line("")
  |> parse_export_entries
}

fn find_export_line(lines: List(String), acc: String) -> String {
  case lines {
    [] -> acc
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "-export([") {
        True ->
          case string.contains(trimmed, "]).") {
            True -> trimmed
            False -> collect_multiline_export(rest, trimmed)
          }
        False -> find_export_line(rest, acc)
      }
    }
  }
}

fn collect_multiline_export(lines: List(String), acc: String) -> String {
  case lines {
    [] -> acc
    [line, ..rest] -> {
      let new_acc = acc <> " " <> string.trim(line)
      case string.contains(line, "]).") {
        True -> new_acc
        False -> collect_multiline_export(rest, new_acc)
      }
    }
  }
}

fn parse_export_entries(export_line: String) -> List(String) {
  case string.split_once(export_line, "[") {
    Error(_) -> []
    Ok(#(_, after_bracket)) ->
      case string.split_once(after_bracket, "]") {
        Error(_) -> []
        Ok(#(entries_str, _)) ->
          entries_str
          |> string.split(",")
          |> list.map(fn(entry) {
            entry
            |> string.trim
            |> string.split("/")
            |> fn(parts) {
              case parts {
                [name, ..] -> string.trim(name)
                _ -> ""
              }
            }
          })
          |> list.filter(fn(s) { s != "" })
      }
  }
}

fn find_block(
  blocks: List(FunctionBlock),
  func_name: String,
) -> Result(FunctionBlock, Nil) {
  list.find(blocks, fn(b) { b.name == func_name })
}

fn parse_blocks(erl_source: String) -> List(FunctionBlock) {
  let lines = string.split(erl_source, "\n")
  case string.contains(erl_source, "-file(") {
    True -> split_into_blocks(lines, [], [])
    False -> split_plain_blocks(lines, [], [])
  }
}

fn split_plain_blocks(
  lines: List(String),
  current_block: List(String),
  acc: List(FunctionBlock),
) -> List(FunctionBlock) {
  case lines {
    [] -> {
      case current_block {
        [] -> list.reverse(acc)
        _ ->
          case finalize_plain_block(list.reverse(current_block)) {
            Ok(block) -> list.reverse([block, ..acc])
            Error(_) -> list.reverse(acc)
          }
      }
    }
    [line, ..rest] -> {
      case is_toplevel_func_start(line) && current_block != [] {
        True -> {
          let new_acc = case finalize_plain_block(list.reverse(current_block)) {
            Ok(block) -> [block, ..acc]
            Error(_) -> acc
          }
          split_plain_blocks(rest, [line], new_acc)
        }
        False -> split_plain_blocks(rest, [line, ..current_block], acc)
      }
    }
  }
}

fn is_toplevel_func_start(line: String) -> Bool {
  case string.to_graphemes(line) {
    [] -> False
    [first, ..] ->
      case is_lowercase_alpha(first) {
        True -> string.contains(line, "(")
        False -> False
      }
  }
}

fn is_lowercase_alpha(c: String) -> Bool {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    _ -> False
  }
}

fn finalize_plain_block(lines: List(String)) -> Result(FunctionBlock, Nil) {
  let meaningful =
    list.filter(lines, fn(line) {
      let trimmed = string.trim(line)
      trimmed != ""
      && !string.starts_with(trimmed, "-module(")
      && !string.starts_with(trimmed, "-compile(")
      && !string.starts_with(trimmed, "-export(")
      && !string.starts_with(trimmed, "-define(")
      && !string.starts_with(trimmed, "-if(")
      && !string.starts_with(trimmed, "-else.")
      && !string.starts_with(trimmed, "-endif.")
      && !string.starts_with(trimmed, "%")
    })
  case meaningful {
    [] -> Error(Nil)
    _ -> extract_func_info(meaningful)
  }
}

fn split_into_blocks(
  lines: List(String),
  current_block: List(String),
  acc: List(FunctionBlock),
) -> List(FunctionBlock) {
  case lines {
    [] -> {
      case current_block {
        [] -> list.reverse(acc)
        _ ->
          case finalize_block(list.reverse(current_block)) {
            Ok(block) -> list.reverse([block, ..acc])
            Error(_) -> list.reverse(acc)
          }
      }
    }
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case is_file_directive(trimmed) {
        True -> {
          let new_acc = case current_block {
            [] -> acc
            _ ->
              case finalize_block(list.reverse(current_block)) {
                Ok(block) -> [block, ..acc]
                Error(_) -> acc
              }
          }
          split_into_blocks(rest, [line], new_acc)
        }
        False -> split_into_blocks(rest, [line, ..current_block], acc)
      }
    }
  }
}

fn is_file_directive(line: String) -> Bool {
  string.starts_with(line, "-file(")
}

fn finalize_block(lines: List(String)) -> Result(FunctionBlock, Nil) {
  let meaningful = skip_non_code(lines)
  case meaningful {
    [] -> Error(Nil)
    _ -> extract_func_info(meaningful)
  }
}

fn skip_non_code(lines: List(String)) -> List(String) {
  case lines {
    [] -> []
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case is_file_directive(trimmed) {
        True -> skip_non_code(rest)
        False ->
          case string.starts_with(trimmed, "?DOC(") {
            True -> skip_doc_block(rest)
            False ->
              case string.starts_with(trimmed, "-spec ") {
                True -> skip_spec_block(trimmed, rest)
                False ->
                  case is_doc_content(trimmed) {
                    True -> skip_non_code(rest)
                    False -> [line, ..rest]
                  }
              }
          }
      }
    }
  }
}

fn skip_spec_block(first_line: String, rest: List(String)) -> List(String) {
  case string.ends_with(first_line, ".") {
    True -> skip_non_code(rest)
    False -> skip_until_spec_end(rest)
  }
}

fn skip_until_spec_end(lines: List(String)) -> List(String) {
  case lines {
    [] -> []
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.ends_with(trimmed, ".") {
        True -> skip_non_code(rest)
        False -> skip_until_spec_end(rest)
      }
    }
  }
}

fn skip_doc_block(lines: List(String)) -> List(String) {
  case lines {
    [] -> []
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case trimmed == ")." {
        True -> skip_non_code(rest)
        False -> skip_doc_block(rest)
      }
    }
  }
}

fn is_doc_content(line: String) -> Bool {
  { string.starts_with(line, "\"") && string.ends_with(line, "\"") }
  || line == ")."
  || { string.starts_with(line, "    \"") && string.ends_with(line, "\"") }
}

fn extract_func_info(lines: List(String)) -> Result(FunctionBlock, Nil) {
  case lines {
    [] -> Error(Nil)
    [first, ..] -> {
      case parse_function_head(string.trim(first)) {
        Ok(#(name, arity)) -> {
          let body = string.join(lines, "\n")
          Ok(FunctionBlock(name: name, arity: arity, body: body))
        }
        Error(_) -> Error(Nil)
      }
    }
  }
}

fn parse_function_head(line: String) -> Result(#(String, Int), Nil) {
  case string.split_once(line, "(") {
    Error(_) -> Error(Nil)
    Ok(#(name, args_rest)) -> {
      let trimmed_name = string.trim(name)
      case trimmed_name {
        "" -> Error(Nil)
        _ -> {
          let arity = count_args(args_rest)
          Ok(#(trimmed_name, arity))
        }
      }
    }
  }
}

fn count_args(args_str: String) -> Int {
  case string.split_once(args_str, ")") {
    Error(_) -> 0
    Ok(#(inside, _)) -> {
      let trimmed = string.trim(inside)
      case trimmed {
        "" -> 0
        _ -> count_top_level_commas(string.to_graphemes(trimmed), 0, 1)
      }
    }
  }
}

fn count_top_level_commas(chars: List(String), depth: Int, count: Int) -> Int {
  case chars {
    [] -> count
    [c, ..rest] ->
      case c {
        "(" | "[" | "{" -> count_top_level_commas(rest, depth + 1, count)
        ")" | "]" | "}" -> count_top_level_commas(rest, depth - 1, count)
        "," if depth == 0 -> count_top_level_commas(rest, depth, count + 1)
        _ -> count_top_level_commas(rest, depth, count)
      }
  }
}
