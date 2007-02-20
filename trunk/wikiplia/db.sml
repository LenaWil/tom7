
(* XXX this needs to support serialization to disk. *)
structure DB =
struct

  exception NotFound
  exception DB of string
  type int = IntInf.int

  infixr 9 `
  fun a ` b = a b

  structure SM = SplayMapFn(type ord_key = string
                            val compare = String.compare)

  type revision = IntInf.int
  val FIRST_REVISION : revision = 0

  (* careful: changing this function will invalidate all revisions.
     also Parse.parse o etos must be the identity.
     *)
  local val primmap = ListUtil.Alist.swap Bytes.prims
    open Bytes
  in
    fun etos (List el) = "(" ^ StringUtil.delimit " " (map etos el) ^ ")"
      | etos (String s) = "\"" ^ String.toString s ^ "\""
      | etos (Int i) = IntInf.toString i (* XXX negative ints? *)
      | etos (Symbol s) = s
      | etos (Quote q) = "'" ^ etos q
      | etos (Prim p) =
      (case ListUtil.Alist.find op= primmap p of
         SOME s => s
       | NONE => raise DB "can't serialize prim!")
      | etos (Closure (env, s, e)) = "(##CLOSURE## (" ^ String.concat (map (fn (s, v) => "(\"" ^ s ^ "\" " ^ etos v ^ ")") env) 
                                                  ^ ") \"" ^ s ^ "\" " ^ etos e^ ")"
  end

  (* We do edit distance on a chunkified version of the input. There are
     two kinds of chunks: whitespace, and everything else. The
     chunkified input is simply a vector of strings where no two
     consecutive chunks are of the same kind. *)

  datatype class = C_WS | C_OTHER
  fun class c = if StringUtil.whitespec c then C_WS else C_OTHER

  fun chunkstr s =
    let

      fun chunk start n =
        if n = size s then
           (if start = n then nil
            else [String.substring(s, start, n - start)])
        else 
          if start <> n andalso class (String.sub(s, n - 1)) <>
                                       class (String.sub(s, n))
          then (* new chunk *)
            String.substring(s, start, n - start) :: chunk n n
          else chunk start ( n + 1 )
             
    in
      Vector.fromList (chunk 0 0)
    end

  (* edit distance on vectors of strings, where
     modification and insertion must give the actual string *)
  structure SED = EditDistanceFn(type ch = string
                                 type str = string vector
                                 val eq = op =
                                 val sub = Vector.sub
                                 val len = Vector.length
                                 fun MODIFY_COST (_, ch) = 1 + size ch
                                 fun INSERT_COST ch = 1 + size ch
                                 fun DELETE_COST _ = 1)
  datatype ? = datatype SED.edit

  (* a plan tells us how to get from one unparsed string to the next *)
  type plan = SED.edit list
  (* XXX PERF *)
  fun playback s nil = s
    | playback s (Modify (i, c) :: r) = playback (Vector.tabulate (Vector.length s, 
                                                                   fn x =>
                                                                   if x = i
                                                                   then c
                                                                   else Vector.sub(s, x))) r
    | playback s (Delete i :: r) = playback (Vector.tabulate (Vector.length s - 1,
                                                              fn x =>
                                                              if x < i
                                                              then Vector.sub(s, x)
                                                              else Vector.sub(s, x + 1))) r
    | playback s (Insert (i, c) :: r) = playback (Vector.tabulate
                                                  (Vector.length s + 1,
                                                   fn x =>
                                                   if x < i
                                                   then Vector.sub(s, x)
                                                   else if x = i
                                                        then c
                                                        else Vector.sub(s, x - 1))) r

  (* each key has a number of revisions, and a current revision *)
  type db = ({ head : Bytes.exp,
               cur  : revision,
               revs : (revision * plan) list
               } SM.map * revision) ref

  (* start empty -- XXX should read from disk *)
  val db = ref (SM.empty, 0) : db

  fun insert key data =
    let val (t, now) = !db
    in
      (case SM.find (t, key) of
         NONE =>
           (* new. *)
           let in
             db := (SM.insert(t, key, 
                              { head = data,
                                cur = now + 1,
                                revs = nil
                                }),
                    now + 1);
             now + 1
           end
       | SOME { head, cur, revs } =>
           let 
             val (_, plan) = SED.minedit (chunkstr ` etos data, chunkstr ` etos head)
           in
             db := (SM.insert(t, key, 
                              { head = data,
                                cur = now + 1,
                                revs = (cur, plan) :: revs
                                }),
                    now + 1);
             now + 1
           end)
    end

  fun head key =
    (case SM.find (#1 (!db), key) of
       NONE => raise NotFound
     | SOME { head, ... } => head)

  fun read key rev =
    (case SM.find (#1 (!db), key) of
       NONE => raise NotFound
     | SOME { head, cur, revs } =>
         let
           fun findy d ((r, plan) :: rest) =
             let
               val d = playback d plan
             in
               (* PERF these are sorted, so could NotFound early... *)
               if r = rev then Parse.parse (String.concat (Vector.foldr op:: nil d))
               else findy d rest
             end
             | findy d nil = raise NotFound
         in
           if cur = rev then head
           else findy (chunkstr ` etos head) revs
         end)

  fun history key =
    (case SM.find (#1 (!db), key) of
       NONE => raise NotFound
     | SOME { head=_, cur, revs } => cur :: map #1 revs)

  fun save file =
    let
      fun stos s = Int.toString (size s) ^ "/" ^ s

      val (tree, head) = !db
      val f = TextIO.openOut file

      fun onekey (key, { head, cur, revs }) =
        let 
          val h = etos head

          fun showrev (r, plan) = 
            let 
              fun oneedit (Modify (i, s)) = TextIO.output(f, "M" ^
                                                         Int.toString i ^
                                                         ":" ^ stos s)
                | oneedit (Insert (i, s)) = TextIO.output(f, "I" ^
                                                         Int.toString i ^
                                                         ":" ^ stos s)
                | oneedit (Delete i) = TextIO.output (f, "D" ^ Int.toString i ^ ":")
            in
              TextIO.output(f, "!" ^ IntInf.toString r ^ "=");
              app oneedit plan;
              TextIO.output(f, "X\n")
            end
        in
          TextIO.output(f, StringUtil.urlencode key ^ " " ^ IntInf.toString cur ^ " " ^ stos h ^ "\n");
          app showrev revs;
          TextIO.output(f, "\n")
        end
    in
      TextIO.output(f, "WPDB\n");
      TextIO.output(f, IntInf.toString head ^ "\n");
      SM.appi onekey tree;

      TextIO.closeOut f
    end

  (* replaces database *)
  fun load file =
    let
      val f = TextIO.openIn file

      fun until stop =
        let
          fun unt () =
            case TextIO.input1 f of
              SOME c => if c = stop then nil
                        else c :: unt ()
            | NONE => raise NotFound
        in
          implode ` unt ()
        end

      fun getlenstr () =
        let
          val n = valOf ` Int.fromString ` until #"/"
        in
          TextIO.inputN (f, n)
        end

      val hdr = TextIO.inputLine f
      val () = if hdr <> SOME "WPDB\n" then raise NotFound else ()
      val cur = valOf ` IntInf.fromString ` valOf ` TextIO.inputLine f

      val base = ref SM.empty

      (* read keys and insert them *)
      fun readkeys () =
        if TextIO.endOfStream f then ()
        else
        let
          val key = valOf ` StringUtil.urldecode ` until #" "
          val cur = valOf ` IntInf.fromString ` until #" "
          val head = getlenstr ()

          val revs = ref nil

          fun readrevs () =
            case TextIO.input1 f of
              SOME #"!" =>
              let
                val r = valOf ` IntInf.fromString ` until #"="
                fun readplan () =
                  case TextIO.input1 f of
                    SOME #"X" => nil
                  | SOME #"M" =>
                    let val at = valOf ` Int.fromString ` until #":"
                      val s = getlenstr ()
                    in
                      Modify(at, s) :: readplan ()
                    end
                  | SOME #"D" =>
                    let val at = valOf ` Int.fromString ` until #":"
                    in
                      Delete at :: readplan ()
                    end
                  | SOME #"I" => 
                    let val at = valOf ` Int.fromString ` until #":"
                      val s = getlenstr ()
                    in
                      Insert(at, s) :: readplan ()
                    end
                  | _ => raise NotFound

                val plan = readplan ()
              in
                revs := (r, plan) :: !revs
              end
            | SOME #"\n" => ()
            | _ => raise NotFound
        in
          ignore ` until #"\n";
          (* now read a series of revs *)
          readrevs ();
          base := SM.insert(!base, key, { head = Parse.parse head, 
                                          revs = rev (!revs), cur = cur });
          readkeys ()
        end
    in
      readkeys ();
      TextIO.closeIn f;
      db := (!base, cur)
    end
    

end
