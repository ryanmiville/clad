//// This module encodes a list of command line arguments as a `dynamic.Dynamic` and
//// provides functions to decode those arguments using a `decode/zero.Decoder`.
////
//// # Encoding
////
//// The following arguments:
//// ```sh
//// -x=3 -y 4 -n5 -abc --hello world --list one --list two --beep=boop foo bar baz
//// ```
//// will be encoded as a `dynamic.Dynamic` in this shape:
//// ```json
//// {
////   "name": 3,
////   "y": 4,
////   "a": True,
////   "b": True,
////   "c": True,
////   "hello": "world",
////   "list": ["one", "two"],
////   "beep": "boop",
////   "_": ["foo", "bar", "baz"]
//// }
//// ```
////
//// # Decoding
////
//// Arguments can be decoded with a normal `zero.Decoder`
////
//// ```gleam
//// // args: --name Lucy --age 8 --enrolled true --class math --class art
////
//// let decoder = {
////   use name <- zero.field("name", zero.string)
////   use age <- zero.field("age", zero.int)
////   use enrolled <- zero.field("enrolled", zero.bool)
////   use classes <- zero.field("class", zero.list(zero.string))
////   zero.success(Student(name:, age:, enrolled:, classes:))
//// }
////
//// let result = clad.decode(args, decoder)
//// assert result == Ok(Student("Lucy", 8, True, ["math", "art"]))
//// ```
//// Clad provides additional functions to support some common CLI behaviors.
////
//// ## Lists
////
//// Clad encodes the arguments without any information about the target record.
//// Unlike other formats like JSON, CLI argument types can be ambiguous. For
//// instance, if there's only one string provided for a `List(String)` argument,
//// Clad will encode it as a String.
////
//// To handle this case, use the `list()` function.
////
//// ```gleam
//// // args: --name Lucy --age 8 --enrolled true --class math
////
//// let decoder = {
////   use name <- zero.field("name", zero.string)
////   use age <- zero.field("age", zero.int)
////   use enrolled <- zero.field("enrolled", zero.bool)
////   use classes <- zero.field("class", clad.list(zero.string))
////   zero.success(Student(name:, age:, enrolled:, classes:))
//// }
////
//// let result = clad.decode(args, decoder)
//// assert result == Ok(Student("Lucy", 8, True, ["math"]))
//// ```
//// ## Boolean Flags
////
//// CLI's commonly represent boolean flags just by the precense or absence of the
//// option. Since Clad has no knowledge of your target record, it cannot encode
//// missing flags as False.
////
//// Clad provides the `flag()` decoder to handle this case.
////
//// ```gleam
//// // args1: --name Lucy --age 8 --class math --class art --enrolled
//// // args2: --name Bob --age 3 --class math
////
//// let decoder = {
////   use name <- zero.field("name", zero.string)
////   use age <- zero.field("age", zero.int)
////   use enrolled <- zero.field("enrolled", clad.flag())
////   use classes <- zero.field("class", clad.list(zero.string))
////   zero.success(Student(name:, age:, enrolled:, classes:))
//// }
////
//// let result = clad.decode(args1, decoder)
//// assert result == Ok(Student("Lucy", 8, True, ["math", "art"]))
////
//// let result = clad.decode(args2, decoder)
//// assert result == Ok(Student("Bob", 3, False, ["math"]))
//// ```
////
//// ## Alternate Names
////
//// It is also common for CLI's to support long names and short names for options
//// (e.g. `--name` and `-n`).
////
//// Clad provides the `opt()` function for this.
////
//// ```gleam
//// // args1: -n Lucy -a 8 -e -c math -c art
//// // args2: --name Bob --age 3 --class math
////
//// let decoder = {
////   use name <- clad.opt(long_name: "name", short_name: "n", zero.string)
////   use age <- clad.opt(long_name: "age", short_name: "a", zero.int)
////   use enrolled <- clad.opt(long_name: "enrolled", short_name: "e" clad.flag())
////   use classes <- clad.opt(long_name: "class", short_name: "c", clad.list(zero.string))
////   zero.success(Student(name:, age:, enrolled:, classes:))
//// }
////
//// let result = clad.decode(args1, decoder)
//// assert result == Ok(Student("Lucy", 8, True, ["math", "art"]))
////
//// let result = clad.decode(args2, decoder)
//// assert result == Ok(Student("Bob", 3, False, ["math"]))
//// ```
////
//// ## Positional Arguments
////
//// A CLI may also support positional arguments. These are any arguments that are
//// not attributed to a named option. Clad provides the `positional_arguments()` decoder to
//// retrieve these values. All arguments followed by a `--` will be added to the positional arguemnts.
////
//// ```gleam
//// // args1: -n Lucy -ea8 -c math -c art -- Lucy is a star student!
//// // args2: --name Bob who is --age 3 --class math Bob -- -idk
////
//// let decoder = {
////   use name <- clad.opt("name", "n", zero.string)
////   use age <- clad.opt("age", "a", zero.int)
////   use enrolled <- clad.opt("enrolled", "e" clad.flag())
////   use classes <- clad.opt(long_name: "class", short_name: "c", clad.list(zero.string))
////   use notes <- clad.positional_arguments()
////   let notes = string.join(notes, " ")
////   zero.success(Student(name:, age:, enrolled:, classes:, notes:))
//// }
////
//// let result = clad.decode(args1, decoder)
//// let assert Ok(Student(
////   "Lucy",
////   8,
////   True,
////   ["math", "art"],
////   "Lucy is a star student!",
//// )) = result
////
//// let result = clad.decode(args2, decoder)
//// assert result == Ok(Student("Bob", 3, False, ["math"], "who is Bob -idk"))
//// ```

import decode/zero.{type Decoder}
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/result
import gleam/string

const positional_arg_name = "_"

type State {
  State(
    opts: Dict(String, Dynamic),
    list_opts: Dict(String, List(Dynamic)),
    positional: List(String),
  )
}

/// Run a decoder on a list of command line arguments, decoding the value if it
/// is of the desired type, or returning errors.
///
/// This function pairs well with the [argv package](https://github.com/lpil/argv).
///
/// # Examples
/// ```gleam
/// // args: --name Lucy --email=lucy@example.com
///
/// let decoder = {
///   use name <- zero.field("name", dynamic.string)
///   use email <- zero.field("email", dynamic.string),
///   clad.decoded(SignUp(name:, email:))
/// }
///
/// let result = clad.decode(argv.load().arguments, decoder)
/// assert result == Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
/// ```
pub fn decode(
  args: List(String),
  decoder: Decoder(t),
) -> Result(t, List(dynamic.DecodeError)) {
  parse(args)
  |> to_dynamic
  |> zero.run(decoder)
}

/// Get all of the unnamed, positional arguments
///
/// Clad encodes all arguments following a `--` as positional arguments.
/// ```gleam
/// let decoder = {
///   use positional <- clad.positional_arguments
///   zero.success(positional)
/// }
/// let result = clad.decode(["-a1", "hello", "-b", "2", "world"], decoder)
/// assert result == Ok(["hello", "world"])
///
/// let result = clad.decode(["-a1", "-b", "2"], decoder)
/// assert result == Ok([])
///
/// let result = clad.decode(["-a1", "--", "-b", "2"], decoder)
/// assert result == Ok(["-b", "2"])
/// ```
pub fn positional_arguments(
  next: fn(List(String)) -> Decoder(final),
) -> Decoder(final) {
  use args <- zero.field(positional_arg_name, zero.list(zero.string))
  next(args)
}

/// A Bool decoder that returns False if value is not present
/// ```gleam
/// let decoder = {
///   use verbose <- zero.field("v", clad.flag())
///   zero.success(verbose)
/// }
/// let result = clad.decode(["-v"], decoder)
/// assert result == Ok(True)
///
/// let result = clad.decode(["-v", "false"], decoder)
/// assert result == Ok(False)
///
/// let result = clad.decode([], decoder)
/// assert result == Ok(False)
/// ```
pub fn flag() -> Decoder(Bool) {
  zero.bool
  |> zero.optional
  |> zero.map(option.unwrap(_, False))
}

fn optional_field(
  field_name: name,
  field_decoder: Decoder(t),
  next: fn(Option(t)) -> Decoder(final),
) -> Decoder(final) {
  let decoding_function = fn(data: Dynamic) {
    use <- bool.guard(dynamic.classify(data) == "Nil", Ok(None))

    case zero.run(data, zero.optional(field_decoder)) {
      Ok(None) -> {
        case zero.run(data, field_decoder) {
          Ok(v) -> Ok(Some(v))
          Error(_) -> Ok(None)
        }
      }
      other -> other
    }
  }

  let decoder = zero.new_primitive_decoder(decoding_function, None)

  zero.field(field_name, decoder, next)
}

/// Decode a command line option by either a long name or short name
/// ```gleam
/// let decoder = {
///   use name <- clad.opt("name", "n", zero.string)
///   zero.success(name)
/// }
///
/// let result = clad.decode(["--name", "Lucy"], decoder)
/// assert result == Ok("Lucy")
///
/// let result = clad.decode(["-n", "Lucy"], decoder)
/// assert result == Ok("Lucy")
/// ```
pub fn opt(
  long_name: String,
  short_name: String,
  field_decoder: Decoder(t),
  next: fn(t) -> Decoder(final),
) -> Decoder(final) {
  use value <- optional_field(long_name, field_decoder)
  case value {
    Some(v) -> next(v)
    None -> zero.field(short_name, field_decoder, next)
  }
}

/// A `List` decoder that will wrap a single item in a list.
/// Clad has no knowledge of the target record, so single item lists will be
/// encoded as the inner type rather than a list.
/// ```gleam
/// let decoder = {
///   use classes <- zero.field("class", clad.list(zero.string))
///   zero.success(classes)
/// }
/// let result = clad.decode(["--class", "art"], decoder)
/// assert result == Ok(["art"])
/// ```
pub fn list(of inner: Decoder(a)) -> Decoder(List(a)) {
  let single = inner |> zero.map(list.wrap)
  zero.one_of(zero.list(inner), [single])
}

fn parse(args: List(String)) -> State {
  let state = State(dict.new(), dict.new(), list.new())

  let state = parse_args(args, state)
  State(..state, positional: list.reverse(state.positional))
}

fn to_dynamic(state: State) -> Dynamic {
  let list_opts =
    dict.map_values(state.list_opts, fn(_, values) {
      list.reverse(values) |> dynamic.from
    })

  state.opts
  |> dict.merge(list_opts)
  |> dict.insert(positional_arg_name, dynamic.from(state.positional))
  |> dynamic.from
}

fn is_number(str: String) -> Bool {
  case regexp.from_string("^[-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)$") {
    Ok(re) -> regexp.check(re, str)
    Error(_) -> False
  }
}

fn is_alpha(str: String) -> Bool {
  case regexp.from_string("^[a-zA-Z]+$") {
    Ok(re) -> regexp.check(re, str)
    Error(_) -> False
  }
}

fn parse_args(args: List(String), state: State) -> State {
  case args {
    [] -> state
    [arg, ..rest] -> {
      let #(new_state, rest) = parse_arg(arg, rest, state)
      parse_args(rest, new_state)
    }
  }
}

fn parse_arg(
  arg: String,
  rest: List(String),
  state: State,
) -> #(State, List(String)) {
  case arg {
    "--" -> {
      let positional = [list.reverse(rest), state.positional] |> list.flatten
      let new_state = State(..state, positional:)
      #(new_state, [])
    }
    "--" <> key -> {
      case string.split(key, "=") {
        [key, value] -> {
          let new_state = set_arg(state, key, value)
          #(new_state, rest)
        }
        _ -> {
          case rest {
            [] | ["-" <> _, ..] -> {
              let new_state = set_arg(state, key, "true")
              #(new_state, rest)
            }
            [next, ..rest] -> {
              let new_state = set_arg(state, key, next)
              #(new_state, rest)
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
              let new_state = set_arg(state, key, value)
              #(new_state, rest)
            }
            _ -> #(state, rest)
          }
        }
        _ -> {
          case rest {
            [] | ["-" <> _, ..] -> {
              case parse_short(key, state) {
                #(new_state, Some(k)) -> #(set_arg(new_state, k, "true"), rest)
                #(new_state, None) -> #(new_state, rest)
              }
            }
            [next, ..new_rest] -> {
              case parse_short(key, state) {
                #(new_state, Some(k)) -> #(
                  set_arg(new_state, k, next),
                  new_rest,
                )
                #(new_state, None) -> #(new_state, rest)
              }
            }
          }
        }
      }
    }
    _ -> {
      let new_state = append_positional(state, arg)
      #(new_state, rest)
    }
  }
}

fn set_arg(state: State, key: String, value: String) -> State {
  let in_opt = dict.get(state.opts, key)
  let in_list = dict.get(state.list_opts, key)
  case in_opt, in_list {
    Error(_), Error(_) -> {
      let opts = dict.insert(state.opts, key, parse_value(value))
      State(..state, opts:)
    }
    Ok(v), _ -> {
      let opts = dict.delete(state.opts, key)
      let list_opts = dict.insert(state.list_opts, key, [parse_value(value), v])
      State(..state, opts:, list_opts:)
    }
    _, Ok(values) -> {
      let list_opts =
        dict.insert(state.list_opts, key, [parse_value(value), ..values])
      State(..state, list_opts:)
    }
  }
}

fn parse_short(arg: String, state: State) -> #(State, Option(String)) {
  case string.pop_grapheme(arg) {
    Ok(#(h, "")) -> #(state, Some(h))
    Ok(#(h, rest)) -> {
      case is_alpha(h), is_number(rest) {
        True, True -> #(set_arg(state, h, rest), None)
        _, _ -> {
          let new_state = set_arg(state, h, "true")
          parse_short(rest, new_state)
        }
      }
    }
    _ -> #(state, None)
  }
}

fn parse_short_arg(
  arg: String,
  state: State,
  next: Option(String),
) -> #(State, List(String)) {
  case string.length(arg) {
    1 -> {
      let value = option.unwrap(next, "true")
      let new_state = set_arg(state, arg, value)
      #(new_state, [])
    }
    _ -> {
      parse_cluster(arg, state, next)
    }
  }
}

fn parse_cluster(
  cluster: String,
  state: State,
  next: Option(String),
) -> #(State, List(String)) {
  case string.pop_grapheme(cluster) {
    Ok(#(h, rest)) -> {
      case is_alpha(h), is_number(rest) {
        True, True -> #(
          set_arg(state, h, rest),
          option.map(next, list.wrap) |> option.unwrap([]),
        )
        _, _ -> {
          let new_state = set_arg(state, h, "true")
          parse_short_arg(rest, new_state, next)
        }
      }
    }
    _ -> #(state, option.map(next, list.wrap) |> option.unwrap([]))
  }
}

fn append_positional(state: State, value: String) -> State {
  let positional = [value, ..state.positional]
  State(..state, positional:)
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
