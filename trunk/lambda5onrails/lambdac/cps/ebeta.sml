(* Beta reduction of existentials. This corrects for the
   wasteful way that we transform fsel when there is just
   one function in the bundle. *)

structure CPSEBeta :> CPSEBETA =
struct

  structure V = Variable
  open CPS

  fun I x = x

  exception EBeta of string

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      print (s ^ ".\n");
      total := !total + n
    end
    

  (* beta reduce

     vtunpack (pack T, v1..vn, D)
     as t, x1..xn, d
     in v

      -->

     [T/t] [v1/x1]..[vn/xn][D/d] v
     
     (Although note that the dictionary is not necessary, since no
      abstract type variable is bound now! Still, the body might
      use it, so we substitute it through.)

     Also note that since we do substitutions, this is not a
     conservative optimization. However, the only place we insert
     vtunpack is for fsel rejiggering, in which case each var is used
     only once as we repack the closure.

     (we could also do this one, but don't for now. we don't generate it.)
     unpack (pack T, v1..vn, D)
     as t, x1..xn, d
     in E

      -->

     [T/t] (let x1 = v1
                 ..
            let xn = vn
            (* dict not necessary *)
            in E)

       *)
  exception No
  fun betae e = pointwisee I betav betae e
  and betav v =
    let fun don't () = pointwisev I betav betae v
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
                   betav v
                 end
               else raise EBeta "unpack-pack value length mismatch"
           | _ => don't ())
      | _ => don't ()
    end

  fun optimize e =
    let 
      fun go e =
        let val e = betae e
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