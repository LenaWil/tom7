AAPH = aaph

default : genbest.aph register.aph upload.aph rate.aph fixup.aph admin.aph adminone.aph newcol.aph modone.aph modsubdir.aph addsubdir.aph rmsubdir.aph copyone.aph delete.aph ping.aph comment.aph comments.aph recent.aph domodsubdir.aph level.aph recentrss.aph verify.aph delcomment.aph upsol.aph allsols.aph adminsols.aph showspeedruns.aph makescreenshots.aph delsol.aph deletefromgame.aph autothin.aph users.aph domodcomment.aph ratings.aph setspoiler.aph generatesummary.aph summaryrss.aph viewsummary.aph

%.aph : %.aa escape.aah escape.db
	${AAPH} -I ../ $< -o $@