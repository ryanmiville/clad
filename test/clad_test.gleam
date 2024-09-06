import clad
import clad/internal/args
import gleam/dynamic.{DecodeError}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

type Options {
  Options(foo: String, bar: Int, baz: Bool, qux: Float, names: List(String))
}

pub fn decode_test() {
  clad.string(long_name: "foo", short_name: "f", then: clad.decoded)
  |> clad.decode(["-f", "hello"])
  |> should.equal(Ok("hello"))

  clad.int(long_name: "bar", short_name: "b", then: clad.decoded)
  |> clad.decode(["-b", "1"])
  |> should.equal(Ok(1))

  clad.bool(long_name: "baz", short_name: "z", then: clad.decoded)
  |> clad.decode(["-z"])
  |> should.equal(Ok(True))

  clad.bool(long_name: "baz", short_name: "z", then: clad.decoded)
  |> clad.decode([])
  |> should.equal(Ok(False))

  clad.float(long_name: "qux", short_name: "q", then: clad.decoded)
  |> clad.decode(["-q", "2.5"])
  |> should.equal(Ok(2.5))

  clad.float(long_name: "qux", short_name: "q", then: clad.decoded)
  |> clad.decode([])
  |> should.be_error

  clad.float_with_default(
    long_name: "qux",
    short_name: "q",
    default: 0.0,
    then: clad.decoded,
  )
  |> clad.decode([])
  |> should.equal(Ok(0.0))

  clad.float_with_default(
    long_name: "qux",
    short_name: "q",
    default: 0.0,
    then: clad.decoded,
  )
  |> clad.decode(["-q", "2.5"])
  |> should.equal(Ok(2.5))

  clad.list("foo", "f", dynamic.string, clad.decoded)
  |> clad.decode(["-f", "hello", "--foo", "world"])
  |> should.equal(Ok(["world", "hello"]))

  let decoder = {
    use foo <- clad.string(long_name: "foo", short_name: "f")
    use bar <- clad.int(long_name: "bar", short_name: "b")
    use baz <- clad.bool(long_name: "baz", short_name: "z")
    use qux <- clad.float_with_default(
      long_name: "qux",
      short_name: "q",
      default: 0.0,
    )
    use names <- clad.list(
      long_name: "name",
      short_name: "n",
      of: dynamic.string,
    )
    clad.decoded(Options(foo:, bar:, baz:, qux:, names:))
  }

  // all fields set
  let args = [
    "--foo", "hello", "-b", "1", "--baz", "-q", "2.5", "-n", "Lucy", "-n", "Joe",
  ]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, True, 2.5, ["Lucy", "Joe"])))

  // using '='
  let args = ["--foo=hello", "-b=1", "--baz", "-q", "2.5", "-n", "Lucy"]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, True, 2.5, ["Lucy"])))

  // missing field with default value
  let args = ["--foo", "hello", "--bar", "1", "--baz", "--name", "Lucy"]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, True, 0.0, ["Lucy"])))

  // missing flag field
  let args = ["--foo", "hello", "--bar", "1", "-n", "Lucy"]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, False, 0.0, ["Lucy"])))

  // explicit setting flag to 'true'
  let args = ["--foo", "hello", "--bar", "1", "-z", "true", "-n", "Lucy"]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, True, 0.0, ["Lucy"])))

  // explicit setting flag to 'false'
  let args = ["--foo", "hello", "--bar", "1", "-z", "false", "-n", "Lucy"]
  clad.decode(decoder, args)
  |> should.equal(Ok(Options("hello", 1, False, 0.0, ["Lucy"])))
}

pub fn decode_errors_test() {
  clad.string(long_name: "foo", short_name: "f", then: clad.decoded)
  |> clad.decode(["--bar", "hello"])
  |> should.equal(Error([DecodeError("field", "nothing", ["--foo"])]))

  clad.string(long_name: "foo", short_name: "f", then: clad.decoded)
  |> clad.decode(["--foo", "1"])
  |> should.equal(Error([DecodeError("String", "Int", ["--foo"])]))

  clad.string_with_default("foo", "f", "hello", clad.decoded)
  |> clad.decode(["--foo", "1"])
  |> should.equal(Error([DecodeError("String", "Int", ["--foo"])]))

  clad.string(long_name: "foo", short_name: "f", then: clad.decoded)
  |> clad.decode(["-f", "hello", "-f", "world"])
  |> should.equal(Error([DecodeError("String", "List", ["--foo"])]))

  clad.list(
    long_name: "foo",
    short_name: "f",
    of: dynamic.string,
    then: clad.decoded,
  )
  |> clad.decode(["-f", "1", "-f", "world"])
  |> should.equal(Error([DecodeError("String", "Int", ["-f", "*"])]))

  let decoder = {
    use foo <- clad.string(long_name: "foo", short_name: "f")
    use bar <- clad.int(long_name: "bar", short_name: "b")
    use baz <- clad.bool(long_name: "baz", short_name: "z")
    use qux <- clad.float_with_default(
      long_name: "qux",
      short_name: "q",
      default: 0.0,
    )
    use names <- clad.list("name", "n", dynamic.string)
    clad.decoded(Options(foo:, bar:, baz:, qux:, names:))
  }

  // no fields
  let args = []
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("field", "nothing", ["--foo"])]))

  // missing first field
  let args = ["-b", "1"]
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("field", "nothing", ["--foo"])]))

  // missing second field
  let args = ["--foo", "hello"]
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("field", "nothing", ["--bar"])]))

  // wrong type
  let args = ["--foo", "hello", "-b", "world"]
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("Int", "String", ["-b"])]))

  // default field wrong type
  let args = ["--foo", "hello", "-b", "1", "--baz", "--qux", "world"]
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("Float", "String", ["--qux"])]))

  // list field wrong type
  let args = [
    "--foo", "hello", "-b", "1", "--baz", "--qux", "2.5", "-n", "Lucy", "-n",
    "100",
  ]
  clad.decode(decoder, args)
  |> should.equal(Error([DecodeError("String", "Int", ["-n", "*"])]))
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
