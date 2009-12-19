
(* This is an "inverse solver", that is, a program that generates puzzles.

   It works by expanding the entire state graph and then finding the
   most distant ("hardest") state that satisfies a certain predicate
   (such as being a "solved" state). 

   Given a correct state generator, this basic framework can work for
   many kinds of puzzles. Currently it is set up for sliding "gold"
   blocks puzzles where all blocks are indistinguishable and end up on
   certain target squares, and sokoban-like levels with a fixed number
   of grey blocks. Both of these work by a reverse method, starting
   from the solved state and working backwards to find the most distant
   state from which the solved state can be reached.

   There is also an experimental "Escape" solver that implements more
   tiles but is much much less efficient. This is a "forward" solver,
   which works by taking a starting configuration and finding a (most
   distant) solved state (player on exit). Here, the length of this
   solution is not indicative of the difficulty of the level, so it
   is mainly useful for finding solutions to levels, rather than
   generating difficult ones. 

   Actually, there are a lot of retraction arguments now, in files
   called retract-*.sml. *)

(* The inverse solver is parametrized on the "game", which defines the
   state space and its transition functions. A game has the following
   signature: *)

signature GAME =
sig
    type state

    val hash : state -> Word32.word
    val eq : state * state -> bool

    (* app_successors (f, s)
       apply f to every successor to s, along with its distance
       from the source *)
    val app_successors : (((state * int) -> unit) * state) -> unit
        
    (* the inital state(s) *)
    val initials : state list

    val tostring : state -> string

    (* short code *)
    val tocode : state -> string

    (* we'll find only paths to accepting states, according to
       this notion of accepting *)
    val accepting : state -> bool

    (* if true, then return the shortest path(s). if false, return 
       the longest. *)
    val findshortest : bool

    (* should the state list be reversed when printing? *)
    val reverse : bool

    (* treat distances as always 1 *)
    val constant_distance : bool
end


functor Search(structure G : GAME
               val stopat : int option) =
struct

    type priority = Word16.word
    val pcompare = Word16.compare
    val ptoi = Word16.toInt
    val itop = Word16.fromInt
    val pzero = Word16.fromInt 0 : priority

    structure H = HeapFn(type priority = priority
                         val compare = pcompare)

    val NBEST = 3

    exception Search of string

    (* length of histogram data *)
    val NHIST = 45
    (* list storing the last NHIST frontier sizes,
       with the newest at the head *)
    val histdata = ref (List.tabulate(NHIST, fn _ => 0))

    (* make hash table 
       PERF: better if we can guess the approximate table size... *)
    structure E :>
    sig
        type hentry
        val hentry :
            { (* PERF could maybe save mem at expense of time by getting
              this from the handle instead *)
              me : G.state,
              
              (* best predecessor so far (closest to any initial state).
                 if equal to me, then this is an initial state. *)
              pred : G.state,
              
              (* distance between me and the predecessor state *)
              (* can be optimized out in the case that it is constant, eg, 1 *)
              dist : int,
              
              (* total depth *)
              (* can be optimized out when we search the path to compute depth *)
              depth : priority,
              
              (* handle into priority queue; might have gone bad
                 (test with H.valid) *)
              hand : H.hand } -> hentry

        val me : hentry -> G.state
        val pred : hentry -> G.state
        val dist : hentry -> int
        val depth : hentry -> priority
        val hand : hentry -> H.hand
    end =
    struct
        type hentry =
            { me : G.state,
              pred : G.state,
(*              dist : int, *)
              depth : priority,
              hand : H.hand }
            
        fun hentry {me, pred, dist, depth, hand} = {me=me, pred=pred, 
                                                    depth=depth, hand=hand}

        (* XXX *)
        val _ = if G.constant_distance
                then ()
                else raise Search "Oops, I broke non-constant distances for PERF"

        val me : hentry -> G.state = #me
        val pred : hentry -> G.state = #pred
(*        val dist : hentry -> int = #dist *)
        fun dist _ = 1
        val depth : hentry -> priority = #depth
        val hand : hentry -> H.hand = #hand
    end

    (* should probably be functor parameter... *)
    val HASH_SIZE = 8000009
    (* XXX *)
    val HASH_SIZE = 14000029

    structure HEL :>
    sig
        type hel
        val empty : hel
        val list : hel -> E.hentry list
        val find : (E.hentry -> bool) -> hel -> E.hentry option
        val filter : (E.hentry -> bool) -> hel -> hel
        val add : E.hentry * hel -> hel
        val app : (E.hentry -> unit) -> hel -> unit
    end =
    struct
        type hel = E.hentry vector
        val empty = Vector.fromList nil : hel

        (* PERF can usually be replaced by iterating *)
        fun list v = Vector.foldr op:: nil v
        val find = Vector.find
        val filter = VectorUtil.filter
        fun add (h, t) = Vector.fromList (h :: list t)
        val app = Vector.app
    end

    val table = Array.array (HASH_SIZE, HEL.empty)
    val h = H.empty () : G.state H.heap

    fun indexof s =
        let
            val h = G.hash s
            val i = Word32.mod (h, Word32.fromInt HASH_SIZE)
        in
            Word32.toIntX i
        end

    (* ignores depth field. if this is called instead of just reading
       depth, then the depth field will never be used, so it should be
       optimized out, saving some memory. Note: this function is very
       expensive! If used, it often accounts for a majority of the
       execution time, when we search for the best state at the end. *)
    fun depth_path acc (s, pred) =
        if G.eq (s, pred)
        then acc (* initial *)
        else
            let
                val i = indexof pred
                val l = Array.sub(table, i)
                fun go nil = raise Search "path error!"
                  | go ((e : E.hentry) ::rest) =
                    let val me' = E.me e
                        val pred' = E.pred e
                        val dist = E.dist e
                    in
                        if G.eq (me', pred)
                        then (* found it *)
                            depth_path (acc + dist) (me', pred')
                        else go rest
                    end
            in
                go (HEL.list l)
            end

    fun printhistogram () =
        let 
            val h = rev (!histdata)
            val HEIGHT = 10
            val max = foldl Int.max 0 h
            val min = foldl Int.min (hd h) h
        in
            Util.for 0 HEIGHT
            (fn x =>
             let in
                 app (fn z =>
                      let
                          val frac = real (HEIGHT - x) / real HEIGHT
                          val slice = real (max - min) / real HEIGHT
                          val cutoff = min + Real.trunc(frac * real (max - min))
                      in
                          TextIO.output1
                          (TextIO.stdErr,
                           if z > cutoff
                           then 
                               (if z - cutoff < Real.trunc(slice / 2.0)
                                then #"."
                                else #":")
                           else #" ")
                      end) h;

                 (if x = 0
                  then TextIO.output(TextIO.stdErr, " <-- " ^ Int.toString max)
                  else if x = HEIGHT
                       then TextIO.output(TextIO.stdErr, " <-- " ^ Int.toString min)
                       else ());

                 TextIO.output (TextIO.stdErr, "\n")
             end)
        end

    local
        val scount = ref 0
        val hsize = ref (0.0, 0.0, 0, 0)
    in
        fun seen s =
            let in
                scount := !scount + 1;

                (* occasionally hash-cons the heap *)
                if !scount = 2000000
                then MLton.shareAll ()
                else ();
                 
                if (!scount = 5) orelse (!scount mod 50000 = 0)
                then 
                    let 
                    in
                      (* only rarely, because it is slow... *)
                      if (!scount < 100) orelse !scount = 1000000
                         orelse !scount = 5000000
                      then 
                          let val hs = MLton.size h
                              val ts = MLton.size table
                          in
                              hsize := (real hs / real (H.size h),
                                        real ts / real (!scount), hs, ts)
                          end
                      else ();

                      histdata := (H.size h) :: List.take(!histdata, NHIST - 1);
                      TextIO.output (TextIO.stdErr, 
                                     "--------------------------------------------------\n");
                      TextIO.output (TextIO.stdErr, "States seen: " ^ Int.toString (!scount) ^ 
                                     "  Frontier size: " ^ Int.toString (H.size h) ^
                                     "\n");
                      TextIO.output (TextIO.stdErr, "State size: >= " ^ Int.toString (MLton.size s)
                                     ^ " bytes" ^
                                     "    In heap: " ^ Real.fmt (StringCvt.FIX (SOME 2)) (#1 (!hsize))
                                     ^ " | " ^ Real.fmt (StringCvt.FIX (SOME 2)) (#2 (!hsize)) ^ "\n");
                      (* XXX no, should approx based on last measurement and current count *)
                      TextIO.output (TextIO.stdErr,
                                     "Table mem: " ^ Int.toString (#3 (!hsize)) ^ "  front mem: " ^
                                     Int.toString (#4 (!hsize)) ^ "\n");

                      (* include depth? *)
                      TextIO.output (TextIO.stdErr, G.tostring s ^ "\n");

                      printhistogram ()
                    end
                else ()
            end
        fun nseen () = !scount 
    end

    (* visit s', coming from s and with depth d *)
    fun visit (d : priority) dist s s' =
        let val i = indexof s'
            val l = Array.sub(table, i)
        in
            (* have we seen it at all yet? *)
            case HEL.find (fn e => G.eq (E.me e, s')) l of
                (* no? then put it in the frontier *)
                NONE => 
                    let val hand = H.insert h d s'
                    in
                        (* and in the hash table... *)
                        Array.update(table, i, HEL.add (E.hentry {me=s', pred=s, hand=hand, 
                                                                  dist=dist, depth=d}, l));
                        seen s
                    end
              | SOME ee => 
                  let
                      val me = E.me ee
                      val pred = E.pred ee
                      val hand = E.hand ee
                      val oldd = E.depth ee
                  in
                    if H.valid hand
                    then (* still in frontier, but maybe we need to
                            update it. *)
                        let (* val (oldd, _) = H.get h hand *)
                        in
                            if Word16.<(d, oldd)
                            then 
                                let in
                                    H.adjust h hand d;
                                    Array.update
                                    (table, i, 
                                     HEL.add(E.hentry {me=s', pred=s, hand=hand, 
                                                       dist=dist, depth=d},
                                             HEL.filter (fn e => not (G.eq(E.me e, s'))) l))
                                end
                            else ()
                        end
                    else () 
                        (* PERF this check is just for sanity *)
                      (*
                      let val best = depth 0 (me, pred)
                      in
                      if d < best
                      then raise Search "dijkstra was wrong!"
                      else ()
                      end
                      *)
                  end
        end


    fun loop () =
        case H.min h of
            NONE => () (* done -- frontier empty *)
          | SOME (d : priority, s) =>
              if (case stopat of
                    NONE => true
                  | SOME x => x > nseen())
              then
                let in
                    G.app_successors
                    ((fn (s', dist) => 
                      let val dist = if G.constant_distance then 1 else dist
                      in
                        visit (Word16.+(d, itop dist)) dist s s'
                      end), 
                     s);
                    loop ()
                end
              (* give up (solutions will be approximate) *)
              else TextIO.output (TextIO.stdErr, "Stopping early!\n")

(*
    val () = app (fn s =>
                  let in
                      print "initial states:\n";
                      print "\n";
                      print (G.tostring s);
                      print "\n....................\n"
                  end) G.initials
*)
    val () = app (fn s => visit pzero 0 s s) G.initials

    val () = loop ()

    val () = print ("Total states: " ^ Int.toString (nseen ()) ^ "\n")
    val () = TextIO.output (TextIO.stdErr, "Total states: " ^ Int.toString (nseen ()) ^ "\n")

    val naccept = ref 0

    val furthest =
        let
            val () = print "done! finding furthest states...\n";

            val best = ref (nil : ((G.state * G.state) * int) list)

            fun lookat e =
                let
                    val me = E.me e
                    val pred = E.pred e
                    val d = E.depth e
                in
                    if G.accepting me
                    then
                    let
                      val cmp = if G.findshortest 
                                then ListUtil.bysecond Int.compare
                                else ListUtil.Sorted.reverse (ListUtil.bysecond Int.compare)

                      val l =
                        ListUtil.Sorted.insert cmp (!best) ((me, pred), ptoi d)
                    in
                      naccept := !naccept + 1;
                      (* but only keep the five best *)
                      if length l > NBEST
                      then best := List.take (l,NBEST)
                      else best := l
                    end
                    else ()
                end
        in
            Array.app (HEL.app lookat) table;
            !best
        end

    val () = print ("Total accepting: " ^ Int.toString (!naccept) ^ "\n")
    val () = TextIO.output (TextIO.stdErr, "Total accepting: " ^ 
                            Int.toString (!naccept) ^ "\n")

    (* and print them. *)
    val () = 
        let

            fun indent n s =
                StringUtil.replace "\n" ("\n" ^ StringUtil.tabulate n #" ") s

            fun solution acc (s, pred) =
                if G.eq (s, pred)
                then if G.reverse 
                     then rev (s :: acc)
                     else (s :: acc) (* initial *)
                else
                    let
                        val i = indexof pred
                        val l = Array.sub(table, i)
                        fun go nil = raise Search "solve error!"
                          | go (e :: rest) =
                            let
                                val me' = E.me e
                                val pred' = E.pred e
                            in
                                if G.eq (me', pred)
                                then (* found it *)
                                    solution (me' :: acc) (me', pred')
                                else go rest
                            end
                    in
                        go (HEL.list l)
                    end
         
            fun one ((s, prev), d) =
                let
                    val sol = solution nil (s, prev)
                in
                    print ("--------------------------------------------------\n");
                    print ("            DISTANCE " ^ Int.toString d ^ ": (code " ^
                           G.tocode s ^ ")\n");
                    print ("--------------------------------------------------\n");
                    print (G.tostring s ^ "\n");
                    ListUtil.appi 
                       (fn (s, i) =>
                          let in
                              print ("--------------------------------------------------\n");
                              print ("Move " ^ Int.toString i ^ " (code " ^
                                     G.tocode s ^ "):");
                              print (indent 4 ("\n" ^ G.tostring s) ^ "\n")
                          end) sol
                end

        in
            app one furthest;
            (* need one at the end for slide-mode *)
            print ("--------------------------------------------------\n")
        end

    (* then print out the whole table, if it is small enough *)
    val _ = 
        if nseen () < 500
        then
        let
            val _ = print "ALL STATES:\n"

            fun lookat e =
                let
                    val me = E.me e
                    val pred = E.pred e
                    val dist = E.dist e
                    val d = E.depth e
                in
                    print ("board " ^ G.tocode me ^ " (pred " ^ G.tocode pred ^ " (dist " ^
                           (if G.constant_distance then "_" else Int.toString dist) ^ ")) depth " ^ 
                           Int.toString (ptoi d) ^ "\n");
                    print (G.tostring me ^ "\n")
                end
        in
            Array.app (HEL.app lookat) table
        end
    else ()

end

(* generally useful stuff *)
structure RetractParse =
struct
  exception Parse of string

  val WIDTH = 16
  val HEIGHT = 16
  val WIDTHR = 18
  val HEIGHTR = 18

  (* bit masks for directions *)
  val UP = 0w1 : Word32.word
  val DOWN = 0w2 : Word32.word
  val LEFT = 0w4 : Word32.word
  val RIGHT = 0w8 : Word32.word

  (* PERF maybe array? *)
  fun dirchange 0w1 = ~WIDTHR
    | dirchange 0w2 = WIDTHR
    | dirchange 0w4 = ~1
    | dirchange 0w8 = 1
    | dirchange _ = 0

  (* parses a standard 16x16 board. return any extra markers
     found in a list with their indices. *)
  fun parse_walls filename =
      let
          val f = TextIO.openIn filename

          fun readuntil c =
              case TextIO.input1 f of
                  NONE => raise Parse ("eof looking for chr " ^ 
                                         Int.toString (ord c))
                | SOME cc => if c = cc then ()
                             else readuntil c

          val board = Array.array(WIDTHR * HEIGHTR, 0w0 : Word32.word)

          val ents = ref (nil : (char * int) list)

          fun readtop y =
              let in
                  Util.for 0 (WIDTH - 1)
                  (fn x =>
                   (* read + *)
                   let val above = y * WIDTHR + (x + 1)
                       val below = (y + 1) * WIDTHR + (x + 1)
                   in
                       ignore (TextIO.input1 f);
                       case TextIO.input1 f of
                           SOME #"-" => 
                           let in
                               Array.update(board,
                                            above,
                                            Word32.orb
                                            (Array.sub(board, above),
                                             DOWN));
                               Array.update(board,
                                            below,
                                            Word32.orb
                                            (Array.sub(board, below),
                                             UP))
                           end
                         | SOME #" " => ()
                         (* XXX support v ^ *)
                         | SOME c => raise Parse ("bad char " ^ implode [c])
                         | NONE => raise Parse "eof"
                   end);
                  readuntil #"\n"
              end handle e => raise e

          fun readmid y =
              let in
                  if TextIO.input1 f = SOME #"|" 
                  then ()
                  else raise Parse "every row should start with |";

                  Array.update(board, (y + 1) * WIDTHR,
                               Word32.orb(Array.sub(board, (y + 1) * WIDTHR),
                                          RIGHT));

                  Array.update(board, (y + 1) * WIDTHR + 1,
                               Word32.orb(Array.sub(board, (y + 1) * WIDTHR + 1),
                                          LEFT));


                  Util.for 0 (WIDTH - 1)
                  (fn x =>
                   let
                       val left = (y + 1) * WIDTHR + (x + 1)
                       val right = (y + 1) * WIDTHR + (x + 2)
                   in
                       (* print ("reading for cell " ^
                          Int.toString left ^ "/" ^
                          Int.toString right ^ "\n"); *)
                       (* entity cell *)
                       (case TextIO.input1 f of
                            SOME #" " => ()
                          | SOME c => ents := (c, left) :: !ents
                          | NONE => raise Parse "eof(cell)");

                       (case TextIO.input1 f of
                            SOME #"|" => 
                                let in
                                    Array.update(board,
                                                 left,
                                                 Word32.orb
                                                 (Array.sub(board, left),
                                                  RIGHT));
                                    Array.update(board,
                                                 right,
                                                 Word32.orb
                                                 (Array.sub(board, right),
                                                  LEFT))
                                end
                          | SOME #" " => ()
                          | SOME c => raise Parse ("bad midchar " ^
                                                     implode [c])
                          | NONE => raise Parse "eof(mid)")
                   end);
                  readuntil #"\n"
              end handle e => raise e
      in
         Util.for 0 (HEIGHT - 1)
            (fn y =>
             let in
                 readtop y;
                 readmid y
             end);

         (* and one more row on the bottom *)
         readtop HEIGHT;

         TextIO.closeIn f;

         {board = board, ents = !ents}
      end 
end

