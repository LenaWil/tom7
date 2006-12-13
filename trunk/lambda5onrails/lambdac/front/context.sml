
structure Context :> CONTEXT =
struct
    open Variable
        
    structure S = StringMap
    structure SU = StringMapUtil

    datatype varsort =
      Modal of IL.world
    | Valid

    datatype context = 
        C of { vars : (IL.typ IL.poly * Variable.var * IL.idstatus * varsort) S.map,
               cons : (IL.kind * IL.con * IL.tystatus) S.map,
               worlds : Variable.var S.map,
               dbs  : unit S.map }

    (* first is class of identifier, second is identifier *)
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
                 | TRef t => has t)
      in
        SU.exists (fn (Poly({worlds, tys}, t), _, _, _) => has t) vars 
      end

    fun world (C{worlds, ...}) s =
      (case S.find (worlds, s) of
         SOME x => x
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

    fun bindex (C {vars, cons, dbs, worlds }) sym typ var stat sort =
        C { vars = S.insert (vars, sym, (typ, var, stat, sort)),
            cons = cons,
            worlds = worlds,
            dbs = dbs }

    fun bindv c sym t v w = bindex c sym t v IL.Normal (Modal w)
    fun bindu c sym typ var stat = bindex c sym typ var stat Valid

    fun bindcex (C { cons, vars, dbs, worlds }) module sym con kind status =
        C { vars = vars,
            cons = S.insert (cons, sym, (kind, con, status)),
            worlds = worlds,
            dbs = dbs }

    fun bindc c sym con kind status = bindcex c NONE sym con kind status

    fun bindw (C { cons, vars, dbs, worlds }) s v =
        C { vars = vars,
            cons = cons,
            worlds = S.insert (worlds, s, v),
            dbs = dbs }

    val empty = C { worlds = S.empty, vars = S.empty, cons = S.empty, 
                    dbs = S.empty }

end
