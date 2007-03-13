structure CPSTypeCheck :> CPSTYPECHECK =
struct
  
  open CPS
  infixr 9 `
  fun a ` b = a b

  structure V = Variable

  datatype context = C of { tvars : bool V.Map.map,
                            worlds : V.Set.set,
                            vars : (ctyp * world) V.Map.map,
                            uvars : ctyp V.Map.map }

  val empty = C { tvars = V.Map.empty,
                  worlds = V.Set.empty,
                  vars = V.Map.empty,
                  uvars = V.Map.empty }

  exception TypeCheck of string

  fun bindtype (C {tvars, worlds, vars, uvars}) v mob =
    C { tvars = V.Map.insert(tvars, v, mob), 
        worlds = worlds, vars = vars, uvars = uvars }
  fun bindworld (C {tvars, worlds, vars, uvars}) v =
    C { tvars = tvars, worlds = V.Set.add(worlds, v), vars = vars, uvars = uvars }
  fun bindvar (C {tvars, worlds, vars, uvars}) v t w =
        C { tvars = tvars, worlds = worlds, vars = V.Map.insert (vars, v, (t, w)), 
            uvars = uvars }
  fun binduvar (C {tvars, worlds, vars, uvars}) v t =
        C { tvars = tvars, worlds = worlds, vars = vars,
            uvars = V.Map.insert (uvars, v, t) }

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

  (* here we go... *)
  fun checkwiset f G typ =
    case ctyp typ of
      At (c, W w) => (getworld G w; At' (f G c, W w))
    | Cont l => Cont' ` map (f G) l
    | AllArrow {worlds, tys, vals, body} => 
        let val G = bindworlds G worlds
            val G = bindtypes G tys
        in AllArrow' { worlds = worlds, tys = tys, vals = map (f G) vals, body = f G body }
        end
    | WExists (v, t) => WExists' (v, f (bindworld G v) t)
    | TExists (v, t) => 
        let val G = bindtype G v false
        in TExists' (v, map (f G) t)
        end
      (* XXX check no dupes *)
    | Product stl => Product' ` ListUtil.mapsecond (f G) stl
    | TVar v => (ignore ` gettype G v; typ)
    | Addr (W w) => (getworld G w; typ)
    | Mu (i, vtl) => 
        let val n = length vtl
        in
          if i < 0 orelse i >= n then raise TypeCheck "mu index out of range"
          else ();

          (* nb. here we assume it is not mobile, which for
             the purposes of checking the remainder of the type, should
             not matter. we could also check that the mu is mobile assuming
             the bound vars are mobile, in which case we could safely
             (but pointlessly) assume that it mobile in the context
             
             XXX, actually, I guess a client could use this and then
             ask if a type is mobile later... should FIXME to do as above
             (though we don't use that now)
             *)
          Mu' (i, map (fn (v, t) => (v, f (bindtype G v false) t)) vtl)
        end

    | Conts tll => Conts' ` map (map ` f G) tll
(*
    | Sum sail => Sum' ` ListUtil.mapsecond (IL.arminfo_map f) sail
    | Primcon (pc, l) => Primcon' (pc, map f l)
    | Shamrock t => Shamrock' ` f t
*)

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