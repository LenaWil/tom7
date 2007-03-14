structure CPSTypeCheck :> CPSTYPECHECK =
struct
  
  open CPS
  infixr 9 `
  fun a ` b = a b

  structure V = Variable

  datatype context = C of { tvars : bool V.Map.map,
                            worlds : V.Set.set,
                            vars : (ctyp * world) V.Map.map,
                            uvars : ctyp V.Map.map,
                            current : world }

  fun empty w = C { tvars = V.Map.empty,
                    worlds = V.Set.empty,
                    vars = V.Map.empty,
                    uvars = V.Map.empty,
                    current = w }

  exception TypeCheck of string

  fun bindtype (C {tvars, worlds, vars, uvars, current}) v mob =
    C { tvars = V.Map.insert(tvars, v, mob), current = current,
        worlds = worlds, vars = vars, uvars = uvars }
  fun bindworld (C {tvars, worlds, vars, uvars, current}) v =
    C { tvars = tvars, worlds = V.Set.add(worlds, v), vars = vars, 
        current = current,
        uvars = uvars }
  fun bindvar (C {tvars, worlds, vars, uvars, current}) v t w =
        C { tvars = tvars, worlds = worlds, vars = V.Map.insert (vars, v, (t, w)), 
            uvars = uvars, current = current }
  fun binduvar (C {tvars, worlds, vars, uvars, current}) v t =
        C { tvars = tvars, worlds = worlds, vars = vars, current = current,
            uvars = V.Map.insert (uvars, v, t) }

  fun worldfrom ( C { current, ... } ) = current
  fun setworld ( C { current, tvars, worlds, vars, uvars } ) w =
    C { current = w, tvars = tvars, worlds = worlds, vars = vars, uvars = uvars }

  fun gettype (C { tvars, ... }) v = 
    (case V.Map.find (tvars, v) of
       NONE => raise TypeCheck ("unbound type var: " ^ V.tostring v)
     | SOME b => b)
  fun getworld (C { worlds, ... }) v = if V.Set.member (worlds, v) then () 
                                       else raise TypeCheck ("unbound world var: " ^
                                                             V.tostring v)
  fun getvar (C { vars, ... }) v =
    (case V.Map.find (vars, v) of
       NONE => raise TypeCheck ("unbound var: " ^ V.tostring v)
     | SOME x => x)
  fun getuvar (C { uvars, ... }) v =
    (case V.Map.find (uvars, v) of
       NONE => raise TypeCheck ("unbound uvar: " ^ V.tostring v)
     | SOME x => x)

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  fun tmobile G typ = false (* FIXME *)

  (* here we go... *)
  fun tok G typ =
    case ctyp typ of
      At (c, W w) => (getworld G w; tok G c)
    | Cont l => app (tok G) l
    | AllArrow {worlds, tys, vals, body} => 
        let 
          val G = bindworlds G worlds
          val G = bindtypes G tys
        in 
          app (tok G) vals; 
          tok G body 
        end
    | WExists (v, t) => tok (bindworld G v) t
    | TExists (v, t) => 
        let val G = bindtype G v false
        in app (tok G) t
        end
    (* XXX check no dupes *)
    | Product stl => ListUtil.appsecond (tok G) stl
    | TVar v => ignore ` gettype G v
    | Addr (W w) => getworld G w
    | Mu (i, vtl) => 
        let val n = length vtl
          (* val selfmobile = tmobile G typ *)
        in
          if i < 0 orelse i >= n then raise TypeCheck "mu index out of range"
          else ();

          (* nb. for purposes of typechecking, we never care about
             the mobility of a type var; so don't bother doing the
             check here. *)
            app (fn (v, t) => tok (bindtype G v false) t) vtl
        end

    | Conts tll => app (app ` tok G) tll
    | Shamrock t => tok G t
    | Primcon (VEC, [t]) => tok G t
    | Primcon (REF, [t]) => tok G t
    | Primcon (DICT, [t]) => tok G t
    | Primcon _ => raise TypeCheck "bad primcon"
    | Sum sail => ListUtil.appsecond (ignore o (IL.arminfo_map ` tok G)) sail


  (* hmm, how to get type information if not through annotations?
     and how to get type of an expression if returned by f (re type-check?) *)

  fun checkwisee ft fv fe G exp =
    (case cexp exp of
       Halt => exp
         )

  fun checkwisev ft fv fe G value =
    (case cval value of
       Int i => value
         
         )
end