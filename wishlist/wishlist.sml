
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

  val dict = Script.wordlist "wordlist.asc"
  val dict2 = Script.wordlist "supplement.txt"
  (* Verified as legitimately not being words *)
  val legitimate = Script.wordlist "legitimate.txt"
  fun isword w = dict w orelse dict2 w
  val () = eprint "Wordlist loaded.\n"

  fun main fs =
   let
       val () = app onefile fs
       val unique = ref 0
       val unique_fake = ref 0
       val total_s = ref 0
       val total_m = ref 0
       val total_t = ref 0
       (* Frequently used words *)
       val mostused = ref nil
       (* Frequently used words that aren't real *)
       val mostused_fake = ref nil

       fun scoretable l =
           StringUtil.table 80
           (["score", "word", "verified"] ::
            map (fn (score, word) =>
                 [Real.fmt (StringCvt.FIX (SOME 1)) score,
                  word,
                  if legitimate word
                  then "!"
                  else ""]) l)
   in
       SM.app (fn _ => ++unique) (!counts);
       SM.app (fn (s, m, t) => 
               let in
                   total_s := !total_s + s;
                   total_m := !total_m + m;
                   total_t := !total_t + t
               end) (!counts);
       SM.appi (fn (w, (s, m, t)) =>
                let
                    (* XXX can do much better! Normalize for letter
                       frequency, score, etc. *)
                    val score : real = real (s + m + t) * Math.ln (real (size w)) * Math.ln (real (size w))
                    fun byscore ((s, w), (ss, ww)) =
                        (* Compare backwards, so that largest scores go first. *)
                        case Real.compare (ss, s) of
                            EQUAL => String.compare (w, ww)
                          | c => c
                in
                    mostused := ListUtil.Sorted.insertbest 20 byscore (!mostused) (score, w);
                    (if isword w
                     then ()
                     else
                         let in
                             ++unique_fake;
                             mostused_fake := 
                             ListUtil.Sorted.insertbest 80 byscore
                             (!mostused_fake) (score, w)
                         end)
                end) (!counts);

(*
            (* insertbest max cmp l a
               inserts a into l, but ensures that the
               resulting list has at most 'max' elements (by dropping
               elements from the end) *)
            val insertbest : int -> ('a * 'a -> order) -> 'a list -> 'a ->
                              'a list
*)

(*
SM.appi (fn (w, (s, m, t)) =>
                print (Int.toString s ^ " " ^ Int.toString m ^ " " ^
                       Int.toString t ^ " " ^ w ^ "\n")) (!counts);
*)
       eprint "done.\n";
       eprint (StringUtil.table 80
               [["badline", Int.toString (!badline)],
                ["total", Int.toString (!total)],
                ["total s", Int.toString (!total_s)],
                ["total m", Int.toString (!total_m)],
                ["total t", Int.toString (!total_t)],
                ["unique", Int.toString (!unique)],
                ["unique fake", Int.toString (!unique_fake)],
                ["lines", Int.toString (!lines)]]);
       eprint "\nMost used overall:\n";
       eprint (scoretable (!mostused));
       eprint "\nMost used fake:\n";
       eprint (scoretable (!mostused_fake))
   end

  val () = Params.main
     ("Count the occurrences in the summary files, compute whatever, " ^
      "and write the results on stdout.") main
     handle Wishlist s => eprint ("Failed: " ^ s ^ "\n")
          | RE.RE s => eprint ("RE: " ^ s ^ "\n")


end
