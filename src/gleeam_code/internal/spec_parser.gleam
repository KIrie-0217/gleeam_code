import gleam/list
import gleam/string

pub type FunctionSpec {
  FunctionSpec(name: String, params: List(Param), return_type: String)
}

pub type Param {
  Param(name: String, type_str: String)
}

pub fn parse_erlang_spec(snippet: String) -> Result(FunctionSpec, String) {
  let lines = string.split(snippet, "\n")
  case find_spec_line(lines) {
    Error(err) -> Error(err)
    Ok(spec_line) -> parse_spec_line(spec_line)
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
    "#tree_node{}"
    | "'null' | #tree_node{}"
    | "#tree_node{} | 'null'"
    | "null | #tree_node{}"
    | "#tree_node{} | null" -> "Option(TreeNode)"
    "#list_node{}"
    | "'null' | #list_node{}"
    | "#list_node{} | 'null'"
    | "null | #list_node{}"
    | "#list_node{} | null" -> "Option(ListNode)"
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

pub fn uses_tree_node(spec: FunctionSpec) -> Bool {
  let in_params =
    list.any(spec.params, fn(p) { string.contains(p.type_str, "TreeNode") })
  in_params || string.contains(spec.return_type, "TreeNode")
}

pub fn uses_list_node(spec: FunctionSpec) -> Bool {
  let in_params =
    list.any(spec.params, fn(p) { string.contains(p.type_str, "ListNode") })
  in_params || string.contains(spec.return_type, "ListNode")
}

pub fn to_snake_case(name: String) -> String {
  name
  |> string.to_graphemes
  |> do_snake_case([], True)
  |> string.join("")
  |> string.lowercase
}

pub fn format_module_name(frontend_id: String, title_slug: String) -> String {
  let padded_id = string.pad_start(frontend_id, 4, "0")
  let snake_slug = string.replace(title_slug, "-", "_")
  "p" <> padded_id <> "_" <> snake_slug
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
  let trimmed = string.drop_start(line, string.length("-spec "))
  case string.split_once(trimmed, "(") {
    Error(_) -> Error("Invalid spec: no opening paren")
    Ok(#(name, rest)) ->
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

fn parse_params(params_str: String) -> List(Param) {
  case string.trim(params_str) {
    "" -> []
    s -> split_params(s) |> list.map(parse_single_param)
  }
}

pub fn split_params(s: String) -> List(String) {
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

fn do_snake_case(
  chars: List(String),
  acc: List(String),
  is_start: Bool,
) -> List(String) {
  case chars {
    [] -> list.reverse(acc)
    [c, ..rest] ->
      case is_upper(c) {
        True ->
          case is_start {
            True -> do_snake_case(rest, [c, ..acc], False)
            False -> do_snake_case(rest, [c, "_", ..acc], False)
          }
        False -> do_snake_case(rest, [c, ..acc], False)
      }
  }
}

fn is_upper(c: String) -> Bool {
  let lower = string.lowercase(c)
  c != lower && lower != c
}
