
structure BytePrint =
struct

  infixr 9 `
  fun a ` b = a b

  structure L = Layout
  structure V = Variable

  val $ = L.str
  val % = L.mayAlign
  val itos = Int.toString

  open Bytecode

  val itol = $ o itos
  fun vtol v = Vector.foldr op:: nil v

  fun otol f NONE = $"NONE"
    | otol f (SOME x) = %[$"SOME", f x]

  (* starts with keyword: *)
  fun stol stmt =
    (case stmt of
       Bind (v, e, s) => %[%[$"BIND", $v, etol e], stol s]
     | End => $"END"
     | Jump (e1, e2, expl) => %[$"JUMP", etol e1, etol e2, itol ` length expl, % ` map etol expl]
     | Case { obj, var, arms, def } => %[$"CASE", etol obj, $var, itol ` length arms,
                                         % ` map (fn (s, st) =>
                                                  %[$s, stol st]) arms,
                                         stol def]
     | Go (e1, e2) => %[$"GO", etol e1, etol e2]
     | Error s => %[$"ERROR", $("\"" ^ String.toString s ^ "\"")]
         )
       
  and etol exp =
    (case exp of
       Record lel => %[%[$"RECORD", itol ` length lel],
                       L.indent 2 ` % ` map (fn (l, e) => %[$l, etol e]) lel]
     | Project (l, e) => %[$"PROJ", $l, etol e]
     | Primcall (s, el) => %[$"PRIMCALL",
                             $s,
                             itol ` length el,
                             % ` map etol el]
     | Int i => $(IntConst.tostring i)
     | Inj (l, e) => %[$"INJ", $l, otol etol e]
     | String s => %[$("\"" ^ String.toString s ^ "\"")]
     | Var s => $s
     | Marshal (e1, e2) => %[$"MARSHAL", etol e1, etol e2]

     | Dp pd => %[$"DP", pdtol pd]
     | Drec sel => %[%[$"DREC", itol ` length sel],
                     L.indent 2 ` % ` map (fn (l, e) => %[$l, etol e]) sel]
     | Dsum seol => %[%[$"DSUM", itol ` length seol],
                      L.indent 2 ` % ` map (fn (l, eo) => %[$l, otol etol eo]) seol]
     | Dlookup s => %[$"DLOOKUP", $s]
     | Dexists { d, a } => %[$"DEXISTS", $d, itol ` length a,
                             L.indent 2 ` % ` map etol a]
     | Dall (sl, e) => %[$"DALL", %[itol ` length sl, L.indent 2 ` % ` map $ sl],
                         L.indent 2 ` etol e]
         )

  and pdtol dic =
    (case dic of
       Dcont => $"DCONT"
     | Dconts => $"DCONTS"
     | Daddr => $"DADDR"
     | Daa => $"DAA"
     | Ddict => $"DDICT"
     | Dint => $"DINT"
     | Dstring => $"DSTRING"
     | Dvoid => $"DVOID")


  fun gtol (FunDec v) =
    %[%[$"FUNDEC",
        itol ` Vector.length v],
      L.indent 1 `
      % ` vtol ` Vector.map (fn (sl, st) =>
                             %[%[itol ` length sl,
                                 % ` map $ sl],
                               L.indent 2 ` stol st]) v]
    | gtol Absent = $"ABSENT"

  fun ptol { globals, main } =
    %[$"PROGRAM", otol itol main,
      itol ` Vector.length globals,
      % ` vtol ` Vector.map gtol globals]

   
end
