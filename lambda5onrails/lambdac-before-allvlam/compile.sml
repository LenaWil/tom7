
structure Compile :> COMPILE =
struct

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
        | _ => raise Compile "Parse error: program must be single expression"
      end handle Parse.Parse s => raise Compile ("Parse error: " ^ s)

    fun getil file =
        let
          val () = vprint "Parsing...\n"
          val e = getel file

          (* wrap with standard declarations *)
          val el = Initial.wrap e
            
          (* rewrite nullary constructors and types *)
          val el = (Nullary.nullary el)
            
          val () = vprint "Elaborating...\n"
          val (il, t) = 
            (Elaborate.elab Initial.initial el)
            handle Pattern.Pattern s =>
              raise Compile ("pattern: " ^ s)
        in
          il
        end

    fun compile fullfile out =
        FSUtil.chdir_excursion fullfile
        (fn file =>
        let
            (* if there's no outfile, base it on the input name *)

            val (base, _) = FSUtil.splitext file

            val _ = SymbolDB.clear ()

            val inter = getil file

            val opted = 
                if (!optil)
                then
                    let val _ = 
                        if (!showil)
                        then 
                            let in
                                print "il expression:\n";
                                Layout.print (ILPrint.etol inter, print);
                                print "\n\n"
                            end
                        else ()
                    in
                        vprint "Optimizing IL...\n";
                        raise Compile "IL optimizer disabled!"
                        (* XXX5 *)
                        (* ILOpt.optimize inter *)
                    end
                else inter

            val _ = 
                if (!showil) orelse (!showfinal)
                then 
                    let in
                        print "after optimization:\n";
                        Layout.print (ILPrint.etol opted, print);
                        print "\n\n"
                    end
                else ()

            val () = vprint "CPS converting...\n"
            val c = ToCPS.convert 
              (fn v => CPS.Primop(Primop.PHalt, [], nil, nil))
              opted

            val _ =
                if (!showcps)
                then
                    let in
                        print "After CPS conversion:\n";
                        CPSPrint.printe c;
                        print "\n"
                    end
                else ()


            val () = 
              if !execcps
              then 
                let in
                  print "\nExecuting first CPS:\n";
                  CPSExec.exec c
                end
              else ()

            val () = vprint "Optimizing CPS...\n"
            val c = if !optcps
                    then CPSOpt.optimize c
                    else c 
                
            val _ =
              if !showcps andalso !optcps
              then 
                let in
                  print "\nCPS after optimization:\n";
                  CPSPrint.printe c;
                  print "\n\n"
                end
              else ()

            val () = 
              if !execcps
              then 
                let in
                  print "\nExecuting CPS after optimization:\n";
                  CPSExec.exec c
                end
              else ()

            val _ =
              if !writecps
              then CPSPrint.writee (base ^ ".cps") c
              else ()

            val () = vprint "Closure converting...\n"
            val closed = Closure.convert c

            val _ =
              if (!showcps)
              then
                let in
                  print "CPS after closure conversion:\n";
                  CPSPrint.printe closed;
                  print "\n\n"
                end
              else ()

            val () = vprint "Alloc converting...\n"
            val alloced = CPSAlloc.convert closed
              
            val _ =
              if (!showfinal) orelse (!showcps)
              then
                let in
                  print "CPS after alloc conversion:\n";
                  CPSPrint.printe alloced;
                  print "\n\n"
                end
              else ()

            val out =
                (case out of
                     "" => base ^ ".XXX"
                   | s => s)

        in
          raise Compile "backend unimplemented";
          OS.Process.success
        end)
    handle Compile s => fail ("\n\nCompilation failed:\n    " ^ s ^ "\n")
         | Nullary.Nullary s => fail ("\nCouldn't do EL nullary prepass:\n" ^ s ^ "\n")
         | Context.Absent s => fail ("\n\nInternal error: Unbound identifier '" ^
                                      s ^ "'\n")
         | ILAlpha.Alpha s => fail ("\nIL Alpha: " ^ s ^ "\n")
         | CPSAlpha.Alpha s => fail ("\nCPS Alpha: " ^ s ^ "\n")
(*         | ILOpt.ILOpt s => fail ("\nIL Optimizer: " ^ s ^ "\n") *)
         | ILDict.ILDict s => fail ("\nIL Dict: " ^ s ^ "\n")
         | ToCPS.CPS s => fail ("\nCPS Conversion: " ^ s ^ "\n")
         | CPSOpt.CPSOpt s => fail ("\nCPS Optimizer: " ^ s ^ "\n")
         | Done s => fail ("\n\nStopped early due to " ^ s ^ " flag.\n")
         | Variable.Variable s => fail ("\n\nBUG: Variables: " ^ s ^ "\n")
         | ex => fail ("\n\nUncaught exception: " ^ exnName ex ^ ": " ^
                        exnMessage ex ^ "\n")

    and fail s =
        let in
            print "\nCompilation failed.\n";
            print s;
            OS.Process.failure
        end

    (* For testing from the SML/NJ prompt *)

    fun tokenize s = 
        (map #1 
         (Stream.tolist
          (Parsing.transform Tokenize.token 
           (Pos.markstream 
            (StreamUtil.stostream s)))))

end
