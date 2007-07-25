(* primop data *)
structure Podata =
struct

  exception Podata of string

  local open Primop
        structure I = IL
  in

    (* nb: all operations are UNSIGNED, including comparisons *)
    (* XXX this should probably be factored out *)
    fun tostring (B PTimes) = "Times"
      | tostring (B PPlus) = "Plus"
      | tostring (B PMinus) = "Minus"
      | tostring (B PDiv) = "Div"
      | tostring (B PMod) = "Mod"
      | tostring (B (PCmp PEq)) = "Eq"
      | tostring (B (PCmp PNeq)) = "Neq"
      | tostring (B (PCmp PLess)) = "Less"
      | tostring (B (PCmp PLesseq)) = "Lesseq"
      | tostring (B (PCmp PGreater)) = "Greater"
      | tostring (B (PCmp PGreatereq)) = "Greatereq"

      | tostring (PNull) = "Null"

      | tostring (B PAndb) = "Andb"
      | tostring (B PXorb) = "Xorb"
      | tostring (B POrb) =  "Orb"
      | tostring (B PShl) = "Shl"
      | tostring (B PShr) = "Shr"

      | tostring PNotb = "Notb"

      | tostring PEqs = "Eqs"

      | tostring PPrint = "Print"

      | tostring PNeg = "Neg"

      | tostring PSet = "Set"
      | tostring PGet = "Get"
      | tostring PRef = "Ref"

      | tostring PArray = "Array"
      | tostring PArray0 = "Array0"
      | tostring PSub = "Sub"
      | tostring PUpdate = "Update"
      | tostring PArraylength = "Arraylength"
      | tostring (PJointext i) = ("Jointext_" ^ Int.toString i)

      | tostring PBind = "Bind"
      | tostring PNewtag = "Newtag"
      | tostring PGethandler = "Gethandler"
      | tostring PSethandler = "Sethandler"

      | tostring (PCompileWarn s) = "Warn(" ^ s ^ ")"

      | tostring PPutc = "Putc"
      | tostring PGetc = "Getc"

      | tostring PHalt = "Halt"

      | tostring PShowval = "(DEBUG:ShowVal)"

    fun potype (PJointext i) = I.Poly({worlds = nil, tys = nil}, 
                                      (List.tabulate (i, fn _ => Initial.ilstring),
                                       Initial.ilstring))
      | potype p = raise Podata ("unimplemented potype " ^ tostring p)

    fun polab (PJointext i) = "po_jointext_" ^ Int.toString i
      | polab p = raise Podata ("unimplemented polab " ^ tostring p)

  end
end