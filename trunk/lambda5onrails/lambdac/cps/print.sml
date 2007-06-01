(* "pretty" printer for CPS terms. *)

structure CPSPrint :> CPSPRINT =
struct

  infixr 9 `
  fun a ` b = a b

  structure L = Layout
  structure V = Variable

  val $ = L.str
  val % = L.mayAlign
  val itos = Int.toString

  open CPS

  fun varl v = $(V.tostring v)

  fun recordortuple layout sep l r osep vals =
        let 
            val sorted = 
                ListUtil.sort (ListUtil.byfirst LambdacUtil.labelcompare) vals
        in
            if
               (* can't be length 1 *)
               length sorted <> 1 andalso
               (* must be consecutive numbers *)
               ListUtil.alladjacent (fn ((x,_), (sx,_)) => 
                                     (case (Int.fromString x, 
                                            Int.fromString sx) of
                                          (SOME xx, SOME ssxx) => xx = ssxx - 1
                                        | _ => false)) sorted andalso
               (* must be empty or start at 1 *)
               (List.null sorted orelse
                #1 (hd sorted) = "1")
            then L.listex l r osep (map (layout o #2) sorted)
            else L.recordex sep (ListUtil.mapsecond layout sorted)
        end

  fun wtol (W w) = $(V.tostring w)
    | wtol (WC s) = $s
      
  fun tftol (bindtol : 'tbind -> L.layout) (ttol : 'ctyp -> L.layout) t =
      (case t of
           Mu (i, m) =>
               (* XXX special case when there is just one *)
               L.paren (%[$("#" ^ itos i),
                          $"mu",
                          L.alignPrefix
                          (ListUtil.mapi 
                           (fn ((v,t),n) =>
                            %[%[$(itos n), $"as",
                                bindtol v,
                                $"."], ttol t]) m,
                           "and ")])
         | At (t, w) => L.paren ` %[ttol t, $"at", wtol w]
         | Shamrock t => %[$"{}", L.indent 2 ` ttol t]
         | Cont tl => %[L.listex "(" ")" "," ` map ttol tl, $"cont"]
         | AllArrow { worlds, tys, vals, body } =>
             %[%[$"allarrow",
                 %[L.indent 2 ` 
                   L.listex "" "" ";"
                   ((case worlds of
                       nil => nil
                     | _ => [% ($"w:" :: map ($ o V.tostring) worlds)]) @
                    (case tys of
                       nil => nil
                     | _ => [% ($"t:" :: map bindtol tys)]) @
                    (case vals of
                       nil => nil
                     | _ => [% ($"v:" :: map (L.paren o ttol) vals)])
                       ),
                       $"."]],
                   L.indent 2 ` ttol body]

         | Sum ltl => L.listex "[" "]" "," `map (fn (l, Carrier { carried = t,
                                                                  definitely_allocated = b}) =>
                                                                     L.seq[$l, $" : ", 
                                                                           ttol t]
                                                                | (l, NonCarrier) =>
                                                                       L.seq[$l, $"(-)"]) ltl
         | Conts tll => %[$"conts:",
                          L.indent 2 `
                          % `
                          ListUtil.mapi
                          (fn (tl, i) => %[%[$("#" ^ itos i), $ ":"],
                                           L.indent 2 ` %[L.listex "(" ")" "," ` map ttol tl, $"cont"]]) tll]

         | TExists (v, tt) => %[%[$"texists", bindtol v, $"."],
                                L.indent 2 ` L.listex "[" "]" "," ` map ttol tt]
         | Product nil => $"unit"
         | Product ltl => recordortuple ttol ":" "(" ")" " *" ltl
         | Primcon (VEC, [t]) => %[ttol t, $"vec"]
         | Primcon (REF, [t]) => %[ttol t, $"ref"]
         | Primcon (DICTIONARY, [t]) => L.paren ` %[ttol t, $"dictionary"]
         | Primcon (INT, []) => $"int"
         | Primcon (STRING, []) => $"string"
         | Primcon (EXN, []) => $"exn"
         | Primcon _ => $"XXX-bad-primcon-XXX"

         | Addr w => %[wtol w, $"addr"]
(*
    | WExists of var * 'ctyp
    | Product of (string * 'ctyp) list
*)
         | TVar v => $(V.tostring v)
         | _ => $"t?"
               ) handle Match => $"XXX_MATCH-TYP_XXX"
      (* $"CPS:unknown typ" *)

  fun ttol t = tftol varl ttol (ctyp t) 

  fun vtol v =
      (case cval v of
           (* special case .0 on single function *)
           Fsel (v, i) =>
             (case (cval v, i) of
                  (Lams [(v, vtl, e)], 0) => %[%[$"lam",
                                                 vbinde v e,
                                                 L.listex "(" ")" "," `
                                                 map (fn (v, t) => 
                                                      %[vbinde v e, $":",
                                                        ttol t]) vtl,
                                                 $"="],
                                               L.indent 2 ` etol e]
                | _ => %[vtol v, $("." ^ itos i)])

         | Lams ll => 
           %[$"lams", 
             L.align
             (ListUtil.mapi 
              (fn ((v, vtl, e), i) =>
                   %[$("#" ^ Int.toString i ^ " is"),
                     %[vbinde v e,
                       L.listex "(" ")" "," 
                       ` map (fn (v, t) =>
                              %[vbinde v e, $":", ttol t]) vtl,
                       $"="],
                     L.indent 2 ` etol e]) ll)]

         | (VLeta (v, va, ve)) => %[%[$"vleta", varl v, $"="],
                                    L.indent 3 ` vtol va,
                                    $"in",
                                    L.indent 3 ` vtol ve]
         | (VLetsham (v, va, ve)) => %[%[$"vletsham", varl v, $"="],
                                       L.indent 3 ` vtol va,
                                       $"in",
                                       L.indent 3 ` vtol ve]
         | (VTUnpack (v, vd, vtl, va, ve)) =>
               %[%[$"vtunpack", L.indent 3 ` vtol va, $"as"],
                 %[L.indent 2 ` %[varl v, $";"],
                   L.indent 2 ` %[varl vd, $";"],
                   L.indent 2 ` 
                   L.listex "[" "]" "," ` map (fn (v, t) =>
                                               %[%[varl v, $":"],
                                                 L.indent 2 ` ttol t]) vtl],
                 $"in",
                 L.indent 3 ` vtol ve]

         | Int i => $(IntConst.tostring i)
         | String s => $("\"" ^ String.toString s ^ "\"")
         | Record svl => 
                recordortuple vtol "=" "(" ")" "," svl
                (* L.listex "{" "}" "," ` map (fn (s, v) => %[$s, $"=", vtol v]) svl *)
         | Hold (w, va) => %[%[$"hold", L.paren ` wtol w],
                             L.indent 2 ` vtol va]
         | WPack _ => $"wpack?"
         | TPack (t, tas, d, vs) => %[%[%[$"tpack", ttol t], %[$"as", ttol tas]],
                                      L.indent 2 ` %[$"dict=", vtol d],
                                      L.indent 2 ` L.listex "[" "]" "," ` map vtol vs]
         | AllApp { worlds = [w], f = v, tys = nil, vals = nil } => %[vtol v, L.indent 2 ` %[$"<<", wtol w, $">>"]]
         | AllApp { tys = [t], f = v, worlds = nil, vals = nil } => %[vtol v, L.indent 2 ` %[$"<", ttol t, $">"]]
         | Sham (v, cv) => %[$"sham", vbindv v cv, $".",
                                            L.indent 2 ` vtol cv]
         | Inj (s, t, vo) => %[%[$("inj_" ^ s), 
                                 (case vo of
                                      NONE => $"(null)"
                                    | SOME v => L.indent 2 ` L.paren ` vtol v)],
                               %[$"into", L.indent 2 ` ttol t]]
         | Roll (t, v) => %[%[$"roll", L.indent 2 ` vtol v], 
                            %[$"into", L.indent 2 ` ttol t]]
         | Unroll v => %[$"unroll", L.indent 2 ` vtol v]

         | Dictfor t => %[$"dictfor", ttol t]

         | AllLam {worlds = [v], tys = nil, vals = nil, body = va} => %[%[$"//\\\\", $(V.tostring v), $"."],
                                                                        L.indent 4 ` vtol va]
         | AllLam {worlds = nil, tys = [v], vals = nil, body = va} => %[%[$"/\\", $(V.tostring v), $"."],
                                                                        L.indent 4 ` vtol va]

         | Proj(l, va) => %[$("#" ^ l), vtol va]

         | AllLam { worlds, tys, vals, body } =>
                %[%[$"alllam",
                  L.listex "" "" ";"
                  ((case worlds of
                      nil => nil
                    | _ => [% ($"w:" :: map ($ o V.tostring) worlds)]) @
                   (case tys of
                      nil => nil
                    | _ => [% ($"t:" :: map ($ o V.tostring) tys)]) @
                   (case vals of
                      nil => nil
                    | _ => [% ($"v:" :: map (fn (v, t) => L.paren (%[$(V.tostring v), $":", ttol t])) vals)])
                      ),
                   $"."],
                   L.indent 2 ` vtol body]
                   
         | AllApp { f, worlds, tys, vals } =>
                %[vtol f,
                  L.indent 2 `
                  L.listex "<" ">" ";" `
                  ((case worlds of
                      nil => nil
                    | _ => [% [$"w:", L.listex "" "" "," ` map wtol worlds]]) @
                   (case tys of
                      nil => nil
                    | _ => [% [$"t:", L.listex "" "" "," ` map ttol tys]]) @
                   (case vals of
                      nil => nil
                    | _ => [% [$"v:", L.listex "" "" "," ` map vtol vals]])
                      )]

         | Codelab s => $("___" ^ s)
                      
         | Dict tf => 
                %[$"dict",
                  L.indent 2 ` tftol (fn (tv, vv) => %[varl tv, $"/", varl vv]) vtol tf]
                   
         | Var v => $(V.tostring v)
         | UVar v => $("~" ^ V.tostring v)
               ) handle Match => $"XXX_MATCH-VAL_XXX"

  and etol e = L.align (estol e)

  (* returns a list of layout "lines" *)
  and estol e = 
      (case cexp e of
           ExternVal (v, l, t, wo, rest) =>
               % [$"extern val",
                  $(V.tostring v),
                  L.indent 4 (%[$":", ttol t, 
                                      $"@", 
                                      case wo of
                                        NONE => $"VALID"
                                      | SOME w => wtol w,

                                      $"=", $l])] :: estol rest

         | ExternWorld(l, rest) =>
               % [$"extern world", $l] :: estol rest

         | Primop ([vv], BIND, [va], rest) =>
               %[%[$(V.tostring vv),
                   $"="],
                 L.indent 3 ` vtol va] :: estol rest
         | Primop (vl, po, vas, rest) =>
               % [%[L.listex "[" "]" "," ` map ($ o V.tostring) vl,
                    $"="],
                  ptol po,
                  L.listex "[" "]" "," ` map vtol vas] :: estol rest

         | Call (v, vl) =>
               [% [%[$"call",
                     vtol v],
                   L.indent 3 ` L.listex "(" ")" "," ` map vtol vl]]

         | Go (w, a, rest) =>
               %[%[$"--",
                   $"go"],
                 vtol a, $"::", wtol w,
                 $"--"] :: estol rest

         | Go_cc { w, addr, env, f } =>
               %[%[$"go_cc", 
                   L.indent 2 ` %[vtol addr, $"::", wtol w]],
                 %[%[$"run", L.indent 2 ` vtol f],
                   %[$"on", L.indent 2 ` vtol env]
                   ]] :: nil

         | Go_mar { w, addr, bytes } =>
               %[%[$"go_mar", 
                   L.indent 2 ` %[vtol addr, $"::", wtol w]],
                 %[$"send", L.indent 2 ` vtol bytes]
                 ] :: nil

         | Put (v, t, va, rest) => 
               %[%[$"put", $(V.tostring v),
                   $":", ttol t, $"="],
                 L.indent 4 ` vtol va] :: estol rest

         | Halt => [$"HALT."]

         | Letsham (v, va, e) => %[%[$"letsham", varl v,
                                     $"="],
                                   L.indent 3 ` vtol va] :: estol e

         | (Leta (v, va, e)) => %[%[$"leta", varl v, $"="],
                                  L.indent 3 ` vtol va] :: estol e

         | (WUnpack _) => [$"XXX-WUNP"]
         | (TUnpack (v, vd, vtl, va, e)) =>
               %[%[%[$"tunpack", L.indent 3 ` vtol va], $"as"],
                 %[%[varl v, $";"],
                   L.indent 2 ` %[varl vd, $";"],
                   L.listex "[" "]" "," ` map (fn (v, t) =>
                                               %[varl v, $":", ttol t]) vtl]
                 ] :: estol e
         | (Case _) => [$"XXX_CASE"]
         | (ExternType _) => [$"XXX_ET"]
(*         | _ => [$"CPS:unknown exp(s)"]
*)
) handle Match => [$"XXX_MATCH-EXP_XXX"]


  and vbindt v t =
    if CPS.freet v t
    then varl v
    else $"_"

  and vbindv v va =
    if CPS.freev v va
    then varl v
    else $"_"

  and vbinde v e =
    if CPS.freee v e
    then varl v
    else $"_"


  and ptol LOCALHOST = $"LOCALHOST"
    | ptol BIND = $"BIND"
    | ptol MARSHAL = $"MARSHAL"
    | ptol (PRIMCALL {sym, dom, cod}) = %[$("PRIMCALL_" ^ sym),
                                          $":",
                                          %[L.listex "(" ")" "," ` map ttol dom,
                                            $"->",
                                            ttol cod]]
end