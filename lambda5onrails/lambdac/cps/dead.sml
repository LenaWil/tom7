(* Simple dead code elimination. This is quite slow because it
   computes free variable sets for every binding. But since we plan to
   improve the performance of the CPS implementation (including free
   variable sets), this will become faster automatically.

   Right now this only does letsham elimination, since that's needed
   to get direct calls to work.

   (Or we can rewrite to work like the IL and JS optimization phases.) *)


structure CPSDead :> CPSDEAD =
struct

  structure V = Variable
  open CPS

  fun I x = x

  exception Dead of string

  val total = ref 0
  fun reset () = total := 0
  fun score var s n =
    let in
      print (s ^ ": " ^ V.tostring var ^ "\n");
      total := !total + n
    end
    
  exception No
  fun deade e = 
    let
      (* this is a bottom up pass... *)
      val e = pointwisee I deadv deade e
    in
      case cexp e of
        Letsham (u, va, ebod) =>
          if isufreeine u ebod
          then e
          else
            let in
              score u "LETSHAM" 50;
              ebod
            end
      | Primop ([v], CPS.BIND, [va], ebod) => 
          if isvfreeine v ebod
          then e
          else
            let in
              score v "BIND" 50;
              ebod
            end
      (* common after exploding closure *)
      | Leta (v, va, ebod) => 
          if isvfreeine v ebod
          then e
          else
            let in
              score v "LETA" 50;
              ebod
            end

      | Put (v, va, ebod) => 
          if isvfreeine v ebod
          then e
          else
            let in
              score v "PUT" 50;
              ebod
            end

      (* PERF more! *)
      | _ => e
    end

  and deadv v = 
    let
      val v = pointwisev I deadv deade v
    in
      case cval v of
        VLetsham (u, va, vbod) =>
          if isufreeinv u vbod
          then v
          else
            let in
              score u "VLETSHAM" 50;
              vbod
            end
      | _ => v
    end

  fun optimize (_ : CPSTypeCheck.context) e =
    let 
      fun go e =
        let val e = deade e
        in
          if !total > 0
          then (print ("Did " ^ Int.toString (!total) ^ " units of dead code elimination.\n");
                reset ();
                go e)
          else e
        end
    in
      go e
    end

end