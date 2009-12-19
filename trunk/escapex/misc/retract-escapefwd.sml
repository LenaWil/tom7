
(* "Forward" with (subset of) standard escape rules.
   Here we are not making a determination of "interesting"
   vs "uninteresting" features of the level, so a state is
   an actual board---this means that in practice we are limited
   to much smaller boards. (but we can generate much more interesting
   levels!) *)

(* Boards are limited to 16x16, but they can be cut short
   so that we don't have to allocate useless parts of the level. *)

functor EscapeFwd(val filename : string
                  (* if provided, require that the board be exactly
                     this in order to succeed *)
                  val finalname : string option) (* :> GAME *) =
struct

  exception Parse of string

  val findshortest = true
  val reverse = false

  datatype tile = FLOOR | GREEN | BLUE | GREY | ROUGH | GOLD | EXIT | LASER
                | SPHERE | STEEL

  type state = { guy : Word8.word,
                 board : tile Vector.vector }
                 (* could add bots, etc. *)

  val hintlegal : ({ guy : Word8.word,
                     board : tile Vector.vector } -> bool) ref = ref (fn _ => true)

  datatype dir = Up | Down | Left | Right
  datatype hint = PUSH of dir | NOGUY

  val rols = Vector.fromList [0w3, 0w5, 0w7, 0w11, 0w13, 0w17, 0w19, 0w23 : Word.word]

  (* this doesn't even depend on the whole board,
     since hashing would be very expensive *)
  fun hash { guy, board } =
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
        | tw STEEL  = 0wx3151719F

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

  val eq = op=

  fun doparse filename =
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
        | uchar #"." = FLOOR
        | uchar #":" = ROUGH
        | uchar #"*" = GOLD
        | uchar #"@" = GREY
        | uchar #"E" = EXIT
        | uchar #"%" = GREEN
        | uchar #"G" = FLOOR
        (* directional hints are also floor *)
        | uchar #">" = FLOOR
        | uchar #"<" = FLOOR
        | uchar #"^" = FLOOR
        | uchar #"v" = FLOOR
        | uchar #"x" = FLOOR

        | uchar #"L" = LASER
        | uchar #"O" = SPHERE
        | uchar #"S" = STEEL
        | uchar c = raise Parse ("Unexpected char: " ^ Char.toString c)

      val g = ref NONE

      (* width, once we figure it out *)
      val w = ref ~1

      val arr = Array.array(16 * 16, FLOOR)

      val hs = Array.array(16 * 16, NONE)
        
      fun parse i =
        (case TextIO.input1 f of
           NONE => raise Parse ("Unexpected EOF: require ^ at end")
         | SOME #"!" => 
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
         | SOME #"~" =>
             (* end everything *)
             let in
               (* height *)
               i div !w
             end
         | SOME c => 
                let in
                  (* special actions *)
                  (case c of 
                     #"G" => g := SOME i
                   | #">" => Array.update(hs, i, SOME (PUSH Right))
                   | #"<" => Array.update(hs, i, SOME (PUSH Left))
                   | #"v" => Array.update(hs, i, SOME (PUSH Down))
                   | #"^" => Array.update(hs, i, SOME (PUSH Up))
                   | #"x" => Array.update(hs, i, SOME NOGUY)
                   | _ => ());

                  Array.update(arr, i, uchar c);
                  parse (i + 1)
                end)
             
      val h = parse 0
    in
      
      TextIO.closeIn f;
      (!w,
       hs,
       { guy = 
         (case !g of
            NONE => raise Parse ("There is no guy (G)")
          | SOME i => Word8.fromInt i),
         board = Vector.tabulate (!w * h,
                                  (fn i => Array.sub(arr, i))) })
    end handle (e as Parse s) => (print ("parse error: " ^ s ^ "\n");
                                  raise e)


  val (width, hints, initial) = doparse filename

  val lasers = Vector.exists (fn LASER => true | _ => false) (#board initial)

  val () = if lasers 
           then TextIO.output(TextIO.stdErr, "LASERS!\n")
           else TextIO.output(TextIO.stdErr, "laser-free!\n")

  val accepting =
    let
      (* if no final pos, then just let him be on an exit *)
      fun onexit { guy, board } =
        let val gi = Word8.toInt guy
        in
          case Vector.sub(board, gi) of
            EXIT => true
          | _ => false
        end

    in
      case finalname of
        NONE => onexit
      | SOME f => 
          let val (ww, _, fi) = doparse f
          in
            if ww <> width then raise Parse "boards are different widths!"
            (* PERF maybe check hash first?? *)
            else (fn state => state = fi)
          end
    end handle (e as Parse s) => (print ("(final) parse error: " ^ s ^ "\n");
                                  raise e)


  val COST_WALK = 1
  val COST_GREY = 1
  val COST_GOLD = 1
  val COST_STEEL = 1
  val constant_distance = true

  fun index (x, y) = y * width + x
  fun whereis i = (i mod width, i div width)

  fun app_successors (f, { guy, board }) =
    let

      fun boardat (x, y) = Vector.sub(board, index(x, y))
      fun hintat (x, y) = Array.sub(hints, index(x, y))

      val height = Vector.length board div width

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

      (* only call f if the resulting board does not kill
         the player, and hint does not forbid it *)
      val f = 
        (* nb, now working with new board and guy, so
           be careful *)
        (fn stuff as (lev as { guy, board }, cost) =>
         let
           (* short-circuit this if there are no lasers *)
           fun dead d =
             if lasers 
             then 
               let
                 fun de (x, y) =
                   case travel d (x, y) of
                     NONE => false
                   | SOME (nx, ny) => 
                       (case Vector.sub(board, index(nx, ny)) of
                          LASER => true
                        | FLOOR => de (nx, ny)
                        | ROUGH => de (nx, ny)
                        (* anything else blocks laser *)
                        | _ => false) 
                          
                 val (x, y) = whereis (Word8.toInt guy)
               in
                 de (x, y)
               end
             else false
         in
           if dead Up orelse
              dead Down orelse
              dead Left orelse
              dead Right orelse
              hintat (whereis (Word8.toInt guy)) = SOME NOGUY orelse
              not ((!hintlegal) lev)
           then ()
           else f stuff
         end)

      (* XXX parameterize cost *)
      fun walk (tx, ty) =
        (* can walk there *)
        f ({ guy = Word8.fromInt (index (tx, ty)), 
             board = board }, COST_WALK)

      fun move f d =
        case travel d (gx, gy) of
          NONE => () (* edge of level *)
        | SOME (tx, ty) => 
            (case boardat (tx, ty) of
               FLOOR => walk (tx, ty)
             | EXIT => walk (tx, ty)
             | ROUGH => walk (tx, ty)

             (* look forward, eating as many
                steels as possible, until we
                see a floor.
                
                then dest becomes floor,
                and every tile up to and including
                that last floor becomes steel. *)
             | STEEL =>
                 let
                   fun findfloor (x, y) l =
                     case travel d (x, y) of
                       NONE => ()
                     | SOME r =>
                         let val l = (index r) :: l
                             val dst = index (tx, ty)
                         in
                           (case boardat r of
                              FLOOR =>
                                f ({ guy = Word8.fromInt dst,
                                     board =
                                     Vector.tabulate
                                     (Vector.length board,
                                      fn i =>
                                      if i = dst then FLOOR
                                      else 
                                        if List.exists (fn z => z = i) l
                                        then STEEL
                                        else Vector.sub(board, i)) },
                                   COST_STEEL)
                            | STEEL => findfloor r l
                            | _ => ())
                         end
                 in
                   findfloor (tx, ty) nil
                 end
                   
             (* XXX sphere *)
             | GOLD =>
                 let
                   fun going (x, y) =
                     case travel d (x, y) of
                       NONE => (x, y)
                     | SOME r => 
                         (case boardat r of
                            FLOOR => going r
                          | _ => (x, y))

                   val (fx, fy) = going (tx, ty)

                   val dst = index (fx, fy)
                   val src = index (tx, ty)
                 in
                   if dst = src
                   then ()
                   else
                     (* slide *)
                     f ({ guy = guy,
                          board =
                          Vector.tabulate
                          (Vector.length board,
                           (fn i =>
                            if i = src then FLOOR
                            else if i = dst then GOLD
                                 else Vector.sub(board, i))) },
                        COST_GOLD)
                 end
             | GREY => 
             (* push only if dest is floor *)
                 (case travel d (tx, ty) of
                    NONE => ()
                  | SOME (dx, dy) =>
                      let 
                        val src = index (tx, ty)
                        val dst = index (dx, dy)
                      in
                        if boardat (dx, dy) = FLOOR
                        then
                          (* push *)
                          f ({ guy = Word8.fromInt (index (tx, ty)),
                               board = 
                               Vector.tabulate 
                               (Vector.length board,
                                (fn i =>
                                 if i = src then FLOOR
                                 else if i = dst then GREY
                                      else Vector.sub(board, i))) }, 
                             COST_GREY)
                        else ()
                      end)

             | GREEN => 
             (* like grey, but becomes blue *)
                 (case travel d (tx, ty) of
                    NONE => ()
                  | SOME (dx, dy) =>
                      let 
                        val src = index (tx, ty)
                        val dst = index (dx, dy)
                      in
                        if boardat (dx, dy) = FLOOR
                        then
                          (* push *)
                          f ({ guy = Word8.fromInt (index (tx, ty)),
                               board = 
                               Vector.tabulate 
                               (Vector.length board,
                                (fn i =>
                                 if i = src then FLOOR
                                 else if i = dst then BLUE
                                      else Vector.sub(board, i))) }, 
                             COST_GREY)
                        else ()
                      end)

             (* should be dead, anyway *)
             | LASER => ()
             | BLUE => ())

      (* hinted move *)
      fun hintmove d =
        (* is there a hint here? *)
        (case hintat (gx, gy) of
           NONE => move f d
         | SOME NOGUY => raise Parse "shouldn't be on noguy hint!"
         | SOME (PUSH pushdir) => 
             (* this hint means, if there is a block in direction d
                and we can push it, we MUST make that move and no
                other. *)
             if pushdir = d then move f d
             else 
               let 
                 fun trypush () =
                   let
                     val canmove = ref false
                   in
                     move (fn _ => canmove := true) pushdir;
                     if !canmove 
                     then () (* prune! *)
                     else move f d (* can't push the blocks, so go *)
                   end
               in
                 (case travel pushdir (gx, gy) of
                     
                     NONE => raise Parse "hint me off board??"
                   | SOME new =>
                       (case boardat new of
                          GREY => trypush ()
                        | STEEL => trypush ()
                        | _ => (* not a block; okay to not push! *)
                               move f d
                               ))
               end)

    in
      (* don't move off exit, since that can only be done on
         the first move and the parser doesn't allow such an
         initial state to be parsed. ;) *)
      case boardat (gx, gy) of
        EXIT => ()
      | _ => 
          let in
            (* basically, the only moves are the four cardinal
               directions. *)
            hintmove Up;
            hintmove Down;
            hintmove Left;
            hintmove Right
          end
    end

  (* (nb. not sure how forward solver interacts with
     multiple initial states...) *)
  val initials = [initial]

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
             | STEEL => #"S"
             | ROUGH => #":"
             | FLOOR => #" "
             | GREY => #"@"
             | GOLD => #"*"
             | EXIT => #"E"
             | GREEN => #"%"
             | LASER => #"L"
             | SPHERE => #"O"
         end)) ^ "#")) @ [topbot])
    end

  (* no sensible code here... *)
  fun tocode s = Word32.toString (hash s)

end
