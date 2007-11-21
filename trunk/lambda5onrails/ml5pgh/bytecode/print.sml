
structure BytePrint :> BYTEPRINT =
struct

  infixr 9 `
  fun a ` b = a b

  structure L = Layout

  val $ = L.str
  val % = L.mayAlign
  val itos = Int.toString

  open Bytecode
  exception BytePrint of string

  val itol = $ o itos
  fun vtol v = Vector.foldr op:: nil v

  fun otol f NONE = $"NONE"
    | otol f (SOME x) = %[$"SOME", f x]

  fun lab l = $("\"" ^ l ^ "\"")

  (* starts with keyword: *)
  fun stol stmt =
    (case stmt of
       Bind (v, e, s) => %[%[$"BIND", $v, L.indent 2 ` etol e], stol s]
     | End => $"END"
     | Return e => %[$"RETURN", L.indent 2 ` etol e]
     | Jump (e1, e2, expl) => %[$"JUMP", etol e1, etol e2, itol ` length expl, % ` map etol expl]
     | Case { obj, var, arms, def } => %[%[$"CASE", etol obj, $var, itol ` length arms],
                                         % ` map (fn (s, st) =>
                                                  %[lab s, L.indent 2 ` stol st]) arms,
                                         stol def]
     | Go (e1, e2) => %[$"GO", L.indent 2 ` etol e1, L.indent 2 ` etol e2]
     | Error s => %[$"ERROR", $("\"" ^ String.toString s ^ "\"")]
         )
       
  and etol exp =
    (case exp of
       Record lel => %[%[$"RECORD", itol ` length lel],
                       L.indent 2 ` % ` map (fn (l, e) => %[lab l, etol e]) lel]
     | Project (l, e) => %[$"PROJ", lab l, etol e]
     | Primcall (s, el) => %[$"PRIMCALL",
                             $s,
                             itol ` length el,
                             % ` map etol el]
     | Call (e, el) => %[%[$"CALL",
                           etol e,
                           itol ` length el],
                         L.indent 2 ` % ` map etol el]
     | Primop (po, args) =>
         (* XXX filter compilewarn and others that should never appear, or we'll
            get a parse error later *)
         %[%[$"PRIMOP", $(Primop.tostring po), itol ` length args], L.indent 2 ` % ` map etol args]
     | Int i => $(IntConst.tostring i)
     | Inj (l, e) => %[$"INJ", lab l, otol etol e]
     | String s => %[$("\"" ^ String.toString s ^ "\"")]
     | Var s => $s
     | Marshal (e1, e2) => %[$"MARSHAL", etol e1, etol e2]

     | Ref _ => raise BytePrint "can't write out refs"
     | Newtag => $"NEWTAG"
     | Dat {d, a} => %[$"DAT", etol d, etol a]
     | Dp pd => %[$"DP", pdtol pd]
     | Drec sel => %[%[$"DREC", itol ` length sel],
                     L.indent 2 ` % ` map (fn (l, e) => %[lab l, L.indent 2 ` etol e]) sel]
     | Dsum seol => %[%[$"DSUM", itol ` length seol],
                      L.indent 2 ` % ` map (fn (l, eo) => %[lab l, L.indent 2 ` otol etol eo]) seol]
     | Dlookup s => %[$"DLOOKUP", $s]
     | Dexists { d, a } => %[$"DEXISTS", $d, itol ` length a,
                             L.indent 2 ` % ` map etol a]
     | Dall (sl, e) => %[$"DALL", %[itol ` length sl, L.indent 2 ` % ` map $ sl],
                         L.indent 2 ` etol e]
     | Dsham { d, v } => %[$"DSHAM", $d, L.indent 2 ` etol v]
     | Dmu (m, sdl) => %[$"DMU", itol m,
                         %[itol ` length sdl, 
                           L.indent 2 ` % ` map (fn (s, d) => %[$s, etol d]) sdl]]
         )

  and pdtol dic =
    (case dic of
       Dcont => $"DCONT"
     | Dconts => $"DCONTS"
     | Daddr => $"DADDR"
     | Daa => $"DAA"
     | Dref => $"DREF"
     | Ddict => $"DDICT"
     | Dint => $"DINT"
     | Dexn => $"DEXN"
     | Dtag => $"DTAG"
     | Dw => $"DW"
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
    | gtol (OneDec (args, st)) =
    %[%[$"ONEDEC", itol ` List.length args],
      L.indent 2 ` % `map $ args,
      L.indent 2 ` stol st]

    | gtol Absent = $"ABSENT"

  fun ptol { globals, main } =
    %[$"PROGRAM", otol itol main,
      itol ` Vector.length globals,
      % ` vtol ` Vector.map gtol globals]

   
end
