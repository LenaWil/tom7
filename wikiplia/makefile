
default : wikiplia


wikiplia : *.sml wikiplia.cm raw-network.c
	mlton -prefer-abs-paths true -show-def-use wikiplia.basis.du -default-ann 'allowFFI true' wikiplia.cm raw-network.c
	grep -v basis wikiplia.basis.du > wikiplia.du
