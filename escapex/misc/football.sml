
structure Football =
struct

  (* needs to be large enough to hold number of actual bits *)
    structure W = Word64
  type state = W.word

  val actual = 38

(*
   *  0  1  2  3  4  _  5  6  *
   7  _  8  9 10  _ 11  _ 12 13
  14 15 16 17 18 19 20  _  _ 21
  22 23 24  _ 25 26 27 28 29 30
   * 31 32 33  _ 34 35 36 37  *
*)

  fun mkop (n, bits) =
      (n, foldr (fn (b, x) => W.orb(x, W.<<(0w1, Word.fromInt b))) 0w0 bits)

  val ops = 
      map mkop
    [(* top row *)
     (1,  [1, 8, 16, 24, 32,  0]),
     (2,  [2, 9, 17,  25, 26, 27, 28, 29, 30]),
     (3,  [3, 10, 18, 25]),
     (4,  [4,   8, 9, 10,  15, 23, 31]),
     (5,  [6, 12,  21]),
     (* top left, top right *)
     (6,  [7, 14, 22,  0, 1, 2, 3, 4,  11, 20, 27, 35,  34, 26, 19]),
     (7,  [5, 6, 13, 21, 30]),
     (* right #1 *)
     (8,  [5, 12, 13]),
     (* left #2 #3 *)
     (9,  [7,  14, 15, 16, 17, 18, 19, 20, 28, 36]),
     (10, [22, 23, 24]),
     (11, [2, 9, 17,  25, 26, 27, 28, 29, 30,  21,  12, 6]),
     (* bottom left, bottom right *)
     (12, [7, 14, 22,  31, 32, 33]),
     (13, [13, 21, 30,  34, 35, 36, 37]),
     (* bottom row *)
     (14, [31, 23, 15, (* 8, -- twice *) 1, 32, 24, 16,  9, 10,  4]),
     (15, [33]),
     (16, [34, 35, 36, 37]),
     (17, [36, 28, 20, 19, 18, 17, 16, 15, 14,  37, 29])
     ]

  val nops = length ops

  fun power nil = [(nil, 0w0)] (* can only achieve 0 word, pressing
                                  no buttons *)
    | power ((x, w) :: rest) =
      (* for each possibility in tail, press or don't... *)
      let
	  val pr = power rest
      in
	  (* do *)
	  map (fn (plan, res) => (x :: plan, W.xorb(res, w))) pr @
	  (* don't *)
	  pr
      end

  val possibilities = power ops

  fun bits_set w =
      let
	  val r = ref 0
      in
	  Util.for 0 38
	  (fn x =>
	   r := !r + 
	   (if W.andb(w, W.<<(0w1, Word.fromInt x)) = 0w0
	    then 0 else 1));
	  !r
      end

  fun comparebybits (w1, w2) = Int.compare(bits_set w1, bits_set w2)

  val possibilities = ListUtil.sort (ListUtil.bysecond
				     comparebybits) possibilities

  (* get rid of things that are too trivial *)
(*
  val possibilities = List.filter (fn (plan, res) => 
				   length plan > 5 andalso
				   length plan < (nops - 5)) possibilities
*)

  val () = app (fn (plan, res) =>
		let in
		    print (W.toString res ^ " (" ^ 
			   Int.toString (length plan) ^ "): ");
		    app (fn p => print (Int.toString p ^ " ")) plan;
		    print "\n"
		end) possibilities

end

