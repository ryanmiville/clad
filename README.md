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
import gleam/dynamic
import gleam/io
import gleam/list
import gleam/string

type Args {
  Args(name: String, count: Int, scream: Bool)
}

fn greet(args: Args) {
  let greeting = case args.scream {
    True -> "HEY " <> string.uppercase(args.name) <> "!"
    False -> "Hello, " <> args.name <> "."
  }
  list.repeat(greeting, args.count) |> list.each(io.println)
}

fn args_decoder() {
  use name <- clad.arg(long_name: "name", short_name: "n", of: dynamic.string)
  use count <- clad.arg_with_default(
    long_name: "count",
    short_name: "c",
    of: dynamic.int,
    default: 1,
  )
  use scream <- clad.toggle(long_name: "scream", short_name: "s")
  clad.decoded(Args(name:, count:, scream:))
}

pub fn main() {
  let args =
    args_decoder()
    |> clad.decode(argv.load().arguments)

  case args {
    Ok(args) -> greet(args)
    _ ->
      io.println(
        "
Options:
  -n, --name <NAME>    Name of the person to greet
  -c, --count <COUNT>  Number of times to greet [default: 1]
  -s, --scream         Whether or not to scream greeting
      ",
      )
  }
}
```

Run the program

```sh
❯ gleam run -m examples/greet -- -n Joe
Hello, Joe.
❯ gleam run -m examples/greet -- --name=Joe
Hello, Joe.
❯ gleam run -m examples/greet -- --name Joe --count 3 --scream
HEY JOE!
HEY JOE!
HEY JOE!
❯ gleam run -m examples/greet

Options:
  -n, --name <NAME>    Name of the person to greet
  -c, --count <COUNT>  Number of times to greet [default: 1]
  -s, --scream         Whether or not to scream greeting
```

Further documentation can be found at <https://hexdocs.pm/clad>.
