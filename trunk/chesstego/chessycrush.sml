structure Chessycrush =
struct

  val whitepiecesp = Params.param "empty"
    (SOME("-whitepieces", "What pieces should white have? " ^
          " ...")) "whitepiecesp"

  val whitepawnsp = Params.param "pawns"
    (SOME("-whitepawns", "What pawns should white have? " ^
          "pawns, cheat, ...")) "whitepawnsp"

  val blackpiecesp = Params.param "empty"
    (SOME("-blackpieces", "What pieces should black have? " ^
          "empty, ...")) "blackpiecesp"

  exception Chessycrush of string
  val itos = Int.toString
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  val WIDTH = 8
  val HEIGHT = 8

  datatype piece =
    Pawn
    (* Destroys a column *)
  | CandyRookCol
  | CandyRookRow
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
  fun candycheat c =
    map (Option.map (fn p => (p, c)))
    [SOME Pawn, SOME Pawn, SOME Pawn, SOME CandyRookCol,
     NONE,      SOME Pawn, SOME Pawn, SOME Pawn]
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
      | "cheat" => candycheat White
      | s => raise Chessycrush ("unknown pawns type: " ^ s)) @

     (case !whitepiecesp of
        "empty" => empty White
      | s => raise Chessycrush ("unknown pieces type: " ^ s))
        )

  fun xytos (x, y) = String.substring ("abcdefgh", x, 1) ^
    itos (7 - y + 1)

  fun ptos (p, c) =
    case (p, c) of
      (Pawn, White) => "P"
    | (Pawn, Black) => "p"
    | (CandyRookCol, White) => "R"
    | (CandyRookCol, Black) => "r"
    | (CandyRookRow, White) => "Q"
    | (CandyRookRow, Black) => "q"
    | (King, White) => "K"
    | (King, Black) => "k"

  fun potos NONE = "-"
    | potos (SOME p) = ptos p

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
  fun flip_pos (x, y) = (x, 7 - y)

  fun clone b = Array.tabulate(WIDTH * HEIGHT, fn x => Array.sub (b, x))

  fun is_white_king (SOME (King, White)) = true
    | is_white_king _ = false

  fun is_black_king (SOME (King, Black)) = true
    | is_black_king _ = false

  fun black_is_dead b =
    not (Array.exists is_black_king b) andalso
    (* Check this because mutual elimination is declared to be a draw *)
    Array.exists is_white_king b

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
                        killrow : int list,
                        candy : bool }

         (* kill all of the black pieces in this column *)
         fun kill_col b x =
           Util.for 0 (HEIGHT - 1)
           (fn y =>
            case get b (x, y) of
              SOME (_, Black) => set b (x, y) NONE
            | _ => ())

         fun kill_row b y =
           Util.for 0 (WIDTH - 1)
           (fn x =>
            case get b (x, y) of
              SOME (_, Black) => set b (x, y) (SOME (King, Black))
            | _ => ())

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
               let
                 val colkills = ref nil
                 val rowkills = ref nil
               in
                 Util.for low high
                 (fn x =>
                  case get b (x, y) of
                    SOME (CandyRookCol, White) => colkills := x :: !colkills
                  | SOME (CandyRookRow, White) => rowkills := y :: !rowkills
                  | _ => ());
                 (!colkills, !rowkills)
               end
           in
             if size >= 3
             then
               let val (ck, rk) = getkills ()
               in Crush { low = low, high = high,
                          killcol = ck, killrow = rk,
                          candy = true }
               end
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
               let
                 val colkills = ref nil
                 val rowkills = ref nil
               in
                 Util.for low high
                 (fn y =>
                  let
                    val p = get b (x, y)
                  in
                    case p of
                      SOME (CandyRookCol, White) => colkills := x :: !colkills
                    | SOME (CandyRookRow, White) => rowkills := y :: !rowkills
                    | _ => ()
                  end);
                 (!colkills, !rowkills)
               end
           in
             if size >= 3
             then
               let val (ck, rk) = getkills ()
               in Crush { low = low, high = high,
                          killcol = ck, killrow = rk,
                          candy = true }
               end
             else NoCrush
           end

         (* Same, but check for crush after. Assumes
            crush can only happen fromthe destination. *)
         fun moveto_crush moved_horiz (destx, desty) =
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
                  Crush { low = x1, high = x2, killcol, killrow, candy } =>
                    let
                      val copy = clone b
                      (* Fix original at any point after copy *)
                      val () = repair ()
                    in
                      Util.for x1 x2
                      (fn xx =>
                       set copy (xx, desty) NONE);
                      app (kill_col copy) killcol;
                      app (kill_row copy) killrow;
                      if candy
                      then set copy (destx, desty)
                        (SOME (if moved_horiz
                               then CandyRookRow
                               else CandyRookCol, White))
                      else ();
                      f ((x, y), (destx, desty), copy)
                    end
                | NoCrush =>
                    (case vertical_crush b (destx, desty) of
                       Crush { low = y1, high = y2, killcol, killrow, candy } =>
                         let
                           val copy = clone b
                           val () = repair ()
                         in
                           Util.for y1 y2
                           (fn yy =>
                            set copy (destx, yy) NONE);
                           app (kill_col copy) killcol;
                           app (kill_row copy) killrow;
                           if candy
                           then set copy (destx, desty)
                                    (SOME (if moved_horiz
                                           then CandyRookRow
                                           else CandyRookCol, White))
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
             moveuntil (~1, 0, x, y) (moveto_crush true);
             moveuntil (1, 0, x, y) (moveto_crush true);
             moveuntil (0, ~1, x, y) (moveto_crush false);
             moveuntil (0, 1, x, y) (moveto_crush false)
           end
       in
         case piece of
           King =>
             let in
               (* XXX pretending kings can't move *)
               () (*
               ;
               moveto (x - 1, y - 1); moveto (x, y - 1); moveto (x + 1, y - 1);
               moveto (x - 1, y);                        moveto (x + 1, y);
               moveto (x - 1, y + 1); moveto (x, y + 1); moveto (x + 1, y + 1)
               *)
             end
         | Pawn =>
             let in
               if y = 6
               then moveto_crush false (x, 4)
               else ();
               moveto_crush false (x, y - 1);
               if has_black_piece (x - 1, y - 1)
               then moveto_crush false (x - 1, y - 1)
               else ();
               if has_black_piece (x + 1, y - 1)
               then moveto_crush false (x + 1, y - 1)
               else ()
             end
         | CandyRookCol => candy_rook ()
         | CandyRookRow => candy_rook ()

       end
     | _ => ()) b

  datatype whitemovetree =
    W of (int * int) * (int * int) * blackmovetree
    | Wtrivial

  (* Allowed but not required to collapse the tree if we do the same
     thing for several different moves of black's. *)
  and blackmovetree =
    B of (((int * int) * (int * int)) list * whitemovetree) list

  structure MoveList =
  struct
    type movelist = ((int * int) * (int * int)) list
    val Nil = nil
    val Cons : ((int * int) * (int * int)) * movelist -> movelist = op::
    (* Prints in reverse *)
    fun tostring l =
      StringUtil.delimit ", " (map (fn (src, dst) =>
                                    xytos src ^ "->" ^ xytos dst) (rev l))
  end

  structure FreeMoveList =
  struct
    type movelist = unit
    val Nil = ()
    fun Cons _ = ()
    fun tostring _ = "-not saved-"
  end

  structure M = MoveList

  fun intpair ((a, b), (aa, bb)) =
    case Int.compare (a, aa) of
      EQUAL => Int.compare (b, bb)
    | order => order

  val movepair =
    Util.lexicographic [Util.order_field #1 intpair,
                        Util.order_field #2 intpair]

  fun cmpw (Wtrivial, Wtrivial) = EQUAL
    | cmpw (W _, Wtrivial) = LESS
    | cmpw (Wtrivial, W _) = GREATER
    | cmpw (W w1, W w2) =
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
    | simplifyw Wtrivial = Wtrivial
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
               let val m = ptos (p, c)
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

  datatype mainline =
      Nil
    | Moves of ((int * int) * (int * int) * mainline) list

  fun ::: ((src, dst), t) = Moves [(src, dst, t)]
  infixr :::

  fun movestos l =
    "[" ^ StringUtil.delimit " or "
    (map (fn (src, dst, ml) => xytos src ^ "->" ^ xytos dst) l) ^
    "]"

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
  fun winning b _ _ 0 = NONE
    | winning b (movelist : M.movelist) Nil depth =
    (let
       fun onemove (src, dst, newboard) =
         let in
           (*
           if depth = DEPTH
           then eprint (xytos src ^ " -> " ^ xytos dst ^ "...\n")
           else ();
           *)

           case losing newboard (M.Cons ((src, dst), movelist))
                       Nil (depth - 1) of
             NONE => ()
           | SOME bmt => raise Winning (W (src, dst, bmt))
         end
     in
       if black_is_dead b
       then raise Winning Wtrivial
       else ();
       app_moves b onemove;
       NONE
     end handle Winning wmt => SOME wmt)
    | winning b movelist (Moves moves) depth =
    (let
       val didmain = ref false

       (* PERF: Assumes there are no more than a handful
          of options. *)
       fun getmainline nil _ = NONE
         | getmainline ((s, d, ml) :: rest) (ss, dd) =
         if ss = s andalso dd = d
         then SOME ml
         else getmainline rest (ss, dd)

       fun onemove (src, dst, newboard) =
         (* PERF could pass this information forward? *)
         case getmainline moves (src, dst) of
           NONE => ()  (* Maybe fall back to search? *)
         | SOME rest =>
         let in
           didmain := true;
           (*
           if depth = DEPTH
           then eprint (xytos src ^ " -> " ^ xytos dst ^ "...\n")
           else ();
           *)

           case losing newboard (M.Cons ((src, dst), movelist))
                       rest (depth - 1) of
             NONE => ()
           | SOME bmt => raise Winning (W (src, dst, bmt))
         end
     in
       if black_is_dead b
       then raise Winning Wtrivial
       else ();

       app_moves b onemove;
       (* XXX need backup strategy in these cases... *)
       if not (!didmain)
       then print ("Entire mainline is illegal: " ^
                   movestos moves ^
                   " on board\n \\chessboard[setfen=" ^ tofen b ^ "]\n" ^
                   " after\n" ^ M.tostring movelist ^ "\n")
       else ();
       NONE
     end handle Winning wmt => SOME wmt)


  and losing _ _ _ 0 = NONE
    | losing original_board movelist mainline depth =
    let
      val moves = ref nil
      val b = dualize original_board

      fun onemove (src, dst, newboard) =
        let val flipboard = dualize newboard
          val fsrc = flip_pos src
          val fdst = flip_pos dst
          val movelist = M.Cons ((fsrc, fdst), movelist)
        in
          case winning flipboard movelist mainline (depth - 1) of
            NONE => raise Losing
          | SOME wmt =>
              moves := ([(fsrc, fdst)], wmt) :: !moves
        end
    in
      app_moves b onemove;
      SOME (B (!moves))
    end handle Losing => NONE

  fun pad 0 = ""
    | pad n = " " ^ pad (n - 1)

  fun wmtsize (W (_, _, bmt)) = 1 + bmtsize bmt
    | wmtsize Wtrivial = 1
  and bmtsize (B l) = foldr op+ 1 (map (fn (_, wmt) => wmtsize wmt) l)

  fun printwmt indent (W (src, dst, bmt)) =
    let in
      print (pad indent ^ "White: " ^ xytos src ^ " -> " ^ xytos dst ^ ":\n");
      printbmt (indent + 2) bmt
    end
    | printwmt indent (Wtrivial) = print (pad indent ^ "(black is dead)\n")

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

  (* Make a move as white. Replays search from this
     position, since some moves have effects beyond
     just placing the piece at src on dst. *)
  exception Done of board
  fun makemovewhite board (src, dst) =
    let
      val board = clone board
      fun moveif (ss, dd, b) =
        if ss = src andalso dd = dst
        then raise Done b
        else ()
    in
      app_moves board moveif;
      raise Chessycrush ("makemovewhite, impossible " ^
                         xytos src ^ "->" ^
                         xytos dst)
    end handle Done b => b

  fun makemoveblack board (src, dst) =
    let
      (* Same as above, but dualize the board and
         move before doing app_moves, then reverse *)
      val board = dualize board
      val fsrc = flip_pos src
      val fdst = flip_pos dst
      fun moveif (ss, dd, b) =
        if ss = fsrc andalso dd = fdst
        then raise Done (dualize b)
        else ()
    in
      app_moves board moveif;
      raise Chessycrush ("makemoveblack, impossible " ^
                         xytos src ^ "->" ^
                         xytos dst)
    end handle Done b => b

  fun printwtree move board (W (src, dst, bmt)) =
    let
      val board = makemovewhite board (src, dst)
    in
      print (pad (move * 4) ^ itos move ^ ". " ^
             xytos src ^ xytos dst ^ " " ^
             tofen board ^ "\n");
      printbtree move board bmt
    end
    | printwtree move board Wtrivial =
    print (pad (move * 4) ^ itos move ^ ". (black is dead)\n")

  and printbtree move board (B nil) =
    print (pad (move * 4 + 2) ^ " ++\n")
    | printbtree move board (B l) =
    let
      fun onemove (moves as ((src, dst) :: _) , wmt) =
        let
          val board = makemoveblack board (src, dst)
          val ms = StringUtil.delimit "," (map (fn (s, d) =>
                                                xytos s ^ xytos d) moves)
         in
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
      val board = makemovewhite board (src, dst)
      val pp = pad (move * 4)
    in
      print (pp ^ "% \\begin{itemize} % white\n" ^
             pp ^ (* "\\item " ^ *) itos (move + 1) ^ ". " ^
             xytos src ^ xytos dst ^ " \\\\ " ^
             "\\chessboard[setfen=" ^ tofen board ^ "]\n");
      texbtree move board bmt;
      print (pp ^ "% \\end{itemize} % white\n")
    end
    | texwtree move board Wtrivial =
      print (pad (move * 4) ^ " (black is dead)\n")

  and texbtree move board (B nil) =
    print (pad (move * 4 + 2) ^ " ++\n")
    | texbtree move board (B l) =
    let
      val pp = pad (move * 4 + 2)
      fun onemove (moves as ((src, dst) :: _) , wmt) =
        let
          val board = makemoveblack board (src, dst)
          val ms = StringUtil.delimit ", " (map (fn (s, d) =>
                                                 xytos s ^ xytos d) moves)
         in
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
    | deepestw Wtrivial = nil
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

(* in chessy v1
  val mainline = [((1, 6), (1, 5)),
                  ((3, 6), (3, 5)),
                  ((4, 6), (4, 5)),
                  ((2, 6), (2, 5)), (* candy *)
                  ((2, 5), (2, 6)),
                  ((2, 6), (4, 6))] (* kills king *)
    *)

  val mainline : mainline =
    ((4, 6), (4, 5)) ::: (* king's pawn *)
    Moves [((5, 6), (5, 5), (* rhs *)
            ((6, 6), (6, 5)) :::
            ((6, 5), (6, 6)) :::
            ((6, 6), (4, 6)) ::: Nil),
           ((3, 6), (3, 5), (* lhs *)
            ((2, 6), (2, 5)) :::
            (* Either bank-rank mate or omega weapon *)
            Moves [((2, 5), (2, 6),
                    ((2, 6), (4, 6)) ::: Nil),
                   ((2, 5), (2, 0),
                    ((2, 0), (4, 0)) ::: Nil)])]

  fun main d =
    let
      val DEPTH = case Int.fromString d of
        NONE => raise Chessycrush "need int"
      | SOME i => i
      val startboard = init ()
      val backup = init ()
    in
       eprint ("Searching to depth " ^ itos DEPTH ^ "...\n");

       case winning startboard M.Nil mainline DEPTH of
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

end

val () = Params.main1 "Command-line argument: nuthin" Chessycrush.main
  handle Chessycrush.Chessycrush s => print ("Chessycrush: " ^ s ^ "\n")