
structure ByteOut =
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
       Bind (v, e, s) => %[$"BIND", $v, etol e, stol s]
     | End => $"END"
     | Jump (exp, expl) => %[$"JUMP", etol exp, itol ` length expl, % ` map etol expl]
     | Case { obj, var, arms, def } => %[$"CASE", etol obj, $var, itol ` length arms,
                                         % ` map (fn (s, st) =>
                                                  %[$s, stol st]) arms,
                                         stol def]
         )
       
  and etol exp =
    (case exp of
       Record lel => %[$"RECORD", itol ` length lel,
                       % ` map (fn (l, e) => %[$l, etol e]) lel]
     | Project (l, e) => %[$"PROJ", $l, etol e]
     | Primcall (s, el) => %[$"PRIMCALL",
                             itol ` length el,
                             % ` map etol el]
     | Int i => $(IntConst.tostring i)
     | Var s => $s
         )

  fun gtol (FunDec v) =
    %[$"FUNDEC",
      itol ` Vector.length v,
      % ` vtol ` Vector.map (fn (sl, st) =>
                             %[itol ` length sl,
                               % ` map $ sl,
                               stol st]) v]

  fun ptol { globals, main } =
    %[$"PROGRAM", itol main,
      itol ` Vector.length globals,
      % ` vtol ` Vector.map gtol globals]

   
end
