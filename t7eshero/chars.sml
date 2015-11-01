
structure Chars =
struct

    (* colors and control codes *)
    val WHITE = "^0"
    val BLUE = "^1"
    val RED = "^2"
    val YELLOW = "^3"
    val GREY = "^4"
    val GRAY = GREY
    val GREEN = "^5"
    val POP = "^<"

    (* these just have to be any non-ascii chars. *)
    val CHECKMARK = implode [chr 128]
    val ESC = implode [chr 129]
    val HEART = implode [chr 130]
    val LCMARK1 = implode [chr 131]
    val LCMARK2 = implode [chr 132]
    val BAR_0 = implode [chr 133]
    val BAR_1 = implode [chr 134]
    val BAR_2 = implode [chr 135]
    val BAR_3 = implode [chr 136]
    val BAR_4 = implode [chr 137]
    val BAR_5 = implode [chr 138]
    val BAR_6 = implode [chr 139]
    val BAR_7 = implode [chr 140]
    val BAR_8 = implode [chr 141]
    val BAR_9 = implode [chr 142]
    val BAR_10 = implode [chr 143]
    val BARSTART = implode [chr 144]
    val LRARROW = implode [chr 145]
    val LLARROW = implode [chr 146]

(*
    val MATCH = implode [chr 147, chr 148]
    val POKEY = implode [chr 149, chr 150]
    val PLUCKY = implode [chr 151, chr 152]
    val SNAKES = implode [chr 153, chr 154]
    val STOIC = implode [chr 155, chr 156]
*)
    val MATCH = "^6ef"
    val POKEY = "^6gh"
    val PLUCKY = "^6ij"
    val SNAKES = "^6kl"
    val STOIC = "^6mn"

    val chars = String.concat
        [CHECKMARK, ESC, HEART, LCMARK1, LCMARK2,
         BAR_0, BAR_1, BAR_2, BAR_3, BAR_4, BAR_5, BAR_6,
         BAR_7, BAR_8, BAR_9, BAR_10, BARSTART, LRARROW, LLARROW]

    fun fancy s =
        String.concat (map (fn c =>
                            implode [#"^", chr (ord #"0" + (Random.random_int() mod 6)), c])
                       (explode s))

end
