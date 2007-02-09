
structure Web =
struct

  structure R = RawNetwork

  val PORT = 2222

  val server = R.listen PORT

  fun loop () =
    (let
       val () = print "accept...\n"
       val (peer, peera) = R.accept server
     in
       print "process request...\n";
       request peer;
       loop ()
     end)
       
  and request p =
    let
      val () = print "receive message..."
      val r = recvall p
    in
      print "send response...\n";
      sendall p
      ("HTTP/1.1 200 OK\r\n" ^
      "Date: " ^ (Date.fmt "%a, %d %b %Y %H:%M:%S %Z" (Date.fromTimeLocal (Time.now ()))) ^ "\r\n" ^
       "Server: Wikiplia\r\n" ^
       "Connection: close\r\n" ^
       "Content-Type: text/html; charset=utf-8\r\n" ^
       "\r\n");

      sendall p "<p><b>We have received your message and will delete it promptly.</b></p>\n";
      sendall p ("<p>P.S. your message was: [" ^ r ^ "]</p>\n");
      sendall p ("<p><form action=\"whatever\" method=\"post\"><input type=text name=a><textarea name=b>woo</textarea><input type=submit value=\"go\"></form></p>");
      print "hangup...\n";
      (R.hangup p) handle _ => ()
    end

  and sendall p s =
    let
      val x = R.send p s
    in
      if x < 0
      then raise R.RawNetwork "sendall to closed" (* closed? *)
      else
        if x < size s
        then sendall p (String.substring(s, x, size s - x))
        else () 
    end

  and recvall p =
    let
      fun more s =
        (print ("sofar: [" ^ s ^ "]\n");
         case R.recv p of
           "" => s
         | s' => 
             let val s = s ^ s'
             in
               if size s >= 4 andalso String.substring(s, size s - 4, 4) = "\r\n\r\n"
               then s
               else more s
             end)
    in
      more ""
    end

end