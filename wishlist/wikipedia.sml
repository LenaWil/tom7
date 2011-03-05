(* Extracts content from Wikipedia database dump. *)
structure Wikipedia =
struct

  exception Wikipedia of string

  (* val INFILE = "/z/wikipedia/enwiki-20090604-pages-articles.xml" *)
  val INFILE = "short.xml"
  val dict = Script.wordlist "wordlist.asc"

  (* We don't actually parse the XML because it's way too big to fit in
     memory and I don't want to use the streaming interface. Just read lines.
     If it starts with the thing that denotes page bodies, then start interpreting
     it as text. Stop when we reach a line that contains </text>. *)
  val lines = SimpleStream.tolinestream 
      (SimpleStream.fromfilechar INFILE)
      
  val SENTINEL_START = "<text xml:space=\"preserve\">" (* " *)
  val SENTINEL_END = "</text>"

  fun ++ r = r := !r + 1
  val nbytes = ref (0 : IntInf.int)
  val nlines = ref (0 : IntInf.int)
  fun report s =
     let in
       ++nlines;
       nbytes := !nbytes + IntInf.fromInt (size s);
       if IntInf.mod(!nlines, 100000) = 0
       then (TextIO.output 
             (TextIO.stdErr, IntInf.toString (!nlines) ^ " lines " ^
              IntInf.toString (!nbytes) ^ " bytes...\n");
             raise Wikipedia "PROFILING.")
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

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))


  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val cmp = Char.compare
    val n = 2
  end

  structure M = MarkovFn(M2C)

  (* Words *)
  val chain = M.chain ()
  fun ows s = 
      M.observe_weighted_string { begin_symbol = chr 1,
                                  end_symbol = chr 0,
                                  weight = 1.0,
                                  chain = chain,
                                  string = explode s }
  val () = print "Observe...\n"

  val alphabetic = StringUtil.charspec "-A-Za-z'"

  (* XXX filters for stuff like #REDIRECT, [[nl:nonsense]] *)
  (* XXX unescape XML, like &lt; and &gt; *)
  fun observe p =
      let val p = StringUtil.lcase p
      in
          (* These are usually [[category:blah]] or [[de:das artikel]], etc. *)
          if (StringUtil.matchhead "[[" p andalso StringUtil.matchtail "]]" p) orelse
             (StringUtil.matchhead "{{" p andalso StringUtil.matchtail "}}" p) orelse
             Option.isSome (StringUtil.find "#redirect" p)
          then ()
          else
              let val p = String.tokens (not o alphabetic) p
              in app (ows o StringUtil.lcase) p
              end
      end

  val () = appcontent observe lines
  val () = print "Predict...\n"

  val beginstate = M.state (List.tabulate (M2C.n, fn _ => chr 1))
  val most_probable = (M.most_probable_paths { lower_bound = 0.000001,
                                               chain = chain,
                                               state = beginstate,
                                               end_symbol = #"\000" })
  val most_probable = Stream.map (fn { string, p } => (p, implode string)) 
                      most_probable
  val most_fake = Stream.filter (fn (_, s) => not (dict s)) most_probable
  val tops = StreamUtil.headn 100 most_fake

  val () = print ("n = " ^ Int.toString (M2C.n) ^ "\n")
  val () = print (Int.toString (length tops) ^ " top paths:\n");
  val () = app (fn (p, s) =>
                print (rtos9 p ^ " " ^ s ^ "\n")) tops

end
