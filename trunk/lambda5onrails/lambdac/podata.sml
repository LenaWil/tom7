(* primop data *)
structure Podata =
struct

  exception Podata of string

  local open Primop
        structure I = IL
        fun mono (dom, cod) = { worlds = nil, tys = nil, dom = dom, cod = cod }
  in

    (* nb. jointext and compilewarn are missing *)
    val alist =
      [
      ("Times", B PTimes),
      ("Plus", B PPlus),
      ("Minus", B PMinus),
      ("Div", B PDiv),
      ("Mod", B PMod),
      ("Eq", B (PCmp PEq)),
      ("Neq", B (PCmp PNeq)),
      ("Less", B (PCmp PLess)),
      ("Lesseq", B (PCmp PLesseq)),
      ("Greater", B (PCmp PGreater)),
      ("Greatereq", B (PCmp PGreatereq)),
      ("Null", PNull),
      ("Andb", B PAndb),
      ("Xorb", B PXorb),
      ("Orb", B POrb),
      ("Shl", B PShl),
      ("Shr", B PShr),
      ("Notb", PNotb),
      ("Eqs", PEqs),
      ("Print", PPrint),
      ("Neg", PNeg),
      ("Set", PSet),
      ("Get", PGet),
      ("Ref", PRef),
      ("Array", PArray),
      ("Array0", PArray0),
      ("Sub", PSub),
      ("Update", PUpdate),
      ("Arraylength", PArraylength),
      ("Bind", PBind),
      ("Newtag", PNewtag),
      ("Gethandler", PGethandler),
      ("Sethandler", PSethandler),
      ("Halt", PHalt),
      ("Showval", PShowval)]

    fun tostring p =
      let
        fun find nil = (case p of
                          PJointext i => ("Jointext_" ^ Int.toString i)
                        | PCompileWarn s => ("Warn(" ^ s ^ ")")
                        | _ => raise Podata "po tostring?")
          | find ((s, p') :: rest) = if p = p' then s
                                   else find rest
      in
        find alist
      end

    fun fromstring s =
      case ListUtil.Alist.find op= alist s of
        NONE => NONE (* XXX should allow at least jointext here *)
      | SOME po => SOME po

    fun potype (PJointext i) = { worlds = nil, tys = nil,
                                 dom = List.tabulate (i, Util.K PT_STRING),
                                 cod = PT_STRING }
      | potype PHalt =
          let val a = Variable.namedvar "a"
          in { worlds = nil, tys = [a], dom = nil, cod = PT_VAR a }
          end
      | potype (B (PCmp _)) = mono ([PT_INT, PT_INT], PT_BOOL)
      | potype (B PTimes) = mono ([PT_INT, PT_INT], PT_INT)
      | potype (B PPlus) = mono ([PT_INT, PT_INT], PT_INT)
      | potype (B PMinus) = mono ([PT_INT, PT_INT], PT_INT)
      | potype PEqs = mono ([PT_STRING, PT_STRING], PT_BOOL)

      | potype p = raise Podata ("unimplemented potype " ^ tostring p)

  end (* local *)
end