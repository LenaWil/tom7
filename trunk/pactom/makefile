
# default : programs outputs thumbnails
# default : kmlcat
# default : shortest.kml shortest.svg
default : map map.svg
# default : llt.svg

all : programs outputs thumbnails pdfs obsolete release

PACTOMLIB=pactom.sml pactom-sig.sml ../sml-lib/files/xml/xml*.sml ../sml-lib/misc/color*.sml ../sml-lib/geom/latlon*.sml ../sml-lib/geom/snappoint*.sml ../sml-lib/geom/latlontree*.sml ../sml-lib/geom/quadtree*.sml ../sml-lib/geom/pointlocation*.sml ../sml-lib/data/undirected-graph*.sml ../sml-lib/util/growarray*.sml ../sml-lib/algo/heap*.sml

# has trouble on new cygwin, because it's a bash builtin?
TIME=

# Generating programs.
programs : shortestpaths colorize map elevsvg makepoints radial lltsvg kmlcat

kmlcat : kmlcat.sml kmlcat.cm ../sml-lib/util/*.sml
	mlton kmlcat.cm

shortestpaths : shortestpaths.sml shortestpaths.cm ${PACTOMLIB} 
	mlton shortestpaths.cm

colorize : colorize.sml colorize.cm ${PACTOMLIB}
	mlton colorize.cm

map : map.sml map.cm ${PACTOMLIB}
	mlton map.cm

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

map.svg : map pac.kml pacannotations.kml pac2.kml neighborhoods.kml interstate-logo.svg
	${TIME} ./map > $@

radial.svg : radial pac.kml pac2.kml
	${TIME} ./radial > $@

points.kml : makepoints neighborhoods.kml
	${TIME} ./makepoints > $@

# This is getting near the maximum memory for 32 bit machines! Probably can do some
# kind of pre-thinning of the points, or maybe a more efficient kd-tree representation,
# or merge at load time?
shortest.kml shortest.svg : shortestpaths pac.kml pac2.kml
	${TIME} ./shortestpaths @MLton max-heap 999m -- -kmlout shortest.kml -svgout shortest.svg

llt.svg : lltsvg pac.kml pac2.kml
	${TIME} ./lltsvg > $@


# MAKETHUMB=convert -scale 400
# MAKETHUMB="/c/program files/inkscape/inkscape"
MAKETHUMB=rsvg/rsvg-convert --keep-aspect-ratio --width=580
MAKEPDF=rsvg/rsvg-convert -f pdf

# XXX Text rendering is not that good this way. Might want to render at a much
# larger size then downsample with imagemagick?

# Convert SVGs to thumbnails for webpage
thumbnails : map.png shortest.png
pdfs : map.pdf shortest.pdf

map.png : map.svg
	${MAKETHUMB} $< -o $@

shortest.png : shortest.svg
	${MAKETHUMB} $< -o $@

radial.png : radial.svg
	${MAKETHUMB} $< -o $@

%.pdf : %.svg
	${MAKEPDF} $< -o $@

# Obsolete
obsolete : parsexml

parsexml : parsexml.cm parsexml.sml ${PACTOMLIB}
	mlton parsexml.cm

# For release, we expect the following files in the current directory:
#   pac.kml
#   pac2.kml

RELEASEFILES=release/pactom.kmz release/shortest.svg release/map.svg release/map.png release/shortest.png release/shortest.pdf release/map.pdf release/radial.svg release/radial.pdf release/radial.png
release : ${RELEASEFILES} $(addsuffix .size, ${RELEASEFILES})
	date +"%d %b %Y at %H:%M" | tr -d '\012' > release/updated
upload : release
	pscp -r release root@spacebar.org:/var/www/pac/

release/%.png : %.png
	cp $< $@

release/%.svg : %.svg
	cp $< $@

release/%.pdf : %.pdf
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

# clean final generated files too, including the whole release dir
veryclean : clean
	rm -rf release
	mkdir release
	rm -f shortest.kml shortest.svg map.svg shortest.pdf map.pdf radial.svg points.kml radial.pdf kmlcat map shortestpaths colorize elevsvg makepoints radial lltsvg
