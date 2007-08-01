
structure ILPrint :> ILPRINT =
struct

  infixr 9 `
  fun a ` b = a b

    val iltypes = Params.flag true
        (SOME ("-iltypes",
               "show types and coercions in IL")) "iltypes"

    open IL
    structure L = Layout
    structure V = Variable

    val $ = L.str
    val % = L.mayAlign
    val itos = Int.toString

    fun dolist s f i l = StringUtil.delimit s (List.map (fn m => f i m) l)

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

           
    exception NoMu
    fun ttol t = ttolex Context.empty t
    and ttolex ctx t =
      if not (!iltypes)
      then $"-"
      else
      let
        val self = ttolex ctx
      in
        (case t of
           (* should print these right-associatively *)
             Arrow (b, [dom], cod) =>
                 L.paren (%[self dom,
                            $(if b then "=>" else "->"),
                            self cod])
           | Arrow (b, dom, cod) => 
                 L.paren (%[L.list (map self dom),
                            $(if b then "=>" else "->"),
                            self cod])
           | Arrows al => L.listex "(" ")" " &&" `
                              map (fn (b, dom, cod) =>
                                   %[L.list (map self dom),
                                     $(if b then "=>" else "->"),
                                     self cod]) al

           | TVec t => L.paren (L.seq[self t, $" vector"])
           | TCont t => L.paren (L.seq[self t, $" cont"])
           | TRef t => L.paren (L.seq[self t, $" ref"])
           | TVar v => L.str (V.show v)
           | TAddr w => L.paren (L.seq[wtol w, $" addr"])
           | Shamrock t => %[$"{}", ttol t]
           | At (t, w) => L.paren (L.seq[self t, $"at", wtol w])
           | Sum ltl => L.listex "[" "]" "," (map (fn (l, Carrier { carried = t,
                                                                    definitely_allocated = b}) =>
                                                   L.seq[$l, $" : ", 
                                                         self t]
                                                    | (l, NonCarrier) =>
                                                   L.seq[$l, $"(-none-)"]) ltl)
           | Mu (i, m) => 
                 (* try to figure out the datatype's name
                    and write that instead. this is rather
                    a hack... *)
                 (let
                    val thisc =
                      (case List.nth(m, i) of
                         (v, _) => Variable.basename v)
                         handle _ => raise NoMu

                    val t = 
                      (case Context.con ctx thisc of
                         (kind, Lambda f, _) => 
                           (case kind of
                              0 => $ thisc
                           (* XXX otherwise do anti-unification 
                              or whatever to figure out what
                              the datatype "type constructor"
                              is applied to. (but we should be
                              careful that unification doesn't
                              cause any harmful side-effects.) *)
                            | _ => raise NoMu)

                       (* doesn't look like a datatype! *)
                       | _ => raise NoMu)


                         (* totally normal for this to be out of
                            scope right now *)
                         handle Context.Absent _ => raise NoMu
                           
                  in
                    $ thisc (* raise NoMu *)
                  end
                    handle NoMu =>
                      L.paren (%[$("#" ^ itos i),
                                 $"mu",
                                 L.alignPrefix
                                 (ListUtil.mapi 
                                  (fn ((v,t),n) =>
                                   %[%[$(itos n), $"as",
                                       $(V.tostring v),
                                       $"."], self t]) m,
                                  "and ")]))
           | TRec nil => $"unit"
           | TRec ltl => recordortuple self ":" "(" ")" " *" ltl

           | TTag (t, v) => %[$"tag", self t, $"=>", $(V.tostring v)]
           | Evar (ref (Bound t)) => self t
           | Evar (ref (Free n)) => $("'a" ^ itos n))
      end

    and wtol (WEvar (ref (Bound w))) = wtol w
      | wtol (WEvar (ref (Free n))) = $("'w" ^ itos n)
      | wtol (WVar v) = $(V.show v)
      | wtol (WConst s) = $s

    (* <t> *)
    fun bttol t = if !iltypes then L.seq[$"<", ttol t, $">"]
                  else $""

    fun vtol v =
      (case v of
         Int i => $("0x" ^ Word32.toString i)
       | String s => $("\"" ^ String.toString s ^ "\"")
       | VRecord lvl => recordortuple vtol "=" "(" ")" "," lvl
       | VRoll (t, v) => %[$"roll", L.paren (ttol t), vtol v]
       | VInject (t, l, vo) => %[$("inj_" ^ l), 
                                 L.paren (ttol t),
                                 (case vo of
                                      NONE => $"NONE"
                                    | SOME v => vtol v)]

       | FSel (n, v) => %[vtol v, $("." ^ Int.toString n)]

       | Sham (v, va) => %[$"sham", $(V.tostring v), $".",
                           L.indent 2 ` vtol va]

       | Fns fl =>
             %[$"fns", (* XXX5 worlds/tys *)
               L.align
               (ListUtil.mapi 
                (fn ({name, arg, dom, cod, body, inline, recu, total}, i) =>
                     %[$("#" ^ Int.toString i ^ " is"),
                       %[if length arg <> length dom 
                         then $"XXX arg/dom mismatch!!"
                         else $"",
                             $(V.tostring name),
                             if !iltypes 
                             then L.seq[$(if inline then "INLINE " else ""),
                                        $(if recu then "RECU " else "NRECU "),
                                        $(if total then "TOTAL" else "PART")]
                             else $"",
                                 L.listex "(" ")" "," 
                                 (ListPair.map 
                                     (fn (a, t) =>
                                      %[$(V.tostring a),
                                        if !iltypes 
                                        then L.seq[$":", ttol t]
                                        else $""]) (arg, dom)),
                                 %[$":",
                                   ttol cod,
                                   $"="]],
                        L.indent 4 (etol body)]) fl)
               ]

       | Polyuvar {worlds=nil, tys=nil, var} => $("~" ^ V.show var)
       | Polyuvar {worlds, tys, var} => 
             %[$("~" ^ V.show var),
               if !iltypes 
               then 
                   (* XXX5 separate them? *)
                   L.listex "<" ">" "," (map wtol worlds @ map ttol tys)
               else $""]

       | Polyvar {worlds=nil, tys=nil, var} => $(V.show var)
       | Polyvar {worlds, tys, var} => %[$(V.show var),
                                         if !iltypes 
                                         then 
                                           (* XXX5 separate them? *)
                                           L.listex "<" ">" "," (map wtol worlds @ map ttol tys)
                                         else $""]

           )

    and etol e =
        (case e of
           (* | Char c => $("?" ^ implode [c]) *)
             App (e1, [e2]) => L.paren(%[etol e1, etol e2])
           | App (e1, e2) => L.paren(%[etol e1, L.list (map etol e2)])

           | Value v => vtol v

           (* print as if n-ary *)
           | Seq _ => 
                 let 
                     fun allseqs acc (Seq (ee, er)) = allseqs (ee::acc) er
                       | allseqs acc e = (acc, e)

                     val (front, last) = allseqs nil e
                 in
                     L.listex "(" ")" ";" (rev (map etol (last::front)))
                 end
           (* also fake n-ary like above *)
           | Let (dd, ee) =>
                 let
                     fun alldecs acc (Let (dd, er)) = alldecs (dd::acc) er
                       | alldecs acc e = (acc, e)

                     val (decs', body) = alldecs nil e
                     val decs = rev (map dtol decs')
                 in
                     L.align
                     [$"let",
                      L.indent 4 (L.align decs),
                      $"in",
                      L.indent 4 (etol body),
                      $"end"]
                 end
           | Proj (l, t, e) => 
                 if !iltypes
                 then
                   %[L.seq[$("#" ^ l), $"/", L.paren(ttol t)],
                     etol e]
                 else %[$("#" ^ l), etol e]
           | Record sel => recordortuple etol "=" "(" ")" "," sel
           | Primapp (po, el, ts) =>
                 %( [$"[PRIM", $(Podata.tostring po),
                     L.listex "(" ")" "," (map etol el)]
                   @ (case (!iltypes, ts) of 
                          (_, nil) => nil
                        | (false, _) => nil
                        | _ => [L.listex "<" ">" "," (map ttol ts)])
                   @ [$"]"])
           | Inject (t, l, NONE) => L.paren (%[$("inj_" ^ l),
                                               bttol t,
                                                $"(-NONE-)"])
           | Inject (t, l, SOME e) => L.paren(%[$("inj_" ^ l),
                                                bttol t,
                                                etol e])
           | Unroll e => 
                 if !iltypes
                 then L.paren(%[$"unroll", etol e])
                 else etol e
           | Roll (t,e) => 
                 if !iltypes
                 then L.paren(%[$"roll", 
                                bttol t,
                                etol e])
                 else etol e
           | Sumcase (t, e, v, lel, def) =>
                 L.align
                 (%[$"sumcase", etol e, %[$":", ttol t], 
                    %[$"as", $ (V.tostring v)]] ::
                  map (fn (l, e) => %[%[$"  |", $l, $"=>"], L.indent 4 (etol e)]) lel @
                  [%[%[$"  |", $"_", $"=>"], L.indent 4 (etol def)]])

           | Untag {typ, obj, target, bound, yes, no} =>

                 %[$"untag", etol obj, $":", ttol typ,
                   $"with", etol target,
                   %[$"  yes", $(V.tostring bound), $" => ", etol yes,
                     $"| no => ", etol no]]

           | Throw (e1, e2) => L.paren(%[$"throw",
                                         etol e1,
                                         $"to",
                                         etol e2])

           | Letcc (v, t, e) => %[%[$"letcc", %[$(V.tostring v),
                                                L.indent 2 ` %[$":", %[ttol t, $"cont"]]]],
                                  %[$"in",
                                    L.indent 2 ` etol e]]

           | Say e => %[$"say", L.indent 2 ` etol e]
           | Raise (t, e) => L.paren(%[$"raise", 
                                       bttol t, etol e])
           | Tag (e1, e2) => L.paren(%[$"tag", etol e1, $"with", etol e2])

           | Handle (e, v, h) => %[L.paren(etol e),
                                   $"handle",
                                   %[%[$(V.tostring v), $"=>"], etol h]]
           | Get {addr = a, typ = t, body = e, dest} => 
                 %[$"from", etol a, $":", %[wtol dest, $" addr"], %[$"get", 
                   etol e, $":", ttol t]]

           | Jointext el =>
                 %[$"jointext",
                   L.listex "[" "]" "," (map etol el)]
                 )

    and dlisttol dlist =
      %[$"{dlist=", %(map (fn (v, va) => 
                           %[$(V.tostring v),
                             $"->",
                             vtol va]) dlist),
        $"}"]

    and btol Val = $"val"
      | btol Put = $"put"

    and dtol d =
        (case d of
             Do e => %[$"do", etol e]
           | Tagtype v => %[$"tagtype", $(V.tostring v)]
           | Newtag (new, t, ext) => %[$"newtag", $(V.tostring new), 
                                       $"tags", ttol t, $"in", 
                                       $(V.tostring ext)]
           | Bind(b, Poly ({worlds, tys}, (var, t, e))) =>
               (* XXX5 worlds too *)
               %[%[%([btol b]
                     @ (case tys of
                          nil => nil
                        | _ => [L.listex "(" ")" "," (map ($ o V.tostring) tys)])
                     @ [$(V.tostring var)]),
                   L.indent 4 (%[$":", ttol t, $"="])],
                 L.indent 4 (etol e)]

           | Letsham (Poly({worlds, tys}, (v, t, va))) =>
               %[%[%([$"letsham"]
                     (* XXX5 worlds *)
                     @ (case tys of
                          nil => nil
                        | _ => [L.listex "(" ")" "," (map ($ o V.tostring) tys)])
                     @ [$(V.tostring v)]),
                   L.indent 4 (%[$"~", ttol t, $"="])],
                 L.indent 4 (vtol va)]

           | ExternWorld (l, k) => %[$"extern world", wktol k, $l]
           | ExternVal (Poly({worlds, tys}, (l, v, t, w))) =>
                 % ($"extern val" ::
                    (case tys of
                       nil => nil
                     | _ => [L.listex "(" ")" "," (map ($ o V.tostring) tys)]) @
                       (* XXX5 poly worlds *)
                       [$(V.tostring v),
                        L.indent 4 (%[$":", ttol t, 
                                      $"@", 
                                      case w of
                                        NONE => $"VALID"
                                      | SOME w => wtol w,

                                      $"=", $l])])
           | ExternType (n, l, v) => 
                 %[$"extern type",
                   (case n of
                       0 => $""
                     | _ => L.listex "(" ")" "," 
                          (List.tabulate (n, fn i => $(implode [chr (ord #"a" + i)])))),
                   $(V.tostring v), $"=", $l]

                 )

    and wktol KJavascript = $"javascript"
      | wktol KBytecode = $"bytecode"

    and xtol x =
      (case x of
         ExportWorld (l, w) => %[$"export world", $l, $"=", wtol w]
       | ExportVal (Poly({worlds, tys}, (l, t, w, v))) =>
                 % ($"export val" ::
                    (case tys of
                       nil => nil
                     | _ => [L.listex "(" ")" "," (map ($ o V.tostring) tys)]) @
                       (* XXX5 poly worlds *)
                       [$ l,
                        L.indent 4 (%[$":", ttol t, 
                                      $"@", 
                                      case w of
                                        NONE => $"VALID"
                                      | SOME w => wtol w,
                                      $"=", vtol v])])
       | ExportType (tys, l, t) =>
           % ($"export type" ::
              (case tys of
                 nil => nil
               | _ => [L.listex "(" ")" "," (map ($ o V.tostring) tys)]) @
                 [$ l, $"=",
                  L.indent 4 ` ttol t])

           )


    and utol (Unit(ds, xs)) =
        %[$"unit",
          L.indent 2 (L.align (map dtol ds)),
          $"in",
          L.indent 2 (L.align (map xtol xs)),
          $"end"]

end
