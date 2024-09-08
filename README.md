# clad


[![Package Version](https://img.shields.io/hexpm/v/clad)](https://hex.pm/packages/clad)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clad/)


Command line argument decoders for Gleam.

- Clad provides primitives to build a `dynamic.Decoder` for command line arguments.
- Arguments can be specified with long names (`--name`) or short names (`-n`).
- Values are decoded in the form `--name value` or `--name=value`.
- Boolean flags do not an explicit value. If the flag exists it is `True`, and if it is missing it is `False`. (i.e. `--verbose`)


## Usage

```sh
gleam add clad
```

This program is in the [examples directory](https://github.com/ryanmiville/clad/tree/main/test/examples)

```gleam
import argv
import clad
import gleam/bool
import gleam/dynamic
import gleam/int
import gleam/io
import gleam/string

type Order {
  Order(flavors: List(String), scoops: Int, cone: Bool)
}

fn order_decoder() {
  use flavors <- clad.arg("flavor", "f", dynamic.list(dynamic.string))
  use scoops <- clad.arg_with_default("scoops", "s", dynamic.int, default: 1)
  use cone <- clad.toggle("cone", "c")
  clad.decoded(Order(flavors:, scoops:, cone:))
}

pub fn main() {
  let order =
    order_decoder()
    |> clad.decode(argv.load().arguments)

  case order {
    Ok(order) -> take_order(order)
    _ ->
      io.println(
        "
Options:
  -f, --flavor <FLAVOR>  Flavors of ice cream
  -s, --scoops <SCOOPS>  Number of scoops per flavor [default: 1]
  -c, --cone             Put ice cream in a cone
      ",
      )
  }
}

fn take_order(order: Order) {
  let scoops = bool.guard(order.scoops == 1, " scoop", fn() { " scoops" })
  let container = bool.guard(order.cone, "cone", fn() { "cup" })
  let flavs = string.join(order.flavors, " and ")
  io.println(
    int.to_string(order.scoops)
    <> scoops
    <> " of "
    <> flavs
    <> " in a "
    <> container
    <> ", coming right up!",
  )
}
```

Run the program

```sh
❯ gleam run -m examples/ice_cream -- -f vanilla
1 scoop of vanilla in a cup, coming right up!
❯ gleam run -m examples/ice_cream -- --flavor vanilla --flavor chocolate
1 scoop of vanilla and chocolate in a cup, coming right up!
❯ gleam run -m examples/ice_cream -- --flavor vanilla --flavor chocolate --scoops 2 --cone
2 scoops of vanilla and chocolate in a cone, coming right up!
❯ gleam run -m examples/ice_cream --

Options:
  -f, --flavor <FLAVOR>  Flavors of ice cream
  -s, --scoops <SCOOPS>  Number of scoops per flavor [default: 1]
  -c, --cone             Put ice cream in a cone
```

Further documentation can be found at <https://hexdocs.pm/clad>.
