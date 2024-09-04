import gleam/dict
import gleam/dynamic.{
  type DecodeError, type DecodeErrors, type Decoder, type Dynamic, DecodeError,
}
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import internal/args

pub fn decode(
  from arguments: List(String),
  using decoder: Decoder(t),
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

pub fn flag(long_name long_name: String, short_name short_name: String) {
  arg(long_name, short_name, dynamic.bool) |> with_default(False)
}

pub fn arg(
  long_name long_name: String,
  short_name short_name: String,
  of decoder: Decoder(t),
) {
  dynamic.any([
    do_long_name(long_name, decoder),
    do_short_name(short_name, decoder),
  ])
}

pub fn with_default(decoder: Decoder(t), default: t) -> Decoder(t) {
  fn(data) {
    use _ <- result.try_recover(decoder(data))
    Ok(default)
  }
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
  try_float(input)
  |> result.or(try_int(input))
  |> result.or(try_bool(input))
  |> result.unwrap(dynamic.from(input))
}

fn try_float(input: String) {
  float.parse(input)
  |> result.map(dynamic.from)
}

fn try_int(input: String) {
  int.parse(input)
  |> result.map(dynamic.from)
}

fn try_bool(input: String) {
  case input {
    "true" | "True" -> Ok(dynamic.from(True))
    "false" | "False" -> Ok(dynamic.from(False))
    _ -> Error(Nil)
  }
}

fn object(entries: List(#(String, Dynamic))) -> dynamic.Dynamic {
  dynamic.from(dict.from_list(entries))
}
