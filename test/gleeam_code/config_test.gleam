import envoy
import gleeam_code/config
import gleeam_code/file

pub fn get_session_from_env_test() {
  envoy.set("LEETCODE_SESSION", "test_cookie_123")
  let assert Ok("test_cookie_123") = config.get_session()
  envoy.unset("LEETCODE_SESSION")
}

pub fn get_session_empty_env_falls_through_test() {
  envoy.set("LEETCODE_SESSION", "")
  // With empty env and no file, should get an error
  let assert Error(_) = config.get_session()
  envoy.unset("LEETCODE_SESSION")
}

pub fn save_and_read_session_test() {
  // Ensure env var is not set so file is used
  envoy.unset("LEETCODE_SESSION")

  let assert Ok(_) = config.save_session("  my_session_cookie  ")

  // Should read trimmed value from file
  let assert Ok("my_session_cookie") = config.get_session()

  // Cleanup
  let home = case envoy.get("HOME") {
    Ok(h) -> h
    Error(_) -> "."
  }
  let assert Ok(_) = file.delete(home <> "/.gleeam/session")
}

pub fn get_session_no_env_no_file_test() {
  envoy.unset("LEETCODE_SESSION")
  // Rename session file temporarily if it exists
  let assert Error(msg) = config.get_session()
  let assert True = {
    msg == "No session found. Set LEETCODE_SESSION env var or run: glc auth"
    || msg == "Session file is empty. Run: glc auth"
  }
}
