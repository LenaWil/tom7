
structure Fetcher =
struct
  exception Fetcher of string

  (* Seconds to wait in-between fetches, no matter what. *)
  val throttle = ref 20

  val lang = Params.param "objective-c"
    (SOME("-lang", "Set the lang for the URL.")) "lang"

  val prefix = Params.param "file"
    (SOME("-prefix", "Set the prefix on downloaded files.")) "prefix"

  val decl = Params.param "const double"
    (SOME("-decl", "Set the decl, like 'const double', to precede the " ^
          "variable epsilon.")) "decl"

  fun fetch index =
    let
      (* Better just compile this one in, instead of wrangling
         with multi-escaping issues. *)
      val query = "\"" ^ !decl ^ " epsilon =\""

      val url =
        "https://github.com/search?l=" ^ !lang ^
        "&o=desc" ^
        "&q=" ^ StringUtil.urlencode query ^
        "&ref=searchresults" ^
        "&s=" ^
        "&type=Code" ^
        "&p=" ^ Int.toString index

      val outfile = !prefix ^ "-" ^ Int.toString index ^ ".html"

      val cmd =
        "wget --no-check-certificate " ^
        "\"" ^ url ^ "\" " ^
        "--output-document " ^ outfile

      val () = print ("Sleeping " ^ Int.toString (!throttle) ^ ".\n")
      val () = OS.Process.sleep (Time.fromSeconds (IntInf.fromInt (!throttle)))
      val ret = OS.Process.system cmd
    in
      if OS.Process.isSuccess ret
      then
        let
          val html = StringUtil.readfile outfile
        in
          if Option.isSome (StringUtil.find "\"highlight\"" html)
          then fetch (index + 1)
          else print ("Outfile " ^ outfile ^ " appears to be the end.\n")
        end
      else
        let
        in
          throttle := !throttle * 2;
          print ("System failed; set throttle to " ^
                 Int.toString (!throttle) ^ " sec.\n");
          fetch index
        end

    end

  fun fetchin l =
    case Int.fromString l of
      SOME i => fetch i
    | NONE =>
        let in
          print "Starting from index 1.\n";
          fetch 1
        end

end

val () = Params.main1 "(see source)" Fetcher.fetchin
