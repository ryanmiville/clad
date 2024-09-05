import clad/internal/args
import gleam/dict
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Decoder, type Dynamic, DecodeError,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/result

/// Run a decoder on a list of command line arguments, decoding the value if it
/// is of the desired type, or returning errors.
///
/// This function works well with the argv package.
///
/// # Examples
/// ```gleam
/// dynamic.decode2(
///   SignUp,
///   clad.string(long_name: "name", short_name: "n"),
///   clad.string(long_name: "email", short_name: "e"),
/// )
/// |> clad.decode(["-n", "Lucy", "--email=lucy@example.com"])
/// // -> Ok(SignUp(name: "Lucy", email: "lucy@example.com"))
/// ```
/// with argv:
/// ```gleam
/// dynamic.decode2(
///   SignUp,
///   clad.string(long_name: "name", short_name: "n"),
///   clad.string(long_name: "email", short_name: "e"),
/// )
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

/// A decoder that decodes String arguments.
/// # Examples
/// ```gleam
/// clad.string(long_name: "name", short_name: "n")
/// |> clad.decode(["-n", "Lucy"])
/// // -> Ok("Lucy")
/// ```
pub fn string(
  long_name long_name: String,
  short_name short_name: String,
) -> Decoder(String) {
  arg(long_name, short_name, dynamic.string)
}

/// A decoder that decodes Int arguments.
/// # Examples
/// ```gleam
/// clad.int(long_name: "count", short_name: "c")
/// |> clad.decode(["-c", "2"])
/// // -> Ok(2)
/// ```
pub fn int(
  long_name long_name: String,
  short_name short_name: String,
) -> Decoder(Int) {
  arg(long_name, short_name, dynamic.int)
}

/// A decoder that decodes Float arguments.
/// # Examples
/// ```gleam
/// clad.float(long_name: "price", short_name: "p")
/// |> clad.decode(["--price", "2.50"])
/// // -> Ok(2.5)
/// ```
pub fn float(
  long_name long_name: String,
  short_name short_name: String,
) -> Decoder(Float) {
  arg(long_name, short_name, dynamic.float)
}

/// A decoder that decodes Bool arguments.
/// # Examples
/// ```gleam
/// clad.bool(long_name: "verbose", short_name: "v")
/// |> clad.decode(["-v"])
/// // -> Ok(True)
/// ```
/// ```gleam
/// clad.bool(long_name: "verbose", short_name: "v")
/// |> clad.decode([])
/// // -> Ok(False)
/// ```
pub fn bool(
  long_name long_name: String,
  short_name short_name: String,
) -> Decoder(Bool) {
  arg(long_name, short_name, dynamic.bool) |> with_default(False)
}

/// Provide a default value for a decoder.
/// # Examples
/// ```gleam
/// clad.int(long_name: "count", short_name: "c") |> clad.with_default(1)
/// |> clad.decode([])
/// // -> Ok(1)
/// ```
/// ```gleam
/// clad.int(long_name: "count", short_name: "c") |> clad.with_default(1)
/// |> clad.decode(["-c", "2"])
/// // -> Ok(2)
/// ```
pub fn with_default(decoder: Decoder(t), default: t) -> Decoder(t) {
  fn(data) {
    use _ <- result.try_recover(decoder(data))
    Ok(default)
  }
}

fn arg(
  long_name long_name: String,
  short_name short_name: String,
  of decoder: Decoder(t),
) -> Decoder(t) {
  dynamic.any([
    do_long_name(long_name, decoder),
    do_short_name(short_name, decoder),
  ])
}

fn do_long_name(long_name: String, decoder: Decoder(t)) {
  dynamic.field("--" <> long_name, decoder)
}

fn do_short_name(short_name: String, decoder: Decoder(t)) {
  dynamic.field("-" <> short_name, decoder)
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
  dynamic.from(dict.from_list(entries))
}
