import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/result
import gleam/string
import gleeam_code/internal/config
import gleeam_code/internal/erlang_convert
import gleeam_code/internal/file
import gleeam_code/internal/meta
import gleeam_code/internal/resolver
import gleeam_code/internal/stdlib_bundler

pub fn run(
  base_dir: String,
  target: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  use session <- result.try(require_session())
  use module_name <- result.try(resolver.resolve_module(base_dir, target))

  let slug = extract_slug(module_name)
  let question_id = extract_question_id(module_name)

  print("Building solution...")
  use _ <- result.try(build_erlang(base_dir))

  use project_name <- result.try(read_project_name(base_dir))
  let erl_path =
    base_dir
    <> "/build/dev/erlang/"
    <> project_name
    <> "/_gleam_artefacts/solutions@"
    <> module_name
    <> "@solution.erl"

  use erl_source <- result.try(read_erl_file(erl_path))

  let converted = erlang_convert.convert(erl_source)

  let stdlib_dir = base_dir <> "/build/dev/erlang/gleam_stdlib/_gleam_artefacts"
  let bundled = stdlib_bundler.bundle(converted, stdlib_dir)

  let solution_path =
    base_dir <> "/src/solutions/" <> module_name <> "/solution.gleam"
  use solution_source <- result.try(read_solution_file(solution_path))
  let needs_tree = string.contains(solution_source, "TreeNode")
  let needs_list = string.contains(solution_source, "ListNode")

  let meta_path = base_dir <> "/src/solutions/" <> module_name <> "/.glc_meta"
  use submit_meta <- result.try(meta.read(meta_path))

  let final_code = case needs_tree || needs_list {
    False -> bundled
    True -> bundle_with_types(bundled, submit_meta, needs_tree, needs_list)
  }

  print("Submitting to LeetCode as Erlang...")

  use csrf <- result.try(fetch_csrf(session))
  use submission_id <- result.try(submit_to_leetcode(
    slug,
    question_id,
    final_code,
    session,
    csrf,
  ))
  print("Submitted! Checking result...")

  use submit_result <- result.try(poll_result(submission_id, session, csrf, 0))
  print(format_result(submit_result))

  meta.save_status(
    meta_path,
    submit_result.status,
    submit_result.runtime,
    submit_result.memory,
  )

  Ok(Nil)
}

fn require_session() -> Result(String, String) {
  case config.get_session() {
    Ok(s) -> Ok(s)
    Error(_) -> Error("No session found. Run 'glc auth' first.")
  }
}

fn extract_slug(module_name: String) -> String {
  case string.split_once(module_name, "_") {
    Ok(#(_, slug_part)) -> string.replace(slug_part, "_", "-")
    Error(_) -> module_name
  }
}

fn extract_question_id(module_name: String) -> String {
  let id_part =
    module_name
    |> string.drop_start(1)
    |> string.split_once("_")
  case id_part {
    Ok(#(num, _)) -> drop_leading_zeros(num)
    Error(_) -> "0"
  }
}

fn drop_leading_zeros(s: String) -> String {
  case string.pop_grapheme(s) {
    Ok(#("0", rest)) if rest != "" -> drop_leading_zeros(rest)
    _ -> s
  }
}

fn fetch_csrf(session: String) -> Result(String, String) {
  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_host("leetcode.com")
    |> request.set_path("/graphql")
    |> request.set_scheme(http.Https)
    |> request.set_body("{\"query\":\"{ user { username } }\"}")
    |> request.prepend_header("content-type", "application/json")
    |> request.prepend_header("cookie", "LEETCODE_SESSION=" <> session)

  case httpc.send(req) {
    Error(_) -> Error("Failed to connect to LeetCode for CSRF")
    Ok(resp) -> extract_csrf_from_headers(resp.headers)
  }
}

fn extract_csrf_from_headers(
  headers: List(#(String, String)),
) -> Result(String, String) {
  case headers {
    [] -> Error("CSRF token not found in response")
    [#(name, value), ..rest] ->
      case
        string.lowercase(name) == "set-cookie"
        && string.contains(value, "csrftoken=")
      {
        True -> {
          let token =
            value
            |> string.split("csrftoken=")
            |> fn(parts) {
              case parts {
                [_, after, ..] ->
                  after
                  |> string.split(";")
                  |> fn(p) {
                    case p {
                      [t, ..] -> t
                      [] -> ""
                    }
                  }
                _ -> ""
              }
            }
          case token {
            "" -> Error("Failed to extract CSRF token")
            t -> Ok(t)
          }
        }
        False -> extract_csrf_from_headers(rest)
      }
  }
}

fn build_erlang(base_dir: String) -> Result(Nil, String) {
  let output =
    os_cmd("cd " <> base_dir <> " && gleam build --target erlang 2>&1")
  case string.contains(output, "error:") {
    True -> Error("Build failed:\n" <> output)
    False -> Ok(Nil)
  }
}

fn read_project_name(base_dir: String) -> Result(String, String) {
  let toml_path = base_dir <> "/gleam.toml"
  case file.read(toml_path) {
    Error(_) -> Error("Could not read gleam.toml")
    Ok(content) -> extract_name_from_toml(content)
  }
}

fn extract_name_from_toml(content: String) -> Result(String, String) {
  let lines = string.split(content, "\n")
  find_name_line(lines)
}

fn find_name_line(lines: List(String)) -> Result(String, String) {
  case lines {
    [] -> Error("No 'name' field found in gleam.toml")
    [line, ..rest] ->
      case string.starts_with(string.trim(line), "name") {
        True ->
          case string.split_once(line, "=") {
            Ok(#(_, value)) -> {
              let name =
                value
                |> string.trim
                |> string.replace("\"", "")
              Ok(name)
            }
            Error(_) -> find_name_line(rest)
          }
        False -> find_name_line(rest)
      }
  }
}

fn read_erl_file(path: String) -> Result(String, String) {
  case file.read(path) {
    Ok(content) -> Ok(content)
    Error(_) -> Error("Could not read compiled .erl file at: " <> path)
  }
}

pub type SubmitResult {
  SubmitResult(status: String, runtime: String, memory: String)
}

fn submit_to_leetcode(
  slug: String,
  question_id: String,
  code: String,
  session: String,
  csrf: String,
) -> Result(String, String) {
  let body =
    json.to_string(
      json.object([
        #("lang", json.string("erlang")),
        #("questionSlug", json.string(slug)),
        #("question_id", json.string(question_id)),
        #("typed_code", json.string(code)),
      ]),
    )

  let req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_host("leetcode.com")
    |> request.set_path("/problems/" <> slug <> "/submit/")
    |> request.set_scheme(http.Https)
    |> request.set_body(body)
    |> request.prepend_header("content-type", "application/json")
    |> request.prepend_header(
      "cookie",
      "LEETCODE_SESSION=" <> session <> "; csrftoken=" <> csrf,
    )
    |> request.prepend_header("x-csrftoken", csrf)
    |> request.prepend_header(
      "referer",
      "https://leetcode.com/problems/" <> slug <> "/",
    )

  case httpc.send(req) {
    Error(_) -> Error("Failed to connect to LeetCode")
    Ok(resp) ->
      case resp.status {
        200 -> parse_submit_response(resp.body)
        _ ->
          Error(
            "Submit failed with status: "
            <> string.inspect(resp.status)
            <> " - "
            <> resp.body,
          )
      }
  }
}

fn parse_submit_response(body: String) -> Result(String, String) {
  let decoder = {
    use id <- decode.field("submission_id", decode.int)
    decode.success(id)
  }

  case json.parse(body, decoder) {
    Ok(id) -> Ok(string.inspect(id))
    Error(_) -> Error("Failed to parse submit response: " <> body)
  }
}

fn poll_result(
  submission_id: String,
  session: String,
  csrf: String,
  attempts: Int,
) -> Result(SubmitResult, String) {
  case attempts > 20 {
    True -> Error("Timed out waiting for submission result")
    False -> {
      sleep(1000)
      case check_submission(submission_id, session, csrf) {
        Ok(result) -> Ok(result)
        Error("pending") ->
          poll_result(submission_id, session, csrf, attempts + 1)
        Error(err) -> Error(err)
      }
    }
  }
}

fn check_submission(
  submission_id: String,
  session: String,
  csrf: String,
) -> Result(SubmitResult, String) {
  let req =
    request.new()
    |> request.set_method(http.Get)
    |> request.set_host("leetcode.com")
    |> request.set_path("/submissions/detail/" <> submission_id <> "/check/")
    |> request.set_scheme(http.Https)
    |> request.prepend_header(
      "cookie",
      "LEETCODE_SESSION=" <> session <> "; csrftoken=" <> csrf,
    )

  case httpc.send(req) {
    Error(_) -> Error("Failed to check submission status")
    Ok(resp) ->
      case resp.status {
        200 -> parse_check_response(resp.body)
        _ -> Error("Check failed with status: " <> string.inspect(resp.status))
      }
  }
}

fn parse_check_response(body: String) -> Result(SubmitResult, String) {
  let state_decoder = {
    use state <- decode.field("state", decode.string)
    decode.success(state)
  }

  case json.parse(body, state_decoder) {
    Error(_) -> Error("Failed to parse check response")
    Ok(state) ->
      case state {
        "PENDING" | "STARTED" -> Error("pending")
        "SUCCESS" -> parse_final_result(body)
        _ -> Error("Unexpected state: " <> state)
      }
  }
}

fn parse_final_result(body: String) -> Result(SubmitResult, String) {
  let decoder = {
    use status <- decode.field("status_msg", decode.string)
    use runtime <- decode.field("status_runtime", decode.string)
    use memory <- decode.field("status_memory", decode.string)
    decode.success(SubmitResult(
      status: status,
      runtime: runtime,
      memory: memory,
    ))
  }

  case json.parse(body, decoder) {
    Ok(result) -> Ok(result)
    Error(_) -> Error("Failed to parse submission result: " <> body)
  }
}

fn format_result(result: SubmitResult) -> String {
  case result.status {
    "Accepted" ->
      "✓ Accepted! Runtime: " <> result.runtime <> ", Memory: " <> result.memory
    _ ->
      "✗ "
      <> result.status
      <> " | Runtime: "
      <> result.runtime
      <> ", Memory: "
      <> result.memory
  }
}

fn read_solution_file(path: String) -> Result(String, String) {
  case file.read(path) {
    Ok(content) -> Ok(content)
    Error(_) -> Ok("")
  }
}

fn bundle_with_types(
  erl_code: String,
  submit_meta: meta.SubmitMeta,
  needs_tree: Bool,
  needs_list: Bool,
) -> String {
  let conversion_fns = generate_conversion_fns(needs_tree, needs_list)
  let renamed =
    string.replace(
      erl_code,
      submit_meta.func_name <> "(",
      submit_meta.func_name <> "_impl(",
    )
  let wrapper = generate_wrapper(submit_meta)

  conversion_fns <> "\n" <> wrapper <> "\n" <> renamed
}

fn generate_conversion_fns(needs_tree: Bool, needs_list: Bool) -> String {
  let tree_fns = case needs_tree {
    True ->
      "tree_to_record(none) -> null;\n"
      <> "tree_to_record({some, {tree_node, Val, Left, Right}}) ->\n"
      <> "    #tree_node{val = Val, left = tree_to_record(Left), right = tree_to_record(Right)}.\n\n"
      <> "tree_from_record(null) -> none;\n"
      <> "tree_from_record(#tree_node{val = Val, left = Left, right = Right}) ->\n"
      <> "    {some, {tree_node, Val, tree_from_record(Left), tree_from_record(Right)}}.\n\n"
    False -> ""
  }
  let list_fns = case needs_list {
    True ->
      "list_to_record(none) -> null;\n"
      <> "list_to_record({some, {list_node, Val, Next}}) ->\n"
      <> "    #list_node{val = Val, next = list_to_record(Next)}.\n\n"
      <> "list_from_record(null) -> none;\n"
      <> "list_from_record(#list_node{val = Val, next = Next}) ->\n"
      <> "    {some, {list_node, Val, list_from_record(Next)}}.\n\n"
    False -> ""
  }
  tree_fns <> list_fns
}

fn generate_wrapper(submit_meta: meta.SubmitMeta) -> String {
  let arg_count = list.length(submit_meta.param_types)
  let arg_names = generate_arg_names(arg_count, 1, [])

  let spec_params =
    list.map(submit_meta.param_types, gleam_type_to_erlang_spec)
    |> string.join(", ")
  let spec_return = gleam_type_to_erlang_spec(submit_meta.return_type)

  let wrapper_params = string.join(arg_names, ", ")

  let converted_args =
    list.zip(arg_names, submit_meta.param_types)
    |> list.map(fn(pair) { convert_arg_expr(pair.0, pair.1) })

  let impl_args = string.join(converted_args, ", ")

  let result_expr = convert_result_expr("GleamResult", submit_meta.return_type)

  "-spec "
  <> submit_meta.func_name
  <> "("
  <> spec_params
  <> ") -> "
  <> spec_return
  <> ".\n"
  <> submit_meta.func_name
  <> "("
  <> wrapper_params
  <> ") ->\n"
  <> "    GleamResult = "
  <> submit_meta.func_name
  <> "_impl("
  <> impl_args
  <> "),\n"
  <> "    "
  <> result_expr
  <> ".\n"
}

fn generate_arg_names(
  count: Int,
  current: Int,
  acc: List(String),
) -> List(String) {
  case current > count {
    True -> list.reverse(acc)
    False -> {
      let name = "Arg" <> string.inspect(current)
      generate_arg_names(count, current + 1, [name, ..acc])
    }
  }
}

fn gleam_type_to_erlang_spec(gleam_type: String) -> String {
  case gleam_type {
    "Option(TreeNode)" -> "'null' | #tree_node{}"
    "Option(ListNode)" -> "'null' | #list_node{}"
    "Int" -> "integer()"
    "Float" -> "float()"
    "Bool" -> "boolean()"
    "String" -> "unicode:unicode_binary()"
    _ ->
      case string.starts_with(gleam_type, "List(") {
        True ->
          "["
          <> gleam_type_to_erlang_spec(extract_inner_type(gleam_type))
          <> "]"
        False -> "any()"
      }
  }
}

fn extract_inner_type(list_type: String) -> String {
  list_type
  |> string.drop_start(5)
  |> string.drop_end(1)
}

fn convert_arg_expr(arg_name: String, type_str: String) -> String {
  case type_str {
    "Option(TreeNode)" -> "tree_from_record(" <> arg_name <> ")"
    "Option(ListNode)" -> "list_from_record(" <> arg_name <> ")"
    _ -> arg_name
  }
}

fn convert_result_expr(result_var: String, return_type: String) -> String {
  case return_type {
    "Option(TreeNode)" -> "tree_to_record(" <> result_var <> ")"
    "Option(ListNode)" -> "list_to_record(" <> result_var <> ")"
    _ -> result_var
  }
}

@external(erlang, "gleeam_code_submit_ffi", "os_cmd")
fn os_cmd(cmd: String) -> String

@external(erlang, "gleeam_code_submit_ffi", "sleep")
fn sleep(ms: Int) -> Nil
