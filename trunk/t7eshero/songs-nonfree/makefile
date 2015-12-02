#                             -*- makefile -*-

songs : bbcscore.mid ng1score.mid popcornscore.mid 14cheerscore.mid bionic1score.mid cattlecallscore.mid rexrocketscore.mid

ALL = ../genscore.exe makefile

# add more...
bbcscore.mid : bbc-theme.mid $(ALL)
	../genscore.exe -noxmeasure -history 6 -hammertime 26 $< 0 1 -o $@

ng1score.mid : ng1-1.mid $(ALL)
	../genscore.exe -noxmeasure -history 2 -hammertime 40 $< 0 2 -o $@

popcornscore.mid : popcorn.mid $(ALL)
	../genscore.exe -history 5 -hammertime 40 $< 0 1 3 -o $@

14cheerscore.mid : 14cheer.mid $(ALL)
	../genscore.exe -history 5 -hammertime 56 $< 0 2 -o $@

bionic1score.mid : bionic1.mid $(ALL)
	../genscore.exe -history 5 -hammertime 42 $< 0 3 8 10 -o $@

cattlecallscore.mid : cattlecall.mid $(ALL)
	../genscore.exe -history 5 -hammertime 25 $< 0 1 -o $@

# also need bloody3 (or whatever that great one is) from castlevania!

rexrocketscore.mid : rexrocket.mid $(ALL)
	../genscore.exe -history 5 -hammertime 25 $< 0 1 2 -o $@

