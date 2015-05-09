package scigen;

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
use IO::File;
use Data::Dumper;
use Autoformat;
use vars qw($SCIGEND_PORT);

#### daemon settings ####
$SCIGEND_PORT = 4724;

sub dup_name {
    my $name = shift;
    return $name . "!!!";
}

sub file_name {
    my $name = shift;
    return $name . ".file";
}

sub read_rules {
    my ($fh, $rules, $RE, $debug) = @_;
    my $line;
    while ($line = <$fh>) {
	next if $line =~ /^#/ ;
	next if $line !~ /\S/ ;

	my @words = split /\s+/, $line;
	my $name = shift @words;
	my $rule = "";

	# non-duplicate rule
	if( $name =~ /([^\+]*)\!$/ ) {
	    $name = $1;
	    push @{$rules->{dup_name("$name")}}, "";
	    next;
	}

	# include rule
	if( $name =~ /\.include$/ ) {
	    my $file = $words[0];
	    # make sure we haven't already included this file
	    # NOTE: this allows the main file to be included at most twice
	    if( defined $rules->{&file_name($file)} ) {
		if( $debug > 0 ) {
		    print "Skipping duplicate included file $file\n";
		}
		next;
	    } else {
		$rules->{&file_name($file)} = 1;
	    }
	    if( $debug > 0 ) {
		print "Opening included file $file\n";
	    }
	    my $inc_fh = new IO::File ("<$file");
	    if( !defined $inc_fh ) {
		die( "Couldn't open included file $file" );
	    }
	    &read_rules( $inc_fh, $rules, undef, $debug );
	    next; # we don't want to have .include itself be a rule
	}

	if ($#words == 0 && $words[0] eq '{') {
	    my $end = 0;
	    while ($line = <$fh>) {
		if ($line =~ /^}[\r\n]+$/) {
		    $end = 1;
		    last;
		} else {
		    $rule .= $line;
		}
	    }
	    if (! $end) {
		die "$name: EOF found before close rule\n";
	    }
	} else {
	    $line =~ s/^\S+\s+//; 
	    chomp ($line);
	    $rule = $line;
	}

	# look for the weight
	my $weight = 1;
	if( $name =~ /([^\+]*)\+(\d+)$/ ) {
	    $name = $1;
	    $weight = $2;
	    if( $debug > 10 ) {
		warn "weighting rule by $weight: $name -> $rule\n";
	    }
	}

	do {
	    push @{$rules->{$name}}, $rule;
	} while( --$weight > 0 );
    }

    if( defined $RE ) {
	compute_re( $rules, $RE );
    }

}

sub compute_re {

    # must sort; order matters, and we want to make sure that we get
    # the longest matches first
    my ($rules, $RE) = @_;
    my $in = join "|", sort { length ($b) <=> length ($a) } keys %$rules;
    $$RE = qr/^(.*?)(${in})/s ;

}

sub generate {
    my ($rules, $start, $RE, $debug, $pretty) = @_;


    my $s = expand ($rules, $start, $RE, $debug);
    if( $pretty ) {
	$s = pretty_print($s);
    }
    return $s;
}

sub pick_rand {
    my ($set) = @_;
    my $n = $#$set + 1;
    my $v =  @$set[int (rand () * $n)];
    return $v;
}

sub pop_first_rule {
    my ($rules, $preamble, $input, $rule, $RE) = @_;

    $$preamble = undef;
    $$rule = undef;

    my $ret = undef;
    
    if ($$input =~ s/$RE//s ) {
	$$preamble = $1;
	$$rule = $2;
	return 1;
    }
	
    return 0;
}

sub pretty_print {

    my ($s) = shift;

    my $news = "";
    my @lines = split( /\n/, $s );
    foreach my $line (@lines) {

	my $newline = "";

	$line =~ s/(\s+)([\.\,\?\;\:])/$2/g;
	$line =~ s/(\b)(a)\s+([aeiou])/$1$2n $3/gi;

	if( $line =~ /\\section(\*?){(.*)}/ ) {
	    $newline = "\\section${1}{" . 
	      Autoformat::autoformat( $2, { case => 'highlight', 
					    squeeze => 0 } );
	    chomp $newline;
	    chomp $newline;
	    $newline .= "}";
	} elsif( $line =~ /(\\subsection){(.*)}/ or 
		 $line =~ /(\\slideheading){(.*)}/ ) {
	    $newline = $1 . "{" . 
	      Autoformat::autoformat( $2, { case => 'highlight', 
					    squeeze => 0 } );
	    chomp $newline;
	    chomp $newline;
	    $newline .= "}";
	} elsif( $line =~ /\\title{(.*)}/ ) {
	    $newline = "\\title{" . 
	      Autoformat::autoformat( $1, { case => 'highlight', 
					    squeeze => 0  } );
	    chomp $newline;
	    chomp $newline;
	    $newline .= "}";
	} elsif( $line =~ /(.*) = {(.*)}\,/ ) {
	    my $label = $1;
	    my $curr = $2;
	    # place brackets around any words containing capital letters
	    $curr =~ s/\b([^\s]*[A-Z]+[^\s\:]*)\b/\{$1\}/g;
	    $newline = "$label = {" . 
	      Autoformat::autoformat( $curr, { case => 'highlight', 
					       squeeze => 0  } );
	    chomp $newline;
	    chomp $newline;
	    $newline .= "},";
	} elsif( $line =~ /\S/ ) {
	    $newline = 
	      Autoformat::autoformat( $line, { case => 'sentence', 
					       squeeze => 0, 
					       break => break_latex(),
					       ignore => qr/^\\/ } );
	}

	$newline =~ s/\\Em/\\em/g;

	if( $newline !~ /\n$/ ) {
	    $newline .= "\n";
	}
	$news .= $newline;

    }

    return $news;
}

sub break_latex($$$) {
    my ($text, $reqlen, $fldlen) = @_;
    if( !defined $text ) {
	$text = "";
    }
    return { $text, "" };
}

sub expand {
    my ($rules, $start, $RE, $debug) = @_;

    # check for special rules ending in + and # 
    # Rules ending in + generate a sequential integer
    # The same rule ending in # chooses a random # from among preiously
    # generated integers
    if( $start =~ /(.*)\+$/ ) {
	my $rule = $1;
	my $i = $rules->{$rule};
	if( !defined $i ) {
	    $i = 0;
	    $rules->{$rule} = 1;
	} else {
	    $rules->{$rule} = $i+1;
	}
	return $i;
    } elsif( $start =~ /(.*)\#$/ ) {
	my $rule = $1;
	my $i = $rules->{$rule};
	if( !defined $i ) {
	    $i = 0;
	} else {
	    $i = int rand $i;
	}
	return $i;
    }
    my $full_token;

    my $repeat = 0;
    my $count = 0;
    do {

	my $input = pick_rand ($rules->{$start});
	$count++;
	if ($debug >= 5) {
	    warn "$start -> $input\n";
	}

	my ($pre, $rule);
	my @components;
	$repeat = 0;	

	while (pop_first_rule ($rules, \$pre, \$input, \$rule, $RE)) {
	    my $ex = expand ($rules, $rule, $RE, $debug);
	    push @components, $pre if length ($pre);
	    push @components, $ex if length ($ex);
	}
	push @components, $input if length ($input);
	$full_token = join "", @components ;
	my $ref = $rules->{dup_name("$start")};
	if( defined $ref ) {
	    my @dups = @{$ref};
	    # make sure we haven't generated this exact token yet
	    foreach my $d (@dups) {
		if( $d eq $full_token ) {
		    $repeat = 1;
		}
	    }
	    
	    if( !$repeat ) {
		push @{$rules->{dup_name("$start")}}, $full_token;
	    } elsif( $count > 50 ) {
		$repeat = 0;
	    }
	    
	}

    } while( $repeat );

    return $full_token;
    
}


1;
