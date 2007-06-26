
structure Marshal :> MARSHAL =
struct

  infixr 9 `
  fun a ` b = a b

  open Bytecode

  exception Marshal of string

  fun unmarshal bytes : exp = raise Marshal "unmarshal unimplemented"

  fun marshal (dict : exp) (value : exp) : string = 
    let
      fun mar (Dp Dint) (Int i) = IntConst.toString i
        | mar (Dp Dint) _ = raise Marshal "dint"
        | mar (Dp Dstring) (String s) = StringUtil.urlencode s
        | mar (Dp Dstring) _ = raise Marshal "dstring"
        | mar (Dp Daddr) (String s) = StringUtil.urlencode s
        | mar (Dp Daddr) _ = raise Marshal "daddr"
        | mar (Dsum seol) (Inj (s, eo)) =
        (case (ListUtil.Alist.find op= seol s, eo) of
           (NONE, _) => raise Marshal "dsum/inj mismatch : missing label"
         | (SOME NONE, NONE) => s ^ " -"
         | (SOME (SOME d), SOME v) => s ^ " + " ^ mar d v
         | _ => raise Marshal "dsum/inj arity mismatch")
        | mar (Dsum _) _ = raise Marshal "dsum"
        | mar (Drec sel) (Record lel) =
        String.concat (map (fn (s, d) =>
                            case ListUtil.Alist.find op= lel s of
                              NONE => raise Marshal 
                                       "drec/rec mismatch : missing label"
                            | SOME v => s ^ " " ^ mar d v) sel)
        | mar (Drec _) _ = raise Marshal "drec"
        | mar (Dexists {d, a}) (Record lel) =
        (case ListUtil.Alist.extract op= lel "d" of
           NONE => raise Marshal "no dict in supposed e-package"
         | SOME (thed, lel) =>
             (* XXX need to bind d; it might appear in a! *)
             mar (Dp Ddict) thed ^ " " ^
             (StringUtil.delimit " " `
              ListUtil.mapi (fn (ad, i) =>
                             (case ListUtil.Alist.find op= lel 
                                        ("v" ^ Int.toString i) of
                                NONE => raise Marshal 
                                  "missing val in supposed e-package"
                              | SOME v => mar ad v)) a)
             )
        | mar (Dexists _) _ = raise Marshal "dexists"
        | mar _ _ = raise Marshal "marshaling unimplemented for this"
    in
      (* XXX contexts.. *)
      mar dict value
    end

end
