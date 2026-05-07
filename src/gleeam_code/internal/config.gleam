/// Configuration and credential management.
/// Reads LEETCODE_SESSION from env var or ~/.gleeam/session file.
import envoy
import gleam/string
import gleeam_code/internal/file

const config_dir = ".gleeam"

const session_filename = "session"

/// Resolve the LeetCode session cookie.
/// Priority: session file (~/.gleeam/session) > env var LEETCODE_SESSION.
pub fn get_session() -> Result(String, String) {
  case read_session_file() {
    Ok(value) -> Ok(value)
    Error(_) ->
      case envoy.get("LEETCODE_SESSION") {
        Ok(value) if value != "" -> Ok(value)
        _ ->
          Error(
            "No session found. Set LEETCODE_SESSION env var or run: glc auth",
          )
      }
  }
}

pub fn session_file_exists() -> Bool {
  let path = config_path() <> "/" <> session_filename
  file.exists(path)
}

/// Save session cookie to ~/.gleeam/session.
pub fn save_session(cookie: String) -> Result(Nil, String) {
  let dir = config_path()
  let path = dir <> "/" <> session_filename
  case file.mkdir(dir) {
    Ok(_) ->
      case file.write(path, string.trim(cookie)) {
        Ok(_) -> Ok(Nil)
        Error(err) ->
          Error("Failed to write session: " <> file.describe_error(err))
      }
    Error(err) ->
      Error("Failed to create config dir: " <> file.describe_error(err))
  }
}

fn read_session_file() -> Result(String, String) {
  let path = config_path() <> "/" <> session_filename
  case file.read(path) {
    Ok(contents) -> {
      let trimmed = string.trim(contents)
      case trimmed {
        "" -> Error("Session file is empty. Run: glc auth")
        _ -> Ok(trimmed)
      }
    }
    Error(_) -> Error("No session file found")
  }
}

fn config_path() -> String {
  case envoy.get("HOME") {
    Ok(home) -> home <> "/" <> config_dir
    Error(_) -> config_dir
  }
}
