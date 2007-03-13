
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
        (VS.intersection (us1, us2), VS.intersection (s1, s2))
      end
    fun freevarse exp = 
      let val (us1, s1) = allvarse exp
          val (us2, s2) = allvarse exp
      in
        (VS.intersection (us1, us2), VS.intersection (s1, s2))
      end

  end

(*
  fun fvtest () = 
    let 
      val f = V.namedvar "free"
      val (u, s) = freevarsv (Lam' (V.namedvar "f", [v], Call'(Var' f, [Var' v])))
    in
      print "\n\nfree uvars:\n";
      VS.app (fn v => print (V.tostring v ^ "\n")) u;
      print "free vars:\n";
      VS.app (fn v => print (V.tostring v ^ "\n")) s;
    end
*)

  fun ct typ =
    (case ctyp typ of
       Cont tl => raise Closure "unimplemented"
    | Conts tll => raise Closure "unimplemented"
    (* don't cc these; they are purely static *)
    | AllArrow { worlds, tys, vals = nil, body } => AllArrow' { worlds=worlds, tys=tys, vals=nil,
                                                                body = ct body }
    | AllArrow { worlds, tys, vals, body } => raise Closure "unimplemented"
    | TExists _ => raise Closure "wasn't expecting to see Exists before cc"
         
    (* cc doesn't touch any other types... *)
    | _ => pointwiset ct typ)

  (* we need to look at the intro and elim forms for
                intro        elim
     cont       (lams/fsel)  call
     conts      lams         fsel
     allarrow   alllam      allapp
     *)
     

  fun ce exp = 
    (case cexp exp of
       Call (f, args) => raise Closure "unimplemented"
         
     | _ => pointwisee ct cv ce exp)

  and cv value =
    (case cval value of
       Lams vael => raise Closure "unimplemented:lams"
     | Fsel (v, i) => raise Closure "unimplemented:fsel"

     (* must have at least one value argument or it's purely static and
        therefore not closure converted *)
     | AllLam { worlds, tys, vals = vals as _ :: _, body } => raise Closure "unimplemented:alllam"

     (* ditto on the elim *)
     | AllApp { f, worlds, tys, vals = vals as _ :: _ } => raise Closure "unimplemented:allapp"

     | _ => pointwisev ct cv ce value)


  val convert = ce
    
end
