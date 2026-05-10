import gleeam_code/init
import gleeam_code/internal/file

const test_dir = "/tmp/glc_init_test"

fn no_print(_msg: String) -> Nil {
  Nil
}

fn setup() -> Nil {
  let _ = file.mkdir(test_dir)
  Nil
}

fn teardown() -> Nil {
  let _ = file.delete(test_dir <> "/.glc.toml")
  let _ = file.delete(test_dir <> "/src/types.gleam")
  let _ = file.delete(test_dir <> "/src/types_ffi.erl")
  let _ = file.remove_directory(test_dir <> "/src/solutions")
  let _ = file.remove_directory(test_dir <> "/src")
  let _ = file.remove_directory(test_dir <> "/test/solutions")
  let _ = file.remove_directory(test_dir <> "/test")
  let _ = file.delete(test_dir <> "/gleam.toml")
  let _ = file.remove_directory(test_dir)
  Nil
}

pub fn init_no_gleam_toml_test() {
  setup()
  let assert Error("gleam.toml not found. Run 'gleam new <project>' first.") =
    init.run(test_dir, no_print)
  teardown()
}

pub fn init_creates_solutions_and_glc_toml_test() {
  setup()
  let assert Ok(_) = file.write(test_dir <> "/gleam.toml", "")

  let assert Ok(_) = init.run(test_dir, no_print)
  let assert True = file.dir_exists(test_dir <> "/src/solutions")
  let assert True = file.dir_exists(test_dir <> "/test/solutions")
  let assert True = file.exists(test_dir <> "/.glc.toml")
  let assert True = file.exists(test_dir <> "/src/types.gleam")
  let assert True = file.exists(test_dir <> "/src/types_ffi.erl")

  teardown()
}

pub fn init_idempotent_test() {
  setup()
  let assert Ok(_) = file.write(test_dir <> "/gleam.toml", "")
  let assert Ok(_) = file.write(test_dir <> "/.glc.toml", "custom content")
  let assert Ok(_) = file.mkdir(test_dir <> "/src/solutions")
  let assert Ok(_) = file.mkdir(test_dir <> "/test/solutions")

  let assert Ok(_) = init.run(test_dir, no_print)

  let assert Ok("custom content") = file.read(test_dir <> "/.glc.toml")
  teardown()
}
