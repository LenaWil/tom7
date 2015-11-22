
(* Accumulates statistics for Postmortem and on-line display.

   Sorta hacky. *)
structure Stats (* XXX :> STATS *) =
struct

    exception Stats of string

    type final =
        (* XXX don't need all three of these lists... *)
        { allmedals : Hero.medal list,
          oldmedals : Hero.medal list,
          medals : Hero.medal list,
          percent : real,
          hit : int,
          total : int,
          danced : real,
          dancerate : real,
          upstrums : int,
          downstrums : int,
          totalseconds : real,
          award : Items.item option }

    type entry = { song : Setlist.songid,
                   missnum : int ref,
                   start_time : Word32.word,
                   final : final option ref }

    val stack = ref nil : entry list ref

    fun head () =
        case !stack of
            nil => raise Stats "asked for stats without starting"
          | h :: _ => h

    fun prev () : entry option =
        case !stack of
            _ :: pr :: _ => SOME pr
          | _ => NONE

    fun miss () = #missnum (head()) := !(#missnum(head())) + 1
    fun misses () = !(#missnum (head()))

    (* Delete all stats. *)
    fun clear () = stack := nil

    (* create *)
    fun push (s : Setlist.songid) =
        stack := { song = s, missnum = ref 0,
                   start_time = SDL.getticks(),
                   final = ref NONE } :: !stack

    (* when finished playing a song, call this with tracks
       to record final statistics. Always saves to the profile. *)
    fun finish tracks profile =
        let
            val songid = #song (head ())

            val { misses, percent = (hit, total), ... } = Match.stats tracks
            val () = print ("At end: " ^ Int.toString misses ^ " misses\n");

            val percent = (real hit * 100.0 / real total)
            val () = if total > 0
                     then print ("At end: " ^ Int.toString hit ^ "/" ^ Int.toString total ^
                                 " (" ^ Real.fmt (StringCvt.FIX (SOME 1)) percent ^
                                 "%) of notes hit\n")
                     else ()
            val { totaldist, totaltime, upstrums, downstrums } = State.stats ()

            val dancerate = totaldist / totaltime


            val () = print ("Danced: " ^ Real.fmt (StringCvt.FIX (SOME 2)) totaldist ^ "m (" ^
                            Real.fmt (StringCvt.FIX (SOME 3)) dancerate
                            ^ "m/s)\n")

            (* Need 90% to qualify for medals. *)
            val medals =
                if percent >= 90.0
                then
                    List.filter
                    (fn Hero.PerfectMatch => hit = total
                      | Hero.Snakes => dancerate >= 0.25
                      | Hero.Stoic => dancerate < 0.02
                      | Hero.Plucky => downstrums = 0
                      | Hero.Pokey => upstrums = 0
                      | Hero.AuthenticStrummer => false (* XXX *)
                      | Hero.AuthenticHammer => false)
                    [Hero.PerfectMatch, Hero.Snakes, Hero.Stoic, Hero.Plucky, Hero.Pokey,
                     Hero.AuthenticStrummer, Hero.AuthenticHammer]
                else nil

            (* get old records for this song, if any. Then decide if we made new records. *)
            val { percent = oldpercent, misses = oldmisses, medals = oldmedals } =
                case List.find (fn (sid, _) => Setlist.eq(sid, songid)) (Profile.records profile) of
                    NONE => { percent = 0, misses = total + 1, medals = nil }
                  | SOME (_, r) => r

            (* old and new, avoiding duplicates *)
            val allmedals = List.filter (fn m' => not (List.exists (fn m => m = m') oldmedals)) medals @ oldmedals

            (* save profile right away *)
            (* Prevent from crashing if there were no notes -- XXX hax *)
            val total = if total = 0 then 1 else total
            val () = Profile.setrecords profile ((songid, { percent = Int.max(oldpercent,
                                                                              (hit * 100) div total),
                                                            misses = Int.min(oldmisses, misses),
                                                            medals = allmedals }) ::
                                                 List.filter (fn (sid, _) => not (Setlist.eq(songid, sid)))
                                                 (Profile.records profile))
            val () = Profile.save()

            val start_time = #start_time (head ())
            val total_time = Real.fromInt (Word32.toInt (SDL.getticks() - start_time)) / 1000.0

            (* got a new medal? then get clothes. *)
            val award = if List.exists (fn m => not (List.exists (fn m' => m = m') oldmedals)) medals
                        then (case Items.award (Profile.closet profile) of
                                  NONE => NONE
                                | SOME i =>
                                      let in
                                          Profile.setcloset profile (i :: Profile.closet profile);
                                          Profile.save();
                                          SOME i
                                      end)
                        else NONE

        in
            #final (head()) := SOME
            { allmedals = allmedals,
              oldmedals = oldmedals,
              medals = medals,
              percent = percent,
              hit = hit,
              total = total,
              danced = totaldist,
              dancerate = dancerate,
              upstrums = upstrums,
              downstrums = downstrums,
              totalseconds = total_time,
              award = award }
        end

    fun has () = not (List.null (!stack))

end
