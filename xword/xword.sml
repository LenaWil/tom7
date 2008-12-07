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

    val legal : unit Trie.trie = Trie.new()
    val () = app (fn w => Trie.insert legal w {}) (Script.linesfromfile "wordlist.asc")

    (* ?? *)

(*    val WIDTH = foldl (fn (w, m) => Int.max (size w, m)) 0 required *)
    val WIDTH = size "happyholidays"
    val HEIGHT = WIDTH

    val a = Array.array (HEIGHT * WIDTH, chr 0)
    fun at(x, y) = 
      (* if x < 0 orelse y < 0
           orelse x >= WIDTH orelse y >= HEIGHT
        then (print ("Out: " ^ Int.toString x ^ "/" ^ Int.toString y ^ "\n");
              raise Subscript)
        else *) Array.sub(a, y * WIDTH + x)
    fun set(x, y, c) = Array.update(a, y * WIDTH + x, c)

    fun copy_array a = Array.tabulate (Array.length a, fn x => Array.sub(a, x))
    val bestdensity = ref 0
    val bestboard = ref (copy_array a)
    fun density () =
        Array.foldl (fn (c, b) =>
                     if c = chr 0
                     then b
                     else b + 1) 0 a

    fun printboard () =
        let in
            print "\n\n";
            Util.for 0 (HEIGHT - 1)
            (fn y =>
             let in
                 Util.for 0 (WIDTH - 1)
                 (fn x =>
                  if at(x, y) = chr 0
                  then print "  "
                  else print (implode [at(x, y), #" "]));
                 print "\n"
             end)
        end

    (* Is the new word crossing x/y in the direction px, py legitimate? *)
    fun legit (x, y, px, py) = 
        let
            (* first rewind until we find the start of the word *)
            val (startx, starty) =
                let
                    fun rewind (x, y) =
                        let val (nx, ny) = (x - px, y - py)
                        in
                            (* assume we only go off top or left *)
                            if nx < 0 orelse ny < 0 then (x, y)
                            else if at(nx, ny) = chr 0 then (x, y)
                                 else rewind(nx, ny)
                        end
                in
                    rewind (x, y)
                end

            (* Check that the word (suffix) is legit, with the length so far being
               'len', continuing at x,y and using (sub)trie t *)
            fun check t len (x, y) =
               (* assume we only go over the right or bottom. *)
               let in
(*
                   print ("legit " ^ Int.toString len ^ " @" ^
                          Int.toString x ^ ", " ^
                          Int.toString y ^ "\n");
                   *)
                   if x >= WIDTH orelse y >= HEIGHT
                      orelse at(x, y) = chr 0
                   (* length-1 "words" don't need to be words *)
                   then let in
                        (* print "STOP\n"; *)
                        Option.isSome (Trie.value t) orelse len = 1
                        end
                   (* PERF repeated sub *)
                   else case Trie.child t (at(x, y)) of
                           NONE => false
                         | SOME t => check t (len + 1) (x + px, y + py)
               end
        in
            check legal 0 (startx, starty)
        end

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
                then 
                    let in
                        (* print "CALL"; *)
                        f()
                    end
                else 
(*
                    if x < 0 orelse y < 0 orelse x >= WIDTH
                       orelse y >= HEIGHT
                    then print "OOPS"
                    else *)
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

    exception Unimplemented
    (* HERE *)
    (* try to fill empty space on the board. *)
    fun fillin () =
        Util.for 0 (HEIGHT - 1)
        (fn y =>
         Util.for 0 (WIDTH - 1)
         (fn x =>
          (* try making a word horizontally and vertically. *)
          let 
              (* with subtree t, continue the word of
                 length len at the position (x, y) heading
                 in direction dx, dy.

                 Need to check that incidental words are legit.
                 Can stop whenever the next letter is blank and
                 we are in an accepting spot, but we don't have to.
                 *)
              fun placer t len (x, y) (dx, dy) =
                  if x >= WIDTH orelse y >= HEIGHT
                     orelse at(x, y) = chr 0
                  (* length-1 "words" don't need to be words *)
                  then let in
                      (* print "STOP\n"; *)
                      (* Option.isSome (Trie.value t) orelse len = 1 *)
                       end
                  else (* case Trie.child t (at(x, y)) of
                      NONE => false
                    | SOME t => check t (len + 1) (x + px, y + py) *)
*)
                  raise Unimplemented
          in
              raise Unimplemented
          end))

    fun allrequired _ _ k nil =
        (* Did it! *)
        k ()
      | allrequired d req k (hs :: t) =
        app (fn h =>
        let 
            val len = size h

            fun horiz () =
                (* horizontal *)
                Util.for 0 (HEIGHT - 1)
                (fn starty =>
                 let in
                     if (d = 0)
                     then print ("\n" ^ Int.toString ((starty * 100) div (HEIGHT - 1)) ^ "-%")
                     else if (d <= 2)
                          then print "."
                          else ();

                     Util.for 0 (WIDTH - len)
                     (fn startx =>
                      let in
                          (*
                          print ("horiz " ^ 
                                 Int.toString startx ^ " " ^
                                 Int.toString starty ^ ": " ^ h ^ "\n");
                          *)
                          (* require gap (or edge) before and after word *)
                          if (startx = 0 orelse at(startx - 1, starty) = chr 0) andalso
                             let in
                                 (* print ("subx " ^ Int.toString (startx + len) ^ "\n"); *)
                                 startx + len = WIDTH orelse at(startx + len, starty) = chr 0
                             end
                          then withplace (h, startx, starty) ACROSS (fn () => allrequired (d + 1) req k t)
                          else ()
                      end)
                 end)

            fun vert () =
                (* vertical *)
                Util.for 0 (HEIGHT - len)
                (fn starty =>
                 let in
                     if (d = 0)
                     then print ("\n" ^ Int.toString ((starty * 100) div (HEIGHT - 1)) ^ "|%")
                     else if (d <= 2)
                          then print "."
                          else ();

                     Util.for 0 (WIDTH - 1)
                     (fn startx =>
                      (* require gap (or edge) before and after word *)
                      let in
                          (* print ("vert " ^ 
                                 Int.toString startx ^ " " ^
                                 Int.toString starty ^ ": " ^ h ^ "\n"); *)
                          if (starty = 0 orelse at(startx, starty - 1) = chr 0) andalso
                             (starty + len = HEIGHT orelse at(startx, starty + len) = chr 0)
                          then withplace (h, startx, starty) DOWN (fn () => allrequired (d + 1) req k t)
                          else ()
                      end)
                 end)
        in
            (* Try all placements of this word. *)
            if d mod 2 = 0
            then (horiz (); vert ())
            else (vert (); horiz ());
            (* If we are not required to place this word, also try skipping it *)
            if req
            then ()
            else allrequired (d + 1) req k t
        end) hs

    fun loadsort f =
        let
            val long = Int.max (WIDTH, HEIGHT)
            val ws = Script.linesfromfile f
            val ws = map (fn l => String.tokens (fn #" " => true | _ => false) l) ws
            val ws = map (ListUtil.sort (fn (w1, w2) => Int.compare (size w2, size w1))) ws
            val ws = ListUtil.sort (fn (w1, w2) =>
                                    let 
                                        val n1 = foldl Int.min long (map size w1)
                                        val n2 = foldl Int.min long (map size w2)
                                    in
                                        Int.compare (n2, n1)
                                    end) ws
        in
            app (fn wl => 
                 let in 
                     app (fn w => print (w ^ " ")) wl;
                     print "\n"
                 end) ws;
            ws
        end

    val seen = ref 0
    val MAXSEEN = 10000000
    fun maybesave () =
        let in
            if density () > !bestdensity
            then 
                let in
                    bestboard := copy_array a;
                    bestdensity := density ();
                    printboard ()
                end
            else (* print "," *) ();
            seen := !seen + 1;
            if !seen > MAXSEEN
            then raise Done
            else ()
        end

    fun go () =
        let 
            val required = loadsort "required.txt"
            val good : string list list = loadsort "good.txt"
        in
            seen := 0;
            Util.for 0 (HEIGHT - 1)
            (fn y =>
             Util.for 0 (WIDTH - 1)
             (fn x =>
              set(x, y, chr 0)));
            allrequired 0 true (fn () => 
                                allrequired 0 false (fn () => 
                                                     let in
                                                         maybesave ()
                                                     end) good
                                ) required
        end
end
