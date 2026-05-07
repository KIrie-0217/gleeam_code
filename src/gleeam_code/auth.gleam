import envoy
import gleam/string
import gleeam_code/internal/config

pub fn run(
  _base_dir: String,
  print: fn(String) -> Nil,
  read_line: fn(String) -> Result(String, Nil),
) -> Result(Nil, String) {
  case check_env_var(print, read_line) {
    Error(msg) -> Error(msg)
    Ok(False) -> Ok(Nil)
    Ok(True) ->
      case check_existing_file(print, read_line) {
        Error(msg) -> Error(msg)
        Ok(False) -> Ok(Nil)
        Ok(True) -> prompt_and_save(print, read_line)
      }
  }
}

fn check_env_var(
  print: fn(String) -> Nil,
  read_line: fn(String) -> Result(String, Nil),
) -> Result(Bool, String) {
  case envoy.get("LEETCODE_SESSION") {
    Ok(value) if value != "" -> {
      print("LEETCODE_SESSION environment variable is already set.")
      print(
        "glc uses the session file (~/.gleeam/session) with higher priority.",
      )
      case read_line("Save a separate session anyway? [y/N]: ") {
        Ok(input) ->
          case string.trim(input) |> string.lowercase {
            "y" | "yes" -> Ok(True)
            _ -> Ok(False)
          }
        Error(_) -> Error("Failed to read input")
      }
    }
    _ -> Ok(True)
  }
}

fn check_existing_file(
  print: fn(String) -> Nil,
  read_line: fn(String) -> Result(String, Nil),
) -> Result(Bool, String) {
  case config.session_file_exists() {
    False -> Ok(True)
    True -> {
      print("Session file already exists (~/.gleeam/session).")
      case read_line("Overwrite? [y/N]: ") {
        Ok(input) ->
          case string.trim(input) |> string.lowercase {
            "y" | "yes" -> Ok(True)
            _ -> Ok(False)
          }
        Error(_) -> Error("Failed to read input")
      }
    }
  }
}

fn prompt_and_save(
  print: fn(String) -> Nil,
  read_line: fn(String) -> Result(String, Nil),
) -> Result(Nil, String) {
  case read_line("Paste your LEETCODE_SESSION cookie: ") {
    Ok(input) -> {
      let cookie = string.trim(input)
      case cookie {
        "" -> Error("Empty input. Session not saved.")
        _ ->
          case config.save_session(cookie) {
            Ok(_) -> {
              print("Session saved to ~/.gleeam/session")
              Ok(Nil)
            }
            Error(err) -> Error(err)
          }
      }
    }
    Error(_) -> Error("Failed to read input")
  }
}

@external(erlang, "gleeam_code_io_ffi", "get_line")
pub fn stdin_read_line(prompt: String) -> Result(String, Nil)
