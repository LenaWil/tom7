(* Inlining is the process of removing a variable binding by carrying
   out the substitution. In order to prevent a blow-up in the size of
   the program, we should only do this when the bound value is "small"
   (about as costly as a variable occurrence) or when we believe that
   after inlining it the program will reduce to something smaller.

   The external language allows function declaratinos to be marked
   as "inline," which advises this pass to do the inlining. This is
   accomplished by a value constructor Inline that indicates that the
   value within it should be inlined. (We can't always inline it,
   so sometimes this has no meaning.)

   We can also inline whenever a variable is used only once (or
   never). This will turn out to be important, because polymorphic,
   valid functions are converted in a way that is difficult to
   directly inline, until an inner inlining has bee performed. The
   code produced for the identity function ( id ~ 'a -> 'a ), marked
   inline by the programmer, is

   letsham id_2 =
      sham _ .
        /\ cat_4 .
            vletsham id_7 =
               sham _ .
                 INLINE
                 lams
                 #0 is _ (x : cat_4, ret_5 : (cat_4) cont) = call ret_5 (x)
                 .0
            in
               ~id_7

   The inside of the /\ (alllam) is a vletsham, which prevents us from
   noticing that the body is inlinable unless we are exceedingly clever
   (we're not). But that body has the form
      vletsham x = (sham w. val')
      in  ... value with one use of x ...
   which can safely be reduced to
      [ ([world/w]val')/x ]value
   where world is the world of value.

   after that we have

   letsham id_2 =
      sham w.
         /\ cat_4.
            INLINE lams 
              #0 is _ (x : cat_4, ret_5 : (cat_4) cont) = call ret_5 (x)
                 .0
   
   which can be seen to be inlinable, even if id is used many times.

*)

structure CPSInline :> CPSINLINE =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  structure Exn =
  struct
    exception Inline of string
  end

  structure T = CPSTypeCheck
  val bindvar = T.bindvar
  val binduvar = T.binduvar
  val bindu0var = T.bindu0var
  val bindtype = T.bindtype
  val bindworld = T.bindworld
  val worldfrom = T.worldfrom

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      print (s ^ ".\n");
      total := !total + n
    end

  fun small v =
    case cval v of
      Var _ => true
    | UVar _ => true
    | Int _ => true
    | Record nil => true
    | String s => size s < 10
    | Hold (w, v) => small v
    | Sham (w, v) => small v
    (* hmm, this can cause duplication of closures since
       it will be closure converted... *)
    | AllLam { body = v, ... } => small v
    | Fsel (v, _) => small v
    | Lams [(v, a, e)] =>
        (not (isvfreeine v e)
         andalso smallfn e)
    | Inline _ => true
    | Codelab _ => true
    | _ => false

  and smallfn e =
    case cexp e of
      Halt => true
    (* not conservative, and sometimes causes blow-ups
       in practice (see bugs/code-blow-up.ml5). *)
    | Call (f, args) => small f andalso List.all small args
    | _ => false
  (* also cases with small branches? *)

  structure IA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = unit
                          val Pass = Exn.Inline)
    open ID

    fun case_VLetsham (z : stuff) ({selfe, selfv, selft}, G) (u, va, vbod) =
      let 
        val (va, t) = selfv z G va
        val inline =
          (* only if this is an immediate sham. *)
          case cval va of
            Sham (w, vas) =>
              if countuinv u vbod <= 1
              then SOME (w, vas, "once")
              else if small vas
                   then SOME (w, vas, "small")
                   else NONE
          | _ => NONE

      in
        case ctyp t of
          Shamrock (w, tt) =>
            let 
              val G = binduvar G u (w, tt)
              val (vbod, te) = selfv z G vbod
              fun noinline () = (VLetsham' (u, va, vbod), te)
            in
              case inline of
                SOME (ww, vas, why) =>
                  (* PERF we can inline even if w appears,
                     it's just that it's difficult to substitute
                     because we don't know the home world at the
                     occurrence(s) with the sub functions. *)
                  if not (iswfreeinv ww vas)
                  then 
                    let in 
                      score ("INLINE (" ^ why ^ ") " ^ V.tostring u) 100;
                      (subuv vas u vbod, te)
                    end
                  else noinline ()
              | NONE => noinline ()
            end
        | _ => raise Exn.Inline "vletsham on non-shamrock"
      end

    fun case_Primop z (s as ({selfe, selfv, selft}, G)) (a as ([v], CPS.BIND, [va], ebod)) =
      let
        val (va, t) = selfv z G va
        val G = bindvar G v t ` worldfrom G
        val ebod = selfe z G ebod
        val inline =
          if small va
          then SOME "once"
          else if countvine v ebod <= 1
               then SOME "small"
               else NONE

      in
        case inline of
          SOME why =>
            let in
              score ("INLINE bind (" ^ why ^ ") " ^ V.tostring v) 100;
              subve va v ebod
            end
        | NONE => Primop' ([v], CPS.BIND, [va], ebod)
      end
      | case_Primop z s a = ID.case_Primop z s a

    fun case_Letsham (z : stuff) ({selfe, selfv, selft}, G) (u, va, ebod) =
      let 
        val (va, t) = selfv z G va
        val inline =
          (* only if this is an immediate sham. *)
          case cval va of
            Sham (w, vas) =>
              if countuine u ebod <= 1
              then SOME (w, vas, "once")
              else if small vas
                   then SOME (w, vas, "small")
                   else NONE
          | _ => NONE

      in
        case ctyp t of
          Shamrock (w, tt) =>
            let 
              val G = binduvar G u (w, tt)
              val ebod = selfe z G ebod
              fun noinline () = Letsham' (u, va, ebod)
            in
              case inline of
                SOME (ww, vas, why) =>
                  (* PERF we can inline even if w appears,
                     it's just that it's difficult to substitute
                     because we don't know the home world at the
                     occurrence(s) with the sub functions. *)
                  if not (iswfreeinv ww vas)
                  then 
                    let in 
                      score ("INLINE (" ^ why ^ ") " ^ V.tostring u) 100;
                      subue vas u ebod
                    end
                  else noinline ()
              | NONE => noinline ()
            end
        | _ => raise Exn.Inline "vletsham on non-shamrock"
      end


  end
    
  structure K = PassFn(IA)

  fun inline G e = K.converte () G e

  fun optimize G e =
    let 
      fun go e =
        let val e = inline G e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of INLINE optimization.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

  open Exn (* since there is a cps constructor Inline *)
end