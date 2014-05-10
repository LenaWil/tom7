(* Sorts the letters in each input line. *)

structure SortLetters =
struct

  fun sortletters s = 
    let val s = StringUtil.lcase s
      val s = StringUtil.filter 
        (not o StringUtil.charspec "!@#$%^&*()_+=:',./,.?- ") s
    in implode (ListUtil.sort Char.compare (explode s))
    end

  val lines = Script.linesfromfile "sortlines.txt"
  val lines = ListUtil.mapto sortletters lines

  fun oneline (a, b) = print (b ^ "       (" ^ a ^ ")\n")
  val () = app oneline lines

end
