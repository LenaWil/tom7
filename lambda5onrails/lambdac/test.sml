structure Test =
struct

  infixr 9 `
  fun a ` b = a b

  open CPS
  structure V = Variable
  structure T = CPSTypeCheck

  val cw = CPS.WC Initial.homename
  val G = T.empty cw

  val f = V.namedvar "f"
  val ft = V.namedvar "ft"
  val fds = V.namedvar "fds"
  val fd = V.namedvar "fd"
  val ret = V.namedvar "ret"

  val g = V.namedvar "g"
  val gt = V.namedvar "gt"
  val gds = V.namedvar "gds"
  val gd = V.namedvar "gd"
  val x = V.namedvar "x"
(*
  val c =
      Bind'(f, AllLam' { worlds = nil, tys = [ft], vals = [(fds, Shamrock' ` Dictionary' ` TVar' ` ft)],
                         body = VLetsham' (fd, Var' fds,
                                           Lam' (V.namedvar "_",
                                                 [(* (V.namedvar "_", TVar' ft) *) (* ,
                                                  (V.namedvar "_", Cont' [Product' nil]) *)],
                                                 Halt')) },
            Bind'(g, AllLam' { worlds = nil, tys = [gt], 
                               vals = [(gds, Shamrock' ` Dictionary' ` TVar' ` gt)],
                               body =
                               VLetsham' (gd, Var' gds,
                                          Lam' (V.namedvar "_",
                                                [(x, TVar' gt)],
                                                Call'(AllApp' { f = Var' f,
                                                                worlds = nil,
                                                                tys = [TVar' gt],
                                                                vals = [Sham0' ` Dictfor' ` TVar' gt] },
                                                      [(* Var' x *)]))) },
                  Halt' ))
*)

  val c =
      Bind'(g, AllLam' { worlds = nil, tys = [gt], 
                         vals = [(gds, Shamrock' ` Dictionary' ` TVar' ` gt)],
                         body =
                         VLetsham' (gd, Var' gds,
                                    Lam' (V.namedvar "_",
                                          [(x, TVar' gt)],
                                          Bind' (f, Dictfor' ` TVar' gt,
                                                 Halt'))) },
            Halt' )

(*
extern val Match_421 : exn @ VALID = Match
f_2627 =
   alllam t: poly_3059; v: (poly_3057_d_2 : {} (poly_3059 dictionary)) .
     vletsham poly_3057_d_3 =
        poly_3057_d_2
     in
        lam _ (_ : poly_3059, _ : (unit) cont) = HALT.
g_945 =
   alllam t: poly_3060; v: (poly_3058_d_2 : {} (poly_3060 dictionary)) .
     vletsham poly_3058_d_3 =
        poly_3058_d_2
     in
        lam _ (_ : unit, ret_1599 : ((poly_3060, (unit) cont) cont) cont) =
          call ret_1599 (f_2627 <t: poly_3060; v: sham _ . dictfor poly_3060>)
HALT.
*)
           fun fail s = (print s; raise Match)
   val res =
       let

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

            val (res1, res2) = CPS.freevarse c
       in 
           (V.Set.listItems res1,
            V.Set.listItems res2)
                    
       end     handle  CPSDict.CPSDict s => fail ("\nCPSDict: " ^ s ^ "\n")
         | CPSTypeCheck.TypeCheck s => fail ("\n\nInternal error: Type checking failed:\n" ^ s ^ "\n")
         | CPSOpt.CPSOpt s => fail ("\n\nInternal error: CPS-Optimization failed:\n" ^ s ^ "\n")
         | Closure.Closure s => fail ("\nClosure conversion: " ^ s ^ "\n")
         | Context.Absent (what, s) => fail ("\n\nInternal error: Unbound " ^ what ^ " identifier '" ^ s ^ "'\n")
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


end
