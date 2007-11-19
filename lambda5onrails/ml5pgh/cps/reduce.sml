(* After inlining, it is imperative that we carry out in-place
   reductions of applications if we want the functions to actually be
   inlined. 

   This code simply reduces

      AllApp (AllLam, args) 

   and

      Call (FSel(Lams), args)

   as the dynamic semantics would.

   For lambdas this is always conservative (because we use varaible
   bindings for values, so the term does not grow). For allapp we
   might duplicate types, values, and worlds that appear multiple
   times, since we use substitution to carry out the reduction of
   AllApp. For example

   (/\ a. (x <a, a, a, a, a>))<int * int>

   produces five copies of int * int, and if x is another such
   term...
*)


structure CPSReduce :> CPSREDUCE =
struct

  structure V = Variable
  structure VM = V.Map
  open CPS

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  exception Reduce of string

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
   
  structure IA : PASSARG where type stuff = unit =
  struct
    type stuff = unit
    structure ID = IDPass(type stuff = unit
                          val Pass = Reduce)
    open ID

    fun case_AllApp z (s as ({selfe, selfv, selft}, G))  (a as { f, worlds, tys, vals }) =
      case cval f of
        AllLam { worlds = lworlds, tys = ltys, vals = lvals, body } =>
          let
            (* need to substitute from right to left (vals, tys, worlds), since
               these are dependent. *)
            val body = ListPair.foldr (fn (va, (v, t), body) => 
                                       subvv va v body) body (vals, lvals)
            val body = ListPair.foldr (fn (ty, v, body) =>
                                       subtv ty v body) body (tys, ltys)
            val body = ListPair.foldr (fn (w, v, body) =>
                                       subwv w v body) body (worlds, lworlds)

          in
            score "ALLAPP" 100;
            selfv z G body
          end
      | _ => ID.case_AllApp z s a

    fun case_Proj z (s as ({selfe, selfv, selft}, G)) (a as (lab, va)) =
      case cval va of
        Record lvl =>
          (case ListUtil.Alist.find op= lvl lab of
             NONE => raise Reduce "bad constant proj"
           | SOME va' =>
               let in
                 score "PROJ" 100;
                 selfv z G va'
               end)
      | _ => ID.case_Proj z s a

    fun case_Call z (s as ({selfe, selfv, selft}, G))  (a as (f, actualargs)) =
      case cval f of
        Fsel (f, n) =>
          (case cval f of
             Lams l =>
               let
                 val (vrec, args, body) = List.nth (l, n) handle _ => raise Reduce "fsel out of bounds"
               in
                 (* refuse if THIS body calls ANY other recursive var in the bundle *)
                 if (* isvfreeine vrec body  (WRONG) *)
                    List.exists (fn (v, _, _) => isvfreeine v body) l
                 then ID.case_Call z s a
                 else
                   let
                     val body = ListPair.foldr (fn (arg, (v, t), body) =>
                                                subve arg v body) body (actualargs, args)
                   in
                     score ("CALL " ^ V.tostring vrec) 100;
                     selfe z G body
                   end
               end
           | _ => ID.case_Call z s a)
      | _ => ID.case_Call z s a

  end
    
  structure K = PassFn(IA)

  fun reduce G e = K.converte () G e

  fun optimize G e =
    let 
      fun go e =
        let val e = reduce G e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of REDUCE optimization.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end