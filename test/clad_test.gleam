import clad
import decode/zero
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
  clad.opt("foo", "f", zero.string, zero.success)
  |> clad.decode(["-f", "hello"], _)
  |> should.equal(Ok("hello"))

  clad.opt("foo", "f", zero.string, zero.success)
  |> clad.decode(["--foo", "hello"], _)
  |> should.equal(Ok("hello"))

  zero.field("b", zero.int, zero.success)
  |> clad.decode(["-b", "1"], _)
  |> should.equal(Ok(1))

  clad.flag("baz", "z", zero.success)
  |> clad.decode(["-z"], _)
  |> should.equal(Ok(True))

  clad.flag("baz", "z", zero.success)
  |> clad.decode([], _)
  |> should.equal(Ok(False))

  zero.field("q", zero.float, zero.success)
  |> clad.decode(["-q", "2.5"], _)
  |> should.equal(Ok(2.5))

  zero.field("z", zero.float, zero.success)
  |> clad.decode([], _)
  |> should.be_error

  let decoder = {
    use foo <- clad.opt("foo", "f", zero.string)
    use bar <- clad.opt("bar", "b", zero.int)
    use baz <- clad.flag("baz", "z")
    use qux <- clad.opt("qux", "q", zero.float)
    use names <- clad.positional_arguments
    zero.success(Options(foo:, bar:, baz:, qux:, names:))
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
  zero.field("f", zero.string, zero.success)
  |> clad.decode(["--bar", "hello"], _)
  |> should.equal(Error([DecodeError("Field", "Nothing", ["f"])]))

  zero.field("foo", zero.string, zero.success)
  |> clad.decode(["--foo", "1"], _)
  |> should.equal(Error([DecodeError("String", "Int", ["foo"])]))

  let decoder = {
    use foo <- clad.opt("foo", "f", zero.string)
    use bar <- clad.opt("bar", "b", zero.int)
    use baz <- clad.flag("baz", "z")
    use qux <- clad.opt("qux", "q", zero.float)
    use names <- clad.positional_arguments
    zero.success(Options(foo:, bar:, baz:, qux:, names:))
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
  clad.opt("foo", "f", zero.string, zero.success)
  |> clad.decode(["--foo", "hello"], _)
  |> should.equal(Ok("hello"))

  clad.opt("foo", "f", zero.string, zero.success)
  |> clad.decode(["-f", "hello"], _)
  |> should.equal(Ok("hello"))
  // clad.opt("foo", "f", zero.string, zero.success)
  // |> clad.decode([], _)
  // |> should.equal(Error([DecodeError("String", "Nothing", ["f"])]))

  // clad.opt("foo", "f", zero.optional(zero.string), zero.success)
  // |> clad.decode(["-f", "hello"], _)
  // |> should.equal(Ok(Some("hello")))

  // clad.opt("foo", "f", zero.optional(zero.string), zero.success)
  // |> clad.decode([], _)
  // |> should.equal(Ok(None))
}

pub fn flag_test() {
  let decoder = {
    use verbose <- clad.flag("verbose", "v")
    zero.success(verbose)
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
    use a <- zero.field("a", zero.bool)
    use b <- zero.field("b", zero.int)
    use c <- clad.positional_arguments()
    zero.success(#(a, b, c))
  }

  clad.decode(["-ab5", "foo", "--hello", "world", "bar", "baz"], decoder)
  |> should.equal(Ok(#(True, 5, ["foo", "bar", "baz"])))

  clad.decode(["-ab5", "foo", "--", "--hello", "world", "bar", "baz"], decoder)
  |> should.equal(Ok(#(True, 5, ["foo", "--hello", "world", "bar", "baz"])))
}

pub fn list_test() {
  let decoder = {
    use list <- zero.field("a", clad.list(zero.int))
    zero.success(list)
  }

  clad.decode(["-a", "1", "-a", "2", "-a", "3"], decoder)
  |> should.equal(Ok([1, 2, 3]))

  clad.decode(["-a", "1"], decoder)
  |> should.equal(Ok([1]))

  clad.decode([], decoder)
  |> should.be_error
}
