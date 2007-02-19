
structure Web =
struct

  structure R = RawNetwork
  exception Web of string

  val PORT = 2222

  fun message (Eval.Abort s) = "abort: " ^ s
    | message (Web s) = "web: " ^ s
    | message e = "?:" ^ exnMessage e

  fun go () =
    let
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
          val (hdrs, content) = recvhttp p
          val (method, h') = StringUtil.token (StringUtil.ischar #" ") hdrs
          val (url, h') = StringUtil.token (StringUtil.ischar #" ") h'

          val kvp = String.fields (StringUtil.ischar #"&") content
          val kvp = List.mapPartial (fn one =>
                                     case String.fields (StringUtil.ischar #"=") one of
                                       [key, value] => (case StringUtil.urldecode value of
                                                          NONE => NONE
                                                        | SOME s => SOME (key, s))
                                     | _ => NONE) kvp

          (* put form elements in database *)
          (* should we also put a parsed/tokenized version of these? *)
          val () = app (fn (k, v) => ignore (DB.insert ("form." ^ k) (Bytes.String v))) kvp

          (* val () = ignore (DB.insert "request.method" "GET") *)
          val () = ignore (DB.insert "request.url" (Bytes.String url))

          fun http code = ("HTTP/1.1 " ^ code ^ "\r\n" ^
          "Date: " ^ (Date.fmt "%a, %d %b %Y %H:%M:%S %Z" (Date.fromTimeLocal (Time.now ()))) ^ "\r\n" ^
           "Server: Wikiplia\r\n" ^
           "Connection: close\r\n");


        in
          print ("URL: [" ^ url ^ "]\n");
          app (fn (k, v) => print ("[" ^ k ^ "]=[" ^ v ^ "]\n")) kvp;

          print "send response...\n";

          (let
             val res = 
               case Eval.eval (DB.head "main") of
                 Bytes.String s => s
               | _ => ("Content-Type: text/html; charset=utf-8\r\n" ^
                       "\r\n" ^
                       "(complex data)")
           in
             if StringUtil.matchhead "Location:" res
             then 
               let in
                 print ("Redirect: [" ^ res ^ "]\n");
                 sendall p (http "301 Moved Permanently" ^ res)
               end
             else
               let in
                 print ("Result: [" ^ res ^ "]\n");
                 sendall p (http "200 OK" ^ res)
               end
           end handle e => (print "ERROR.\n";
                            (* XXX internal server error? *)
                            sendall p (http "200 OK");
                            sendall p ("Content-Type: text/html; charset=utf-8\r\n" ^
                                       "\r\n");
                            sendall p ("ERROR. " ^ message e)));
          print "hangup...\n";
          (R.hangup p) handle _ => ();
          DB.save "database.wpdb"
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

      and recvhttp p =
        let
          val headerlength = ref NONE (* length of headers string up to and including
                                         the terminating \r\n\r\n *)
          val contentlength = ref NONE

          (* string preceding content length int *)
          val cls = "Content-Length: "

          (* XXX I think HTTP/1.0 can also be connection:close w/o content length? *)
          fun more s =
            (print ("sofar: [" ^ s ^ "]\n");
             case R.recv p of
               "" => (s, "") (* XXX what do we assume if connection closed? *)
             | s' => 
                 let val s = s ^ s'
                   fun next () =
                   (case !headerlength of
                      SOME h =>
                        (case !contentlength of
                           SOME cl =>
                             (* did we read enough? *)
                             if size s >= h + cl
                             then (String.substring(s, 0, h),
                                   String.substring(s, h, cl))
                             else more s
                         | NONE => (* XXX? *) (print "bad content length...\n"; 
                                               raise R.RawNetwork "uhhh"))
                    | NONE =>
                           (case StringUtil.find "\r\n\r\n" s of
                              SOME n => (headerlength := SOME (n + 4);
                                         (case StringUtil.find cls s of
                                            SOME cl => 
                                              (contentlength :=
                                               Int.fromString(String.substring(s,
                                                                               cl + size cls,
                                                                               size s - (cl + size cls)));
                                               next ())
                                          | NONE => (* assume no content... *) (s, "")))
                            | NONE => more s))
                 in
                      next ()
                 end)
        in
          more ""
        end
    in
      loop ()
    end

end