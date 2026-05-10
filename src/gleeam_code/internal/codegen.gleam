import gleam/int
import gleam/list
import gleam/string
import gleeam_code/internal/spec_parser.{type FunctionSpec, type Param}

pub fn generate_solution(
  frontend_id: String,
  title: String,
  title_slug: String,
  difficulty: String,
  spec: FunctionSpec,
) -> String {
  let header =
    "//// Problem "
    <> frontend_id
    <> ": "
    <> title
    <> "\n//// https://leetcode.com/problems/"
    <> title_slug
    <> "/\n//// Difficulty: "
    <> difficulty
    <> "\n"

  let imports = generate_imports(spec)

  let params_str =
    spec.params
    |> list.map(fn(p) { p.name <> ": " <> p.type_str })
    |> string.join(", ")

  let func =
    "\npub fn "
    <> spec.name
    <> "("
    <> params_str
    <> ") -> "
    <> spec.return_type
    <> " {\n  todo\n}\n"

  header <> imports <> func
}

fn generate_imports(spec: FunctionSpec) -> String {
  let needs_tree = spec_parser.uses_tree_node(spec)
  let needs_list = spec_parser.uses_list_node(spec)
  case needs_tree || needs_list {
    False -> ""
    True -> {
      let option_import = "\nimport gleam/option.{type Option, None, Some}\n"
      let type_imports = case needs_tree, needs_list {
        True, True ->
          "import types.{type TreeNode, TreeNode, type ListNode, ListNode}\n"
        True, False -> "import types.{type TreeNode, TreeNode}\n"
        False, True -> "import types.{type ListNode, ListNode}\n"
        False, False -> ""
      }
      option_import <> type_imports
    }
  }
}

pub fn generate_test(
  module_path: String,
  spec: FunctionSpec,
  inputs: List(String),
  outputs: List(String),
) -> String {
  let import_line = "import " <> module_path <> "/solution\n"
  let needs_tree = spec_parser.uses_tree_node(spec)
  let needs_list = spec_parser.uses_list_node(spec)
  let extra_imports = case needs_tree || needs_list {
    False -> ""
    True -> {
      let option_import = "import gleam/option.{None, Some}\n"
      let types_import = case needs_tree, needs_list {
        True, True -> "import types.{tree_from_level_order, list_from_list}\n"
        True, False -> "import types.{tree_from_level_order}\n"
        False, True -> "import types.{list_from_list}\n"
        False, False -> ""
      }
      option_import <> types_import
    }
  }

  let padded_outputs = pad_outputs(outputs, list.length(inputs))
  let pairs = list.zip(inputs, padded_outputs)

  let uses_nodes = needs_tree || needs_list
  let tests =
    list.index_map(pairs, fn(pair, idx) {
      let example_num = int.to_string(idx + 1)
      let args = parse_testcase_input(pair.0, spec.params)
      let expected = format_gleam_value_typed(pair.1, spec.return_type)

      case uses_nodes {
        True ->
          "\npub fn example_"
          <> example_num
          <> "_test() {\n  let expected = "
          <> expected
          <> "\n  let result = solution."
          <> spec.name
          <> "("
          <> args
          <> ")\n  let assert True = expected == result\n}\n"
        False ->
          "\npub fn example_"
          <> example_num
          <> "_test() {\n  let assert "
          <> expected
          <> " = solution."
          <> spec.name
          <> "("
          <> args
          <> ")\n}\n"
      }
    })
    |> string.join("")

  import_line <> extra_imports <> tests
}

fn pad_outputs(outputs: List(String), target_len: Int) -> List(String) {
  let current_len = list.length(outputs)
  case current_len >= target_len {
    True -> outputs
    False -> list.append(outputs, list.repeat("todo", target_len - current_len))
  }
}

pub fn extract_outputs(content: String) -> List(String) {
  do_extract_outputs(content, [])
}

fn do_extract_outputs(content: String, acc: List(String)) -> List(String) {
  case string.split_once(content, "<strong>Output:</strong>") {
    Error(_) -> list.reverse(acc)
    Ok(#(_, after)) -> {
      let value = extract_output_value(string.trim_start(after))
      do_extract_outputs(after, [value, ..acc])
    }
  }
}

fn extract_output_value(s: String) -> String {
  take_until_delimiter(string.to_graphemes(s), "")
  |> string.trim
  |> decode_html_entities
}

fn take_until_delimiter(chars: List(String), acc: String) -> String {
  case chars {
    [] -> acc
    ["\n", ..] -> acc
    ["<", ..] -> acc
    [c, ..rest] -> take_until_delimiter(rest, acc <> c)
  }
}

fn decode_html_entities(s: String) -> String {
  s
  |> string.replace("&quot;", "\"")
  |> string.replace("&amp;", "&")
  |> string.replace("&lt;", "<")
  |> string.replace("&gt;", ">")
  |> string.replace("&#39;", "'")
  |> string.replace("&nbsp;", " ")
}

fn parse_testcase_input(input: String, params: List(Param)) -> String {
  let lines = string.split(input, "\n")
  list.zip(lines, params)
  |> list.map(fn(pair) { format_gleam_value_typed(pair.0, pair.1.type_str) })
  |> string.join(", ")
}

pub fn format_gleam_value(raw: String) -> String {
  format_gleam_value_typed(raw, "")
}

pub fn format_gleam_value_typed(raw: String, type_str: String) -> String {
  let trimmed = string.trim(raw)
  case type_str {
    "Option(TreeNode)" -> format_tree_value(trimmed)
    "Option(ListNode)" -> format_list_node_value(trimmed)
    _ ->
      case trimmed {
        "\"" <> _ -> trimmed
        "[" <> _ -> format_gleam_list(trimmed)
        "true" -> "True"
        "false" -> "False"
        "null" -> "None"
        _ -> trimmed
      }
  }
}

fn format_tree_value(raw: String) -> String {
  case raw {
    "null" | "[]" -> "None"
    "[" <> _ -> {
      let inner =
        raw
        |> string.drop_start(1)
        |> string.drop_end(1)
      let items =
        split_list_items(inner)
        |> list.map(fn(item) {
          let v = string.trim(item)
          case v {
            "null" -> "None"
            _ -> "Some(" <> v <> ")"
          }
        })
        |> string.join(", ")
      "tree_from_level_order([" <> items <> "])"
    }
    _ -> raw
  }
}

fn format_list_node_value(raw: String) -> String {
  case raw {
    "null" | "[]" -> "None"
    "[" <> _ -> {
      let inner =
        raw
        |> string.drop_start(1)
        |> string.drop_end(1)
      let items =
        split_list_items(inner)
        |> list.map(fn(item) { string.trim(item) })
        |> string.join(", ")
      "list_from_list([" <> items <> "])"
    }
    _ -> raw
  }
}

fn format_gleam_list(s: String) -> String {
  let inner =
    s
    |> string.drop_start(1)
    |> string.drop_end(1)

  case string.trim(inner) {
    "" -> "[]"
    content -> {
      let items =
        split_list_items(content)
        |> list.map(fn(item) { format_gleam_value(string.trim(item)) })
        |> string.join(", ")
      "[" <> items <> "]"
    }
  }
}

fn split_list_items(s: String) -> List(String) {
  spec_parser.split_params(s)
}
