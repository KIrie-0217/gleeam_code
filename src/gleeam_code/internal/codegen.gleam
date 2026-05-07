import gleam/int
import gleam/list
import gleam/string

pub type FunctionSpec {
  FunctionSpec(name: String, params: List(Param), return_type: String)
}

pub type Param {
  Param(name: String, type_str: String)
}

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

  header <> func
}

pub fn generate_test(
  module_path: String,
  spec: FunctionSpec,
  inputs: List(String),
  outputs: List(String),
) -> String {
  let import_line = "import " <> module_path <> "/solution\n"

  let padded_outputs = pad_outputs(outputs, list.length(inputs))
  let pairs = list.zip(inputs, padded_outputs)

  let tests =
    list.index_map(pairs, fn(pair, idx) {
      let example_num = int.to_string(idx + 1)
      let args = parse_testcase_input(pair.0, spec.params)
      let expected = format_gleam_value(pair.1)

      "\npub fn example_"
      <> example_num
      <> "_test() {\n  let assert "
      <> expected
      <> " = solution."
      <> spec.name
      <> "("
      <> args
      <> ")\n}\n"
    })
    |> string.join("")

  import_line <> tests
}

fn pad_outputs(outputs: List(String), target_len: Int) -> List(String) {
  let current_len = list.length(outputs)
  case current_len >= target_len {
    True -> outputs
    False -> list.append(outputs, list.repeat("todo", target_len - current_len))
  }
}

pub fn parse_erlang_spec(snippet: String) -> Result(FunctionSpec, String) {
  let lines = string.split(snippet, "\n")
  case find_spec_line(lines) {
    Error(err) -> Error(err)
    Ok(spec_line) -> parse_spec_line(spec_line)
  }
}

fn find_spec_line(lines: List(String)) -> Result(String, String) {
  case lines {
    [] -> Error("No -spec line found in snippet")
    [line, ..rest] ->
      case string.starts_with(line, "-spec ") {
        True -> Ok(line)
        False -> find_spec_line(rest)
      }
  }
}

fn parse_spec_line(line: String) -> Result(FunctionSpec, String) {
  // Format: -spec func_name(Name :: type(), ...) -> return_type().
  let trimmed = string.drop_start(line, string.length("-spec "))
  // Split at first "("
  case string.split_once(trimmed, "(") {
    Error(_) -> Error("Invalid spec: no opening paren")
    Ok(#(name, rest)) -> {
      // Split params from return type at ") ->"
      case string.split_once(rest, ") ->") {
        Error(_) -> Error("Invalid spec: no ') ->' found")
        Ok(#(params_str, return_str)) -> {
          let params = parse_params(params_str)
          let return_type =
            return_str
            |> string.trim
            |> string.drop_end(1)
            |> erlang_type_to_gleam
          Ok(FunctionSpec(name: name, params: params, return_type: return_type))
        }
      }
    }
  }
}

fn parse_params(params_str: String) -> List(Param) {
  case string.trim(params_str) {
    "" -> []
    s -> split_params(s) |> list.map(parse_single_param)
  }
}

fn split_params(s: String) -> List(String) {
  do_split_params(string.to_graphemes(s), 0, "", [])
}

fn do_split_params(
  chars: List(String),
  depth: Int,
  current: String,
  acc: List(String),
) -> List(String) {
  case chars {
    [] ->
      case string.trim(current) {
        "" -> list.reverse(acc)
        trimmed -> list.reverse([trimmed, ..acc])
      }
    [",", ..rest] if depth == 0 ->
      do_split_params(rest, 0, "", [string.trim(current), ..acc])
    ["(", ..rest] | ["[", ..rest] | ["{", ..rest] ->
      do_split_params(rest, depth + 1, current <> hd_char(chars), acc)
    [")", ..rest] | ["]", ..rest] | ["}", ..rest] ->
      do_split_params(rest, depth - 1, current <> hd_char(chars), acc)
    [c, ..rest] -> do_split_params(rest, depth, current <> c, acc)
  }
}

fn hd_char(chars: List(String)) -> String {
  case chars {
    [c, ..] -> c
    [] -> ""
  }
}

fn parse_single_param(param_str: String) -> Param {
  // Format: "Name :: type()" or just "type()"
  case string.split_once(param_str, " :: ") {
    Ok(#(name, type_str)) ->
      Param(
        name: to_snake_case(name),
        type_str: erlang_type_to_gleam(string.trim(type_str)),
      )
    Error(_) ->
      Param(name: "arg", type_str: erlang_type_to_gleam(string.trim(param_str)))
  }
}

pub fn erlang_type_to_gleam(erl_type: String) -> String {
  let trimmed = string.trim(erl_type)
  case trimmed {
    "integer()" -> "Int"
    "float()" -> "Float"
    "boolean()" -> "Bool"
    "unicode:chardata()" -> "String"
    "unicode:unicode_binary()" -> "String"
    "char()" -> "Int"
    _ ->
      case string.starts_with(trimmed, "[") && string.ends_with(trimmed, "]") {
        True -> {
          let inner =
            trimmed
            |> string.drop_start(1)
            |> string.drop_end(1)
          "List(" <> erlang_type_to_gleam(inner) <> ")"
        }
        False -> trimmed
      }
  }
}

pub fn to_snake_case(name: String) -> String {
  name
  |> string.to_graphemes
  |> do_snake_case([], True)
  |> string.join("")
  |> string.lowercase
}

fn do_snake_case(
  chars: List(String),
  acc: List(String),
  is_start: Bool,
) -> List(String) {
  case chars {
    [] -> list.reverse(acc)
    [c, ..rest] ->
      case is_uppercase(c) {
        True ->
          case is_start {
            True -> do_snake_case(rest, [c, ..acc], False)
            False -> do_snake_case(rest, [c, "_", ..acc], False)
          }
        False -> do_snake_case(rest, [c, ..acc], False)
      }
  }
}

fn is_uppercase(c: String) -> Bool {
  let lower = string.lowercase(c)
  c != lower && lower != c
}

pub fn format_module_name(frontend_id: String, title_slug: String) -> String {
  let padded_id = string.pad_start(frontend_id, 4, "0")
  let snake_slug = string.replace(title_slug, "-", "_")
  "p" <> padded_id <> "_" <> snake_slug
}

fn parse_testcase_input(input: String, params: List(Param)) -> String {
  let lines = string.split(input, "\n")
  list.zip(lines, params)
  |> list.map(fn(pair) { format_gleam_value(pair.0) })
  |> string.join(", ")
}

pub fn format_gleam_value(raw: String) -> String {
  let trimmed = string.trim(raw)
  case trimmed {
    // String value with quotes
    "\"" <> _ -> trimmed
    // Array
    "[" <> _ -> format_gleam_list(trimmed)
    // Boolean
    "true" -> "True"
    "false" -> "False"
    // Number or other
    _ -> trimmed
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
  do_split_params(string.to_graphemes(s), 0, "", [])
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
  // Take until newline or '<'
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
