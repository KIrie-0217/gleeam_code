import gleam/list
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

fn take_next(values: List(Option(Int))) -> #(Option(Int), List(Option(Int))) {
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
    [] -> panic as "unreachable: empty list"
    [x] -> ListNode(val: x, next: None)
    [x, ..rest] -> ListNode(val: x, next: Some(do_list_from_list(rest)))
  }
}
