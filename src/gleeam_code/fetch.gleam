import gleam/result
import gleeam_code/internal/codegen
import gleeam_code/internal/config
import gleeam_code/internal/file
import gleeam_code/internal/leetcode

pub fn run(
  base_dir: String,
  target: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  let session = config.get_session()

  use slug <- try_with(
    leetcode.resolve_slug(target, session),
    leetcode.describe_error,
  )

  print("Fetching problem: " <> slug <> "...")

  use problem <- try_with(
    leetcode.fetch_problem(slug, session),
    leetcode.describe_error,
  )

  use spec <- result.try(codegen.parse_erlang_spec(problem.erlang_snippet))

  let module_name =
    codegen.format_module_name(problem.frontend_id, problem.title_slug)
  let module_path = "solutions/" <> module_name

  let src_dir = base_dir <> "/src/" <> module_path
  let test_dir = base_dir <> "/test/" <> module_path

  use _ <- result.try(ensure_dir(src_dir))
  use _ <- result.try(ensure_dir(test_dir))

  let solution_content =
    codegen.generate_solution(
      problem.frontend_id,
      problem.title,
      problem.title_slug,
      problem.difficulty,
      spec,
    )

  let outputs = codegen.extract_outputs(problem.content)

  let test_content =
    codegen.generate_test(module_path, spec, problem.example_testcases, outputs)

  use _ <- result.try(write_file(src_dir <> "/solution.gleam", solution_content))
  print("  Created src/" <> module_path <> "/solution.gleam")

  use _ <- result.try(write_file(
    test_dir <> "/solution_test.gleam",
    test_content,
  ))
  print("  Created test/" <> module_path <> "/solution_test.gleam")

  Ok(Nil)
}

fn try_with(
  res: Result(a, e),
  to_string: fn(e) -> String,
  next: fn(a) -> Result(Nil, String),
) -> Result(Nil, String) {
  case res {
    Ok(val) -> next(val)
    Error(err) -> Error(to_string(err))
  }
}

fn ensure_dir(path: String) -> Result(Nil, String) {
  case file.mkdir(path) {
    Ok(_) -> Ok(Nil)
    Error(err) ->
      Error("Failed to create directory: " <> file.describe_error(err))
  }
}

fn write_file(path: String, content: String) -> Result(Nil, String) {
  case file.write(path, content) {
    Ok(_) -> Ok(Nil)
    Error(err) -> Error("Failed to write file: " <> file.describe_error(err))
  }
}
