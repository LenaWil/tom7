
structure Items :> ITEMS =
struct

    exception Items of string
    val ITEMS_FILE = "items/items.hero"

    type class = string

    type item = { id : string,
                  name : string,
                  class : class,
                  frames : (SDL.surface * int * int) Vector.vector,
                  zindex : int }

    (* all of the available items *)
    val items : item list ref = ref nil
    fun eq ({ id = id1, ...} : item, { id = id2, ... } : item) = id1 = id2
    fun byz ({ zindex = zindex1, ...} : item, { zindex = zindex2, ... } : item) = Int.compare (zindex1, zindex2)

    (* negative zindex, positive zindex. sorted by zindex. *)
    type worn = item list * item list

    fun award (l : item list) = List.find (fn { id, ... } => not (List.exists (fn { id = id', ... } : item => id = id') l)) (!items)

    fun app_behind (s, _) f = List.app f s
    fun app_infront (_, s) f = List.app f s

    val name : item -> string = #name
    val frames : item -> (SDL.surface * int * int) Vector.vector = #frames
    val id : item -> string = #id
    val zindex : item -> int = #zindex

    fun has (a, b) i =
        List.exists (fn x => eq (x, i)) a orelse
        List.exists (fn x => eq (x, i)) b

    fun remove (a, b) i =
        (List.filter (fn x => not (eq(x, i))) a,
         List.filter (fn x => not (eq(x, i))) b)

    fun removeclass (a, b) c =
        (List.filter (fn {class, ...} : item => class <> c) a,
         List.filter (fn {class, ...} : item => class <> c) b)

    (* Need to maintain no duplicates, no class mismatches, sorted order *)
    fun add (a, b) (i as { zindex, class, ... }) =
        (* this removes the item itself, too *)
        let val (a, b) = removeclass (a, b) class
        in
            if zindex < 0
            then (ListUtil.Sorted.insert byz a i, b)
            else (a, ListUtil.Sorted.insert byz b i)
        end

    val trim = StringUtil.losespecl StringUtil.whitespec o StringUtil.losespecr StringUtil.whitespec
    exception NotFound
    fun req f =
        case (SDL.loadimage ("items/" ^ trim f)) handle _ => NONE of
            NONE => (Hero.messagebox ("couldn't open item graphic " ^ f ^ "\n");
                     raise NotFound)
          | SOME p => p

    fun load () =
        let
            val lines = StringUtil.readfile ITEMS_FILE
            val lines = String.tokens (fn #"\n" => true | _ => false) lines
            val lines = List.mapPartial
                (fn s =>
                 case String.fields (fn #"|" => true | _ => false) s of
                     [id, class, name, f1, x1, y1, f2, x2, y2, f3, x3, y3, f4, x4, y4, z] =>
                         ((case map (valOf o Int.fromString) [x1, y1, x2, y2, x3, y3, x4, y4, z] of
                               [x1, y1, x2, y2, x3, y3, x4, y4, z] =>
                                   SOME { id = trim id, class = trim class, name = trim name,
                                          frames = Vector.fromList([(req f1, x1, y1),
                                                                    (req f2, x2, y2),
                                                                    (req f3, x3, y3),
                                                                    (req f4, x4, y4)]),
                                          zindex = z }
                             | _ => raise Items "impossible") handle Option => (Hero.messagebox "bad int"; NONE)
                                                                 | Overflow => (Hero.messagebox "big int"; NONE)
                                                                 | NotFound => (Hero.messagebox "graphic"; NONE))
                   | _ => (print ("Bad line: " ^ s ^ "\n"); NONE)) lines
        in
            app (fn {id, ...} => print (id ^ "\n")) lines;
            items := lines
        end

    fun fromid id' =
        case List.find (fn { id, ... } => id = id') (!items) of
            NONE => raise Items ("item '" ^ id' ^ "' not found")
          | SOME i => i

    fun wtostring (wa, wb) = StringUtil.delimit "," (map id wa @ map id wb)
    fun wfromstring s =
        let val l = String.tokens (fn #"," => true | _ => false) s
        in foldr (fn (i, w) => add w (fromid i)) (nil, nil) l
        end

    (* XXX these should probably be in config files? *)
    val default_closet_items = ["RedGuitar"]
    fun default_closet () =
        let
            val l = List.filter (fn { id, ... } => List.exists (fn id' => id = id') default_closet_items) (!items)
        in
            if length l <> length default_closet_items
            then Hero.messagebox "Can't find at least one default closet item!"
            else ();
            l
        end

    fun default_outfit () = (nil, default_closet ())

end
