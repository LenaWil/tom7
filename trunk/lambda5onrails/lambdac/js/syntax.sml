
(* shorthands for various javascript syntax *)
structure JSSyntax =
struct

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  open Javascript
  open Joint
  structure A = AssignOp
  structure B = BinaryOp
  structure U = UnaryOp
  val % = Vector.fromList
  val $ = Id.fromString

  (* subscript an array by a literal integer *)
  fun Subscripti (a, i) = Select { object = a, property = String ` String.fromString ` Int.toString i }
  fun Sele ob exp = Select { object = ob, property = exp }

  fun Bind (id, e) = Var ` %[(id, SOME e)]

  fun RealNumber r =
    if r < 0.0
    then Unary { exp = Number ` Number.fromReal ` Real.~ r,
                 oper = U.Neg }
    else Number ` Number.fromReal r

  fun Sel ob field =  SelectId { object = ob, property = Id.fromString field }

end
