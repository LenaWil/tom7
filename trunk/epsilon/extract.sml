
structure Extract =
struct
  exception Extract of string

  (* Seconds to wait in-between fetches, no matter what. *)
  val throttle = ref 20

  val lang = Params.param "objective-c"
    (SOME("-lang", "Set the lang for the URL.")) "lang"

  val prefix = Params.param "file"
    (SOME("-prefix", "Set the prefix on downloaded files.")) "prefix"

  val caseepsilon = "[Ee][Pp][Ss][Ii][Ll][Oo][Nn]"

  val re = RE.findall ("<pre><div class=\"line\" .*>" ^
                       ".*" ^ caseepsilon ^ ".*" ^
                       "</div></pre>")

  (* works for c, c++, javascript, objective c?, c# *)
  (* XXX in javascript, typical and legal to not have semicolon. 
     TODO: If it contains a semicolon, use that. If not, allow
     comma to end line *)
  val c_re = RE.find (caseepsilon ^ "[\\t ]*=[\\t ]*([^;,]+);")
  val js_re = RE.find (caseepsilon ^ "[\\t ]*=[\\t ]*(.+)")
  fun find_c s =
    case c_re s of
    NONE => NONE
  | SOME f => SOME (f 1)

  fun find_js s =
    case js_re s of
    NONE => NONE
  | SOME f => SOME (f 1)

  structure SM = SplayMapFn(type ord_key = string
                            val compare = String.compare)

  val counts = ref SM.empty : int SM.map ref
  fun getcount s =
    case SM.find (!counts, s) of
      NONE => 0
    | SOME i => i
  fun addcount s =
    counts := SM.insert (!counts, s, getcount s + 1)

  fun count (SOME s) = addcount s
    | count NONE = addcount "/* UNPARSEABLE */"

  fun sortedlist () =
    let
      val l = SM.listItemsi (!counts)
      val l = ListUtil.sort (Util.bysecond Int.compare) l
    in
      l
    end

  fun dump () =
    app (fn (s, n) => print (s ^ "\t" ^ Int.toString n ^ "\n"))
    (sortedlist ())

  fun striptags s =
     let 
       fun stripin (#">" :: rest) = stripout rest
         | stripin (_ :: rest) = stripin rest
         | stripin nil = raise Extract "bad HTML"
       and stripout (#"<" :: rest) = stripin rest
         | stripout (c :: rest) = c :: stripout rest
         | stripout nil = nil
     in
       implode (stripout (explode s))
     end

  fun extractone d ({ dir =  false, lnk = false, 
                      name, ... } : FSUtil.fileinfo) =
    let

      val f = FSUtil.dirplus d name
      val s = StringUtil.readfile f

      fun oneline (l : int -> string) =
        let 
          val match = l 0
          val line = striptags match
          val c = case !lang of
            "js" => find_js line
          | _ => find_c line
          val c = Option.map (StringUtil.losespecsides
                              StringUtil.whitespec) c
        in
          count c;
          case c of
            NONE => print ("no parse: [" ^ line ^ "]\n")
          | SOME _ => ()
        end
      val matches = re s
    in
      print (f ^ " " ^ Int.toString (size s) ^ ":\n");
      app oneline matches
    end
    | extractone _ _ = ()

  fun extractdir d =
    let in
      FSUtil.dirapp (extractone d) d;
      dump ()
    end

end

val () = Params.main1 "(see source)" Extract.extractdir
