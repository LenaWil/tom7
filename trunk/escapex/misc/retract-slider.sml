(* retracts a board with sliders and 0/1 switches. *)
functor Slider(val filename : string
               val flip_every_move : bool) :> GAME =
struct

    val constant_distance = true

    datatype dir = UP | DOWN | LEFT | RIGHT

    exception Slider of string

    val findshortest = false
    val reverse = true

    datatype color = LR | UD
    datatype parity = Norm | Rev

    datatype bug = GREY (* catch cut'n'paste errors *)

    structure WP = Word7
    structure WP1 = Word8

    (* unpacked states *)
    type ustate = { guy : WP.word,
                    parity : parity,
                    (* Distinct and sorted *)
                    slider : (WP.word * color) Vector.vector } 

    type state = WP1.word Vector.vector

    fun pack { guy, parity, slider } : state =
      let val g =
        WP1.orb(WP1.<< (WP1.fromInt (WP.toInt guy), 0w1),
                case parity of 
                  Norm => 0w0
                | Rev => 0w1)
      in
        Vector.tabulate(Vector.length slider + 1,
                        fn 0 => g
                         | n =>
                        let val (p, c) = Vector.sub(slider, n - 1)
                        in
                          WP1.orb(WP1.<< (WP1.fromInt (WP.toInt p), 0w1),
                                  case c of 
                                    LR => 0w0
                                  | UD => 0w1)
                        end)
      end (* handle Subscript => (TextIO.output (TextIO.stdErr, "pack\n"); raise Subscript) *)

    fun unpack v =
      let
        val g = Vector.sub(v, 0)
      in
        { guy = (WP.fromInt (WP1.toInt (WP1.>> (g, 0w1)))),
          parity = (case WP1.andb (g, 0w1) of
                      0w0 => Norm
                    | _ => Rev),
          slider =
        Vector.tabulate(Vector.length v - 1,
                        fn n =>
                        let val w = Vector.sub(v, n + 1)
                        in
                          (WP.fromInt (WP1.toInt (WP1.>> (w, 0w1))),
                           case WP1.andb(w, 0w1) of
                             0w1 => UD
                           | _ => LR)
                        end) }
      end (* handle Subscript => (TextIO.output (TextIO.stdErr, "unpack\n"); raise Subscript) *)


    fun colorcompare (LR, LR) = EQUAL
      | colorcompare (UD, UD) = EQUAL
      | colorcompare (LR, UD) = LESS
      | colorcompare (UD, LR) = GREATER

    fun flip Norm = Rev
      | flip Rev = Norm

    fun slidercompare ((w1, c1), (w2, c2)) =
      case WP.compare (w1, w2) of
        EQUAL => colorcompare (c1, c2)
      | other => other

    (* must be non-zero *)
    fun colortoint LR = 1
      | colortoint UD = 5

    val xorb = Word32.xorb
    infix xorb
    fun rol (a, w) = Word32.orb(Word32.<<(a, w), Word32.>>(a, 0w32 - w))
    fun hash v =
      Vector.foldl (fn (a, b) => Word32.fromInt (WP1.toInt a) xorb rol(b, 0w21)) 0w1 v

    val eq = op= : state * state -> bool

  datatype cell = WALL | FLOOR | SWAP

  val (width, { guy=initguy, xmark, board, slider=initslider } ) =
    let

      val slider = ref nil

      val f = TextIO.openIn filename

      fun readuntil c =
        case TextIO.input1 f of
          NONE => raise Slider ("eof looking for chr " ^ 
                               Int.toString (ord c))
        | SOME cc => if c = cc then ()
                     else readuntil c

      fun uchar #"#" = WALL
        | uchar #" " = FLOOR
        | uchar #"." = FLOOR
        | uchar #"G" = FLOOR (* guy is on floor *)
        | uchar #"0" = SWAP
        | uchar #"1" = SWAP
        | uchar #"-" = FLOOR (* so are sliders *)
        | uchar #"|" = FLOOR
        | uchar #"?" = FLOOR (* schematic slider *)
        | uchar #"X" = FLOOR (* X marks spot *)
        | uchar c = raise Slider ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      val xmark = ref nil

      (* width, once we figure it out *)
      val w = ref ~1

      val arr = Array.array(16 * 16, FLOOR)
        
      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Slider ("Unexpected EOF: require ^ at end")
         | SOME #"<" => 
             (* end row *)
             let in
               (case !w of
                  ~1 => w := i
                | x  => if x mod !w <> 0 
                        then raise Slider ("Uneven rows")
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
                  (case c of
                     #"G" => g := SOME i
                   | #"-" => slider := (i, SOME LR) :: !slider
                   | #"|" => slider := (i, SOME UD) :: !slider
                   | #"?" => slider := (i, NONE) :: !slider
                   | #"X" => xmark  := i :: !xmark
                   | _ => ());
                  
                  Array.update(arr, i, uchar c);
                  parse (i + 1)
                end)

      val h = parse 0

      val () = if !w * h > (1 + WP.toInt (WP.fromInt ~1))
               then raise Slider ("board too big for " ^ Int.toString WP.wordSize ^ 
                                  " bit positions (increase structure WP size)!")
               else ()
    in
      
      TextIO.closeIn f;
      (!w,
       { guy = 
         (case !g of
            NONE => raise Slider ("There is no guy (G)")
          | SOME i => WP.fromInt i),
         xmark = !xmark,
         slider = ListUtil.mapfirst WP.fromInt (!slider),
         board = Vector.tabulate (!w * h,
                                  (fn i => Array.sub(arr, i))) })
    end handle (e as Slider s) => (TextIO.output (TextIO.stdErr, "parse error: " ^ s ^ "\n");
                                   raise e)


  fun accepting { guy = g, parity, slider } =
    (case xmark of
       (* if there are no X marks, then allow him to start anywhere *)
       nil => true
     | l => List.exists (fn n => WP.toInt g = n) l)

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
  local
    (* return the set of all possible initial siders *)
    fun gi nil = [[]]
      | gi ((p, SOME d) :: rest) = map (fn s => (p, d) :: s) (gi rest)
      | gi ((p, NONE) :: rest) = List.concat (map (fn s => [(p, UD) :: s,
                                                            (p, LR) :: s]) (gi rest))
     
    fun gen_initials () =
      List.concat (map (fn s =>
                        [{ guy = initguy, parity = Norm, slider = Vector.fromList s },
                         { guy = initguy, parity = Rev, slider = Vector.fromList s }]) (gi initslider))

  in
    val initials = gen_initials ()
  end


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
         Slider itself is an argument to
         Search), but not unless I can apply
         functors within loops... *)
      fun shortestpath (src, dest) =
        case Vector.sub(board, src) of
            WALL => width * height + 2
          | SWAP => width * height + 2
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
                                             | SWAP => ()
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

  fun every Norm = if flip_every_move then Rev else Norm
    | every Rev  = if flip_every_move then Norm else Rev

  fun app_successors (f, packedstate : state) =
      let

        val {guy, parity, slider} : ustate = unpack packedstate
        val f = fn (s, d) => f (pack s, d)

        val parity = every parity

        fun slideok parity dir color =
          case (parity, dir, color) of
            (Norm, LEFT, LR) => true
          | (Norm, RIGHT, LR) => true
          | (Norm, UP, UD) => true
          | (Norm, DOWN, UD) => true
          | (Rev,  LEFT, UD) => true
          | (Rev,  RIGHT, UD) => true
          | (Rev,  UP, LR) => true
          | (Rev,  DOWN, LR) => true
          | _ => false

          (* we always move in one of four directions.

             when we do, we might "drag" a slider with us. *)

          val guy = WP.toInt guy

          fun sliderat slider dest =
              (* PERF? could do binary search *)
              (* by invt, there is at most one, so we can return a single
                 example *)
              Vector.findi (fn (_, (x, color)) => x = dest) slider

          fun issliderat slider dest = Option.isSome (sliderat slider dest)

          (* FIXME also swaps *)

          (* retracting a move in direction 'dir'

               <- opp
                -+-+-+-+
                  G X X|
                -+-+-+-+
                  dir->

               retracts to:

                -+-+-+-+        -+-+-+-+
                G   X X|   or   G X   X|
                -+-+-+-+        -+-+-+-+
               

                *)
            fun go bombs dir opp =
                case travel guy opp of
                    NONE => () (* off board *)
                    (* guynew is the new place for the guy 
                       (ie. where was in the retracted state) *)
                  | SOME guynew => 
                let
                    val guynew = WP.fromInt guynew
                    (* here, blocked means that we wouldn't
                       have been able to walk into 'idx' from d. 
                       We also assume we don't ever start
                       on walls or slider. *)
                    val blocked =
                        (* by invariant, we aren't on a wall
                           or slider. is our retracted position
                           on a wall or slider? *)
                        case Vector.sub(board, WP.toInt guynew) of
                            WALL => true
                          | SWAP => true
                          | FLOOR => issliderat slider guynew
                                        
                in
                    if blocked
                    then ()
                    else
                        let 
                        in
                          (* try to drag *)
                          (case travel guy dir of
                             NONE => (* edge of board; fail *) ()
                           | SOME i =>
                               case sliderat slider (WP.fromInt i) of
                                 NONE => (* no slider; fail *) ()
                               | SOME (idx, (_, color)) =>
                                   if slideok parity dir color
                                   then f({guy = guynew, parity = parity,
                                           slider =
                                           Vector.fromList (ListUtil.sort
                                                            slidercompare
                                                            
                                                            (* PERF could do insertion sort *)
                                                            (ListUtil.mapi 
                                                             (fn (a as (_, color), i) =>
                                                              if i = idx
                                                              then (WP.fromInt guy, color)
                                                              else a) 
                                                             (* PERF less allocation *)
                                                             (Vector.foldr (op::) nil slider)))}, 1)
                                   else () (* wrong direction *)
                                     );
                                   
                          (* or don't drag *)
                          f ({guy = guynew, parity = parity, slider = slider}, 1)
                        end
                end

            (* can we "unpress" a button adjacent in direction d? *)
            fun press d =
                case travel guy d of
                    NONE => () (* off board *)
                  | SOME guynew => 
                      case Vector.sub(board, guynew) of
                        WALL => ()
                      | FLOOR => ()
                      | SWAP =>
                          (* nb. pressing a swap in flip_every_move does nothing *)
                          f ({guy = WP.fromInt guy, parity = flip parity, slider = slider}, 1)

        in
          go slider UP DOWN;
          go slider DOWN UP;
          go slider LEFT RIGHT;
          go slider RIGHT LEFT;

          press UP;
          press DOWN;
          press LEFT;
          press RIGHT
        end


  fun tostring { guy, parity, slider } =
    let 
        val FACTOR = 1

        val topbot = 
            CharVector.tabulate(FACTOR - 1, fn _ => #" ") ^ "#" ^
            CharVector.tabulate(FACTOR * width, 
                                         fn x => #"#") ^ "#"
(*        ^ CharVector.tabulate(FACTOR - 1, fn _ => #" ") *)

        fun choose n r =
          case parity of
            Norm => n
          | Rev => r
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
                if i = WP.toInt guy
                then "@"
                else 
                    (case Vector.find (fn (z, _) => z = (WP.fromInt i)) slider of
                         SOME (_, LR) => choose "-" "|"
                       | SOME (_, UD) => choose "|" "-"
                       | NONE => 
                             case Vector.sub(board, i) of
                                 FLOOR => " "
                               | SWAP => choose "0" "1"
                               | WALL => "#")
            end))) ^ "#")) @ [topbot])
    end

    fun tocode { guy, parity, slider } =
        let
            val e = WP.toString guy :: 
                (Vector.foldr op:: nil (Vector.map (fn (p, color) => 
                                                    (case color of 
                                                       LR => "-"
                                                     | UD => "|") ^
                                                    WP.toString p) slider))
        in
          (case parity of 
             Norm => "+"
           | Rev => "-") ^ StringUtil.delimit "" e
        end

    val accepting = accepting o unpack
    val tocode = tocode o unpack
    val tostring = tostring o unpack
    val initials = map pack initials


end
