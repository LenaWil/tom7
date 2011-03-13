(* Extracts content from Wikipedia database dump. *)
structure Wikipedia =
struct

  exception Wikipedia of string

  val INFILE = "/z/wikipedia/enwiki-20090604-pages-articles.xml"
  (* val INFILE = "short.xml" *)
  val dict = Script.wordlist "wordlist.asc"
  val wikino = Script.wordlist "wikipedia-no.txt"

  val filesize : LargeInt.int = 23080896255

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  (* We don't actually parse the XML because it's way too big to fit in
     memory and I don't want to use the streaming interface. Just read lines.
     If it starts with the thing that denotes page bodies, then start interpreting
     it as text. Stop when we reach a line that contains </text>. *)
  val lines = SimpleStream.tolinestream 
      (SimpleStream.fromfilechar INFILE)
      
  val SENTINEL_START = "<text xml:space=\"preserve\">" (* " *)
  val SENTINEL_END = "</text>"

  fun ++ r = r := !r + 1
  val nbytes = ref (0 : LargeInt.int)
  val nlines = ref (0 : LargeInt.int)
  fun report s =
     let in
       ++nlines;
       nbytes := !nbytes + LargeInt.fromInt (size s);
       if LargeInt.mod(!nlines, 100000) = 0
       then (TextIO.output 
             (TextIO.stdErr, LargeInt.toString (!nlines) ^ " lines " ^
              LargeInt.toString (!nbytes) ^ " bytes (" ^ 
              rtos (100.0 * Real.fromLargeInt (!nbytes) /
                    Real.fromLargeInt (filesize)) ^ "%)\n"))
       else ();
       s
     end

  val lines = SimpleStream.map report lines

  fun appcontent f ss =
      case ss () of
          NONE => ()
        | SOME s =>
           let val s = StringUtil.losespecl StringUtil.whitespec s
           in
               if StringUtil.matchhead SENTINEL_START s
               then let val s = String.substring (s, size SENTINEL_START, 
                                                  size s - size SENTINEL_START)
                    (* might also </end> on the same line... *)
                    in addandrecurse f ss s
                    end
               else appcontent f ss
           end
  and appincontent f ss =
     (case ss () of
          NONE => print "Ended inside article??"
        | SOME s => addandrecurse f ss s)

  and addandrecurse f ss s =
     let val s = StringUtil.losespecr StringUtil.whitespec s
     in
       if StringUtil.matchtail SENTINEL_END s
       then (f (String.substring (s, 0, size s - size SENTINEL_END));
             appcontent f ss)
       else (f s; appincontent f ss)
     end

  (* val () = appcontent (fn s => print (s ^ "\n")) lines *)

  (* val () = appposts (fn (u, s) => print ("[" ^ u ^ "]: " ^ s ^ "\n")) xml *)


  val BEGIN_SYMBOL = chr (ord #"z" + 1)
  val END_SYMBOL = chr (ord #"z" + 2)
  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val n = 4
    val radix = 28
    fun toint c = ord c - ord #"a"
    fun fromint x = chr (x + ord #"a")
  end

  structure M = MarkovFn(M2C)

  (* Words *)
  val chain = M.chain ()
  fun ows s = 
      if wikino s
      then ()
      else 
          let in
              (* print ("[" ^ s ^ "]"); *)
              M.observe_weighted_string { begin_symbol = BEGIN_SYMBOL,
                                          end_symbol = END_SYMBOL,
                                          weight = 1.0,
                                          chain = chain,
                                          string = explode s }
          end
  val () = print "Observe...\n"

  (* Expects lowercase. *)
  val alphabetic = StringUtil.charspec "a-z"

  (* Inword is SOME p for a position p that started a word. *)
  fun strip_ows (s, n, depth, inword) =
      if depth < 0
      then () (* ill-formed, or parser is too dumb *)
      else
        if n >= size s
        then (case inword of
                  SOME p => ows (String.substring (s, p, size s - p))
                | NONE => ())
        else (let val c = String.sub (s, n)
                  val a = alphabetic c
                  val inword =
                      case (a, inword) of
                          (true, NONE) => SOME n
                        | (false, NONE) => NONE
                        | (true, SOME _) => inword
                        | (false, SOME p) =>
                              (* ended word. *)
                              let in
                                  ows (String.substring (s, p, n - p));
                                  NONE
                              end
              in
              case c of
                  #"[" => strip_ows (s, n + 1, depth + 1, NONE)
                | #"{" => strip_ows (s, n + 1, depth + 1, NONE)
                | #"]" => strip_ows (s, n + 1, depth - 1, NONE)
                | #"}" => strip_ows (s, n + 1, depth - 1, NONE)
                | #"<" =>
                  if StringUtil.matchat (n + 1) "ref>" s
                  then (case StringUtil.findat (n + 6) "</ref>" s of
                            NONE => () (* ? no closing ref? Sometimes they span lines. *)
                          | SOME r => strip_ows (s, r + 6, depth, NONE))
                  else strip_ows (s, n + 1, depth, NONE) (* might be like br? *)
                | c => strip_ows (s, n + 1, depth, inword)
              end)

  fun observe p =
      let val p = StringUtil.lcase p
          (* unescape XML, like &lt; and &gt; *)
          val p = StringUtil.replace "&lt;" "<" p
          val p = StringUtil.replace "&gt;" ">" p
          val p = StringUtil.replace "&quot;" "\"" p (* " *)
      in
          (* These are usually [[category:blah]] or [[de:das artikel]], etc. *)
          if (StringUtil.matchhead "[[" p andalso StringUtil.matchtail "]]" p) orelse
             (StringUtil.matchhead "{{" p andalso StringUtil.matchtail "}}" p) orelse
             Option.isSome (StringUtil.find "#redirect" p)
          then ()
          else strip_ows (p, 0, 0, NONE)
(*              let val p = String.tokens (not o alphabetic) p
              in app (ows o StringUtil.lcase) p
              end *)
      end

  val () = appcontent observe lines
  val () = print "Predict...\n"

  val beginstate = M.state (List.tabulate (M2C.n, fn _ => BEGIN_SYMBOL))
  val most_probable = (M.most_probable_paths { lower_bound = 0.000001,
                                               chain = chain,
                                               state = beginstate,
                                               end_symbol = END_SYMBOL })
  val most_probable = Stream.map (fn { string, p } => (p, implode string)) 
                      most_probable
  val most_fake = Stream.filter (fn (_, s) => not (dict s)) most_probable
  val tops = StreamUtil.headn 5000 most_fake

  val () = print ("n = " ^ Int.toString (M2C.n) ^ "\n")
  val () = print (Int.toString (length tops) ^ " top paths:\n");
  val () = app (fn (p, s) =>
                print (rtos9 p ^ " " ^ s ^ "\n")) tops

end
