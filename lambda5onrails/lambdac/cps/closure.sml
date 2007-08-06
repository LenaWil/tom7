
(* FIXME the calls to getdict also need to make sure that they get the
   right ("most recent") dictionary, not just any old one in context. 
   see bugs/cloub.ml5 for failure.

   I already fixed this, right?   -  5 Aug 2007 *)

(* This is a dirt simple implementation of closure conversion.

   The Hemlock series of compilers had a very compilcated closure
   conversion algorithm that attempted to balance a number of
   constraints to produce as good code as possible. This led to a very
   complex and error-prone implementation. One of the reasons was that
   it was annoying to consider the implications of mutual recursion
   (and implement it), but difficult to just punt on that case without
   making the implementation incorrect.

   This language is much more complicated than the Hemlock CPS IL, so
   the closure conversion algorithm cannot be as ambitious. In
   addition to the new machinery having to do with the modal features,
   we also must maintain a dictionary-passing invariant (see dict.sml)
   during this translation.

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
              let fv1 = #fv1 env      (except actually leta and lift; see proposal)
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
   in  
     (... maintain dictionary invt; see dict.sml ...)
    pack ( ENV ; [de, env, fs.m] ) 

   in many situations (especially for m = 0 and fs a singleton) we should be able to
   optimize this to avoid the immediate packing and unpacking.


   Question: is it really the best choice to have the fns construct
   dynamically bind the individual function variables within itself,
   or should it bind the bundle and then we use fsel to make friend
   calls? Both seem to work, but the latter seems a bit more uniform.


   Other features need to be closure converted as well. They are
   simpler but less standard.

   The AllLam construct allows quantification over value variables. We
   won't be able to evaluate the body of an alllam if it quantifies
   over value variables, since we won't know the values of those
   variables. So, we will closure convert it whenever there is at
   least one value argument. These lambdas are converted pretty much
   the same way as regular lambdas.

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

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)



  (* augmentfreevars ctx freesvars freevars freeuvars exemptargs

     When we compute the free variables of some value or expression,
     we also need to provide the dictionaries for some static parts,
     in order to preserve our invariant. Any free type variable must
     have its dictionary included. By free we mean type variables that
     actually occur, but also type variables that occur within type
     types of any free dynamic variables. (Essentially we can think
     of this as the free type variables of the derivation, not of the
     expression or value). We do the same for world variables, which
     are also represented.

     Note that we don't need to include a dictionary in this implicit
     environment if that dictionary is already an explicit argument to
     this function. This is particularly important for our shamrock
     translation, where the immediately embedded alllam is designed to
     establish the dictionary invariant, but also naively triggers the
     need for the dictionary! The 'exemptargs' argument to the
     augmentfreevars function is a list of arguments that will be
     bound directly, for the purposes of this culling.

     *)
  fun augmentfreevars G { w = fw, t = ft } fv fuv exemptargs =
    let
      val () = print "AUGMENT.\nfv:    ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fv;
      val () = print "\nfuv:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fuv;
      val () = print "\nfw:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fw;
      val () = print "\nft:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) ft;

      (* for any free var we already have, we need to get its type
         and world. Those are more sources of free variables. *)
      val (fvt, worlds) = ListPair.unzip ` map (T.getvar G) ` V.Set.listItems fv
      (* only the world variables... *)
      val worlds = List.mapPartial (fn (W w) => SOME w | _ => NONE) worlds

      val fuvt = map (T.getuvar G) ` V.Set.listItems fuv
      (* these types have a bound world; the free vars in "w.t" are
         the same as the freevars in {w}t, so we can use that to
         save a little work *)
      val fuvt = map Shamrock' fuvt

      (* dictionaries are always passed Shamrocked. *)
      val exemptargs = List.mapPartial (fn (_, t) =>
                                        case ctyp t of
                                          (* throwing out the bound self-world
                                             here, but we only test t for
                                             equality against things from
                                             another scope, so if w is used,
                                             this will just never be equal to
                                             anything. *)
                                          Shamrock (w, t) => SOME t
                                        | _ => NONE) exemptargs

      fun exempt_getwdict wv =
        if List.exists (fn t =>
                        case ctyp t of
                          TWdict (W w') => V.eq (wv, w')
                        | _ => false) exemptargs
        then 
          let in
            print ("exempt! (w): " ^ V.tostring wv ^ "\n");
            NONE
          end
        else SOME (T.getwdict G wv)

      fun exempt_getdict tv =
        if List.exists (fn t =>
                        case ctyp t of
                          Primcon(DICTIONARY, [t]) =>
                            (case ctyp t of
                               TVar tv' => V.eq (tv, tv')
                             | _ => false)
                        | _ => false) exemptargs
        then 
          let in
            print ("exempt! (t): " ^ V.tostring tv ^ "\n");
            NONE
          end
        else SOME (T.getdict G tv)

      (* get only those dicts that are not exempt *)
      fun getdicts f vars = V.SetUtil.mappartial f vars

      (* first, the literally occurring world vars *)
      val litw = getdicts exempt_getwdict fw
      val () = print "\naug literalw: "
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) litw

      (* then, the literally occurring type variables *)
      val litt = getdicts exempt_getdict ft
      val () = print "\naug literalt: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) litt

      (* indirect world and type vars appearing in the types of other stuff *)
      val iv = foldl (fn (t, set) =>
                      let
                        val { w = wv, t = tv } = freesvarst t
                        val set = V.Set.union(set, getdicts exempt_getwdict wv)
                        val set = V.Set.union(set, getdicts exempt_getdict  tv)
                      in
                        set
                      end) V.Set.empty (fvt @ fuvt)

      val () = print "\naug indirect: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) iv

      val ivw = getdicts exempt_getwdict (V.SetUtil.fromlist worlds)
      val () = print "\naug judgmentw: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) ivw

    in
      print "\n";
      V.Set.union (fuv, 
                   V.Set.union(litw, 
                               V.Set.union (litt, 
                                            V.Set.union (iv, ivw))))
    end

  (* mkenv G (fv, fuv)
     in the context G, make the environment that consists of the free vars fv and
     the free uvars fuv. return the environment value, its type, and two wrapper
     functions that, when given the environment value, "bind" these free variables 
     within an expression or value respectively. *)
  fun mkenv G (fv, fuv) : { env : cval, envt : ctyp, 
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

      val () = print "mkenv FV: "
      val () = app (fn v => print (V.tostring v ^ " ")) fvs
      val () = print "\nmkenv FUV: "
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


  structure CA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = stuff
                          val Pass = Closure)
    open ID

    (* types. *)

    fun case_Cont z ({selfe, selfv, selft}, G) tl =
         let 
           val tl = map (selft z G) tl
           val venv = V.namedvar "env"
         in
           TExists' (venv, [TVar' venv,
                            Cont' (TVar' venv :: tl)])
         end

    fun case_Conts z ({selfe, selfv, selft}, G) tll =
         let 
           val tll = map (map (selft z G)) tll
           val venv = V.namedvar "env"
         in
           TExists' (venv, [TVar' venv,
                            (* new arg to each function ... *)
                            Conts' (map (fn l => TVar' venv :: l) tll)])
         end

    fun case_AllArrow z ({selfe, selfv, selft}, G) { worlds, tys, vals = nil, body } = 
      AllArrow' { worlds=worlds, tys=tys, vals=nil, body = selft z G body }
      | case_AllArrow _ _ { worlds, tys, vals, body } = 
      raise Closure "unimplemented allarrow"

    fun case_TExists _ _ _ = raise Closure "wasn't expecting to see Exists before closure conversion"



    (* Expressions and values.
       we need to look at the intro and elim forms for
                  intro        elim
       cont       (lams/fsel)  call
       conts      lams         fsel
       allarrow   alllam      allapp
       *)

    (* Our ability to build closures requires us to know the types of free variables,
       so these translations basically have to bake in type checking...
       *)

    fun case_Call z ({selfe, selfv, selft}, G) (f, args) =
         let
           val (f, ft) = selfv z G f
           val (args, argts) = ListPair.unzip ` map (selfv z G) args
           val vu = V.namedvar "envd"
           val envt = V.namedvar "envt"
           val envv = V.namedvar "env"

           val fv = V.namedvar "f"
         in
           TUnpack' (envt,
                     vu,
                     [(envv, TVar' envt),
                      (fv, Cont' (TVar' envt :: argts))],
                     f,
                     Call'(Var' fv, Var' envv :: args))
         end

    (* Only need to convert Say *)
    fun case_Primop z ({selfe, selfv, selft}, G)  ([v], SAY, [k], e) =
         let
           val (k, t) = selfv z G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           Primop' ([v], SAY_CC, [k], selfe z G e)
         end

      | case_Primop z ({selfe, selfv, selft}, G)  (_, SAY_CC, _, _) =
      raise Closure "unexpected SAY_CC before closure conversion"
      | case_Primop z c e = ID.case_Primop z c e


    (* go [w; a] e
       
       ==>
       
       go_cc [w; [[a]]; env; < envt cont >]
       *)
    fun case_Go z ({selfe, selfv, selft}, G)  (wdest, addr, body) =
         let
           val (addr, _) = selfv z G addr
           val body = selfe z (T.setworld G wdest) body

           val (fv, fuv) = freevarse body

           (* See case for Lams.
              note here there are no exempt args.
              *)
           local
             (* all the free variables occuring in the derivation, including the
                world at which it is typed *)
             val { t, w } = freesvarse body
             val { t = _, w = w' } = freesvarsw wdest
           in
             val fuv = augmentfreevars G { t = t, w = VS.union (w, w') } fv fuv nil
           end

           val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

           val envv = V.namedvar "go_env"

         in
           Go_cc' { w = wdest, 
                    addr = addr,
                    env = env,
                    f = Lam' (V.namedvar "go_unused",
                              [(envv, envt)],
                              wrape (Var' envv, body)) }
         end

    (* values. *)


    (*
       fns f(x). e1           ==>    
       and g(y). e2


        pack ( ENV ; dictfor ENV ;  env = { fv1 = fv1, ... fvn = fvn },
              fns f(env, x). 
                  let fv1 = #fv1 env      (except actually leta and letsham; see proposal)
                        ...
                      (: create closures for calls to f and g within e1 :)
                      f = (pack ( ENV ; dictfor ENV ; [env = env, f] ))
                      g = (pack ( ENV ; dictfor ENV ; [env = env, g] ))
                      .. [[e1]]
              and g(env, y).
                      .. same ..
              ])

             where ENV is the record type { fv1 : t1, ... fvn : tn }.
    *)
    fun case_Lams z ({selfe, selfv, selft}, G)  vael =
       let
         val value = Lams' vael

         val () = print "Closure convert Lams: "
         val () = app (fn (v, _, _) => print (V.tostring v ^ " ")) vael;
         val () = print "\n"

         (* not body; we don't want argument occurrences since they are bound by lam *)
         val (fv, fuv) = freevarsv value

         (* we also must store the dictionary for any free type variable. These might
            not show up as free uvars even though they will be generated by undict. *)
         (* nb: this must include not just the type vars we literally mention,
            but the type vars that appear in the types of any of the free variables,
            above. (Essentially anything free in the _derivation_.) *)
         (* PERF do we want/need to include the type/world vars that appear (only) 
            in the arguments? It seems it would be "too late" for them. *)
         (* PERF. not passing along any exempt arguments here;
            we need to compute those arguments that are common to all of the
            lams or else we can't exempt them. It's not clear that exemption ever
            happens here and it is not needed for correctness. *)
         local
           (* all the free variables occuring in the derivation, including the
              world at which it is typed *)
           val { t, w } = freesvarsv value
           val { t = _, w = w' } = freesvarsw ` worldfrom G
         in
           val fuv = augmentfreevars G { t = t, w = VS.union (w, w') } fv fuv nil
         end

         (* val () = print "\nmkenv..\n" *)

         val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

         val vael = map (fn (f, args, body) =>
                         (f, ListUtil.mapsecond (selft z G) args, body)) vael

           (*
         val () = 
             let in
                 print "\n\n\nCONVERTED BODY:\n\n";
                 Layout.print (CPSPrint.vtol (Lams' vael), print);
                 print "\n"
             end
             *)

         (* bind all fn variables recursively *)
       (* 
          wrong -- not closure converted
         val G = foldr (fn ((f, args, body), G) =>
                        let val dom = map #2 args
                        in
                          bindvar G f (Cont' dom) ` worldfrom G
                        end) G vael
         *)

         val envtv = V.namedvar "lams_envt"
         val rest = TExists' (envtv, [TVar' envtv,
                                      Conts' (map (fn (_, args, _) =>
                                                   TVar' envtv :: map #2 args) vael)])

         val envvv = V.namedvar "env"

         (* the recursive closures; one for each of our friends, including ourselves.
            (we get n^2 of these packages here, but most will probably be dead code. 
             For PERF, we could only generate the ones that are free...) *)
         val recs = 
           (* f = (pack ( ENV ; dictfor ENV ; [env = env, f] )) *)
           map (fn (f, args, _) =>
                (* environment has the same type *)
                (f,
                 TPack'(envt,
                        (* this individual fn has Cont type *)
                        TExists' (envtv,
                                  [TVar' envtv,
                                  Cont' (TVar' envtv :: map #2 args)]),
                        Sham0' ` Dictfor' envt,
                        (* but we use the one that came in as an argument *)
                       [Var' envvv,
                        (* and the recursive var *)
                        Var' f]))
                ) vael

         (* bind all closure-converted friends *)
         (* val () = print "friends:\n" *)
         val G = foldr (fn ((f, args, body), G) =>
                        let 
                          val dom = map #2 args
                          val ve = V.namedvar "fenv"
                          val t = TExists' (ve, [TVar' ve,
                                                 Cont' (TVar' ve :: dom)])
                        in
                          (*
                          Layout.print (Layout.indent 2 ` 
                                        Layout.align
                                        [Layout.str (V.tostring f ^ " : "),
                                         Layout.indent 2 ` CPSPrint.ttol t],
                                        print);
                          print "\n";
                          *)
                          bindvar G f t ` worldfrom G
                        end) G vael

         val lams =
            Lams' `
            map (fn (f, args, body) =>
                 let 
                   (* bind args *)
                   val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args
                   val G = bindvar G envvv envt ` worldfrom G

                   val bod = selfe z G body

                   (* creating recursive closures (assumes dictionaries already
                      pulled from environments, so happes on the _inside_) *)
                   val bod = foldr (fn ((v,c), bod) => 
                                    Bind'(v, c, bod)) bod recs

                   (* projecting the components from the environment arg *)
                   val bod = wrape (Var' envvv, bod)
                 in
                   (f, (envvv, envt) :: args, bod)
                 end
                 ) vael
       in
         let val (vs, us) = freevarsv lams
         in case (V.Set.listItems vs, V.Set.listItems us) of
               (nil, nil) =>
                 print ("function " ^ StringUtil.delimit "/" (map (V.tostring o #1) vael) ^
                        " successfully closed.\n")

             | (fv, fuv) => 
                 let in
                   print ("For function " ^ 
                          StringUtil.delimit "/" (map (V.tostring o #1) vael) ^ "...\n" ^
                          "there are still free vars:\n");
                   app (fn v => print ("  " ^ V.tostring v ^ "\n")) fv;
                   print "and free uvars:\n";
                   app (fn v => print ("  " ^ V.tostring v ^ "\n")) fuv;
                   print "the result was:\n";
                   Layout.print (CPSPrint.vtol lams, print);
                   print "\n";
                   raise Closure "closure conversion failed to produce a closed lambda!"
                 end
         end;

         (TPack'
          (envt,
           rest,
           Sham0' ` Dictfor' envt,
           [env, lams]),
          rest)
       end

    fun case_Fsel z ({selfe, selfv, selft}, G)  (v, i) =
      (* e.m must translate into 

         unpack e as (ENV; [de, env, fs]) 
         in  pack ( ENV ; [de, env, fs.m] )  *)
      let
        val (v, t) = selfv z G v
        val venvt = V.namedvar "fsel_envt"
        val vde = V.namedvar "fsel_de"
        val venv = V.namedvar "fsel_env"
        val vfs = V.namedvar "fsel_fs"
      in
        case ctyp t of
           TExists (vr, [tenv, tfs]) =>
             let
               val tres = 
                 TExists' (vr, [tenv,
                                case ctyp tfs of
                                  Conts ts =>
                                    (Cont' ` List.nth (ts, i)
                                     handle _ => raise Closure "fsel out of range")
                                | _ => raise Closure "fsel texists wasn't conts??"])

               val tenv = subtt (TVar' venvt) vr tenv
               val tfs = subtt (TVar' venvt) vr tfs

             in
               (VTUnpack' (venvt,
                           vde,
                           [(* (vde, tde), *)
                            (venv, TVar' venvt),
                            (vfs, tfs)],
                           (* unpack this *)
                           v, 
                           TPack'
                           (* same environment type,
                              dict, environment. *)
                           (TVar' venvt,
                            tres,
                            Sham0' ` UVar' vde,
                            [Var' venv,
                             Fsel' (Var' vfs, i)])),
                tres)
             end
         | _ => raise Closure "fsel on non-function (didn't translate to Exists 3)"
      end


    fun case_VTUnpack _ _ _ = raise Closure "wasn't expecting to see vtunpack before closure conversion"
    fun case_TPack _ _ _ = raise Closure "wasn't expecting to see tpack before closure conversion"

      (* must have at least one value argument or it's purely static and
         therefore not closure converted *)
    fun case_AllLam z ({selfe, selfv, selft}, G) 
        (all as { worlds, tys, vals = vals as _ :: _, body }) =
       (*
       { w; t; t dict } -> c

       ==>

       E env. [env dict, { w; t; env, t dict } -> c]
       *)
       let
         val value = AllLam' all
         val (fv, fuv) = freevarsv value (* not counting the vars we just bound! *)

         (* also potential dictionaries, as above.
            note the exempt arguments: this is necessary for the case that
            this alllam is being used to establish the dictionary invariant!
            *)
         local
           (* all the free variables occuring in the derivation, including the
              world at which it is typed *)
           val { t, w } = freesvarsv value
           val { t = _, w = w' } = freesvarsw ` worldfrom G
         in
           val fuv = augmentfreevars G { t = t, w = VS.union (w, w') } fv fuv vals
         end

         val { env, envt, wrape, wrapv } = mkenv G (fv, fuv)

         val envv = V.namedvar "al_env"
         val envtv = V.namedvar "al_envt"

         val G = bindworlds G worlds
         val G = bindtypes G tys
         val vals = ListUtil.mapsecond (selft z G) vals
         val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G vals
         val (body, bodyt) = selfv z G body

         (* type of this pack *)
         val rest = TExists' (envtv, [TVar' envtv,
                                      AllArrow' { worlds = worlds, tys = tys,
                                                  vals = TVar' envtv :: map #2 vals,
                                                  body = bodyt }])
       in
         (TPack' (envt, 
                  rest,
                  Sham0' ` Dictfor' envt,
                  [env,
                   AllLam' { worlds = worlds, 
                             tys = tys,
                             vals = (envv, envt) :: vals,
                             body = wrapv (Var' envv, body) }]),
          rest)
       end
     (* With no value args, just do the default thing *)
      | case_AllLam z s e = ID.case_AllLam z s e

    (* needs to remain a value... *)
    fun case_AllApp z ({selfe, selfv, selft}, G)  
       { f, worlds, tys, vals = vals as _ :: _ } =
       let
         val (f, ft) = selfv z G f
         val tys = map (selft z G) tys
         val (vals, valts) = ListPair.unzip ` map (selfv z G) vals

         val envt = V.namedvar "aa_envt"
         val envv = V.namedvar "aa_env"
         val fv = V.namedvar "aa_f"

         val vdu = V.namedvar "aa_dus"
       in
         case ctyp ft of
           TExists (envtv, [_, aat]) =>
             (case ctyp aat of 
                AllArrow { worlds = aw, tys = at, vals = _ :: avals, body = abody } =>
                  (VTUnpack' (envt,
                              vdu,
                              [(envv, TVar' envt),
                               (* aad thinks envtype is envtv, so need to
                                  rename to local existential var *)
                               (fv, subtt (TVar' envt) envtv aat)],
                              f,
                              (* maintain dict invariant *)
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
                       let val t = foldr (fn ((tv, ta), t) => subtt ta tv t) t tl
                       in foldr (fn ((wv, w), t) => subwt w wv t) t wl
                       end
                   in
                     subt abody
                   end)
               | _ => raise Closure "allapp non non-allarrow")
         | _ => raise Closure "Allapp on non-exists3-allarrow"
       end
      (* With no value args, just do the default thing *)
      | case_AllApp z s e = ID.case_AllApp z s e

  end

  structure C = PassFn(CA)
  fun convert w e = C.converte () (T.empty w) e
    handle Match => raise Closure "unimplemented/match"

end
