(* Simple dead code elimination. This is quite slow because it
   computes free variable sets for every binding. But since we plan to
   improve the performance of the CPS implementation (including free
   variable sets), this will become faster automatically.

   (Or we can rewrite to work like the IL and JS optimization phases.) *)


structure CPSDead =
struct

  structure V = Variable
  open CPS

  fun I x = x

  exception Dead of string

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      print (s ^ ".\n");
      total := !total + n
    end
    
  exception No
  fun etae e = 
    let
      fun don't () = pointwisee I etav etae e
    in
      case cexp e of
        Letsham (v, va, e) =
        if 


    end

  and etav v =
    let fun don't () = pointwisev I etav etae v
    in
      case cval v of
        VTUnpack (tv, dv, xs, obj, v) =>
          (case cval obj of
             (* ignore annotation *)
             TPack (t, _, d, vs) =>
               (* let's do it! *)
               if length vs = length xs 
               then
                 let
                   (* also ignore annotation on vars *)
                   val xv = ListPair.zip (vs, map #1 xs)
                   (* we can only substitute uvars for uvars,
                      so just bind this one *)
                   val v = VLetsham' (dv, d, v)
                   (* substitute values *)
                   val v = foldr (fn ((vv, xx), v) => CPS.subvv vv xx v) v xv
                   (* substitute type *)
                   val v = CPS.subtv t tv v
                 in
                   score "EBETA" 100;
                   etav v
                 end
               else raise EBeta "unpack-pack value length mismatch"
           | _ => don't ())
      | _ => don't ()
    end

  fun optimize e =
    let 
      fun go e =
        let val e = etae e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of ebeta reduction.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end