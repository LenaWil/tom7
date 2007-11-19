(* This simplifies primops that are applied to constants.
   Right now, we only reduce jointext, since the elaboration
   of it often allows for a lot of reduction, and it can
   be quite expensive at runtime. 

   PERF: should simplify compares, math, etc.
*)

structure CPSSimplifyPrimop :> CPSSIMPLIFYPRIMOP =
struct

  structure V = Variable
  structure P = Primop
  open CPS CPSUtil

  fun I x = x

  exception SimplifyPrimop of string

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      print (s ^ ", ");
      total := !total + n
    end

  exception No
  fun simplifye e = 
    let fun don't () = pointwisee I simplifyv simplifye e
    in
      (case cexp e of
         Native { var = v, po = P.PJointext _, tys = nil, args, bod } =>
           let
             val args = map simplifyv args
             val args = ListUtil.mapto cval args
             fun reduce nil = nil
               | reduce ((_, String "") :: rest) =
               let in
                 score "jointext-empty" 50;
                 reduce rest
               end
               | reduce ((_, String s1) :: (_, String s2) :: rest) =
               let 
                 val s = s1 ^ s2
               in
                 score "jointext-consts" 50;
                 reduce ((String' s, String s) :: rest)
               end
               | reduce ((h, _) :: rest) = h :: reduce rest

             val args = reduce args
           in
             Native' { var = v, po = P.PJointext (length args), tys = nil, args = args,
                       bod = simplifye bod }
           end
       | _ => don't ())
    end

  and simplifyv v = pointwisev I simplifyv simplifye v

  fun optimize _ e =
    let 
      fun go e =
        let val e = simplifye e
        in
          if !total > 0
          then (print ("\nDid " ^ Int.toString (!total) ^ " units of simplify-primop reduction.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end