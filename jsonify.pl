#!/usr/bin/env perl

use lib '.';
use strict;
use scigen;
use IO::File;
use JSON::XS;

my @files = ( 'functions', 'graphviz', 'scirules', 'svg_figures', 'system_names', 'talkrules');
my $rules = {};
my $re = undef;

foreach my $file (@files) {
  scigen::read_rules ( new IO::File ( '<' . $file . '.in' ), $rules, \$re, 0 );
  open( TEX, '>' .$file . '.json' );
  print TEX JSON::XS::encode_json( $rules );
  close( TEX );
}