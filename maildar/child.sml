structure Child =
struct

    (* TODO: make last-chance timer that kills this process after 5 minutes *)

    (* XXX in config.sml *)
    open Config

    structure R = RawNetwork
    exception Child of string

    fun eprint s = TextIO.output(TextIO.stdErr, s)

    fun execute (from, to, subject, parts) =
        Action.perform (Config.what_action to, subject, parts)

    exception BadMail of string
    fun receive_mail (from, to, lines) =
        let 
            fun isspace #" " = true
              (* continued headers indented by tab, not space *)
              | isspace #"\t" = true 
              | isspace _ = false

            fun getheaders true _ nil = raise BadMail "no body?"
              | getheaders false hdrs nil = (rev hdrs, nil)
              | getheaders _ hdrs ("" :: t) = (rev hdrs, t)
              | getheaders needbody hdrs (h :: t) = getheaders needbody (h :: hdrs) t
            val (headers, body) = getheaders true nil lines

            val subject =
                case ListUtil.findpartial
                    (fn s =>
                     if StringUtil.matchhead "Subject: " s
                     then SOME (#2 (StringUtil.token isspace s))
                     else NONE) headers of
                    SOME s => s
                  | NONE => "(no subject)"

            (* search through headers for 
               Content-Type: multipart/mixed;
                  boundary=YYYYYYYYYYYYY
               *)
            fun getboundary nil = raise BadMail "no content-type"
              | getboundary (s :: t) =
                case StringUtil.token isspace s of
                    ("Content-Type:", rest) =>
                        (case StringUtil.token isspace rest of
                             ("multipart/mixed;", more) =>
                                 (* now, boundary= might be on
                                    the same line or the next.
                                    make these cases the same: *)
                                 let
                                     val b = more ^ " " ^ (case t of 
                                                               nil => ""
                                                             | nn :: _ => nn)

                                     val () = eprint ("b: [" ^ b ^ "]\n")

                                     (* this also assumes there is no quoted
                                        space in the boundary, which is
                                        reasonable *)
                                     val (tok, _) = StringUtil.token isspace b
                                 in
                                     eprint ("btok: [" ^ tok ^ "]\n");
                                     (* tok should be
                                        boundary=YYYYYYY
                                        or 
                                        boundary="YYYYYYYYY" *)
                                     (case StringUtil.token (fn #"=" => true
                                                                 | _ => false) tok of
                                          ("boundary", tok) =>
                                              (* then just unquote it;
                                                 I just assume quotes don't appear *)
                                              StringUtil.filter 
                                                (fn #"\"" => false | _ => true) (* " *) tok
                                        | _ => raise BadMail "expected boundary for multipart/mixed")
                                 end
                           | _ => raise BadMail "expected content-type multipart/mixed")
                  | _ => getboundary t

            val boundary = getboundary headers
            val () = eprint ("boundary: [" ^ boundary ^ "]\n")

            (* per RFC 2046, add these dashes *)
            val boundary = "--" ^ boundary
                
        (* Now we expect to see the message consist of parts 
           separated by the unique string --boundary
           starting lines (and possibly including other garbage at the
           end of the line, ignored) *)
            fun eatparts parts cur nil = rev (rev cur :: parts)
              | eatparts parts cur (h :: t) =
                if StringUtil.matchhead boundary h
                then eatparts (rev cur :: parts) nil t
                else eatparts parts (h :: cur) t

            val parts = eatparts nil nil body

            datatype encoding = ASCII | BASE64

            fun dopart lines =
                let
                    val (h, b) = getheaders false nil lines
                    (* assume ASCII when there are no headers *)
                    fun gettype nil = ASCII
                      | gettype (h :: t) =
                        case StringUtil.token (fn #" " => true | _ => false) h of
                            ("Content-Transfer-Encoding:", enc) =>
                                (case StringUtil.token (fn #" " => true | _ => false) enc of
                                     ("7bit", _) => ASCII
                                   | ("base64", _) => BASE64
                                   | _ => raise BadMail ("unknown content encoding " ^ enc))
                          | _ => gettype t
                in
                    case gettype h of
                        ASCII => Action.Text (StringUtil.delimit "\n" b)
                      | BASE64 =>
                          (case Base64.decode (String.concat b) of
                               NONE => raise BadMail "couldn't decode base64 region"
                             | SOME data => Action.Data data)
                end

            val parts = map dopart parts
        in
            app (fn Action.Text s =>
                 let in
                     print "### Text part: ###\n";
                     print s;
                     print "\n"
                 end
                  | Action.Data d => 
                 let in
                     print "### Data part ###\n";
                     print ("(" ^ Int.toString (size d) ^ " bytes)\n")
                 end) parts;
            execute (from, to, subject, parts)
        end

    fun sendall (sock : R.sdesc, str : string) =
        let
            val n = R.send sock str
        in
            if n = ~1
            then raise RawNetwork.RawNetwork "send error"
            else
                if n < size str
                then sendall (sock, String.substring(str, n, size str - n))
                else ()
        end

    structure L :>
    sig
        type pack
        val empty : pack
        val recvline : R.sdesc * pack -> (string * pack) option
    end =
    struct
        (* list of completed lines,
           then partial line with no newlines in it *)
        type pack = (string list * string)
        val empty = (nil, "") : pack
        fun recvline (sock, (nil, partial)) =
            let
                val s = R.recv sock
                    
                (* after finding a packet, there might be
                   more packets we have to queue up, and
                   there is always a partial packet at the end *)
                fun putty nil = raise Child "impossible2"
                  (* last packet had no newline on it *)
                  | putty [t] = (nil, t)
                  | putty (next :: t) =
                    let val (l, partial) = putty t
                    in (next :: l, partial)
                    end

                (* get rid of all carriage returns. *)
                val s = StringUtil.filter (fn #"\r" => false | _ => true) s
            in
                (* print ("got: [" ^ s ^ "]\n"); *)
                if s = ""
                then (R.hangup sock handle _ => (); 
                      (* drops last partial packet *)
                      NONE)
                else
                    case String.fields (fn #"\n" => true | _ => false) s of
                        nil => raise Child "impossible"
                      | [h] => (* no full packet *)
                               let in
                                   (* print "no full.\n"; *)
                                   recvline (sock, (nil, partial ^ h))
                               end
                      | h :: t => 
                               let in
                                   (*
                                   print ("return packet with " ^
                                          Int.toString (length t) ^
                                          " more\n");
                                   *)
                                   SOME (partial ^ h, putty t)
                               end
            end

          | recvline (sock, (h :: t, partial)) =
            SOME (h, (t, partial))
    end

    fun recvall (sock) =
        case R.recv sock of
            "" => (R.hangup sock handle _ => (); "")
          | s => s ^ recvall sock

    (* after MAIL or RCPT,
       can be TO:<name@host.tld>
           or FROM:<name@host.tld>
       *)
    fun getaddr s =
        case String.fields (fn #"<" => true | #">" => true | _ => false) 
             (StringUtil.lcase s) of
            ["to:", addr, ""] => SOME addr
          | ["from:", addr, ""] => SOME addr
          | _ => 
                let in
                    eprint ("Bad addr line: " ^ s ^ "\n");
                    NONE
                end
    
    exception Done
    fun child (sock : R.sdesc) =
        let 

            (* maximum message size 1mb *)
            val msize = ref 0
            val message = ref (nil : string list)
            val sender = ref (NONE : string option)
            val recipient = ref (NONE : string option)

            fun getmode p =
                case L.recvline (sock, p) of
                    NONE => print "bye-bye\n"
                  | SOME (line, p) =>
                        let in
                            (* print ("data: " ^ line ^ "\n"); *)
                            (case StringUtil.field (fn #" " => true 
                                                    (* XXX already filtered these out *)
                                                     | #"\r" => true
                                                     | #"\n" => true
                                                     | _ => false) line of
                                 (".", _) => process p
                               | _ =>
                                     let in
                                         msize := !msize + size line;
                                         if !msize > MAX_MESSAGE
                                         then (sendall(sock, "500 Maximum mail size exceeded.\n");
                                               R.hangup sock;
                                               raise Done)
                                         else ();
                                         message := line :: !message;
                                         getmode p
                                     end)
                        end

            and finish p =
                case L.recvline (sock, p) of
                    NONE => print "bye-bye\n"
                  | SOME (line, p) =>
                        let in
                            print ("(finish) line: " ^ line ^ "\n");
                            (case StringUtil.field (fn #" " => true 
                                                     | #"\r" => true
                                                     | #"\n" => true
                                                     | _ => false) line of
                                 ("QUIT", _) => (sendall(sock, "221 bye-bye\n"); 
                                                 print "(finish) quitted\n";
                                                 R.hangup sock;
                                                 raise Done)
                               | _ => sendall (sock,
                                               "500 After DATA, I just want QUIT. Go!\n"));
                            finish p
                        end handle Done => ()

            (* process the completed message! *)
            and process p =
                let 
                    val from = valOf (!sender)
                    val to =   valOf (!recipient)
                in
                    eprint ("From: " ^ from ^ " To: " ^ to ^ "\n");
                    receive_mail(from, to, rev (!message));
                    sendall(sock, "250 OK Accepted\n");
                    finish p
                end handle BadMail s => (sendall(sock, "500 Bad Mail: " ^ s ^ "\n");
                                         eprint ("(process) bad mail: " ^ s ^ "\n");
                                         R.hangup sock;
                                         raise Done)

            and prot (p : L.pack) =
                case L.recvline (sock, p) of
                    NONE => print "bye-bye\n"
                  | SOME (line, p) =>
                        let in
                            print ("(prot) line: " ^ line ^ "\n");
                            (case StringUtil.field (fn #" " => true 
                                                     | #"\r" => true
                                                     | #"\n" => true
                                                     | _ => false) line of
                                 ("HELO", _) => 
                                     let in
                                         sendall(sock, "250 " ^ HOST ^ " Wide awake and physical.\n");
                                         prot p
                                     end
                               | ("MAIL", rest) => 
                                     (case getaddr rest of
                                          NONE => 
                                              let in
                                                  sendall (sock, "500 Couldn't read sender.\n");
                                                  prot p
                                              end
                                        | SOME addr => 
                                          if Config.senderok addr
                                          then 
                                              let in
                                                  sender := SOME addr;
                                                  sendall(sock, "250 Sender ok\n");
                                                  prot p
                                              end
                                          else
                                              let in
                                                  sendall(sock, "500 Sender not permitted\n");
                                                  R.hangup sock;
                                                  raise Done
                                              end)
                               | ("RCPT", rest) =>
                                     (case getaddr rest of
                                          NONE =>
                                              let in
                                                  sendall (sock, "500 Couldn't read recipient.\n");
                                                  prot p
                                              end
                                        | SOME addr =>
                                              let in
                                                  recipient := SOME addr;
                                                  sendall(sock, "250 Recipe ok\n");
                                                  prot p
                                              end)
                               | ("DATA", _) => 
                                     (case (!sender, !recipient) of
                                          (SOME _, SOME _) => 
                                              (sendall(sock, "354 Enter mail, ending with .\n");
                                               eprint ("Data time.\n");
                                               getmode p)
                                        | _ =>
                                              (sendall(sock, "500 Need both sender and recipient before data.\n");
                                               getmode p))

                               | ("QUIT", _) => (sendall(sock, "221 bye-bye\n"); 
                                                 print "quitted\n";
                                                 R.hangup sock;
                                                 raise Done)
                               | _ => sendall (sock,
                                               "500 This server only accepts the most primitive commands.\n")
                                 );
                            prot p
                        end handle Done => ()
        in
            eprint ("I'm the child.\n");
            sendall(sock,
                    "220 Don't get confused.\n");
            prot (L.empty);
(*
                    "250 tom7.org Wide awake and physical.\n" ^
                    "250 I'm not paying attention.\n" ^
                    "250 Still just always saying ok.\n" ^
                    "354 Go go gadget DATA!\n" ^
                    "250 I am throwing your message away.\n" ^
                    "221 Time to go\n");
            print (recvall sock);
*)
            eprint ("\n\n--- exiting ---\n");
            Posix.Process.exit 0w0;
            ()
        end

end
