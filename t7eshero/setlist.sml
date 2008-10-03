structure Setlist =
struct

    (* using midi name for now *)
    type songid = string
        
    fun tostring s = s
    fun fromstring s = s

    val SONGS_FILE = "songs.hero"
    val SONGS_NONFREE = "songs-nonfree.hero"

end