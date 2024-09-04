import clad
import gleam/dynamic
import gleeunit
import gleeunit/should
import internal/args

pub fn main() {
  gleeunit.main()
}

type Options {
  Options(foo: String, bar: Int, baz: Bool, qux: Float)
}

pub fn decode_test() {
  let dec =
    dynamic.decode4(
      Options,
      clad.arg(long_name: "foo", short_name: "f", of: dynamic.string),
      clad.arg(long_name: "bar", short_name: "b", of: dynamic.int),
      clad.flag(long_name: "baz", short_name: "z"),
      clad.arg(long_name: "qux", short_name: "q", of: dynamic.float)
        |> clad.with_default(0.0),
    )

  // all fields set
  let args = ["--foo", "hello", "-b", "1", "--baz", "-q", "2.5"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, True, 2.5)))

  // using '='
  let args = ["--foo=hello", "-b=1", "--baz", "-q", "2.5"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, True, 2.5)))

  // missing field with default value
  let args = ["--foo", "hello", "--bar", "1", "--baz"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, True, 0.0)))

  // missing flag field
  let args = ["--foo", "hello", "--bar", "1"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, False, 0.0)))

  // explicit setting flag to 'true'
  let args = ["--foo", "hello", "--bar", "1", "-z", "true"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, True, 0.0)))

  // explicit setting flag to 'false'
  let args = ["--foo", "hello", "--bar", "1", "-z", "false"]
  clad.decode(args, dec)
  |> should.equal(Ok(Options("hello", 1, False, 0.0)))
}

pub fn add_bools_test() {
  let args = []
  args.add_bools(args)
  |> should.equal([])

  let args = ["--foo"]
  args.add_bools(args)
  |> should.equal(["--foo", "true"])

  let args = ["--foo", "-b"]
  args.add_bools(args)
  |> should.equal(["--foo", "true", "-b", "true"])

  let args = ["-f", "--bar", "hello"]
  args.add_bools(args)
  |> should.equal(["-f", "true", "--bar", "hello"])

  let args = ["--foo", "hello", "--bar", "world"]
  args.add_bools(args)
  |> should.equal(["--foo", "hello", "--bar", "world"])

  let args = ["--foo", "hello", "--bar"]
  args.add_bools(args)
  |> should.equal(["--foo", "hello", "--bar", "true"])
}

pub fn split_equals_test() {
  let args = []
  args.split_equals(args)
  |> should.equal([])

  let args = ["--foo="]
  args.split_equals(args)
  |> should.equal(["--foo", ""])

  let args = ["--foo=hello", "-b=world"]
  args.split_equals(args)
  |> should.equal(["--foo", "hello", "-b", "world"])

  let args = ["-f=hello", "--bar", "world"]
  args.split_equals(args)
  |> should.equal(["-f", "hello", "--bar", "world"])

  let args = ["--foo", "hello", "--bar", "world"]
  args.split_equals(args)
  |> should.equal(["--foo", "hello", "--bar", "world"])

  // '=' is in value
  let args = ["--foo", "hello=world", "--bar=world"]
  args.split_equals(args)
  |> should.equal(["--foo", "hello=world", "--bar", "world"])

  // only splits the first '='
  let args = ["--foo=hello=world", "--bar"]
  args.split_equals(args)
  |> should.equal(["--foo", "hello=world", "--bar"])
}
