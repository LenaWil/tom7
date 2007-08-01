(* Copyright (C) 1999-2005 Henry Cejtin, Matthew Fluet, Suresh
 *    Jagannathan, and Stephen Weeks.
 *
 * MLton is released under a BSD-style license.
 * See the file MLton-LICENSE for details.
 *)

structure HashSet: HASH_SET =
struct

  open MLtonCompat
  
datatype 'a t =
   T of {buckets: 'a list array ref,
         hash: 'a -> word,
         mask: word ref,
         numItems: int ref}

fun 'a newWithBuckets {hash, numBuckets: int}: 'a t =
   let
      val mask: word = Word.fromInt numBuckets - 0w1
   in
      T {buckets = ref (Array.array (numBuckets, [])),
         hash = hash,
         numItems = ref 0,
         mask = ref mask}
   end

val initialSize: int = (* Int.pow (2, 6) *) 64

fun new {hash} = newWithBuckets {hash = hash,
                                 numBuckets = initialSize}

fun int_roundUpToPowerOfTwo n =
  let
    fun f m = if m >= n then m
              else f (m * 2)
  in
    f 1
  end

fun newOfSize {hash, size} =
   newWithBuckets {hash = hash,
                   numBuckets = 4 * int_roundUpToPowerOfTwo size}

fun size (T {numItems, ...}) = !numItems

fun index (w: word, mask: word): int =
   Word.toInt (Word.andb (w, mask))

val numPeeks: int ref = ref 0
val numLinks: int ref = ref 0

fun stats () =
   let open Layout
   in align
      [seq [str "numPeeks = ", str (Int.toString (!numPeeks))],
       seq [str "average position in bucket = ",
            str let open Real
                in fmt (StringCvt.FIX (SOME 3)) (fromInt (!numLinks) / fromInt (!numPeeks))

                end]]
   end

fun stats' (T {buckets, numItems, ...}) =
   let open Layout
       val numi = !numItems
       val numb = Array.length (!buckets)
       val numb' = numb - 1
       val avg = let open Real in (fromInt numi / fromInt numb) end
       val (min,max,total)
         = array_fold
           (!buckets,
            (int_maxInt, int_minInt, 0.0),
            fn (l,(min,max,total)) 
             => let
                  val n = List.length l
                  val d = (Real.fromInt n) - avg
                in
                  (Int.min(min,n),
                   Int.max(max,n),
                   total + d * d)
                end)
       val stdd = let open Real in Math.sqrt(total / (fromInt numb')) end
       val rfmt = fn r => Real.fmt (StringCvt.FIX (SOME 3)) r
   in align
      [seq [str "numItems = ", int_layout numi],
       seq [str "numBuckets = ", int_layout numb],
       seq [str "avg = ", str (rfmt avg),
            str " stdd = ", str (rfmt stdd),
            str " min = ", int_layout min, 
            str " max = ", int_layout max]]
   end

fun resize (T {buckets, hash, mask, ...}, size: int, newMask: word): unit =
   let
      val newBuckets = Array.array (size, [])
   in array_foreach (!buckets, fn r =>
                     list_foreach (r, fn a =>
                                   let val j = index (hash a, newMask)
                                   in Array.update
                                      (newBuckets, j,
                                       a :: Array.sub (newBuckets, j))
                                   end))
      ; buckets := newBuckets
      ; mask := newMask
   end

fun maybeGrow (s as T {buckets, mask, numItems, ...}): unit =
   let
      val n = Array.length (!buckets)
   in if !numItems * 4 > n
         then resize (s,
                      n * 2,
                      (* The new mask depends on growFactor being 2. *)
                      Word.orb (0w1, Word.<< (!mask, 0w1)))
      else ()
   end

fun removeAll (T {buckets, numItems, ...}, p) =
   array_modify (!buckets, fn elts =>
                 list_fold (elts, [], fn (a, ac) =>
                            if p a
                               then (int_dec numItems; ac)
                            else a :: ac))

fun remove (T {buckets, mask, numItems, ...}, w, p) =
   let
      val i = index (w, !mask)
      val b = !buckets
      val _ = Array.update (b, i, list_removeFirst (Array.sub (b, i), p))
      val _ = int_dec numItems
   in
      ()
   end

fun peekGen (T {buckets = ref buckets, mask, ...}, w, p, no, yes) =
   let
      val _ = int_inc numPeeks
      val j = index (w, !mask)
      val b = Array.sub (buckets, j)
   in case list_peek (b, fn a => (int_inc numLinks; p a)) of
      NONE => no (j, b)
    | SOME a => yes a
   end

fun peek (t, w, p) = peekGen (t, w, p, fn _ => NONE, SOME)

(* fun update (T {buckets = ref buckets, equals, hash, mask, ...}, a) =
 *    let
 *       val j = index (hash a, !mask)
 *       val _ =
 *       Array.update (buckets, j,
 *                     a :: (List.remove (Array.sub (buckets, j),
 *                                        fn a' => equals (a, a'))))
 *    in ()
 *    end
 *)

fun insertIfNew (table as T {buckets, numItems, ...}, w, p, f, 
                 g: 'a -> unit) =
   let
      fun no (j, b) =
         let val a = f ()
            val _ = int_inc numItems
            val _ = Array.update (!buckets, j, a :: b)
            val _ = maybeGrow table
         in a
         end
      fun yes x = (g x; x)
   in peekGen (table, w, p, no, yes)
   end

fun lookupOrInsert (table, w, p, f) =
   insertIfNew (table, w, p, f, ignore)

fun fold (T {buckets, ...}, b, f) =
   array_fold (!buckets, b, fn (r, b) => list_fold (r, b, f))

(*
local
   structure F = Fold (type 'a t = 'a t
                       type 'a elt = 'a
                       val fold = fold)
   open F
in
   val foreach = foreach
end
*)
   fun foreach (hs, f) = fold (hs, (), (fn (x, _) => f x))

fun forall (T {buckets, ...}, f) =
   array_forall (!buckets, fn r => list_forall (r, f))

fun toList t = fold (t, [], fn (a, l) => a :: l)

fun layout lay t = Layout.list (map lay (toList t))

fun fromList (l, {hash, equals}) =
   let
      val s = new {hash = hash}
      val () =
         list_foreach (l, fn a =>
                       ignore (lookupOrInsert (s, hash a,
                                               fn b => equals (a, b),
                                               fn _ => a)))
   in
      s
   end

end
