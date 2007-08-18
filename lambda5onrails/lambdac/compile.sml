
structure Compile :> COMPILE =
struct

    val showil = Params.flag false
        (SOME ("-showil",
               "Show internal language AST")) "showil"

    val showcps = Params.flag false
        (SOME ("-showcps",
               "Show internal CPS after each phase")) "showcps"

    val optil = Params.flag false
        (SOME ("-optil", 
               "Optimize the intermediate language")) "optil"

    val optcps = Params.flag true
        (SOME ("-optcps", 
               "Optimize the CPS language")) "optcps"

    val verbose = Params.flag true
        (SOME ("-v",
               "Show progress")) "verbose"

    structure T = CPSTypeCheck

    exception Compile of string

    fun vprint s =
      if !verbose then print s
      else ()

    (* could also turn off CPSOpt.debug *)
    fun quiet () =
        let 
            val debugopt = Params.flag true NONE "debugopt"
        in
            showil := false;
            debugopt := false
        end
    
    (* XXX should also get some other portable nonce here
       (PIDs are not portable between NJ/mlton, according
       to an old comment here?) *)
    val pids = Time.toString (Time.now())

    exception Done of string

    fun getel file =
      let
        fun tokenize s = 
          Parsing.transform Tokenize.token (Pos.markstreamex file s)
          
        fun parseexpression G s = 
          Parsing.transform (Parse.unit G) (tokenize s)
          
        val parsed = Stream.tolist 
          (parseexpression Initfix.initial 
           (StreamUtil.ftostream file))
      in
        case parsed of
          [e] => e
        | nil => raise Compile "Parse error: no expression"
        | _ => raise Compile "Parse error: program must be single unit"
      end handle Parse.Parse s => raise Compile ("Parse error: " ^ s)

    fun getil file =
        let
          val () = vprint "Parsing...\n"
          val e = getel file

          (* wrap with standard declarations *)
          val el = Initial.wrap e
            
          (* rewrite nullary constructors and types *)
          val el = (Nullary.nullary el)
             handle Match => raise Nullary.Nullary "match"

          val () = vprint "Elaborating...\n"
        in
          (Elaborate.elaborate el)
        end

    fun showcpsphase c =
      if !showcps
      then Layout.print (CPSPrint.etol c, print)
      else ()
    fun showprogphase p =
      if !showcps
      then Layout.print (CPSPrint.ptol p, print)
      else ()

    fun compile fullfile =
        FSUtil.chdir_excursion fullfile
        (fn file =>
        let
            fun cpspass name f (G : CPSTypeCheck.context) (c : CPS.cexp) =
              let
                val () = print ("\n\n**** CPS " ^ name ^ " ****\n")
                val c : CPS.cexp = f G c
                val () = showcpsphase c
                val () = T.check G c
                val () = print "\n* Typechecked OK *\n"
              in
                c
              end

            (* if there's no outfile, base it on the input name *)

            val (base, _) = FSUtil.splitext file

            val () = SymbolDB.clear ()

            val il = getil file

            val () = print "\n\n**** ELABORATED: ****\n"
            val () = Layout.print( ILPrint.utol il, print)

            val () = print "\n\n**** UNUSED: ****\n"
            val il = ILUnused.unused il
            val () = Layout.print( ILPrint.utol il, print)

            val cw = CPS.WC' Initial.homename

            val () = print "\n\n**** CPS CONVERSION... ****\n"
            val c : CPS.cexp = ToCPS.convert il Initial.home
            val () = print "\n\n**** CPS CONVERTED: ****\n"
            val () = showcpsphase c 

            val G = T.empty cw
            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            (* undoes some CPS conversion waste *)
            val () = print "\n\n**** CPS ETA: ****\n"
            val c : CPS.cexp = CPSEta.optimize c
            val () = showcpsphase c

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            (* reduce the amount of code as much as possible... *)
            val c = cpspass "DEAD" CPSDead.optimize G c

            val () = print "\n\n**** CPS DICT: ****\n"
            val c : CPS.cexp = Dict.translate G c
            val () = showcpsphase c

            val G = T.setopts G [T.O_EXTERNDICTS]

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"


            val () = print "\n\n**** CLOSURE: ****\n"
            val c : CPS.cexp = Closure.convert cw c
            val () = showcpsphase c

            (* from now on, code should be closed. *)
            val G = T.setopts G [T.O_CLOSED, T.O_EXTERNDICTS]

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            (* sometimes undoes senseless closure conversions *)
            val () = print "\n\n**** CPS EBETA ****\n";
            val c : CPS.cexp = CPSEBeta.optimize c
            val () = showcpsphase c
            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val () = print "\n\n**** UNDICT: ****\n"
            val c : CPS.cexp = UnDict.undict cw c
            val () = showcpsphase c

            (* make more phases use this, nicer.

               can't run DEAD before undict, because it
               might erase dictionaries that we need, later
               (but we could create a dict-safe version)
               *)
            val c = cpspass "DEAD" CPSDead.optimize G c
            val c = cpspass "KNOWN" CPSKnown.optimize G c
            val c = cpspass "DEAD" CPSDead.optimize G c

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val () = print "\n\n**** HOIST: ****\n"
            val p : CPS.program = Hoist.hoist cw Initial.homekind c
            val () = showprogphase p
              
            val () = T.checkprog p
            val () = print "\n* Typechecked OK *\n"

            (* would be nice to have another optimization phase here... *)
            val code = Codegen.generate p

            val () = Write.write base code

        in
          print "\n";
          (* code *) ()
        end)
    handle 
           Done s => fail ("Stopped early due to " ^ s ^ " flag.")
         | CPSDead.Dead s => fail("CPS Dead code elimination: " ^ s)
         | CPSKnown.Known s => fail("CPS knowledge-based reduction: " ^ s)
         | ByteCodegen.ByteCodegen s => fail("Bytecode codegen: " ^ s)
         | BytePrint.BytePrint s => fail("Bytecode print: " ^ s)
         | CPS.CPS s => fail ("Internal error in CPS:\n" ^ s)
         | CPSEta.Eta s => fail ("Internal error: CPS-Optimization failed:\n" ^ s)
         | CPSTypeCheck.TypeCheck s => fail ("Internal error: Type checking failed:\n" ^ s)
         | Closure.Closure s => fail ("Closure conversion: " ^ s)
         | Codegen.Codegen s => fail ("Code generation: " ^ s)
         | Compile s => fail ("Compilation failed:\n    " ^ s)
         | Context.Absent (what, s) => fail ("Internal error: Unbound " ^ what ^ " identifier '" ^ s ^ "'")
         | Context.Context s => fail ("Context: " ^ s)
         | Dict.Dict s => fail ("CPSDict: " ^ s)
         | Elaborate.Elaborate s => fail("Elaboration: " ^ s)
         | Hoist.Hoist s => fail ("Hoist: " ^ s)
         | ILAlpha.Alpha s => fail ("IL Alpha: " ^ s)
         | ILUnused.Unused s => fail ("IL unused: " ^ s)
         | JSCodegen.JSCodegen s => fail("Javascript codegen: " ^ s)
         | JSOpt.JSOpt s => fail("Javascript optimization: " ^ s)
         | Nullary.Nullary s => fail ("Couldn't do EL nullary prepass:\n" ^ s)
         | Podata.Podata s => fail("primop data: " ^ s)
         | PrimTypes.PrimTypes s => fail("PrimTypes: " ^ s)
         | ToCPS.ToCPS s => fail ("ToCPS: " ^ s)
         | UnDict.UnDict s => fail("UnDict: " ^ s)
         | Variable.Variable s => fail ("BUG: Variables: " ^ s)
         | Write.Write s => fail ("Write: " ^ s)
         | ex => (print ("\nUncaught exception: " ^ exnName ex ^ ": " ^
                         exnMessage ex);
                  raise ex)
        
    and fail s =
        let in
            print "\nCompilation failed.\n";
            print s;
            print "\n";
            raise Compile "failed."
              (* OS.Process.failure *)
        end

    (* For testing from the SML/NJ prompt *)

    fun tokenize s = 
        (map #1 
         (Stream.tolist
          (Parsing.transform Tokenize.token 
           (Pos.markstream 
            (StreamUtil.stostream s)))))

end

(*
val _ =
    case Params.docommandline () of
        [input] => (* OS.Process.exit(Test.compile input) *) Test.fail "unimplemented"
      | _ =>
            let in
                print "Usage: lambdac file.ml5\n\n";
                print (Params.usage ());
                Test.fail "bad usage"
            end
*)