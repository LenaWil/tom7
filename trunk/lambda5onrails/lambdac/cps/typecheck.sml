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

  (* since all worlds are variables, we must at least bind the
     world we're starting at *)
  fun empty (W w) = C { tvars = V.Map.empty,
                        worlds = V.Set.add'(w, V.Set.empty),
                        vars = V.Map.empty,
                        uvars = V.Map.empty,
                        current = W w }

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

  fun tmobile G typ = 
    (case ctyp typ of
       TVar v => gettype G v
     | Product ltl => ListUtil.allsecond (tmobile G) ltl
     | Addr _ => true
     | Primcon (INT, []) => true
     | Primcon (STRING, []) => true
     | Primcon (VEC, [t]) => tmobile G t
     | _ => raise TypeCheck "unimplemented tmobile")


  fun unroll (m, tl) =
    (let val (_, t) = List.nth (tl, m)
         val (thet, _) =
           List.foldl (fn((v,t),(thet,idx)) =>
                       (subtt (Mu' (idx, tl)) v thet,
                        idx + 1))
           (t, 0)
           tl
     in
       thet
     end handle _ => raise TypeCheck "malformed mu")

  fun faile exp msg =
    let in
      print "\nIll-typed:\n";
      Layout.print (CPSPrint.etol exp, print);
      raise TypeCheck msg
    end
       
  fun wok G (W w) = getworld G w

  (* here we go... *)
  fun tok G typ =
    case ctyp typ of
      At (c, w) => (wok G w; tok G c)
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
    | Addr w => wok G w
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
    | Primcon (INT, []) => ()
    | Primcon (STRING, []) => ()
    | Primcon (EXN, []) => ()
    | Primcon _ => raise TypeCheck "bad primcon"
    | Sum sail => ListUtil.appsecond (ignore o (IL.arminfo_map ` tok G)) sail

  (* some actions ought only happen at the same world we're in now *)
  fun insistw G w =
    if world_eq (worldfrom G, w) 
    then ()
    else raise TypeCheck ("expected to be at same world: "
                          ^ V.tostring (let val W x = worldfrom G in x end) ^
                          " and "
                          ^ V.tostring (let val W x = w in x end))

  (* check that the expression is well-formed at the world in G *)
  fun eok G exp =
    (case cexp exp of
       Halt => ()
     | ExternVal (v, l, t, wo, e) =>
         let
           val () = Option.app (wok G) wo
           val () = tok G t
           val G = 
             case wo of
               NONE => binduvar G v t
             | SOME w => bindvar G v t w
         in
           eok G e
         end
     | Primop ([v], BIND, [va], e) =>
         let
           val t = vok G va
           val G = bindvar G v t ` worldfrom G
         in
           eok G e
         end
     | Primop ([v], PRIMCALL { sym = _, dom, cod }, vas, e) =>
         let
           val vts = map (vok G) vas
         in
           app (tok G) dom;
           tok G cod;
           if ListUtil.all2 ctyp_eq dom vts
           then eok (bindvar G v cod ` worldfrom G) e
           else raise TypeCheck "primcall argument mismatch"
         end
     | Primop ([v], LOCALHOST, [], e) => eok (binduvar G v ` Addr' ` worldfrom G) e
     | Primop _ => faile exp "unimplemented/bad primop"
     | Call (fv, avl) =>
         (case (ctyp ` vok G fv, map (vok G) avl) of
            (Cont al, al') => if ListUtil.all2 ctyp_eq al al'
                              then ()
                              else raise TypeCheck "argument mismatch at call"
          | _ => faile exp "call to non-cont")
     | ExternWorld (v, _, e) => eok (bindworld G v) e
     | Leta (v, va, e) =>
            (case ctyp ` vok G va of
               At (t, w) => eok (bindvar G v t w) e
             | _ => faile exp "leta on non-at")
     | Letsham (v, va, e) =>
            (case ctyp ` vok G va of
               Shamrock t => eok (binduvar G v t) e
             | _ => faile exp "letsham on non-shamrock")

     | Go (w, va, e) =>
               (wok G w;
                case ctyp ` vok G va of
                  Addr w' => if world_eq (w, w')
                             then eok (setworld G w) e
                             else faile exp "go to wrong world addr"
                | _ => faile exp "go to non-world")

     | Put (v, t, va, e) =>
               (tok G t;
                if tmobile G t
                then let val tt = vok G va
                         val G = binduvar G v t
                     in
                       if ctyp_eq (t, tt)
                       then eok G e
                       else faile exp "annotation on put mismatch"
                     end
                else faile exp "put of non-mobile value")


(*
    | Primop of var list * primop * 'cval list * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    (* type var, contents vars *)
    | TUnpack of var * (var * ctyp) list * 'cval * 'cexp
    | Case of 'cval * var * (string * 'cexp) list * 'cexp
    | ExternWorld of var * string * 'cexp
    (* always kind 0; optional argument is a value import of the dictionary
       for that type *)
    | ExternType of var * string * (var * string) option * 'cexp
*)

    | _ => 
         let in
           print "\nUnimplemented:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise TypeCheck "unimplemented"
         end
         )

  (* check that the value is okay at the current world, return its type *)
  and vok G value : ctyp =
    (case cval value of
       Int i => Primcon'(INT, [])
     | String s => Primcon'(STRING, [])
     | AllLam { worlds, tys, vals, body } =>
         let
           val G = bindworlds G worlds
           val G = bindtypes G tys
           val () = ListUtil.appsecond (tok G) vals
           val G = foldl (fn ((v, t), G) => bindvar G v t (worldfrom G)) G vals
         in
           AllArrow' { worlds = worlds, tys = tys, vals = map #2 vals, 
                       body = vok G body }
         end
     | Record svl => Product' ` ListUtil.mapsecond (vok G) svl

     | Fsel ( va, i ) =>
         (case ctyp ` vok G va of
            Conts tll =>
              if i < length tll andalso i >= 0
              then Cont' ` List.nth (tll, i)
              else raise TypeCheck "fsel out of range"
          | _ => raise TypeCheck "fsel on non-conts")
     | Lams vael =>
         let
           (* check types ok *)
           val () = app (fn (_, args, _) => ListUtil.appsecond (tok G) args) vael
           (* recursive vars *)
           val G = foldl (fn ((v, args, _), G) =>
                          bindvar G v (Cont' ` map #2 args) ` worldfrom G) G vael

         in
           (* check each body under its args *)
           app (fn (_, args, e) =>
                eok (foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args) e) vael;
                
           (* if exps are okay, then use annotations *)
           Conts' (map (fn (_, args, _) => map #2 args) vael)
         end

     | Proj (l, va) =>
            (case ctyp ` vok G va of
               Product stl => (case ListUtil.Alist.find op= stl l of
                                 NONE => raise TypeCheck ("proj label " ^ l ^ " not in type")
                               | SOME t => t)
             | _ => raise TypeCheck "proj on non-product")

     | Dictfor t => (tok G t; Dict' t)

     | Inj (l, t, vo) =>
         let in
           tok G t;
           case ctyp t of
             Sum lal =>
               (case (ListUtil.Alist.find op= lal l, vo) of
                  (NONE, _) => raise TypeCheck ("inj label into sum without that label " ^ l)
                | (SOME NonCarrier, NONE) => t
                | (SOME (Carrier { definitely_allocated, carried }), SOME va) => 
                    let 
                      val tv = vok G va
                    in
                      if ctyp_eq (carried, tv)
                      then t
                      else raise TypeCheck "inj carrier type mismatch"
                    end
                | _ => raise TypeCheck "inj carrier/noncarrier mismatch")

            | _ => raise TypeCheck "inj into non-sum"
         end

     | Var v =>
         let val (t, w) = getvar G v
         in
           insistw G w;
           t
         end

     | UVar v => getuvar G v

     | Roll (t, va) =>
         (tok G t;
          case ctyp t of
            Mu (i, ts) =>
              let
                val tt = vok G va
              in
                if ctyp_eq (tt, unroll (i, ts))
                then t
                else raise TypeCheck "roll mismatch"
              end

          | _ => raise TypeCheck "roll into non-mu")
     | Hold (w, va) => 
         let
           val () = wok G w
           val G = setworld G w
         in
           At' (vok G va, w)
         end

     | Sham (w, va) =>
         let
           val G' = bindworld G w
           val G' = setworld G' (W w)

           val t = vok G' va
         in
           (* type can't mention the bound world;
              suffices to check it in the old context *)
           tok G t;
           Shamrock' t
         end

     | AllApp { f, worlds, tys, vals } =>
         (case ctyp ` vok G f of
            AllArrow { worlds = ww, tys = tt, vals = vv, body = bb } =>
              let
                val () = app (wok G) worlds
                val () = app (tok G) tys
                val () = if length ww = length worlds andalso length tt = length tys
                         then () 
                         else raise TypeCheck "allapp to wrong number of worlds/tys"
                val wl = ListPair.zip (ww, worlds)
                val tl = ListPair.zip (tt, tys)
                fun subt t =
                  let val t = foldr (fn ((wv, w), t) => subwt w wv t) t wl
                  in foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                  end

              in
                (* check args *)
                ListUtil.all2 (fn (va, vt) => ctyp_eq (subt vt, vok G va)) vals vv;
                subt bb
              end
        | _ => raise TypeCheck "allapp to non-allarrow")
            

     | _ => 
         let in
           print "\nUnimplemented:\n";
           Layout.print (CPSPrint.vtol value, print);
           raise TypeCheck "unimplemented"
         end
         )

  fun check w exp = eok (empty w) exp

end