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
