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
