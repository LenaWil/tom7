(* Tries to fit (essentially) arbitrary functions to Skymall douche data.
   http://snoot.org/toys/skymall/ *)
structure SkyMall =
struct

  val rtos = Real.fmt (StringCvt.FIX (SOME 2))
  val rtos9 = Real.fmt (StringCvt.FIX (SOME 9))

  val douches = [
  ("personal-headphones.jpg", "In Charge of the Music", 207, 66, 75.82),
  ("head-spa-massage.jpg", "The Thinker", 201, 73, 73.35),
  ("sandproof-blanket.jpg", "Seaside Date", 197, 76, 72.16),
  ("laptop-holder.jpg", "Reclining Numbercruncher", 193, 80, 70.69),
  ("fluidity-of-motion.jpg", "Karate Genius", 188, 85, 68.86),
  ("poolside-read.jpg", "Poolside Bibliophile", 177, 95, 65.07),
  ("global-network.jpg", "Traveling Salesman", 171, 102, 62.63),
  ("relaxing.jpg", "Beauty Rest", 167, 106, 61.17),
  ("jeweler.jpg", "Jeweler", 167, 106, 61.17),
  ("i-have-to-take-this.jpg", "I Have to Take This", 160, 113, 58.60),
  ("nose-jewelry.jpg", "Cured Snorer", 141, 132, 51.64),
  ("sleeping.jpg", "Man who can Sleep in Any Seat", 131, 140, 48.33),
  ("after.jpg", "Treatment Recipent", 121, 152, 44.32),
  ("business-expert.jpg", "Business Expert", 118, 155, 43.22),
  ("confidence.jpg", "Confident in Glasses", 118, 155, 43.22),
  ("sass-moulavi.jpg", "Sass Moulavi M.D.", 117, 155, 43.01),
  ("videochat.jpg", "New Haircut", 96, 177, 35.16),
  ("pockets-jacket.jpg", "Woodsy Gentleman", 86, 186, 31.61),
  ("john-q-storus.jpg", "John Q. Storus", 78, 195, 28.57),
  ("security-system.jpg", "Father/Kidnapper", 73, 199, 26.83),
  ("promotion.jpg", "Got the Promotion", 59, 214, 21.61),
  ("runner.jpg", "Silver Medalist", 34, 238, 12.50)
  ]

  val douches = map (fn (f, t, a, b, c) =>
                     (StringUtil.readfile f, t, a, b, c)) douches

  fun score f =
    let
        fun scoreone (dat, _, _, _, frac) =
            let val d = (frac / 100.0) - f dat
            in Math.sqrt (d * d)
            end
    in
        foldl op+ 0.0 (map scoreone douches)
    end

  fun table fs =
    let
        fun onerow (dat, t, _, _, frac) =
          let
              
          in
              print (t ^ ", " ^ rtos frac);
              app (fn (_, f) => print (", " ^ rtos9 (100.0 * f dat))) fs;
              print "\n"
          end
    in
        (* header. *)
        print "name, douche";
        app (fn (name, _) => print (", " ^ name)) fs;
        print "\n";

        app onerow douches
    end

  fun bytesfrac s =
    let
        val s = explode s
        val d = Math.pow (256.0, real (length s))
        fun go a nil = a / d
          | go a (ch :: rest) =
            let val a = a * 256.0
                val c = real (ord ch)
            in 
                go (a + c) rest
            end
    in
        go 0.0 s
    end

  fun f_sha1 s = bytesfrac (SHA1.hash s)
  fun f_md5 s = bytesfrac (MD5.md5 s)
(*
  fun output (f, name) =
      let
          
      in

      end
*)
  structure MT = MersenneTwister

  (* val iv = (0wx68B7C4E5, 0wx4F6097D6, 0wx29B76190, 0wxD4DE7499) *)
  (* val iv = (0wx992B3C53, 0wx8C45719, 0wx1E715739, 0wxCBA8DCC5) *)
  (* val iv = (0wx6AA32BFA, 0wx2196B639, 0wx8014EDD3, 0wx7623D71D) *)
  (* val iv = (0wx6DFA64B5, 0wx14F3A3A0, 0wx3AD7FEDD, 0wxC4CDC45E) *)
  (* val iv = (0wx7355BDBB, 0wx3AB852C8, 0wxFD3CD702, 0wxD48A3BA) *)
  val iv = (0wxA8F82303, 0wx8A1B76B, 0wxAA25DA9E, 0wx4C2C1883)

  (* Don't always try the same IVs, or we always have to repeat work that
     we know won't be fruitful! *)
  val mt = MT.init32 (#3 iv)

  fun f_md5iv iv s = bytesfrac (MD5.md5_advanced { iv = iv, msg = s })
  fun fstart s = bytesfrac (MD5.md5_advanced { iv = iv, msg = s })
  val bestscore = ref (score fstart)

  (* Find some good IVs. *)
  val tries = ref 0
  fun findivs fs 0 = fs
    | findivs fs n =
    let
        val iv = (MT.rand32 mt, MT.rand32 mt, MT.rand32 mt, MT.rand32 mt)
        fun f s = bytesfrac (MD5.md5_advanced { iv = iv, msg = s })
        val sc = score f
    in
        if !tries mod 1000 = 0
        then TextIO.output (TextIO.stdErr, Int.toString (!tries) ^ "...\n")
        else ();

        tries := !tries + 1;
        if sc < !bestscore
        then (TextIO.output (TextIO.stdErr, 
                             Int.toString (!tries) ^
                             " new best: " ^ rtos9 sc ^ " (" ^
                             "0wx" ^ Word32.toString (#1 iv) ^ ", " ^
                             "0wx" ^ Word32.toString (#2 iv) ^ ", " ^
                             "0wx" ^ Word32.toString (#3 iv) ^ ", " ^
                             "0wx" ^ Word32.toString (#4 iv) ^ ")\n");
              bestscore := sc;
              findivs (("xxx", f) :: fs) (n - 1))
        else findivs fs n
    end
      
  val () = TextIO.output (TextIO.stdErr, rtos9 (score f_sha1) ^ "\n")
  val () = TextIO.output (TextIO.stdErr, rtos9 (score f_md5) ^ "\n")
  val () = TextIO.output (TextIO.stdErr, rtos9 (score (f_md5iv iv)) ^ "\n")

  val () = table ([("sha1", f_sha1), 
                   ("md5", f_md5),
                   ("md5-iv", f_md5iv iv)])

  val _ = findivs nil 10

end
