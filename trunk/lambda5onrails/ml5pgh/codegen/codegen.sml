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

  open JSSyntax

  structure SM = StringMap
  
  datatype code =
    CodeJS of { prog : Javascript.Program.t }
  | CodeB  of { prog : Bytecode.program }

  fun generate ({ worlds, globals, main } : CPS.program) =
    let
      val labels = map #1 globals

      (* map and its inverse *)
      val labels = Vector.fromList labels
      val labelmap = Vector.foldli (fn (i, l, m) => SM.insert(m, l, i)) SM.empty labels
      val gctx = { labels = labels, labelmap = labelmap }

      val maini = case SM.find (labelmap, main) of
                     NONE => raise Codegen "impossible: can't find main!"
                   | SOME i => i

      (* globals is now in "sorted" order since we derived the label map from
         whatever order it was already in. *)

      fun oneworld (worldname, worldkind) =
        let
          open Javascript
          open Joint
          val % = Vector.fromList
          val $ = Id.fromString
          val pn = PropertyName.fromString

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
               let

                 val maybejs = Vector.map (JSCodegen.generate gctx) maybecodes
                 val labeldata = Array ` Vector.map SOME maybejs
                 val arraydec = Var ` Vector.fromList [(JSCodegen.codeglobal,
                                                        SOME labeldata)]

                 (* XXX this stuff should probably be in js/codegen *)
                 val maybecallmain =
                   if Vector.exists (fn (l, _) => l = main) maybecodes
                   then 
                     (* enqueue main in thread queue *)
                     Exp `
                     Call { func = Id ` JSCodegen.enqthread,
                            args = %[Number ` Number.fromInt 0,
                                     Number ` Number.fromInt 0,
                                     (* no args for start *)
                                     Array ` %[]] }

                     (* call directly
                     Var ` Vector.fromList
                     [($"go", SOME `
                       Call { func = 
                              Subscripti ((* the main bundle *)
                                          Subscripti (Id JSCodegen.codeglobal, maini),
                                          (* it is a unary array *)
                                          0),
                              args = Vector.fromList nil })]
                     *)
                   else Empty

                 (* call the scheduler *)
                     (* included in the above
                 val startruntime = 
                   Exp ` 
                   Call { func = Id ` $"setTimeout", 
                          args = %[Id ` $"lc_schedule", (* XXX get from js *)
                                   (* initial timeout at 10ms (?) *)
                                   Number ` Number.fromInt 10] }
                   *)

                 val prog = Program.T ` Vector.fromList [arraydec,
                                                         maybecallmain (* ,
                                                         startruntime *)]
                   
                 (* simple cleanup stuff... *)
                 val prog = JSOpt.optimize prog
               in
                 (* we also need the runtime, but it is just prepended as
                    text by SERVER5. *)
                 CodeJS { prog = prog }
               end
           | CPS.KBytecode =>
               let
                 val globals = Vector.map (ByteCodegen.generate gctx worldname) maybecodes
               in
                 (* XXX support main for bytecode? *)
                 CodeB { prog = { globals = globals, main = NONE } }
               end
               
               )
        end

      val data = map oneworld worlds
    in
      data
    end
    

end
