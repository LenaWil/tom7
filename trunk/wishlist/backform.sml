(* Generate words with backformation rules. *)
structure Backform =
struct
  fun eprint s = TextIO.output (TextIO.stdErr, s)

  val () = eprint "Load dictionaries...\n"
  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "sowpods.txt")
  val dict = Script.wordlist "sowpods.txt"

  val BEGIN_SYMBOL = chr (ord #"z" + 1)
  val END_SYMBOL = chr (ord #"z" + 2)
  structure M2C : NMARKOVARG =
  struct
    type symbol = char
    val n = 4 (* 3 *)
    val radix = 28
    fun toint c = ord c - ord #"a"
    fun fromint x = chr (x + ord #"a")
  end

  structure SM = SplayMapFn(type ord_key = string val compare = String.compare)
  structure M = MarkovFn(M2C)

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  val chain = M.chain ()
  (* Count for prefix/suffix. The pair is the numerator and denominator
     of the fraction: How many times did we see this prefix? How often
     was the string that remained after we removed it a word? *)
  val prefixes = ref (SM.empty : (int * int) SM.map)
  val suffixes = ref (SM.empty : (int * int) SM.map)
  fun incrementfrac (m, w, is) =
      let val (n, d) = (case SM.find (!m, w) of
                            NONE => (0, 0)
                          | SOME r => r)
      in
          m := SM.insert (!m, w, (if is then n + 1 else n, d + 1))
      end

  (* Goal is to generate the likelihood that removing a
     prefix (or suffix) from a word will produce a real
     word. We do this by accounting for every prefix of
     every word, and just counting the number of times
     that its removal retained wordness. Runtime is reasonable,
     at 2 * l * n * log(n) where n is the number of words, l
     is the average length, and 2 because we do this for both
     prefix and suffix (though simultaneously). *)
  (* this is easy, just loop from 1 .. n-1, take the
     substrings, and treat one as the prefix with the suffix
     as the new word, and vice versa. *)
  fun countoneword w =
      Util.for 1 (size w - 1)
      (fn pfxlen =>
       let
           val (pfx, sfx) = StringUtil.partition w pfxlen
       in
           incrementfrac (prefixes, pfx, dict sfx);
           incrementfrac (suffixes, sfx, dict pfx)
       end)

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
          else ();

          countoneword s
      end
  val () = eprint "Observe, and generate prefixes and suffixes...\n"
  val () = SimpleStream.app ows lines

  (* Show the most likely formation rules. *)
  val () = eprint "Best fixes...\n"
  val bestfixes = ref (nil : (real * string * int * int) list)
  fun realdesc ((r, _, _, _), (rr, _, _, _)) = Real.compare (rr, r)
  (* Ignore singular observations. *)
  fun onefix which (w, (n, 1)) = ()
    | onefix which (w, (n, d)) =
      if real n / real d < 1.0
      then
          let val p = real n / real d
          in bestfixes := ListUtil.Sorted.insertbest 100 realdesc (!bestfixes)
              (p, 
               (if which
                then w ^ "-"
                else "-" ^ w), n, d)
          end
      else ()
  val () = SM.appi (onefix true) (!prefixes)
  val () = SM.appi (onefix false) (!suffixes)
  val () = print "Best fixes:\n"
  val () = print (StringUtil.table 78 (map (fn (r, s, n, d) => 
                                            [rtos9 r, s, 
                                             Int.toString n ^ "/" ^ Int.toString d]) (!bestfixes)))

      (* XXX *)
  (* val () = raise Match *)

  fun ++ r = r := !r + 1
  val norule = ref 0
  val alreadyword = ref 0
  val splits = ref 0
  val unique = ref 0
  val never = ref 0
  val toorare = ref 0

  (* Load words again for second pass. *)
  val () = eprint "Backform...\n"
  val lines = SimpleStream.tolinestream (SimpleStream.fromfilechar "sowpods.txt")

  fun probability w = M.string_probability { chain = chain,
                                             begin_symbol = BEGIN_SYMBOL,
                                             end_symbol = END_SYMBOL,
                                             string = explode w }

  (* First component is different ways we could form this, with probabilities.
     second is its markov probability *)
  val results = ref (SM.empty : ((string * real) list * real) SM.map)
      (* XXX keep fixl in order *)
  fun observe (fix : string, p : real, w : string) =
      results := 
      SM.insert (!results, w,
                 case SM.find (!results, w) of 
                     NONE => ([(fix, p)], probability w)
                   | SOME (l, pr) => ((fix, p) :: l, pr))

  fun tryform (m, fix, which, leftover) =
      (* If it's already a word, don't bother. *)
      if dict leftover
      then ++alreadyword
      else (case SM.find (!m, fix) of
                (* Never saw this -fix. Never actually happens if the training set is
                   the same as the domain for backformation, since we will have observed
                   this actual split during training. *)
                NONE => ++norule
              | SOME (0, _) => ++never
              | SOME (n, d) =>
                    if d < 10
                    then ++toorare
                    else
                        let 
                            val p = real n / real d
                        in
                            (* Should also never happen, because n would have
                               to be 0 or 1. If 0, then this is caught by the
                               case above. If 1, then we've seen this split,
                               and the remainder is indeed a word. *)
                            (if d <= 1 then ++unique else ());
                                observe (if which 
                                         then fix ^ "-"
                                         else "-" ^ fix, p, leftover)
                        end)
          
  (* Now for each word, try applying prefix or suffix elimination.
     If the resulting word is not already real, let its probability
     be the product of that prefix/suffix's legality and its
     markov probability. *)
  fun oneword w =
      let val w = StringUtil.lcase w
      in
          Util.for 1 (size w - 1)
          (fn pfxlen =>
           let
               val (pfx, sfx) = StringUtil.partition w pfxlen
           in
               ++splits;
               tryform (prefixes, pfx, true, sfx);
               tryform (suffixes, sfx, false, pfx)
           end)
      end
  val () = SimpleStream.app oneword lines

  val () = print ("Backformed " ^ Int.toString (SM.numItems (!results)) ^ ".\n")
  val () = print ("No rule: " ^ Int.toString (!norule) ^ "\n")
  val () = print ("Unique prefix: " ^ Int.toString (!unique) ^ "\n")
  val () = print ("Already word: " ^ Int.toString (!alreadyword) ^ "\n")
  val () = print ("Splits attempted: " ^ Int.toString (!splits) ^ "\n")
  val () = print ("Impossible split: " ^ Int.toString (!never) ^ "\n")
  val () = print ("Too rare: " ^ Int.toString (!toorare) ^ "\n")

  (* Now show the best ones, obviously. *)
  val () = eprint "Find best...\n"
  val best = ref (nil : { fixl : (string * real) list,
                          mp : real,
                          score : real,
                          word : string } list)
  fun getbest (w, (fixl, mp)) =
      if size w > 4 (* XXX arbitrary! *)
      then
      let
          (* By decreasing score. *)
          fun byscore ({ score, ... }, { score = score', ... }) =
              Real.compare (score', score)
          (* Probability of none of the backformation rules applying, assuming
             independence *)
          val jointprobnot = List.foldl (fn ((_, r), j) =>
                                         j * (1.0 - r)) 1.0 fixl
          (* Probability of at least one of the backformation rules applying *)
          val probany = 1.0 - jointprobnot
          val score = probany * mp
      in
          best := ListUtil.Sorted.insertbest 500 byscore (!best)
            { fixl = fixl, mp = mp, score = score, word = w }
      end
      else ()
  val () = SM.appi getbest (!results)

  val tbl = map (fn { fixl, mp, score, word } =>
                 let 
                     val fixl = ListUtil.sort (ListUtil.bysecond (Util.descending
                                                                  Real.compare)) fixl

                     val lf = length fixl
                     val (fixl, ell) = if lf > 100
                                       then (List.take (fixl, 100), 
                                             " +" ^ Int.toString (lf - 100) ^ "...")
                                       else (fixl, "")
                 in
                     [ word, rtos9 score, rtos mp,
                      StringUtil.delimit " " (map (fn (s, p) =>
                                                   s ^ " (" ^ rtos p ^ ")") fixl) ^
                      ell ]
                 end)
                (!best)

  val () = print (StringUtil.table 79 tbl)

end