(* Writes generated code to files. *)
structure Write :> WRITE =
struct

  exception Write of string

  open Codegen

  fun write base code =
    let
      fun one (world, CodeJS { prog }) =
        let
          val n = base ^ "_" ^ world ^ ".js"
          val f = TextIO.openOut n
          fun p s = TextIO.output(f, s)
        in
          p  "/* Generated code - do not edit! */\n\n";
          p ("\n\n/* Created by LAMBDAC version " ^ Version.version ^ " */\n\n");
          Layout.print (Javascript.Program.layout prog, p);
          TextIO.closeOut f;
          print ("Wrote " ^ n ^ "\n")
        end
        | one (world, CodeB _) = raise Write "unimplemented: writing bytecode"
    in
      app one code
    end

end