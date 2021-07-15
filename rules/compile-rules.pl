#!/usr/bin/env perl

use lib '../scigen-perl';
use strict;
use scigen;
use IO::File;
use JSON::XS;

my $rules_original_dir = 'rules-original/';
my $rules_compiled_dir = 'rules-compiled/';
my @files = ( 'functions', 'graphviz', 'scirules', 'svg_figures', 'system_names', 'talkrules');
my $rules = {};
my $re = undef;

foreach my $file (@files) {
  scigen::read_rules ( new IO::File ( '<' . $rules_original_dir . $file . '.in' ), $rules, \$re, 0 );
  open( TEX, '>' . $rules_compiled_dir . $file . '.json' );
  print TEX JSON::XS::encode_json( $rules );
  close( TEX );
}