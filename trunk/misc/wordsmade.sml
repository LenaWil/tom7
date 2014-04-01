(* Finds words that can be made of other words (e.g., symbols in the
   periodic table) and how they can be made. *)

structure WordsMade =
struct

  local
    (* lanthanides *)
    val la = ["La", "Ce", "Pr", "Nd", "Pm", "Sm", "Eu", "Gd", "Tb", "Dy", "Ho", "Er", "Tm", "Yb", "Lu"]
    (* actinides *)
    val ac = ["Ac", "Th", "Pa", "U",  "Np", "Pu", "Am", "Cm", "Bk", "Cf", "Es", "Fm", "Md", "No", "Lr"]
  in

  val elements = [
    "H",                                                                                                  "He",
    "Li", "Be",                                                           "B",  "C",  "N",  "O",  "F",  "Ne",
    "Na", "Mg",                                                             "Al", "Si", "P",  "S",  "Cl", "Ar",
    "K",  "Ca", "Sc", "Ti", "V",  "Cr", "Mn", "Fe", "Co", "Ni", "Cu", "Zn", "Ga", "Ge", "As", "Se", "Br", "Kr",
    "Rb", "Sr", "Y",  "Zr", "Nb", "Mo", "Tc", "Ru", "Rh", "Pd", "Ag", "Cd", "In", "Sn", "Sb", "Te", "I",  "Xe",
    "Cs", "Ba"] @la@ ["Hf", "Ta", "W",  "Re", "Os", "Ir", "Pt", "Au", "Hg", "Tl", "Pb", "Bi", "Po", "At", "Rn",
    "Fr", "Ra"] @ac@ ["Rf", "Db", "Sg", "Bh", "Hs", "Mt", "Ds", "Rg", "Cn", "Uut", "Fl", "Uup", "Lv", "Uus", "Uuo"]

  end

  structure SM = SplayMapFn(type ord_key = string
                            val compare = String.compare)
(*
  fun getword "the" = SOME "the"
    | getword "there" = SOME "there"
    | getword "min" = SOME "min"
    | getword "theremin" = SOME "theremin"
    | getword "mine" = SOME "mine"
    | getword _ = NONE
*)
  val dict = ref SM.empty : string SM.map ref
  val () = app (fn s =>
                dict := SM.insert (!dict, StringUtil.lcase s, s)) elements
  fun getword w = SM.find (!dict, w)

  fun oneword s =
    let
      (* Holds a list of little words that can make up
         the suffix of the big one starting at this
         position. *)
      val a = Array.array(size s, NONE)
      (* Only works once this position has been filled
         in, obviously *)
      fun gettail n = if n = size s
                      then SOME nil
                      else Array.sub(a, n)
      fun fill ~1 = ()
        | fill x =
        let
          fun try_len l =
            if x + l <= size s
            then
              let val prefix = String.substring (s, x, l)
              in
                case gettail (x + l) of
                  NONE => try_len (l + 1)
                | SOME tail =>
                    case getword prefix of
                      NONE => try_len (l + 1)
                    | SOME w => Array.update(a, x, SOME (w :: tail))
              end
            else ()
        in
          try_len 1;
          fill (x - 1)
        end
    in
      fill (size s - 1);
      gettail 0
    end

  fun printlist l = print (StringUtil.delimit "" l ^ "\n")
  fun printres NONE = print ("NONE.\n")
    | printres (SOME l) = printlist l
  fun try s = printres (oneword s)
  fun printif s = case oneword s of
    NONE => ()
  | SOME w => printlist w
  (* val words = Script.linesfromfile "/usr/share/dict/web2" *)
  val words = Script.linesfromfile "../../tom7misc/manarags/wordlist.asc"
  val words = map StringUtil.lcase words

  val possible = map String.concat (List.mapPartial oneword words)

  fun bylength (a, b) = Int.compare (size a, size b)
  val possible = ListUtil.sort bylength possible
  val () = app (fn s => print (s ^ "\n")) possible

end
