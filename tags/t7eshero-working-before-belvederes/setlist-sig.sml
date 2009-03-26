signature SETLIST =
sig

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

    val allsongs : unit -> songinfo list

    val eq : songid * songid -> bool
    val cmp : songid * songid -> order
    val tostring : songid -> string
    val fromstring : string -> songid option

    structure Map : ORD_MAP where type Key.ord_key = songid

end
