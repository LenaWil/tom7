
(* FIXME the calls to getdict also need to make sure that they get the
   right ("most recent") dictionary, not just any old one in context. 
   see bugs/cloub.ml5 for failure.

   I already fixed this, right?   -  5 Aug 2007

   No. See bugs/direct-not-closed.ml5.     - 24 Aug 2007
 *)

(* This is a "simple" implementation of closure conversion.

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



   Addendum     23 Aug 2007

   It turns out it's actually much more difficult to undo closure
   conversion than it is to do it somewhat well in the first place,
   and that bad closure representations account for very large
   fraction of the cost of running a program, in large part because
   closures require the reification of type information as
   dictionaries. So we also implement some common cases of direct
   calls. See case_Primop below.

*)


structure Closure :> CLOSURE =
struct

  val opt_directcalls = Params.flag true
        (SOME ("-directcalls",
               "Implement direct calls in closure conversion")) "opt_directcalls"

  structure V = Variable
  structure VS = Variable.Set
  open CPS CPSUtil

  infixr 9 `
  fun a ` b = a b
  fun I x = x

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
(*
      val () = print "AUGMENT.\nfv:    ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fv;
      val () = print "\nfuv:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fuv;
      val () = print "\nfw:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) fw;
      val () = print "\nft:   ";
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) ft;
*)

      (* for any free var we already have, we need to get its type
         and world. Those are more sources of free variables. *)
      val (fvt, worlds) = ListPair.unzip ` map (T.getvar G) ` V.Set.listItems fv
      (* only the world variables... *)
      val worlds = List.mapPartial (fn (W w) => SOME w | _ => NONE) (map world worlds)

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
                          TWdict wor => 
                            (case world wor of
                               W w' => V.eq (wv, w')
                             | _ => false)
                        | _ => false) exemptargs
        then 
          let in
            (* print ("exempt! (w): " ^ V.tostring wv ^ "\n"); *)
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
            (* print ("exempt! (t): " ^ V.tostring tv ^ "\n"); *)
            NONE
          end
        else SOME (T.getdict G tv)

      (* get only those dicts that are not exempt *)
      fun getdicts f vars = V.SetUtil.mappartial f vars

      (* first, the literally occurring world vars *)
      val litw = getdicts exempt_getwdict fw
      (*
      val () = print "\naug literalw: "
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) litw
      *)
      (* then, the literally occurring type variables *)
      val litt = getdicts exempt_getdict ft
      (*
      val () = print "\naug literalt: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) litt
      *)

      (* indirect world and type vars appearing in the types of other stuff *)
      val iv = foldl (fn (t, set) =>
                      let
                        val { w = wv, t = tv } = freesvarst t
                        val set = V.Set.union(set, getdicts exempt_getwdict wv)
                        val set = V.Set.union(set, getdicts exempt_getdict  tv)
                      in
                        set
                      end) V.Set.empty (fvt @ fuvt)

      (*
      val () = print "\naug indirect: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) iv
      *)
      val ivw = getdicts exempt_getwdict (V.SetUtil.fromlist worlds)
    (*
      val () = print "\naug judgmentw: " 
      val () = V.Set.app (fn v => print (V.tostring v ^ " ")) ivw
      *)

    in
      (* print "\n"; *)
      V.Set.union (fuv, 
                   V.Set.union(litw, 
                               V.Set.union (litt, 
                                            V.Set.union (iv, ivw))))
    end

  (* for each of the free variables, give the wrapped value,
     a function that unwraps that value to bind it within an
     expression or value, and the type of the wrapped value. *)
  fun getenv G (fv, fuv) : { value : cval,
                             binde : cval  ->  cexp  ->  cexp,
                                 (* freeval   openbody   res *)
                             bindv : cval  ->  cval  ->  cval,
                             basename : string,
                             wrapped_typ : ctyp } list =
    let
      val fvs =  V.Set.foldr op:: nil fv
      val fuvs = V.Set.foldr op:: nil fuv

      (* avoid wrapping if we're at the same world already. *)
      val here = worldfrom G
      fun maybehold (world, value) =
        if world_eq (world, here)
        then value
        else Hold' (world, value)
      fun maybeat (typ, world) =
        if world_eq (world, here)
        then typ
        else At' (typ, world)

      fun maybeleta LET LETA world (var, value, body) =
        if world_eq (world, here)
        then LET  (var, value, body)
        else LETA (var, value, body)


      val fvs = map (fn v =>
                     let val (t, w) = T.getvar G v
                       
                     in
                       { wrapped_typ = maybeat (t, w),
                         binde = (fn atv =>
                                  fn exp =>
                                   maybeleta Bind' Leta' w (v, atv, exp)),
                         bindv = (fn atv =>
                                  fn vbod =>
                                   maybeleta 
                                      (fn (v, atv, vbod) =>
                                       subvv atv v vbod) 
                                      VLeta' w (v, atv, vbod)),
                         value = maybehold (w, Var' v),
                         basename = Variable.basename v }
                     end) fvs
      val fuvs = map (fn v =>
                      let val w't = T.getuvar G v
                      in
                        { value = Sham0' (UVar' v),
                          binde = (fn shv =>
                                   fn exp =>
                                    Letsham' (v, shv, exp)),
                          bindv = (fn shv =>
                                   fn vbod =>
                                    VLetsham' (v, shv, vbod)),
                          wrapped_typ = Shamrock' w't,
                          basename = Variable.basename v }
                      end) fuvs

    in
      fvs @ fuvs
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

(*
      val () = print "mkenv FV: "
      val () = VS.app (fn v => print (V.tostring v ^ " ")) fv
      val () = print "\nmkenv FUV: "
      val () = VS.app (fn v => print (V.tostring v ^ " ")) fuv
      val () = print "\n"
*)
      
      val env = getenv G (fv, fuv)
      val env = map (fn { value, bindv, binde, basename, wrapped_typ } =>
                     { value = value,
                       bindv = bindv,
                       binde = binde,
                       basename = basename,
                       wrapped_typ = wrapped_typ,
                       label = new () }) env

    in
      { env = Record' `
              map (fn { label, value, ... } => (label, value)) env,
        envt = Product' `
               map (fn { label, wrapped_typ, ... } => (label, wrapped_typ)) env,

        wrape = 
           foldr (fn ({ label, binde : cval -> cexp -> cexp, ... }, 
                      k : cval * cexp -> cexp) =>
                  (fn (envr : cval, e : cexp) => binde (Proj' (label, envr)) (k (envr,e))))
                  (fn (_ : cval, e : cexp) => e) env,

        wrapv = 
           foldr (fn ({ label, bindv, ... }, k) =>
                  fn (envr, va) => bindv (Proj' (label, envr)) (k (envr, va)))
                  (fn (_, va) => va) env

        }
    end

  (* PERF no longer using this variable set. we use the type information *)
  structure VS = Variable.Set
  type stuff = VS.set

  structure CA : PASSARG where type stuff = stuff =
  struct
    type stuff = stuff
    structure ID = IDPass(type stuff = stuff
                          val Pass = Closure)
    open ID

    (* types. *)

    fun case_Cont z ({selfe, selfv, selft}, G) tl =
         let 
           val tl = map (selft z G) tl
           val venv = V.namedvar (* "env" *) (Nonce.nonce ())
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

    fun case_TExists _ _ _ = 
      raise Closure "wasn't expecting to see Exists before closure conversion"



    (* Expressions and values.
       we need to look at the intro and elim forms for
                  intro        elim
       cont       (lams/fsel)  call
       conts      lams         fsel
       allarrow   alllam      allapp
       *)

    (* This may be a closure call or an (already converted) direct call.
       We don't try to track the flow of particular values: even
       functions that initially are all direct calls--and so can be
       identified by a single binder--can later be put inside closures
       and therefore renamed. Instead, we use the type of the thing
       we're calling to determine how the call should be made. If it
       is a packed existential type, then it is a closure call. If it
       is a bare continuation, then it is a direct call. *)
    fun case_Call z (s as ({selfe, selfv, selft}, G)) (a as (f, args)) =
      let
        val (f, ft) = selfv z G f
      in
        case ctyp ft of
          Cont _ => 
            let in
              (*
              print ("direct call to ");
              Layout.print (CPSPrint.vtol f, print);
              print "\n";
              *)
              (* this was already converted as a direct call, then. *)
              ID.case_Call z s a
            end
        | TExists _ => 
            let
              val (args, argts) = ListPair.unzip ` map (selfv z G) args
              val vu = V.namedvar "envd"
              val envt = V.namedvar "envt"
              val envv = V.namedvar "env"

              val fv = V.namedvar "f"
            in
              (*
              print ("closure call to ");
              Layout.print (CPSPrint.vtol f, print);
              print "\n";
              *)
              TUnpack' (envt,
                        vu,
                        [(envv, TVar' envt),
                         (fv, Cont' (TVar' envt :: argts))],
                        f,
                        Call'(Var' fv, Var' envv :: args))
            end
        | _ => raise Closure "for a call, we expect a raw cont (direct call) or texists (closure call)"
      end

    fun free_vars_lams G value =
      let
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
      in
        (fv, fuv)
      end

    fun case_Say z ({selfe, selfv, selft}, G) (v, stl, k, e) =
         let
           val (k, t) = selfv z G k
           val G = bindvar G v (Zerocon' STRING) ` worldfrom G
         in
           raise Closure "unimplemented stl"
         (*  Primop' ([v], SAY_CC, [k], selfe z G e) *)
         end

    fun case_Say_cc _ _ _ =
      raise Closure "unexpected SAY_CC before closure conversion"

    (* The only primop we might convert is Bind, which is part of
       the direct call idiom. *)
    fun case_Primop z (c as ({selfe, selfv, selft}, G)) 
                      (a as ([v], CPS.BIND, [obj], ebod)) =
        (case cval obj of
           Fsel(l, n) =>
             (case cval l of
                (* XXX should support polymorphic lambdas.
                   To do so, we need to find either AllLam (Lams ..) or
                   a plain Lams. Then when search for calls to this,
                   we either find the value v or AllApp(v, ...). The
                   translation of the Lams body is the same, since it is
                   not polymorphically recursive. But what about the
                   free variables? Do they go in the val arguments to
                   the AllLam or to the Lams? probably both? *)
                Lams vael =>
                  let

                    (* are all occurrences direct? *)
                    exception NotDirect
                    fun ndtyp _ = ()

                    fun ndval va =
                      (case cval va of
                         Var vv =>
                           if V.eq(vv, v)
                           then raise NotDirect
                           else ()
                       | _ => appwisev ndtyp ndval ndexp va)

                    and ndexp exp =
                      (case cexp exp of
                         Call (f, args) =>
                           let
                             val () = app ndval args
                           in
                             case cval f of
                               Var vv => () (* okay *)
                             | _ => ndval f
                           end
                       | _ => appwisee ndtyp ndval ndexp exp)

                    (* same, but for recursive calls. these are
                       based on the recursive variable, and we also
                       must consider all of the other recursive
                       friends in this bundle. *)
                    fun rtyp _ = ()
                    fun rval va =
                      (case cval va of
                         Var vv =>
                           if List.exists (fn (v, _, _) => V.eq(vv, v)) vael
                           then (print "not direct: recursive or recursive friend\n";
                                 raise NotDirect)
                           else ()
                       | _ => appwisev rtyp rval rexp va)
                    and rexp exp =
                      (case cexp exp of
                         Call (f, args) =>
                           let
                             val () = app rval args
                           in
                             case cval f of
                               Var vv => () (* okay *)
                             | _ => rval f
                           end
                       | _ => appwisee rtyp rval rexp exp)

                  in
                     let 
                       (* disable optimization if turned off *)
                       val () = if !opt_directcalls
                                then ()
                                else raise NotDirect

                       (* check the whole scope (body) for escapes. *)
                       val () = ndexp ebod

                       (* and check the bodies of the function for escaping
                          self- or friend-calls. 

                          PERF: this can be overconservative if there
                          are unused friends; we should get rid of those
                          in some earlier phase. *)
                       val () = app (fn (_, _, e) => rexp e) vael
                         
                       (* nb. right now G is the same as the outer
                          context, but if we also support direct calls
                          to alllam-lams (we should) then they will
                          need to be added here. *)
                       val (fv, fuv) = free_vars_lams G obj
                       val env = getenv G (fv, fuv)
                       val env = map (fn { binde, bindv, basename, wrapped_typ,
                                           value } =>
                                      { binde = binde,
                                        bindv = bindv,
                                        value = value,
                                        var = V.namedvar (basename ^ "_dc"),
                                        wrapped_typ = wrapped_typ }) env

                       val here = worldfrom G

                       (* we extend the arguments for all of the continuations 
                          in the same way. do this first so that the bodies can
                          be translated with the updated type for the recursive
                          variables. *)
                       val vael =
                         map (fn (v, args, e) =>
                              let 
                                val args = ListUtil.mapsecond (selft z G) args
                                val args =
                                  args @ map (fn { var, wrapped_typ, ...} =>
                                              (var, wrapped_typ)) env
                              in
                                (v, args, e)
                              end) vael

                       (* Now translate the bodies... *)
                       val vael =
                         map (fn (v, args, e) =>
                              let 

                                (* translate any self- or friend-call *)
                                fun rval va = pointwisev I rval rexp va
                                and rexp exp =
                                  case cexp exp of
                                    Call (f, args) =>
                                      (case cval f of
                                         Var vv => if List.exists (fn (v, _, _) => V.eq (vv, v)) vael
                                                   (* XXX here env should pull (e.g. dictionaries) from the
                                                      arguments, not from the outer scope, right? Or are
                                                      we guaranteed to get the same free variable? maybe so.. *)
                                                   then Call'(f, map rval args @ map #value env)
                                                   else pointwisee I rval rexp exp
                                       | _ => pointwisee I rval rexp exp)
                                  | _ => pointwisee I rval rexp exp

                                val e = rexp e

                                (* Now restore the free variables from their
                                   (possibly wrapped) arguments. We have to do this
                                   after doing the conversion above because when we
                                   bind the variables, they will no longer have the
                                   same names as they did when free in the outer scope. *)
                                val e = foldr (fn ({ binde, var, ... }, e) =>
                                               binde (Var' var) e) e env

                                (* we are closing this lambda over all of its
                                   dynamic free variables, so we should type
                                   check it in an empty dynamic context. This
                                   is required for correctness, because getdict
                                   might return ANY dictionary in scope for a
                                   type variable, and we don't want it to return
                                   a dictionary from an outer scope, creating an
                                   open lambda. *)
                                val G = T.cleardyn G

                                (* all recursive vars *)
                                val G = foldr (fn ((v, a, _), G) =>
                                               let val t = Cont' ` map #2 a
                                               in bindvar G v t here
                                               end) G vael

                                (* this function's arguments *)
                                val G = foldr (fn (( var, typ ), G) =>
                                               bindvar G var typ here)
                                              G args
                                              
                                (*
                                val () = print "\nCTX:\n"
                                val () = Layout.print (CPSTypeCheck.ctol G, print)
                                val () = print "\nBOD:\n"
                                val () = Layout.print (CPSPrint.etol e, print)
                                *)

                                (* Then translate the wrapped body. *)
                                val e = selfe z G e
                              in
                                (v, args, e)
                              end) vael

                       val lams = Fsel'(Lams' vael, n)

                       (* and then all of the calls must be augmented... *)
                       fun rwval va = pointwisev I rwval rwexp va
                       and rwexp exp =
                         case cexp exp of
                            Call (f, args) =>
                              (case cval f of
                                 Var vv => if V.eq (vv, v)
                                           then Call'(f, map rwval args @ map #value env)
                                           else pointwisee I rwval rwexp exp
                               | _ => pointwisee I rwval rwexp exp)
                          | _ => pointwisee I rwval rwexp exp
                       val ebod = rwexp ebod
                       val G = bindvar G v (Cont' (let val (_, args, _) = List.nth (vael, n)
                                                   in map #2 args
                                                   end)) here
                       val ebod = selfe (VS.add(z, v)) G ebod
                     in
                       (*
                       print "directcall lams:\n";
                       Layout.print (CPSPrint.vtol lams, print);
                       print "\n\n";
                       *)

                       print (V.tostring v ^ " is a direct call!\n");
                       Primop' ([v], CPS.BIND, [lams], ebod)
                     end handle NotDirect =>
                       let in
                         print (V.tostring v ^ " escapes\n");
                         ID.case_Primop z c a
                       end
                  end
              | _ => ID.case_Primop z c a)
         | _ => ID.case_Primop z c a)

      | case_Primop z c a = ID.case_Primop z c a


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

         
           val { env, envt, wrape, wrapv } = mkenv (T.setworld G wdest) (fv, fuv)

           val envv = V.namedvar "go_env"

         in
           Go_cc' { w = wdest, 
                    addr = addr,
                    env = env,
                    f = Lam' (V.namedvar ("go_" ^ Nonce.nonce () ^ "_nonrec"),
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

         (*
         val () = print "Closure convert Lams: "
         val () = app (fn (v, _, _) => print (V.tostring v ^ " ")) vael;
         val () = print "\n"
         *)

         val (fv, fuv) = free_vars_lams G value
           
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

           (*
         val fname = 
           case vael of
             [(v, _, _)] => V.tostring v
           | (v, _, _) :: _ => V.tostring v ^ "_and_friends"
           | nil => raise Closure "totally empty Lams bundle??"
             *)

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
                 (*
                 print ("function " ^ StringUtil.delimit "/" (map (V.tostring o #1) vael) ^
                        " successfully closed.\n")
                 *)
                 ()
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
                            (* better to recompute the dictionary,
                               since in the most common case (single fun)
                               we are going to reduce this and we don't
                               want the dictionary variable to be free at
                               all so that we can reduce further. Dictfor
                               will use vde if necessary, however. *)
                            Sham0' ` Dictfor' ` TVar' venvt,
                            (* Sham0' ` UVar' vde, *)
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
  fun convert w e = C.converte VS.empty (T.empty w) e
    handle Match => raise Closure "unimplemented/match"

end
