
      (* When generating strings we use doubly-linked lists (DLL, not
         dynamically linked library :)) to concatenate strings instead
         of eagerly rebuilding the strings with ^. *)
      "  datatype dllcell' =\n" ^
      "    D' of dllcell' option ref * string * dllcell' option ref\n" ^
      (* head and tail. Head should be NONE on its left and
         tail should be NONE on its right. They should be linked
         all the way through. *)
      "  type dll' = dllcell' * dllcell'\n" ^
      "  fun ^^ ((head, a as D' (t as ref NONE, _, _)),\n" ^
      "          (b as D' (h as ref NONE, _, _), tail)) =\n" ^
      "    let in\n" ^
      "      h := SOME a;\n" ^
      "      t := SOME b;\n" ^
      "      (head, tail)\n" ^
      "    end\n" ^
      "   | ^^ ((D'(_, s, _), D'(_, ss, _)),\n" ^
      "         (D'(_, z, _), D'(_, zz, _))) =\n" ^
      "     raise Parse (\"^^ bug: \" ^ s ^ \",\" ^ ss ^ \"+\" ^ z ^ \",\" ^ zz)\n" ^
      "  infix 2 ^^\n" ^
      "  fun $s = let val d = D'(ref NONE, s, ref NONE) in (d, d) end\n" ^
