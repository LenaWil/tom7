
(* This is a dirt simple implementation of closure conversion.

   The Hemlock series of compilers had a very compilcated closure
   conversion algorithm that attempted to balance a number of
   constraints to produce as good code as possible. This led to a very
   complex and error-prone implementation. One of the reasons was that
   it was annoying to consider the implications of mutual recursion
   (and implement it), but difficult to just punt on that case without
   making the implementation incorrect.

   This language is more complicated than the Hemlock CPS IL, so the
   closure conversion algorithm cannot be as ambitious. In addition to
   the new machinery having to do with the modal features, we also
   must maintain a dictionary-passing invariant (see dict.sml) during
   this translation.

   Therefore the new strategy is to do something simple and general,
   but then implement things like direct calls for the common case in
   a later optimization pass. This has the advantage that we can more
   easily punt on any difficult cases like mutual recursion. It also may
   subsume and/or be assisted by other optimizations like known-argument
   and tuple flattening optimizations. It also shortens the path to a
   working but slow compiler.

   Several things need to be closure converted. First, obviously, is
   the Fns expression, which is a bundle of mutually-recursive
   functions. The conversion of this is a little tricky because of
   mutual recursion. The straightforward thing is this:

   fns f(x). e1           ==>    
   and g(y). e2


    pack ( ENV ; [dictfor ENV, env = { fv1 = fv1, ... fvn = fvn },
          fns f(env, x). 
              let fv1 = #fv1 env      (except actually leta and lift, see proposal)
                    ...
                  (: create closures for calls to f and g within e1 :)
                  f = (pack ( ENV ; [dictfor ENV, env = env, f] ))
                  g = (pack ( ENV ; [dictfor ENV, env = env, g] ))
                  .. [[e1]]
          and g(env, y).
                  .. same ..
          ])

         where ENV is the record type { fv1 : t1, ... fvn : tn }.

   so the type |(a, b, c) -> d; (e, f, g) -> h|
   becomes     E ENV. [ENV dict, ENV, |(env, [[a]], [[b]], [[c]]) -> [[d]];
                                       (env, [[e]], [[f]], [[g]]) -> [[h]]|]

   And the type (a, b, c) -> d
   becomes     E ENV. [ENV dict, ENV, (env, [[a]], [[b]], [[c]]) -> [[d]]]

   So the question is, what to do with the fsel construct, which has this typing
   rule?

      e : | ts1 -> t1 ; ts2 -> t2 ; ... tsn -> tn | @ w      0 <= m < n
     ------------------------------------------------------------ fsel
                     e . m   :  tsm -> tm @ w

   the translation must take on this type:

      e : E ENV. [ENV dict, ENV, |(env :: ts1) -> t1; ...
                                  (env :: tsn) -> tn|] @ w      0 <= m < n
     ------------------------------------------------------------------------------ fsel?
       e . m   :  E ENV. [ENV dict, ENV, (env, tsm) -> tm]  @ w

   and it must be a value.

   There's only one way to do this. e.m must translate into 

   unpack e as (ENV; [de, env, fs])           <- unpack must be a value then
   in  pack ( ENV ; [de, env, fs.m] ) 

   in many situations (especially for m = 0 and fs a singleton) we should be able to
   optimize this to avoid the immediate packing and unpacking.


   Question: is it really the best choice to have the fns construct dynamically bind
   the individual function variables within itself, or should it bind the bundle and
   then we use fsel to make friend calls? Both seem to work, but the latter seems
   a bit more uniform.


   Other features need to be closure converted as well. They are
   simpler but less standard.

   The AllLam construct allows quantification over value variables;
   we will also closure convert it whenever there is at least one value
   variable. These lambdas are converted pretty much the same way as
   regular lambdas.

   { w; t; t dict } -> c

          ==>

   E env. [env dict, { w; t; env, t dict } -> c]

*)


structure Closure :> CLOSURE =
struct

  structure V = Variable
  structure VS = Variable.Set
  open CPS

  infixr 9 `
  fun a ` b = a b

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  exception Closure of string

  local 
    fun accvarsv (us, s) (value : CPS.cval) : CPS.cval =
      (case cval value of
         Var v => (s := VS.add (!s, v); value)
       | UVar u => (us := VS.add (!us, u); value)
       | _ => pointwisev (fn t => t) (accvarsv (us, s)) (accvarse (us, s)) value)
    and accvarse (us, s) exp = 
      (pointwisee (fn t => t) (accvarsv (us, s)) (accvarse (us, s)) exp; exp)

    (* give the set of all variable occurrences in a value or expression.
       the only sensible use for this is below: *)
    fun allvarse exp = 
           let val us = ref VS.empty
               val s  = ref VS.empty
           in
             accvarse (us, s) exp;
             (!us, !s)
           end
    fun allvarsv value =
           let val us = ref VS.empty
               val s  = ref VS.empty
           in
             accvarsv (us, s) value;
             (!us, !s)
           end

  in
    
    (* Sick or slick? You make the call! *)
    fun freevarsv value =
      (* compute allvars twice; intersection is free vars *)
      let val (us1, s1) = allvarsv value
          val (us2, s2) = allvarsv value
      in
        (VS.intersection (s1, s2), VS.intersection (us1, us2))
      end
    fun freevarse exp = 
      let val (us1, s1) = allvarse exp
          val (us2, s2) = allvarse exp
      in
        (VS.intersection (s1, s2), VS.intersection (us1, us2))
      end

  end

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  (* this can pleasantly be done with pointwise, since it does not need any
     contextual information. *)
  fun ct typ =
    (case ctyp typ of
       Cont tl => 
         let 
           val tl = map ct tl
           val venv = V.namedvar "env"
         in
           TExists' (venv, [Dict' ` TVar' ` venv, 
                            TVar' venv,
                            Cont' (TVar' venv :: tl)])
         end
    | Conts tll => 
         let 
           val tll = map (map ct) tll
           val venv = V.namedvar "env"
         in
           TExists' (venv, [Dict' ` TVar' ` venv, 
                            TVar' venv,
                            (* new arg to each function ... *)
                            Conts' (map (fn l => TVar' venv :: l) tll)])
         end
    (* don't cc these; they are purely static *)
    | AllArrow { worlds, tys, vals = nil, body } => AllArrow' { worlds=worlds, tys=tys, vals=nil,
                                                                body = ct body }
    | AllArrow { worlds, tys, vals, body } => raise Closure "unimplemented allarrow"
    | TExists _ => raise Closure "wasn't expecting to see Exists before cc"
         
    (* cc doesn't touch any other types... *)
    | _ => pointwiset ct typ)

  (* we need to look at the intro and elim forms for
                intro        elim
     cont       (lams/fsel)  call
     conts      lams         fsel
     allarrow   alllam      allapp
     *)
     
  (* Our ability to build closures requires us to know the types of free variables,
     so these translations basically have to bake in type checking...
     *)

  fun ce G exp = 
    (case cexp exp of
       Call (f, args) =>
         let
           val (f, ft) = cv G f
           val (args, argts) = ListPair.unzip ` map (cv G) args
           val vu = V.namedvar "envd"
           val envt = V.namedvar "envt"
           val envv = V.namedvar "env"

           val fv = V.namedvar "f"
         in
           TUnpack' (envt,
                     [(vu, Dict' ` TVar' envt),
                      (envv, TVar' envt),
                      (fv, Cont' (TVar' envt :: argts))],
                     f,
                     Call'(Var' fv, Var' envv :: args))
         end
         
     | Halt => exp
     | ExternVal (v, l, t, wo, e) =>
         let val t = ct t
         in
           ExternVal'
           (v, l, t, wo, 
            ce (case wo of
                  NONE => binduvar G v t
                | SOME w => bindvar G v t w) e)
         end

     | ExternWorld (v, l, e) => 
         ExternWorld' (v, l, ce (bindworld G v) e)

     | Primop ([v], LOCALHOST, [], e) =>
           Primop' ([v], LOCALHOST, [], 
                    ce (binduvar G v ` Addr' ` worldfrom G) e)
           
     | Primop ([v], BIND, [va], e) =>
         let
           val (va, t) = cv G va
           val G = bindvar G v t ` worldfrom G
         in
           Primop' ([v], BIND, [va], ce G e)
         end
     (* not a closure call *)
     | Primop ([v], PRIMCALL { sym, dom, cod }, vas, e) =>
         let
           val vas = map (fn v => #1 ` cv G v) vas
           val cod = ct cod
         in
           Primop'([v], PRIMCALL { sym = sym, dom = map ct dom, cod = cod }, vas,
                   ce (bindvar G v cod ` worldfrom G) e)
         end
     | Leta (v, va, e) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
             At (t, w) => 
               Leta' (v, va, ce (bindvar G v t w) e)
           | _ => raise Closure "leta on non-at"
         end

     | Letsham (v, va, e) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
             Shamrock t => 
               Letsham' (v, va, ce (binduvar G v t) e)
           | _ => raise Closure "letsham on non-shamrock"
         end

     | Put (v, t, va, e) => 
         let
           val t = ct t
           val (va, _) = cv G va
           val G = binduvar G v t
         in
           Put' (v, t, va, ce G e)
         end

       (* go [w; a] e

           ==>

          go_cc [w; [[a]]; env; < envt cont >]
          *)
     | Go (w, addr, body) =>
         let
           val (addr, _) = cv G addr
           val body = ce (T.setworld G w) body

           val (fv, fuv) = freevarse body
           val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

           val envv = V.namedvar "go_env"

         in
           Go_cc' { w = w, 
                    addr = addr,
                    env = env,
                    f = Lam' (V.namedvar "go_unused",
                              [(envv, envt)],
                              wrape (Var' envv, body)) }
         end

     | _ =>
         let in
           print "CLOSURE: unimplemented exp:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise Closure "unimplemented EXP"
         end
         )

  (* Convert the value v; 
     return the converted value paired with the converted type. *)
  and cv G value =
    (case cval value of
       Int _ => (value, Zerocon' INT)
     | String _ => (value, Zerocon' STRING)

     | Record lvl =>
         let 
           val (l, v) = ListPair.unzip lvl
           val (v, t) = ListPair.unzip ` map (cv G) v
         in
           (Record' ` ListPair.zip (l, v),
            Product' ` ListPair.zip (l, t))
         end

     | Var v => 
         let in
           (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
           (value, #1 ` T.getvar G v)
         end
     | UVar v => 
         let in
           (* print ("Lookup " ^ V.tostring v ^ "\n"); *)
           (value, T.getuvar G v)
         end
     | Inj (s, t, vo) => let val t = ct t 
                         in (Inj' (s, ct t, Option.map (#1 o cv G) vo), t)
                         end
     | Hold (w, va) => 
         let
           val G = T.setworld G w
           val (va, t) = cv G va
         in
           (Hold' (w, va),
            At' (t, w))
         end

     | Sham (w, va) =>
         let
           val G' = bindworld G w
           val G' = T.setworld G' (W w)

           val (va, t) = cv G' va
         in
           (Sham' (w, va),
            Shamrock' t)
         end

     | Roll (t, va) => 
         let
           val t = ct t
           val (va, _) = cv G va
         in
           (Roll' (t, va), t)
         end

     | Proj (l, va) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
              Product stl => (case ListUtil.Alist.find op= stl l of
                                NONE => raise Closure ("proj label " ^ l ^ " not in type")
                              | SOME t => (Proj' (l, va), t))
            | _ => raise Closure "proj on non-product"
         end

     | Lams vael => 
(*
   fns f(x). e1           ==>    
   and g(y). e2


    pack ( ENV ; [dictfor ENV, env = { fv1 = fv1, ... fvn = fvn },
          fns f(env, x). 
              let fv1 = #fv1 env      (except actually leta and lift, see proposal)
                    ...
                  (: create closures for calls to f and g within e1 :)
                  f = (pack ( ENV ; [dictfor ENV, env = env, f] ))
                  g = (pack ( ENV ; [dictfor ENV, env = env, g] ))
                  .. [[e1]]
          and g(env, y).
                  .. same ..
          ])

         where ENV is the record type { fv1 : t1, ... fvn : tn }.
*)
         let
           (* not body; we don't want argument occurrences since they are bound by lam *)
           val (fv, fuv) = freevarsv value
           val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

           val vael = map (fn (f, args, body) =>
                           (f, ListUtil.mapsecond ct args, body)) vael

           (* bind all fn variables recursively *)
           val G = foldr (fn ((f, args, body), G) =>
                          let val dom = map #2 args
                          in
                            bindvar G f (Cont' dom) ` worldfrom G
                          end) G vael

           val envtv = V.namedvar "lams_envt"
           val rest = TExists' (envtv, [Dict' ` TVar' envtv, 
                                        TVar' envtv,
                                        Conts' (map (fn (_, args, _) =>
                                                     TVar' envtv :: map #2 args) vael)])

           val envvv = V.namedvar "env"

         in
           (TPack'
            (envt,
             rest,
             [Dictfor' envt,
              env,
              Lams' `
              map (fn (f, args, body) =>
                   let 
                     (* bind args *)
                     val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args
                     val G = bindvar G envvv envt ` worldfrom G
                     (* FIXME bind rec closures *)
                   in
                     (f, (envvv, envt) :: args, wrape (Var' envvv, ce G body))
                   end
                   ) vael]),
            rest)
         end

     | Fsel (v, i) => 

     (* e.m must translate into 
        
        unpack e as (ENV; [de, env, fs]) 
        in  pack ( ENV ; [de, env, fs.m] )  *)
         let
           val (v, t) = cv G v
           val venvt = V.namedvar "fsel_envt"
           val vde = V.namedvar "fsel_de"
           val venv = V.namedvar "fsel_env"
           val vfs = V.namedvar "fsel_fs"
         in
           case ctyp t of
              TExists (vr, [tde, tenv, tfs]) =>
                let
                  val tres = TExists' (vr, [tde, tenv,
                                            case ctyp tfs of
                                              Conts ts =>
                                                (Cont' ` List.nth (ts, i)
                                                 handle _ => raise Closure "fsel out of range")
                                            | _ => raise Closure "fsel texists wasn't conts??"])

                  val tde = subtt (TVar' venvt) vr tde
                  val tenv = subtt (TVar' venvt) vr tenv
                  val tfs = subtt (TVar' venvt) vr tfs

                in
                  (VTUnpack' (venvt,
                              [(vde, tde),
                               (venv, TVar' venvt),
                               (vfs, tfs)],
                              v, (* unpack this *)
                              TPack'
                              (* same environment type,
                                 dict, environment. *)
                              (TVar' venvt,
                               tres,
                               [Var' vde,
                                Var' venv,
                                Fsel' (Var' vfs, i)])),
                   tres)
                end
            | _ => raise Closure "fsel on non-function (didn't translate to Exists 3)"
         end



     (* must have at least one value argument or it's purely static and
        therefore not closure converted *)
     | AllLam { worlds, tys, vals = vals as _ :: _, body } => 
         (*
         { w; t; t dict } -> c
         
         ==>
         
         E env. [env dict, { w; t; env, t dict } -> c]
         *)
         let
           val (fv, fuv) = freevarsv value (* not counting the vars we just bound! *)
           val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

           val envv = V.namedvar "al_env"
           val envtv = V.namedvar "al_envt"
             
           val G = bindworlds G worlds
           val G = bindtypes G tys
           val vals = ListUtil.mapsecond ct vals
           val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vals
           val (body, bodyt) = cv G body

           (* type of this pack *)
           val rest = TExists' (envtv, [Dict' ` TVar' envtv, 
                                        TVar' envtv,
                                        AllArrow' { worlds = worlds, tys = tys,
                                                    vals = TVar' envtv :: map #2 vals,
                                                    body = bodyt }])
         in
           (TPack' (envt, 
                    rest,
                    [Dictfor' envt, 
                     env,
                     AllLam' { worlds = worlds, 
                               tys = tys,
                               vals = (envv, envt) :: vals,
                               body = wrapv (Var' envv, body) }]),
            rest)
         end

     (* ditto on the elim *)
     (* needs to remain a value... *)
     | AllApp { f, worlds, tys, vals = vals as _ :: _ } =>
         let
           val (f, ft) = cv G f
           val tys = map ct tys
           val (vals, valts) = ListPair.unzip ` map (cv G) vals

           val envt = V.namedvar "aa_envt"
           val envv = V.namedvar "aa_env"
           val fv = V.namedvar "aa_f"
         in
           case ctyp ft of
             TExists (envtv, [_, _, aat]) =>
               (case ctyp aat of 
                  AllArrow { worlds = aw, tys = at, vals = _ :: avals, body = abody } =>
                    (VTUnpack' (envt,
                                [(V.namedvar "aa_du", Dict' ` TVar' envt),
                                 (envv, TVar' envt),
                                 (* aad thinks envtype is envtv, so need to
                                    rename to local existential var *)
                                 (fv, subtt (TVar' envt) envtv aat)],
                                f,
                                AllApp' { f = Var' fv,
                                          worlds = worlds,
                                          tys = tys,
                                          vals = Var' envv :: vals }),

                     (* to get result type, do substitution for our actual world/ty
                        arguments into body type *)
                     let
                       val wl = ListPair.zip (aw, worlds)
                       val tl = ListPair.zip (at, tys)
                       fun subt t =
                         let val t = foldr (fn ((wv, w), t) => subwt w wv t) t wl
                         in foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                         end
                     in
                       subt abody
                     end)
                 | _ => raise Closure "allapp non non-allarrow")
           | _ => raise Closure "Allapp on non-exists-allarrow"
         end

     | Dictfor t => 
         let val t = ct t
         in (Dictfor' ` ct t, Dict' t)
         end

(*
         let
           val (f, ft) = cv G f
           val (args, argts) = ListPair.unzip ` map (cv G) args
           val vu = V.namedvar "envd"
           val envt = V.namedvar "envt"
           val envv = V.namedvar "env"

           val fv = V.namedvar "fv"
         in
           TUnpack' (envt,
                     [(vu, Dict' ` TVar' envt),
                      (envv, TVar' envt),
                      (fv, Cont' (TVar' envt :: argts))],
                     f,
                     Call'(Var' fv, Var' envv :: args))
         end
*)


     | _ => 
         let in
           print "CLOSURE: unimplemented val\n";
           Layout.print (CPSPrint.vtol value, print);
           raise Closure "unimplemented VAL"
         end

         )
           
  (* mkenv G (fv, fuv)
     in the context G, make the environment that consists of the free vars fv and
     the free uvars fuv. return the environment value, its type, and two wrapper
     functions that "bind" these free variables within an expression or value,
     respectively. *)
  and mkenv G (fv, fuv) : { env : cval, envt : ctyp, 
                            wrape : cval * cexp -> cexp, 
                            wrapv : cval * cval -> cval } =
    (* environment will take the form of a record.
       the first few labels will hold regular vals, held at their respective worlds.
       *)
    let
      val lab = ref 1 (* start at 1 to make these tuples, so they
                         pretty-print nicer *)
      fun new () = (Int.toString (!lab) before lab := !lab + 1)
      val fvs =  V.Set.foldr op:: nil fv
      val fuvs = V.Set.foldr op:: nil fuv

      val () = print "FV: "
      val () = app (fn v => print (V.tostring v ^ " ")) fvs
      val () = print "\nFUV: "
      val () = app (fn v => print (V.tostring v ^ " ")) fuvs
      val () = print "\n"

      val fvs = map (fn v =>
                     let val (t, w) = T.getvar G v
                       
                     in
                       { label = new (), 
                         typ = t,
                         world = w,
                         var = v }
                     end) fvs
      val fuvs = map (fn v =>
                      let val t = T.getuvar G v
                      in
                        { label = new (),
                          typ = t,
                          var = v }
                      end) fuvs
      fun dowrap LETA LETSHAM env x =
        let
          val x = foldr (fn ({label, typ, var}, x) =>
                         LETSHAM (var, Proj' (label, env), x)) x fuvs
          val x = foldr (fn ({label, typ, world, var}, x) =>
                         LETA (var, Proj' (label, env), x)) x fvs
        in
          x
        end

    in
      { env = Record' `
              (map (fn { label, typ, world, var } =>
                    (label, Hold' (world, Var' var))) fvs @
               map (fn { label, typ, var } =>
                    (label, Sham' (V.namedvar "unused", UVar' var))) fuvs),
        envt = Product' `
               (map (fn { label, typ, world, var } =>
                     (label, At' (typ, world))) fvs @
                map (fn { label, typ, var } =>
                     (label, Shamrock' typ)) fuvs),
        wrape = fn (env, v) => dowrap Leta' Letsham' env v,
        wrapv = fn (env, v) => dowrap VLeta' VLetsham' env v
        }
    end


  fun convert w e =
    ce (T.empty w) e
    handle Match => raise Closure "unimplemented/match"

end
