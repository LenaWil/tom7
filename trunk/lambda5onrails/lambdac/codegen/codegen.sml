(* Code generation is the process of making the code that's targeted
   to each specific platform (worldkind) from the CPS program, which
   is represented in a uniform language. At this point we also discard
   static type information, since our target languages are un(i)typed.

   The CPS program consists of a series of labels, corresponding to
   all of the bits of code that might be part of the computation.
   These labels are global (each world refers to them by the same
   names) and unique (each code bit has a different label). Some labels
   are polymorphic and we will produce code for that label for each
   world in the program. Some labels can only have code generated for
   one specific world (and only in these code bits will we have to
   make local primitive calls).

   The actual code generation is handled by different modules (one for
   each platform) so all this code does is decide which code needs to
   be converted and invokes the relevant module's code generation.

   For efficiency sake we establish here a dense mapping from labels
   to integers, so that code can use numbers instead of strings to
   refer to them.

   *)

structure Codegen :> CODEGEN =
struct

  infixr 9 `
  fun a ` b = a b
  fun I x = x

  exception Codegen of string

  structure SM = StringMap
  
  datatype code =
    CodeJS of { prog : Javascript.Program.t, main : string option }
  | CodeB  of { prog : Bytecode.program }

  fun generate ({ worlds, globals, main } : CPS.program) =
    let
      val labels = map #1 globals

      (* map and its inverse *)
      val labels = Vector.fromList labels
      val labelmap = Vector.foldli (fn (i, l, m) => SM.insert(m, l, i)) SM.empty labels
      val gctx = { labels = labels, labelmap = labelmap }

      (* globals is now in "sorted" order since we derived the label map from
         whatever order it was already in. *)

      fun oneworld (worldname, worldkind) =
        let
          fun relevant (lab, c) =
            (lab, 
             case CPS.cglo c of
               CPS.PolyCode _ => SOME c
             | CPS.Code (_, _, l) => if l = worldname
                                    then SOME c
                                    else NONE)

          val maybecodes = Vector.fromList ` map relevant globals
        in
          (worldname,
           case worldkind of
             CPS.KJavascript => 
               let val maybejs = Vector.map (JSCodegen.generate gctx) maybecodes
               in
                 CodeJS { prog = Javascript.Program.T maybejs,
                          main = NONE (* XXX *) }
               end
           | CPS.KBytecode => raise Codegen "bytecode codegen unimplemented")
        end

      val data = map oneworld worlds
    in
      data
    end
    

end
