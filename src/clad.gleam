//// This module encodes a list of command line arguments as a `dynamic.Dynamic` and
//// provides primitives to build a `dynamic.Decoder` to decode records from command line
//// arguments.
////
//// Arguments are parsed from long names (`--name`) or short names (`-n`).
//// Values are decoded in the form `--name value` or `--name=value`.
//// Boolean flags do not need an explicit value. If the flag exists it is `True`,
//// and `False` if it is missing. (i.e. `--verbose`)
////
//// # Examples
////
//// ## Encoding
////
//// Clad encodes the arguments without any knowledge of your target record.
//// It cannot know if a field is intended to be a single, basic type or a
//// list with a single item. Therefore it encodes everything as a list.
////
//// All of the following get encoded the same:
////
//// ```sh
//// --name Lucy --count 3 --verbose
//// --name Lucy --count 3 --verbose true
//// --name=Lucy --count=3 --verbose=true
//// ```
////
//// ```gleam
//// // {"--name": ["Lucy"], "--count": [3], "--verbose": [true]}
//// ```
////
//// Since the target record is unknown, missing Bool arguments are not encoded at all:
////
//// ```sh
//// --name Lucy --count 3
//// ```
//// ```gleam
//// // {"--name": ["Lucy"], "--count": [3]}
//// ```
////
//// There is no way to know that a long name and a short name are the same argument when encoding.
//// So they are encoded as separate fields:
////
//// ```sh
//// --name Lucy -n Joe
//// ```
//// ```gleam
//// // {"--name": ["Lucy"], "-n": ["Joe"]}
//// ```
////
//// ## Decoding Fields
////
//// Clad provides the `arg` function to handle these quirks of the Dynamic representation.
////
//// ```sh
//// --name Lucy
//// ```
//// ```gleam
//// use name <- clad.arg(long_name: "name", short_name: "n", of: dynamic.string)
//// // -> "Lucy"
//// ```
//// ```sh
//// -n Lucy
//// ```
//// ```gleam
//// use name <- clad.arg(long_name: "name", short_name: "n", of: dynamic.string)
//// // -> "Lucy"
//// ```
//// ```sh
//// -n Lucy -n Joe
//// ```
//// ```gleam
//// use names <- clad.arg("name", "n", of: dynamic.list(dynamic.string))
//// // -> ["Lucy", "Joe"]
//// ```
////
//// Clad's `toggle` decoder only requires the name. Missing arguments are `False`:
////
//// ```sh
//// --verbose
//// ```
//// ```gleam
//// use verbose <- clad.toggle(long_name: "verbose", short_name: "v")
//// // -> True
//// ```
//// ```sh
//// --name Lucy
//// ```
//// ```gleam
//// use verbose <- clad.toggle(long_name: "verbose", short_name: "v")
//// // -> False
//// ```
////
//// It's common for CLI's to have default values for arguments.
//// This can be accomplished with a `dynamic.optional`, but
//// the `arg_with_default` function is provided for convenience:
////
//// ```sh
//// --name Lucy
//// ```
//// ```gleam
//// use count <- clad.arg_with_default(
////   long_name: "count",
////   short_name: "c",
////   of: dynamic.int,
////   default: 1,
//// )
//// // -> 1
//// ```
//// ## Decoding Records
//// Clad's API is heavily inspired by (read: copied from) [toy](https://github.com/Hackder/toy).
//// ```gleam
//// fn arg_decoder() {
////   use name <- clad.arg("name", "n", dynamic.string)
////   use count <- clad.arg_with_default("count", "c", dynamic.int, 1)
////   use verbose <- clad.toggle("verbose", "v")
////   clad.decoded(Args(name:, count:, verbose:))
//// }
//// ```
////
//// And then use it to decode the arguments:
//// ```gleam
//// // arguments: ["--name", "Lucy", "--count", "3", "--verbose"]
////
//// let args =
////   arg_decoder()
////   |> clad.decode(arguments)
//// let assert Ok(Args("Lucy", 3, True)) = args
//// ```
////
//// Here are a few examples of arguments that would decode the same:
////
//// ```sh
//// --name Lucy --count 3 --verbose
//// --name=Lucy -c 3 -v=true
//// -n=Lucy -c=3 -v
//// ```
//// # Errors
////
//// Clad returns the first error it encounters. If multiple fields have errors, only the first one will be returned.
////
//// ```gleam
//// // arguments: ["--count", "three"]
////
//// let args =
////   arg_decoder()
////   |> clad.decode(arguments)
//// let assert Error([DecodeError("field", "nothing", ["--name"])]) = args
//// ```
////
//// If a field has a default value, but the argument is supplied with the incorrect type, an error will be returned rather than falling back on the default value.
////
//// ```gleam
//// // arguments: ["-n", "Lucy" "-c", "three"]
////
//// let args =
////   arg_decoder()
////   |> clad.decode(arguments)
//// let assert Error([DecodeError("Int", "String", ["-c"])]) = args
//// ```

import clad/internal/args
import gleam/dict.{type Dict}
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Decoder, type Dynamic, DecodeError,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result

/// Run a decoder on a list of command line arguments, decoding the value if it
/// is of the desired type, or returning errors.
///
/// This function pairs well with the [argv package](https://github.com/lpil/argv).
///
/// # Examples
/// ```gleam
/// {
///   use name <- clad.arg("name", "n", dynamic.string)
///   use email <- clad.arg("email", "e", dynamic.string),
///   clad.decoded(SignUp(name:, email:))
/// }
/// |> clad.decode(["-n", "Lucy", "--email=lucy@example.com"])
/// // -> Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
/// ```
/// with argv:
/// ```gleam
/// {
///   use name <- clad.arg("name", "n", dynamic.string)
///   use email <- clad.arg("email", "e", dynamic.string),
///   clad.decoded(SignUp(name:, email:))
/// }
/// |> clad.decode(argv.load().arguments)
/// ```
pub fn decode(
  decoder: Decoder(t),
  arguments: List(String),
) -> Result(t, DecodeErrors) {
  use arguments <- result.try(prepare_arguments(arguments))
  object(arguments)
  |> decoder
}

fn prepare_arguments(
  arguments: List(String),
) -> Result(List(#(String, Dynamic)), DecodeErrors) {
  let arguments =
    arguments
    |> args.split_equals
    |> args.add_bools
  let chunked = list.sized_chunk(arguments, 2)
  let chunked =
    list.map(chunked, fn(chunk) {
      case chunk {
        [k, v] -> Ok(#(k, parse(v)))
        _ -> fail("key/value pairs", "dangling arg")
      }
    })

  result.all(chunked)
}

/// Creates a decoder which directly returns the provided value.
/// Used to collect decoded values into a record.
/// # Examples
/// ```gleam
/// pub fn user_decoder() {
///   use name <- clad.string("name", "n")
///   clad.decoded(User(name:))
/// }
/// ```
pub fn decoded(value: a) -> Decoder(a) {
  fn(_) { Ok(value) }
}

/// A decoder that decodes Bool arguments.
///
/// Toggles do not need an explicit value. If the flag exists it is `True`,
/// and `False` if it is missing. (i.e. `--verbose`)
///
/// # Examples
/// ```gleam
/// // data: ["-v"]
/// use verbose <- clad.toggle(long_name: "verbose", short_name: "v")
/// // -> True
/// ```
/// ```gleam
/// // data: []
/// use verbose <- clad.toggle(long_name: "verbose", short_name: "v")
/// // -> False
/// ```
pub fn toggle(
  long_name long_name: String,
  short_name short_name: String,
  then next: fn(Bool) -> Decoder(a),
) -> Decoder(a) {
  arg_with_default(long_name, short_name, dynamic.bool, False, next)
}

/// Decode an argument, returning a default value if the argument does not exist
///
/// # Examples
/// ```gleam
/// // data: ["--name", "Lucy"]
/// use name <- clad.arg(
///   long_name: "name",
///   short_name: "n",
///   of: dynamic.string,
///   default: "Joe"
/// )
/// // -> "Lucy"
/// ```
/// ```gleam
/// // data: []
/// use name <- clad.arg(
///   long_name: "name",
///   short_name: "n",
///   of: dynamic.string,
///   default: "Joe"
/// )
/// // -> "Joe"
/// ```
pub fn arg_with_default(
  long_name long_name: String,
  short_name short_name: String,
  of decoder: Decoder(a),
  default default: a,
  then next: fn(a) -> Decoder(b),
) {
  use res <- arg(long_name, short_name, dynamic.optional(decoder))
  next(option.unwrap(res, default))
}

type Arg {
  Arg(long_name: String, short_name: String)
  LongName(String)
  ShortName(String)
}

type DecodeResult =
  Result(Option(List(Dynamic)), List(DecodeError))

type ArgResults {
  ArgResults(
    long_name: String,
    short_name: String,
    long_result: DecodeResult,
    short_result: DecodeResult,
  )
  LongNameResults(long_name: String, long_result: DecodeResult)
  ShortNameResults(short_name: String, short_result: DecodeResult)
}

/// Decode an argument by either its long name (`--name`) or short name (`-n`).
///
/// List arguments are represented by repeated values.
///
/// # Examples
/// ```gleam
/// // data: ["--name", "Lucy"]
/// use name <- clad.arg(long_name: "name", short_name: "n", of: dynamic.string)
/// // -> "Lucy"
/// ```
/// ```gleam
/// // data: ["-n", "Lucy"]
/// use name <- clad.arg(long_name: "name", short_name: "n", of: dynamic.string)
/// // -> "Lucy"
/// ```
/// ```gleam
/// // data: ["-n", "Lucy", "-n", "Joe"]
/// use name <- clad.arg(
///   long_name: "name",
///   short_name: "n",
///   of: dynamic.list(dynamic.string)
/// )
/// // -> ["Lucy", "Joe"]
/// ```
pub fn arg(
  long_name long_name: String,
  short_name short_name: String,
  of decoder: Decoder(a),
  then next: fn(a) -> Decoder(b),
) -> Decoder(b) {
  fn(data) {
    let long_name = "--" <> long_name
    let short_name = "-" <> short_name
    let first = do_arg(Arg(long_name, short_name), decoder)
    use a <- result.try(first(data))
    next(a)(data)
  }
}

/// Decode an argument only by a short name
///
/// # Examples
/// ```gleam
/// // data: ["-n", "Lucy"]
/// use name <- clad.short_name("n", dynamic.string)
/// // -> "Lucy"
/// ```
pub fn short_name(
  short_name: String,
  decoder: Decoder(a),
  next: fn(a) -> Decoder(b),
) {
  fn(data) {
    let first = do_arg(ShortName("-" <> short_name), decoder)
    use a <- result.try(first(data))
    next(a)(data)
  }
}

/// Decode an argument only by a long name
///
/// # Examples
/// ```gleam
/// // data: ["--name", "Lucy"]
/// use name <- clad.long_name("name", dynamic.string)
/// // -> "Lucy"
/// ```
pub fn long_name(
  long_name: String,
  decoder: Decoder(a),
  next: fn(a) -> Decoder(b),
) {
  fn(data) {
    let first = do_arg(LongName("--" <> long_name), decoder)
    use a <- result.try(first(data))
    next(a)(data)
  }
}

fn do_arg(arg: Arg, using decoder: Decoder(t)) -> Decoder(t) {
  fn(data) {
    let arg_res = case arg {
      Arg(long_name, short_name) -> {
        ArgResults(
          long_name,
          short_name,
          dynamic.optional_field(long_name, dynamic.shallow_list)(data),
          dynamic.optional_field(short_name, dynamic.shallow_list)(data),
        )
      }
      LongName(name) -> {
        LongNameResults(
          name,
          dynamic.optional_field(name, dynamic.shallow_list)(data),
        )
      }
      ShortName(name) -> {
        ShortNameResults(
          name,
          dynamic.optional_field(name, dynamic.shallow_list)(data),
        )
      }
    }

    case arg_res {
      ArgResults(l, s, lr, sr) -> do_arg_results(l, s, lr, sr, decoder)
      LongNameResults(n, r) -> do_single_name_results(n, r, decoder)
      ShortNameResults(n, r) -> do_single_name_results(n, r, decoder)
    }
  }
}

fn do_arg_results(
  long_name: String,
  short_name: String,
  long_result: DecodeResult,
  short_result: DecodeResult,
  decoder: Decoder(t),
) {
  case long_result, short_result {
    Ok(Some(a)), Ok(Some(b)) ->
      do_list(long_name, decoder)(dynamic.from(list.append(a, b)))
    Ok(Some([a])), Ok(None) -> do_single(long_name, decoder)(a)
    Ok(None), Ok(Some([a])) -> do_single(short_name, decoder)(a)
    Ok(Some(a)), Ok(None) -> do_list(long_name, decoder)(dynamic.from(a))
    Ok(None), Ok(Some(a)) -> do_list(short_name, decoder)(dynamic.from(a))
    Ok(None), Ok(None) ->
      do_single(long_name, decoder)(dynamic.from(None))
      |> result.replace_error(missing_field(long_name))
    Error(e1), Error(e2) -> Error(list.append(e1, e2))
    Error(e), _ | _, Error(e) -> Error(e)
  }
}

fn do_single_name_results(
  name: String,
  decode_result: DecodeResult,
  decoder: Decoder(t),
) {
  case decode_result {
    Ok(Some([a])) -> do_single(name, decoder)(a)
    Ok(Some(a)) -> do_list(name, decoder)(dynamic.from(a))
    Ok(None) ->
      do_single(name, decoder)(dynamic.from(None))
      |> result.replace_error(missing_field(name))
    Error(e) -> Error(e)
  }
}

fn do_single(name: String, decoder: Decoder(t)) -> Decoder(t) {
  fn(data) {
    use first_error <- result.try_recover(decoder(data))
    let decoder = do_list(name, decoder)
    use second_error <- result.map_error(decoder(dynamic.from([data])))
    case first_error {
      [DecodeError(..) as e] -> [DecodeError(..e, path: [name, ..e.path])]
      _ -> second_error
    }
  }
}

fn do_list(name: String, decoder: Decoder(t)) -> Decoder(t) {
  fn(data) {
    use error <- result.map_error(decoder(data))
    case error {
      [DecodeError(..) as e] -> [DecodeError(..e, path: [name, ..e.path])]
      _ -> error
    }
  }
}

fn fail(expected: String, found: String) {
  Error([DecodeError(expected, found, [])])
}

fn parse(input: String) -> Dynamic {
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

fn object(entries: List(#(String, Dynamic))) -> dynamic.Dynamic {
  do_object_list(entries, dict.new())
}

fn do_object_list(
  entries: List(#(String, Dynamic)),
  acc: Dict(String, Dynamic),
) -> Dynamic {
  case entries {
    [] -> dynamic.from(acc)
    [#(k, _), ..rest] -> {
      case dict.has_key(acc, k) {
        True -> do_object_list(rest, acc)
        False -> {
          let values = list.key_filter(entries, k)
          do_object_list(rest, dict.insert(acc, k, dynamic.from(values)))
        }
      }
    }
  }
}

// fn failure(
//   expected: String,
//   found: String,
//   path: List(String),
// ) -> Result(t, DecodeErrors) {
//   Error([DecodeError(expected, found, path)])
// }

// fn missing_field_error(long_name: String) {
//   failure("field", "nothing", ["--" <> long_name])
// }

fn missing_field(name: String) {
  [DecodeError("field", "nothing", [name])]
}
