import gleeam_code/file

const glc_toml_content = "# glc project config
[project]
solutions_dir = \"solutions\"
"

pub fn run(base_dir: String, print: fn(String) -> Nil) -> Result(Nil, String) {
  let gleam_toml = base_dir <> "/gleam.toml"
  let solutions_dir = base_dir <> "/solutions"
  let glc_toml = base_dir <> "/.glc.toml"

  case file.exists(gleam_toml) {
    False ->
      Error("gleam.toml not found. Run 'gleam new <project>' first.")
    True -> {
      case create_solutions_dir(solutions_dir, print) {
        Ok(_) -> create_glc_toml(glc_toml, print)
        Error(err) -> Error(err)
      }
    }
  }
}

fn create_solutions_dir(
  path: String,
  print: fn(String) -> Nil,
) -> Result(Nil, String) {
  case file.dir_exists(path) {
    True -> {
      print("  solutions/ already exists, skipping")
      Ok(Nil)
    }
    False ->
      case file.mkdir(path) {
        Ok(_) -> {
          print("  Created solutions/")
          Ok(Nil)
        }
        Error(err) ->
          Error(
            "Failed to create solutions/: " <> file.describe_error(err),
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
