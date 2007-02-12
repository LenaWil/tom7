
(* XXX this needs to support serialization to disk. *)
structure DB =
struct

  exception NotFound
  type int = IntInf.int

  structure SM = SplayMapFn(type ord_key = string
                            val compare = String.compare)

  structure IM = SplayMapFn(type ord_key = IntInf.int
                            val compare = IntInf.compare)

  type revision = IntInf.int
  val FIRST_REVISION : revision = 0

  (* each key has a number of revisions, and a current revision *)
  type db = (Bytes.exp IM.map * int) SM.map ref

  (* start empty -- XXX should read from disk *)
  val db = ref SM.empty : db

  fun insert key data =
    (case SM.find (!db, key) of
       NONE =>
         (* new. *)
         let in
           db := SM.insert(!db, key, (IM.insert(IM.empty, FIRST_REVISION, data),
                                      FIRST_REVISION));
           FIRST_REVISION
         end
     | SOME (im, newest) =>
         let in
           db := SM.insert(!db, key, (IM.insert(IM.empty, newest + 1, data),
                                      newest + 1));
           newest + 1
         end)

  fun head key =
    (case SM.find (!db, key) of
       NONE => raise NotFound
     | SOME (im, newest) => 
         (case IM.find(im, newest) of
            NONE => raise NotFound (* ?!? *)
          | SOME d => d))

  fun read key rev =
    (case SM.find (!db, key) of
       NONE => raise NotFound
     | SOME (im, _) =>
         (case IM.find(im, rev) of
            NONE => raise NotFound
          | SOME d => d))

end
