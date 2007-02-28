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


  fun recordortuple layout sep l r osep vals =
        let 
            val sorted = 
                ListUtil.sort (ListUtil.byfirst HumlockUtil.labelcompare) vals
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

  fun vtol v =
      (case cval v of
           (* special case .0 on single function *)
           Fsel (v, i) =>
             (case (cval v, i) of
                  (Lams [(v, vl, e)], 0) => %[%[$"lam",
                                              $ ` V.tostring v,
                                              L.listex "(" ")" "," `
                                              map ($ o V.tostring) vl,
                                              $"="],
                                              L.indent 2 ` etol e]
                | _ => %[vtol v, $("." ^ itos i)])
                                            
         | Lams ll => 
           %[$"lams", 
             L.align
             (ListUtil.mapi 
              (fn ((v, vl, e), i) =>
                   %[$("#" ^ Int.toString i ^ " is"),
                     %[$(V.tostring v),
                       L.listex "(" ")" "," 
                       ` map ($ o V.tostring) vl,
                       $"="],
                     L.indent 2 ` etol e]) ll)]

               
         | Int i => $(IntConst.tostring i)
         | String s => $("\"" ^ String.toString s ^ "\"")
         | Record svl => L.listex "{" "}" "," ` map (fn (s, v) => %[$s, $"=", vtol v]) svl
         | Hold _ => $"hold?"
         | WPack _ => $"wpack?"
         | WApp (v, w) => %[vtol v, L.indent 2 ` %[$"<<", wtol w, $">>"]]
         | TApp (v, w) => %[vtol v, L.indent 2 ` %[$"<", ttol w, $">"]]
         | Sham v => $"sham?"
         | Inj (s, t, vo) => %[%[$("inj_" ^ s), 
                                 (case vo of
                                      NONE => $"(null)"
                                    | SOME v => L.indent 2 ` L.paren ` vtol v)],
                               %[$"into", L.indent 2 ` ttol t]]
         | Roll (t, v) => %[%[$"roll", L.indent 2 ` vtol v], 
                            %[$"into", L.indent 2 ` ttol t]]
         | Unroll v => %[$"unroll", L.indent 2 ` vtol v]

         | WLam (v, va) => %[%[$"//\\\\", $(V.tostring v), $"."],
                             L.indent 4 ` vtol va]
         | TLam (v, va) => %[%[$"/\\", $(V.tostring v), $"."],
                             L.indent 4 ` vtol va]

         | Var v => $(V.tostring v)
         | UVar v => $("~" ^ V.tostring v)
               )

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

         | ExternWorld(v, l, rest) =>
               % [$"extern world",
                  $(V.tostring v),
                  $"=", $l] :: estol rest

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

         | Proj(v, l, va, rest) => 
               %[%[$(V.tostring v), $"="],
                 L.indent 3 `
                 %[$("#" ^ l), L.indent 2 ` vtol va]] :: estol rest

         | Go (w, a, rest) =>
               %[%[$"--",
                   $"go"],
                 vtol a, $"::", wtol w,
                 $"--"] :: estol rest

         | Put (v, t, va, rest) => 
               %[%[$"put", $(V.tostring v),
                   $":", ttol t, $"="],
                 L.indent 4 ` vtol va] :: estol rest

         | Halt => [$"HALT."]
         | _ => [$"CPS:unknown exp(s)"])

  and ttol t = 
      (case ctyp t of
           Mu (i, m) =>
               (* XXX special case when there is just one *)
               L.paren (%[$("#" ^ itos i),
                          $"mu",
                          L.alignPrefix
                          (ListUtil.mapi 
                           (fn ((v,t),n) =>
                            %[%[$(itos n), $"as",
                                $(V.tostring v),
                                $"."], ttol t]) m,
                           "and ")])
         | At (t, w) => $"at?"
         | Cont tl => %[L.listex "(" ")" "," ` map ttol tl, $"cont"]
         | WAll (v, t) => $"wall?"
         | TAll (v, t) => $"tall?"
               
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

         | Product nil => $"unit"
         | Product ltl => recordortuple ttol ":" "(" ")" " *" ltl
         | Primcon (VEC, [t]) => %[ttol t, $"vec"]
         | Primcon (REF, [t]) => %[ttol t, $"ref"]
         | Primcon _ => $"XXX-bad-primcon-XXX"
(*
    | WExists of var * 'ctyp
    | Product of (string * 'ctyp) list
    | Addr of world
    | Primcon of primcon * 'ctyp list
    | Shamrock of 'ctyp
*)
         | TVar v => $(V.tostring v)
         | _ => $"t?"
               )
      (* $"CPS:unknown typ" *)

  and wtol (W w) = $(V.tostring w)

  and ptol LOCALHOST = $"LOCALHOST"
    | ptol BIND = $"BIND"
    | ptol (PRIMCALL {sym, dom, cod}) = %[$("PRIMCALL_" ^ sym),
                                          $":",
                                          %[L.listex "(" ")" "," ` map ttol dom,
                                            $"->",
                                            ttol cod]]

end