(* Coin words with coinduction. *)
structure Coin =
struct

(*  
  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "wordlist.asc")
  val dict = Script.wordlist "wordlist.asc"
*)

  (* val DICTFILE = "sowpods.txt" *)
  val DICTFILE = "zingarelli2005.txt"

  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar DICTFILE)
  val dict = Script.wordlist DICTFILE


(*
  structure M2C : NMARKOVCMPARG =
  struct
    type symbol = char
    val cmp = Char.compare
    val n = 4
  end
*)

  val BEGIN_SYMBOL = chr (ord #"z" + 1)
  val END_SYMBOL = chr (ord #"z" + 2)
  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val n = 1 (* 3 *)
    val radix = 28
    fun toint c = ord c - ord #"a"
    fun fromint x = chr (x + ord #"a")
  end

  structure M = MarkovFn(M2C)

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  val chain = M.chain ()
  val alphabetic = StringUtil.charspec "a-z"
  fun ows s = 
      let val s = StringUtil.lcase s
      in
          if StringUtil.all alphabetic s
          then 
              M.observe_weighted_string { begin_symbol = BEGIN_SYMBOL,
                                          end_symbol = END_SYMBOL,
                                          weight = 1.0,
                                          chain = chain,
                                          string = explode s }
          else ()
      end
  val () = print "Observe...\n"
  val () = SimpleStream.app ows lines
  val () = print "Predict...\n"      

  fun state s = M.state (explode s)

  val beginstate = M.state (List.tabulate (M2C.n, fn _ => BEGIN_SYMBOL))
  val most_probable = (M.most_probable_paths { lower_bound = 0.000001,
                                               chain = chain,
                                               state = beginstate,
                                               end_symbol = END_SYMBOL })
  val most_fake = Stream.filter (fn { string, p = _ } => not (dict (implode string))) most_probable
  val tops = StreamUtil.headn 100 most_fake

  fun prprob s =
      let val s = StringUtil.lcase s
      in
          print ("Probability of [" ^ s ^ "]: " ^ 
                 Real.toString (M.string_probability { chain = chain,
                                                       begin_symbol = BEGIN_SYMBOL,
                                                       end_symbol = END_SYMBOL,
                                                       string = explode s }) ^
                 "\n")
      end
  val () = prprob "thethethe"
  val () = prprob "qatzs"

  val () = print ("Markov chain with n=" ^ Int.toString M2C.n ^ ".\n")
  val () = print (Int.toString (length tops) ^ " top paths:\n");
  val () = app (fn { string, p } =>
                print (rtos9 p ^ " " ^ implode string ^ "\n")) tops

  structure NMS = NMarkovSVG(structure M = M
                             fun tostring c = 
                                 if c = BEGIN_SYMBOL then "<"
                                 else if c = END_SYMBOL then ">"
                                      else implode [c])
  val s = NMS.makesvg (DICTFILE ^ "-coin" ^ Int.toString M2C.n ^ ".svg", chain)

end