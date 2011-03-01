(* Coin words with coinduction. *)
structure Coin =
struct
  
  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "wordlist.asc")
  val dict = Script.wordlist "wordlist.asc"

  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val cmp = Char.compare
    val n = 4
  end

  structure M = MarkovFn(M2C)

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  val chain = M.chain ()
  fun ows s = 
      M.observe_weighted_string { begin_symbol = chr 1,
                                  end_symbol = chr 0,
                                  weight = 1.0,
                                  chain = chain,
                                  string = explode s }
  val () = print "Observe...\n"
  val () = SimpleStream.app ows lines
  val () = print "Predict...\n"      

  fun state s = M.state (explode s)

  val beginstate = M.state (List.tabulate (M2C.n, fn _ => chr 1))
  val most_probable = (M.most_probable_paths { lower_bound = 0.000001,
                                               chain = chain,
                                               state = beginstate,
                                               end_symbol = #"\000" })
  val most_fake = Stream.filter (fn { string, p = _ } => not (dict (implode string))) most_probable
  val tops = StreamUtil.headn 100 most_fake

  (* XXX output includes end symbol. is this desired? fix here or in nmarkov. *)
  val () = print (Int.toString (length tops) ^ " top paths:\n");
  val () = app (fn { string, p } =>
                print (rtos9 p ^ " " ^ implode string ^ "\n")) tops

end