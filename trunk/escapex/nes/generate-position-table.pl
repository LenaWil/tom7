$a = 0x2100; for $i (0..9) { for $j (0..17) { $r = $a + ($i * 64) + ($j * 2); if ($j > 15) {$r += 0x400; $r -= 0x20} push @low, ($r & 0xFF); push @high, ($r & 0xFF00) >> 8;}} $c = 0; foreach (@low) {printf "\$%.2X,", $_; $c++; print "\\\n" if ($c % 16 == 0)} print "\n\n"; $c = 0; foreach (@high) {printf "\$%.2X,", $_; $c++; print "\\\n" if ($c % 16 == 0);} print "\n\n";
