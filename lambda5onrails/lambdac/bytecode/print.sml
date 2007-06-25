
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
       Record lel => %[$"RECORD", itol ` length lel,
                       % ` map (fn (l, e) => %[$l, etol e]) lel]
     | Project (l, e) => %[$"PROJ", $l, etol e]
     | Primcall (s, el) => %[$"PRIMCALL",
                             $s,
                             itol ` length el,
                             % ` map etol el]
     | Int i => $(IntConst.tostring i)
     | Inj (l, e) => %[$"INJ", $l, etol e]
     | String s => %[$("\"" ^ String.toString s ^ "\"")]
     | Var s => $s
         )

  fun gtol (FunDec v) =
    %[%[$"FUNDEC",
        itol ` Vector.length v],
      L.indent 1 `
      % ` vtol ` Vector.map (fn (sl, st) =>
                             %[%[itol ` length sl,
                                 % ` map $ sl],
                               L.indent 2 ` stol st]) v]
    | gtol Absent = $"ABSENT"

  fun otol f NONE = $"NONE"
    | otol f (SOME x) = %[$"SOME", f x]

  fun ptol { globals, main } =
    %[$"PROGRAM", otol itol main,
      itol ` Vector.length globals,
      % ` vtol ` Vector.map gtol globals]

   
end
