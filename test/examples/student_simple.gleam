import argv
import clad
import decode/zero
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
    use name <- zero.field("name", zero.string)
    use age <- zero.field("age", zero.int)
    use enrolled <- zero.field("enrolled", zero.bool)
    use classes <- zero.field("class", zero.list(zero.string))
    use notes <- clad.positional_arguments()
    let notes = string.join(notes, " ")
    zero.success(Student(name:, age:, enrolled:, classes:, notes:))
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
