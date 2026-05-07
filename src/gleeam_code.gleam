import argv
import gleam/io
import gleeam_code/auth
import gleeam_code/fetch
import gleeam_code/init
import gleeam_code/submit
import gleeam_code/test_cmd

pub type GlobalOpts {
  GlobalOpts(directory: String)
}

pub type Command {
  Init
  Auth
  Fetch(target: String)
  Test(target: String)
  Submit(target: String)
}

pub fn parse_global(args: List(String)) -> #(GlobalOpts, List(String)) {
  case args {
    ["-C", dir, ..rest] -> #(GlobalOpts(directory: dir), rest)
    _ -> #(GlobalOpts(directory: "."), args)
  }
}

pub fn route(args: List(String)) -> Result(Command, String) {
  case args {
    ["init"] -> Ok(Init)
    ["auth"] -> Ok(Auth)
    ["fetch", target] -> Ok(Fetch(target))
    ["test", target] -> Ok(Test(target))
    ["submit", target] -> Ok(Submit(target))
    ["fetch"] | ["test"] | ["submit"] -> Error("Missing argument: <slug-or-number>")
    _ -> Error(usage())
  }
}

pub fn main() -> Nil {
  let #(opts, rest) = parse_global(argv.load().arguments)
  case route(rest) {
    Ok(Init) ->
      case init.run(opts.directory, io.println) {
        Ok(_) -> Nil
        Error(msg) -> io.println("Error: " <> msg)
      }
    Ok(Auth) ->
      case auth.run(opts.directory, io.println, auth.stdin_read_line) {
        Ok(_) -> Nil
        Error(msg) -> io.println("Error: " <> msg)
      }
    Ok(Fetch(target)) ->
      case fetch.run(opts.directory, target, io.println) {
        Ok(_) -> Nil
        Error(msg) -> io.println("Error: " <> msg)
      }
    Ok(Test(target)) ->
      case test_cmd.run(opts.directory, target, io.println) {
        Ok(_) -> Nil
        Error(msg) -> io.println("Error: " <> msg)
      }
    Ok(Submit(target)) ->
      case submit.run(opts.directory, target, io.println) {
        Ok(_) -> Nil
        Error(msg) -> io.println("Error: " <> msg)
      }
    Error(msg) -> io.println(msg)
  }
}

pub fn usage() -> String {
  "glc - Gleam LeetCode CLI

Usage:
  glc init                    Initialize project
  glc auth                    Save LeetCode session cookie
  glc fetch <slug-or-number>  Fetch problem and generate files
  glc test <slug-or-number>   Run tests for a problem
  glc submit <slug-or-number> Submit solution to LeetCode"
}
