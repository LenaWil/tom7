signature SETLIST =
sig

    exception Setlist of string

    type songid
    type songinfo =
        { file : string,
          slowfactor : int,
          hard : int,
          fave : int,
          title : string,
          artist : string,
          year : string,
          id : songid }

    datatype interlude =
        SwitchToGuitar
      | SwitchToDrums
      | GetWomb
    (* WARP ZONE *)

    datatype background =
        BG_SOLID of SDL.color

    datatype showpart =
        Song of { song : songid,
                  misses : bool,
                  drumbank : int Vector.vector option,
                  background : background
                  (* ... ? *)
                  }
      | Postmortem
      | Interlude of interlude

    type showinfo =
        { name : string,
          date : string,
          parts : showpart list }

    val allsongs : unit -> songinfo list
    val allshows : unit -> showinfo list

    val eq : songid * songid -> bool
    val cmp : songid * songid -> order
    val tostring : songid -> string
    val fromstring : string -> songid option

    val getsong : songid -> songinfo

    structure Map : ORD_MAP where type Key.ord_key = songid

end
