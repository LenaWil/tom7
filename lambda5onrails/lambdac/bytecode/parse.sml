
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

  val strlit = any when (fn STRING s => SOME s | _ => NONE)

  (* labels are identifiers but also numbers *)
  val label = id || number wth (Int.toString o Word32.toInt)

  (* expect an integer, and then that many repetitions of the parser *)
  fun repeated p = 
    int -- (fn n =>
            let
              fun rep 0 = succeed nil
                | rep n = p && rep (n - 1) wth op ::
            in
              rep n
            end)

  fun exp () =
       `PROJ >> label && $exp wth Project
    || `RECORD >> repeated (label && $exp) wth Record
    || `PRIMCALL >> label && repeated ($exp) wth Primcall
    || number wth Int
    || strlit wth String
    || id wth Var


  and stmt () =
       `END return End
    || `BIND >> id && $exp && $stmt wth (fn (a, (b, c)) => Bind (a, b, c))
    || `JUMP >> $exp && $exp && repeated ($exp) wth (fn (a, (b, c)) => Jump (a, b, c))
    || `ERROR >> strlit wth Error
    || `CASE >> $exp && id && repeated (label && $stmt) && $stmt
         wth (fn (a, (b, (c, d))) => Case { obj = a, var = b, arms = c, def = d})

  fun bopt p = `TNONE return NONE || `TSOME >> p wth SOME

  val global = 
       `ABSENT return Absent
    || `FUNDEC >> repeated (repeated id && $stmt) wth (FunDec o Vector.fromList)

  val program =
    `PROGRAM >> bopt int && repeated global
    wth (fn (main, globals) => { main = main, globals = Vector.fromList globals } : program)



  fun parsefile file =
    let
      fun tokenize s = 
        Parsing.transform ByteTokenize.token (Pos.markstreamex file s)
        
      fun parseprogram s = 
        Parsing.transform program (tokenize s)
        
      val parsed = Stream.tolist (parseprogram (StreamUtil.ftostream file))
    in
      case parsed of
        [e] => e
      | nil => raise BytecodeParse "Parse error: no program"
      | _ => raise BytecodeParse "Parse error: too many programs?"
    end 


end
