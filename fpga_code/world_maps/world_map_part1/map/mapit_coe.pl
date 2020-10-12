#!/apps/Perl/bin/perl
#
# mapit_c0e.pl - makes rojobot map file into a file that can be used to initialize
# a ROM created with the Xilinx Core Generator
#
############################

print STDERR "Rojobot map file conversion (Xilinx COE)\n\n";
my $addr = 0;

while ($line = <STDIN>) {
	last if $line =~ /^\-*/;
}
$line = <STDIN>;
printf STDOUT "MEMORY_INITIALIZATION_RADIX=16;\n";
printf STDOUT "MEMORY_INITIALIZATION_VECTOR=\n";


while ($line = <STDIN>)  {
	chomp $line;
	($row, $col) = split /\|/, $line;
	foreach $i (split(//, $col)) {
		if (($addr % 32) == 0){
			printf STDOUT "\n";
		}
		print STDOUT "$i,";
		$addr++;
	}
}
			