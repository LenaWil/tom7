(* The code in dict.sml establishes an invariant, before closure
   conversion, that associates a dynamic value with each free static
   type variable, so that at any point in the program we can construct
   the dictionary for a type. We also associate a value with every
   static world variable.

   The dictionary is a dynamic representation of a type. It is used as
   an input to the marshal and unmarshal functions. We also put
   dynamic representations inside existential packages; we would not
   be able to marshal e.g. "exists t. t" even given a representation
   of the type "exists t. t" because the hidden type could have many
   different forms dynamically.

   Maintaining this invariant through the hoisting transformation (see
   hoist.sml) would be painful. In this pass we remove the need for
   the invariant by making the uses of dictionaries explicit, so that
   the ability to create dictionaries at any program point is no
   longer required. (This will prevent us from packing existentials
   at arbitrary program points too, but we shouldn't need to do this
   any more.)

   Dictionaries are used as arguments to the primitives marshal and
   unmarshal. Conceptually these have the following types:

     marshal    :  forall a. a dict * a -> bytes
     unmarshal  :  forall a. a dict * bytes -> a option
   

   Communication only happens at the go_cc construct, which requests
   that (remotely) a continuation value be run on an argument value,
   both of which are @ the remote world. In order to make such a
   request, we must marshal the continuation value and the argument
   value to get some bytes.

   On the receiving end, we'll take those bytes, unmarshal them into
   the pair of argument and continuation, and do the application. This
   code always looks like

     entry = 
       lam (b : bytes) .
         leta p @ w' = 
           unmarshal < (exists arg . {arg dict, arg cont, arg}) at w' > 
              ( dictfor ( (exists arg . {arg dict, arg cont, arg}) at w' ),
                b ) in
         unpack _, { _, f, a } the p in
         run f on a

   in other words, the go_cc construct will become go_mar, which takes
   an address and bytes and always invokes the same entry point above.
   The use of unmarshal doesn't need any dictionaries--we always
   unmarshal at the same type. (Existential packages have type
   representations within them, which is where we get the necessary
   dynamic information from.) In fact, the entry lambda above is
   totally closed.

   We always unmarshal at the same type (well, one type for each
   host), and so we always marshal at the same type.

     go_cc (addr : w' addr, f : argt cont, a : argt)

   -->

     p = hold(w') (pack <argt, { dictfor argt, f, a }>
                   as exists arg . { arg dict, arg cont, arg })

     b : bytes = marshal < (exists arg . { arg dict, arg cont, arg }) at w' > 
                    ( dictfor ((exists arg . { arg dict, arg cont, arg }) at w'), p )

     go_mar (addr, b)


   Thus, even though dictionaries are arguments to the marshal
   function, the real purpose of the dictionary passing invariant is
   to create the dictionaries that are stored in existential packages.
   The dictionary argument to the marshal primitive is always the same
   closed existential type and the marshal function gets the
   information it needs recursively from the dictionary stored inside
   the existential package.


   This translation is very simple. We simply need to find occurrences
   of the go_cc construct and apply the rule above. (The insertion of
   the entry point can happen in another phase since it doesn't need
   dictionaries.) We must keep track of the association of type variables
   to dictionaries so that we can generate the dictionary for the new
   'pack' we create above.

   We'll also translate any 'dictfor' so that it only operates on closed
   types. The translation doesn't affect the type of anything.

   At this point we will have created all of the downstream uses of
   the dictionary passing invariant, so we no longer need to maintain
   it explicitly. (This means that, for instance, an optimization pass could
   remove dictionaries that are not used anywhere.)

*)


structure UnDict :> UNDICT =
struct

  structure V = Variable
  structure VS = Variable.Set
  open CPS

  infixr 9 `
  fun a ` b = a b

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  exception UnDict of string

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  (* makes a dictionary for the type ty, without using Dictfor. 

     Primcon(INT, [])          ->      Dict (Primcon(INT, [])
     Cont( int, string )       ->      Dict (Cont (Dict int, Dict string))
     a                         ->      x          (where x is the value uvariable
                                                   holding the dictionary for the
                                                   type variable a)
     Mu a. (a * a)             ->      Dict (Mu (a/x). Dict (Product (x, x)))
                                                  (Dict-level Mu binds a value
                                                   uvariable.)
     etc. *)
  fun makedict_fake G ty = 
    let in
      (* for testing purposes; Dictfor will have the right type but
         our job is to eliminate dictfor! *)
      print "WARNING: calling makedict_fake\n";
      Dictfor' ty
    end

  (* PERF self-check, unnecessary *)
  and makedict G ty =
      let
          val d = makedict' G ty
          val t = T.checkv G d
      in
          if ctyp_eq (Dictionary' ty, t)
          then d
          else 
              let in
                  print "\n\n\nMAKEDICT FAILS\n** target type:";
                  Layout.print (CPSPrint.ttol ` Dictionary' ty, print);
                  print "\n** value result\n:";
                  Layout.print (CPSPrint.vtol d, print);
                  print "\n** type of that\n:";
                  Layout.print (CPSPrint.ttol t, print);

                  raise UnDict "makedict produced an ill-typed dictionary"
              end
      end

  and makewdict G (WC s) = WDict' s
    | makewdict G (W w) =
    let val () = print ("Get dictionary for wvar " ^ V.tostring w ^ "\n")
        val u = T.getwdict G w
    in
      UVar' u
    end

  and makedict' G ty =
    (case ctyp ty of
       TVar a => 
           let 
               val () = print ("Want dictionary for tvar " ^ V.tostring a ^"\n");
               val u = T.getdict G a
               val (w, t) = T.getuvar G u
           in
               print ("I got this uvar: " ^ V.tostring u ^ "\n");
               print "It has type:\n";
               Layout.print (Layout.align[Layout.str (V.tostring w ^ "."), 
                                          CPSPrint.ttol t], print);
               print "\n";
               UVar' u
           end
     | Mu (i, vtl) =>
         let
           (* put types in context, put dicts in context too *)
           val vvtl = map (fn (v, t) => ((v, V.namedvar "mudict"), t)) vtl
           val G = bindtypes G (map #1 vtl)
           val G = foldr (fn (((v, u), _), G) =>
                          bindu0var G u (Dictionary' ` TVar' v)) G vvtl
         in
           Dict' ` Mu(i, ListUtil.mapsecond (makedict G) vvtl)
         end
     | Product stl => Dict' ` Product(ListUtil.mapsecond (makedict G) stl)
     | Sum stl => Dict' ` Sum(ListUtil.mapsecond (IL.arminfo_map (makedict G)) stl)

     | At (t, w) => Dict' ` At (makedict G t, makewdict G w)

     (* XXX just following the form of the others and adding a value dictionary.
        but the dictionary should actually come from an embedded alllam, if any.

        compare allarrow: we fatten the type arg bindings, but if there are to
        be any real dictionaries, they are being passed in the value slots. *)
     | Shamrock (w, t) => 
         let 
           val wd = V.namedvar "shamwdict_XXX"
           val G = bindworld G w
           val G = bindu0var G wd (TWdict' ` W w)
         in Dict' ` Shamrock ((w, wd), makedict G t)
         end

     | Primcon (pc, tl) => 
         let 
             val () = print "primcon\n"
             val r =              Dict' ` Primcon (pc, map (makedict G) tl)
         in
             print "The primcon result:\n";
             Layout.print (CPSPrint.vtol r, print);
             print "\nprimcon out\n";
             r
         end
     | Cont tl => Dict' ` Cont ` map (makedict G) tl
     | Conts tll => Dict' ` Conts ` map (map (makedict G)) tll
     | Addr w => Dict' ` Addr ` makewdict G w
     | TExists (v, tl) =>
         let
           val G = bindtype G v false
           val ud = V.namedvar "exdict"
           val G = bindu0var G ud (Dictionary' ` TVar' v)
         in
           Dict' ` TExists((v,ud), map (makedict G) tl)
         end
     | AllArrow { worlds : var list, tys : var list, vals : ctyp list, body : ctyp } =>
         let
           val wvys = map (fn v => (v, V.namedvar "aawdict")) worlds
           val tvys = map (fn v => (v, V.namedvar "aadict")) tys

           (* Static components *)
           val G = bindworlds G worlds
           val G = bindtypes G tys

           (* Dynamic components *)
           val G = foldr (fn ((v, u), G) => bindu0var G u (TWdict' ` W v)) G wvys
           val G = foldr (fn ((v, u), G) => bindu0var G u (Dictionary' ` TVar' v)) G tvys
         in
           Dict' ` AllArrow { worlds = wvys,
                              tys = tvys,
                              vals = map (makedict G) vals,
                              body = makedict G body }
         end
     | TWdict w => Dict' ` TWdict (makewdict G w)
     | _ => 
         let in
           print "UNDICT: unimplemented typ:\n";
           Layout.print (CPSPrint.ttol ty, print);
           raise UnDict "makedict constructor unimplemented"
         end)


  structure DA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = stuff
                          val Pass = UnDict)
    open ID

    (* we don't touch types at all. *)

    fun case_Go _ _ (w, addr, body) = 
      raise UnDict "UnDict expects closure-converted code, but saw Go"


     (*
         go_cc (addr : w' addr, f : argt cont, a : argt)

       -->

         EXTY = exists arg . { arg cont, arg }
         MARTY = EXTY at w'

         p = hold(w') (pack <argt, dictfor argt, { f, a }>
                       as EXTY)

         b : bytes = marshal < MARTY > ( dictfor MARTY, p )

         go_mar (addr, b)
     *)
    fun case_Go_cc z ({selfe, selfv, selft}, G)  { w, addr, env, f } =
      let
        val (addr, at) = selfv z G addr
        val w' = case ctyp at of
                   Addr w' => if world_eq (w, w')
                              then w' 
                              else raise UnDict "go_cc world/addr mismatch"
                 | _ => raise UnDict "go_cc to non addr"
        val (f, ft) = selfv z G f
        val (env, envt) = selfv z G env
        val av = V.namedvar "arg"
        val exty  = TExists' (av, [Cont' [TVar' av], TVar' av])
        val marty = At' (exty, w')

        val p = V.namedvar "p"
        val b = V.namedvar "b"
      in
        Bind' (p, Hold' (w', TPack' ( envt, exty, Sham0' ` makedict G envt, [f, env] )),
               Marshal'(b, makedict G marty, Var' p,
                        Go_mar' { w = w,
                                  addr = addr,
                                  bytes = Var' b }))
      end

    fun case_Lams z (s, G) vael =
      let
        (* clear the dynamic portion of the context. By invariant, all Lambdas
           are closed at this point, so this is safe. The idea is to ensure that
           we don't accidentally use some old dictionary for a type variable
           when we call getdict, since this would make the Lambda not closed. *)
        val G = T.cleardyn G
      in
        ID.case_Lams z (s, G) vael
      end

    fun case_AllLam z (s, G) (e as { worlds, tys, vals = vals as (_ :: _), body }) =
      (* as with Lams *)
      ID.case_AllLam z (s, T.cleardyn G) e
      (* not necessarily closed if it had no val args *)
      | case_AllLam z (s, G) e = ID.case_AllLam z (s, G) e

    (* all the action is here. We need to expand it so that we do not use
       the Dictfor construct any more. *)
    fun case_Dictfor z ({selfe, selfv, selft}, G) t = 
      let in
        print "makedict for:\n";
        Layout.print(Layout.indent 4 ` CPSPrint.ttol t, print);
        print "\n";
        (makedict G t, Dictionary' t)
      end

  end


  structure D = PassFn(DA)
  fun undict w e = D.converte () (T.empty w) e
    handle Match => raise UnDict "unimplemented/match"

end
