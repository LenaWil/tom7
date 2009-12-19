
(* For 'knights and rotations' *)

structure KandR =
struct

  local 
    val k = DES.key (0wxBADFEED0, 0wx22334455)
    val bad = ref (0w0 : Word32.word, 0w0 : Word32.word)
  in
    fun random () =
      let 
        val b = DES.encrypt k (!bad)
      in
        bad := b;
        #1 b
      end
    
    fun randint () =
      let
        val n = Word32.andb(random (), 0wxFFFFFF)
      in
        abs(Word32.toIntX n)
      end
  end

  val SIZE = 8
  val MAXI = 8

  exception KandR of string

  fun index (x, y) = y * SIZE + x
  (* return x,y *)
  fun coords i = (i mod SIZE, i div SIZE)

  fun transitions () =
    let
      (* ntrans holds the number of transitions out 
         of any square. vtrans holds the values of
         those transitions. (as indices into the
         array) *)
      val ntrans = Array.array(SIZE * SIZE, ~1)
      val vtrans = Array.array(SIZE * SIZE * MAXI, ~1)

      fun fillred (x, y) =
        let
          (* all possible knight's moves
             as coordinate pair deltas *)
          val l = [(2, 1), (2, ~1), (1, 2), (1, ~2),
                   (~2, 1), (~2, ~1), (~1, 2), (~1, ~2)]
          val d =
            List.mapPartial (fn (dx, dy) =>
                             if x + dx < SIZE andalso x + dx >= 0 andalso 
                                y + dy < SIZE andalso y + dy >= 0
                             then SOME (index (x + dx, y + dy))
                             else NONE) l
        in 
          Array.update (ntrans, index (x, y), length d);
          Util.for 0 (length d - 1)
          (fn i =>
           let in
             (*
             print (Int.toString x ^ "," ^ Int.toString y ^ " -> " ^
                    Int.toString (List.nth (d, i)) ^ "\n");
             *)
             Array.update (vtrans, (MAXI * index (x, y)) + i,
                           List.nth (d, i))
           end)
        end

      (* black transitions. could flip horizontally, vertically,
         or both. always three transitions *)
      fun fillblack (x, y) =
        let 
          val i = index(x, y)
          val xo = (SIZE - 1) - x
          val yo = (SIZE - 1) - y
        in
          Array.update(ntrans, i, 3);
          Array.update(vtrans, (MAXI * i) + 0, index(xo, yo));
          Array.update(vtrans, (MAXI * i) + 1, index(y,  xo));
          Array.update(vtrans, (MAXI * i) + 2, index(yo, x))
        end

      fun fill n =
        let val (x, y) = coords n
        in
          if (x + y) mod 2 = 1
          then fillblack (x, y)
          else fillred (x, y)
        end
    in
      Util.for 0 ((SIZE * SIZE) - 1) fill;
      (ntrans, vtrans)
    end

  fun ptrans (ntrans, vtrans) =
    let
      val lists =
        List.tabulate 
        (SIZE, 
         (fn y =>
          List.tabulate(SIZE,
                        (fn x =>
                         StringUtil.delimit ", " 
                         (List.tabulate(Array.sub(ntrans, index(x, y)),
                                        (fn i =>
                                         Int.toString 
                                         (Array.sub(vtrans,
                                                    (index(x,y) *
                                                     MAXI) + i)))))))))
    in
      print "Transition matrix: \n";
      print (StringUtil.table 75 lists);
      print "--------------------------\n"
    end

  fun pinv vinv =
    let
      val lists =
        List.tabulate 
        (SIZE, 
         (fn y =>
          List.tabulate(SIZE,
                        (fn x =>
                         StringUtil.delimit ", " 
                         (map Int.toString (Array.sub(vinv, index(x, y))))))))
    in
      print "Inverse matrix: \n";
      print (StringUtil.table 75 lists);
      print "--------------------------\n"
    end


  fun pboard b =
    let
      val lists =
        List.tabulate 
        (SIZE, 
         (fn y =>
          List.tabulate(SIZE,
                        (fn x =>
                         Int.toString (Array.sub(b, index(x, y)))))))
    in
      print "Solution board: \n";
      print (StringUtil.table 75 lists);
      print "--------------------------\n"
    end


  (* also keep track of the inverse transition graph *)
  fun invert (ntrans, vtrans) =
    let
      val vinv = Array.array(SIZE * SIZE, nil : int list)

      fun flow n =
        let
        in
          (* print (Int.toString n ^ " reaches...\n"); *)
          Util.for 0 (Array.sub(ntrans, n) - 1)
          (fn d =>
           let val dest = Array.sub(vtrans, (MAXI * n) + d)
           in
             (* print ("   " ^ Int.toString dest ^ "\n"); *)
             Array.update(vinv, dest, n :: Array.sub(vinv, dest))
           end)
        end
    in
      Util.for 0 ((SIZE * SIZE) - 1) flow;
      vinv
    end

  (* cover the board with a graph, starting at
     point (0,0) eagerly. Only allow closing the cycle
     at the start point *)
  fun makegraph () =
    let
      val (ntrans, vtrans) = transitions ()
      val inv = invert (ntrans, vtrans)

        (*
      val _ = ptrans (ntrans, vtrans)
      val _ = pinv inv
      *)

      val board = Array.array(SIZE * SIZE, ~1)

      (* simplest method. go until stuck,
         return number of edges placed *)
      fun go_simple depth idx =
        let 
          val nouts = Array.sub (ntrans, idx)
          val choice = if nouts > 0 then randint () mod nouts
                       else ~1

(*
          val _ = print ("\n\n*******  I am at " ^ Int.toString idx ^ " ****\n")
          val _ = print ("   there are " ^ Int.toString nouts ^ " choices:\n")
          val _ = print ("   " ^ StringUtil.delimit ", "
                         (List.tabulate(nouts, (fn i =>
                                                Int.toString
                                                (Array.sub(vtrans, (MAXI * idx)
                                                           + i))))) ^ "\n")
*)
        in
            case (nouts, choice) of 
              (0, _) => 
                let in
                  (* failure *)
                  (* print "failure\n"; *)
                  depth
                end
            | (1, 0) => 
                let in
                  (* print "finished cycle\n"; *)
                  Array.update(board, idx, 0);
                (* must choose it. might have succeeded! *) (depth + 1)
                end
            | (n, 0) => (* don't form cycle! new random *) go_simple depth idx
            | (nouts, choice) => 
            let
              (* Get real destination *)
              val choice = Array.sub(vtrans, (MAXI * idx) + choice)

              (* remove current square from out edges of any incident 
                 squares. we don't actually care about out edges from
                 this thing itself, since we won't come back *)

              val ins = Array.sub(inv, idx)

              fun removeat i = 
                let
                  val num = Array.sub(ntrans, i)
                  fun ra n =
                    if n >= num then raise KandR "bad inv graph"
                    else
                      if Array.sub(vtrans, (MAXI * i) + n) = idx
                      then 
                        Array.update(vtrans, (MAXI * i) + n,
                                     Array.sub(vtrans, (MAXI * i) + (num - 1)))
                      else ra (n + 1)
                in
                  ra 0;
                  Array.update(ntrans, i, num - 1)
                end
            in
              (*
              print (Int.toString idx ^ " could be reached by: " ^ 
                     StringUtil.delimit ", " (map Int.toString ins) ^ "\n");
               *)
              app removeat ins;
              Array.update(board, idx, choice);

              (*
              print "now the boards are:\n";
              ptrans (ntrans, vtrans);
              pinv inv;
               *)

              go_simple (depth + 1) choice
            end
        end

      val d = go_simple 0 0
    in
      (d, board)
    end

  (* New strategy alternates phases, adding edges on an UNDIRECTED
     graph. (Now, in a solved puzzle each square has two undirected
     edges, pointing to its two neighbors.)

     The "solve" phase adds in edges that MUST be present if the current
     state is going to be successful. Call "nec(x)" the number of remaining
     edges before square x is finished (ie, has degree 2). If nec(x) > 0
     and outgoing_possibilities(x) = nec(x), then these edges are required,
     so we add them. If nec(x) < outgoing_possibilities(x), then we can
     give up. *)

  datatype node =
      OPEN
    | ONE of int
    | TWO of int * int


  (* success *)
  exception Succeed of node Array.array

  fun solve () =
    let

      (* working arrays *)
      val (ntrans, vtrans) = transitions ()
      val inv = invert (ntrans, vtrans)
      val board = Array.array(SIZE * SIZE, OPEN)
      
      fun solve_phase () =
        let
          val needy =
            Util.ford 0 ((SIZE * SIZE) - 1) nil
            (fn (i, l) =>
             let 
               val avail = Array.sub(ntrans, i)
               val cell = Array.sub(board, i)
             in
               case cell of
                 OPEN => { idx = i, avail = avail, cell = cell } :: l
               | ONE _ => { idx = i, avail = avail, cell = cell } :: l
               | TWO _ => l
             end)

          fun needed OPEN = 2
            | needed (ONE _) = 1
            | needed (TWO _) = 0

          (* sort it by urgency. The neediest ones are the ones
             #possibilities - #needed is smallest *)
          val needy =
            ListUtil.sort (fn ({avail = avail1,
                                cell = cell1, idx = _},
                               {avail = avail2,
                                cell = cell2, idx = _}) =>
                           Int.compare (avail1 - needed cell1,
                                        avail2 - needed cell2)) needy

          (* done!! *)
          fun greedy nil = raise Succeed board
            | greedy (l as ({avail, cell, idx}::rest)) =
            let val urgency = avail - needed cell
            in
              if urgency < 0
              then () (* fail *)
              else 
                let
                in
                  () (* XXX HERE *)
                end
            end
        in
          (* try satisfying things that need to be greedily satisfied,
             now. then guess. *)
          greedy needy
        end
    in
      solve_phase ()
    end

  (* apparently the solutions are too sparse to do it this way for 8x8. *)
  fun keeptrying n =
    let
      val (d, board) = makegraph ()
    in
      if (d < n) then keeptrying n
      else (d, board)
    end

end