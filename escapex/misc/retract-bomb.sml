(* retracts a board with Bombs, assuming nothing
   on the board can be destroyed *)
functor Bomb(val nbombs : int
             val timers : int list
             val filename : string) :> GAME =
struct

    datatype dir = UP | DOWN | LEFT | RIGHT

    exception Bomb of string

    val () = if nbombs < 0 orelse length timers < 1
             then raise Bomb "bad args: negative or empty timers?"
             else ()

    val () = if List.exists (fn t => t >= 11 orelse t < 0) timers
             then raise Bomb "max timer too high"
             else ()

    val findshortest = false
    val reverse = true

    (* need to generate intermediate timers of bombs
       that are destroyed in chain reactions. *)
    val maxtimer = 
        List.foldl Int.max (hd timers) timers

    fun foralltimers f =
        List.app f timers

    (* top 8 bits: position,
       next 4 bits: current timer
       low 4 bits: start timer 

       bombs can be in one of several 
       states.

       * timer counting down:
          pos, cur, start as expected.

       * not yet lit
          pos and start as expected.
          cur = 0xE
          (0xE is beyond any legal
          max timer, so

       * exploding
          pos and start as expected.
          cur = 0xF
          (these bombs are placed
          during phoenixization: they
          are exploded and so they have
          timer ~1, but are temporarily)

       * exploded and gone
          pos   = 0
          cur   = 0
          start = 0
          (must all be 0 so that
           we consider them equal
           no matter where they
           exploded)

       *)
    structure BW = Word16
    type bomb = BW.word

    fun bw x = BW.fromLargeWord x

    type state = { guy : Word8.word,
                   (* always distinct and sorted (by BW.word value),
                      length exactly nbombs *)
                   bombs : bomb Vector.vector } 

    fun bomb_start w = BW.toInt(BW.andb(w, bw 0w15))
    fun bomb_cur   w = BW.toInt(BW.andb(BW.>>(w, 0w4), bw 0w15))
    fun bomb_pos   w = BW.toInt(BW.andb(BW.>>(w, 0w8), bw 0w255))

    fun bombw_ { pos, cur, start } =
        BW.orb(BW.<<(pos, 0w8),
               BW.orb(BW.<<(cur, 0w4),
                      start))

    fun bomb_ { pos, cur, start } = bombw_ { pos = BW.fromInt pos,
                                             cur = BW.andb(BW.fromInt cur, bw 0w15),
                                             start = BW.andb(BW.fromInt start, bw 0w15) }

    fun bomb_exploding pos start = bombw_ { pos = BW.fromInt pos,
                                            cur = bw 0w15,
                                            start = BW.fromInt start }

    (* only allow levels with
       all bombs set unlit *)
    fun accepting { guy = _,
                    bombs } = 
        Vector.all (fn b => b <> bw 0w0 andalso bomb_cur b = 14) bombs

        
    val xorb = Word32.xorb
    infix xorb
    fun rol (a, w) = Word32.orb(Word32.<<(a, w), Word32.>>(a, 0w32 - w))
    fun hash { guy, bombs } =
        (* PERF: note, toLarge is apparently slower in current mlton *)
       Vector.foldl (fn (a, b) => Word32.fromInt (BW.toInt a) xorb rol(b, 0w11))
                  (Word32.fromInt (Word8.toInt guy))
                  bombs

    val eq = op= : state * state -> bool

  datatype cell = WALL | FLOOR

  val (width, { guy=initguy, board } ) =
    let

      val f = TextIO.openIn filename

      fun readuntil c =
        case TextIO.input1 f of
          NONE => raise Bomb ("eof looking for chr " ^ 
                               Int.toString (ord c))
        | SOME cc => if c = cc then ()
                     else readuntil c

      (* XXX some way to place bombs too? *)
      fun uchar #"#" = WALL
        | uchar #" " = FLOOR
        | uchar #"-" = FLOOR
        | uchar #"." = FLOOR
        | uchar #"G" = FLOOR (* guy is on floor *)
        | uchar c = raise Bomb ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      (* width, once we figure it out *)
      val w = ref ~1

      val arr = Array.array(16 * 16, FLOOR)
        
      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Bomb ("Unexpected EOF: require ^ at end")
         | SOME #"<" => 
             (* end row *)
             let in
               (case !w of
                  ~1 => w := i
                | x  => if x mod !w <> 0 
                        then raise Bomb ("Uneven rows")
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
                  Array.update(arr, i, uchar c);
                  parse (i + 1)
                end)

      val h = parse 0
    in
      
      TextIO.closeIn f;
      (!w,
       { guy = 
         (case !g of
            NONE => raise Bomb ("There is no guy (G)")
          | SOME i => Word8.fromInt i),
         board = Vector.tabulate (!w * h,
                                  (fn i => Array.sub(arr, i))) })
    end handle (e as Bomb s) => (print ("parse error: " ^ s ^ "\n");
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

  (* start with guy wherever he goes, bombs all detonated *)
  val initial = [{ guy = initguy,
                   bombs = Vector.tabulate(nbombs, fn _ => bw 0w0) }]


  (* insert a bomb into v, assuming that there is at least one
     empty (0w0) bomb in the vector. Since there must be at least
     one, and the bomb vector is sorted, wlog we can use the
     first slot. *)
  fun insertbomb v newbomb =
      (* PERF correct, ridiculous *)
      Vector.fromList (ListUtil.sort BW.compare (newbomb ::
                                                 tl
                                                 (Vector.foldr op:: nil v)))
  (* erase the nth bomb *)
  fun takebomb v idx =
      Vector.fromList (ListUtil.sort BW.compare
                       (Vector.foldri (fn (i, a, b) =>
                                       (if i = idx
                                        then bw 0w0
                                        else a) :: b) nil v))

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
         RetractBomb itself is an argument to
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
      

  fun app_successors (f_orig, {guy, bombs} : state) =
      let
          (* prune impossible states; then call f_orig
             only for the possible ones. 
             
             for a configuration to be possible, each
             lit bomb of (max, cur) must have been
             touched (max - cur) steps ago, so the
             player must have at most that manhattan
             distance from the bomb.

             also, every move to a four-connected
             neighbor reverses the parity of the
             guy's index, so we can also filter out
             half of the (max - cur) values this way,
             if the bomb resides on a cell of the
             wrong parity.

             nb. even though we do this pruning at
             the last minute, we also do some 
             pruning during the bomb generation phase
             below, since it is itself exponential. *)
          fun f (state as { guy, bombs }, score) =
              let
                  fun bomb_ok b =
                      if b = (bw 0w0) orelse bomb_cur b = 14
                      then true (* unlit or gone bombs are always ok *)
                      else
                          let val time = bomb_start b - bomb_cur b
                          in
                              (* if time is even, then
                                 guy and bomb should have
                                 the same parity. *)
                              (if time mod 2 = 0
                               then parity (Word8.toInt guy) = parity (bomb_pos b)
                               else parity (Word8.toInt guy) <> parity (bomb_pos b))
                                 andalso
                              time <= distance (Word8.toInt guy, bomb_pos b)
                                  
                          (* PERF andalso distance *)
                          end
              in
                  if Vector.all bomb_ok bombs
                  then f_orig (state, score)
                  else ()
              end

          (* we always move in one of four directions.

             when we do, we might "drag" a bomb with
             us. we can only do this if the bomb has
             its max timer value minus 1 (which is what
             happens when we push a bomb: it becomes
             lit and set to its max timer value, then
             decreases when it takes its turn). the
             bomb after dragging can have any timer
             value less than its max timer, or can be
             unlit. 

             any lit bombs we're not dragging get their
             timer values increased by exactly 1. If
             this causes any to reach its maximum
             timer value, then the move is impossible.
             (this constrains the movement of the player
             a lot when lit bombs are present).

             before we move (which corresponds to *after*
             the guy moves in the regular direction of time)
             some bombs may pop into existence (an explosion
             of some bombs *after* the dude walks). These
             pop into existence with a timer of X; 
             think about it:
             
             
             real time T(n-1)     T(n-1)         T(n)
                   player turn    bomb turn      player turn

                    .....          ...*.         .....
                    ...0.          ..***         .....
                    .G...          G..*.         G....
                    .....          .....         .....

               guy walks left     bomb explodes   end

             a bomb can pop into existence ("phoenixize")
             on any empty square whose 4-connected neighbors
             are also empty before retraction. this is because
             bombs destroy the player and adjacent bombs when
             they explode.

             because of chain reactions, we can phoenixize
             a whole bunch of bombs all at once. inside the
             explosion region of a detonating bomb (its
             4-connected neighbors, we may invent another
             bomb. it may have any timer value (including unlit)
             and any max timer. since that bomb is detonated
             as part of the chain reaction, we apply this
             process recursively to any square that is a candidate
             for bomb phoenixization.

             so, the steps are:

             1. pick a phoenixization
                  (set of newly invented bombs consistent
                   with the current pre-retraction state)

             2. for each one, pick a walking direction
                  (4 are possible)
             
             3. for each direction, maybe drag an adjacent
                bomb with us (only if it has the right
                timer value).

             *)

          (* can move the guy in one of four directions. *)
          val guy = Word8.toInt guy

          (* get the unexploded bomb at dest? *)
          fun bombat bombs dest =
              (* PERF? could do binary search *)
              (* by invt, there is at most one, so we can return a single
                 example *)
              Vector.findi (fn (_, x) => x <> bw 0w0 andalso bomb_pos x = dest) bombs

          fun isbombat bombs dest = Option.isSome (bombat bombs dest)

          (* call f for all phoenixizations of the current position.
             f : bombvector -> unit
             *)
          fun all_phoenixizations f =
              let
                  fun ap 0 _ = ()
                    | ap bombsleft bombs =
                      let

                          datatype phoenixstyle =
                              (* can't place a bomb here *)
                              NOTOK
                              (* can place a bomb, but it must
                                 be exploding *)
                            | OKCLEAR
                              (* can place a bomb, but it can
                                 have any timer value *)
                            | OKCHAIN

                          fun check i =
                              if guy = i then NOTOK
                              else (case bombat bombs i of
                                        NONE => OKCLEAR
                                      | SOME (_, b) => 
                                            if bomb_cur b = 15
                                            then OKCHAIN
                                            else NOTOK)

                          (* assuming neither is NOTOK, 
                             can this be okchain? *)
                          fun chainup (OKCHAIN, _) = OKCHAIN
                            | chainup (_, OKCHAIN) = OKCHAIN
                            | chainup _ = OKCLEAR
                          infix chainup

                          fun checkd UP i =
                              if i >= width
                              then check (i - width)
                              else OKCLEAR

                            | checkd DOWN i =                           
                              if i < ((height * width) - width)
                              then check (i + width)
                              else OKCLEAR

                            | checkd LEFT i =
                              if i mod width <> 0
                              then check (i - 1)
                              else OKCLEAR

                            | checkd RIGHT i =
                              if i mod width <> (width - 1)
                              then check (i + 1)
                              else OKCLEAR

                          (* PERF should not be okclear if
                             manhattan distance from player
                             to bomb exceeds maxtimer *)
                          (* PERF can also use guy parity *)
                          (* a square is phoenixok if it
                             contains nothing and also all
                             of its 4-connected neighbors
                             contain nothing (or a bomb that's
                             exploding now) *)
                          fun phoenixok i =
                               case (Vector.sub(board, i), check i) of
                                   (WALL, _) => NOTOK
                                 | (_, OKCHAIN) => NOTOK
                                 | (_, NOTOK) => NOTOK
                                 | (FLOOR, OKCLEAR) =>
                                  case checkd UP i of
                                       NOTOK => NOTOK
                                     | r0 =>
                                   case checkd DOWN i of
                                       NOTOK => NOTOK
                                     | r1 =>
                                    case checkd LEFT i of
                                        NOTOK => NOTOK
                                      | r2 =>
                                     case checkd RIGHT i of
                                         NOTOK => NOTOK
                                       | r3 => r0 chainup r1 chainup r2 chainup r3

                          fun placebomb_exploding i max =
                               let
                                   (* val () = print ("PLACEBOMB " ^ Int.toString i ^ "\n")*)
                                   val bombs = insertbomb bombs (bomb_exploding i max)
                               in
                                   f bombs;
                                   (* maybe place more... *)
                                   ap (bombsleft - 1) bombs
                               end

                          fun placebombs_lit i max =
                              (* timer when exploded. lit timers are always
                                 in the range 0..maxtimer-1 *)
                              (* PERF should prune eagerly... *)
                              Util.for 0 (max - 1)
                              (fn cur =>
                               let
                                   val bombs = insertbomb bombs (bomb_ { pos = i,
                                                                         cur = cur,
                                                                         start = max })
                               in
                                   f bombs;
                                   ap (bombsleft - 1) bombs
                               end)

                          fun placebomb_unlit i max =
                               let
                                   val bombs = insertbomb bombs (bomb_ { pos = i,
                                                                         cur = 14,
                                                                         start = max })
                               in
                                   f bombs;
                                   ap (bombsleft - 1) bombs
                               end

                      in
                          Util.for 0 (width * height - 1)
                          (fn i =>
                           case phoenixok i of
                               OKCLEAR => foralltimers (fn t =>
                                                        (* this maxtimer t is only possible
                                                           if we are no more than t steps
                                                           (manhattan distance) away from the 
                                                           exploding bomb, since we must have
                                                           touched it in the last t steps. *)
                                                        if distance (i, guy) <= (t + 1)
                                                        then placebomb_exploding i t
                                                        else ())
                             | OKCHAIN =>
                                   let in
                                       (* print "CHAIN!\n";*)
                                       (* lit bombs of any timer (max and cur) *)
                                       foralltimers (placebombs_lit i);
                                       (* also a bomb exploding synchronously.
                                          same condition as above... *)
                                       foralltimers (fn t =>
                                                     if distance (i, guy) <= (t + 1)
                                                     then placebomb_exploding i t
                                                     else ());
                                       (* and finally unlit bombs. can't do any
                                          pruning on these... *)
                                       foralltimers (placebomb_unlit i)
                                   end
                             | NOTOK => ())
                      end
                  (* convenient to count this once *)
                  val bleft = VectorUtil.count (fn c => c = bw 0w0) bombs
              in
                  (* print ("BOMBSLEFT: " ^ Int.toString bleft ^ "\n"); *)
                  (* place no bombs *)
                  f bombs;
                  ap bleft bombs
              end

          (* given some bombs, now retracting a move in
             direction 'dir'

               <- opp
                -+-+-+
                  G X|
                -+-+-+
                  dir->

               retracts to:

                -+-+-+           -+-+-+
                G   X|     or    G X  |
                -+-+-+           -+-+-+
               

                *)
            fun go bombs dir opp =
                case travel guy opp of
                    NONE => () (* off board *)
                    (* guynew is the new place for the guy 
                       (ie. where was in the retracted state) *)
                  | SOME guynew => 
                let
                    (* here, blocked means that we wouldn't
                       have been able to walk into 'idx' from d. 
                       We also assume we don't ever start
                       on walls or bombs. *)
                    val blocked =
                        (* by invariant, we aren't on a wall
                           or bomb. is our retracted position
                           on a wall or bomb? *)
                        case Vector.sub(board, guynew) of
                            WALL => true
                          | FLOOR => isbombat bombs guynew

                    fun ifincrement b f =
                        (* because the major axis here is
                           position, incrementing the cur
                           value cannot affect the sort
                           order! *)
                        let val newb =
                            Vector.map (fn x =>
                                        if x = bw 0w0
                                        then x
                                        else
                                            let 
                                                val pos = bomb_pos x
                                                val start = bomb_start x
                                                val cur = bomb_cur x

                                                val ncur = BW.toInt
                                                    (BW.andb(BW.fromInt(cur + 1),
                                                             bw 0w15))
                                            in
                                                if cur = 14
                                                then x
                                                else if ncur > start
                                                     then raise Illegal
                                                     else bomb_ { pos = pos,
                                                                  cur = ncur,
                                                                  start = start }
                                            end) b
                        in
                            f newb
                        end handle Illegal => ()
                                        
                in
                    if blocked
                    then ()
                    else
                        let 
                        in
                            (* just walking--only if increment is legal. *)
                            ifincrement bombs (fn bombs =>
                                               f ({ guy = Word8.fromInt guynew,
                                                    bombs = bombs }, 1));
                            (* pulling bombs? *)
                            (case travel guy dir of
                                 NONE => () (* no bomb over here, 
                                               since edge of board *)
                               | SOME bi =>
                                   (case bombat bombs bi of
                                        NONE => () (* no bomb: no retract *)
                                      | SOME (idx, b) =>
                                            let
                                                val pos = bomb_pos b
                                                val start = bomb_start b
                                                val cur = bomb_cur b
                                            in
                                                (* can only retract when the
                                                   bomb we are pulling is at
                                                   its max timer value - 1. *)
                                                if cur = start - 1
                                                then 
                                                    ifincrement 
                                                       (* everything but this bomb *)
                                                       (takebomb bombs idx)
                                                       (fn bombs =>
                                                        let in
                                                        (* lit. could have had
                                                           any value when we
                                                           pushed it. *)
                                                        Util.for 0 (start - 1)
                                                        (fn cur =>
                                                         f ({ guy = Word8.fromInt guynew,
                                                              bombs = 
                                                              insertbomb bombs
                                                              (bomb_ { pos = guy,
                                                                       cur = cur,
                                                                       start = start }) },
                                                            1));

                                                        (* unlit *)
                                                        f ({ guy = Word8.fromInt guynew,
                                                             bombs =
                                                             insertbomb bombs
                                                             (bomb_ { pos = guy,
                                                                      cur = 14,
                                                                      start = start }) },
                                                           1)
                                                        end)
                                                else ()
                                            end))
                        end

                end
(*
                        let 
                            val bi = guy + dirchange dir

                            (* what about bringing a block with us? *)
                            fun perhapsretract yb (yy1, yy2, yy3, yy4, yy5) =
                                if yb = bi
                                then f (merge (fi guynew) (fi guy)
                                         {y2 = fi yy1, y3= fi yy2, y4= fi yy3, y5= fi yy4,
                                          y6 = fi yy5},
                                        100)
                                else ()
                        in
                            (* can't be on rough. *)
                            if Word32.andb(Array.sub(board, guy), ROUGH) = 0w0
                                (* assume no wall between us -- we support only solid
                                   walls, I guess *)
                            then
                                let in
                                    (* and there must be a block to retract *)
                                    perhapsretract y1 (y2, y3, y4, y5, y6);
                                    perhapsretract y2 (y1, y3, y4, y5, y6);
                                    perhapsretract y3 (y1, y2, y4, y5, y6);
                                    perhapsretract y4 (y1, y2, y3, y5, y6);
                                    perhapsretract y5 (y1, y2, y3, y4, y6);
                                    perhapsretract y6 (y1, y2, y3, y4, y5)
                                end
                            else ()
                        end
                end
*)                    
        in
            all_phoenixizations
            (fn bombs =>
             let 
(*
                 val () = 
                     print ("bombs: " ^
                            StringUtil.delimit ","
                            (map BW.toString (Vector.foldr op:: nil bombs)) ^ "\n")
                     
*)
             in
                 go bombs UP DOWN;
                 go bombs DOWN UP;
                 go bombs LEFT RIGHT;
                 go bombs RIGHT LEFT
             end)
        end

  fun tostring { guy, bombs } =
    let 
        val FACTOR = 3

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
         "  #" ^
         String.concat
         (List.tabulate
          (width,
           (fn x =>
            let val i = y * width + x
            in
                if i = Word8.toInt guy
                then " G "
                else 
                    (case Vector.find (fn z => z <> bw 0w0 
                                       andalso bomb_pos z = i) bombs of
                         SOME b => 
                             if bomb_cur b = 14
                             then " " ^ Int.toString (bomb_start b) ^ " "
                             else Int.toString (bomb_start b) 
                                   ^ "@" ^ Int.toString (bomb_cur b)
                       | NONE => 
                             case Vector.sub(board, i) of
                                 FLOOR => " . "
                               | WALL => "###")
            end))) ^ "#  ")) @ [topbot])
    end

    fun tocode { guy, bombs } =
        let
            val e = Word8.toInt guy :: 
                (Vector.foldr op:: nil (Vector.map BW.toInt bombs))
        in
            StringUtil.delimit "," (map Int.toString e)
        end

end
