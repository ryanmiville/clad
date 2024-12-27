# clad


[![Package Version](https://img.shields.io/hexpm/v/clad)](https://hex.pm/packages/clad)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/clad/)


Command line argument decoders for Gleam.

Clad makes it easy and familiar to parse command line arguments in
Gleam. The goal is to support simple-to-medium complexity command line
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
import gleam/dynamic/decode

pub type Student {
  Student(name: String, age: Int, enrolled: Bool, classes: List(String))
}

pub fn main() {
  let decoder = {
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use enrolled <- decode.field("enrolled", decode.bool)
    use classes <- decode.field("class", decode.list(decode.string))
    decode.success(Student(name:, age:, enrolled:, classes:))
  }

  // args: --name Lucy --age 8 --enrolled true --class math --class art
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student("Lucy", 8, True, ["math", "art"])) = result
}
```

Or, for more flexibility:

```gleam
import argv
import clad
import gleam/dynamic/decode

pub type Student {
  Student(name: String, age: Int, enrolled: Bool, classes: List(String))
}

pub fn main() {
  let decoder = {
    use name <- clad.opt("name", "n", decode.string)
    use age <- clad.opt("age", "a", decode.int)
    use enrolled <- clad.flag("enrolled", "e")
    use classes <- clad.opt("class", "c", clad.list(decode.string))
    decode.success(Student(name:, age:, enrolled:, classes:))
  }

  // args: --name=Lucy -ea8 -c math -c art
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student("Lucy", 8, True, ["math", "art"])) = result
}
```

Further documentation can be found at <https://hexdocs.pm/clad>.
