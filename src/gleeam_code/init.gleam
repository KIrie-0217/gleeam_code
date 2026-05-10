import gleeam_code/internal/file

const glc_toml_content = "# glc project config
[project]
solutions_dir = \"solutions\"
"

const types_gleam_content = "import gleam/list
import gleam/option.{type Option, None, Some}

pub type TreeNode {
  TreeNode(val: Int, left: Option(TreeNode), right: Option(TreeNode))
}

pub type ListNode {
  ListNode(val: Int, next: Option(ListNode))
}

pub fn tree_from_level_order(values: List(Option(Int))) -> Option(TreeNode) {
  case values {
    [] -> None
    [None, ..] -> None
    [Some(root_val), ..rest] -> {
      let #(flat, _) = bfs_assign([0], rest, [#(Some(root_val), -1, -1)], 1)
      build_tree_from_flat(flat, 0)
    }
  }
}

fn bfs_assign(
  queue: List(Int),
  remaining: List(Option(Int)),
  flat: List(#(Option(Int), Int, Int)),
  next_idx: Int,
) -> #(List(#(Option(Int), Int, Int)), List(Option(Int))) {
  case queue {
    [] -> #(flat, remaining)
    [parent_idx, ..rest_queue] -> {
      let #(left_val, after_left) = take_next(remaining)
      let #(right_val, after_right) = take_next(after_left)
      let #(left_idx, flat2, queue2, idx2) = case left_val {
        None -> #(-1, flat, rest_queue, next_idx)
        Some(_) -> #(
          next_idx,
          list.append(flat, [#(left_val, -1, -1)]),
          list.append(rest_queue, [next_idx]),
          next_idx + 1,
        )
      }
      let #(right_idx, flat3, queue3, idx3) = case right_val {
        None -> #(-1, flat2, queue2, idx2)
        Some(_) -> #(
          idx2,
          list.append(flat2, [#(right_val, -1, -1)]),
          list.append(queue2, [idx2]),
          idx2 + 1,
        )
      }
      let flat4 =
        list.index_map(flat3, fn(entry, i) {
          case i == parent_idx {
            True -> #(entry.0, left_idx, right_idx)
            False -> entry
          }
        })
      bfs_assign(queue3, after_right, flat4, idx3)
    }
  }
}

fn take_next(
  values: List(Option(Int)),
) -> #(Option(Int), List(Option(Int))) {
  case values {
    [] -> #(None, [])
    [v, ..rest] -> #(v, rest)
  }
}

fn build_tree_from_flat(
  flat: List(#(Option(Int), Int, Int)),
  idx: Int,
) -> Option(TreeNode) {
  case idx < 0 {
    True -> None
    False ->
      case list.drop(flat, idx) {
        [] -> None
        [#(None, _, _), ..] -> None
        [#(Some(val), left_idx, right_idx), ..] -> {
          let left = build_tree_from_flat(flat, left_idx)
          let right = build_tree_from_flat(flat, right_idx)
          Some(TreeNode(val: val, left: left, right: right))
        }
      }
  }
}

pub fn list_from_list(values: List(Int)) -> Option(ListNode) {
  case values {
    [] -> None
    _ -> Some(do_list_from_list(values))
  }
}

fn do_list_from_list(values: List(Int)) -> ListNode {
  case values {
    [] -> panic as \"unreachable: empty list\"
    [x] -> ListNode(val: x, next: None)
    [x, ..rest] -> ListNode(val: x, next: Some(do_list_from_list(rest)))
  }
}
"

const types_ffi_content = "-module(types_ffi).
-export([tree_to_record/1, tree_from_record/1,
         list_to_record/1, list_from_record/1]).

-record(tree_node, {val = 0, left = null, right = null}).
-record(list_node, {val = 0, next = null}).

tree_to_record(none) ->
    null;
tree_to_record({some, {tree_node, Val, Left, Right}}) ->
    #tree_node{val = Val,
               left = tree_to_record(Left),
               right = tree_to_record(Right)};
tree_to_record({tree_node, Val, Left, Right}) ->
    #tree_node{val = Val,
               left = tree_to_record(Left),
               right = tree_to_record(Right)}.

tree_from_record(null) ->
    none;
tree_from_record(#tree_node{val = Val, left = Left, right = Right}) ->
    {some, {tree_node, Val, tree_from_record(Left), tree_from_record(Right)}}.

list_to_record(none) ->
    null;
list_to_record({some, {list_node, Val, Next}}) ->
    #list_node{val = Val, next = list_to_record(Next)};
list_to_record({list_node, Val, Next}) ->
    #list_node{val = Val, next = list_to_record(Next)}.

list_from_record(null) ->
    none;
list_from_record(#list_node{val = Val, next = Next}) ->
    {some, {list_node, Val, list_from_record(Next)}}.
"

pub fn run(base_dir: String, print: fn(String) -> Nil) -> Result(Nil, String) {
  let gleam_toml = base_dir <> "/gleam.toml"
  let src_solutions = base_dir <> "/src/solutions"
  let test_solutions = base_dir <> "/test/solutions"
  let glc_toml = base_dir <> "/.glc.toml"
  let types_gleam = base_dir <> "/src/types.gleam"
  let types_ffi = base_dir <> "/src/types_ffi.erl"

  case file.exists(gleam_toml) {
    False -> Error("gleam.toml not found. Run 'gleam new <project>' first.")
    True -> {
      use _ <- result_try(create_solutions_dir(
        src_solutions,
        "src/solutions/",
        print,
      ))
      use _ <- result_try(create_solutions_dir(
        test_solutions,
        "test/solutions/",
        print,
      ))
      use _ <- result_try(create_glc_toml(glc_toml, print))
      use _ <- result_try(create_file(
        types_gleam,
        types_gleam_content,
        "src/types.gleam",
        print,
      ))
      create_file(types_ffi, types_ffi_content, "src/types_ffi.erl", print)
    }
  }
}

fn result_try(
  result: Result(Nil, String),
  next: fn(Nil) -> Result(Nil, String),
) -> Result(Nil, String) {
  case result {
    Ok(_) -> next(Nil)
    Error(err) -> Error(err)
  }
}

fn create_file(
  path: String,
  content: String,
  label: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  case file.exists(path) {
    True -> {
      print("  " <> label <> " already exists, skipping")
      Ok(Nil)
    }
    False ->
      case file.write(path, content) {
        Ok(_) -> {
          print("  Created " <> label)
          Ok(Nil)
        }
        Error(err) ->
          Error(
            "Failed to create " <> label <> ": " <> file.describe_error(err),
          )
      }
  }
}

fn create_solutions_dir(
  path: String,
  label: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  case file.dir_exists(path) {
    True -> {
      print("  " <> label <> " already exists, skipping")
      Ok(Nil)
    }
    False ->
      case file.mkdir(path) {
        Ok(_) -> {
          print("  Created " <> label)
          Ok(Nil)
        }
        Error(err) ->
          Error(
            "Failed to create " <> label <> ": " <> file.describe_error(err),
          )
      }
  }
}

fn create_glc_toml(
  path: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  case file.exists(path) {
    True -> {
      print("  .glc.toml already exists, skipping")
      Ok(Nil)
    }
    False ->
      case file.write(path, glc_toml_content) {
        Ok(_) -> {
          print("  Created .glc.toml")
          Ok(Nil)
        }
        Error(err) ->
          Error("Failed to create .glc.toml: " <> file.describe_error(err))
      }
  }
}
