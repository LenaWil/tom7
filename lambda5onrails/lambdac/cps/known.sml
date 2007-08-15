(* Known is an optimization pass that reduces elimination
   forms where the object is a known introduction form.

   As a result this implements direct calls, since it
   reduces the idiom

   let closure = pack ...
   in
      unpack closure as f, env
      in 
      call(f, env, args)
*)

structure CPSKnown :> CPSKNOWN =
struct

  structure V = Variable
  open CPS

  fun I x = x

  exception Known of string

  val total = ref 0
  fun reset () = total := 0
  fun score s n =
    let in
      print (s ^ ".\n");
      total := !total + n
    end

  structure DA : PASSARG where type stuff = VS.set =
  struct
    type stuff = VS.set
    structure ID = IDPass(type stuff = stuff
                          val Pass = Exn.Dict)
    open ID

    (* fun case_ *)

  end
    
(*
  fun optimize e =
    let 
      fun go e =
        let val e = etae e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of optimization.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end
*)
end