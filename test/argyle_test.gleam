import argyle
import gleam/dynamic
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn decode_test() {
  let args = ["--foo", "hello", "--bar", "1"]
  let dec =
    dynamic.decode2(
      Options,
      dynamic.field("--foo", dynamic.string),
      dynamic.field("--bar", dynamic.string),
    )
  argyle.decode(args, dec)
  |> should.equal(Ok(Options("hello", "1")))
}

type Options {
  Options(foo: String, bar: String)
}
