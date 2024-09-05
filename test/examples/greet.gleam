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

pub fn main() {
  let args =
    dynamic.decode3(
      Args,
      clad.string(long_name: "name", short_name: "n"),
      clad.int(long_name: "count", short_name: "c") |> clad.with_default(1),
      clad.bool(long_name: "scream", short_name: "s"),
    )
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
