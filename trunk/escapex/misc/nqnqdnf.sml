
structure NQNQDNF =
struct
  datatype color = X | O

  datatype pos = L | M | R

  exception NQ of string

  fun parity b nil = not b
    | parity b (O :: t) = parity b t
    | parity b (X :: t) = parity (not b) t

  (* satisfies if, for every column, the parity is even *)
  fun satisfies mtx pl =
      (* select the appropriate columns *)
      let
          fun third [h] = [h]
            | third [h, _] = [h]
            | third [h, _, _] = [h]
            | third (h :: _ :: _ :: t) = h :: third t

          fun cvt (L, _::_::t) = third t
            | cvt (M, _::t) = third t
            | cvt (R, t) = third t

          val newrows = ListPair.map cvt (pl, mtx)
          val cols = ListUtil.transpose newrows
      in
          length pl = length mtx orelse raise NQ "not equal";
          List.all (parity true) cols
      end

  (* returns all satisfying assignments *)
  fun allsats mtx =
      let
          fun allp 0 = [[]]
            | allp n =
              let val rests = allp (n - 1)
              in
                  (map (fn l => L :: l) rests) @
                  (map (fn l => M :: l) rests) @
                  (map (fn l => R :: l) rests)
              end

          val perms = allp (length mtx)
      in
          List.filter (satisfies mtx) perms
      end

  val m_test =
      (*   v        v   *)
      [[X, X, X, X, X, X],
       [X, O, X, X, O, X],
       [X, X, O, X, O, O],
       [O, X, X, X, O, X],
       [O, X, X, X, X, O]]

  val brian =
      [[O, X, O, X, X, X, X, O, O, O, O, O, O, O, X],
       [X, X, O, O, O, O, X, O, X, X, O, X, X, X, O],
       [O, O, X, X, X, X, X, X, X, O, O, O, O, O, X],
       [O, X, O, X, O, O, X, O, O, X, X, O, O, X, X],
       [O, O, X, X, X, O, X, X, O, X, O, O, O, X, X]]

  (* slow, but good quality pseudo-random nums *)
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
  end


  fun randm w h =
      let
          fun randp _ =
              case Word32.andb (Word32.>> (random (), 0w3),
                                0w1) of
                  0w0 => O
                | _ => X

      in
          List.tabulate (h, (fn _ =>
                             List.tabulate (w, randp)))
      end

  (* Special to NQDNF.

     Cookable if, when the assignment has R
     in the last position, and the first column
     has parity even, and the topmost element in
     the first column is X. *)
  fun cooks mtx pl =
      (* select the appropriate columns *)
  let
      fun third [h] = [h]
        | third [h, _] = [h]
        | third [h, _, _] = [h]
        | third (h :: _ :: _ :: t) = h :: third t

      fun cvt (L, _::_::t) = third t
        | cvt (M, _::t) = third t
        | cvt (R, t) = third t

      val newrows = ListPair.map cvt (pl, mtx)
      val cols = ListUtil.transpose newrows
  in
      length pl = length mtx orelse raise NQ "not equal";
      case cols of
          ((l as (X::_))::rest) => 
              parity false l andalso List.all (parity true) rest
        | _ => false
  end

  fun cookable mtx =
      let
          fun allp 0 = [[]]
            | allp n =
              let val rests = allp (n - 1)
              in
                  (map (fn l => L :: l) rests) @
                  (map (fn l => M :: l) rests) @
                  (map (fn l => R :: l) rests)
              end

          (* last assignment must be R *)
          val perms = 
              map (fn l => l @ [R]) 
              (allp (length mtx - 1))
      in
          List.filter (cooks mtx) perms
      end




  fun rand_unsolvable w h =
      let
          val m = randm w h
      in
          case allsats m of
              nil => m
            | _ => rand_unsolvable w h
      end

  fun rand_onlycookable w h =
      let
          val m = randm w h
      in
          case allsats m of
              nil => (case cookable m of
                          l as [_] => (l, m)
                        | _ => rand_onlycookable w h)
            | _ => rand_onlycookable w h
      end

  fun pr m =
      print 
      (StringUtil.table 60
       (map (map (fn X => "X" | O => "O")) m))

  fun go w h =
      let val (l, m) = rand_onlycookable w h
      in
          pr m;
          (l, m)
      end
end