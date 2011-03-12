
(* Processes apache logs to count words used in snoot games. *)

structure Wishlist =
struct
  
  exception Wishlist of string

  structure SM = SplayMapFn(type ord_key = string val compare = String.compare)

  datatype snootapp = Muddle | Scribble | Test

  val noget = ref 0
  val badline = ref 0
  val lines = ref 0
  val total = ref 0
  fun ++ r = r := !r + 1

  val counts = ref SM.empty
  fun addcount (s, m, t, word) =
      let 
          val word = StringUtil.lcase word
          val (ss, mm, tt) = 
              (case SM.find (!counts, word) of
                   NONE => (0, 0, 0)
                 | SOME r => r)
      in
          total := !total + s + m + t;
          counts := SM.insert(!counts, word,
                              (s + ss, m + mm, t + tt))
      end

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  fun oneline l =
    let in
      ++lines;
      case String.tokens (StringUtil.ischar #" ") l of
          (* XXX empty string... *)
          [s, m, t, w] =>
              (case (Int.fromString s, Int.fromString m, Int.fromString t) of
                   (SOME s, SOME m, SOME t) => addcount (s, m, t, w)
                | _ => 
                       let in
                           eprint ("Bad line: " ^ l ^ "\n");
                           ++badline
                       end)
        | _ => 
              let in
                  eprint ("Bad line: " ^ l ^ "\n");
                  ++badline
              end
    end

  fun onefile f =
   let val fs = SimpleStream.tolinestream (SimpleStream.fromfilechar f)
   in  eprint (f ^ "\n");
       SimpleStream.app oneline fs
   end

  (* val dict = Script.wordlist "wordlist.asc" *)
  val dict = Script.wordlist "sowpods.txt"
  (* Seemed to be missing from the wordlist *)
  val dict2 = Script.wordlist "supplement.txt"
  (* Things like 'iraq' and 'tv' that don't count as non-words, IMO. *)
  val dict3 = (fn _ => false) (* Script.wordlist "imo.txt" *)

  (* Verified as legitimately not being words *)
  val legitimate = (fn _ => false) (* Script.wordlist "legitimate.txt" *)
  fun isword w = dict w orelse dict2 w orelse dict3 w
  val () = eprint "Wordlist loaded.\n"

  fun int_reverse (a, b) = Int.compare (b, a)
  structure IM = SplayMapFn(type ord_key = int
                            val compare = int_reverse)

  fun printcdf histo file =
      let
          val f = TextIO.openOut file
          val (tots, totm, totb) = (ref 0, ref 0, ref 0)
          val j = ref 0
      in
          IM.appi (fn (i, (s, m, b)) =>
                   let in
                       tots := !tots + !s;
                       totm := !totm + !m;
                       totb := !totb + !b;
                       ++j;

                       (* Thin data except in the interesting parts. *)
                       if i < 100 orelse
                          i > 40000 orelse
                          !j mod 10 = 0
                       then
                           TextIO.output (f,
                                          Int.toString i ^ "\t" ^
                                          Int.toString (!tots) ^ "\t" ^
                                          Int.toString (!totm) ^ "\n"(*  ^
                                          Int.toString (!totb) ^ "\n" *))
                       else ()
                   end) histo;
          TextIO.closeOut f
      end

  fun printdata f hist =
      let
          val tot = ref 0
          val j = ref 0
      in
          IM.appi (fn (i, r) =>
                   let in
                       tot := !tot + !r;
                       ++j;

                       (* Thin data except in the interesting parts. *)
                       if i < 100 orelse
                          i > 40000 orelse
                          true
                          (* !j mod 10 = 0 *)
                       then
                           TextIO.output (f,
                                          Int.toString i ^ " " ^
                                          Int.toString (!tot) ^ "\n")
                       else ()
                   end) hist;
          TextIO.output (f, "e\n")
      end

  fun main fs =
   let
       val () = app onefile fs
       val unique = ref 0
       val unique_fake = ref 0
       val total_s = ref 0
       val total_m = ref 0
       val total_t = ref 0
       val real_s = ref 0
       val real_m = ref 0
       val real_t = ref 0
       (* Frequently used words *)
       val mostused = ref nil
       (* In scrabble, muddle *)
       val mostused_s = ref nil
       val mostused_m = ref nil
       (* Frequently used words that aren't real *)
       val mostused_fake = ref nil
       val mostused_fake_s = ref nil
       val mostused_fake_m = ref nil

       (* Count of words that were used that many times. *)
       val histo_s = ref IM.empty
       val histo_m = ref IM.empty
       val histo_b = ref IM.empty

       fun scoretable l =
           StringUtil.table 80
           (["score", "word", "verified"] ::
            map (fn (score, word) =>
                 [Real.fmt (StringCvt.FIX (SOME 1)) score,
                  word,
                  if legitimate word
                  then "!"
                  else (if isword word
                        then "."
                        else "")]) l)
   in
       eprint "Analyze...\n";
       SM.app (fn (s, m, _) =>
               let 
                   fun refornew h i =
                       case IM.find (!h, i) of
                           NONE =>
                               let val r = ref 0
                               in h := IM.insert (!h, i, r); r
                               end
                         | SOME r => r
               in
                   ++ (refornew histo_s s);
                   ++ (refornew histo_m m);
                   ++ (refornew histo_b (s + m))
               end) (!counts);
                   
       SM.app (fn _ => ++unique) (!counts);
       SM.app (fn (s, m, t) => 
               let in
                   total_s := !total_s + s;
                   total_m := !total_m + m;
                   total_t := !total_t + t
               end) (!counts);
       SM.appi (fn (w, (s, m, t)) =>
                let in
                    if isword w then real_s := !real_s + s else ();
                    if isword w then real_m := !real_m + m else ();
                    if isword w then real_t := !real_t + t else ()
                end) (!counts);
       SM.appi (fn (w, (s, m, t)) =>
                let
                    (* XXX can do much better! Normalize for letter
                       frequency, score, etc. *)
                    val score : real = real (s + m + t) (* * 
                        Math.ln (real (size w)) * 
                        Math.ln (real (size w)) *)
                    fun byscore ((s, w), (ss, ww)) =
                        (* Compare backwards, so that largest scores go first. *)
                        case Real.compare (ss, s) of
                            EQUAL => String.compare (w, ww)
                          | c => c
                in
                    mostused := ListUtil.Sorted.insertbest 20 byscore (!mostused) (score, w);
                    mostused_s := ListUtil.Sorted.insertbest 20 byscore (!mostused_s) (real s, w);
                    mostused_m := ListUtil.Sorted.insertbest 20 byscore (!mostused_m) (real m, w);
                    (if isword w
                     then ()
                     else
                         let in
                             ++unique_fake;
                             mostused_fake := 
                             ListUtil.Sorted.insertbest 80 byscore
                             (!mostused_fake) (score, w);

                             mostused_fake_s := 
                             ListUtil.Sorted.insertbest 50 byscore
                             (!mostused_fake_s) (real s, w);

                             mostused_fake_m := 
                             ListUtil.Sorted.insertbest 50 byscore
                             (!mostused_fake_m) (real m, w)
                         end)
                end) (!counts);

       eprint " ... done.\n";
       print (StringUtil.table 80
              [["badline", Int.toString (!badline)],
               ["total", Int.toString (!total)],
               ["total s", Int.toString (!total_s)],
               ["total m", Int.toString (!total_m)],
               ["total t", Int.toString (!total_t)],
               ["real s", Int.toString (!real_s)],
               ["real m", Int.toString (!real_m)],
               ["real t", Int.toString (!real_t)],
               ["unique", Int.toString (!unique)],
               ["unique fake", Int.toString (!unique_fake)],
               ["lines", Int.toString (!lines)]]);
       print "\nMost used overall:\n";
       print (scoretable (!mostused));
       print "\nMost used scribble:\n";
       print (scoretable (!mostused_s));
       print "\nMost used muddle:\n";
       print (scoretable (!mostused_m));

       print "\nMost used fake:\n";
       print (scoretable (!mostused_fake));
       print "\nMost used fake scribble:\n";
       print (scoretable (!mostused_fake_s));
       print "\nMost used fake muddle:\n";
       print (scoretable (!mostused_fake_m));

       let
           val f = TextIO.openOut "wishlist.plot"
       in
           TextIO.output (f,
                          "set term gif size 2048 1024\n" ^
                          "set xlabel 'Number of words\n" ^
                          "set data style lines\n" ^
                          "set autoscale xy\n" ^
                          "set output 'wishlist.gif'\n" ^
                          "set ylabel 'Seen this many times or fewer\n" ^
                          "set title 'wishlist CDF'\n" ^
                          (* "set ydata time\n" ^ *)
                          (* "set format y '%M:%S'" ^ *)
                          "plot '-' using 1:(log($2)) title 's', " ^
                          "'-' using 1:(log($2)) title 'm', " ^
                          "'-' using 1:(log($2)) title 'b'\n");

           printdata f (!histo_s);
           printdata f (!histo_m);
           printdata f (!histo_b);
           TextIO.closeOut f
       end
   end

  val () = Params.main
     ("Count the occurrences in the summary files, compute whatever, " ^
      "and write the results on stdout.") main
     handle Wishlist s => eprint ("Failed: " ^ s ^ "\n")
          | RE.RE s => eprint ("RE: " ^ s ^ "\n")


end
