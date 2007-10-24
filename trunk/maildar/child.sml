structure Child =
struct

    (* TODO: make last-chance timer that kills this process after 5 minutes *)

    val MAX_MESSAGE = 1000000

    structure R = RawNetwork
    exception Child of string

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
                    TextIO.output(TextIO.stdErr, "Bad addr line: " ^ s ^ "\n");
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
                            print ("data: " ^ line ^ "\n");
                            (case StringUtil.field (fn #" " => true 
                                                     | #"\r" => true
                                                     | #"\n" => true
                                                     | _ => false) line of
                                 (".", _) => (sendall(sock, "250 OK Accepted\n");
                                              process p)
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
                    TextIO.output(TextIO.stdErr, "From: " ^ from ^ " To: " ^ to ^ "\n");
                    (* FIXME HERE do it *)
                    finish p
                end

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
                                         sendall(sock, "250 tom7.org Wide awake and physical.\n");
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
                                              let in
                                                  sender := SOME addr;
                                                  sendall(sock, "250 Sender ok\n");
                                                  prot p
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
                                               TextIO.output(TextIO.stdErr, "Data time.\n");
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
            TextIO.output(TextIO.stdErr, "I'm the child.\n");
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
            TextIO.output(TextIO.stdErr, "\n\n--- exiting ---\n");
            Posix.Process.exit 0w0;
            ()
        end

end
