
signature ALGORITHM =
sig

    (* Take a single RSS item and summarize it. *)
    val algorithm : 
        { guid : string,
          link : string option,
          title : string,
          description : string,
          date : Date.date,
          body : XML.tree list } ->
        { url : string,
          title : string } option

end