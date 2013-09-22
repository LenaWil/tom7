
(* Reads a snoot apache log file and collect counts of words that
   were used, irrespective of whether they are real or not. *)

structure Preprocess =
struct

  exception Preprocess of string

  structure SM = SplayMapFn(type ord_key = string val compare = String.compare)

(* Logs from scribble look like this:
   209.240.206.206 - - [28/Apr/2008:04:32:26 +0000] "GET /f/a/s/scribble/play?flags=e&seq=1417079249&m=2&n=4&row=-1&col=-1&dir=0&word=o8.sing&chat=&x=40&y=17 HTTP/1.0" 200 10883 "http://snoot.org/f/a/s/scribble/play?flags=e&seq=1381452375&m=2&n=4&row=-1&col=-1&dir=0&word=d&chat=&x=40&y=17" "Mozilla/4.0 WebTV/2.6 (compatible; MSIE 4.0)" *)

(* Logs from word test:
209.240.206.79 - - [01/May/2008:00:29:19 +0000] "GET /f/a/s/test?word=bettings HTTP/1.0" 200 30 "-" "Mozilla/4.0 WebTV/2.6 (compatible; MSIE 4.0)" *)

(* Logs from muddle:

68.166.177.122 - - [02/May/2008:03:54:48 +0000] "GET /f/a/s/muddle/play?dx=0&dy=0&or=0&n=1&pid=603440&seq=797545647&epoch=1209700440&words=wort+wouns+cour+court+sour+sours+dour+dours+muds+murs+murts+wont+want+wans+wons+duns+suns+runs+rons+docs+dour HTTP/1.1" 200 5357 "http://snoot.org/f/a/s/muddle/play?n=1&flags=" "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US; rv:1.8.1.14) Gecko/20080404 Firefox/2.0.0.14" *)

  (* Find the URL part of GET requests. *)
  fun geturl l =
    case StringUtil.find "\"GET " (* " *) l of
      NONE => NONE
    | SOME i =>
          case StringUtil.findat (i + 6) " " l of
              NONE => NONE (* ? *)
            | SOME j => 
                  SOME (String.substring (l, i + 5, j - (i + 5)))

  datatype snootapp = Muddle | Scribble | Test

  val noget = ref 0
  val total = ref 0
  val noaph = ref 0
  val notapp = ref 0
  fun ++ r = r := !r + 1

  val scribble =
      RE.find "s[/%2Ff]+scribble[/%2Ff]+play.*&word=([a-zA-Z0-9.]+)"
  val muddle = RE.find "s[/%2Ff]+muddle[/%2Ff]+play.*words=([a-zA-Z+]+)"
  val test = RE.find "s[/%2Ff]+test.*word=([a-zA-Z]+)"

  fun stripscribble s =
      case StringUtil.find "." s of
          NONE => s
        | SOME i => String.substring(s, i + 1, size s - (i + 1))

  fun match f s =
      case f s of
          NONE => NONE
        | SOME m => SOME (m 1)

  fun parseapp url =
      if StringUtil.matchhead "/f/a/s" url orelse
         StringUtil.matchhead "/fcgi-bin/aphid" url
      then
          (case match muddle url of
               SOME ws => SOME (Muddle, 
                                String.tokens (StringUtil.ischar #"+") ws)
             | NONE =>
          (case match scribble url of
               SOME ws => SOME (Scribble, [stripscribble ws])
             | NONE => 
          (case match test url of
               SOME ws => SOME (Test, [ws])
             | NONE => (++notapp; NONE)
                   )))
      else (++noaph; NONE)

  val counts = ref SM.empty
  fun addcount what word =
      let 
          val word = StringUtil.lcase word
          val (s, m, t) = 
              (case SM.find (!counts, word) of
                   NONE => (0, 0, 0)
                 | SOME r => r)
      in
          counts := SM.insert(!counts, word,
                              case what of
                                  Scribble => (s + 1, m, t)
                                | Muddle => (s, m + 1, t)
                                | Test => (s, m, t + 1))
      end
          

  fun oneline l =
    let in
      ++total;
      case geturl l of
          NONE => ++noget
        | SOME url =>
           case parseapp url of
               SOME (what, words) => app (addcount what) words
             | NONE => ()
    end

  fun eprint s = TextIO.output (TextIO.stdErr, s)

  fun main f =
   let
       val fs = SimpleStream.tolinestream (SimpleStream.fromfilechar f)
   in
       SimpleStream.app oneline fs;
       SM.appi (fn (w, (s, m, t)) =>
                print (Int.toString s ^ " " ^ Int.toString m ^ " " ^
                       Int.toString t ^ " " ^ w ^ "\n")) (!counts);
       eprint "done.\n";
       eprint (StringUtil.table 80
               [["noget", Int.toString (!noget)],
                ["noaph", Int.toString (!noaph)],
                ["notapp", Int.toString (!notapp)],
                ["total", Int.toString (!total)]])
   end

  val () = Params.main1 
     ("Count the occurrences in the log file and write them to stdout.") main
     handle Preprocess s => eprint ("Failed: " ^ s ^ "\n")
          | RE.RE s => eprint ("RE: " ^ s ^ "\n")

end
