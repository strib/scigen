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

my $tmp_dir = "/tmp";
my $tmp_pre = "/$tmp_dir/scimaketalkfig.$$";
my $svg_file = "$tmp_pre.svg";
my $eps_file = "$tmp_pre.eps";
my $ps_file = "$tmp_pre.ps";
my $png_file = "$tmp_pre.png";

my %types = qw( network NETWORK_DIAGRAM
		anything ANYTHING_DIAGRAM
	     );

my $sysname;
my $filename;
my $seed;

sub usage {
    select(STDERR);
    print <<EOUsage;
    
$0 [options]
  Options:

    --help                    Display this help message
    --seed <seed>             Seed the prng with this
    --file <file>             Save the postscript in this file
    --sysname <file>          What is the system called?
    --type <type>             What type of figure?

EOUsage

    exit(1);

}

# Get the user-defined parameters.
# First parse options
my %options;
&GetOptions( \%options, "help|?", "seed=s", "file=s", "sysname=s", "type=s" )
    or &usage;

if( $options{"help"} ) {
    &usage();
}
if( defined $options{"file"} ) {
    $filename = $options{"file"};
}
if( defined $options{"sysname"} ) {
    $sysname = $options{"sysname"};
}
if( defined $options{"seed"} ) {
    $seed = $options{"seed"};
} else {
    $seed = int rand 0xffffffff;
}
srand($seed);

if( defined $filename ) {
    $eps_file = $filename;
}

my $dat = {};
my $RE = undef;

my $fh = new IO::File( "<svg_figures.in" );
scigen::read_rules( $fh, $dat, \$RE, 0 );

my $type = "network";
if( defined $options{"type"} ) {
    $type = $options{"type"};
}
my @a;
if( !defined $types{$type} ) {
    die( "Bad type: $type" );
} else {
    @a = ($types{$type});
    $dat->{"FIGURE_TYPE"} = \@a;
}

my @b;
my @c;
my @d;
# special network processing
if( $type eq "network" ) {

    my $num_nodes = scigen::generate( $dat, "NETWORK_NUM_COMPS", $RE, 0, 0 );
    @b = ("COMPUTERS_$num_nodes");
    $dat->{"COMPUTERS"} = \@b;

    # some number of edges (n/2 - 2n-1)
    my $num_edges = int rand($num_nodes/2);
    $num_edges += int ($num_nodes*3/2)-1;
    if( $num_edges > 16 ) {
	$num_edges = 16;
    } elsif( $num_edges == 0 ) {
	$num_edges = 1;
    }

    @c = ("LINE_P2P_$num_edges");
    $dat->{"LINES"} = \@c;

    # some number of partners
    my $num_partners = int rand($num_nodes);
    if( $num_partners == 0 ) {
	$num_partners = 1;
    }

    @d = ("COMPUTER_PARTNER_$num_partners");
    $dat->{"COMPUTER_PARTNERS"} = \@d;

}


scigen::compute_re( $dat, \$RE );
my $svg = scigen::generate( $dat, "SVG_FIG", $RE, 0, 0 );

# file needs pwd I guess
$svg =~ s/href=\"(.*)\"/href=\"$ENV{'PWD'}\/$1\"/gi;


# We want to draw line, etc, from objects that have already been placed
my @lines = split( /\n/, $svg );
my @positions = ();
my $svg_out = "";
foreach my $line (@lines) {
    if( $line =~ /x=\"(\d+)\" y=\"(\d+)\" width=\"(\d+)px\" height=\"(\d+)px\"/ ) {
	my $x = $1+int($3/2);
	my $y = $2+int($4/2);
	push @positions, "$x $y";
    } elsif( $line =~ /OLDPOINT(\d*)/ ) {
	while( $line =~ /OLDPOINT(\d*)/ ) {
	    my $num = $1;
	    if( !defined $num ) {
		$num = "";
	    }
	    my $point = $positions[int rand @positions];
	    my @xy = split( /\s+/, $point );
	    my $newpoint = "x$num=\"$xy[0]\" y$num=\"$xy[1]\"";
	    $line =~ s/OLDPOINT\d*/$newpoint/;
	}
    }

    $svg_out .= $line . "\n";
}

open( SVG, ">$svg_file" ) or die( "Can't open $svg_file for writing" );
print SVG $svg_out;
close( SVG );

system( "inkscape -z --export-png=$png_file -b white -D $svg_file; " .
	"convert $png_file $eps_file" ) and
    die( "Can't run inkscape or convert on $svg_file" );

if( !defined $filename ) {
    system( "gv $eps_file" ) and
	die( "Can't run gv on $eps_file" );
} else {
    system( "cp $eps_file $filename" );
}

system( "rm -f $tmp_pre*" ) and die( "Couldn't rm" );
