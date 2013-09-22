(* Extracts content from saved Facebook feeds. *)
structure Facebook =
struct

  val dict = Script.wordlist "wordlist.asc"

  datatype tree = datatype XML.tree

  (* Applies f to all the wall posts, as a pair of the poster's name and
     their text (with leading and trailing whitespace removed). *)
  fun appposts f (Text _) = ()
    | appposts f (Elem (("div", al), tl)) =
      (case XML.getattr al "class" of
           SOME wh =>
             if wh = "feedentry" orelse wh = "comment"
             then 
                 let fun appusertext (Elem (("span", [("class", "profile")]), 
                                            [Text u]) :: 
                                      Text s :: _) = 
                     let val s = StringUtil.losespecsides StringUtil.whitespec s
                     in f (u, s)
                     end
                       | appusertext (_ :: t) = appusertext t
                       | appusertext nil = ()
                 in
                     appusertext tl;
                     app (appposts f) tl
                 end
             else app (appposts f) tl
         | _ => app (appposts f) tl)
    | appposts f (Elem (_, tl)) = app (appposts f) tl
      
  val xml = XML.parsefile "facebook.xml"

  (* val () = appposts (fn (u, s) => print ("[" ^ u ^ "]: " ^ s ^ "\n")) xml *)

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))


  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val radix = 256
    val toint = ord
    val fromint = chr
    val n = 4
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

  val seen = ref 0
  val alphabetic = StringUtil.charspec "-A-Za-z'"
  fun observe ("Tom Murphy VII", p) =
      let val p = String.tokens (not o alphabetic) p
      in  seen := !seen + 1;
          app (ows o StringUtil.lcase) p
      end
    | observe _ = ()
  val () = appposts observe xml
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

  val () = print ("I saw: " ^ Int.toString (!seen) ^ "\n")

(*
  (* Sentences *)
  structure M2S : NMARKOVARG =
  struct
    type symbol = string
    val cmp = String.compare
    val n = 1
  end

  structure MS = MarkovFn(M2S)

  val chain = MS.chain ()
  fun ows s = 
      MS.observe_weighted_string { begin_symbol = "<",
                                   end_symbol = ">",
                                   weight = 1.0,
                                   chain = chain,
                                   string = s }
  val () = print "Observe...\n"

  val separator = StringUtil.charspec "-A-Za-z0-9'"
  fun observe ("Tom Murphy VII", p) =
      let val p = String.tokens (not o separator) (StringUtil.lcase p)
      in ows p
      end
    | observe _ = ()
  val () = appposts observe xml
  val () = print "Predict...\n"

  val beginstate = MS.state (List.tabulate (M2S.n, fn _ => "<"))
  val most_probable = (MS.most_probable_paths { lower_bound = 0.000001,
                                                chain = chain,
                                                state = beginstate,
                                                end_symbol = ">" })
  val most_probable = Stream.map 
                      (fn { string, p } => (p, StringUtil.delimit " " string)) 
                      most_probable
  val tops = StreamUtil.headn 100 most_probable

  val () = print (Int.toString (length tops) ^ " top sentence paths:\n");
  val () = app (fn (p, s) =>
                print (rtos9 p ^ " " ^ s ^ "\n")) tops
*)

end
