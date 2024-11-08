# clad


[![Package Version](https://img.shields.io/hexpm/v/clad)](https://hex.pm/packages/clad)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clad/)


Command line argument decoders for Gleam.

Clad aims to make it as easy as possible to parse command line arguments in
Gleam. The goal is to support simple to medium complexity command line
interfaces while staying as minimal as possible. It is inspired by
[minimist](https://github.com/minimistjs/minimist) and
[gleam/json](https://hexdocs.pm/gleam_json/)


## Usage

```sh
gleam add clad
```

This program is in the [examples directory](https://github.com/ryanmiville/clad/tree/main/test/examples)

```gleam
import argv
import clad
import decode/zero

pub type Student {
  Student(name: String, age: Int, enrolled: Bool, classes: List(String))
}

pub fn main() {
  let decoder = {
    use name <- zero.field("name", zero.string)
    use age <- zero.field("age", zero.int)
    use enrolled <- zero.field("enrolled", zero.bool)
    use classes <- clad.positional_arguments()
    zero.success(Student(name:, age:, enrolled:, classes:))
  }

  // args: --name Lucy --age 8 --enrolled true math science art
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student("Lucy", 8, True, ["math", "science", "art"])) = result
}
```

Or, for more flexibility:

```gleam
import argv
import clad
import decode/zero

pub type Student {
  Student(name: String, age: Int, enrolled: Bool, classes: List(String))
}

pub fn main() {
  let decoder = {
    use name <- clad.opt("name", "n", zero.string)
    use age <- clad.opt("age", "a", zero.int)
    use enrolled <- clad.opt("enrolled", "e", clad.flag())
    use classes <- clad.positional_arguments()
    zero.success(Student(name:, age:, enrolled:, classes:))
  }

  // args: --name=Lucy -ea8 math science art
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student("Lucy", 8, True, ["math", "science", "art"])) = result
}
```

Further documentation can be found at <https://hexdocs.pm/clad>.
