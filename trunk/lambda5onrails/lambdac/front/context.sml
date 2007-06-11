
structure Context :> CONTEXT =
struct
    open Variable
        
    structure S = StringMap
    structure SU = StringMapUtil
    structure SS = StringSet

    datatype varsort =
      Modal of IL.world
    | Valid

    datatype context = 
        C of { vars : (IL.typ IL.poly * Variable.var * IL.idstatus * varsort) S.map,
               cons : (IL.kind * IL.con * IL.tystatus) S.map,
               worlds : Variable.var S.map,
               wlabs : IL.worldkind S.map,
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

    (* this only checks vars, not cons, dbs, or worlds.
       But evars shouldn't ever appear bound to type variables, right?
       (I can't look inside lambdas, anyway.) *)
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
                 | TAddr _ => false
                 | Arrows l =>
                       List.exists (fn (_, tl, t) =>
                                    has t orelse List.exists has tl) l
                 | TRef t => has t)
      in
        SU.exists (fn (Poly({worlds, tys}, t), _, _, _) => has t) vars 
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


    fun bindwlab (C {vars, cons, dbs, worlds, wlabs }) sym kind = 
        C { vars = vars,
            cons = cons,
            wlabs = 
            (case S.find (wlabs, sym) of
               NONE => S.insert(wlabs, sym, kind)
             | SOME kind' => if kind = kind'
                             then wlabs (* already there *)
                             else raise Context ("kinds don't agree on multiple " ^
                                                 "extern world declarations for " ^ sym)),
            worlds = worlds,
            dbs = dbs }

    fun bindex (C {vars, cons, dbs, worlds, wlabs }) sym typ var stat sort =
        C { vars = S.insert (vars, sym, (typ, var, stat, sort)),
            cons = cons,
            wlabs = wlabs,
            worlds = worlds,
            dbs = dbs }

    fun bindv c sym t v w = bindex c sym t v IL.Normal (Modal w)
    fun bindu c sym typ var stat = bindex c sym typ var stat Valid

    fun bindcex (C { cons, vars, dbs, worlds, wlabs }) module sym con kind status =
        C { vars = vars,
            cons = S.insert (cons, sym, (kind, con, status)),
            wlabs = wlabs,
            worlds = worlds,
            dbs = dbs }

    fun bindc c sym con kind status = bindcex c NONE sym con kind status

    fun bindw (C { cons, vars, dbs, worlds, wlabs }) s v =
        C { vars = vars,
            cons = cons,
            wlabs = wlabs,
            worlds = S.insert (worlds, s, v),
            dbs = dbs }

    val empty = C { worlds = S.empty, 
                    vars = S.empty, 
                    cons = S.empty, 
                    wlabs = S.empty,
                    dbs = S.empty }

end
