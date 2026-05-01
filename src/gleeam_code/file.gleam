/// File I/O operations.
/// Thin wrappers over Erlang file/filelib via FFI.

import gleam/erlang/atom.{type Atom}

pub type FileError =
  Atom

/// Read a file's contents as a string.
pub fn read(path: String) -> Result(String, FileError) {
  read_file(path)
}

/// Write a string to a file, creating it if it doesn't exist.
pub fn write(path: String, contents: String) -> Result(Nil, FileError) {
  write_file(path, contents)
}

/// Create a directory and all parent directories.
pub fn mkdir(path: String) -> Result(Nil, FileError) {
  ensure_dir(path <> "/.")
}

/// Create a single directory (parents must exist).
pub fn make_directory(path: String) -> Result(Nil, FileError) {
  make_dir(path)
}

/// Check if a file exists.
pub fn exists(path: String) -> Bool {
  is_regular(path)
}

/// Check if a directory exists.
pub fn dir_exists(path: String) -> Bool {
  is_dir(path)
}

/// Delete a file.
pub fn delete(path: String) -> Result(Nil, FileError) {
  delete_file(path)
}

/// Delete an empty directory.
pub fn remove_directory(path: String) -> Result(Nil, FileError) {
  delete_dir(path)
}

/// Format a FileError as a human-readable string.
pub fn describe_error(error: FileError) -> String {
  atom.to_string(error)
}

// --- Erlang FFI (direct, returns {ok, Binary} | {error, Atom}) ---

@external(erlang, "file", "read_file")
fn read_file(path: String) -> Result(String, FileError)

// --- Erlang FFI (via wrapper, converts ok -> {ok, nil}) ---

@external(erlang, "gleeam_code_file_ffi", "write_file")
fn write_file(path: String, contents: String) -> Result(Nil, FileError)

@external(erlang, "gleeam_code_file_ffi", "ensure_dir")
fn ensure_dir(path: String) -> Result(Nil, FileError)

@external(erlang, "gleeam_code_file_ffi", "make_dir")
fn make_dir(path: String) -> Result(Nil, FileError)

@external(erlang, "gleeam_code_file_ffi", "delete_file")
fn delete_file(path: String) -> Result(Nil, FileError)

@external(erlang, "gleeam_code_file_ffi", "delete_dir")
fn delete_dir(path: String) -> Result(Nil, FileError)

// --- Erlang FFI (direct, returns boolean) ---

@external(erlang, "filelib", "is_regular")
fn is_regular(path: String) -> Bool

@external(erlang, "filelib", "is_dir")
fn is_dir(path: String) -> Bool
