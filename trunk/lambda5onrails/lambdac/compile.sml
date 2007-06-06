
structure Compile =
struct

  exception TestFail

    val showil = Params.flag false
        (SOME ("-showil",
               "Show internal language AST")) "showil"

    val showcps = Params.flag false
        (SOME ("-showcps", 
               "Show internal CPS after each phase")) "showcps"

    val execcps = Params.flag false
        (SOME ("-execcps",
               "Try interpreting the CPS language at various phases, for debugging")) "execcps"

    val optil = Params.flag false
        (SOME ("-optil", 
               "Optimize the intermediate language")) "optil"

    val optcps = Params.flag true
        (SOME ("-optcps", 
               "Optimize the CPS language")) "optcps"

    val showfinal = Params.flag false
        (SOME ("-showfinal", 
               "Show the final versions of each phase")) "showfinal"

    val writecps = Params.flag true
        (SOME ("-writecps", 
               "Write .cps file")) "writecps"

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
    
    (* (* not portable *)
    val pids = (Word.toString
                (Posix.Process.pidToWord
                 (Posix.ProcEnv.getpid ())))
        *)

    val pids = Time.toString (Time.now())
(*
    fun execredir file (prog, args) =
        let 
            (* avoid /tmp symlink races *)
            val _ = (Posix.FileSys.unlink file) handle _ => ()
            val fd = Posix.FileSys.createf 
                (file, Posix.FileSys.O_RDWR,
                 Posix.FileSys.O.flags
                 [Posix.FileSys.O.excl],
                 Posix.FileSys.S.irwxu)
        in
            Posix.IO.dup2 { old = fd, new = Posix.FileSys.stdout };
            (* clear close-on-exec flag, if set *)
            Posix.IO.setfd ( Posix.FileSys.stdout, 
                             Posix.IO.FD.flags nil );
            Posix.Process.exec (prog, prog :: args)         
        end

    fun system (prog, args) =
        let val file = "/tmp/hemtmp_" ^ pids
        in
        (case Posix.Process.fork () of
             NONE => execredir file (prog, args)
           | SOME pid =>
             (case Posix.Process.waitpid (Posix.Process.W_CHILD(pid), nil) of
                  (_, Posix.Process.W_EXITED) => NONE
                | (_, Posix.Process.W_EXITSTATUS w8) => SOME w8
                | _ => 
                      let in
                          (* XXX print contents of 'file', which
                             contains its stdout. *)
                          raise Compile (prog ^ " exited strangely")
                      end))
        end

    fun systeml nil = NONE
      | systeml ((p,a)::t) =
        (case system (p, a) of
             NONE => systeml t
           | fail => fail)
*)
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

    fun compile fullfile =
        FSUtil.chdir_excursion fullfile
        (fn file =>
        let
            (* if there's no outfile, base it on the input name *)

            val (base, _) = FSUtil.splitext file

            val () = SymbolDB.clear ()

            val il = getil file

            val () = print "\n\n**** ELABORATED: ****\n"
            val () = Layout.print( ILPrint.utol il, print)

            val il = ILUnused.unused il
            val () = print "\n\n**** UNUSED: ****\n"
            val () = Layout.print( ILPrint.utol il, print)

            val cw = CPS.WC Initial.homename

            val c : CPS.cexp = ToCPS.convert il Initial.home
            val () = print "\n\n**** CPS CONVERTED: ****\n"
            val () = Layout.print ( CPSPrint.etol c, print)

            val G = T.empty cw
            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val c : CPS.cexp = CPSOpt.optimize c
            val () = print "\n\n**** CPS OPT1: ****\n"
            val () = Layout.print ( CPSPrint.etol c, print)

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val c : CPS.cexp = CPSDict.translate c
            val () = print "\n\n**** CPS DICT: ****\n"
            val () = Layout.print ( CPSPrint.etol c, print)

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val c : CPS.cexp = Closure.convert cw c
            val () = print "\n\n**** CLOSURE: ****\n"
            val () = Layout.print ( CPSPrint.etol c, print)

            (* from now on, code should be closed. *)
            val G = T.setopts G [T.O_CLOSED]

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val c : CPS.cexp = UnDict.undict cw c
            val () = print "\n\n**** UNDICT: ****\n"
            val () = Layout.print ( CPSPrint.etol c, print)

            val () = T.check G c
            val () = print "\n* Typechecked OK *\n"

            val p : CPS.program = Hoist.hoist cw c
            val () = print "\n\n**** HOIST: ****\n"
            val () = Layout.print ( CPSPrint.ptol p, print)
              
            val () = T.checkprog p
            val () = print "\n* Typechecked OK *\n"

        in
            print "\n";
          (*
          raise Compile "backend unimplemented";
          OS.Process.success
          *)
          p
        end)
    handle Compile s => fail ("\n\nCompilation failed:\n    " ^ s ^ "\n")
         | CPSDict.CPSDict s => fail ("\nCPSDict: " ^ s ^ "\n")
         | CPSTypeCheck.TypeCheck s => fail ("\n\nInternal error: Type checking failed:\n" ^ s ^ "\n")
         | CPSOpt.CPSOpt s => fail ("\n\nInternal error: CPS-Optimization failed:\n" ^ s ^ "\n")
         | Closure.Closure s => fail ("\nClosure conversion: " ^ s ^ "\n")
         | Context.Absent (what, s) => fail ("\n\nInternal error: Unbound " ^ what ^ " identifier '" ^ s ^ "'\n")
         | Done s => fail ("\n\nStopped early due to " ^ s ^ " flag.\n")
         | Elaborate.Elaborate s => fail("\nElaboration: " ^ s ^ "\n")
         | PrimTypes.PrimTypes s => fail("\nPrimTypes: " ^ s ^ "\n")
         | Podata.Podata s => fail("\nprimop data: " ^ s ^ "\n")
         | Hoist.Hoist s => fail ("\nHoist: " ^ s ^ "\n")
         | ILAlpha.Alpha s => fail ("\nIL Alpha: " ^ s ^ "\n")
         | ILUnused.Unused s => fail ("\nIL unused: " ^ s ^ "\n")
         | Nullary.Nullary s => fail ("\nCouldn't do EL nullary prepass:\n" ^ s ^ "\n")
         | ToCPS.ToCPS s => fail ("\nToCPS: " ^ s ^ "\n")
         | UnDict.UnDict s => fail("\nUnDict: " ^ s ^ "\n")
         | Variable.Variable s => fail ("\n\nBUG: Variables: " ^ s ^ "\n")
         | ex => (print ("\n\nUncaught exception: " ^ exnName ex ^ ": " ^
                         exnMessage ex ^ "\n");
                  raise ex)
        
    and fail s =
        let in
            print "\nCompilation failed.\n";
            print s;
            raise TestFail
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