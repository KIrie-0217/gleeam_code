import gleam/option.{None, Some}
import gleeam_code/internal/tree_builder.{ListNode, TreeNode}

pub fn tree_from_level_order_empty_test() {
  let assert None = tree_builder.tree_from_level_order([])
}

pub fn tree_from_level_order_null_root_test() {
  let assert None = tree_builder.tree_from_level_order([None])
}

pub fn tree_from_level_order_single_node_test() {
  let assert Some(TreeNode(val: 1, left: None, right: None)) =
    tree_builder.tree_from_level_order([Some(1)])
}

pub fn tree_from_level_order_complete_test() {
  // [1, 2, 3] =>    1
  //                 / \
  //                2   3
  let assert Some(tree) =
    tree_builder.tree_from_level_order([Some(1), Some(2), Some(3)])
  let assert 1 = tree.val
  let assert Some(TreeNode(val: 2, left: None, right: None)) = tree.left
  let assert Some(TreeNode(val: 3, left: None, right: None)) = tree.right
}

pub fn tree_from_level_order_with_nulls_test() {
  // [1, null, 2, 3] =>  1
  //                       \
  //                        2
  //                       /
  //                      3
  let assert Some(tree) =
    tree_builder.tree_from_level_order([Some(1), None, Some(2), Some(3)])
  let assert 1 = tree.val
  let assert None = tree.left
  let assert Some(right) = tree.right
  let assert 2 = right.val
  let assert Some(TreeNode(val: 3, left: None, right: None)) = right.left
  let assert None = right.right
}

pub fn tree_from_level_order_left_skewed_test() {
  // [1, 2, null, 3] =>  1
  //                     /
  //                    2
  //                   /
  //                  3
  let assert Some(tree) =
    tree_builder.tree_from_level_order([Some(1), Some(2), None, Some(3)])
  let assert 1 = tree.val
  let assert None = tree.right
  let assert Some(left) = tree.left
  let assert 2 = left.val
  let assert Some(TreeNode(val: 3, left: None, right: None)) = left.left
  let assert None = left.right
}

pub fn tree_from_level_order_invert_example_test() {
  // [4, 2, 7, 1, 3, 6, 9] =>     4
  //                              /   \
  //                             2     7
  //                            / \   / \
  //                           1   3 6   9
  let assert Some(tree) =
    tree_builder.tree_from_level_order([
      Some(4),
      Some(2),
      Some(7),
      Some(1),
      Some(3),
      Some(6),
      Some(9),
    ])
  let assert 4 = tree.val
  let assert Some(left) = tree.left
  let assert 2 = left.val
  let assert Some(TreeNode(val: 1, left: None, right: None)) = left.left
  let assert Some(TreeNode(val: 3, left: None, right: None)) = left.right
  let assert Some(right) = tree.right
  let assert 7 = right.val
  let assert Some(TreeNode(val: 6, left: None, right: None)) = right.left
  let assert Some(TreeNode(val: 9, left: None, right: None)) = right.right
}

pub fn list_from_list_empty_test() {
  let assert None = tree_builder.list_from_list([])
}

pub fn list_from_list_single_test() {
  let assert Some(ListNode(val: 1, next: None)) =
    tree_builder.list_from_list([1])
}

pub fn list_from_list_multiple_test() {
  let assert Some(node) = tree_builder.list_from_list([1, 2, 3])
  let assert 1 = node.val
  let assert Some(node2) = node.next
  let assert 2 = node2.val
  let assert Some(ListNode(val: 3, next: None)) = node2.next
}
