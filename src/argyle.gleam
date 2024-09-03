import gleam/bool
import gleam/dynamic.{type Decoder, DecodeError}
import gleam/float
import gleam/int
import gleam/json.{type Json}
import gleam/list
import gleam/result

pub fn decode(
  from arguments: List(String),
  using decoder: Decoder(t),
) -> Result(t, json.DecodeError) {
  use <- bool.guard(list.length(arguments) % 2 != 0, fail())
  let chunked = list.sized_chunk(arguments, 2)
  let chunked =
    list.map(chunked, fn(chunk) {
      case chunk {
        [k, v] -> #(k, parse_to_json(v))
        _ -> panic as "unreachable"
      }
    })
  json.object(chunked)
  |> json.to_string
  |> json.decode(decoder)
}

fn fail() {
  Error(
    json.UnexpectedFormat([
      DecodeError("even number of arguments", "odd number of arguments", []),
    ]),
  )
}

type Arg {
  Int(Int)
  Float(Float)
  Bool(Bool)
  String(String)
}

fn parse_to_json(input: String) -> Json {
  parse(input) |> to_json
}

fn parse(input: String) -> Arg {
  try_float(input)
  |> result.or(try_int(input))
  |> result.or(try_bool(input))
  |> result.unwrap(String(input))
}

fn try_float(input: String) {
  float.parse(input)
  |> result.map(Float)
}

fn try_int(input: String) {
  int.parse(input)
  |> result.map(Int)
}

fn try_bool(input: String) {
  case input {
    "true" | "True" -> Ok(Bool(True))
    "false" | "False" -> Ok(Bool(False))
    _ -> Error(Nil)
  }
}

fn to_json(arg: Arg) -> Json {
  case arg {
    Int(arg) -> json.int(arg)
    Float(arg) -> json.float(arg)
    Bool(arg) -> json.bool(arg)
    String(arg) -> json.string(arg)
  }
}
