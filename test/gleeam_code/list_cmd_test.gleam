import gleam/list
import gleam/string
import gleeam_code/internal/file
import gleeam_code/list_cmd

fn setup_test_dir() -> String {
  let base = "/tmp/glc_list_test_" <> random_suffix()
  let solutions = base <> "/src/solutions"
  let assert Ok(_) = file.mkdir(solutions)
  base
}

fn create_solution(base: String, dir_name: String, content: String) -> Nil {
  let dir = base <> "/src/solutions/" <> dir_name
  let assert Ok(_) = file.mkdir(dir)
  let assert Ok(_) = file.write(dir <> "/solution.gleam", content)
  Nil
}

fn cleanup(path: String) -> Nil {
  let assert Ok(_) = remove_recursive(path)
  Nil
}

pub fn list_empty_directory_test() {
  let base = setup_test_dir()
  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "No solutions found") })
  cleanup(base)
}

pub fn list_no_solutions_dir_test() {
  let base = "/tmp/glc_list_test_nodir_" <> random_suffix()
  let assert Ok(_) = file.mkdir(base)
  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "No solutions found") })
  cleanup(base)
}

pub fn list_single_problem_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )

  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  let assert True = list.any(output, fn(line) { string.contains(line, "Easy") })
  cleanup(base)
}

pub fn list_multiple_problems_sorted_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0014_longest_common_prefix",
    "//// Problem 14: Longest Common Prefix
//// https://leetcode.com/problems/longest-common-prefix/
//// Difficulty: Easy

pub fn longest_common_prefix(strs: List(String)) -> String {
  todo
}
",
  )
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )

  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True = list.length(output) == 3
  let assert True =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "longest-common-prefix") })

  let assert [_, row1, row2] = output
  let assert True = string.contains(row1, "1")
  let assert True = string.contains(row2, "14")
  cleanup(base)
}

pub fn list_shows_accepted_status_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  let meta_path = base <> "/src/solutions/p0001_two_sum/.glc_meta"
  let assert Ok(_) =
    file.write(
      meta_path,
      "entry_function=two_sum\nparams=List(Int),Int\nreturn_type=List(Int)\nstatus=Accepted\nruntime=0 ms\nmemory=7.2 MB\n",
    )

  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "✓ Accepted") })
  cleanup(base)
}

pub fn list_shows_failed_status_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  let meta_path = base <> "/src/solutions/p0001_two_sum/.glc_meta"
  let assert Ok(_) =
    file.write(
      meta_path,
      "entry_function=two_sum\nparams=List(Int),Int\nreturn_type=List(Int)\nstatus=Wrong Answer\nruntime=N/A\nmemory=N/A\n",
    )

  let output = collect_output(fn(print) { list_cmd.run(base, [], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "✗ Wrong Answer") })
  cleanup(base)
}

pub fn filter_by_difficulty_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  create_solution(
    base,
    "p0053_maximum_subarray",
    "//// Problem 53: Maximum Subarray
//// https://leetcode.com/problems/maximum-subarray/
//// Difficulty: Medium

pub fn max_sub_array(nums: List(Int)) -> Int {
  todo
}
",
  )

  let output =
    collect_output(fn(print) { list_cmd.run(base, ["--medium"], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "maximum-subarray") })
  let assert False =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  cleanup(base)
}

pub fn filter_by_solved_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  let assert Ok(_) =
    file.write(
      base <> "/src/solutions/p0001_two_sum/.glc_meta",
      "entry_function=two_sum\nstatus=Accepted\n",
    )
  create_solution(
    base,
    "p0053_maximum_subarray",
    "//// Problem 53: Maximum Subarray
//// https://leetcode.com/problems/maximum-subarray/
//// Difficulty: Medium

pub fn max_sub_array(nums: List(Int)) -> Int {
  todo
}
",
  )

  let output =
    collect_output(fn(print) { list_cmd.run(base, ["--solved"], print) })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  let assert False =
    list.any(output, fn(line) { string.contains(line, "maximum-subarray") })
  cleanup(base)
}

pub fn filter_by_unsolved_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  let assert Ok(_) =
    file.write(
      base <> "/src/solutions/p0001_two_sum/.glc_meta",
      "entry_function=two_sum\nstatus=Accepted\n",
    )
  create_solution(
    base,
    "p0053_maximum_subarray",
    "//// Problem 53: Maximum Subarray
//// https://leetcode.com/problems/maximum-subarray/
//// Difficulty: Medium

pub fn max_sub_array(nums: List(Int)) -> Int {
  todo
}
",
  )

  let output =
    collect_output(fn(print) { list_cmd.run(base, ["--unsolved"], print) })
  let assert False =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "maximum-subarray") })
  cleanup(base)
}

pub fn filter_combined_test() {
  let base = setup_test_dir()
  create_solution(
    base,
    "p0001_two_sum",
    "//// Problem 1: Two Sum
//// https://leetcode.com/problems/two-sum/
//// Difficulty: Easy

pub fn two_sum(nums: List(Int), target: Int) -> List(Int) {
  todo
}
",
  )
  let assert Ok(_) =
    file.write(
      base <> "/src/solutions/p0001_two_sum/.glc_meta",
      "entry_function=two_sum\nstatus=Accepted\n",
    )
  create_solution(
    base,
    "p0014_longest_common_prefix",
    "//// Problem 14: Longest Common Prefix
//// https://leetcode.com/problems/longest-common-prefix/
//// Difficulty: Easy

pub fn longest_common_prefix(strs: List(String)) -> String {
  todo
}
",
  )
  create_solution(
    base,
    "p0053_maximum_subarray",
    "//// Problem 53: Maximum Subarray
//// https://leetcode.com/problems/maximum-subarray/
//// Difficulty: Medium

pub fn max_sub_array(nums: List(Int)) -> Int {
  todo
}
",
  )

  let output =
    collect_output(fn(print) {
      list_cmd.run(base, ["--easy", "--unsolved"], print)
    })
  let assert False =
    list.any(output, fn(line) { string.contains(line, "two-sum") })
  let assert True =
    list.any(output, fn(line) { string.contains(line, "longest-common-prefix") })
  let assert False =
    list.any(output, fn(line) { string.contains(line, "maximum-subarray") })
  cleanup(base)
}

fn collect_output(
  f: fn(fn(String) -> Nil) -> Result(Nil, String),
) -> List(String) {
  let output = collect_lines(f)
  output
}

@external(erlang, "gleeam_code_list_test_ffi", "collect_lines")
fn collect_lines(
  f: fn(fn(String) -> Nil) -> Result(Nil, String),
) -> List(String)

@external(erlang, "gleeam_code_list_test_ffi", "random_suffix")
fn random_suffix() -> String

@external(erlang, "gleeam_code_list_test_ffi", "remove_recursive")
fn remove_recursive(path: String) -> Result(Nil, Nil)
