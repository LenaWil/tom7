(* The code in dict.sml establishes an invariant, before closure
   conversion, that associates a dynamic value with each free static
   type variable, so that at any point in the program we can construct
   the dictionary for a type.

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


   Even though dictionaries are arguments to the marshal function, the
   real purpose of the dictionary passing invariant is to create the
   dictionaries that are stored in existential packages. The
   dictionary argument to the marshal primitive is always the same
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
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  exception UnDict of string

  val bindworlds = foldl (fn (v, c) => bindworld c v)
  (* assuming not mobile *)
  val bindtypes  = foldl (fn (v, c) => bindtype c v false)

  (* no need to touch types *)
  fun ct t = t

  fun ce G exp : cexp = 
    (case cexp exp of
       Call (f, args) =>
         let
           val (f, _) = cv G f
           val (args, _) = ListPair.unzip ` map (cv G) args
         in
           Call' (f, args)
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
           | _ => raise UnDict "leta on non-at"
         end

     | Letsham (v, va, e) =>
         let val (va, t) = cv G va
         in
           case ctyp t of
             Shamrock t => 
               Letsham' (v, va, ce (binduvar G v t) e)
           | _ => raise UnDict "letsham on non-shamrock"
         end

     | Put (v, t, va, e) => 
         let
           val t = ct t
           val (va, _) = cv G va
           val G = binduvar G v t
         in
           Put' (v, t, va, ce G e)
         end

     | Go (w, addr, body) => raise UnDict "UnDict expects closure-converted code, but saw Go"

     | Go_cc { w, addr, env, f } => 

     (*
         go_cc (addr : w' addr, f : argt cont, a : argt)

       -->

         EXTY = exists arg . { arg dict, arg cont, arg }
         MARTY = EXTY at w'

         p = hold(w') (pack <argt, { dictfor argt, f, a }>
                       as EXTY)

         b : bytes = marshal < MARTY > ( dictfor MARTY, p )

         go_mar (addr, b)
     *)
         let
           val (addr, at) = cv G addr
           (* PERF unnecessary extra typechecking *)
           val w' = case ctyp at of
                      Addr w' => if world_eq (w, w')
                                 then w' 
                                 else raise UnDict "go_cc world/addr mismatch"
                    | _ => raise UnDict "go_cc to non addr"
           val (f, ft) = cv G f
           val (env, envt) = cv G env
           val av = V.namedvar "arg"
           val exty  = TExists' (av, [Dictionary' ` TVar' av, Cont' [TVar' av], TVar' av])
           val marty = At' (exty, w')

           val p = V.namedvar "p"
           val b = V.namedvar "b"
         in
           Bind' (p, Hold' (w', TPack' ( envt, exty, [makedict G envt, f, env] )),
                  Marshal'(b, makedict G marty, Var' p,
                           Go_mar' { w = w,
                                     addr = addr,
                                     bytes = Var' b }))
         end

     | _ =>
         let in
           print "UNDICT: unimplemented exp:\n";
           Layout.print (CPSPrint.etol exp, print);
           raise UnDict "unimplemented EXP"
         end
         )

  (* makes a dictionary for the type ty, without using Dictfor. *)
  and makedict G ty = Dictfor' ty (* XXX *)

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
                                NONE => raise UnDict ("proj label " ^ l ^ " not in type")
                              | SOME t => (Proj' (l, va), t))
            | _ => raise UnDict "proj on non-product"
         end

     | Lams vael => 
         let
           (* check types ok *)
           val vael = map (fn (f, args, e) => (f, ListUtil.mapsecond ct args, e)) vael

           (* recursive vars *)
           val G = foldl (fn ((v, args, _), G) =>
                          bindvar G v (Cont' ` map #2 args) ` worldfrom G) G vael
           val vael = 
               map (fn (f, args, e) =>
                    let val G = foldr (fn ((v, t), G) => bindvar G v t ` worldfrom G) G args
                    in
                      (f, args, ce G e)
                    end) vael

         in
           (Lams' vael, 
            Conts' ` map (fn (_, args, _) => map #2 args) vael)
         end

     | Fsel ( va, i ) =>
        let val (va, t) = cv G va
        in
          case ctyp t of
            Conts tll => (Fsel' (va, i), Cont' ` List.nth (tll, i))
          | _ => raise UnDict "fsel on non-conts"
        end

     | AllLam { worlds, tys, vals, body } => 
            raise UnDict "unimplemented: alllam"

     | AllApp { f, worlds, tys, vals } =>
            raise UnDict "unimplemented: allapp"

     (* Here we need to expand the dictionary, so that it does not use the Dictfor
        construct at all. *)
     | Dictfor t => (makedict G t, Dictionary' t)

     | _ => 
         let in
           print "CLOSURE: unimplemented val\n";
           Layout.print (CPSPrint.vtol value, print);
           raise UnDict "unimplemented VAL"
         end

         )

  fun undict w e =
    ce (T.empty w) e
    handle Match => raise UnDict "unimplemented/match"

end
