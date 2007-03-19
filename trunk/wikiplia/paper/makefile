
default : wikiplia.dvi

wikiplia.dvi : wikiplia.tex wikiplia.bib ss_homepage.eps
	latex wikiplia
	-bibtex wikiplia
	latex wikiplia
	latex wikiplia

ss_homepage.eps : ss_homepage.png
	bmeps ss_homepage.png > ss_homepage.eps
