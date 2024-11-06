import argv
import decode/zero.{type Decoder}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regex
import gleam/result
import gleam/string

type Argv {
  Argv(opts: Dict(String, Dynamic), positional: List(String))
}

pub fn main() {
  // parse(argv.load().arguments)
  // |> to_dynamic
  // |> string.inspect
  // |> io.println
  argv.load().arguments
  |> decode(decoder())
  |> string.inspect
  |> io.println
}

type Parsed {
  Parsed(
    a: Int,
    d: Bool,
    e: Int,
    f: Int,
    name: String,
    port: Int,
    rest: List(String),
  )
}

fn decoder() {
  use a <- zero.field("a", zero.int)
  use d <- zero.field("d", zero.bool)
  use e <- zero.field("e", zero.int)
  use f <- zero.field("f", zero.int)
  use name <- zero.field("name", zero.string)
  use port <- zero.field("port", zero.int)
  use rest <- positional_arguments
  zero.success(Parsed(a:, d:, e:, f:, name:, port:, rest:))
}

pub fn positional_arguments(
  next: fn(List(String)) -> Decoder(final),
) -> Decoder(final) {
  use args <- zero.field("clad_positional_arguments", zero.list(zero.string))
  next(args)
}

pub fn decode(
  args: List(String),
  decoder: Decoder(t),
) -> Result(t, List(dynamic.DecodeError)) {
  parse(args)
  |> to_dynamic
  |> zero.run(decoder)
}

fn parse(args: List(String)) -> Argv {
  let initial_argv = Argv(dict.new(), list.new())

  let argv = parse_args(args, initial_argv)
  Argv(..argv, positional: list.reverse(argv.positional))
}

fn to_dynamic(argv: Argv) -> Dynamic {
  argv.opts
  |> dict.insert("clad_positional_arguments", dynamic.from(argv.positional))
  |> dynamic.from
}

fn is_number(str: String) -> Bool {
  case
    regex.from_string("^[-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:[eE][-+]?\\d+)?$")
  {
    Ok(re) -> regex.check(re, str)
    Error(_) -> False
  }
}

fn is_alpha(str: String) -> Bool {
  case regex.from_string("^[a-zA-Z]+$") {
    Ok(re) -> regex.check(re, str)
    Error(_) -> False
  }
}

fn parse_args(args: List(String), argv: Argv) -> Argv {
  case args {
    [] -> argv
    [arg, ..rest] -> {
      let #(new_argv, rest) = parse_arg(arg, rest, argv)
      parse_args(rest, new_argv)
    }
  }
}

fn parse_arg(
  arg: String,
  rest: List(String),
  argv: Argv,
) -> #(Argv, List(String)) {
  case arg {
    "--" <> key -> {
      case string.split(key, "=") {
        [key, value] -> {
          let new_argv = set_arg(argv, key, value)
          #(new_argv, rest)
        }
        _ -> {
          case rest {
            [] | ["-" <> _, ..] -> {
              let new_argv = set_arg(argv, key, "true")
              #(new_argv, rest)
            }
            [next, ..rest] -> {
              let new_argv = set_arg(argv, key, next)
              #(new_argv, rest)
            }
          }
        }
      }
    }
    "-" <> key -> {
      case string.split(key, "=") {
        [key, value] -> {
          case string.pop_grapheme(key) {
            Ok(#(key, _)) -> {
              let new_argv = set_arg(argv, key, value)
              #(new_argv, rest)
            }
            _ -> #(argv, rest)
          }
        }
        _ -> {
          case rest {
            [] | ["-" <> _, ..] -> {
              let new_argv = parse_short_arg(key, argv, None)
              #(new_argv, rest)
            }
            [next, ..rest] -> {
              let new_argv = parse_short_arg(key, argv, Some(next))
              #(new_argv, rest)
            }
          }
        }
      }
    }
    _ -> {
      let new_argv = append_positional(argv, arg)
      #(new_argv, rest)
    }
  }
}

fn set_arg(argv: Argv, key: String, value: String) -> Argv {
  let opts = dict.insert(argv.opts, key, parse_value(value))
  Argv(..argv, opts:)
}

fn parse_short_arg(arg: String, argv: Argv, next: Option(String)) -> Argv {
  case string.length(arg) {
    1 -> {
      let value = option.unwrap(next, "true")
      let new_argv = set_arg(argv, arg, value)
      new_argv
    }
    _ -> {
      parse_cluster(arg, argv, next)
    }
  }
}

fn parse_cluster(cluster: String, argv: Argv, next: Option(String)) -> Argv {
  case string.pop_grapheme(cluster) {
    Ok(#(h, rest)) -> {
      case is_alpha(h), is_number(rest) {
        True, True -> set_arg(argv, h, rest)
        _, _ -> {
          let new_argv = set_arg(argv, h, "true")
          parse_short_arg(rest, new_argv, next)
        }
      }
    }
    _ -> argv
  }
}

fn append_positional(argv: Argv, value: String) -> Argv {
  let positional = [value, ..argv.positional]
  Argv(..argv, positional:)
}

fn parse_value(input: String) -> Dynamic {
  try_parse_float(input)
  |> result.or(try_parse_int(input))
  |> result.or(try_parse_bool(input))
  |> result.unwrap(dynamic.from(input))
}

fn try_parse_float(input: String) {
  float.parse(input)
  |> result.map(dynamic.from)
}

fn try_parse_int(input: String) {
  int.parse(input)
  |> result.map(dynamic.from)
}

fn try_parse_bool(input: String) {
  case input {
    "true" | "True" -> Ok(dynamic.from(True))
    "false" | "False" -> Ok(dynamic.from(False))
    _ -> Error(Nil)
  }
}
