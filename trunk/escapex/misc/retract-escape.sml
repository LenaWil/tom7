functor Escape(val filename : string) (* :> GAME *) =
struct

  val findshortest = false
  val reverse = true
  fun accepting _ = true

  structure W8 = Word8

  datatype tile = FLOOR | GREEN | BLUE | GREY | 
                  ROUGH | GOLD | EXIT | LASER | 
                  SPHERE | HOLE | TRAP1 | TRAP2

  type state = { guy : W8.word,
                 board : tile Vector.vector }
                 (* could add bots, etc. *)

  val (width, initial) =
    let

      val f = TextIO.openIn filename
        
      fun readuntil c =
        case TextIO.input1 f of
          NONE => raise Parse ("eof looking for chr " ^ 
                               Int.toString (ord c))
        | SOME cc => if c = cc then ()
                     else readuntil c


      fun uchar #"#" = BLUE
        | uchar #" " = FLOOR
        | uchar #":" = ROUGH
        | uchar #"o" = HOLE
        | uchar #"*" = GOLD
        | uchar #"@" = GREY
        | uchar #"E" = EXIT
        | uchar #"%" = GREEN
        | uchar #"1" = TRAP1
        | uchar #"2" = TRAP2
        | uchar #"G" = (* FLOOR *) EXIT (* assuming guy ends on exit *)
        | uchar #"L" = LASER
        | uchar #"O" = SPHERE
        | uchar c = raise Parse ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      (* width, once we figure it out *)
      val w = ref ~1

      val arr = Array.array(16 * 16, FLOOR)
        
      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Parse ("Unexpected EOF: require ^ at end")
         | SOME #"<" => 
             (* end row *)
             let in
               (case !w of
                  ~1 => w := i
                | x  => if x mod !w <> 0 
                        then raise Parse ("Uneven rows")
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
            NONE => raise Parse ("There is no guy (G)")
          | SOME i => Word8.fromInt i),
         board = Vector.tabulate (!w * h,
                                  (fn i => Array.sub(arr, i))) })
    end handle (e as Parse s) => (TextIO.output (TextIO.stdErr, "parse error: " ^ s ^ "\n");
                                  raise e)

  val initials = [initial]

  val rols = Vector.fromList [0w3, 0w5, 0w7, 0w11, 0w13, 0w17, 0w19, 0w23 : Word.word]
      
  fun hash { guy, board } = (* Word32.fromInt (W8.toInt guy) *)
    let 
      fun tw FLOOR  = 0wx11335577
        | tw GREEN  = 0wx98765432
        | tw BLUE   = 0wxFFAACCDD
        | tw GREY   = 0wx73737373
        | tw ROUGH  = 0wx18274799
        | tw GOLD   = 0wxA0C2B3D9
        | tw EXIT   = 0wx3F7F5A90
        | tw LASER  = 0wx789ABCDE
        | tw SPHERE = 0wx90210CC3
        | tw HOLE   = 0wx20386711
        | tw TRAP1  = 0wxabcd3021
        | tw TRAP2  = 0wx88771317

      val s = Vector.length board
        
      fun rol (w, n) = Word32.orb(Word32.<< (w, n),
                                  Word32.>> (w, 0w32 - n))

      val t = 0wx00000000
      val i = Word8.toInt guy

      fun go (t, _) 0 = t
        | go (t, i) n =
        let
          val b = tw (Vector.sub(board,(i+Word32.toInt(Word32.andb(t,0wxFFFFFF))) mod s))
          val t = Word32.xorb(rol(t, Vector.sub(rols, i mod 8)), b)
          val i = i + 1
        in
          go (t, i) (n - 1)
        end
    in
      (* higher number of iterations gives better quality hash,
         but this whole thing is pointless if n gets on the order of
         the size of the board. *)
      Word32.xorb(Word32.fromInt i,
                  go (t, i) 24)
    end


  (* consider boards equal if they're both winning,
     to avoid cooks (XXX correct??) *)
(*
  fun eq (l1 as { guy = g1, board = b1 },
          l2 as { guy = g2, board = b2 }) =
      case Vector.sub(b1, W8.toInt g1) of
          EXIT => (case Vector.sub(b2, W8.toInt g2) of
                       EXIT => true
                     | _ => false)
        | _ => l1 = l2
*)

  val eq = op =


  (* here we are really retracting. *)
  fun app_successors (f, { guy, board }) =
    let

      fun index (x, y) = y * width + x
      fun windex (x, y) = W8.fromInt (index (x, y))
      fun whereis i = (i mod width, i div width)
      fun boardat (x, y) = Vector.sub(board, index(x, y))

      (* PERF hoist *)
      val height = Vector.length board div width

      datatype dir = Up | Down | Left | Right

      fun opp Up = Down
        | opp Down = Up
        | opp Left = Right
        | opp Right = Left

      fun travel Up (_, 0) = NONE
        | travel Up (x, y) = SOME (x, y - 1)
        | travel Down (x, y) = if y < (height - 1)
                               then SOME (x, y + 1)
                               else NONE
        | travel Left (0, y) = NONE
        | travel Left (x, y) = SOME (x - 1, y)
        | travel Right (x, y) = if x < (width - 1)
                                then SOME (x + 1, y)
                                else NONE
        
      val (gx, gy) = whereis (Word8.toInt guy)


      fun canwalkonto FLOOR = true
        | canwalkonto EXIT = true
        | canwalkonto ROUGH = true
        | canwalkonto TRAP1 = true
        | canwalkonto TRAP2 = true
        | canwalkonto _ = false

      fun canblockon FLOOR = true
        | canblockon _ = false

      fun istrappable HOLE = true
        | istrappable TRAP1 = true
        | istrappable _ = false

      (* currently, 
         player can only have moved in one of four directions,
         perhaps pulling a block with him.

         TODO: 
          * teleports to this spot,
          * adjacent buttons
          * retract gold/sphere
         *)
      fun move dir =
          if canwalkonto (boardat (gx, gy))
          then
              (case travel dir (gx, gy) of
                   SOME (nx, ny) =>
                       let 

                           val bpos = index (gx, gy)
                           val gpos = index (nx, ny)

                           val boardwalk =
                               if istrappable (boardat (nx, ny))
                               then
                                   Vector.tabulate
                                   (Vector.length board,
                                    fn i =>
                                    if i = gpos
                                    then 
                                        (case boardat (nx, ny) of
                                             HOLE => TRAP1
                                           | _ => TRAP2)
                                    else Vector.sub(board, i))
                               else board
                       in
                           (* well, then we can walk that way... *)
                           f ({ guy = windex (nx, ny),
                                board = boardwalk }, 1);

                           (* also maybe pull a block *)
                           if canblockon (boardat(gx, gy)) then
                              case Option.map boardat (travel (opp dir) (gx, gy)) of
                                  (* off board? *)
                                  NONE => ()
                                | SOME GREY =>
                                      let
                                          (* can't fail since we did this above. *)
                                          val opos = index (valOf (travel (opp dir) (gx, gy)))
                                      in
                                          f({ guy = windex (nx, ny),
                                              board =
                                              Vector.tabulate 
                                              (Vector.length board,
                                               (fn i =>
                                                if i = opos then FLOOR
                                                else if i = bpos then GREY
                                                     else Vector.sub(boardwalk, i))) }, 
                                            1)
                                      end
                                | SOME FLOOR =>
                                      (* can pull a block/hole combo out *)
                                      let
                                          
                                          (* old
                                             
                                             --P--
                                             
                                             new
                                             
                                             -P@o-  *)

                                          (* can't fail since we did this above. *)
                                          val opos = index (valOf (travel (opp dir) (gx, gy)))
                                      in
                                          f({ guy = windex (nx, ny),
                                              board =
                                              Vector.tabulate
                                              (Vector.length board,
                                               (fn i =>
                                                if i = opos then HOLE
                                                else if i = bpos then GREY
                                                     else Vector.sub(boardwalk, i))) }, 1)
                                      end
                                (* could phoenixize blocks out of floor (w/hole), 
                                   electricity *)
                                | _ => ()
                           else ()

                       end
                 (* edge of board... *)
                 | NONE => ())
          (* can't move that dir! *)
          else ()

    in
        (* basically, the only moves are the four cardinal
           directions. *)
        move Up;
        move Down;
        move Left;
        move Right
    end

  fun tostring {guy, board} =
    let 
      val topbot = CharVector.tabulate(width + 2, fn _ => #"#")
    in
    StringUtil.delimit "\n"
    (topbot ::
     List.tabulate
     (Vector.length board div width,
      (fn y =>
       "#" ^
       CharVector.tabulate
       (width,
        (fn x =>
         let val i = y * width + x
         in
           if i = Word8.toInt guy
           then #"G"
           else 
             case Vector.sub(board, i) of
               BLUE => #"#"
             | ROUGH => #":"
             | FLOOR => #" "
             | HOLE => #"o"
             | GREY => #"@"
             | GOLD => #"*"
             | EXIT => #"E"
             | GREEN => #"%"
             | LASER => #"L"
             | SPHERE => #"O"
             | TRAP1 => #"1"
             | TRAP2 => #"2"
         end)) ^ "#")) @ [topbot])
    end

  (* no sensible code here... *)
  fun tocode s = Word32.toString (hash s)

end

