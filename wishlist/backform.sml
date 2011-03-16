(* Coin words with coinduction. *)
structure Coin =
struct

  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "sowpods.txt")
  val dict = Script.wordlist "sowpods.txt"

  val BEGIN_SYMBOL = chr (ord #"z" + 1)
  val END_SYMBOL = chr (ord #"z" + 2)
  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val n = 2 (* 3 *)
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

  val () = print "Generate prefixes and suffixes...\n"
  (* Goal is to generate the likelihood that removing a
     prefix (or suffix) from a word will produce a real
     word. We do this by accounting for every prefix of
     every word, and just counting the number of times
     that its removal retained wordness. Runtime is reasonable,
     at 2 * l * n * log(n) where n is the number of words, l
     is the average length, and 2 because we do this for both
     prefix and suffix (though simultaneously). *)
  (* XXX this is easy, just loop from 1 .. n-1, take the
     substrings, and treat one as the prefix with the suffix
     as the new word, and vice versa. *)


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

(*
  structure NMS = NMarkovSVG(structure M = M
                             fun tostring c = 
                                 if c = BEGIN_SYMBOL then "<"
                                 else if c = END_SYMBOL then ">"
                                      else implode [c])
  val s = NMS.makesvg ("coin" ^ Int.toString M2C.n ^ ".svg", chain)
*)
end