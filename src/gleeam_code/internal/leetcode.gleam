import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string

pub type Problem {
  Problem(
    frontend_id: String,
    title_slug: String,
    title: String,
    difficulty: String,
    content: String,
    is_paid_only: Bool,
    erlang_snippet: String,
    example_testcases: List(String),
  )
}

pub type FetchError {
  HttpError(String)
  JsonError(String)
  PremiumNoAuth
  PremiumNoAccess
  NoContent
  NoErlangSnippet
  ProblemNotFound
}

pub fn describe_error(err: FetchError) -> String {
  case err {
    HttpError(msg) -> "HTTP error: " <> msg
    JsonError(msg) -> "JSON parse error: " <> msg
    PremiumNoAuth -> "Premium problem. Run 'glc auth' to authenticate."
    PremiumNoAccess ->
      "Premium problem. Your account may not have Premium access."
    NoContent -> "Failed to fetch problem content."
    NoErlangSnippet -> "No Erlang code snippet available for this problem."
    ProblemNotFound -> "Problem not found."
  }
}

pub fn fetch_problem(
  slug: String,
  session: Result(String, String),
) -> Result(Problem, FetchError) {
  let query =
    "{\"query\":\"query questionContent($titleSlug: String!) { question(titleSlug: $titleSlug) { questionFrontendId titleSlug title difficulty content isPaidOnly codeSnippets { lang langSlug code } exampleTestcaseList }}\",\"variables\":{\"titleSlug\":\""
    <> slug
    <> "\"}}"

  use resp <- result.try(send_graphql(query, session))
  parse_problem_response(resp, session)
}

pub fn resolve_slug(
  input: String,
  session: Result(String, String),
) -> Result(String, FetchError) {
  case is_numeric(input) {
    False -> Ok(input)
    True -> lookup_slug_by_number(input, session)
  }
}

fn lookup_slug_by_number(
  number: String,
  session: Result(String, String),
) -> Result(String, FetchError) {
  let query =
    "{\"query\":\"query questionByNumber { questionList: questionList(categorySlug: \\\"\\\" limit: 1 skip: 0 filters: { searchKeywords: \\\""
    <> number
    <> "\\\" }) { data { questionFrontendId titleSlug } }}\"}"

  use resp <- result.try(send_graphql(query, session))
  parse_slug_response(resp, number)
}

fn send_graphql(
  body: String,
  session: Result(String, String),
) -> Result(String, FetchError) {
  let base_req =
    request.new()
    |> request.set_method(http.Post)
    |> request.set_host("leetcode.com")
    |> request.set_path("/graphql")
    |> request.set_scheme(http.Https)
    |> request.set_body(body)
    |> request.prepend_header("content-type", "application/json")

  let req = case session {
    Ok(cookie) ->
      base_req
      |> request.prepend_header("cookie", "LEETCODE_SESSION=" <> cookie)
    Error(_) -> base_req
  }

  case httpc.send(req) {
    Ok(resp) ->
      case resp.status {
        200 -> Ok(resp.body)
        status -> Error(HttpError("status " <> string.inspect(status)))
      }
    Error(_) -> Error(HttpError("failed to connect"))
  }
}

fn parse_problem_response(
  body: String,
  session: Result(String, String),
) -> Result(Problem, FetchError) {
  let question_decoder =
    decode.at(["data", "question"], decode.optional(decode.success(Nil)))

  case json.parse(body, question_decoder) {
    Error(_) -> Error(JsonError("invalid response structure"))
    Ok(option) ->
      case option {
        None -> Error(ProblemNotFound)
        Some(_) -> parse_question_fields(body, session)
      }
  }
}

fn parse_question_fields(
  body: String,
  session: Result(String, String),
) -> Result(Problem, FetchError) {
  let content_decoder =
    decode.at(["data", "question", "content"], decode.optional(decode.string))
  let is_paid_decoder =
    decode.at(["data", "question", "isPaidOnly"], decode.bool)

  let content_result = json.parse(body, content_decoder)
  let is_paid_result = json.parse(body, is_paid_decoder)

  case content_result, is_paid_result {
    Ok(None), Ok(True) ->
      case session {
        Ok(_) -> Error(PremiumNoAccess)
        Error(_) -> Error(PremiumNoAuth)
      }
    Ok(None), _ -> Error(NoContent)
    Ok(Some(content)), _ -> parse_full_problem(body, content)
    _, _ -> Error(JsonError("failed to parse content fields"))
  }
}

fn parse_full_problem(
  body: String,
  content: String,
) -> Result(Problem, FetchError) {
  let decoder =
    decode.at(["data", "question"], {
      use frontend_id <- decode.field("questionFrontendId", decode.string)
      use title_slug <- decode.field("titleSlug", decode.string)
      use title <- decode.field("title", decode.string)
      use difficulty <- decode.field("difficulty", decode.string)
      use snippets <- decode.field(
        "codeSnippets",
        decode.list(snippet_decoder()),
      )
      use testcases <- decode.field(
        "exampleTestcaseList",
        decode.list(decode.string),
      )
      decode.success(#(
        frontend_id,
        title_slug,
        title,
        difficulty,
        snippets,
        testcases,
      ))
    })

  case json.parse(body, decoder) {
    Error(_) -> Error(JsonError("failed to parse problem fields"))
    Ok(#(frontend_id, title_slug, title, difficulty, snippets, testcases)) -> {
      case find_erlang_snippet(snippets) {
        Error(err) -> Error(err)
        Ok(erlang_code) ->
          Ok(Problem(
            frontend_id: frontend_id,
            title_slug: title_slug,
            title: title,
            difficulty: difficulty,
            content: content,
            is_paid_only: False,
            erlang_snippet: erlang_code,
            example_testcases: testcases,
          ))
      }
    }
  }
}

type Snippet {
  Snippet(lang_slug: String, code: String)
}

fn snippet_decoder() -> decode.Decoder(Snippet) {
  use lang_slug <- decode.field("langSlug", decode.string)
  use code <- decode.field("code", decode.string)
  decode.success(Snippet(lang_slug: lang_slug, code: code))
}

fn find_erlang_snippet(snippets: List(Snippet)) -> Result(String, FetchError) {
  case list.find(snippets, fn(s) { s.lang_slug == "erlang" }) {
    Ok(snippet) -> Ok(snippet.code)
    Error(_) -> Error(NoErlangSnippet)
  }
}

fn parse_slug_response(
  body: String,
  number: String,
) -> Result(String, FetchError) {
  let decoder =
    decode.at(
      ["data", "questionList", "data"],
      decode.list({
        use fid <- decode.field("questionFrontendId", decode.string)
        use slug <- decode.field("titleSlug", decode.string)
        decode.success(#(fid, slug))
      }),
    )

  case json.parse(body, decoder) {
    Error(_) -> Error(JsonError("failed to parse question list"))
    Ok(items) ->
      case list.find(items, fn(item) { item.0 == number }) {
        Ok(#(_, slug)) -> Ok(slug)
        Error(_) -> Error(ProblemNotFound)
      }
  }
}

fn is_numeric(s: String) -> Bool {
  case string.to_graphemes(s) {
    [] -> False
    chars -> list.all(chars, fn(c) { is_digit(c) })
  }
}

fn is_digit(c: String) -> Bool {
  case c {
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    _ -> False
  }
}
