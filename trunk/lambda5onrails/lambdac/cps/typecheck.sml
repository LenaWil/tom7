structure CPSTypeCheck :> CPSTYPECHECK =
struct
  
  open CPS
  infixr 9 `
  fun a ` b = a b

  structure V = Variable
  structure SM = StringMap
  structure SS = StringSet

  type cglot = (unit, unit) cglofront

  datatype checkopt = 
      O_CLOSED 
    | O_NO_DICTFOR
    (* shouldn't see nested lams, shouldn't use recursive vars *)
    | O_HOISTED
    | O_EXTERNDICTS

  datatype context = C of { tvars : bool V.Map.map,
                            worlds : V.Set.set,
                            worldlabs : worldkind SM.map,
                            vars : (ctyp * world) V.Map.map,
                            uvars : ctyp V.Map.map,
                            globals : cglot SM.map,
                            current : world,
                            options : checkopt list }

  fun empty w = C { tvars = V.Map.empty,
                    (* only home to start *)
                    worldlabs = SM.insert(SM.empty, Initial.homename, Initial.homekind),
                    worlds = V.Set.empty, (* V.Set.add'(w, V.Set.empty),*)
                    vars = V.Map.empty,
                    uvars = V.Map.empty,
                    globals = SM.empty,
                    current = w,
                    options = nil }

  exception TypeCheck of string

  local
    structure L = Layout
    structure V = Variable
    structure P = CPSPrint

    val $ = L.str
    val % = L.mayAlign
    val itos = Int.toString

    fun two s l = %[$s, L.indent 3 l]
  in
    fun ctol (C { tvars, worlds, vars, uvars, current, worldlabs, globals, options }) =
      %[$"context:",
        L.indent 4 `
        L.align 
        [two "current:" ` P.wtol current,
         two "worlds:" ` L.listex "" "" "," ` map ($ o V.tostring) (V.Set.listItems worlds),
         two "tvars:" ` L.listex "" "" "," ` map (fn (v, b) =>
                                                $(V.tostring v ^
                                                  (if b then " (mobile)"
                                                   else ""))) (V.Map.listItemsi tvars),
         two "vars:" ` L.listex "" "" "," ` map (fn (v, (t, w)) =>
                                               %[$(V.tostring v),
                                                 $":",
                                                 P.ttol t,
                                                 $"@",
                                                 P.wtol w]) (V.Map.listItemsi vars),
         two "uvars:" ` L.listex "" "" "," ` map (fn (v, t) =>
                                                %[$(V.tostring v),
                                                  $"~",
                                                  P.ttol t]) (V.Map.listItemsi uvars)
         (* XXX worldlabs and globals *)
          ]]
  end

  fun bindtype (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) v mob =
    C { tvars = V.Map.insert(tvars, v, mob), current = current,
        worlds = worlds, vars = vars, uvars = uvars, worldlabs = worldlabs, 
        globals = globals, options = options }
  fun bindworld (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) v =
    C { tvars = tvars, worlds = V.Set.add(worlds, v), vars = vars, 
        current = current,
        uvars = uvars, worldlabs = worldlabs, globals = globals, options = options }
  fun bindvar (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) v t w =
        C { tvars = tvars, worlds = worlds, vars = V.Map.insert (vars, v, (t, w)), 
            uvars = uvars, current = current, worldlabs = worldlabs, 
            globals = globals, options = options }
  fun binduvar (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) v t =
        C { tvars = tvars, worlds = worlds, vars = vars, current = current,
            uvars = V.Map.insert (uvars, v, t), worldlabs = worldlabs, 
            globals = globals, options = options }

  fun worldfrom ( C { current, ... } ) = current
  fun setworld ( C { current, tvars, worlds, vars, uvars, worldlabs, globals, options } ) w =
    C { current = w, tvars = tvars, worlds = worlds, vars = vars, uvars = uvars, 
        worldlabs = worldlabs, globals = globals, options = options }

  fun setopts ( C { current, tvars, worlds, vars, uvars, worldlabs, globals, options } ) ol =
    C { current = current, tvars = tvars, worlds = worlds, vars = vars, uvars = uvars, 
        worldlabs = worldlabs, globals = globals, options = ol }

  fun option (C { options, ... }) opt = List.exists (fn oo => oo = opt) options

  fun addglobal (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) s g =
        C { tvars = tvars, worlds = worlds, vars = vars, current = current,
            uvars = uvars, worldlabs = worldlabs, options = options,
            globals = SM.insert (globals, s, g) }
  fun getglobal (C { globals, ...}) s =
    case SM.find (globals, s) of
      NONE => raise TypeCheck ("global not found: " ^ s)
    | SOME g => g

  fun bindworldlab (C {tvars, worlds, vars, uvars, current, worldlabs, globals, options}) s k =
    C { tvars = tvars, worlds = worlds, vars = vars, options = options,
        current = current,
        uvars = uvars, 
        worldlabs = 
        (case SM.find (worldlabs, s) of
           NONE => SM.insert(worldlabs, s, k)
         | SOME kind' => if k = kind' 
                         then worldlabs (* already there *)
                         else raise TypeCheck ("extern worlds at different kind: " ^ s)),
        globals = globals }

  fun gettype (C { tvars, ... }) v = 
    (case V.Map.find (tvars, v) of
       NONE => raise TypeCheck ("unbound type var: " ^ V.tostring v)
     | SOME b => b)

  fun cleardyn (C { tvars, worlds, vars, uvars, current, worldlabs, globals, options }) =
      C { vars = V.Map.empty,
          uvars = V.Map.empty,
          tvars = tvars,
          worlds = worlds,
          current = current,
          worldlabs = worldlabs,
          globals = globals,
          options = options }

  fun getworld (C { worlds, ... }) (W v) = 
    if V.Set.member (worlds, v) then () 
    else raise TypeCheck ("unbound world var: " ^
                          V.tostring v)
    | getworld (C { worldlabs, ...}) (WC l) =
      if isSome ` SM.find (worldlabs, l) then ()
      else raise TypeCheck ("unknown world constant " ^ l)

  fun getvar (ctx as C { vars, ... }) v =
    (case V.Map.find (vars, v) of
       NONE => 
         let in
           print "\n\nContext:\n";
           Layout.print(ctol ctx, print);
           raise TypeCheck ("unbound var: " ^ V.tostring v)
         end
     | SOME x => x)
  fun getuvar (C { uvars, ... }) v =
    (case V.Map.find (uvars, v) of
       NONE => raise TypeCheck ("unbound uvar: " ^ V.tostring v)
     | SOME x => x)


  fun getdict (ctx as C { uvars, ... }) tv =
    let 
      val m = V.Map.mapPartial (fn t => 
                                case ctyp t of
                                  Primcon(DICTIONARY, [t]) =>
                                    (case ctyp t of
                                       TVar tv' => if V.eq (tv, tv')
                                                   then SOME ()
                                                   else NONE
                                     | _ => NONE)
                                 | _ => NONE) uvars
    in
      ignore ` gettype ctx tv;
      (* finds any match in scope, since "t Dictionary" is a singleton type *)
      (case V.Map.listItemsi m of
         nil => 
           let in
             print "\n\nINVARIANT VIOLATION!\n";
             Layout.print (ctol ctx, print);
             raise TypeCheck ("invariant violated: no dictionary for type var " ^
                              V.tostring tv ^ " in context")
           end
       | (l as ((vv, ()) :: _)) =>
           let in
             print ("\nDictionaries for " ^ V.tostring tv ^ "\n");
             app (fn (vv, ()) => print ("  " ^ V.tostring vv ^ "\n")) l;
             vv
           end)
    end

  fun getwdict (ctx as C { uvars, ... }) wv =
    let 
      val m = V.Map.mapPartial (fn t => 
                                case ctyp t of
                                  TWdict (W wv') =>
                                    if V.eq (wv, wv')
                                    then SOME ()
                                    else NONE
                                | _ => NONE) uvars
    in
      ignore ` gettype ctx wv;
      (* finds any match in scope, since "t wdict" is a singleton type *)
      (case V.Map.listItemsi m of
         nil => 
           let in
             print "\n\nINVARIANT VIOLATION!\n";
             Layout.print (ctol ctx, print);
             raise TypeCheck ("invariant violated: no world dictionary for world var " ^
                              V.tostring wv ^ " in context")
           end
       | (l as ((vv, ()) :: _)) =>
           let in
             print ("\nDictionaries for worldvar " ^ V.tostring wv ^ "\n");
             app (fn (vv, ()) => print ("  " ^ V.tostring vv ^ "\n")) l;
             vv
           end)
    end


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

  datatype error =
      TY of ctyp
    | TYL of ctyp list
    | $ of string
    | VA of cval
    | EX of cexp
    | V of var
    | VS of var list
    (* var is bound in the type; don't display the type, just use it
       to decide whether var is _ *)
    | BT of var * ctyp
    | IN of error

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

  fun fail err =
    let 
      fun errtol (TY t) = CPSPrint.ttol t
        | errtol (TYL tl) = Layout.listex "<" ">" ";" ` map CPSPrint.ttol tl
        | errtol ($ s) = Layout.str s
        | errtol (VA v) = CPSPrint.vtol v
        | errtol (VS vs) = Layout.listex "[" "]" "," ` map (Layout.str o V.tostring) vs
        | errtol (EX e) = CPSPrint.etol e
        | errtol (V v) = Layout.str ` V.tostring v
        | errtol (BT (v, t)) = CPSPrint.vbindt v t
        | errtol (IN e) = Layout.indent 3 ` errtol e
    in
      print "\n\n";
      Layout.print (Layout.mayAlign (map errtol err), print);
      raise TypeCheck "(see above)"
    end

  fun faile exp msg = fail [$"\n\nIll-typed: ", EX exp, $"\n", $msg]
       
  val wok = getworld
  (* fun wok G w = getworld G w *)

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
    | TWdict w => wok G w
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

  fun wtos (W w) = V.tostring w
    | wtos (WC c) = "##" ^ c

  (* some actions ought only happen at the same world we're in now *)
  fun insistw G w =
    if world_eq (worldfrom G, w) 
    then ()
    else raise TypeCheck ("expected to be at same world: "
                          ^ wtos ` worldfrom G
                          ^ " and "
                          ^ wtos w)

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

     | Primop ([v], SAY, [k], e) =>
         let
           val t = vok G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           (* XXX insist that we are at home... *)
           (* arg must be a unit cont *)
           if ctyp_eq (Cont' [Product' nil], t)
           then eok G e
           else fail [$"primop say expects unit cont",
                      $"actual: ", TY t]
         end

     | Primop ([v], SAY_CC, [k], e) =>
         let
           val t = vok G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           (* XXX insist that we are at home... *)
           (* arg must be a unit cont *)
           if ctyp_eq (t,
                       let val venv = V.namedvar "tc_venv"
                       in
                         TExists' (venv, [TVar' venv,
                                          Cont' [TVar' venv, Product' nil]])
                       end)
           then eok G e
           else fail [$"primop say_cc expects closure-converted unit cont",
                      $"actual: ", TY t]
         end


     | Primop ([v], NATIVE { po, tys }, l, e) =>
         (case Podata.potype po of
            { worlds = nil, tys = tvs, dom, cod } =>
              let
                val argts = map (vok G) l

                val s = ListUtil.wed tvs tys
                fun dosub tt = foldr (fn ((tv, t), tt) => subtt t tv tt) tt s 

                val dom = map (dosub o ptoct) dom
                val cod = dosub ` ptoct cod

                (* check args *)
                val () = app (fn (argt, domt) =>
                              if ctyp_eq (argt, domt)
                              then ()
                              else fail [$"primop arg mismatch",
                                         $"actual: ", TY argt,
                                         $"expected: ", TY domt,
                                         $"prim: ", $(Podata.tostring po)]) ` 
                           ListUtil.wed argts dom

                val G = bindvar G v cod ` worldfrom G
              in
                eok G e
              end
          | _ => faile exp "unimplemented: primops with world args")

     | Primop ([v], MARSHAL, [vd, va], e) =>
         let
           val td = vok G vd
           val ta = vok G va
           (* Always the same result *)
           val G = bindvar G v (Zerocon' BYTES) ` worldfrom G
         in
           case ctyp td of
             Primcon(DICTIONARY, [t]) => if ctyp_eq (t, ta)
                                         then eok G e
                                         else fail[$"marshal dict/arg mismatch",
                                                   $"dict arg: ", TY t,
                                                   $"actual arg: ", TY ta]
           | _ => raise TypeCheck "marshal: need dict and arg"
         end
     | Primop (_, MARSHAL, _, _) => raise TypeCheck "bad marshal primop"

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
                              else fail [$"argument mismatch at call.",
                                         $"function's domain: ", TYL al,
                                         $"actual: ", TYL al',
                                         $"function exp: ", VA fv
                                         ]
          | (ot, _) => fail [$"call to non-cont",
                             $"in exp: ", EX ` exp,
                             $"got: ", TY (ctyp' ot)]
                                
                                )
     | ExternWorld (l, k, e) => eok (bindworldlab G l k) e
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

     | Go_cc { w, addr = va, env, f = bod } =>
               (wok G w;
                case (ctyp ` vok G va, 
                      (* env and body have to be at remote world *)
                      vok (setworld G w) env, 
                      ctyp ` vok (setworld G w) bod) of
                    (Addr w', tenv, Cont [tenv']) => 
                      let
                      in
                        if ctyp_eq (tenv, tenv')
                        then if world_eq (w, w')
                             then ()
                             else fail [$"go_cc world/addr mismatch"]
                        else fail [$"in go_cc, env doesn't match arg:",
                                   $"env: ", TY tenv,
                                   $"arg: ", TY tenv']
                      end
                   | _ => fail [$"go_cc args not of right form"])

     | Go_mar { w, addr = va, bytes } =>
               (wok G w;
                case (ctyp ` vok G va, 
                      ctyp ` vok G bytes) of
                    (Addr w', Primcon(BYTES, [])) => 
                      if world_eq (w, w')
                      then ()
                      else fail [$"go_mar world/addr mismatch"]
                   | _ => fail [$"go_mar args not of right form (want addr and bytes)"])

     | Put (v, va, e) =>
               let val t = vok G va
               in
                 if tmobile G t
                 then eok (binduvar G v t) e
                 else faile exp "put of non-mobile value"
               end

     | TUnpack (tv, vd, vvs, va, e) =>
               (case ctyp ` vok G va of
                  TExists (vr, tl) =>
                    let 
                      val tl = map (subtt (TVar' tv) vr) tl
                      val () = if ListUtil.all2 ctyp_eq tl (map #2 vvs)
                               then ()
                               else fail [$"tunpack val args don't agree: ",
                                          $"from typ of object: ", V vr, $".", TYL tl,
                                          $"stated: ", V tv, $".", TYL ` map #2 vvs]
                      (* new type, can't be mobile *)
                      val G = bindtype G tv false
                      (* its dictionary *)
                      val G = binduvar G vd ` Dictionary' ` TVar' tv
                      (* some values now *)
                      val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs
                    in
                      eok G e
                    end
                | t => fail [$"tunpack non-exists: ",
                             IN ` EX exp,
                             $"has type: ",
                             IN ` TY ` ctyp' t])

    | Case (va, v, arms, def) =>
       (case ctyp ` vok G va of
          Sum stl =>
            let
              fun armok (s, e) =
                case ListUtil.Alist.find op= stl s of
                  NONE => fail [$"arm ", $s, $" not found in case sum type"]
                | SOME NonCarrier => eok G e (* var not bound *)
                | SOME (Carrier { carried = t, ... }) => 
                    eok (bindvar G v t ` worldfrom G) e
            in
              app armok arms;
              eok G def
            end
        | _ => fail [$"case on non-sum"])

(*
      dictionaries!
    | Primop of var list * primop * 'cval list * 'cexp
    (* world var, contents var *)
    | WUnpack of var * var * 'cval * 'cexp
    | ExternWorld of var * string * 'cexp
*)

    | ExternType (v, l, dicto, e) =>
          let
            val () = print "Externtype.\n"
            (* XXX should support mobile types here? *)
            val G = bindtype G v false
            (* and dictionary, if there... *)
            val G = case dicto of
                      NONE => if option G O_EXTERNDICTS
                              then fail [$"O_EXTERNDICTS expected dict in ",
                                         $("extern type " ^ l)]
                              else G
                    | SOME (dv, _) => binduvar G dv ` Dictionary' ` TVar' v
          in
            print "context:\n";
            Layout.print (ctol G, print);
            print "\n\n";
            eok G e
          end

    | _ => 
         let in
           print "\nUnimplemented:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise TypeCheck "unimplemented"
         end
         )

  and requireclosedv s value =
      let val (vs, us) = freevarsv value
      in case (V.Set.listItems vs, V.Set.listItems us) of
          (nil, nil) => ()
        | (vs, us) => fail [$"ILL-TYPED: ",
                            VA value,
                            $"O_CLOSED: ", $(s ^ " is not closed "),
                            $"because it has the following free variables:",
                            $"regular: ", VS vs, 
                            $"universal: ", VS us]
      end


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
           if option G O_CLOSED
           then requireclosedv "alllam" value
           else ();

           AllArrow' { worlds = worlds, tys = tys, vals = map #2 vals, 
                       body = vok G body }
         end
     | Record svl => Product' ` ListUtil.mapsecond (vok G) svl

     | Unroll va =>
         (case ctyp ` vok G va of
            Mu (n, vtl) => unroll (n, vtl)
          | _ => fail [$"unroll on non-mu"])

     | TPack (t, tas, vd, vs) =>
         (case (tok G tas; ctyp tas) of
            TExists (v, tl) =>
              let
                val () = tok G t
                val td = vok G vd
                val ts = map (vok G) vs
                  
                (* after substituting in the packed type for the 
                   existential variable, does the actual type match? *)
                val stl = map (subtt t v) tl
              in
                (case ctyp td of
                   Shamrock d =>
                     (case ctyp d of
                        Primcon(DICTIONARY, [t']) =>
                          if ctyp_eq (t, t')
                          then () 
                          else fail [$"tpack dictionary is not for the right type: ",
                                     TY t,
                                     $"dict: ", TY t']
                      | _ => fail [$"tpack dictionary not a shamrock'd dictionary: ",
                                   TY td])
                 | _ => fail [$"tpack dictionary not a shamrock'd dictionary: ",
                              TY td]);
                if ListUtil.all2 ctyp_eq stl ts
                then tas 
                else fail [$"tpack doesn't match annotation: ",
                           $"from typ of packed things: ", TYL ts,
                           $"annotation: ", TYL stl]
              end
          | _ => raise TypeCheck "tpack as non-existential")

     | WDict s => TWdict' ` WC s
     | WDictfor w => (wok G w; TWdict' w)

     | Dict tf =>
       let
         fun edict' s (Primcon(DICTIONARY, [t])) = t
           | edict' s _ = raise TypeCheck (s ^ " dict with non-dicts inside")

         fun ewdict' s (TWdict w) = w
           | ewdict' s _ = raise TypeCheck (s ^ " dict with non-wdict inside")

         fun edict s t = edict' s ` ctyp t
         fun ewdict s t = ewdict' s ` ctyp t
       in
         case tf of
            Primcon(pc, dl) =>
              let
                val tl = map (vok G) dl
                val ts = map (edict "primcon") tl
              in
                (* XXX should check arity of primcon, I guess? 
                   not obvious that Dict(Primcon(REF, [])) shouldn't have
                   type Primcon(REF, []) Dictionary, though that type
                   classifies no values... *)
                Dictionary' ` Primcon'(pc, ts)
              end
          | Mu (n, arms) =>
              Dictionary' ` Mu' (n,
                                 let
                                   (* everything bound in all arms *)
                                   val G = foldr (fn (((vt, vd), _), G) =>
                                                  let
                                                    val G = bindtype G vt false
                                                    val G = binduvar G vd ` Dictionary' ` TVar' vt
                                                  in
                                                    G
                                                  end) G arms
                                   fun one ((vt, _), t) = (vt, edict "mu" ` vok G t)
                                 in
                                   map one arms
                                 end)

          | Product stl =>
              Dictionary' ` Product' ` ListUtil.mapsecond (fn v => edict "prod" ` vok G v) stl

          | Sum stl =>
              Dictionary' ` Sum' ` ListUtil.mapsecond (IL.arminfo_map (fn v => edict "sum" ` vok G v)) stl

          | Shamrock t => Dictionary' ` Shamrock' ` edict "sham" ` vok G t
          | TWdict w => Dictionary' ` TWdict' (ewdict "twdict" ` vok G w)
          | Addr w => Dictionary' ` Addr' (ewdict "addr" ` vok G w)
          | At (t, w) => Dictionary' ` At' (edict "at" ` vok G t, ewdict "at" ` vok G w)
          | TExists((v1, v2), vl) =>
              let
                val G = bindtype G v1 false
                val G = binduvar G v2 (Dictionary' ` TVar' v1)
              in
                Dictionary' ` TExists' (v1, map (fn v => edict "texists" ` vok G v) vl)
              end

          | Cont tl => Dictionary' ` Cont' ` map (fn v => edict "cont" ` vok G v) tl
          | Conts tll => Dictionary' ` Conts' ` map (map (fn v => edict "conts" ` vok G v)) tll

          | AllArrow { worlds, tys, vals, body } =>
              let
                (* static worlds *)
                val G = bindworlds G (map #1 worlds)
                (* world representations *)
                val G = foldr (fn ((w, wd), G) => binduvar G wd (TWdict' ` W w)) G tys
                (* static types *)
                val G = foldr (fn ((v1, _), G) => bindtype G v1 false) G tys
                (* type representations *)
                val G = foldr (fn ((v1, v2), G) => binduvar G v2 (Dictionary' ` TVar' v1)) G tys
              in
                Dictionary' ` AllArrow' { worlds = map #1 worlds, tys = map #1 tys,
                                          vals = map (fn v => edict "allarrow" ` vok G v) vals,
                                          body = edict "allarrow-body" ` vok G body }
              end
          | TVar _ => fail [$"shouldn't see dict tvar", VA value]

          | _ => fail [$"typecheck unimplemented dict typefront", VA value]
       end

     | VLeta (v, va, ve) =>
            (case ctyp ` vok G va of
               At (t, w) => vok (bindvar G v t w) ve
             | _ => fail [$"leta on non-at: ", VA va])

     | VLetsham (v, va, ve) =>
            (case ctyp ` vok G va of
               Shamrock t => vok (binduvar G v t) ve
             | _ => fail [$"letsham on non-shamrock", VA va])

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
           val G = 
             (* XXX could check for freeness and give a better error... *)
             if option G O_HOISTED
             then G
             else
               foldl (fn ((v, args, _), G) =>
                      bindvar G v (Cont' ` map #2 args) ` worldfrom G) G vael

         in
           (* check each body under its args *)
           app (fn (_, args, e) =>
                eok (foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args) e) vael;

           if option G O_CLOSED
           then requireclosedv "lams" value
           else ();
                
           (* if exps are okay, then use annotations *)
           Conts' (map (fn (_, args, _) => map #2 args) vael)
         end

     | Proj (l, va) =>
            (case ctyp ` vok G va of
               Product stl => (case ListUtil.Alist.find op= stl l of
                                 NONE => raise TypeCheck ("proj label " ^ l ^ " not in type")
                               | SOME t => t)
             | _ => raise TypeCheck "proj on non-product")

     | Dictfor t => (tok G t; Dictionary' t)

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
           (*
           Layout.print (Layout.mayAlign[Layout.str (V.tostring v ^ ": "),
                                         CPSPrint.ttol t,
                                         Layout.str "\n"],
                         print);
           *)
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

     | VTUnpack (tv, vd, vvs, va, ve) =>
         let val t = vok G va
         in
               (case ctyp t of
                  TExists (vr, tl) =>
                    let 
                      (*
                      val () = print "\nVTUNPACK:\n"
                      val () = Layout.print(CPSPrint.ttol t, print)
                      val () = print "\n---------------\n"
                      val () = Layout.print(CPSPrint.vtol value, print)
                      *)
                      val tl = map (subtt (TVar' tv) vr) tl
                      val vs = map #2 vvs
                      val () = if ListUtil.all2 ctyp_eq tl vs
                               then ()
                               else fail [$"vtunpack val args don't agree",
                                          $"from packed value: ", BT (vr, Cont' tl), $".", 
                                             IN ` TYL tl,
                                          $"from unpack annotations: ", BT (tv, Cont' vs), $".", 
                                             IN ` TYL vs]
                      (* new type, can't be mobile *)
                      val G = bindtype G tv false
                      (* its dictionary *)
                      val G = binduvar G vd ` Dictionary' ` TVar' tv
                      (* some values now *)
                      val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vvs
                    in
                      vok G ve
                    end
                | _ => raise TypeCheck "vtunpack non-exists")
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
            
     | Codelab s =>
        (case getglobal G s of
           Code ((), t, w) =>
             let in
               insistw G (WC w);
               t
             end
         | PolyCode (wv, (), t) => 
             let 
               val current = worldfrom G
             in
               subwt current wv t
             end)

     | _ => 
         let in
           print "\nUnimplemented val:\n";
           Layout.print (CPSPrint.vtol value, print);
           raise TypeCheck "unimplemented"
         end
         )

  fun check G exp = 
    let in
      print "\n\nTypecheck:\n";
      eok G exp
    end

  fun checkprog ({ main, worlds, globals } : program) =
    let
      (* we'll reset the current world before checking each global *)
      val G = empty (WC "dummy")
      val G = setopts G [O_CLOSED, O_HOISTED, O_NO_DICTFOR]

      fun bindglobal ((s, Code (va, t, wc)), G) = addglobal G s (Code ((), t, wc))
        | bindglobal ((s, PolyCode (v, va, t)), G) = addglobal G s (PolyCode (v, (), t))

      val G = foldr bindglobal G ` ListUtil.mapsecond cglo globals

      val G = foldr (fn ((s, k), G) => bindworldlab G s k) G worlds

      fun checkglobal (lab, glo) = 
        case cglo glo of
           (Code (va, t, w)) =>
             (let
                val G = setworld G (WC w)
                val t' = vok G va
              in
                if ctyp_eq (t, t')
                then ()
                else fail [$lab, $":",
                           $"Code global's type doesn't match annotation",
                           $"type:", TY t',
                           $"annotation:", TY t]
              end handle TypeCheck s =>
                raise TypeCheck ("In Code label " ^ lab ^ ":\n" ^ s))
                
         | (PolyCode (wv, va, t)) => 
             (let
                val G = bindworld G wv
                val G = setworld G (W wv)
                val t' = vok G va
              in
                if ctyp_eq (t, t')
                then ()
                else fail [$lab, $":",
                           $"PolyCode global's type doesn't match annotation",
                           $"type:", TY t',
                           $"annotation:", TY t]
              end handle TypeCheck s =>
                raise TypeCheck ("In PolyCode label " ^ lab ^ ":\n" ^ s))

    in
       (* Doesn't matter what main is, as long as it exists. *)
      (case ListUtil.Alist.find op= globals main of
         NONE => raise TypeCheck ("The main label doesn't exist: " ^ main)
       | SOME _ => ());

      app checkglobal globals
    end
   
  val checkv = vok

end