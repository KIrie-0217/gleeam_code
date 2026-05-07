import envoy
import gleeam_code/auth
import gleeam_code/internal/config
import gleeam_code/internal/file

fn no_print(_msg: String) -> Nil {
  Nil
}

fn mock_read_line(value: String) -> fn(String) -> Result(String, Nil) {
  fn(_prompt) { Ok(value) }
}

fn mock_read_line_error() -> fn(String) -> Result(String, Nil) {
  fn(_prompt) { Error(Nil) }
}

fn cleanup_session() -> Nil {
  let home = case envoy.get("HOME") {
    Ok(h) -> h
    Error(_) -> "."
  }
  let _ = file.delete(home <> "/.gleeam/session")
  Nil
}

pub fn auth_saves_session_test() {
  cleanup_session()
  envoy.unset("LEETCODE_SESSION")

  let assert Ok(_) = auth.run(".", no_print, mock_read_line("abc123"))
  let assert Ok("abc123") = config.get_session()

  cleanup_session()
}

pub fn auth_trims_input_test() {
  cleanup_session()
  envoy.unset("LEETCODE_SESSION")

  let assert Ok(_) = auth.run(".", no_print, mock_read_line("  cookie456  \n"))
  let assert Ok("cookie456") = config.get_session()

  cleanup_session()
}

pub fn auth_empty_input_error_test() {
  envoy.unset("LEETCODE_SESSION")

  let assert Error("Empty input. Session not saved.") =
    auth.run(".", no_print, mock_read_line("  "))
}

pub fn auth_eof_error_test() {
  envoy.unset("LEETCODE_SESSION")

  let assert Error("Failed to read input") =
    auth.run(".", no_print, mock_read_line_error())
}

pub fn auth_env_var_set_decline_test() {
  envoy.set("LEETCODE_SESSION", "existing_cookie")

  let assert Ok(_) = auth.run(".", no_print, mock_read_line("N"))

  envoy.unset("LEETCODE_SESSION")
}

pub fn auth_env_var_set_accept_test() {
  cleanup_session()
  envoy.set("LEETCODE_SESSION", "existing_cookie")

  let responses = ["y", "new_cookie"]
  let read_fn = make_sequential_reader(responses)

  let assert Ok(_) = auth.run(".", no_print, read_fn)
  envoy.unset("LEETCODE_SESSION")
  let assert Ok("new_cookie") = config.get_session()

  cleanup_session()
}

pub fn auth_existing_file_decline_test() {
  cleanup_session()
  envoy.unset("LEETCODE_SESSION")

  // Create existing session file
  let assert Ok(_) = config.save_session("old_cookie")

  let assert Ok(_) = auth.run(".", no_print, mock_read_line("N"))

  // Session file should remain unchanged
  let assert Ok("old_cookie") = config.get_session()
  cleanup_session()
}

pub fn auth_existing_file_accept_test() {
  cleanup_session()
  envoy.unset("LEETCODE_SESSION")

  // Create existing session file
  let assert Ok(_) = config.save_session("old_cookie")

  let responses = ["y", "updated_cookie"]
  let read_fn = make_sequential_reader(responses)

  let assert Ok(_) = auth.run(".", no_print, read_fn)
  let assert Ok("updated_cookie") = config.get_session()

  cleanup_session()
}

pub fn auth_env_var_and_file_both_exist_test() {
  cleanup_session()
  envoy.set("LEETCODE_SESSION", "env_cookie")
  let assert Ok(_) = config.save_session("file_cookie")

  // y to env var warning, y to overwrite, then new cookie
  let responses = ["y", "y", "brand_new"]
  let read_fn = make_sequential_reader(responses)

  let assert Ok(_) = auth.run(".", no_print, read_fn)
  envoy.unset("LEETCODE_SESSION")
  let assert Ok("brand_new") = config.get_session()

  cleanup_session()
}

@external(erlang, "gleeam_code_auth_test_ffi", "make_sequential_reader")
fn make_sequential_reader(
  responses: List(String),
) -> fn(String) -> Result(String, Nil)
