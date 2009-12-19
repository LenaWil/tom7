(* Retracts a board with some hugbots on it, and some blocks in it.
   
   This is a bit complex for a number of reasons.
   First, when there are bots, there are distinct "turns"
   within a "motion". We normally think of retraction steps
   as being motions, but here we should really think of them
   as turns, for simplicity.
   
   Then, there are several kinds of turns: Player turns
   (he can move any way he likes) or Hugbot turns (it can
   move only by following the hugbot rules). Additionally,
   any kind of entity can be pushed by an entity that
   moves before it (but here, since we are retracting, we
   will see that move later, as we advance backwards).

   So, suppose we have

     .#..
     .12.
     .p3.
     ....

   Where p is the player (moves first in the forward direction),
   and then the bots in their forward move order 1, 2, 3.

   When retracting, we first consider bot 3. He could have
   gotten there by walking 

     .#..
     .12.
     .p.3
     ....

   (but not from the south; hugbots prefer horizontal movement)
   or by being pushed by bot 2

     .#2.
     .13.
     .p..
     ....
   
   but that's probably the wrong way to think of it. We're only
   considering 3's motion, here. From the perspective of his motion,
   every other entity just acts like a pushable block.
   So 3 might have walked, and he might have pushed the player,
   and that's it:

     .#..    .#..
     .12.    .12.
     .p.3    ..p3
     ....    ....

   From there, we consider how 2 may have moved (let's extend the
   second possibility above). We know where the player is, but this
   time he could have come from either direction:

     .#2.     .#..
     .1..     .1.2
     ..p3     ..p3
     ....     ....

   and either way he could have additionally been pushing:

     .#2.     .#..
     .1p.     ..12
     ...3     ..p3
     ....     ....

*)
functor Hugblock(val permute : bool
                 val nbots : int
                 val nblocks : int
                 structure BW : WORD
                 structure F : FIXEDWORDVEC where type word = BW.word
                 val filename : string) :> 
sig 
    include GAME
end =
struct

  datatype dir = UP | DOWN | LEFT | RIGHT | STAY

  exception Hugblock of string

  val findshortest = false
  val reverse = true
  val constant_distance = true

  (* now we assume these as arguments *)
  (* must agree in bits per word *)
  (* structure BW = Word5 *)
  (* BW bits per word, six words *)
  (* structure F = FixedWordVec_5_8 *)
  type state = F.vector

  (* turn number, 
     player position,
     hugbot positions (nbots),
     block positions (sorted lowest->highest) *)
  (* type state = int * BW.word vector *) 
  fun state_turn v = BW.toInt (F.sub(v, 0))
  fun state_pos (v, n) = F.sub(v, n + 1)
  fun state_bot (v, n) = F.sub(v, n + 2)
  fun state_block (v, n) = F.sub(v, n + nbots + 2)

  (* doesn't sort blocks. you have to do it yourself! *)
  fun state_tabulate (turn : int, 
                      guy : BW.word,
                      botf : int -> BW.word,
                      blockf : int -> BW.word) =
      F.tabulate (nbots + nblocks + 2,
                  fn 0 => BW.fromInt turn 
                   | 1 => guy
                   | n => if n < (nbots + 2)
                          then botf (n - 2)
                          else blockf (n - nbots - 2))

  fun state_tabulate_ent (turn : int, 
                          entf : int -> BW.word,
                          blockf : int -> BW.word) =
      let val f =
      F.tabulate (nbots + nblocks + 2,
                  fn 0 => BW.fromInt turn 
                   | n => if n < (nbots + 2)
                          then ((* print ("entf " ^ Int.toString (n - 1) ^ "\n"); *)
                                entf (n - 1))
                          else ((* print ("blockf " ^ Int.toString (n - nbots - 2) ^ "\n"); *)
                                blockf (n - nbots - 2)))
      in
          (* print "Tabok\n"; *)
          f
      end

  fun state_fromlist (turn, l) = F.fromList (BW.fromInt turn :: l)

  (* any starting position is okay, but it has to be the guy's turn. *) 
  fun accepting state = state_turn state = 0

  val xorb = Word32.xorb
  infix xorb
  fun rol (a, w) = Word32.orb(Word32.<<(a, w), Word32.>>(a, 0w32 - w))
  (* PERF this ought to be in the fixedwordvec implementation
     where it would be a lot cheaper *)
  fun hash state =
     F.foldr (fn (a, b) => Word32.fromInt (BW.toInt a) xorb rol(b, 0w11))
               0w12345
             state

  val eq = op= : state * state -> bool

  (* EXIT is not the same as floor here, because although bots and players
     can walk on it, they cannot push onto it *)
  datatype cell = WALL | FLOOR | EXIT

  (* other kinds of "bots" (like dead bots) would be easy to
     support; daleks not so easy... *)
  datatype bot = PLAYER | HUGBOT

  fun botkind 0 = PLAYER
    | botkind i = HUGBOT

  fun parseboard filename =
    let

      val f = TextIO.openIn filename

      fun readuntil c =
        case TextIO.input1 f of
          NONE => raise Hugblock ("eof looking for chr " ^ 
                               Int.toString (ord c))
        | SOME cc => if c = cc then ()
                     else readuntil c

      (* XXX some way to place bombs too? *)
      fun uchar #"#" = WALL
        | uchar #" " = FLOOR
        | uchar #"." = FLOOR
        | uchar #"-" = FLOOR
        | uchar #"D" = FLOOR (* dead bots on floors *)
        | uchar #"G" = FLOOR (* guy is on floor unless described by *)
        | uchar #"X" = EXIT  (* an X *)
        | uchar c = 
          if ord c >= ord #"0" andalso ord c <= ord #"9"
          then FLOOR (* bots start on floor *)
          else raise Hugblock ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      (* width, once we figure it out *)
      val w = ref ~1

      (* turn, if given *)
      val t = ref 0

      val arr = Array.array(16 * 16, FLOOR)
      val bots = Array.array(16, NONE)
      val deads = ref nil

      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Hugblock ("Unexpected EOF: require ^ at end")
         | SOME #"!" =>
             let 
                 val c = case TextIO.input1 f of
                              NONE => raise Hugblock "EOF after !"
                            | SOME c => c
             in
                 if ord c >= ord #"0"
                 andalso ord c <= ord #"9"
                 then t := (ord c - ord #"0")
                 else raise Hugblock "need turn number after !";
                 readuntil #"\n";
                 parse i
             end
         | SOME #"<" => 
             (* end row *)
             let in
               (case !w of
                  ~1 => w := i
                | x  => if x mod !w <> 0 
                        then raise Hugblock ("Uneven rows")
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
                  if c = #"D"
                  then deads := i :: !deads
                  else ();
                  if c = #"G" orelse c = #"X"
                  then g := SOME i
                  else ();
                  if ord c >= ord #"0" 
                     andalso
                     ord c <= ord #"9"
                  then
                      let val b = ord c - ord #"0"
                      in
                          Array.update(bots, b, SOME i)
                      end
                  else ();
                  Array.update(arr, i, uchar c);
                  parse (i + 1)
                end)

      val h = parse 0

      val nhug =
          let fun f n = 
              case Array.sub(bots, n) of
                  NONE => n
                | SOME _ => f (n + 1)
          in
              f 0
          end

      val startbots =
          Vector.tabulate(nhug, fn i => BW.fromInt (valOf (Array.sub(bots, i))))

      val startdead = ListUtil.sort BW.compare (map BW.fromInt (!deads))
    in
        if length (!deads) <> nblocks
        then raise Hugblock ("expected " ^ Int.toString nblocks ^ " blocks")
        else ();

        if nhug <> nbots
        then raise Hugblock ("expected " ^ Int.toString nbots ^ " bots")
        else ();

      TextIO.closeIn f;
      { width = !w,
        initturn = !t,
        initguy = 
        (case !g of
           NONE => raise Hugblock ("There is no guy (G)")
         | SOME i => BW.fromInt i),
        inithug = startbots,
        initblock = Vector.fromList startdead,
        board = Vector.tabulate (!w * h,
                                 (fn i => Array.sub(arr, i))) }
    end handle (e as Hugblock s) => (print ("parse error: " ^ s ^ "\n");
                                  raise e)

  val { width, initturn, initguy, inithug, initblock, board } =
      parseboard filename

  val () = print ("There are " ^ Int.toString nbots ^ " hugbots and "^
                  Int.toString nblocks ^ " blocks.\n");

  val height = Vector.length board div width

  fun travel i UP =    if i >= width 
                       then SOME (i - width)
                       else NONE
    | travel i DOWN =  if i < ((height * width) - width) 
                       then SOME (i + width)
                       else NONE
    | travel i LEFT =  if i mod width <> 0
                       then SOME (i - 1)
                       else NONE
    | travel i RIGHT = if i mod width <> (width - 1)
                       then SOME (i + 1)
                       else NONE
    | travel i STAY =  SOME i

  fun coords i = (i mod width, i div width)
  fun index (x, y) = x + y * width

  (* the initial state is where the guy is on the exit,
     and it his his turn again because all the bots have moved. *)
  val initials = 
      if permute 
      then
          let in
                  map (fn l => 
                       let val v = Vector.fromList l
                       in
                           state_tabulate
                           (initturn,
                            initguy,
                            fn n => Vector.sub(v, n),
                            fn n => Vector.sub(initblock, n))
                       end) (ListUtil.permutations (Vector.foldr op:: nil inithug))
          end
      else [state_tabulate (initturn,
                            initguy,
                            fn n => Vector.sub(inithug, n),
                            fn n => Vector.sub(initblock, n))]

  datatype what =
      ENT of int
    | BLOCK of int
    | NOTHING

  fun app_successors (f, state) =
      let

          (* val () = print "APP.succ\n" *)

          val turn = state_turn state

          (* since in the end state it is turn's turn,
             for this retraction it will be the preceding
             entity's turn. It's never a block's turn, though. *)
          val moving = (turn - 1) mod (nbots + 1)
          val loc = BW.toInt (state_pos(state, moving))
          val what = botkind moving

          (* val () = print ("(moving : " ^ Int.toString moving ^ ")\n") *)

          fun isobjat p =
              let val p = BW.fromInt p

                  fun ex i =
                      if i = F.length state
                      then false
                      else F.sub(state, i) = p orelse ex (i + 1)
              in 
                  (* skip turn, which is not an object *)
                  ex 1
              end

          fun getentat p =
              let val p = BW.fromInt p
                  fun findl ~1 = NOTHING
                    | findl i =
                      if state_block(state, i) = p
                      then BLOCK i
                      else findl (i - 1)
                  fun findb ~1 = findl (nblocks - 1)
                    | findb i =
                      if state_pos(state, i) = p
                      then ENT i
                      else findb (i - 1)
              in 
                  (* including the player... *)
                  findb nbots
              end

          (* The only way that players and bots differ is which
             moves they will consider. The player can retract
             in any direction (but may never stand still), as 
             usual.

             Hugbots usually move horizontally towards the
             player. So, if we are looking at the post-move
             state:

              DDDDACCCC
              DDDDACCCC
              DDDDpCCCC
              DDDDBCCCC
              DDDDBCCCC

              Then a hugbot in A got there by walking LEFT,
              RIGHT, or DOWN. One in B got there by walking
              LEFT, RIGHT, or UP. Hugbots in D or C can only
              get there by walking RIGHT and LEFT respectively.

              This assumes there are no other bots or blocks
              in play, however. Within the regions A and B,
              the bot still has all of the retractions available
              to him. However, if he is currently in a position
              where he is blocked (for example, in the region A
              with two bots below him) then he can retract STAY.
              
              (of course, the normal restrictions on where we
               can retract from--like the requirement that the
               source square be empty--still apply)

              A bot in D or C might be able to move UP or DOWN
              or STAY as well. Specifically, we further divide
              the regions to

              GGGGAFFFF
              GGGGAFFFF
              IIIIpJJJJ
              HHHHBEEEE
              HHHHBEEEE
              
              Within I and J, the bot can only move towards the player
              or STAY. Within E, the bot got there by walking LEFT, or
              by STAY (if blocked to the left) or by UP (if blocked to
              the left in the space below its current position.

              (We might think this is a bit more complicated because
               the quadrant that we're in depends on where the player
               was *before* moving, and we might push him, but pushing
               will never change the quadrant.)

              So, the following function is apropos:
             *)

          (* is the moving hugbot blocked (assuming it was at the position
             given) from moving in the direction given? *)
          fun blocked pos dir =
              let 
                  fun blocked1 pos =
                      case travel pos dir of
                          (* edge of level is like wall *)
                          NONE => true
                        | SOME p' =>
                              case Vector.sub(board, p') of
                                  (* can't push a bot into an exit *)
                                  EXIT => true
                                (* or wall, naturally *)
                                | WALL => true
                                (* or another entity *)
                                | FLOOR => isobjat p'
              in
                  case travel pos dir of
                      NONE => true
                    | SOME p' => 
                          (* blocked if it's a wall... *)
                          case Vector.sub(board, p') of
                              WALL => true
                            (* can't push entity OFF an exit, either *)
                            | EXIT => isobjat p'
                            | _ => isobjat p' andalso blocked1 p'
              end

          (* then this function is the same for any kind of
             entity.
             we're retracting a move in direction 'dir':

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

            (* staying is easy.. *)
            fun go STAY _ = 
                let in
                    (* print "STAY.\n"; *)
                    f (state_tabulate(moving,
                                      state_pos(state, 0),
                                      fn i => state_bot(state, i),
                                      fn i => state_block(state, i)), 1)
                end
              | go dir opp =
                case travel loc opp of
                    NONE => () (* off board *)
                    (* locnew is the new place for the entity
                       (ie. where he was in the retracted state) *)
                  | SOME locnew => 
                let
                    (* would we have been able to walk here?
                       we can't come from atop a wall or
                       other entity *)
                    val can't =
                        case Vector.sub(board, locnew) of
                            WALL => true
                          | _ => isobjat locnew

                in
                    if can't
                    then ()
                    else
                        let in
                            (* walking without pushing is always an option: *)
                            (* print "NOpush\n"; *)
                            f(state_tabulate_ent(moving,
                                                 fn i => 
                                                 if i = moving
                                                 then BW.fromInt locnew
                                                 else state_pos(state, i),
                                                 fn i => state_block(state, i)), 1);

                            (* print "TRYpush\n"; *)
                            (* also try pulling an entity, if possible: *)
                            case travel loc dir of
                                NONE => () (* nothing over here; edge *)
                              | SOME ei =>
                                    case getentat ei of
                                        NOTHING => () (* no ent: no retract *)
                                      | ENT idx =>
                                            let in
                                                (* print "yesbot\n"; *)
                                            f(state_tabulate_ent
                                              (moving,
                                               fn i =>
                                               if i = moving
                                               then BW.fromInt locnew
                                               else if i = idx
                                                    (* pull it into our spot *)
                                                    then BW.fromInt loc 
                                                    else state_pos(state, i),
                                               fn i => state_block(state, i)),
                                              1)
                                            end
                                      | BLOCK idx =>
                                        let
                                            (* val () = print "yesblock\n" *)
                                            (* PERF should do insertion sort *)
                                            val l = 
                                                List.tabulate(nblocks,
                                                              fn i =>
                                                              if i = idx
                                                              then BW.fromInt loc
                                                              else state_block(state, i))
                                            val l = ListUtil.sort BW.compare l
                                            val l = Vector.fromList l
                                        in
                                            f(state_tabulate_ent
                                              (moving,
                                               fn i =>
                                               if i = moving
                                               then BW.fromInt locnew
                                               else state_pos(state, i),
                                               fn i => Vector.sub(l, i)),
                                              1)
                                        end
                        end
                end

        in
            (* print "WH?\n"; *)
            (case what of
                PLAYER =>
                    let in
                        go UP DOWN;
                        go DOWN UP;
                        go LEFT RIGHT;
                        go RIGHT LEFT
                    end
              (* PERF correct, but wasteful to consider this a turn!
                 when we reach nhugs, we should just wrap the turn
                 counter... *)
              (* | DEAD => go STAY STAY *)
              | HUGBOT => 
                    (* where am I compared to the player, then? *)
                    let
                        (* val () = print "HB\n"; *)
                        val (hx, hy) = coords loc
                        val (px, py) = coords (BW.toInt (state_pos(state, 0)))

                        (* when we choose to go vertically instead of
                           horizontally, it's because we were blocked
                           where we *were*, not where we *are*. Given
                           the direction that 'were' is in, tell us
                           if we were blocked in the other supplied direction *)
                        fun blockedby dispdir dir =
                            case travel loc dispdir of
                                NONE => false (* ? not blocked; can't be there! *)
                              | SOME loc' => blocked loc' dir
                    in
                        (*
                          GGGGAFFFF
                          GGGGAFFFF
                          IIIIpJJJJ
                          HHHHBEEEE
                          HHHHBEEEE
                        *)
                        case (Int.compare (hx, px),
                              Int.compare (hy, py)) of
                            (LESS, LESS) => (* G *)
                                let in
                                    (* tend to go right, but if blocked,
                                       consider vertical travel *)
                                    go RIGHT LEFT;
                                    (* would we have been able to travel
                                       right if we were up one space? *)
                                    if blockedby UP RIGHT
                                    then go DOWN UP
                                    else ();
                                    (* we can stay still but we have to
                                       be doubly blocked *)
                                    if blocked loc RIGHT andalso
                                       blocked loc DOWN
                                    then go STAY STAY
                                    else ()
                                end
                          | (LESS, GREATER) => (* H *)
                                let in
                                    go RIGHT LEFT;
                                    if blockedby DOWN RIGHT
                                    then go UP DOWN
                                    else ();
                                    if blocked loc RIGHT andalso
                                       blocked loc UP
                                    then go STAY STAY
                                    else ()
                                end
                          | (GREATER, LESS) => (* F *)
                                let in
                                    go LEFT RIGHT;
                                    if blockedby UP LEFT
                                    then go DOWN UP
                                    else ();
                                    if blocked loc LEFT andalso
                                       blocked loc DOWN
                                    then go STAY STAY
                                    else ()
                                end
                          | (GREATER, GREATER) => (* E *)
                                let in
                                    go LEFT RIGHT;
                                    if blockedby DOWN LEFT
                                    then go UP DOWN
                                    else ();
                                    if blocked loc LEFT andalso
                                       blocked loc UP
                                    then go STAY STAY
                                    else ()
                                end
                          | (EQUAL, LESS) => (* A *)
                                let in
                                    (* lots of ways to get in this column *)
                                    go DOWN UP;
                                    go LEFT RIGHT;
                                    go RIGHT LEFT;
                                    if blocked loc DOWN
                                    then go STAY STAY
                                    else ()
                                end
                          | (EQUAL, GREATER) => (* B *)
                                let in
                                    go UP DOWN;
                                    go LEFT RIGHT;
                                    go RIGHT LEFT;
                                    if blocked loc UP
                                    then go STAY STAY
                                    else ()
                                end
                          | (LESS, EQUAL) => (* I *)
                                let in
                                    (* here, either walk towards the player
                                       or be blocked. Additionally: we can
                                       walk vertically into this row if blocked
                                       above or below *)
                                    go RIGHT LEFT;
                                    if blocked loc RIGHT
                                    then go STAY STAY
                                    else ();
                                    if blockedby UP RIGHT
                                    then go DOWN UP
                                    else ();
                                    if blockedby DOWN RIGHT
                                    then go UP DOWN
                                    else ()
                                end
                          | (GREATER, EQUAL) => (* J *)
                                let in
                                    go LEFT RIGHT;
                                    if blocked loc LEFT
                                    then go STAY STAY
                                    else ();
                                    if blockedby UP LEFT
                                    then go DOWN UP
                                    else ();
                                    if blockedby DOWN LEFT
                                    then go UP DOWN
                                    else ()
                                end
                          | (EQUAL, EQUAL) => raise Hugblock "impossible--on player!"
                    end)
        end

  fun tostring state =
    let 
        val FACTOR = 1

        val topbot = 
            CharVector.tabulate(FACTOR - 1, fn _ => #" ") ^ "#" ^
            CharVector.tabulate(FACTOR * width, 
                                         fn x => #"#") ^ "#"
(*        ^ CharVector.tabulate(FACTOR - 1, fn _ => #" ") *)
    in
      StringUtil.delimit "\n"
      ("Turn: " ^ Int.toString (state_turn state) ::
       topbot ::
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
                (* ignore the turn, it is not an ent *)
                case F.findi (fn (0, z) => false | (_, z) => BW.toInt z = i) state of
                    SOME (1, _) => "G"
                  | SOME (b, _) => if b < (nbots + 2) 
                                   then Int.toString (b - 2)
                                   else "D"
                  | NONE => 
                        case Vector.sub(board, i) of
                            FLOOR => "."
                          | EXIT => "X"
                          | WALL => "#"
            end))) ^ "#")) @ [topbot])
    end

    fun tocode state =
        let
            val e = map BW.toString (F.foldr op:: nil state)
        in
            StringUtil.delimit "," e
        end

(*
    val () = app (fn s => print (tostring s ^ "\n\n")) initials
    val () = raise Hugblock "FIXME"
*)

end
