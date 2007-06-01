(* After closure conversion and undictionarying, all functions are
   closed to dynamic variables and uvariables. This means that we can
   hoist this code out of its nestled environs to the top-level and
   give it a global name. At run-time, we pass around these names
   instead of the code itself.
   
   Though the code is closed to dynamic variables, it may have free
   static (world and type) variables. When we extract the code from
   the scope of these variables, we need to abstract the code over
   those variables and apply it to them back in its original location.

   In fact, the code might be typed @ a free world variable. So the
   hoisted code might be polymorphic in the world at which it is typed,
   that is, valid. (Actually, we really parameterize the typing judgment
   here by the world, so the world parameter can appear in the type of
   the code as well, unlike with traditional valid things.)
   
*)

structure Hoist :> HOIST =
struct

  infixr 9 `
  fun a ` b = a b

  exception Hoist of string
  open CPS
  structure V = Variable

  fun hoist home program =
    let
      val accum = ref nil
      val ctr = ref 0
      (* PERF. we should be able to merge alpha-equivalent labels here,
         which would probably yield substantial $avings. *)
      (* Take code and return a label after inserting it in the global
         code table. *)
      fun insert (arg as (ws, ts, vael)) =
          let
              (* XXX could derive it from a function name in vael? *)
              val l = "L_" ^ Int.toString (!ctr)
          in
              ctr := !ctr + 1;
              accum := arg :: !accum;
              l
          end


      (* types do not change. *)
      fun ct t = t

      (* don't need to touch expressions, except the values within them *)
      fun ce e = pointwisee ct cv ce e

      (* for values, only Lams is relevant

         XXX I think we need to hoist alllam when it has a value argument,
         since it is also closure-converted.
         *)
      and cv v =
        (case cval v of
           Lams vael =>
             let
               val { w, t } = freesvarsv v
               val w = V.Set.foldr op:: nil w
               val t = V.Set.foldr op:: nil t

               val () = print "Hoist FWV: "
               val () = app (fn v => print (V.tostring v ^ " ")) w
               val () = print "\nHoist FTV: "
               val () = app (fn v => print (V.tostring v ^ " ")) t
               val () = print "\n"

               val l = insert (w, t, vael)
                   
             in
               AllApp' { f = Codelab' l, worlds = map W w, tys = map TVar' t, vals = nil }
             end
         | _ => pointwisev ct cv ce v)

      val program' = ce program
    in
      (* FIXME wrap program' with global bindings *)
      raise Hoist "unimplemented"
    end

end
