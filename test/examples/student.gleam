import argv
import clad
import gleam/dynamic/decode
import gleam/string

pub type Student {
  Student(
    name: String,
    age: Int,
    enrolled: Bool,
    classes: List(String),
    notes: String,
  )
}

pub fn main() {
  let decoder = {
    use name <- clad.opt("name", "n", decode.string)
    use age <- clad.opt("age", "a", decode.int)
    use enrolled <- clad.flag("enrolled", "e")
    use classes <- clad.opt("class", "c", clad.list(decode.string))
    use notes <- clad.positional_arguments()
    let notes = string.join(notes, " ")
    decode.success(Student(name:, age:, enrolled:, classes:, notes:))
  }

  // args: --name=Lucy -ea8 -c math  -c art -- Lucy is a star student!
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student(
    "Lucy",
    8,
    True,
    ["math", "art"],
    "Lucy is a star student!",
  )) = result
}
