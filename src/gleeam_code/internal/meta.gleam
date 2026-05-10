import gleam/list
import gleam/string
import gleeam_code/internal/file

pub type SubmitMeta {
  SubmitMeta(func_name: String, param_types: List(String), return_type: String)
}

pub fn read(meta_path: String) -> Result(SubmitMeta, String) {
  case file.read(meta_path) {
    Error(_) ->
      Error("No .glc_meta found. Re-run 'glc fetch' for this problem.")
    Ok(content) -> {
      let lines = string.split(content, "\n")
      let func_name = find_value(lines, "entry_function")
      let params_str = find_value(lines, "params")
      let return_type = find_value(lines, "return_type")
      case func_name {
        "" -> Error("No entry_function in .glc_meta")
        name -> {
          let param_types = case params_str {
            "" -> []
            s -> string.split(s, ",")
          }
          Ok(SubmitMeta(
            func_name: name,
            param_types: param_types,
            return_type: return_type,
          ))
        }
      }
    }
  }
}

pub fn find_value(lines: List(String), key: String) -> String {
  case lines {
    [] -> ""
    [line, ..rest] ->
      case string.starts_with(line, key <> "=") {
        True ->
          string.drop_start(line, string.length(key) + 1)
          |> string.trim
        False -> find_value(rest, key)
      }
  }
}

pub fn save_status(
  meta_path: String,
  status: String,
  runtime: String,
  memory: String,
) -> Nil {
  case file.read(meta_path) {
    Ok(content) -> {
      let updated =
        content
        |> remove_key("status")
        |> remove_key("runtime")
        |> remove_key("memory")
      let new_content =
        string.trim_end(updated)
        <> "\nstatus="
        <> status
        <> "\nruntime="
        <> runtime
        <> "\nmemory="
        <> memory
        <> "\n"
      let _ = file.write(meta_path, new_content)
      Nil
    }
    Error(_) -> Nil
  }
}

fn remove_key(content: String, key: String) -> String {
  content
  |> string.split("\n")
  |> list.filter(fn(line) { !string.starts_with(line, key <> "=") })
  |> string.join("\n")
}
