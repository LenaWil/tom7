
structure BytecodeParse :> BYTECODEPARSE =
struct

  open ByteTokens

  open Parsing

  open Bytecode

  structure LU = ListUtil

  infixr 4 << >>
  infixr 3 &&
  infix  2 -- ##
  infix  2 wth suchthat return guard when
  infixr 1 ||

  exception BytecodeParse of string

  fun **(s, p) = p ## (fn pos => raise BytecodeParse ("@" ^ Pos.toString pos ^ ": " ^ s))
  infixr 4 **

  (* as `KEYWORD -- punt "expected KEYWORD KEYWORD2" *)
  fun punt msg _ = msg ** fail

  val itos = Int.toString

  fun `w = satisfy (fn x => eq (x, w))

  fun ifmany f [x] = x
    | ifmany f l = f l

  val id = satisfy (fn ID s => true | _ => false) 
               wth (fn ID s => s | _ => raise BytecodeParse "impossible")

  val number = any when (fn INT i => SOME i | _ => NONE)

  val int = number wth IntConst.toInt

  (* labels are identifiers but also numbers *)
  val label = id || number wth (Int.toString o Word32.toInt)

  fun exp () =
    `PROJ >> label && $exp wth Project
  || id wth Var


  fun bopt p = `TNONE return NONE || `TSOME >> p wth SOME

  (* expect an integer, and then that many repetitions of the parser *)
  fun repeated p = 
    int -- (fn n =>
            let
              fun rep 0 = succeed nil
                | rep n = p && rep (n - 1) wth op ::
            in
              rep n
            end)

  val global = `ABSENT return Absent (* XXX or... *)

  val program =
    `PROGRAM >> bopt int && repeated global
    wth (fn (main, globals) => { main = main, globals = Vector.fromList globals } : program)

end
