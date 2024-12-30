import clad
import gleam/dynamic/decode.{DecodeError}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

type Options {
  Options(foo: String, bar: Int, baz: Bool, qux: Float, names: List(String))
}

pub fn decode_test() {
  clad.opt("foo", "f", decode.string, decode.success)
  |> clad.decode(["-f", "hello"], _)
  |> should.equal(Ok("hello"))

  clad.opt("foo", "f", decode.string, decode.success)
  |> clad.decode(["--foo", "hello"], _)
  |> should.equal(Ok("hello"))

  decode.field("b", decode.int, decode.success)
  |> clad.decode(["-b", "1"], _)
  |> should.equal(Ok(1))

  clad.flag("baz", "z", decode.success)
  |> clad.decode(["-z"], _)
  |> should.equal(Ok(True))

  clad.flag("baz", "z", decode.success)
  |> clad.decode([], _)
  |> should.equal(Ok(False))

  decode.field("q", decode.float, decode.success)
  |> clad.decode(["-q", "2.5"], _)
  |> should.equal(Ok(2.5))

  decode.field("z", decode.float, decode.success)
  |> clad.decode([], _)
  |> should.be_error

  let decoder = {
    use foo <- clad.opt("foo", "f", decode.string)
    use bar <- clad.opt("bar", "b", decode.int)
    use baz <- clad.flag("baz", "z")
    use qux <- clad.opt("qux", "q", decode.float)
    use names <- clad.positional_arguments
    decode.success(Options(foo:, bar:, baz:, qux:, names:))
  }

  // all fields set
  let args = ["--foo", "hello", "-b", "1", "--baz", "-q", "2.5", "Lucy", "Joe"]
  clad.decode(args, decoder)
  |> should.equal(Ok(Options("hello", 1, True, 2.5, ["Lucy", "Joe"])))

  // using '='
  let args = ["--foo=hello", "-b=1", "--baz", "-q", "2.5", "Lucy"]
  clad.decode(args, decoder)
  |> should.equal(Ok(Options("hello", 1, True, 2.5, ["Lucy"])))

  // missing flag field
  let args = ["--foo", "hello", "--bar", "1", "-q", "0.0"]
  clad.decode(args, decoder)
  |> should.equal(Ok(Options("hello", 1, False, 0.0, [])))

  // explicit setting flag to 'true'
  let args = ["--foo", "hello", "--bar", "1", "-z", "true", "-q", "0.0", "Lucy"]
  clad.decode(args, decoder)
  |> should.equal(Ok(Options("hello", 1, True, 0.0, ["Lucy"])))

  // explicit setting flag to 'false'
  let args = [
    "--foo", "hello", "--bar", "1", "-z", "false", "-q", "0.0", "Lucy",
  ]
  clad.decode(args, decoder)
  |> should.equal(Ok(Options("hello", 1, False, 0.0, ["Lucy"])))
}

pub fn decode_errors_test() {
  decode.field("f", decode.string, decode.success)
  |> clad.decode(["--bar", "hello"], _)
  |> should.equal(Error([DecodeError("Field", "Nothing", ["f"])]))

  decode.field("foo", decode.string, decode.success)
  |> clad.decode(["--foo", "1"], _)
  |> should.equal(Error([DecodeError("String", "Int", ["foo"])]))

  let decoder = {
    use foo <- clad.opt("foo", "f", decode.string)
    use bar <- clad.opt("bar", "b", decode.int)
    use baz <- clad.flag("baz", "z")
    use qux <- clad.opt("qux", "q", decode.float)
    use names <- clad.positional_arguments
    decode.success(Options(foo:, bar:, baz:, qux:, names:))
  }

  // no fields
  let args = []
  clad.decode(args, decoder)
  |> should.equal(
    Error([
      DecodeError("Field", "Nothing", ["f"]),
      DecodeError("Field", "Nothing", ["b"]),
      DecodeError("Field", "Nothing", ["q"]),
    ]),
  )

  // missing first field
  let args = ["-b", "1"]
  clad.decode(args, decoder)
  |> should.equal(
    Error([
      DecodeError("Field", "Nothing", ["f"]),
      DecodeError("Field", "Nothing", ["q"]),
    ]),
  )

  // missing second field
  let args = ["--foo", "hello"]
  clad.decode(args, decoder)
  |> should.equal(
    Error([
      DecodeError("Field", "Nothing", ["b"]),
      DecodeError("Field", "Nothing", ["q"]),
    ]),
  )

  // wrong type
  let args = ["--foo", "hello", "-b", "world"]
  clad.decode(args, decoder)
  |> should.equal(
    Error([
      DecodeError("Int", "String", ["b"]),
      DecodeError("Field", "Nothing", ["q"]),
    ]),
  )
}

pub fn opt_test() {
  clad.opt("foo", "f", decode.string, decode.success)
  |> clad.decode(["--foo", "hello"], _)
  |> should.equal(Ok("hello"))

  clad.opt("foo", "f", decode.string, decode.success)
  |> clad.decode(["-f", "hello"], _)
  |> should.equal(Ok("hello"))
  // clad.opt("foo", "f", decode.string, decode.success)
  // |> clad.decode([], _)
  // |> should.equal(Error([DecodeError("String", "Nothing", ["f"])]))

  // clad.opt("foo", "f", decode.optional(decode.string), decode.success)
  // |> clad.decode(["-f", "hello"], _)
  // |> should.equal(Ok(Some("hello")))

  // clad.opt("foo", "f", decode.optional(decode.string), decode.success)
  // |> clad.decode([], _)
  // |> should.equal(Ok(None))
}

pub fn flag_test() {
  let decoder = {
    use verbose <- clad.flag("verbose", "v")
    decode.success(verbose)
  }

  clad.decode(["-v"], decoder)
  |> should.equal(Ok(True))

  clad.decode([], decoder)
  |> should.equal(Ok(False))

  clad.decode(["-v", "true"], decoder)
  |> should.equal(Ok(True))

  clad.decode(["-v", "false"], decoder)
  |> should.equal(Ok(False))

  clad.decode(["-v", "123"], decoder)
  |> should.be_error
}

pub fn positional_arguments_test() {
  let decoder = {
    use a <- decode.field("a", decode.bool)
    use b <- decode.field("b", decode.int)
    use c <- clad.positional_arguments()
    decode.success(#(a, b, c))
  }

  clad.decode(["-ab5", "foo", "--hello", "world", "bar", "baz"], decoder)
  |> should.equal(Ok(#(True, 5, ["foo", "bar", "baz"])))

  clad.decode(["-ab5", "foo", "--", "--hello", "world", "bar", "baz"], decoder)
  |> should.equal(Ok(#(True, 5, ["foo", "--hello", "world", "bar", "baz"])))
}

pub fn list_test() {
  let decoder = {
    use list <- decode.field("a", clad.list(decode.int))
    decode.success(list)
  }

  clad.decode(["-a", "1", "-a", "2", "-a", "3"], decoder)
  |> should.equal(Ok([1, 2, 3]))

  clad.decode(["-a", "1"], decoder)
  |> should.equal(Ok([1]))

  clad.decode([], decoder)
  |> should.be_error
}

pub fn optional_opt_test() {
  let decoder = {
    use name <- clad.optional_opt("name", "n", "Lucy", decode.string)
    decode.success(name)
  }

  clad.decode(["--name", "Joe"], decoder)
  |> should.equal(Ok("Joe"))

  clad.decode(["-n", "Joe"], decoder)
  |> should.equal(Ok("Joe"))

  clad.decode([], decoder)
  |> should.equal(Ok("Lucy"))
}
