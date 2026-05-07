import gleeam_code/internal/codegen

pub fn parse_erlang_spec_two_sum_test() {
  let snippet =
    "-spec two_sum(Nums :: [integer()], Target :: integer()) -> [integer()].\ntwo_sum(Nums, Target) ->\n  ."
  let assert Ok(spec) = codegen.parse_erlang_spec(snippet)
  let assert "two_sum" = spec.name
  let assert "List(Int)" = spec.return_type
  let assert [p1, p2] = spec.params
  let assert "nums" = p1.name
  let assert "List(Int)" = p1.type_str
  let assert "target" = p2.name
  let assert "Int" = p2.type_str
}

pub fn parse_erlang_spec_string_test() {
  let snippet =
    "-spec longest_common_prefix(Strs :: [unicode:unicode_binary()]) -> unicode:unicode_binary().\nlongest_common_prefix(Strs) ->\n  ."
  let assert Ok(spec) = codegen.parse_erlang_spec(snippet)
  let assert "longest_common_prefix" = spec.name
  let assert "String" = spec.return_type
  let assert [p1] = spec.params
  let assert "strs" = p1.name
  let assert "List(String)" = p1.type_str
}

pub fn erlang_type_to_gleam_test() {
  let assert "Int" = codegen.erlang_type_to_gleam("integer()")
  let assert "Float" = codegen.erlang_type_to_gleam("float()")
  let assert "Bool" = codegen.erlang_type_to_gleam("boolean()")
  let assert "String" = codegen.erlang_type_to_gleam("unicode:chardata()")
  let assert "String" = codegen.erlang_type_to_gleam("unicode:unicode_binary()")
  let assert "List(Int)" = codegen.erlang_type_to_gleam("[integer()]")
  let assert "List(String)" =
    codegen.erlang_type_to_gleam("[unicode:unicode_binary()]")
}

pub fn to_snake_case_test() {
  let assert "nums" = codegen.to_snake_case("Nums")
  let assert "target" = codegen.to_snake_case("Target")
  let assert "title_slug" = codegen.to_snake_case("TitleSlug")
  let assert "l1" = codegen.to_snake_case("L1")
}

pub fn format_module_name_test() {
  let assert "p0001_two_sum" = codegen.format_module_name("1", "two-sum")
  let assert "p0014_longest_common_prefix" =
    codegen.format_module_name("14", "longest-common-prefix")
  let assert "p0100_same_tree" = codegen.format_module_name("100", "same-tree")
}

pub fn format_gleam_value_test() {
  let assert "[0, 1]" = codegen.format_gleam_value("[0,1]")
  let assert "[1, 2]" = codegen.format_gleam_value("[1,2]")
  let assert "\"fl\"" = codegen.format_gleam_value("\"fl\"")
  let assert "True" = codegen.format_gleam_value("true")
  let assert "False" = codegen.format_gleam_value("false")
  let assert "42" = codegen.format_gleam_value("42")
}

pub fn extract_outputs_test() {
  let content =
    "<p><strong class=\"example\">Example 1:</strong></p>\n<pre>\n<strong>Input:</strong> nums = [2,7,11,15], target = 9\n<strong>Output:</strong> [0,1]\n</pre>\n<p><strong class=\"example\">Example 2:</strong></p>\n<pre>\n<strong>Input:</strong> nums = [3,2,4], target = 6\n<strong>Output:</strong> [1,2]\n</pre>"
  let assert ["[0,1]", "[1,2]"] = codegen.extract_outputs(content)
}

pub fn generate_solution_test() {
  let spec =
    codegen.FunctionSpec(
      name: "two_sum",
      params: [
        codegen.Param(name: "nums", type_str: "List(Int)"),
        codegen.Param(name: "target", type_str: "Int"),
      ],
      return_type: "List(Int)",
    )
  let result =
    codegen.generate_solution("1", "Two Sum", "two-sum", "Easy", spec)
  let assert True =
    result
    == "//// Problem 1: Two Sum\n//// https://leetcode.com/problems/two-sum/\n//// Difficulty: Easy\n\npub fn two_sum(nums: List(Int), target: Int) -> List(Int) {\n  todo\n}\n"
}
