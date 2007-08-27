(* Eta reduction. CPS conversion can introduce lots of eta-expanded
   continuations, so we reduce these. This is a simple syntactic
   substitution. *)

structure CPSEta :> CPSETA =
struct

  structure V = Variable
  open CPS CPSUtil

  fun I x = x

  exception Eta of string

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      (* print (s ^ ".\n"); *)
      total := !total + n
    end
    

  (* eta-reduce:

     lam _ (arg0 ... argn).
       call f(arg0 ... argn)      -->    f

     (note this is actually

     lams (_ (arg0 ... argn).  call val(arg0 ... argn)).0  -->  val

       *)
  exception No
  fun etae e = pointwisee I etav etae e
  and etav v =
    let fun don't () = pointwisev I etav etae v
    in
      case cval v of
         Fsel (lams, 0) =>
           (case cval lams of
              Lams [(vrec, args, e)] =>
                (case cexp e of
                   Call (vf : cval, args') =>
                     (* must be all variables *)
                     (let val args' = map (fn (Var x) => x | _ => raise No) (map cval args')
                      in
                        (* must be same args. *)
                        if ListUtil.all2 V.eq (map #1 args) args'
                        then
                          let in
                            score "ETA" 50;
                            etav vf
                         end
                        else don't ()
                      end handle No => don't ())
                 | _ => don't ())
            | _ => don't ())
       | _ => don't ()
    end

  fun optimize _ e =
    let 
      fun go e =
        let val e = etae e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of eta reduction.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end