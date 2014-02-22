structure Chesstego =
struct

  exception Chesstego of string
  val itos = Int.toString

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

  fun init () =
    Array.fromList
    (map (fn x => SOME (x, Black, false))
     [Rook,  Knight, Bishop, King,  Queen, Bishop, Knight, Rook,
      Pawn,  Pawn,   Pawn,   Pawn,  Pawn,  Pawn,   Pawn,   Pawn] @

     [NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE,
      NONE, NONE,  NONE,  NONE, NONE, NONE,  NONE,  NONE] @

     map (fn x => SOME (x, White, false))
     [Pawn,  Pawn,   Pawn,   Pawn,  Pawn,  Pawn,   Pawn,   Pawn,
      Rook,  Knight, Bishop, King,  Queen, Bishop, Knight, Rook])

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
  and blackmovetree =
    B of ((int * int) * (int * int) * whitemovetree) list

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
        case losing newboard (depth - 1) of
          NONE => ()
        | SOME bmt => raise Winning (W (src, dst, bmt))
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
              in moves := (fsrc, fdst, wmt) :: !moves
              end
        end
    in
      app_moves b onemove;
      SOME (B (!moves))
    end handle Losing => NONE

  (* XXX try all pawns *)
  val startboard = init_with_kings (4, 1, 0, 7)

  fun xytos (x, y) = String.substring ("ABCDEFGH", x, 1) ^
    itos (7 - y + 1)

  fun pad 0 = ""
    | pad n = " " ^ pad (n - 1)

  fun wmtsize (W (_, _, bmt)) = 1 + bmtsize bmt
  and bmtsize (B l) = foldr op+ 1 (map (fn (_, _, wmt) => wmtsize wmt) l)

  fun printwmt indent (W (src, dst, bmt)) =
    let in
      print (pad indent ^ "White: " ^ xytos src ^ " -> " ^ xytos dst ^ ":\n");
      printbmt (indent + 2) bmt
    end

  and printbmt indent (B nil) =
    print (pad indent ^ "** black has no moves **\n")
    | printbmt indent (B l) =
    app (fn (src, dst, wmt) =>
         let in
           print (pad indent ^
                  "If black: " ^ xytos src ^ " -> " ^ xytos dst ^ " then:\n");
           printwmt (indent + 2) wmt
         end) l

  val DEPTH = 10
  val () = print ("Searching to depth " ^ itos DEPTH ^ "\n")
  val () = case winning startboard DEPTH of
    NONE => print ("No winning strategy in " ^ itos DEPTH ^ "\n")
  | SOME wmt =>
      let in
        print ("WINNING!\n");
        print ("Strategy size: " ^ itos (wmtsize wmt) ^ "\n");
        (* printwmt 0 wmt; *)
        ()
      end

end
