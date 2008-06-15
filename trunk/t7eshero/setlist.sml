structure Setlist =
struct

    (* using midi name for now *)
    type songid = string
        
    fun tostring s = s
    fun fromstring s = s

end