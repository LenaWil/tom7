
# probably don't want keephistory on when running for real
retract : retract-*.sml retract.sml retract.cm makefile fixedword5x6.sml fixedword5x8.sml
	nice -n 15 mlton @MLton max-heap 150m -- retract.cm
	mv retract retract.exe

# exnhistory, sort, dumbretract: 1m15.327s   sys .530
# sort, dumbretract: 1m13.140s    sys .406
# unsafe, sort, dumbretract: 1m10.171s    sys 0.390
# unsafe, sort, dumbretract: 1m9.265s    sys 0.374
# word9, unsafe, sort, dumbretract: 1m10.249  sys 0.311s
# word8, unsafe, sort, dumbretract, rescan: 2m12.562   sys 0.406

# rewrite, dijkstra's, dumbretract: 0m6.452   sys 0.171

fixedword6x2.sml : makefixedword
	./makefixedword 6 2 > fixedword6x2.sml

fixedword6x6.sml : makefixedword
	./makefixedword 6 6 > fixedword6x6.sml

fixedword5x6.sml : makefixedword
	./makefixedword 5 6 > fixedword5x6.sml

fixedword5x10.sml : makefixedword
	./makefixedword 5 10 > fixedword5x10.sml

fixedword5x8.sml : makefixedword
	./makefixedword 5 8 > fixedword5x8.sml

makefixedword : makefixedword.sml fixedwordvec-sig.sml makefixedword-main.sml makefixedword.cm
	mlton @MLton max-heap 150m -- makefixedword.cm
