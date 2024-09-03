import gleam/bool
import gleam/dynamic.{type DecodeErrors, type Decoder, type Dynamic, DecodeError}
import gleam/json
import gleam/list

pub fn decode(
  from arguments: List(String),
  using decoder: Decoder(t),
) -> Result(t, json.DecodeError) {
  use <- bool.guard(list.length(arguments) % 2 != 0, fail())
  let chunked = list.sized_chunk(arguments, 2)
  let chunked =
    list.map(chunked, fn(chunk) {
      case chunk {
        [k, v] -> #(k, json.string(v))
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
