structure JSCodegen :> JSCODEGEN =
struct

  infixr 9 `
  fun a ` b = a b

  exception JSCodegen of string

  open Javascript
  open Joint
  structure A = AssignOp
  structure B = BinaryOp
  structure U = UnaryOp
  val % = Vector.fromList
  val $ = Id.fromString

  fun generate { labels, labelmap } (lab, SOME global) =
    FunctionDec { args = %[],
                  name = $lab,
                  body = %[Throw ` String ` String.fromString "unimplemented"] }
    | generate _ (lab, NONE) = 
    FunctionDec { args = %[],
                  name = $lab,
                  body = %[Throw ` String ` 
                           String.fromString "error: should never call this in js"] }

end