
structure MLtonCompat =
struct

  (* The mlton folks are working on a redesign of the basis
     library that adds a bunch of functionality but also changes
     some fundamental things. The rest of ML5/pgh uses the
     existing basis library, so in order to use the JS lib,
     we need some compatibility stubs. *)

  (* folds left; see ENUMERABLE in mltonlib/com/sweeks *)
  fun vector_fold (v, b, f) = Vector.foldl f b v
    
  (* XXX? *)
  fun char_fromHexDigit n = StringUtil.nybbletohex n
    
  fun vector_toListMap (v, f) = map f (Vector.foldr op:: nil v)
  val real_toIntInf = Real.toLargeInt IEEEReal.TO_NEAREST

  (* folds left; see ENUMERABLE *)
  fun array_fold (v, b, f) = Array.foldl f b v
  fun int_layout i = Layout.str (Int.toString i)

  (* just used for stats, which assumes ints are bounded (?) *)
  val int_maxInt = case Int.maxInt of
                     NONE => 1000000 * 1000000
                   | SOME i => i
  val int_minInt = case Int.minInt of
                     NONE => ~ (1000000 * 1000000)
                   | SOME i => i
  fun array_foreach (a, f) = Array.app f a
  fun list_foreach (l, f) = List.app f l
  fun vector_foreach (v, f) = Vector.app f v
  (* left, see com/sweeks/list.sig *)
  fun list_fold (l, b, f) = List.foldl f b l

  fun int_dec (r as ref x) = r := x - 1
  fun int_inc (r as ref x) = r := x + 1
  fun array_modify (a, f) = Array.modify f a
  fun array_forall (a, f) = Array.all f a
  fun list_forall (l, f) = List.all f l

  fun vector_new0 () = Vector.fromList nil
  fun vector_new1 e = Vector.fromList [e]

  (* Char.toString is like String.toString composed with this *)
  fun char_tostring c = implode [c]

  fun bool_layout true = Layout.str "true"
    | bool_layout false = Layout.str "false"

  fun list_peek (l, f) =
    let
      fun loop l =
        case l of
          [] => NONE
        | x :: l => if f x then SOME x else loop l
    in
      loop l
    end

  fun list_removeFirst (l, f) =
    let
      fun appendRev (l, l') = list_fold (l, l', op ::)
      fun loop (l, ac) =
        case l of
          [] => raise Empty
        | x :: l =>
            if f x
            then appendRev (ac, l)
            else loop (l, x :: ac)
    in loop (l, [])
    end


  fun list_layout f l = Layout.list (map f l)

  (* normally the Trace structure adds debugging info to functions.
     we turn that off, which makes most arguments ignored. *)
  structure Trace =
  struct
    fun trace3 (_, _, _, _, _) f = f 
    val trace3 : 'str * 'lay1 * 'lay2 * 'lay3 * 'lay4 -> 'f -> 'f = trace3
  end


end