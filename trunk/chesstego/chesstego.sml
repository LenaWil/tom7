structure Chesstego =
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

  exception Chesstego of string
  val itos = Int.toString
  fun eprint s = TextIO.output(TextIO.stdErr, s)

  datatype piece =
    Pawn
  | Rook
  | Knight
  | Bishop
  | Queen
  | King

  datatype color =
    Black
  | White

  type board = (piece * color * bool) option Array.array

  val pawns =
    [Pawn,  Pawn,   Pawn,   Pawn,  Pawn,  Pawn,   Pawn,   Pawn]
  val regular =
    [Rook,  Knight, Bishop, Queen,  King, Bishop, Knight, Rook]
  val queens =
    [Queen, Queen,  Queen,  Queen,  King, Queen,  Queen, Queen]
  val knights =
    [Knight, Knight, Knight, Knight, Knight, Knight, Knight, Knight]
  val mega =
    [Knight, Knight, Knight, Bishop, Bishop, Knight, Knight, Knight]

  fun white l = map (fn x => SOME (x, White, false)) l
  fun black l = map (fn x => SOME (x, Black, false)) l

  fun init () =
    Array.fromList
    (
    (case !blackpiecesp of
       "regular" => black regular
     | "justking" => [NONE, NONE, NONE, NONE,
                      SOME (King, Black, false),
                      NONE, NONE, NONE]
     | s => raise Chesstego ("unknown pieces type: " ^ s)) @

    black pawns @

     [NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE] @

     (case !whitepawnsp of
        "pawns" => white pawns
      | "knights" => white knights
      | "mega" => white mega
      | s => raise Chesstego ("unknown pawns type: " ^ s)) @

     (case !whitepiecesp of
        "regular" => white regular
      | "queens" => white queens
      | s => raise Chesstego ("unknown pieces type: " ^ s))
        )

  fun get board (x, y) =
    Array.sub (board, y * 8 + x)

  fun set board (x, y) a =
    Array.update (board, y * 8 + x, a)

  fun init_with_kings (x1, y1, x2, y2) =
    let val board = init ()
      fun makeking (x, y) =
        case get board (x, y) of
          NONE => raise Chesstego "No piece to make king"
        | SOME (piece, color, _) =>
            set board (x, y) (SOME (piece, color, true))
    in
      makeking (x1, y1);
      makeking (x2, y2);
      board
    end

  (* Flips the board so that black becomes white and vice versa.
     We use this to simplify move generation; it is always white
     that is moving, and always "up" the board. *)
  fun dualize b =
    Array.tabulate (8 * 8,
                    fn i =>
                    let
                      val x = i mod 8
                      val y = i div 8
                      val oldy = 7 - y

                      fun oc White = Black
                        | oc Black = White
                      fun opp NONE = NONE
                        | opp (SOME (piece, color, king)) =
                        SOME (piece, oc color, king)

                      val old = get b (x, oldy)
                    in
                      opp old
                    end)

  fun is_white_king NONE = false
    | is_white_king (SOME (_, Black, _)) = false
    | is_white_king (SOME (_, White, b)) = b

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
       src_cell as (SOME (piece, White, is_king)) =>
       let val y = i div 8
           val x = i mod 8

         fun moveto (destx, desty) =
           (* Can't move off board *)
           if destx < 0 orelse destx >= 8 orelse
              desty < 0 orelse desty >= 8
           then ()
           else
             (* Can't capture own piece *)
             case get b (destx, desty) of
               SOME (_, White, _) => ()
             | dst_cell =>
              let in
                set b (x, y) NONE;
                set b (destx, desty) src_cell;
                f ((x, y), (destx, desty), b);
                (* put it back *)
                set b (x, y) src_cell;
                set b (destx, desty) dst_cell
              end

         (* e.g. for pawn captures *)
         fun has_black_piece (x, y) =
           x >= 0 andalso x < 8 andalso y >= 0 andalso y < 8 andalso
           (case get b (x, y) of
              SOME (_, Black, _) => true
            | _ => false)

         fun moveuntil (dx, dy, cx, cy) (f : int * int -> unit) =
           let val (newx, newy) = (cx + dx, cy + dy)
           in
             if newx < 0 orelse newx >= 8 orelse
                newy < 0 orelse newy >= 8
             then ()
             else (case get b (newx, newy) of
                     NONE => (f (newx, newy);
                              moveuntil (dx, dy, newx, newy) f)
                   | SOME (_, Black, _) => f (newx, newy)
                   | _ => ())
           end

         (* Hoisted because queen = rook || bishop *)
         fun rook () =
           let in
             moveuntil (~1, 0, x, y) moveto;
             moveuntil (1, 0, x, y) moveto;
             moveuntil (0, ~1, x, y) moveto;
             moveuntil (0, 1, x, y) moveto
           end

         fun bishop () =
           let in
             moveuntil (~1, ~1, x, y) moveto;
             moveuntil (1, ~1, x, y) moveto;
             moveuntil (1, 1, x, y) moveto;
             moveuntil (~1, 1, x, y) moveto
           end

       in
         case piece of
           King =>
             let in
               moveto (x - 1, y - 1); moveto (x, y - 1); moveto (x + 1, y - 1);
               moveto (x - 1, y);                        moveto (x + 1, y);
               moveto (x - 1, y + 1); moveto (x, y + 1); moveto (x + 1, y + 1)
             end
         | Knight =>
             let in
               moveto (x - 1, y - 2); moveto (x + 1, y - 2);
               moveto (x - 2, y - 1); moveto (x + 2, y - 1);
               moveto (x - 2, y + 1); moveto (x + 2, y + 1);
               moveto (x - 1, y + 2); moveto (x + 1, y + 2)
             end
         | Pawn =>
             let in
               if y = 6
               then moveto (x, 4)
               else ();
               moveto (x, y - 1);
               if has_black_piece (x - 1, y - 1)
               then moveto (x - 1, y - 1)
               else ();
               if has_black_piece (x + 1, y - 1)
               then moveto (x + 1, y - 1)
               else ()
             end
         | Rook => rook ()
         | Bishop => bishop ()
         | Queen =>
             let in
               rook ();
               bishop ()
             end
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

  fun clone b = Array.tabulate(8 * 8, fn x => Array.sub (b, x))
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
           | SOME (p, c, k) =>
               let val m =
                 case (p, c) of
                   (Pawn, White) => "P"
                 | (Pawn, Black) => "p"
                 | (Rook, White) => "R"
                 | (Rook, Black) => "r"
                 | (Knight, White) => "N"
                 | (Knight, Black) => "n"
                 | (Bishop, White) => "B"
                 | (Bishop, Black) => "b"
                 | (Queen, White) => "Q"
                 | (Queen, Black) => "q"
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
        | onemove (nil, wmt) = raise Chesstego "nil bmt not allowed"
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
        | onemove (nil, wmt) = raise Chesstego "nil bmt not allowed"
    in
      print (pp ^ "\\begin{itemize} % black\n");
      app onemove l;
      print (pp ^ "\\end{itemize} % black\n")
    end


  fun deepestw (W (src, dst, bmt)) =
    (src, dst) :: deepestb bmt
  and deepestb (B nil) = nil
    | deepestb (B ((nil, _) :: _)) = raise Chesstego "nil bmt not allowed"
    | deepestb (B (((hsrc, hdst) :: _, hwmt) :: t)) =
    let
      fun getdeepest (deepest, len) nil = (deepest, len)
        | getdeepest _ ((nil, _) :: _) = raise Chesstego "nil bmt not allowed"
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

  val dopawn =
(*  val () =
    Util.for 0 7 *)
    (fn pawn_x =>
     let
       val startboard = init_with_kings (pawn_x, 1, 0, 7)
       val backup = init_with_kings (pawn_x, 1, 0, 7)
     in
       eprint ("Searching to depth " ^ itos DEPTH ^
              " with king at pawn idx " ^ itos pawn_x ^ "\n");

       case winning startboard DEPTH of
         NONE => eprint ("No winning strategy in " ^ itos DEPTH ^ " " ^
                         "for king at idx " ^ itos pawn_x ^ "\n")
       | SOME wmt =>
           let
             val wmt = simplifying wmt
             val deepest = deepestw wmt
             val ssize = wmtsize wmt
           in
             eprint ("WINNING! with pawn idx " ^ itos pawn_x ^ "\n");
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
     end)

  fun main s =
    case Int.fromString s of
      NONE => raise Chesstego "need int"
    | SOME x => dopawn x

end

val () = Params.main1 "Command-line argument: pawn x idx." Chesstego.main
  handle Chesstego.Chesstego s => print ("Chesstego: " ^ s ^ "\n")