(* retracts a board with steel tiles. *)
functor Steel(val filename : string) :> GAME =
struct

    datatype dir = UP | DOWN | LEFT | RIGHT

    exception Steel of string

    val findshortest = false
    val reverse = true

    datatype color = GREY

    (* maybe I should be writing in Lisp? ;) *)
    type state = { guy : Word8.word,
                   (* Distinct and sorted *)
                   steel : (Word8.word * color) Vector.vector } 

    fun colorcompare _ = EQUAL
    fun steelcompare ((w1, c1), (w2, c2)) =
      case Word8.compare (w1, w2) of
        EQUAL => colorcompare (c1, c2)
      | other => other

    (* only allow levels with
       all bombs set unlit *)
    fun accepting { guy = _, steel } = true

    (* must be non-zero *)
    fun colortoint c = 1

    val xorb = Word32.xorb
    infix xorb
    fun rol (a, w) = Word32.orb(Word32.<<(a, w), Word32.>>(a, 0w32 - w))
    fun hash { guy, steel } =
       Vector.foldl (fn ((a, c), b) => Word32.fromInt (Word8.toInt a * colortoint c) xorb rol(b, 0w11))
                  (Word32.fromInt (Word8.toInt guy))
                  steel

    val eq = op= : state * state -> bool

  datatype cell = WALL | FLOOR

  val (width, { guy=initguy, board, steel=initsteel } ) =
    let

      val steel = ref nil

      val f = TextIO.openIn filename

      fun readuntil c =
        case TextIO.input1 f of
          NONE => raise Steel ("eof looking for chr " ^ 
                               Int.toString (ord c))
        | SOME cc => if c = cc then ()
                     else readuntil c

      fun uchar #"#" = WALL
        | uchar #" " = FLOOR
        | uchar #"-" = FLOOR
        | uchar #"." = FLOOR
        | uchar #"G" = FLOOR (* guy is on floor *)
        | uchar #"s" = FLOOR
        | uchar c = raise Steel ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      (* width, once we figure it out *)
      val w = ref ~1

      val arr = Array.array(16 * 16, FLOOR)
        
      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Steel ("Unexpected EOF: require ^ at end")
         | SOME #"<" => 
             (* end row *)
             let in
               (case !w of
                  ~1 => w := i
                | x  => if x mod !w <> 0 
                        then raise Steel ("Uneven rows")
                        else ());
               readuntil #"\n";
               parse i
             end
         | SOME #"^" =>
             (* end everything *)
             let in
               (* height *)
               i div !w
             end
         | SOME c => 
                let in
                  if c = #"G"
                  then g := SOME i
                  else ();
                  if c = #"s"
                  then steel := (i, GREY) :: !steel
                  else ();
                  Array.update(arr, i, uchar c);
                  parse (i + 1)
                end)

      val h = parse 0

    in
      
      TextIO.closeIn f;
      (!w,
       { guy = 
         (case !g of
            NONE => raise Steel ("There is no guy (G)")
          | SOME i => Word8.fromInt i),
         steel = Vector.fromList (ListUtil.mapfirst Word8.fromInt (!steel)),
         board = Vector.tabulate (!w * h,
                                  (fn i => Array.sub(arr, i))) })
    end handle (e as Steel s) => (print ("parse error: " ^ s ^ "\n");
                                  raise e)

  val height = Vector.length board div width

  fun travel i UP = if i >= width 
                    then SOME (i - width)
                    else NONE
    | travel i DOWN = if i < ((height * width) - width) 
                      then SOME (i + width)
                      else NONE
    | travel i LEFT = if i mod width <> 0
                      then SOME (i - 1)
                      else NONE
    | travel i RIGHT = if i mod width <> (width - 1)
                       then SOME (i + 1)
                       else NONE

  fun coords i = (i mod width, i div width)
  fun index (x, y) = x + y * width

  (* whatever is specified in the board text file *)
  val initials = [{ guy = initguy, steel = initsteel }]

  val () = if width * height > 255 
           then raise Steel "board too big for 8 bit positions!"
           else ()


(*
  (* insert a bomb into v, assuming that there is at least one
     empty (0w0) bomb in the vector. Since there must be at least
     one, and the bomb vector is sorted, wlog we can use the
     first slot. *)
  fun insertbomb v newbomb =
      (* PERF correct, ridiculous *)
      Vector.fromList (ListUtil.sort SW.compare (newbomb ::
                                                 tl
                                                 (Vector.foldr op:: nil v)))
  (* erase the nth bomb *)
  fun takebomb v idx =
      Vector.fromList (ListUtil.sort SW.compare
                       (Vector.foldri (fn (i, a, b) =>
                                       (if i = idx
                                        then bw 0w0
                                        else a) :: b) nil v))
*)

  exception Illegal
  
  (* given as indices... *)
  fun manhattan (a, b) =
      let val (x1, y1) = (a mod width, a div width)
          val (x2, y2) = (b mod width, b div width)
          fun abs x = if x < 0 then 0 - x else x
      in
          abs(x1 - x2) + 
          abs(y1 - y2)
      end

  fun parity a =
      let val (x, y) = (a mod width, a div width)
      in
          ((x + y) mod 2) = 1
      end

  (* not currently used? *)

  (* distances between pairs of positions on the
     board; must be conservative (should take no
     fewer than the number of steps here for the
     player to walk from one square to the other.) *)
  val distmap = Array.array (width * height *
                             width * height, 0)

  local
      structure H = HeapFn(type priority = int
                           val compare = Int.compare)

      
      (* compute the shortest path, assuming the
         guy is never on a wall *)
      (* it'd be great if I could use the Search
         functor for this (and amusing since
         Steel itself is an argument to
         Search), but not unless I can apply
         functors within loops... *)
      fun shortestpath (src, dest) =
        case Vector.sub(board, src) of
            WALL => width * height + 2
          | FLOOR => 
          let
              (* intialize distances with infinity, except src is 0 *)
              val dist = Array.array(width * height, NONE)
              fun setdist (x, y) v = Array.update(dist, x + y * width, v)
              fun getdist (x, y) = Array.sub(dist, x + y * width)

              val queue = H.empty () : (int * int) H.heap

              (* new path here from source, set.. *)
              fun visit (x, y) d =
                  case getdist (x, y) of
                      NONE => (* first time seeing this *)
                          let val hand = H.insert queue d (x, y)
                          in
                              setdist (x, y) (SOME ((x, y), d, hand))
                          end
                    | SOME (_, dist, hand) =>
                          if H.valid hand
                          then (* still in queue, might need to update it.. *)
                              let val (oldd, _) = H.get queue hand
                              in
                                  (* strictly better? *)
                                  if d < oldd
                                  then
                                      let in
                                          H.adjust queue hand d;
                                          setdist (x, y) (SOME((x, y), d, hand))
                                      end
                                  else ()
                              end
                          else () (* already found minimal path *)

              fun loop () =
                  case H.min queue of
                      NONE => () (* done -- frontier empty *)
                    | SOME (_, pos) =>
                          let 
                              val (_, dist, hand) = valOf (getdist pos)
                              fun try d = 
                                  case travel (index pos) d of 
                                      SOME pos' => 
                                          (case Vector.sub(board, pos') of
                                               WALL => ()
                                             | FLOOR => visit (coords pos') (dist + 1))
                                    | NONE => ()
                          in
                              try UP;
                              try LEFT;
                              try RIGHT;
                              try DOWN;
                              loop ()
                          end
          in
              visit (coords src) 0;
              loop ();
              (case getdist (coords dest) of
                   NONE => (* can't reach *) width * height + 1 
                 | SOME (_, d, _) => d)
          end
      
      (* PERF this is crazy--the procedure above computes src->all dests,
         so it should be called for all sources, not all s/d pairs *)
      (* PERF should be symmetric *)
      fun init i =
          let
              val src = i mod (width * height)
              val dst = i div (width * height)
          in
              Array.update(distmap, i, shortestpath (src, dst))
          end
  in
      val () =
          Util.for 0 (width * height * width * height - 1) init

      val _ = TextIO.output(TextIO.stdErr, "distances cached.\n")

      fun distance (a, b) = 
          Array.sub(distmap,
                    (width * height * b) + a)
  end
      

  fun app_successors (f, {guy, steel} : state) =
      let

          (* we always move in one of four directions.

             when we do, we might "drag" steel with us.
             we can drag any number of consecutive 
             steels (including 0) along the column
             that we move. *)

          val guy = Word8.toInt guy

          fun steelat steel dest =
              (* PERF? could do binary search *)
              (* by invt, there is at most one, so we can return a single
                 example *)
              Vector.findi (fn (_, (x, color)) => x = dest) steel

          fun issteelat steel dest = Option.isSome (steelat steel dest)

          (* retracting a move in direction 'dir'

               <- opp
                -+-+-+-+
                  G X X|
                -+-+-+-+
                  dir->

               retracts to:

                -+-+-+-+        -+-+-+-+        -+-+-+-+
                G   X X|   or   G X   X|   or   G X X  |
                -+-+-+-+        -+-+-+-+        -+-+-+-+
               

                *)
            fun go bombs dir opp =
                case travel guy opp of
                    NONE => () (* off board *)
                    (* guynew is the new place for the guy 
                       (ie. where was in the retracted state) *)
                  | SOME guynew => 
                let
                    val guynew = Word8.fromInt guynew
                    (* here, blocked means that we wouldn't
                       have been able to walk into 'idx' from d. 
                       We also assume we don't ever start
                       on walls or steel. *)
                    val blocked =
                        (* by invariant, we aren't on a wall
                           or steel. is our retracted position
                           on a wall or steel? *)
                        case Vector.sub(board, Word8.toInt guynew) of
                            WALL => true
                          | FLOOR => issteelat steel guynew
                                        
                in
                    if blocked
                    then ()
                    else
                        let 
                          (* drag each steel in the retset along with the dude. *)
                          fun dodrag nil = (* common case, reuse steel vector *)
                            f ({guy = guynew, steel=steel}, 1)

                            | dodrag retset =
                            let
                              (* each steel in retset moves one space in direction 
                                 'dir' *)
                              (* PERF could do less allocation here *)
                              val (moves, stays) =
                                let 
                                  val l = Vector.foldr op:: nil steel
                                  fun parti _ nil = (nil, nil)
                                    | parti n (h :: t) =
                                    let
                                      val (tt, ff) = parti (n + 1) t
                                    in
                                      if List.exists (fn x => x = n) retset
                                      then (h :: tt, ff)
                                      else (tt, h :: ff)
                                    end
                                in
                                  parti 0 l
                                end

                              val steel =
                                Vector.fromList (ListUtil.sort
                                                 steelcompare
                                                 
                                                 (* new steel list *)
                                                 (map (fn (pos, color) =>
                                                       case travel (Word8.toInt pos) opp of
                                                         NONE => raise Steel "impossible!"
                                                       | SOME pos => (Word8.fromInt pos, color)) moves
                                                  @ stays))
                            in
                              f ({guy = guynew, steel=steel}, 1)
                            end

                          (* retract 'n' steel tiles in the direction 'dir'.
                             we can always do at least 0 *)
                          fun retn retset g =
                            let in
                              (* be eager--try dragging as many as possible
                                 first *)
                              (case travel g dir of
                                 NONE => (* edge of board; fail *) ()
                               | SOME bi =>
                                   case steelat steel (Word8.fromInt bi) of
                                     NONE => (* no steel; fail *) ()
                                   | SOME (idx, _) =>
                                       retn (idx :: retset) bi);

                                 dodrag retset
                            end
                        in
                            retn nil guy
                        end
                end
        in
          go steel UP DOWN;
          go steel DOWN UP;
          go steel LEFT RIGHT;
          go steel RIGHT LEFT
        end


  fun tostring { guy, steel } =
    let 
        val FACTOR = 1

        val topbot = 
            CharVector.tabulate(FACTOR - 1, fn _ => #" ") ^ "#" ^
            CharVector.tabulate(FACTOR * width, 
                                         fn x => #"#") ^ "#"
(*        ^ CharVector.tabulate(FACTOR - 1, fn _ => #" ") *)
    in
      StringUtil.delimit "\n"
      (topbot ::
       List.tabulate
       (Vector.length board div width,
        (fn y =>
         "#" ^
         String.concat
         (List.tabulate
          (width,
           (fn x =>
            let val i = y * width + x
            in
                if i = Word8.toInt guy
                then "@"
                else 
                    (case Vector.find (fn (z, _) => z = (Word8.fromInt i)) steel of
                         SOME (_, GREY) => "s"
                       | NONE => 
                             case Vector.sub(board, i) of
                                 FLOOR => " "
                               | WALL => "#")
            end))) ^ "#")) @ [topbot])
    end

    fun tocode { guy, steel } =
        let
            val e = Word8.toInt guy :: 
                (Vector.foldr op:: nil (Vector.map (fn (p, GREY) => Word8.toInt p) steel))
        in
            StringUtil.delimit "," (map Int.toString e)
        end

end
