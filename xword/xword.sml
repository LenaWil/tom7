(* Makes crossword puzzles. 

   The difficulty (because it is a large search space) comes from the
   placement of some set of clues into the grid in such a way that
   they cover as much of the grid as possible.

   Let's say there are two modes:

   (Place mode.) Try to fit every word in our required list into the
   grid. There are many such placements; we simply enumerate them.

   (Fill mode.) For each placement above, try to fill the rest of the
   grid with legal words from the dictionary. Here the difference is
   that instead of searching over words and places to put them, we are
   searching over grid cells and things to put in them.

*)
structure XWord =
struct

    val required = Script.linesfromfile "required.txt"

    val legal : unit Trie.trie = Trie.new()
    val () = app (fn w => Trie.insert legal w {}) (Script.linesfromfile "wordlist.asc")

    (* ?? *)
    val WIDTH = foldl (fn (w, m) => Int.max (size w, m)) 0 required
    val HEIGHT = WIDTH

    val a = Array.array (HEIGHT * WIDTH, chr 0)
    fun at(x, y) = Array.sub(a, y * WIDTH + x)
    fun set(x, y, c) = Array.update(a, y * WIDTH + x, c)

    fun printboard() =
        Util.for 0 (HEIGHT - 1)
        (fn y =>
         let in
             Util.for 0 (WIDTH - 1)
             (fn x =>
              print (implode [at(x, y), #" "]));
             print "\n"
         end)

    (* Is the new word crossing x/y in the direction px, py legitimate? *)
    fun legit (x, y, px, py) = true (* XXX *)

    exception Done
    datatype dir = ACROSS | DOWN
    (* try placing the word w at x,y in the current board,
       heading in direction (dx, dy).
       Does not check bounds. Checks that newly created incidental
       words are legit.
       If successful, call f with the modified board, then
       restore the board.
       If unsuccessful, return with the board unmodified. *)
    fun withplace (h, x, y) dir f =
        let
            val (dx, dy, px, py) = 
                case dir of
                    ACROSS => (1, 0, 0, 1)
                  | DOWN => (0, 1, 1, 0)
            val len = size h
            fun wp (i, x, y) =
                if i >= len
                then f()
                else 
                    let val ch = String.sub(h, i)
                    in
                        if at(x, y) = chr 0
                        then 
                            (* place, check, undo. *)
                            let in
                                set(x, y, ch);
                                if legit(x, y, px, py)
                                then wp (i + 1, x + dx, y + dy)
                                else ();
                                set(x, y, chr 0)
                            end
                        else if at(x, y) = ch
                             then wp (i + 1, x + dx, y + dy)
                             else () (* fails *)
                    end
        in
            wp (0, x, y)
        end

    fun allrequired nil =
        (* Did it! *)
        (printboard (); raise Done)
      | allrequired (h :: t) =
        let 
            val len = size h
        in
            (* Try all placements of this word. *)
            (* horizontal *)
            Util.for 0 (HEIGHT - 1)
            (fn starty =>
             Util.for 0 (WIDTH - len)
             (fn startx =>
              withplace (h, startx, starty) ACROSS (fn () => allrequired t)
              ))
        end
end
