import argv
import gleam/io
import gleeam_code/init

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
