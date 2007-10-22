structure Child =
struct

    (* TODO: make last-chance timer that kills this process after 5 minutes *)

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
            in
                (* print ("got: [" ^ s ^ "]\n"); *)
                (* XXX need to remove \r here *)
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
    
    exception Done
    fun child (sock : R.sdesc) =
        let 
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
                                              prot p)
                               | _ => getmode p)
                        end

            and prot (p : L.pack) =
                case L.recvline (sock, p) of
                    NONE => print "bye-bye\n"
                  | SOME (line, p) =>
                        let in
                            print ("line: " ^ line ^ "\n");
                            (case StringUtil.field (fn #" " => true 
                                                     | #"\r" => true
                                                     | #"\n" => true
                                                     | _ => false) line of
                                 ("HELO", _) => sendall(sock, "250 tom7.org Wide awake and physical.\n")
                               | ("MAIL", _) => sendall(sock, "250 Sender ok\n")
                               | ("RCPT", _) => sendall(sock, "250 Recpt ok\n")
                               | ("DATA", _) => (sendall(sock, "354 Enter mail, ending with .\n");
                                                 getmode p)
                               (* | (".", _) => sendall(sock, "250 OK Accepted\n") *)
                               | ("QUIT", _) => (sendall(sock, "221 bye-bye\n"); 
                                                 R.hangup sock;
                                                 raise Done)
                               | _ => sendall (sock,
                                               "500 This server only accepts the most primitive commands.\n")
                                 );
                            prot p
                        end handle Done => ()
        in
            print "I'm the child.\n";
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
            print "\n\n---exiting---\n";
            Posix.Process.exit 0w0;
            ()
        end

end
