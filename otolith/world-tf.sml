(* Generated from world.tfdesc by tfcompiler. Do not edit! *)

structure WorldTF :>
sig
  datatype node = N of {
    id : int,
    coords : (string * int * int) list,
    triangles : (int * int) list
  }

  and keyedtesselation = KT of {
    nodes : node list
  }

  and screen = S of {
    areas : keyedtesselation,
    objs : keyedtesselation list
  }

  and world = W of {
    screens : (int * int * screen) list
  }

  exception Parse of string

  structure N :
  sig
    type t = node
    val tostring : t -> string
    val fromstring : string -> t
    val maybefromstring : string -> t option

    val tofile : string -> t -> unit
    val fromfile : string -> t
    val maybefromfile : string -> t option

    val default : t
  end

  structure KT :
  sig
    type t = keyedtesselation
    val tostring : t -> string
    val fromstring : string -> t
    val maybefromstring : string -> t option

    val tofile : string -> t -> unit
    val fromfile : string -> t
    val maybefromfile : string -> t option

    val default : t
  end

  structure S :
  sig
    type t = screen
    val tostring : t -> string
    val fromstring : string -> t
    val maybefromstring : string -> t option

    val tofile : string -> t -> unit
    val fromfile : string -> t
    val maybefromfile : string -> t option

    val default : t
  end

  structure W :
  sig
    type t = world
    val tostring : t -> string
    val fromstring : string -> t
    val maybefromstring : string -> t option

    val tofile : string -> t -> unit
    val fromfile : string -> t
    val maybefromfile : string -> t option

    val default : t
  end

end =





(* Implementation follows. You want to read tfcompiler.sml or
   the README, not this generated, uncommented code. *)
struct
  datatype node = N of {
    id : int,
    coords : (string * int * int) list,
    triangles : (int * int) list
  }

  and keyedtesselation = KT of {
    nodes : node list
  }

  and screen = S of {
    areas : keyedtesselation,
    objs : keyedtesselation list
  }

  and world = W of {
    screens : (int * int * screen) list
  }

  exception Parse of string

  structure S = Substring

  fun readfile f =
    let val l = TextIO.openIn f
        val s = TextIO.inputAll l
    in TextIO.closeIn l; s
    end
  fun writefile f s =
   let val l = TextIO.openOut f
   in  TextIO.output (l, s);
       TextIO.closeOut l
   end
  fun maybefromstringwith fs s =
    (SOME (fs s)) handle Parse _ => NONE
  fun fromfilewith fs f = fs (readfile f)
  fun maybefromfilewith fs f =
    (SOME (fs (readfile f))) handle Parse _ => NONE
  fun tofilewith ts f t = writefile f (ts t)

  datatype dllcell' =
    D' of string * dllcell' option ref
  type dll' = dllcell' * dllcell' option ref
  fun ^^ ((head, t as ref NONE),
          (h, tail)) =
    let in
      t := SOME h;
      (head, tail)
    end
   | ^^ _ =
     raise Parse "^^ bug"
  infix 2 ^^
  fun $s : dll' = let val r = ref NONE in (D'(s, r), r) end
  fun dlltostring (head, _) =
    let fun dts (D' (s, r)) =
          case !r of
             NONE => s
           | SOME d => s ^ dts d
    in dts head
    end
  fun dllconcat' nil = $""
    | dllconcat' (h :: t) = h ^^ dllconcat' t
  fun dllconcatwith' s nil = $""
    | dllconcatwith' s [e] = e
    | dllconcatwith' s (h :: t) = h ^^ $s ^^ dllconcatwith' s t
  fun nspaces' n = CharVector.tabulate (n, fn _ => #" ")
  fun itos' i = if i < 0
                then "-" ^ Int.toString (~i)
                else Int.toString i
  fun stos' str =
    let
      val digits = "0123456789ABCDEF"
      fun hexdig i = implode [#"\\",
                              CharVector.sub (digits, i div 16),
                              CharVector.sub (digits, i mod 16)]
      fun noescape #"\"" = false (* " *)
        | noescape #"\\" = false
        | noescape c = ord c >= 32 andalso ord c <= 126
      fun ss (s : S.substring) =
        let val (clean, dirty) = S.splitl noescape s
        in case S.getc dirty of
              NONE => [clean, S.full "\""] (* " *)
            | SOME (c, rest) =>
                clean :: S.full (hexdig (ord c)) :: ss rest
        end
    in
      S.concat (S.full "\"" :: ss (S.full str)) (* " *)
    end
  datatype fielddata' =
      Int' of int
    | String' of string
    | List' of fielddata' list
    | Message' of string * (string * fielddata') list
  datatype token' =
      LBRACE' | RBRACE' | LBRACK' | RBRACK'
    | COMMA' | INT' of int | STRING' of string
    | SYMBOL' of S.substring
  type field' = string * fielddata'
  fun whitespace #" " = true
    | whitespace #"\n" = true
    | whitespace #"\r" = true
    | whitespace #"\t" = true
    | whitespace _ = false
  fun readfields (str : S.substring) : field' list * S.substring =
    let
      fun isletter c = (ord c >= ord #"a" andalso ord c <= ord #"z")
          orelse (ord c >= ord #"A" andalso ord c <= ord #"Z")
      fun numeric #"-" = true
        | numeric c = ord c >= ord #"0" andalso ord c <= ord #"9"
      fun symbolic c = isletter c orelse
        ord c >= ord #"0" andalso ord c <= ord #"9"
      fun readint (s : S.substring) : token' * S.substring =
        let val (f, s) = case S.sub (s, 0) of
               #"-" => (~, S.triml 1 s)
             | _ => ((fn x => x), s)
            val (intpart, rest) = S.splitl numeric s
        in case Int.fromString (S.string intpart) of
             NONE => raise Parse ("Expected integer")
           | SOME i => (INT' (f i), rest)
        end
      fun readsym (s : S.substring) : token' * S.substring =
        let val (sympart, rest) = S.splitl symbolic s
        in (SYMBOL' sympart, rest)
        end
      fun readstring (str : S.substring) : token' * S.substring =
        let val str = S.triml 1 str
            fun stop #"\"" = false (* " *)
              | stop #"\\" = false
              | stop c = true
            fun hexvalue c =
              let val oc = ord c
              in  if oc >= ord #"a" andalso oc <= ord #"f"
                  then 10 + (oc - ord #"a")
                  else if oc >= ord #"A" andalso oc <= ord #"F"
                  then 10 + (oc - ord #"A")
                  else if oc >= ord #"0" andalso oc <= ord #"9"
                  then (oc - ord #"0")
                  else raise Parse "bad escaped hex digit"
              end
            fun getescape (s : S.substring) : char * S.substring =
              if S.size s < 2
              then raise Parse "expected escape sequence"
              else let val c1 = S.sub (s, 0)
                       val c2 = S.sub (s, 1)
                       val s = S.triml 2 s
                   in (chr (hexvalue c1 * 16 + hexvalue c2), s)
                   end
            fun de (s : S.substring) =
              let val (clean, dirty) = S.splitl stop s
                  val (l, rest) =
                 (case S.getc dirty of
                    NONE => raise Parse "unterminated string"
                  | SOME (#"\"", rest) => (nil, rest) (* " *)
                  | SOME (#"\\", rest) =>
                    let val (c, rest) = getescape rest
                        val (ll, rest) = de rest
                    in (S.full (String.implode [c]) :: ll, rest)
                    end
                  | _ => raise Parse "bug: impossible dirty char")
              in (clean :: l, rest)
              end
          val (l, rest) = de str
        in
          (STRING' (Substring.concat l), rest)
        end
      fun get_token (s : S.substring) :
            (token' * S.substring) option =
        let val s = S.dropl whitespace s
        in if S.isEmpty s then NONE
           else SOME (case S.sub (s, 0) of
                  #"}" => (RBRACE', S.triml 1 s)
                | #"{" => (LBRACE', S.triml 1 s)
                | #"]" => (RBRACK', S.triml 1 s)
                | #"[" => (LBRACK', S.triml 1 s)
                | #"," => (COMMA',  S.triml 1 s)
                | #"\"" => readstring s (* " *)
                | c => if isletter c
                       then readsym s
                       else if numeric c
                       then readint s
                       else raise Parse ("Unexpected character '" ^
                                         implode [c] ^ "'"))
        end
      fun get_data_maybe (s : S.substring) :
           (fielddata' * S.substring) option =
        case get_token s of
           NONE => raise Parse "Expected data"
         | SOME (INT' i, s) => SOME (Int' i, s)
         | SOME (STRING' str, s) => SOME (String' str, s)
         | SOME (LBRACK', s) =>
           let fun eat s =
                case get_data_maybe s of
                   NONE => (nil, s)
                 | SOME (d, s) => let val (l, s) = eat s
                                  in (d :: l, s)
                                  end
               val (l, s) = eat s
           in case get_token s of
                  SOME (RBRACK', s) => SOME (List' l, s)
                | _ => raise Parse "expected closing bracket"
           end
         | SOME (LBRACE', s) =>
           (case get_token s of
              SOME (SYMBOL' m, s) =>
                let val (fs, s) = readfields s
                in case get_token s of
                     SOME (RBRACE', s) =>
                         SOME (Message' (S.string m, fs), s)
                   | _ => raise Parse "expected rbrace after message"
                end
            | _ => raise Parse "expected symbol after lbrace")
         | SOME _ => NONE
      fun get_data s =
          case get_data_maybe s of
              NONE => raise Parse "expected field data"
            | SOME d => d
      fun get_field (s : S.substring) : (field' * S.substring) option =
        case get_token s of
            NONE => NONE
          | SOME (SYMBOL' tok, s) => let val (d, s) = get_data s
                                     in SOME ((S.string tok, d), s)
                                     end
          | SOME (RBRACE', _) => NONE
          | SOME _ => raise Parse ("unexpected token: " ^ S.string s)
    in
       case get_field str of
           NONE => (nil, str)
         | SOME (f, rest) => let val (l, rest) = readfields rest
                             in (f :: l, rest)
                             end
    end
  fun readallfields (s : string) : field' list =
    let val (fs, s) = readfields (S.full s)
        val s = S.dropl whitespace s
    in if S.isEmpty s
       then fs
       else raise Parse "Unparseable leftovers"
    end

  val node_default' : node = N {
    id = 0,
    coords = nil,
    triangles = nil
  }
  val keyedtesselation_default' : keyedtesselation = KT {
    nodes = nil
  }
  val screen_default' : screen = S {
    areas = keyedtesselation_default',
    objs = nil
  }
  val world_default' : world = W {
    screens = nil
  }

  fun node_fromfields' (fs : field' list) : node=
    let
        val id_ref' : (int) ref =
          ref (0)
        val coords_ref' : ((string * int * int) list) ref =
          ref (nil)
        val triangles_ref' : ((int * int) list) ref =
          ref (nil)
      fun read' d' =
      case d' of
        ("id", d') =>
          id_ref' :=
          (case d' of Int' i => i
            | _ => raise Parse "expected int")
      | ("c", d') =>
          coords_ref' :=
          (case d' of List' l =>
            List.map (fn d' => (case d' of List' [f0', f1', f2'] =>
                            ((case f0' of String' s => s
                                | _ => raise Parse "expected string"),
                              (case f1' of Int' i => i
                                | _ => raise Parse "expected int"),
                              (case f2' of Int' i => i
                                | _ => raise Parse "expected int"))
                            | _ => raise Parse "expected 3-list for tuple")) l
            | _ => raise Parse "expected list for list")
      | ("t", d') =>
          triangles_ref' :=
          (case d' of List' l =>
            List.map (fn d' => (case d' of List' [f0', f1'] =>
                            ((case f0' of Int' i => i
                                | _ => raise Parse "expected int"),
                              (case f1' of Int' i => i
                                | _ => raise Parse "expected int"))
                            | _ => raise Parse "expected 2-list for tuple")) l
            | _ => raise Parse "expected list for list")
      | _ => ()
    in
      app read' fs;
      N {
          id = !id_ref',
          coords = !coords_ref',
          triangles = !triangles_ref'
        }
    end

  and keyedtesselation_fromfields' (fs : field' list) : keyedtesselation=
    let
        val nodes_ref' : (node list) ref =
          ref (nil)
      fun read' d' =
      case d' of
        ("ns", d') =>
          nodes_ref' :=
          (case d' of List' l =>
            List.map (fn d' => (case d' of Message' ("N", fs) => node_fromfields' fs
                            | _ => raise Parse "expected submessage node")) l
            | _ => raise Parse "expected list for list")
      | _ => ()
    in
      app read' fs;
      KT {
          nodes = !nodes_ref'
        }
    end

  and screen_fromfields' (fs : field' list) : screen=
    let
        val areas_ref' : (keyedtesselation) ref =
          ref (keyedtesselation_default')
        val objs_ref' : (keyedtesselation list) ref =
          ref (nil)
      fun read' d' =
      case d' of
        ("areas", d') =>
          areas_ref' :=
          (case d' of Message' ("KT", fs) => keyedtesselation_fromfields' fs
            | _ => raise Parse "expected submessage keyedtesselation")
      | ("objs", d') =>
          objs_ref' :=
          (case d' of List' l =>
            List.map (fn d' => (case d' of Message' ("KT", fs) => keyedtesselation_fromfields' fs
                            | _ => raise Parse "expected submessage keyedtesselation")) l
            | _ => raise Parse "expected list for list")
      | _ => ()
    in
      app read' fs;
      S {
          areas = !areas_ref',
          objs = !objs_ref'
        }
    end

  and world_fromfields' (fs : field' list) : world=
    let
        val screens_ref' : ((int * int * screen) list) ref =
          ref (nil)
      fun read' d' =
      case d' of
        ("screens", d') =>
          screens_ref' :=
          (case d' of List' l =>
            List.map (fn d' => (case d' of List' [f0', f1', f2'] =>
                            ((case f0' of Int' i => i
                                | _ => raise Parse "expected int"),
                              (case f1' of Int' i => i
                                | _ => raise Parse "expected int"),
                              (case f2' of Message' ("S", fs) => screen_fromfields' fs
                                | _ => raise Parse "expected submessage screen"))
                            | _ => raise Parse "expected 3-list for tuple")) l
            | _ => raise Parse "expected list for list")
      | _ => ()
    in
      app read' fs;
      W {
          screens = !screens_ref'
        }
    end

  fun node_todll' (depth' : int, (N { id, coords, triangles }) : node) : dll' =
    $"id " ^^ $(itos' id) ^^ $" " ^^
    $"c " ^^ ($"[" ^^
               dllconcatwith' " " (List.map
               (fn v => let val (f0', f1', f2') = v
                    in
                      $"[" ^^ $(stos' f0') ^^ $" " ^^ $(itos' f1') ^^ $" " ^^ $(itos' f2') ^^ $"]"
                    end) coords
            ) ^^ $"]") ^^ $" " ^^
    $"t " ^^ ($"[" ^^
               dllconcatwith' " " (List.map
               (fn v => let val (f0', f1') = v
                    in
                      $"[" ^^ $(itos' f0') ^^ $" " ^^ $(itos' f1') ^^ $"]"
                    end) triangles
            ) ^^ $"]")

  and keyedtesselation_todll' (depth' : int, (KT { nodes }) : keyedtesselation) : dll' =
    $"ns " ^^ ($"[\n" ^^
               dllconcat' (List.map
               (fn v => $(nspaces' depth') ^^ ($"{N " ^^ node_todll'(depth' + 2, v) ^^ $"}") ^^ $"\n") nodes
            ) ^^ $"]")

  and screen_todll' (depth' : int, (S { areas, objs }) : screen) : dll' =
    $"areas " ^^ ($"{KT " ^^ keyedtesselation_todll'(depth' + 2, areas) ^^ $"}") ^^ $" " ^^
    $"objs " ^^ ($"[\n" ^^
               dllconcat' (List.map
               (fn v => $(nspaces' depth') ^^ ($"{KT " ^^ keyedtesselation_todll'(depth' + 2, v) ^^ $"}") ^^ $"\n") objs
            ) ^^ $"]")

  and world_todll' (depth' : int, (W { screens }) : world) : dll' =
    $"screens " ^^ ($"[" ^^
               dllconcatwith' " " (List.map
               (fn v => let val (f0', f1', f2') = v
                    in
                      $"[" ^^ $(itos' f0') ^^ $" " ^^ $(itos' f1') ^^ $" " ^^ ($"{S " ^^ screen_todll'(depth' + 2, f2') ^^ $"}") ^^ $"]"
                    end) screens
            ) ^^ $"]")



  structure N =
  struct
    type t = node
    fun tostring (m : t) : string =
      dlltostring (node_todll' (0, m))

    fun fromstring s =
      let val fs = readallfields s
      in node_fromfields' fs
      end

    (* derived *)
    val maybefromstring = maybefromstringwith fromstring
    val tofile = tofilewith tostring
    val fromfile = fromfilewith fromstring
    val maybefromfile = maybefromfilewith fromstring
    val default = node_default'
  end


  structure KT =
  struct
    type t = keyedtesselation
    fun tostring (m : t) : string =
      dlltostring (keyedtesselation_todll' (0, m))

    fun fromstring s =
      let val fs = readallfields s
      in keyedtesselation_fromfields' fs
      end

    (* derived *)
    val maybefromstring = maybefromstringwith fromstring
    val tofile = tofilewith tostring
    val fromfile = fromfilewith fromstring
    val maybefromfile = maybefromfilewith fromstring
    val default = keyedtesselation_default'
  end


  structure S =
  struct
    type t = screen
    fun tostring (m : t) : string =
      dlltostring (screen_todll' (0, m))

    fun fromstring s =
      let val fs = readallfields s
      in screen_fromfields' fs
      end

    (* derived *)
    val maybefromstring = maybefromstringwith fromstring
    val tofile = tofilewith tostring
    val fromfile = fromfilewith fromstring
    val maybefromfile = maybefromfilewith fromstring
    val default = screen_default'
  end


  structure W =
  struct
    type t = world
    fun tostring (m : t) : string =
      dlltostring (world_todll' (0, m))

    fun fromstring s =
      let val fs = readallfields s
      in world_fromfields' fs
      end

    (* derived *)
    val maybefromstring = maybefromstringwith fromstring
    val tofile = tofilewith tostring
    val fromfile = fromfilewith fromstring
    val maybefromfile = maybefromfilewith fromstring
    val default = world_default'
  end

end
