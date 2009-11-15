
# default : programs outputs thumbnails
# default : kmlcat
default : shortest.kml shortest.svg
# default : tosvg map.svg
# default : llt.svg

all : programs outputs thumbnails obsolete release

PACTOMLIB=pactom.sml pactom-sig.sml ../sml-lib/files/xml/xml*.sml ../sml-lib/misc/color*.sml ../sml-lib/misc/latlon*.sml ../sml-lib/geom/latlontree*.sml ../sml-lib/geom/quadtree*.sml ../sml-lib/geom/pointlocation*.sml ../sml-lib/data/undirected-graph*.sml ../sml-lib/util/growarray*.sml ../sml-lib/algo/heap*.sml

TIME=

# Generating programs.
programs : shortestpaths colorize tosvg elevsvg makepoints radial lltsvg kmlcat

kmlcat : kmlcat.sml kmlcat.cm ../sml-lib/util/*.sml
	mlton kmlcat.cm

shortestpaths : shortestpaths.sml shortestpaths.cm ${PACTOMLIB} 
	mlton shortestpaths.cm

colorize : colorize.sml colorize.cm ${PACTOMLIB}
	mlton colorize.cm

tosvg : tosvg.sml tosvg.cm ${PACTOMLIB}
	mlton tosvg.cm

# XXX need output for this
elevsvg : elevsvg.sml elevsvg.cm ${PACTOMLIB}
	mlton elevsvg.cm

makepoints : makepoints.sml makepoints.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton makepoints.cm

radial : radial.sml radial.cm ${PACTOMLIB} ../sml-lib/geom/*.sml
	mlton radial.cm

lltsvg : lltsvg.sml lltsvg.cm ${PACTOMLIB}
	mlton lltsvg.cm

# outputs
# XXX these should explicitly depend on inputs, like pac.kml

outputs : radial.svg points.kml llt.svg map.svg

map.svg : tosvg pac.kml pacannotations.kml pac2.kml
	${TIME} ./tosvg > $@

radial.svg : radial
	${TIME} ./radial > $@

points.kml : makepoints neighborhoods.kml
	${TIME} ./makepoints > $@

shortest.kml shortest.svg : shortestpaths pac.kml pac2.kml
	${TIME} ./shortestpaths -kmlout shortest.kml -svgout shortest.svg

llt.svg : lltsvg pac.kml pac2.kml
	${TIME} ./lltsvg > $@


# MAKETHUMB=convert -scale 400
# MAKETHUMB="/c/program files/inkscape/inkscape"
MAKETHUMB=rsvg/rsvg-convert --keep-aspect-ratio --width=400

# Convert SVGs to thumbnails for webpage
thumbnails : map.png shortest.png

map.png : map.svg
	${MAKETHUMB} $< -o $@

shortest.png : shortest.svg
	${MAKETHUMB} $< -o $@

# Obsolete
obsolete : parsexml

parsexml : parsexml.cm parsexml.sml ${PACTOMLIB}
	mlton parsexml.cm

# For release, we expect the following files in the current directory:
#   pac.kml
#   pac2.kml

RELEASEFILES=release/pactom.kmz release/shortest.svg release/map.svg
release : ${RELEASEFILES} $(addsuffix .size, ${RELEASEFILES})
upload : release
	pscp -r release root@spacebar.org:/var/www/pac/

release/%.svg : %.svg
	cp $< $@

# XXX also annotations, neighborhood, etc.
release/pactom.kmz : pac.kml pac2.kml kmlcat
	rm -f _pactom.kml
	./kmlcat pac.kml pac2.kml > _pactom.kml
	rm -f release/pactom.kmz
	zip release/pactom.kmz _pactom.kml

# Produces a human-readable size (i.e. "2.7M") and strips newlines.
# These are used on the web page to report the size of downloadable
# files.
release/%.size : release/%
	du --si $^ | cut -f 1 | tr -d '\012' > $@

clean :
	rm -f _pactom.kml release/pactom.kmz release/*.size *~

# clean final generated files too
veryclean : clean
	rm -f shortest.kml shortest.svg map.svg
