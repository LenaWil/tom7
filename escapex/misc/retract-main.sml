
(*
structure Y = Yellow5AllRetract(val filename = "board.txt")
structure R = Search(Y)
*)

(*
structure G = Grey6Retract(val filename = "soko.txt")
structure R = Search(G)
*)

(*
structure E = EscapeFwd(val filename = "esc.txt")
val _ = print (E.tostring E.initial ^ "\n")
structure R = Search(E)
*)

(*
structure E = Escape(val filename = "escape.txt")
val _ = print (E.tostring E.initial ^ "\n")
structure R = Search(E)
*)

(* these are leaked when running out of memory on Cygwin *)

val () = FSUtil.dirapp (fn {name = s, ...} => 
                        if StringUtil.matchhead "FromSpace" s
                        then (TextIO.output(TextIO.stdErr,
                                            "removing " ^ s ^ "..\n");
                              OS.FileSys.remove ("/tmp/" ^ s))
                        else ())
                       "/tmp"

val () = print "                         -*- slide -*- \n"
(*
structure B = Bomb(val nbombs = 6
                   val timers = [0,1]
                   val filename = "bomb.txt")
val _ = print (B.tostring B.initial ^ "\n")
structure R = Search(B)
*)
(*
structure S = Steel(val filename = "steel.txt")
val _ = print (S.tostring S.initial ^ "\n")
structure R = Search(S)
*)
(*
structure S = Slider(val filename = "slider.txt"
                     val flip_every_move = true)
(* val _ = print (S.tostring (hd S.initial) ^ "\n") *)
structure R = Search(structure G = S
                     val stopat = SOME 13000000)
*)

(*
structure Y = Yellow5AllRetract(val filename = "yellow5.txt")
structure R = Search(structure G = Y
                     val stopat = SOME 15000000)

*)
(*
structure E = EscapeFwd(val filename = "comp3.txt"
                        val finalname = SOME "comp3.fin")

val () = E.hintlegal :=
    (fn {guy, board} =>
     (* in the first row, from right to left, there
        must be three steel before we're allowed to
        see any grey. *)
     let
         fun check nsteel ~1 = true
           | check 3 _ = true
           | check nsteel n =
             (case Vector.sub(board, E.index(n, 0)) of
                  E.STEEL => ((* TextIO.output(TextIO.stdErr, "steel\n"); *)
                              check (nsteel + 1) (n - 1))
                | E.GREY => ((* TextIO.output(TextIO.stdErr, "grey!\n"); *)
                             false)
                | _ => check nsteel (n - 1))
     in
         check 0 (E.width - 1)
     end)

structure R = Search(structure G = E
                     val stopat = SOME 6000000)
*)

(*
structure B = Bomb(val nbombs = 6
                   val timers = [0,1]
                   val filename = "bomb.txt")
val _ = print (B.tostring B.initial ^ "\n")
structure R = Search(B)
*)

(*
structure R = Search(structure G = Football
                     (* we will stop at nothing!! *)
                     val stopat = NONE)
*)
(*
structure Hugbot = Hugbot(val permute = false
                          val filename = "hugbug.txt")
fun showdeep depth =
    let
        fun show 0 (state, dist) = ()
          | show n (state, dist) = 
            let
                fun indent n s =
                    StringUtil.replace "\n" ("\n" ^ StringUtil.tabulate n #" ") s
                val d = depth - n
            in
                print (indent (4 * (d + 1)) ("DEPTH " ^ Int.toString dist ^ ":\n"));
                print (indent (4 * (d + 1)) (Hugbot.tostring state));
                print "\n---------------------------\n";
                Hugbot.app_successors (show (n - 1), state)
            end
    in
        show depth
    end

val () =
    let in
        print "Showing successors of this state:\n";
        print (Hugbot.tostring (hd Hugbot.initials));
        print "\n\n"
    end

val () = Hugbot.app_successors (showdeep 1, hd Hugbot.initials)
*)

(* require in this order *)
(*
structure Hugbot = Hugbot(val permute = true
                          val filename = "hug.txt")
structure H = Search(structure G = Hugbot
                     val stopat = SOME 25000000)
*)

structure Hugbot = Hugblock(val permute = true
                            val nbots = 1
                            val nblocks = 5
                            structure BW = Word5
                            (* nbots + nblocks + 1 (guy) + 1 (turn) *)
                            structure F = FixedWordVec_5_8
                            val filename = "hug.txt")
structure H = Search(structure G = Hugbot
                     val stopat = SOME 25000000)
