#!/usr/bin/perl -w

#    This file is part of SCIgen.
#
#    SCIgen is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    SCIgen is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SCIgen; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


use strict;
use scigen;
use Getopt::Long;

my $filename;
my $seed;
my $color = "";

sub usage {
    select(STDERR);
    print <<EOUsage;
    
$0 [options]
  Options:

    --help                    Display this help message
    --seed <seed>             Seed the prng with this
    --file <file>             Save the postscript in this file
    --color                   Draw in color?

EOUsage

    exit(1);

}

# Get the user-defined parameters.
# First parse options
my %options;
&GetOptions( \%options, "help|?", "seed=s", "file=s", "color" )
    or &usage;

if( $options{"help"} ) {
    &usage();
}
if( $options{"color"} ) {
    $color = "color";
}
if( defined $options{"file"} ) {
    $filename = $options{"file"};
}
if( defined $options{"seed"} ) {
    $seed = $options{"seed"};
} else {
    $seed = int rand 0xffffffff;
}
srand($seed);

# noise margin
my $MARGIN = .1;

my $XMAX;
my $XMIN;
do {
    $XMAX = int rand 100 + 10;
    $XMIN = $XMAX - int rand 2*$XMAX;
} while( $XMAX == $XMIN );

my $NUM_POINTS_SCATTER = (int rand 1000) + 100;
my $NUM_POINTS_CURVE = (int rand 100) + 10;
my $NUM_BARS = (int rand 20) + 10;

sub add_noise {

    my $x = shift;
    my $n = rand abs($x*($MARGIN*2));

    return $x + ($n-$MARGIN);

}

my $fh = new IO::File ("<scirules.in");
my $dat = {};
my $RE = undef;
scigen::read_rules ($fh, $dat, \$RE, 0);

my $graph = scigen::generate ($dat, "GNUPLOT", $RE, 0, 0);
#`perl scigen.pl -f scirules.in -s GNUPLOT -p 0`;
#print "# [$$] func = $func\n";

my @graph_lines = split( /\n/, $graph );

my $type;
my $curves;
my $error = 0;

my $tmp_dir = "/tmp/scigengraph.";
my $gpfile = "$tmp_dir$$.gnuplot";
my $epsfile = "$tmp_dir$$.eps";
if( defined $filename ) {
    $epsfile = $filename;
}
my $datafile = "$tmp_dir$$.dat";
my @labels = ();
my $num_points = 10;

open( GPFILE, ">$gpfile" ) or die( "Couldn't write to $gpfile" );

print GPFILE "set terminal postscript eps $color 26\n";
print GPFILE "set output \"$epsfile\"\n";

foreach my $line (@graph_lines) {

    if( $line =~ /graphtype (.*)=(.*)/ ) {
	$type = $1;
	$curves = $2;
	if( $type eq "scatter" ) {
	    $num_points = $NUM_POINTS_SCATTER;
	} else {
	    $num_points = $NUM_POINTS_CURVE;
	}
    } elsif( $line =~ /curvelabel (.*)/ ) {
	push @labels, $1;
    } elsif( $line =~ /errorbars/ ) {
	$error = 1;
    } else {
	print GPFILE "$line\n";
    }

}

my @x = ();
if( $type eq "bargraph" ) {

    for( my $x = $XMIN; $x <= $XMAX; $x += ($XMAX-$XMIN)/$NUM_BARS ) {
	push @x, $x;
    }

} else {
    for( my $j = 0; $j < $num_points; $j++ ) {
	
	my $x = (rand ($XMAX-$XMIN))+$XMIN;
	push @x, $x;
	
    }
}


@x = sort { $a <=> $b } @x;
my @y = ();

my $funcfh = new IO::File ("<functions.in");
my $funcdat = {};
my $funcRE = undef;
scigen::read_rules ($funcfh, $funcdat, \$funcRE, 0);

print GPFILE "plot ";
for( my $i = 0; $i < $curves; $i++ ) {
    my $label = $labels[$i];
    print GPFILE "\'$datafile.$i\' $label with ";
    if( $type eq "scatter" ) {
	print GPFILE "points";
    } elsif( $type eq "curve" ) {
	print GPFILE "linespoints";
	if( $error ) {
	    print GPFILE ",\'$datafile.$i\' notitle with errorbars";
	}
    } elsif( $type eq "cdf" ) {
	print GPFILE "lines";
    } else {
	print GPFILE "boxes";
    }

    if( $i != $curves -1 ) {
	print GPFILE ", ";
    } else {
	print GPFILE "\n";
    }

    my $num_points = 0;
    do {
	@y = ();
	my $func = scigen::generate ($funcdat, "EXPR", $funcRE, 0, 0);
	#my $func = `perl scigen.pl -f functions.in -s EXPR -p 0`;
	
	open( DAT, ">$datafile.$i" ) or 
	    clean() and die( "Couldn't write to $datafile.$i" );
	
	foreach my $x (@x) {
	    
	    my $expr = $func . " ";
	    $expr =~ s/xxx/$x/g;
	    #print "expr = $expr\n";
	    my $y = eval( $expr );
	    if( !defined $y or $y eq "NaN" ) {
		next;
	    }
	    
	    my $yn = &add_noise($y);
	    if( $type eq "curve" and $error ) {
		my $ymin = $yn - (rand)*abs($yn);
		my $ymax = $yn + (rand)*abs($yn);
		$yn = "$yn $ymin $ymax";
	    }

	    if( $type ne "cdf" ) {
		print DAT "$x $yn\n";
	    } else {
		if( $#y == -1 ) {
		    push @y, abs($yn);
		} else {
		    push @y, abs($yn)+$y[$#y];
		}
	    }
	    $num_points++;
	}
	
    } while($num_points == 0);

    if( $type eq "cdf" ) {
	my $k = 0;
	foreach my $y (@y) {
	    my $ynormal = $y/$y[$#y];
	    print DAT "$x[$k] $ynormal\n";
	    $k++;
	}
    }

    close( DAT );

}

close( GPFILE );

system( "gnuplot $gpfile" ) and clean() and die( "Couldn't gnuplot $gpfile" );
if( !defined $filename ) {
    system( "gv $epsfile" ) and clean() 
	and die( "Couldn't gv $epsfile" ) and clean();
}
clean();

sub clean {
    system( "rm $tmp_dir$$*" ) and die( "Couldn't rm anything" );
}
