
(* This is the main event loop for SERVER 5.
   The only kind of event is a network event: a new connection, a new packet,
   or failure. We also dole out periodic timeslices when nothing else is
   happening. 

   We have one master LISTENER socket waiting for web requests. In this loop
   we decide what to do with an incoming request; this depends on what URL
   the request is for.

      /5/prog                 ... start a new session for the program "prog"

      /toclient/<sessionid>   
      /toserver/<sessionid>   ... hand the connection off to the active session
                                  with this ID

      other urls              ... serve an error message

*)

structure Loop =
struct

  infixr 9 `
  fun a ` b = a b

  exception Loop of string

  structure N = Network

  val listener = ref NONE : N.listener option ref

  (* Sockets that have not been assigned to a session yet *)
  val incoming = ref nil : N.sock list ref

  fun !!(ref (SOME x)) = x
    | !! _ = raise Loop "impossible !! NONE"

  val http = Http.protocol

  fun loop () =
    let
      val socks = ! incoming @ Session.sockets ()

      fun nis s s' = N.eq (s, s')
    in
      (case N.wait [!!listener] socks ` SOME ` Time.fromMilliseconds 1000 of
         (* must be the one listener *)
         N.Accept (_, s, _, _) => incoming := s :: !incoming
       (* we don't make any outgoing connections *)
       | N.Connected _ => raise Loop "should never get Connected event"
       (* could be ours or a session's *)
       | N.Closed s =>
           (case ListUtil.extract (nis s) ` !incoming of
              NONE => Session.closed s
            (* we just drop incomplete requests without incident. *)
            | SOME (_, rest) => incoming := rest)
       (* ditto *)
       | N.Packet (p, s) => 
              (case ListUtil.extract (nis s) ` !incoming of
                 NONE => Session.packet (p, s)
               | SOME (_, rest) =>
                   let in
                     (* Once we get a packet (HTTP headers) we're ready to hand this
                        socket off or get rid of it entirely. So remove it from our
                        list *)
                     incoming := rest;
                     request s ` N.decode http p
                   end)
       | _ => 
          let in
            Session.step ()
          end);

      loop ()
    end

  and request s (cmd :: headers, so) = 
    let
      fun expectint str (f : int -> unit) : unit =
        case Int.fromString str of
          NONE => error404 s "URL not found (expected int)"
        | SOME i => f i
    in
      print "REQUEST:\n";
      app (fn s => print ("  " ^ s ^ "\n")) (cmd :: headers);
      print "DATA:\n";
      Option.app (fn s => print ("  " ^ s ^ "\n")) so;

      case String.tokens (StringUtil.ischar #" ") cmd of
        "GET" :: url :: _ =>
          (case StringUtil.token (StringUtil.ischar #"/") url of
             ("5", prog) => Session.new s prog
           | ("toclient", id) => expectint id ` Session.toclient s
           | ("toserver", id) => expectint id ` Session.toserver s
           | ("exit", _) => raise Loop "EXIT."
           | _ => error404 s "URL not found.")
      | method :: _ => error501 s ("unsupported method " ^ method)
      | _ => error501 s "??"
    end
    | request s _ = 
       let in
         error501 s "request lacked command";
         print "Request lacked command\n"
       end

  and error501 s str =
       let in
         N.sendraw s
         ("HTTP/1.1 501 Method Not Implemented\r\n" ^
          "Date: " ^ Version.date () ^ "\r\n" ^
          "Server: " ^ Version.version ^ "\r\n" ^
          "Allow: GET, POST\r\n" ^
          "Connection: close\r\n" ^
          "Content-Type: text/html; charset=utf-8\r\n" ^
          "\r\n" ^
          str);
         N.disconnect s
       end
         
  and error404 s str =
       let in
         N.sendraw s
         ("HTTP/1.1 404 URL Not Found\r\n" ^
          "Date: " ^ Version.date () ^ "\r\n" ^
          "Server: " ^ Version.version ^ "\r\n" ^
          "Connection: close\r\n" ^
          "Content-Type: text/html; charset=utf-8\r\n" ^
          "\r\n" ^
          str);
         N.disconnect s
       end


  fun init () =
    (* XXX from parameter / config *)
    listener := SOME ` N.listen http 5555

end
