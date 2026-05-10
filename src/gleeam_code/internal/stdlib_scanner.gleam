import gleam/list
import gleam/string

pub type StdlibCall {
  StdlibCall(module: String, function: String)
}

pub fn scan(erl_source: String) -> List(StdlibCall) {
  erl_source
  |> string.to_graphemes
  |> scan_chars([], [])
  |> list.unique
}

fn scan_chars(
  chars: List(String),
  current: List(String),
  acc: List(StdlibCall),
) -> List(StdlibCall) {
  case chars {
    [] -> acc
    [c, ..rest] ->
      case is_identifier_char(c) {
        True -> scan_chars(rest, [c, ..current], acc)
        False ->
          case c {
            ":" ->
              case try_parse_module(list.reverse(current)) {
                Ok(module) -> scan_after_colon(rest, module, acc)
                Error(_) -> scan_chars(rest, [], acc)
              }
            _ -> scan_chars(rest, [], acc)
          }
      }
  }
}

fn scan_after_colon(
  chars: List(String),
  module: String,
  acc: List(StdlibCall),
) -> List(StdlibCall) {
  let #(func_chars, rest) = take_identifier(chars, [])
  let func_name = string.concat(func_chars)
  case func_name {
    "" -> scan_chars(rest, [], acc)
    _ -> {
      let call = StdlibCall(module: module, function: func_name)
      scan_chars(rest, [], [call, ..acc])
    }
  }
}

fn take_identifier(
  chars: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case chars {
    [] -> #(list.reverse(acc), [])
    [c, ..rest] ->
      case is_identifier_char(c) {
        True -> take_identifier(rest, [c, ..acc])
        False -> #(list.reverse(acc), chars)
      }
  }
}

fn try_parse_module(chars: List(String)) -> Result(String, Nil) {
  let name = string.concat(chars)
  case name {
    "" -> Error(Nil)
    _ ->
      case is_stdlib_module(name) {
        True -> Ok(name)
        False -> Error(Nil)
      }
  }
}

fn is_stdlib_module(name: String) -> Bool {
  name == "gleam_stdlib" || string.starts_with(name, "gleam@")
}

fn is_identifier_char(c: String) -> Bool {
  case c {
    "a"
    | "b"
    | "c"
    | "d"
    | "e"
    | "f"
    | "g"
    | "h"
    | "i"
    | "j"
    | "k"
    | "l"
    | "m"
    | "n"
    | "o"
    | "p"
    | "q"
    | "r"
    | "s"
    | "t"
    | "u"
    | "v"
    | "w"
    | "x"
    | "y"
    | "z" -> True
    "A"
    | "B"
    | "C"
    | "D"
    | "E"
    | "F"
    | "G"
    | "H"
    | "I"
    | "J"
    | "K"
    | "L"
    | "M"
    | "N"
    | "O"
    | "P"
    | "Q"
    | "R"
    | "S"
    | "T"
    | "U"
    | "V"
    | "W"
    | "X"
    | "Y"
    | "Z" -> True
    "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" -> True
    "_" | "@" -> True
    _ -> False
  }
}
