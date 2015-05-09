#!/usr/bin/perl

#
# simple context-free grammar expander
#
# $Id: scigen.pl,v 1.16 2005/04/11 15:29:00 strib Exp $
#

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


use IO::File;
use strict;
use scigen;

# main
my $dat = {} ;
my $fh;
my $filename;
my $start = "START";
my $debug = 0;
my $pretty = 1;
my $RE;

use Getopt::Long;

# parse args
my $result = GetOptions ("filename=s" => \$filename,
			 "start=s"    => \$start,
			 "pretty=i"    => \$pretty,
			 "debug=i"    => \$debug );

if ( $filename ) {
    $fh = new IO::File ("<$filename");
    die "cannot open input file: $filename\n" unless $fh;
} else {
    $filename = "STDIN";
    $fh = \*STDIN;
}

foreach my $arg (@ARGV) {
    my ($n,$v) = split /=/, $arg;
    push @{$dat->{$n}}, $v;
}

# run
scigen::read_rules ($fh, $dat, \$RE, $debug);
print scigen::generate ($dat, $start, $RE, $debug, $pretty) . "\n";
