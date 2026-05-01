import argv
import gleam/io

pub type Command {
  Init
  Auth
  Fetch(target: String)
  Test(target: String)
  Submit(target: String)
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
  case route(argv.load().arguments) {
    Ok(Init) -> io.println("TODO: glc init")
    Ok(Auth) -> io.println("TODO: glc auth")
    Ok(Fetch(target)) -> io.println("TODO: glc fetch " <> target)
    Ok(Test(target)) -> io.println("TODO: glc test " <> target)
    Ok(Submit(target)) -> io.println("TODO: glc submit " <> target)
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
