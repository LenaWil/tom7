
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

  (* labels are identifiers but also numbers.
     we quote them because they might clash with keywords. *)
  val label = strlit
    (* id || number wth (Int.toString o Word32.toInt) *)

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

  val pdict =
       `DCONT return Dcont
    || `DCONTS return Dconts
    || `DADDR return Daddr
    || `DDICT return Ddict
    || `DINT return Dint
    || `DSTRING return Dstring
    || `DVOID return Dvoid
    || `DAA return Daa
    || `DREF return Dref
    || `DW return Dw

  fun exp () =
       `PROJ >> label && $exp wth Project
    || `RECORD >> repeated (label && $exp) wth Record
    || `PRIMCALL >> id && repeated ($exp) wth Primcall
    || `CALL >> $exp && repeated ($exp) wth Call
    || `INJ >> label && bopt ($exp) wth Inj
    || `MARSHAL >> $exp && $exp wth Marshal
    || `PRIMOP >> id && repeated ($exp) wth (fn (s, args) =>
                                             case Primop.fromstring s of
                                               NONE => raise BytecodeParse ("unknown primop " ^ s)
                                             | SOME po => Primop (po, args))
    

    || `DP >> pdict wth Dp
    || `DREC >> repeated (label && $exp) wth Drec
    || `DSUM >> repeated (label && bopt ($exp)) wth Dsum
    || `DLOOKUP >> id wth Dlookup
    || `DEXISTS >> id && repeated ($exp) wth (fn (d,a) => Dexists { d = d,
                                                                    a = a })
    || `DALL >> repeated id && $exp wth Dall
    || `DAT >> $exp && $exp wth (fn (d, a) => Dat   { d = d, a = a })
    || `DSHAM >> id && $exp wth (fn (d, v) => Dsham { d = d, v = v })
    || `DMU >> int && repeated (id && $exp) wth Dmu

    || `CALL -- punt "parse error after CALL"
    || `DALL -- punt "parse error after DALL"
    || `DAT -- punt "parse error after DAT"
    || `DEXISTS -- punt "parse error after DEXISTS"
    || `DLOOKUP -- punt "parse error after DLOOKUP"
    || `DP -- punt "parse error after DP"
    || `DREC -- punt "parse error after DREC"
    || `DSHAM -- punt "parse error after DSHAM"
    || `DMU -- punt "parse error after DMU"
    || `DSUM -- punt "parse error after DSUM"
    || `INJ -- punt "parse error after INJ"
    || `MARSHAL -- punt "parse error after MARSHAL"
    || `PRIMCALL -- punt "parse error after PRIMCALL"
    || `PROJ -- punt "parse error after PROJ"
    || `RECORD -- punt "parse error after RECORD"

    || number wth Int
    || strlit wth String
    || id wth Var


  and stmt () =
       `END return End
    || `RETURN >> $exp wth Return
    || `BIND >> id && $exp && $stmt wth (fn (a, (b, c)) => Bind (a, b, c))
    || `JUMP >> $exp && $exp && repeated ($exp) wth (fn (a, (b, c)) => Jump (a, b, c))
    || `GO >> $exp && $exp wth Go
    || `ERROR >> strlit wth Error
    || `CASE >> $exp && id && repeated (label && $stmt) && $stmt
         wth (fn (a, (b, (c, d))) => Case { obj = a, var = b, arms = c, def = d})

    || `BIND -- punt "parse error after BIND"
    || `JUMP -- punt "parse error after JUMP"
    || `GO -- punt "parse error after GO"
    || `ERROR -- punt "parse error after ERROR"
    || `CASE -- punt "parse error after CASE"
    || `RETURN -- punt "parse error after RETURN"

  val global = 
       `ABSENT return Absent
    || `FUNDEC >> repeated (repeated id && $stmt) wth (FunDec o Vector.fromList)
    || `ONEDEC >> repeated id && $stmt wth OneDec

    || `FUNDEC -- punt "parse error after FUNDEC"
    || `ONEDEC -- punt "parse error after ONEDEC"

  val program =
    `PROGRAM >> bopt int && repeated global
       wth (fn (main, globals) => { main = main, globals = Vector.fromList globals } : program)
    
    || `PROGRAM -- punt "parse error after PROGRAM"


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
