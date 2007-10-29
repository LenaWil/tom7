
structure Action =
struct

    structure R = RawNetwork

    datatype part =
        Text of string
      (* decoding the base64 *)
      | Data of string


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

    fun recvall (sock) =
        case R.recv sock of
            "" => (R.hangup sock handle _ => (); "")
          | s => s ^ recvall sock

    fun connectsend (host, port, data) =
        let val sock = R.connect host port
        in  sendall (sock, data);
            print "Response:\n";
            print (recvall sock)
        end

    val CRLF = "\r\n"

    (* get rid of blank lines at front, end *)
    fun compact s = 
        let val s = StringUtil.losespecl (fn #"\n" => true | _ => false) s
            val s = StringUtil.losespecr (fn #"\n" => true | _ => false) s
        in s
        end

    fun perform (Config.MessageBoard i, subject, parts) =
        let
            val sep = "XXX-MAKE-RANDOM"

            val message_body = String.concat (map (fn Text s => s | _ => "") parts)

            val (theimage, thetitle) =
                (case ListUtil.findpartial (fn Data s => SOME s | _ => NONE) parts of
                     SOME d => (d, Config.MSG_IMGTITLE)
                   | _ => ("", ""))

            val pieces =
                (* no need for seql, seqh if password given,
                   nor poison, pw. *)
                [("n", Int.toString i),
                 ("msg", "0"),
                 ("adminpass", Config.MSG_ADMINPASS),
                 ("postname", Config.MSG_POSTNAME),
                 ("subject", subject),
                 ("content", message_body),
                 ("imgtitle", thetitle)]

            val bodyparts =
                map (fn (key, data) =>
                     "Content-Disposition: form-data; name=\"" ^ key ^ "\"" ^ CRLF ^
                     CRLF ^
                     data) pieces @
                (* XXX this is bogus when there's no image, but it should
                   probably not mess anything up on the server *)
                ["Content-Disposition: form-data; name=\"image\"; filename=\"maildar.jpg\"" ^ CRLF ^
                 "Content-Type: image/jpeg" ^ CRLF ^
                 CRLF ^
                 theimage]
                     
            val body =
                "--" ^ sep ^ CRLF ^
                StringUtil.delimit (CRLF ^ "--" ^ sep ^ CRLF) bodyparts ^
                CRLF ^ "--" ^ sep ^ "--" ^ CRLF

            val msg =
                "POST /f/a/s/msg/reallyreply HTTP/1.1" ^ CRLF ^
                "Host: " ^ Config.MSG_HOST ^ CRLF ^
                "Accept: text/xml,application/xml,application/xhtml+xml," ^
                    "text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" ^ CRLF ^
                "Accept-Language: en-us,en;q=0.5" ^ CRLF ^
                "Accept-Encoding: gzip,deflate" ^ CRLF ^
                "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7" ^ CRLF ^
                "User-Agent: maildar" ^ CRLF ^
                "Connection: close" ^ CRLF ^
                "Content-Type: multipart/form-data; boundary=" ^ sep ^ CRLF ^
                "Content-Length: " ^ Int.toString (size body) ^ CRLF ^
                CRLF ^
                body
        in
            (* StringUtil.writefile "/tmp/cool" msg;
            print "Here's the message: (in /tmp/cool)\n"; *)
            connectsend(Config.MSG_HOST, Config.MSG_PORT, msg);
            print "message sent!\n"
        end

      | perform (Config.Radar i, subject, parts) =
        let
            val sep = "XXX-MAKE-RANDOM"

            val message_body = String.concat (map (fn Text s => s | _ => "") parts)
            val message_body = compact message_body

            val theimage =
                case ListUtil.findpartial (fn Data s => SOME s | _ => NONE) parts of
                    SOME d => d
                  | _ => ""

            val pieces =
                (* no need for seql, seqh if password given,
                   nor poison, pw. *)
                [("n", Int.toString i),
                 ("pass", Config.WEBLOG_PASS),
                 ("cssclass", "mobile"),
                 ("kindname", "mobile"),
                 ("kind", "5"), (* image *)
                 ("title", subject),
                 ("content", message_body)]

            val bodyparts =
                map (fn (key, data) =>
                     "Content-Disposition: form-data; name=\"" ^ key ^ "\"" ^ CRLF ^
                     CRLF ^
                     data) pieces @
                (* XXX this is bogus when there's no image, but it should
                   probably not mess anything up on the server *)
                ["Content-Disposition: form-data; name=\"thumb\"; filename=\"maildar.jpg\"" ^ CRLF ^
                 "Content-Type: image/jpeg" ^ CRLF ^
                 CRLF ^
                 theimage]
                     
            val body =
                "--" ^ sep ^ CRLF ^
                StringUtil.delimit (CRLF ^ "--" ^ sep ^ CRLF) bodyparts ^
                CRLF ^ "--" ^ sep ^ "--" ^ CRLF

            val msg =
                "POST /f/a/weblog/insert HTTP/1.1" ^ CRLF ^
                "Host: " ^ Config.MSG_HOST ^ CRLF ^
                "Accept: text/xml,application/xml,application/xhtml+xml," ^
                    "text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5" ^ CRLF ^
                "Accept-Language: en-us,en;q=0.5" ^ CRLF ^
                "Accept-Encoding: gzip,deflate" ^ CRLF ^
                "Accept-Charset: ISO-8859-1,utf-8;q=0.7,*;q=0.7" ^ CRLF ^
                "User-Agent: maildar" ^ CRLF ^
                "Connection: close" ^ CRLF ^
                "Content-Type: multipart/form-data; boundary=" ^ sep ^ CRLF ^
                "Content-Length: " ^ Int.toString (size body) ^ CRLF ^
                CRLF ^
                body
        in
            connectsend(Config.WEBLOG_HOST, Config.WEBLOG_PORT, msg);
            print "message sent!\n"
        end
      (* | perform _ = print "XXX unimplemented" *)


end