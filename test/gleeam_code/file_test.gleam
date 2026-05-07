import gleeam_code/internal/file

pub fn write_and_read_test() {
  let path = "test/tmp_test_file.txt"
  let assert Ok(_) = file.write(path, "hello")
  let assert Ok("hello") = file.read(path)
  let assert Ok(_) = file.delete(path)
}

pub fn read_nonexistent_test() {
  let assert Error(_) = file.read("test/no_such_file.txt")
}

pub fn mkdir_test() {
  let dir = "test/tmp_test_dir"
  let assert Ok(_) = file.mkdir(dir)
  let assert True = file.dir_exists(dir)
  let assert Ok(_) = file.remove_directory(dir)
}

pub fn exists_test() {
  let assert True = file.exists("gleam.toml")
  let assert False = file.exists("no_such_file.toml")
}

pub fn dir_exists_test() {
  let assert True = file.dir_exists("src")
  let assert False = file.dir_exists("no_such_dir")
}
