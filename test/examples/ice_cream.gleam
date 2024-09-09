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
