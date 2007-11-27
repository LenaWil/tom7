
structure Context :> CONTEXT =
struct
    open Variable

    val showbinds = Params.flag false
        (SOME ("-showilbinds",
               "When ")) "showilbinds"
        
    structure S = StringMap
    structure SU = StringMapUtil
    structure SS = StringSet
    structure VS = Variable.Set

    datatype varsort = datatype IL.varsort

    datatype context = 
        C of { vars : (IL.typ IL.poly * Variable.var * IL.idstatus * varsort) S.map,
               cons : (IL.kind * IL.con * IL.tystatus) S.map,
               worlds : Variable.var S.map,
               wlabs : IL.worldkind S.map,
               mobiles : VS.set,
               (* obsolete, but might come back *)
               dbs  : unit S.map }

    (* first is class of identifier, second is identifier *)
    exception Context of string
    exception Absent of string * string

    fun absent what s =
        let in 
(*
              print "(Unbound in context: ";
              print s;
              print ")\n";
*)
            raise Absent (what, s)
        end

    structure L = Layout
    fun stol sort = (case sort of
                       Modal w => ILPrint.wtol w
                     | Valid v => Layout.str ("VALID " ^ Variable.tostring v ^ "."))

    fun ctol (C { vars, cons, worlds, wlabs, mobiles, dbs }) =
      let
        val $ = L.str
        val % = L.mayAlign
        val itos = Int.toString

        val vars = S.listItemsi vars
        val worlds = S.listItemsi worlds
      in
        %[$"Context.",
          L.indent 3
          (
           %[$"worlds:",
             % (map (fn (s, v) =>
                     %[$s, $"==", $(Variable.tostring v)]) worlds),
             $"vars:",
             % (map (fn (s, (tp, v, vs, sort)) =>
                     %[%[$s, $"==", $(Variable.tostring v), $":"],
                       L.indent 2 (%[ILPrint.ptol ILPrint.ttol tp,
                                     $"@", stol sort])]) vars),
             $"XXX mobiles, cons, wlabs"])]
          
      end

    (* for type evars. these can only appear in the types of vars. *)
    fun has_evar (C{vars, ...}) n =
      let
          open IL
          fun has tt =
              (case tt of
                   TVar _ => false
                 | TRec ltl => List.exists (fn (_, t) => 
                                            has t) ltl
                 | Arrow (_, tl, t) =>
                       has t orelse
                       List.exists has tl
                 | Sum ltl => List.exists 
                       (fn (_, Carrier { carried, ... }) => has carried
                          | _ => false) ltl
                 | Mu (_, vtl) => List.exists (fn (_, t) => has t) vtl
                 | Evar (ref (Free m)) => n = m
                 | Evar (ref (Bound t)) => has t
                 | TVec t => has t
                 | TCont t => has t
                 | TTag (t, _) => has t
                 | At (t, w) => has t
                 | Shamrock (_, t) => has t
                 | TAddr _ => false
                 | Arrows l =>
                       List.exists (fn (_, tl, t) =>
                                    has t orelse List.exists has tl) l
                 | TRef t => has t)
      in
        SU.exists (fn (Poly({worlds, tys}, t), _, _, _) => has t) vars 
      end

    (* for world evars. Again, these can only appear in the types of bound vars;
       bound worlds and types have uninteresting kinds. *)
    fun has_wevar (C{vars, ...}) n =
      let
          open IL
          fun hasw (WVar _) = false
            | hasw (WConst _) = false
            | hasw (WEvar er) =
            case !er of
              Free m => m = n
            | Bound w => hasw w

          and has tt =
              (case tt of
                   TVar _ => false
                 | TRec ltl => List.exists (fn (_, t) => 
                                            has t) ltl
                 | Arrow (_, tl, t) =>
                       has t orelse
                       List.exists has tl
                 | Sum ltl => List.exists 
                       (fn (_, Carrier { carried, ... }) => has carried
                          | _ => false) ltl
                 | Mu (_, vtl) => List.exists (fn (_, t) => has t) vtl
                 | Evar (ref (Free _)) => false
                 | Evar (ref (Bound t)) => has t
                 | TVec t => has t
                 | TCont t => has t
                 | TTag (t, _) => has t
                 | At (t, w) => has t orelse hasw w
                 | Shamrock (_, t) => has t
                 | TAddr w => hasw w
                 | Arrows l =>
                       List.exists (fn (_, tl, t) =>
                                    has t orelse List.exists has tl) l
                 | TRef t => has t)

          fun hassort (Modal w') = hasw w'
            | hassort (Valid _) = false
      in
        SU.exists (fn (Poly({worlds, tys}, t), _, _, sort) => hassort sort orelse has t) vars 
      end

    (* Worlds may be world variables or world constants. If there is a world
       constant we assume it takes precedence. (It might be good to prevent
       the binding of a world variable when there is a constant of the same
       name?) *)
    fun world (C{worlds, wlabs, ...}) s =
      if isSome (S.find (wlabs, s))
      then IL.WConst s
      else
        (case S.find (worlds, s) of
           SOME x => IL.WVar x
         | NONE => absent "world" s)


    fun varex (C {vars, ...}) sym =
        (case S.find (vars, sym) of
             SOME x => x
           | NONE => absent "var" sym)

    fun var ctx sym = varex ctx sym

    fun conex (C {cons, ...}) module sym =
        (case S.find (cons, sym) of
             SOME x => x
           | NONE => absent "con" sym)

    fun con ctx sym = conex ctx NONE sym


    fun bindwlab (C {vars, cons, dbs, worlds, wlabs, mobiles }) sym kind = 
        C { vars = vars,
            cons = cons,
            wlabs = 
            (case S.find (wlabs, sym) of
               NONE => S.insert(wlabs, sym, kind)
             | SOME kind' => if kind = kind'
                             then wlabs (* already there *)
                             else raise Context ("kinds don't agree on multiple " ^
                                                 "extern world declarations for " ^ sym)),
            mobiles = mobiles,
            worlds = worlds,
            dbs = dbs }

    fun bindex (C {vars, cons, dbs, worlds, wlabs, mobiles }) sym typ var stat sort =
      let 
        val sym = (case sym of NONE => 
                     ML5pghUtil.newstr "bindex" | SOME s => s)
      in
        if !showbinds
        then let in
          print (sym ^ " == " ^ Variable.tostring var ^ " : ");
          Layout.print(ILPrint.ptol ILPrint.ttol typ, print);
          print " @ ";
          Layout.print(stol sort, print);
          print "\n"
             end
        else ();
        C { vars = S.insert (vars, 
                             sym,
                             (typ, var, stat, sort)),
            cons = cons,
            wlabs = wlabs,
            worlds = worlds,
            mobiles = mobiles,
            dbs = dbs }
      end

    fun bindv c sym t v w = bindex c (SOME sym) t v IL.Normal (Modal w)
    fun bindu c sym typ var stat = bindex c (SOME sym) typ var stat (Valid (Variable.namedvar "unused"))

    fun bindcex (C { cons, vars, dbs, worlds, mobiles, wlabs }) module sym con kind status =
        C { vars = vars,
            cons = S.insert (cons, sym, (kind, con, status)),
            wlabs = wlabs,
            worlds = worlds,
            mobiles = mobiles,
            dbs = dbs }

    fun bindc c sym con kind status = bindcex c NONE sym con kind status

    fun bindw (C { cons, vars, dbs, worlds, mobiles, wlabs }) s v =
        C { vars = vars,
            cons = cons,
            mobiles = mobiles,
            wlabs = wlabs,
            worlds = S.insert (worlds, s, v),
            dbs = dbs }

    val empty = C { worlds = S.empty, 
                    vars = S.empty, 
                    cons = S.empty, 
                    mobiles = VS.empty,
                    wlabs = S.empty,
                    dbs = S.empty }

    fun bindmobile (C { cons, vars, dbs, worlds, mobiles, wlabs }) v =
      C { vars = vars,
          cons = cons,
          dbs = dbs,
          worlds = worlds,
          wlabs = wlabs,
          mobiles = VS.add (mobiles, v) }

    fun ismobile (C { mobiles, ... }) v = VS.member (mobiles, v)
      
end
