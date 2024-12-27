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
    use name <- decode.field("name", decode.string)
    use age <- decode.field("age", decode.int)
    use enrolled <- decode.field("enrolled", decode.bool)
    use classes <- decode.field("class", decode.list(decode.string))
    use notes <- clad.positional_arguments()
    let notes = string.join(notes, " ")
    decode.success(Student(name:, age:, enrolled:, classes:, notes:))
  }

  // args: --name Lucy --age 8 --enrolled true --class math --class art -- Lucy is a star student!
  let result = clad.decode(argv.load().arguments, decoder)
  let assert Ok(Student(
    "Lucy",
    8,
    True,
    ["math", "art"],
    "Lucy is a star student!",
  )) = result
}
