structure Chessycrush =
struct

  val whitepiecesp = Params.param "regular"
    (SOME("-whitepieces", "What pieces should white have? " ^
          "regular, queens, kor, koq, mor, moq, ...")) "whitepiecesp"

  val whitepawnsp = Params.param "pawns"
    (SOME("-whitepawns", "What pawns should white have? " ^
          "pawns, knights, mega, ...")) "whitepawnsp"

  val blackpiecesp = Params.param "regular"
    (SOME("-blackpieces", "What pieces should black have? " ^
          "regular, justking, ...")) "blackpiecesp"

  exception Chessycrush of string
  val itos = Int.toString
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  val WIDTH = 8
  val HEIGHT = 8

  datatype piece =
    Pawn
    (* Destroys a column *)
  | CandyRookCol
    (* Destroys a row *)
    (* | CandyRookRow *)
    (* Bomb that destroys 3x3 *)
    (* | CandyWrapper *)
    (* Color bomb *)
    (* | CandyBomb *)
  | King

  datatype color =
    Black
  | White

  type board = (piece * color) option Array.array

  val pawns =
    [Pawn,  Pawn,   Pawn,   Pawn,  Pawn,  Pawn,   Pawn,   Pawn]
  fun empty c =
    [NONE, NONE, NONE, NONE, SOME (King, c), NONE, NONE, NONE]

  fun white l = map (fn x => SOME (x, White)) l
  fun black l = map (fn x => SOME (x, Black)) l

  fun init () =
    Array.fromList
    (
    (case !blackpiecesp of
       "empty" => empty Black
     | s => raise Chessycrush ("unknown pieces type: " ^ s)) @

    black pawns @

     [NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE] @

     (case !whitepawnsp of
        "pawns" => white pawns
      | s => raise Chessycrush ("unknown pawns type: " ^ s)) @

     (case !whitepiecesp of
        "empty" => empty White
      | s => raise Chessycrush ("unknown pieces type: " ^ s))
        )

  fun get board (x, y) =
    Array.sub (board, y * WIDTH + x)

  fun set board (x, y) a =
    Array.update (board, y * WIDTH + x, a)

  (* Flips the board so that black becomes white and vice versa.
     We use this to simplify move generation; it is always white
     that is moving, and always "up" the board. *)
  fun dualize b =
    Array.tabulate (WIDTH * HEIGHT,
                    fn i =>
                    let
                      val x = i mod WIDTH
                      val y = i div WIDTH
                      val oldy = (HEIGHT - 1) - y

                      fun oc White = Black
                        | oc Black = White
                      fun opp NONE = NONE
                        | opp (SOME (piece, color)) =
                        SOME (piece, oc color)

                      val old = get b (x, oldy)
                    in
                      opp old
                    end)

  fun copyboard b =
    Array.tabulate (WIDTH * HEIGHT, fn i => Array.sub (b, i))

  fun is_white_king (SOME (King, White)) = true
    | is_white_king _ = false

  (* Apply the function to all moves that white can make. A
     move is represented by the pair of coordinates of the piece
     that's moving, and the resulting board. Castling and en
     passant capture are not supported, since it's expected
     that we won't search deep enough to even use these (but
     they could be added with a little extra work to keep
     track of the required state). To simplify matters, we also
     allow moving into check -- if you do this, the state will
     be losing because the opponent can just capture your king
     on the next move.

     The board that f receives is a modified alias of b.
     app_moves itself takes responsibility for repairing the board
     in between calls to f and before it returns. However, it
     assumes that if f modifies b, that it puts the board back
     in the state in which it received it. *)
  fun app_moves b (f : (int * int) * (int * int) * board -> unit) : unit =
    (* If my king is dead, I have no moves. *)
    if not (Array.exists is_white_king b)
    then ()
    else
    Array.appi
    (fn (i, elt) =>
     case elt of
       src_cell as (SOME (piece, White)) =>
       let val y = i div WIDTH
           val x = i mod WIDTH

         (* For normal capturing chess moves. Move src to
            the destination, call f, and then return the
            board to the original state. *)
         fun moveto (destx, desty) =
           (* Can't move off board *)
           if destx < 0 orelse destx >= WIDTH orelse
              desty < 0 orelse desty >= HEIGHT
           then ()
           else
             (* Can't capture own piece *)
             case get b (destx, desty) of
               SOME (_, White) => ()
             | dst_cell =>
              let in
                set b (x, y) NONE;
                set b (destx, desty) src_cell;
                f ((x, y), (destx, desty), b);
                (* put it back *)
                set b (x, y) src_cell;
                set b (destx, desty) dst_cell
              end

         datatype crush =
             NoCrush
           | Crush of { low : int, high : int,
                        killcol : int list,
                        candy : bool }

         (* kill all of the black pieces in this column *)
         fun kill_col b x =
           Util.for 0 (HEIGHT - 1)
           (fn y => set b (x, y) NONE)

         fun horizontal_crush b (x, y) =
           let
             (* return the index of the left edge
                of the crush. assumes arg is in it *)
             fun goleft 0 = 0
               | goleft x =
               case get b (x - 1, y) of
                 SOME (_, White) => goleft (x - 1)
               | _ => x

             fun goright x =
               if x = WIDTH - 1
               then x
               else case get b (x + 1, y) of
                 SOME (_, White) => goright (x + 1)
               | _ => x

             val low = goleft x
             val high = goright x
             val size = high - low + 1

             fun getkills () =
               let val kills = ref nil
               in
                 Util.for low high
                 (fn x =>
                  case get b (x, y) of
                    SOME (CandyRookCol, White) => kills := x :: !kills
                  | _ => ());
                 !kills
               end
           in
             if size >= 3
             then Crush { low = low, high = high,
                          killcol = getkills (),
                          candy = size > 3 }
             else NoCrush
           end

         fun vertical_crush b (x, y) =
           let
             (* return the index of the top edge
                of the crush. assumes arg is in it *)
             fun goup 0 = 0
               | goup y =
               case get b (x, y - 1) of
                 SOME (_, White) => goup (y - 1)
               | _ => y

             fun godown y =
               if y = HEIGHT - 1
               then y
               else case get b (x, y + 1) of
                 SOME (_, White) => godown (y + 1)
               | _ => y

             val low = goup y
             val high = godown y
             val size = high - low + 1

             (* PERF probably can just return the one, if there
                are multiple. Probably never happens in search
                though. *)
             fun getkills () =
               let val kills = ref nil
               in
                 Util.for low high
                 (fn y =>
                  case get b (x, y) of
                    (* x is correct here -- we want the column.
                       It'll be the same each time. *)
                    SOME (CandyRookCol, White) => kills := x :: !kills
                  | _ => ());
                 !kills
               end
           in
             if size >= 3
             then Crush { low = low, high = high,
                          killcol = getkills (),
                          candy = size > 3 }
             else NoCrush
           end

         (* Same, but check for crush after. Assumes
            crush can only happen fromthe destination. *)
         fun moveto_crush (destx, desty) =
           (* Can't move off board *)
           if destx < 0 orelse destx >= WIDTH orelse
              desty < 0 orelse desty >= HEIGHT
           then ()
           else
             (* Can't capture own piece *)
             case get b (destx, desty) of
               SOME (_, White) => ()
             | dst_cell =>
              let
                (* undoes just the normal part of the move.
                   in the crush scenario, we use this to
                   repair the original after copying (copy
                   will be discarded). In the normal move
                   scenario, we repair in place *)
                fun repair () =
                  let in
                    set b (x, y) src_cell;
                    set b (destx, desty) dst_cell
                  end

              in
                set b (x, y) NONE;
                set b (destx, desty) src_cell;

                case horizontal_crush b (destx, desty) of
                  Crush { low = x1, high = x2, killcol, candy } =>
                    let
                      val copy = copyboard b
                      (* Fix original at any point after copy *)
                      val () = repair ()
                    in
                      Util.for x1 x2
                      (fn xx =>
                       set copy (xx, desty) NONE);
                      app (kill_col copy) killcol;
                      if candy
                      then set copy (destx, desty) (SOME (CandyRookCol, White))
                      else ();
                      f ((x, y), (destx, desty), copy)
                    end
                | NoCrush =>
                    (case vertical_crush b (destx, desty) of
                       Crush { low = y1, high = y2, killcol, candy } =>
                         let
                           val copy = copyboard b
                           val () = repair ()
                         in
                           Util.for y1 y2
                           (fn yy =>
                            set copy (destx, yy) NONE);
                           app (kill_col copy) killcol;
                           if candy
                           then set copy (destx, desty)
                                    (SOME (CandyRookCol, White))
                           else ();
                           f ((x, y), (destx, desty), copy)
                         end
                     | NoCrush =>
                         let in
                           f ((x, y), (destx, desty), b);
                           (* repair after recursion *)
                           repair ()
                         end)
              end

         (* e.g. for pawn captures *)
         fun has_black_piece (x, y) =
           x >= 0 andalso x < WIDTH andalso y >= 0 andalso y < HEIGHT andalso
           (case get b (x, y) of
              SOME (_, Black) => true
            | _ => false)

         fun moveuntil (dx, dy, cx, cy) (f : int * int -> unit) =
           let val (newx, newy) = (cx + dx, cy + dy)
           in
             if newx < 0 orelse newx >= WIDTH orelse
                newy < 0 orelse newy >= HEIGHT
             then ()
             else (case get b (newx, newy) of
                     NONE => (f (newx, newy);
                              moveuntil (dx, dy, newx, newy) f)
                   | SOME (_, Black) => f (newx, newy)
                   | _ => ())
           end

         fun candy_rook () =
           let in
             moveuntil (~1, 0, x, y) moveto_crush;
             moveuntil (1, 0, x, y) moveto_crush;
             moveuntil (0, ~1, x, y) moveto_crush;
             moveuntil (0, 1, x, y) moveto_crush
           end
       in
         case piece of
           King =>
             let in
               moveto (x - 1, y - 1); moveto (x, y - 1); moveto (x + 1, y - 1);
               moveto (x - 1, y);                        moveto (x + 1, y);
               moveto (x - 1, y + 1); moveto (x, y + 1); moveto (x + 1, y + 1)
             end
         | Pawn =>
             let in
               if y = 6
               then moveto_crush (x, 4)
               else ();
               moveto_crush (x, y - 1);
               if has_black_piece (x - 1, y - 1)
               then moveto_crush (x - 1, y - 1)
               else ();
               if has_black_piece (x + 1, y - 1)
               then moveto_crush (x + 1, y - 1)
               else ()
             end
         | CandyRookCol => candy_rook ()

       end
     | _ => ()) b

  datatype whitemovetree =
    W of (int * int) * (int * int) * blackmovetree

  (* Allowed but not required to collapse the tree if we do the same
     thing for several different moves of black's. *)
  and blackmovetree =
    B of (((int * int) * (int * int)) list * whitemovetree) list

  fun intpair ((a, b), (aa, bb)) =
    case Int.compare (a, aa) of
      EQUAL => Int.compare (b, bb)
    | order => order

  val movepair =
    Util.lexicographic [Util.order_field #1 intpair,
                        Util.order_field #2 intpair]

  fun cmpw (W w1, W w2) =
    Util.lexicographic [Util.order_field #1 intpair,
                        Util.order_field #2 intpair,
                        Util.order_field #3 cmpb] (w1, w2)
  and cmpb (B l1, B l2) =
    Util.lex_list_order cmpbm (l1, l2)

  (* (moves, wmt) *)
  and cmpbm (bm1, bm2) =
    Util.lexicographic [Util.order_field #1 cmpmoves,
                        Util.order_field #2 cmpw] (bm1, bm2)

  and cmpmoves (l1, l2) =
    Util.lex_list_order movepair (l1, l2)

  fun simplifyw (W (src, dst, bmt)) = W (src, dst, simplifyb bmt)
  and simplifyb (B l) =
    let
      val l = map (fn (x, y) => (x, simplifyw y)) l
      val swapl = map (fn (x, y) => (y, x)) l
      (* val stratify : ('a * 'a -> order) -> ('a * 'b) list ->
                        ('a * 'b list) list *)
      val ll = ListUtil.stratify cmpw swapl
      val swapll = map (fn (x, y) => (List.concat y, x)) ll
    in
      B swapll
    end

  fun simplifying t =
    let val newt = simplifyw t
    in
      case cmpw (t, newt) of
        EQUAL => newt
      | _ => simplifying newt
    end

  val DEPTH = 6

  fun xytos (x, y) = String.substring ("abcdefgh", x, 1) ^
    itos (7 - y + 1)

  (* A state is known to be winning (for white) if there exists
     a move where the resulting state is losing (for black). A
     state is losing (for black) if for all black's moves,
     the states are winning (for white). Importantly, this includes
     the case where black has no moves--this is the only way for
     the recursion to terminate.

     Two mutually-recursive functions. We only compute this to a
     certain depth, so these are conservative approximations --
     they may return false even if it is really winning/losing.

     Both functions may modify the board temporarily in order to
     recurse, but should put it back before returning. *)
  exception Winning of whitemovetree
  exception Losing
  fun winning b 0 = NONE
    | winning b depth =
    let
      fun onemove (src, dst, newboard) =
        let in
          if depth = DEPTH
          then eprint (xytos src ^ " -> " ^ xytos dst ^ "...\n")
          else ();

          case losing newboard (depth - 1) of
            NONE => ()
          | SOME bmt => raise Winning (W (src, dst, bmt))
        end
    in
      app_moves b onemove;
      NONE
    end handle Winning wmt => SOME wmt

  and losing _ 0 = NONE
    | losing original_board depth =
    let
      val moves = ref nil
      val b = dualize original_board

      fun flip (x, y) = (x, 7 - y)

      fun onemove (src, dst, newboard) =
        let val flipboard = dualize newboard
        in
          case winning flipboard (depth - 1) of
            NONE => raise Losing
          | SOME wmt =>
              let val fsrc = flip src
                  val fdst = flip dst
              in moves := ([(fsrc, fdst)], wmt) :: !moves
              end
        end
    in
      app_moves b onemove;
      SOME (B (!moves))
    end handle Losing => NONE

  fun pad 0 = ""
    | pad n = " " ^ pad (n - 1)

  fun wmtsize (W (_, _, bmt)) = 1 + bmtsize bmt
  and bmtsize (B l) = foldr op+ 1 (map (fn (_, wmt) => wmtsize wmt) l)

  fun printwmt indent (W (src, dst, bmt)) =
    let in
      print (pad indent ^ "White: " ^ xytos src ^ " -> " ^ xytos dst ^ ":\n");
      printbmt (indent + 2) bmt
    end

  and printbmt indent (B nil) =
    print (pad indent ^ "** black has no moves **\n")
    | printbmt indent (B l) =
    app (fn (moves, wmt) =>
         let
           val ms = StringUtil.delimit ", " (map (fn (s, d) =>
                                                  xytos s ^ xytos d) moves)
         in
           print (pad indent ^
                  "If black: " ^ ms ^ " then:\n");
           printwmt (indent + 2) wmt
         end) l

  fun clone b = Array.tabulate(WIDTH * HEIGHT, fn x => Array.sub (b, x))
  fun tofen b =
    let
      fun rowtofen y =
        let
          val s = ref ""
          val blanks = ref 0
          fun doblanks () =
            if !blanks > 0
            then (s := !s ^ itos (!blanks); blanks := 0)
            else ()
        in
          Util.for 0 7
          (fn x =>
           case get b (x, y) of
             NONE => blanks := !blanks + 1
           | SOME (p, c) =>
               let val m =
                 case (p, c) of
                   (Pawn, White) => "P"
                 | (Pawn, Black) => "p"
                 | (CandyRookCol, White) => "R"
                 | (CandyRookCol, Black) => "r"
                 | (King, White) => "K"
                 | (King, Black) => "k"
               in
                 doblanks ();
                 s := !s ^ m
               end);
          doblanks ();
          !s
        end
    in
      rowtofen 0 ^ "/" ^
      rowtofen 1 ^ "/" ^
      rowtofen 2 ^ "/" ^
      rowtofen 3 ^ "/" ^
      rowtofen 4 ^ "/" ^
      rowtofen 5 ^ "/" ^
      rowtofen 6 ^ "/" ^
      rowtofen 7
      (* currently no bonus stuff *)
    end

  fun printwtree move board (W (src, dst, bmt)) =
    let
      val board = clone board
      val spiece = get board src
    in
      set board src NONE;
      set board dst spiece;
      print (pad (move * 4) ^ itos move ^ ". " ^
             xytos src ^ xytos dst ^ " " ^
             tofen board ^ "\n");
      printbtree move board bmt
    end

  and printbtree move board (B nil) =
    print (pad (move * 4 + 2) ^ " ++\n")
    | printbtree move board (B l) =
    let
      fun onemove (moves as ((src, dst) :: _) , wmt) =
        let
          val board = clone board
          val spiece = get board src
          val ms = StringUtil.delimit "," (map (fn (s, d) =>
                                                xytos s ^ xytos d) moves)
         in
          set board src NONE;
          set board dst spiece;
          print (pad (move * 4 + 2) ^ itos move ^
                 ". ..." ^ ms ^ " "  ^ tofen board ^ "\n");
          printwtree (move + 1) board wmt
        end
        | onemove (nil, wmt) = raise Chessycrush "nil bmt not allowed"
    in
      app onemove l
    end

  fun texwtree move board (W (src, dst, bmt)) =
    let
      val board = clone board
      val spiece = get board src
      val pp = pad (move * 4)
    in
      set board src NONE;
      set board dst spiece;
      print (pp ^ "% \\begin{itemize} % white\n" ^
             pp ^ (* "\\item " ^ *) itos (move + 1) ^ ". " ^
             xytos src ^ xytos dst ^ " \\\\ " ^
             "\\chessboard[setfen=" ^ tofen board ^ "]\n");
      texbtree move board bmt;
      print (pp ^ "% \\end{itemize} % white\n")
    end

  and texbtree move board (B nil) =
    print (pad (move * 4 + 2) ^ " ++\n")
    | texbtree move board (B l) =
    let
      val pp = pad (move * 4 + 2)
      fun onemove (moves as ((src, dst) :: _) , wmt) =
        let
          val board = clone board
          val spiece = get board src
          val ms = StringUtil.delimit ", " (map (fn (s, d) =>
                                                 xytos s ^ xytos d) moves)
         in
          set board src NONE;
          set board dst spiece;
          print (pp ^ "\\item " ^ itos (move + 1) ^
                 ". \\ldots " ^ ms ^ "\n" ^
                 pp ^ "% " ^ tofen board ^ "\n");
          texwtree (move + 1) board wmt
        end
        | onemove (nil, wmt) = raise Chessycrush "nil bmt not allowed"
    in
      print (pp ^ "\\begin{itemize} % black\n");
      app onemove l;
      print (pp ^ "\\end{itemize} % black\n")
    end


  fun deepestw (W (src, dst, bmt)) =
    (src, dst) :: deepestb bmt
  and deepestb (B nil) = nil
    | deepestb (B ((nil, _) :: _)) = raise Chessycrush "nil bmt not allowed"
    | deepestb (B (((hsrc, hdst) :: _, hwmt) :: t)) =
    let
      fun getdeepest (deepest, len) nil = (deepest, len)
        | getdeepest _ ((nil, _) :: _) = raise Chessycrush "nil bmt not allowed"
        | getdeepest (deepest, len) (((src, dst) :: _, wmt) :: rest) =
        let val d = (src, dst) :: deepestw wmt
          val ld = length d
        in if ld > len
           then getdeepest (d, ld) rest
           else getdeepest (deepest, len) rest
        end

      val hdeepest = (hsrc, hdst) :: deepestw hwmt
      val (deepest, len) = getdeepest (hdeepest, length hdeepest) t
    in
      deepest
    end

  fun search () =
    let
      val startboard = init ()
      val backup = init ()
    in
       eprint ("Searching to depth " ^ itos DEPTH ^ "...\n");

       case winning startboard DEPTH of
         NONE => eprint ("No winning strategy in " ^ itos DEPTH ^ "...")
       | SOME wmt =>
           let
             val wmt = simplifying wmt
             val deepest = deepestw wmt
             val ssize = wmtsize wmt
           in
             eprint ("WINNING!\n");
             eprint ("Strategy size: " ^ itos ssize ^ "\n");
             eprint ("Example deepest:\n  ");
             app (fn (src, dst) =>
                  eprint (xytos src ^ " -> " ^ xytos dst ^ " ")) deepest;
             eprint "\n";
             if (ssize < 1000)
             then texwtree 0 backup wmt
             else ();

             (* printwmt 0 wmt; *)
             ()
           end
     end

  fun main () = search ()
end

val () = Params.main0 "Command-line argument: nuthin" Chessycrush.main
  handle Chessycrush.Chessycrush s => print ("Chessycrush: " ^ s ^ "\n")