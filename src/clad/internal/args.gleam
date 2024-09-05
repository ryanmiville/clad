import gleam/bool
import gleam/list
import gleam/string

pub fn split_equals(arguments: List(String)) -> List(String) {
  use arg <- list.flat_map(arguments)
  use <- bool.guard(!is_name(arg), [arg])
  case string.split_once(arg, "=") {
    Ok(#(arg, value)) -> [arg, value]
    Error(_) -> [arg]
  }
}

pub fn add_bools(arguments: List(String)) -> List(String) {
  do_add_bools(arguments, [])
}

pub fn do_add_bools(arguments: List(String), acc: List(String)) -> List(String) {
  case arguments {
    [] -> acc
    [arg] -> list.append(acc, one_arg(arg))
    [first, second, ..rest] -> {
      case is_name(first), is_name(second) {
        True, True ->
          do_add_bools([second, ..rest], list.append(acc, [first, "true"]))
        True, False -> do_add_bools(rest, list.append(acc, [first, second]))
        _, _ -> do_add_bools([second, ..rest], acc)
      }
    }
  }
}

fn one_arg(arg: String) {
  case is_name(arg) {
    True -> [arg, "true"]
    False -> [arg]
  }
}

fn is_name(input: String) -> Bool {
  case string.to_graphemes(input) {
    ["-", "-", next, ..] -> is_alpha(next)
    ["-", next, ..] -> is_alpha(next)
    _ -> False
  }
}

fn is_alpha(character: String) -> Bool {
  case string.to_graphemes(character) {
    [grapheme] -> string.lowercase(grapheme) != string.uppercase(grapheme)
    _ -> False
  }
}
