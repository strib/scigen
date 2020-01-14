package Autoformat;  # modified by JS: remove Text:: package

# See the bottom of this file for copyright and owner information.
# Modified by Jeremy Stribling to work with SCIgen, 2/2005.

use strict; use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); use Carp;
use 5.005;
$VERSION = '1.12';

require Exporter;

# modified by JS: remove Text:: package
use Reform qw( form tag break_at break_with break_wrap break_TeX );

@ISA = qw(Exporter);
@EXPORT = qw( autoformat );
@EXPORT_OK =
	qw( form tag break_at break_with break_wrap break_TeX ignore_headers );


my %ignore = map {$_=>1} qw {
	a an at as and are
	but by 
	ere
	for from
	in into is
	of on onto or over
	per
	the to that than
	until unto upon
	via
	with while whilst within without
};

my @entities = qw {
	&Aacute;   &aacute;      &Acirc;    &acirc;        &AElig;    &aelig;
	&Agrave;   &agrave;      &Alpha;    &alpha;        &Atilde;   &atilde;
	&Auml;     &auml;        &Beta;     &beta;         &Ccedil;   &ccedil;
	&Chi;      &chi;         &Delta;    &delta;        &Eacute;   &eacute;
	&Ecirc;    &ecirc;       &Egrave;   &egrave;       &Epsilon;  &epsilon;
	&Eta;      &eta;         &ETH;      &eth;          &Euml;     &euml;
	&Gamma;    &gamma;       &Iacute;   &iacute;       &Icirc;    &icirc;
	&Igrave;   &igrave;      &Iota;     &iota;         &Iuml;     &iuml;
	&Kappa;    &kappa;       &Lambda;   &lambda;       &Mu;       &mu;
	&Ntilde;   &ntilde;      &Nu;       &nu;           &Oacute;   &oacute;
	&Ocirc;    &ocirc;       &OElig;    &oelig;        &Ograve;   &ograve;
	&Omega;    &omega;       &Omicron;  &omicron;      &Otilde;   &otilde;
	&Ouml;     &ouml;        &Phi;      &phi;          &Pi;       &pi;
	&Prime;    &prime;       &Psi;      &psi;          &Rho;      &rho;
	&Scaron;   &scaron;      &Sigma;    &sigma;        &Tau;      &tau;
	&Theta;    &theta;       &THORN;    &thorn;        &Uacute;   &uacute;
	&Ucirc;    &ucirc;       &Ugrave;   &ugrave;       &Upsilon;  &upsilon;
	&Uuml;     &uuml;        &Xi;       &xi;           &Yacute;   &yacute;
	&Yuml;     &yuml;        &Zeta;     &zeta;         
};

my %lower_entities = @entities;
my %upper_entities = reverse @entities;

my %casing = (
	lower => [ \%lower_entities,  \%lower_entities,
		   sub { $_ = lc },   sub { $_ = lc } ],
	upper => [ \%upper_entities,  \%upper_entities,
		   sub { $_ = uc },   sub { $_ = uc } ],
        # modified by JS: no need to lowercase everything before the ucfirst
	title => [ \%upper_entities,  \%lower_entities,
		   sub { $_ = ucfirst  }, sub { $_ = lc  } ],
);

my $default_margin = 72;
my $default_widow  = 10;

# modified by JS: remove Text:: package
$Autoformat::widow_slack = 0.1;


sub defn($)
{
	return $_[0] if defined $_[0];
	return "";
}

my $ignore_headers = qr/\A(From\b.*$)?([^:]+:.*$([ \t].*$)*)+\s*\Z/m;
my $ignore_indent  = qr/^[^\S\n].*(\n[^\S\n].*)*$/;

sub ignore_headers { $_[0]==1 && /$ignore_headers/ }

# BITS OF A TEXT LINE

my $quotechar = qq{[!#%=|:]};
my $quotechunk = qq{(?:$quotechar(?![a-z])|[a-z]*>+)};
my $quoter = qq{(?:(?i)(?:$quotechunk(?:[ \\t]*$quotechunk)*))};

my $separator = q/(?:[-_]{2,}|[=#*]{3,}|[+~]{4,})/;

use overload;
sub autoformat	# ($text, %args)
{
	my ($text,%args,$toSTDOUT);

	foreach ( @_ )
	{
		if (ref eq 'HASH')
			{ %args = (%args, %$_) }
		elsif (!defined($text) && !ref || overload::Method($_,'""'))
			{ $text = "$_" }
		else {
			croak q{Usage: autoformat([text],[{options}])}
		}
	}

	unless (defined $text) {
		$text = join("",<STDIN>);
		$toSTDOUT = !defined wantarray();
	}

	return unless length $text;

	$args{right}   = $default_margin unless exists $args{right};
	$args{justify} = "" unless exists $args{justify};
	$args{widow}   = 0 if $args{justify}||"" =~ /full/;
	$args{widow}   = $default_widow unless exists $args{widow};
	$args{case}    = '' unless exists $args{case};
	$args{squeeze} = 1 unless exists $args{squeeze};
	$args{gap}     = 0 unless exists $args{gap};
	$args{break}  = break_at('-') unless exists $args{break};
	$args{impfill} = ! exists $args{fill};
	$args{expfill} = $args{fill};
	$args{renumber} = 1 unless exists $args{renumber};
	$args{autocentre} = 1 unless exists $args{autocentre};
	$args{_centred} = 1 if $args{justify} =~ /cent(er(ed)?|red?)/;

	# SPECIAL IGNORANCE...
	if ($args{ignore}) {
		$args{all} = 1;
		my $ig_type = ref $args{ignore};
		if ($ig_type eq 'Regexp') {
			my $regex = $args{ignore};
			$args{ignore} = sub { /$regex/ };
		}
		elsif ($args{ignore} =~ /^indent/i) {
			$args{ignore} = sub { ignore_headers(@_) || /$ignore_indent/ };
		}
		croak "Expected suboutine reference as value for -ignore option"
			if ref $args{ignore} ne 'CODE';
	}
	else {
		$args{ignore} = \&ignore_headers;
	}
	
	# DETABIFY
	my @rawlines = split /\n/, $text;
	use Text::Tabs;
	@rawlines = expand(@rawlines);

	# PARSE EACH LINE

	my $pre = 0;
	my @lines;
	foreach (@rawlines)
	{
			push @lines, { raw	   => $_ };
			s/\A([ \t]*)($quoter?)([ \t]*)//
				or die "Internal Error ($@) on '$_'";
			$lines[-1]{presig} =  $lines[-1]{prespace}   = defn $1;
			$lines[-1]{presig} .= $lines[-1]{quoter}     = defn $2;
			$lines[-1]{presig} .= $lines[-1]{quotespace} = defn $3;

			$lines[-1]{hang}       = Hang->new($_);

			s/([ \t]*)(.*?)(\s*)$//
				or die "Internal Error ($@) on '$_'";
			$lines[-1]{hangspace} = defn $1;
			$lines[-1]{text} = defn $2;
			$lines[-1]{empty} = $lines[-1]{hang}->empty() && $2 !~ /\S/;
			$lines[-1]{separator} = $lines[-1]{text} =~ /^$separator$/;
	}

	# SUBDIVIDE DOCUMENT INTO COHERENT SUBSECTIONS

	my @chunks;
	push @chunks, [shift @lines];
	foreach my $line (@lines)
	{
		if ($line->{separator} ||
		    $line->{quoter} ne $chunks[-1][-1]->{quoter} ||
		    $line->{empty} ||
		    @chunks && $chunks[-1][-1]->{empty})
		{
			push @chunks, [$line];
		}
		else
		{
			push @{$chunks[-1]}, $line;
		}
	}



 # DETECT CENTRED PARAS

	CHUNK: foreach my $chunk ( @chunks )
	{
		next CHUNK if !$args{autocentre} || @$chunk < 2;
		my @length;
		my $ave = 0;
		foreach my $line (@$chunk)
		{
			my $prespace = $line->{quoter}  ? $line->{quotespace}
							: $line->{prespace};
			my $pagewidth = 
				2*length($prespace) + length($line->{text});
			push @length, [length $prespace,$pagewidth];
			$ave += $pagewidth;
		}
		$ave /= @length;
		my $diffpre = 0;
		foreach my $l (0..$#length)
		{
			next CHUNK unless abs($length[$l][1]-$ave) <= 2;
			$diffpre ||= $length[$l-1][0] != $length[$l][0]
				if $l > 0;
		}
		next CHUNK unless $diffpre;
		foreach my $line (@$chunk)
		{
			$line->{centred} = 1;
			($line->{quoter} ? $line->{quotespace}
					 : $line->{prespace}) = "";
		}
	}

	# REDIVIDE INTO PARAGRAPHS

	my @paras;
	foreach my $chunk ( @chunks )
	{
		my $first = 1;
		my $firstfrom;
		foreach my $line ( @{$chunk} )
		{
			if ($first ||
			    $line->{quoter} ne $paras[-1]->{quoter} ||
			    $paras[-1]->{separator} ||
			    !$line->{hang}->empty
			   )
			{
				push @paras, $line;
				$first = 0;
				$firstfrom = length($line->{raw}) - length($line->{text});
			}
			else
			{
    my $extraspace = length($line->{raw}) - length($line->{text}) - $firstfrom;
				$paras[-1]->{text} .= "\n" . q{ }x$extraspace . $line->{text};
				$paras[-1]->{raw} .= "\n" . $line->{raw};
			}
		}
	}

	# SELECT PARAS TO HANDLE

	my $remainder = "";
	if ($args{all}) { # STOP AT MAIL TERMINATOR
		for my $index (0..$#paras) {
		    local $_ = $paras[$index]{raw};
		    $paras[$index]{ignore} = $args{ignore}($index+1);
		    next unless /^--$/;
		    $remainder = join "\n", map { $_->{raw} } splice @paras, $index;
	            $remainder .= "\n" unless $remainder =~ /\n\z/;
		    last;
		}
	}
	else { # JUST THE FIRST PARA
		$remainder = join "\n", map { $_->{raw} } @paras[1..$#paras];
	        $remainder .= "\n" unless $remainder =~ /\n\z/;
		@paras = ( $paras[0] );
	}

	# RE-CASE TEXT
	if ($args{case}) {
		foreach my $para ( @paras ) {
			next if $para->{ignore};
			if ($args{case} =~ /upper/i) {
				$para->{text} = recase($para->{text}, 'upper');
			}
			if ($args{case} =~ /lower/i) {
				$para->{text} = recase($para->{text}, 'lower');
			}
			if ($args{case} =~ /title/i) {
				entitle($para->{text},0);
			}
			if ($args{case} =~ /highlight/i) {
				entitle($para->{text},1);
			}
			if ($args{case} =~ /sentence(\s*)/i) {
				my $trailer = $1;
				$args{squeeze}=0 if $trailer && $trailer ne " ";
				ensentence();
				$para->{text} =~ s/(\S+(\s+|$))/ensentence($1, $trailer)/ge;
			}
			$para->{text} =~ s/\b([A-Z])[.]/\U$1./gi; # ABBREVS
		}
	}

	# ALIGN QUOTERS
	# DETERMINE HANGING MARKER TYPE (BULLET, ALPHA, ROMAN, ETC.)

	my %sigs;
	my $lastquoted = 0;
	my $lastprespace = 0;
	for my $i ( 0..$#paras )
	{
		my $para = $paras[$i];
		next if $para->{ignore};

	 if ($para->{quoter})
		{
			if ($lastquoted) { $para->{prespace} = $lastprespace }
			else		 { $lastquoted = 1; $lastprespace = $para->{prespace} }
		}
		else
		{
			$lastquoted = 0;
		}
	}

# RENUMBER PARAGRAPHS

	for my $para ( @paras ) {
		next if $para->{ignore};
		my $sig = $para->{presig} . $para->{hang}->signature();
		push @{$sigs{$sig}{hangref}}, $para;
		$sigs{$sig}{hangfields} = $para->{hang}->fields()-1
			unless defined $sigs{$sig}{hangfields};
	}

	while (my ($sig,$val) = each %sigs) {
		next unless $sig =~ /rom/;
		field: for my $field ( 0..$val->{hangfields} )
		{
			my $romlen = 0;
			foreach my $para ( @{$val->{hangref}} )
			{
				my $hang = $para->{hang};
				my $fieldtype = $hang->field($field);
				next field 
					unless $fieldtype && $fieldtype =~ /rom|let/;
				if ($fieldtype eq 'let') {
					foreach my $para ( @{$val->{hangref}} ) {
						$hang->field($field=>'let')
					}
				}
				else {
					$romlen += length $hang->val($field);
				}
			}
			# NO ROMAN LETTER > 1 CHAR -> ALPHABETICS
			if ($romlen <= @{$val->{hangref}}) {
				foreach my $para ( @{$val->{hangref}} ) {
					$para->{hang}->field($field=>'let')
				}
			}
		}
	}

	my %prev;

	for my $para ( @paras ) {
		next if $para->{ignore};
		my $sig = $para->{presig} . $para->{hang}->signature();
		if ($args{renumber}) {
			unless ($para->{quoter}) {
				$para->{hang}->incr($prev{""}, $prev{$sig});
				$prev{""} = $prev{$sig} = $para->{hang}
					unless $para->{hang}->empty;
			}
		}
			
		# COLLECT MAXIMAL HANG LENGTHS BY SIGNATURE

		my $siglen = $para->{hang}->length();
		$sigs{$sig}{hanglen} = $siglen
			if ! $sigs{$sig}{hanglen} ||
			   $sigs{$sig}{hanglen} < $siglen;
	}

	# PROPAGATE MAXIMAL HANG LENGTH

	while (my ($sig,$val) = each %sigs)
	{
		foreach (@{$val->{hangref}}) {
			$_->{hanglen} = $val->{hanglen};
		}
	}

	# BUILD FORMAT FOR EACH PARA THEN FILL IT 

	$text = "";
	my $gap = $paras[0]->{empty} ? 0 : $args{gap};
	for my $para ( @paras )
	{
	    if ($para->{empty}) {
		$gap += 1 + ($para->{text} =~ tr/\n/\n/);
	    }
	    if ($para->{ignore}) {
	        $text .= (!$para->{empty} ? "\n"x($args{gap}-$gap) : "") ;
		$text .= $para->{raw};
		$text .= "\n" unless $para->{raw} =~ /\n\z/;
	    }
	    else {
	        my $leftmargin = $args{left} ? " "x($args{left}-1)
					 : $para->{prespace};
	        my $hlen = $para->{hanglen} || $para->{hang}->length;
	        my $hfield = ($hlen==1 ? '~' : '>'x$hlen);
	        my @hang;
	        push @hang, $para->{hang}->stringify if $hlen;
	        my $format = $leftmargin
			   . quotemeta($para->{quoter})
			   . $para->{quotespace}
			   . $hfield
			   . $para->{hangspace};
                # modified by JS: remove Text:: package
	        my $rightslack = int (($args{right}-length $leftmargin)*$Autoformat::widow_slack);
	        my ($widow_okay, $rightindent, $firsttext, $newtext) = (0,0);
	        do {
	            my $tlen = $args{right}-$rightindent-length($leftmargin
			 			    . $para->{quoter}
			 			    . $para->{quotespace}
			 			    . $hfield
			 			    . $para->{hangspace});
	            next if blockquote($text,$para, $format, $tlen, \@hang, \%args);
	            my $tfield = ( $tlen==1                          ? '~'
			         : $para->{centred}||$args{_centred} ? '|'x$tlen
			         : $args{justify} eq 'right'         ? ']'x$tlen
			         : $args{justify} eq 'full'          ? '['x($tlen-2) . ']]'
			         : $para->{centred}||$args{_centred} ? '|'x$tlen
			         :                                     '['x$tlen
        		         );
		    my $tryformat = "$format$tfield";
		    $newtext = (!$para->{empty} ? "\n"x($args{gap}-$gap) : "") 
		             . form( { squeeze=>$args{squeeze}, trim=>1,
				       break=>$args{break},
				       fill => !(!($args{expfill}
					    || $args{impfill} &&
					       !$para->{centred}))
			           },
				    $tryformat, @hang,
				    $para->{text});
		    $firsttext ||= $newtext;
		    $newtext =~ /\s*([^\n]*)$/;
		    $widow_okay = $para->{empty} || length($1) >= $args{widow};
	        } until $widow_okay || ++$rightindent > $rightslack;
    
	        $text .= $widow_okay ? $newtext : $firsttext;
	    }
	    $gap = 0 unless $para->{empty};
	}


	# RETURN FORMATTED TEXT

	if ($toSTDOUT) { print STDOUT $text . $remainder; return }
	return $text . $remainder;
}

use utf8;

my $alpha = qr/[^\W\d_]/;
my $notalpha = qr/[\W\d_]/;
my $word = qr/\pL(?:\pL'?)*/;
my $upper = qr/[^\Wa-z\d_]/;
my $lower = qr/[^\WA-Z\d_]/;
my $mixed = qr/$alpha*?(?:$lower$upper|$upper$lower)$alpha*/;

sub recase {
	my ($origtext, $case) = @_;
	my ($entities, $other_entities, $first, $rest) = @{$casing{$case}};

	my $text = "";
	my @pieces = split /(&[a-z]+;)/i, $origtext;
	use Data::Dumper 'Dumper';
	push @pieces, "" if @pieces % 2;
	return $text unless @pieces;
	local $_ = shift @pieces;
	if (length $_) {
		$entities = $other_entities;
		&$first;
		$text .= $_;
	}
	return $text unless @pieces;
	$_ = shift @pieces;
	$text .= $entities->{$_} || $_;
	while (@pieces) {
		$_ = shift @pieces; &$rest; $text .= $_;
		$_ = shift @pieces; $text .= $other_entities->{$_} || $_;
	}
	return $text;
}

my $alword = qr{(?:\pL|&[a-z]+;)(?:[\pL']|&[a-z]+;)*}i;

sub entitle {
	my $ignore = pop;
	local *_ = \shift;

	# put into lowercase if on stop list, else titlecase
	s{($alword)}
         # modified by JS: just a formatting change
	 { $ignore && 
	       $ignore{lc $1} ? recase($1,'lower') : recase($1,'title') }gex;

	s/^($alword) /recase($1,'title')/ex;  # last word always to cap
	s/ ($alword)$/recase($1,'title')/ex;  # first word always to cap

	# treat parethesized portion as a complete title
	s/\( ($alword) /'('.recase($1,'title')/ex;
	s/($alword) \) /recase($1,'title').')'/ex;

	# capitalize first word following colon or semi-colon
	s/ ( [:;] \s+ ) ($alword) /$1 . recase($2,'title')/ex;
}

my $abbrev = join '|', qw{
        # modified by JS: add al. and Jr.
	etc[.]	pp[.]	ph[.]?d[.]	U[.]S[.]  al. Jr.
};

my $gen_abbrev = join '|', $abbrev, qw{
 	(^[^a-z]*([a-z][.])+)
};

my $term = q{(?:[.]|[!?]+)};

my $eos = 1;
my $brsent = 0;

sub ensentence {
	do { $eos = 1; return } unless @_;
	my ($str, $trailer) = @_;
	if ($str =~ /^([^a-z]*)I[^a-z]*?($term?)[^a-z]*$/i) {
		$eos = $2;
		$brsent = $1 =~ /^[[(]/;
		return uc $str
	}
        # modified by JS: Don't lc LaTeX stuff inside {}
	unless ($str =~ /[a-z0-9].*[A-Z]|[A-Z].*[a-z0-9]/ or 
		$str =~ /^\(?\{?[A-Z]+\}?\)?/) {
		$str = lc $str;
	}
	if ($eos) {
		$str =~ s/([a-z])/uc $1/ie;
		$brsent = $str =~ /^[[(]/;
	}
	$eos = $str !~ /($gen_abbrev)[^a-z]*\s/i
	    && $str =~ /[a-z][^a-z]*$term([^a-z]*)\s/
	    && !($1=~/[])]/ && !$brsent);
	$str =~ s/\s+$/$trailer/ if $eos && $trailer;
	return $str;
}

# blockquote($text,$para, $format, $tlen, \@hang, \%args);
sub blockquote {
	my ($dummy, $para, $format, $tlen, $hang, $args) = @_;
=begin other
	print STDERR "[", join("|", $para->{raw} =~
/ \A(\s*)		# $1 - leading whitespace (quotation)
	   (["']|``)		# $2 - opening quotemark
	   (.*)			# $3 - quotation
	   (''|\2)		# $4 closing quotemark
	   \s*?\n		# trailing whitespace
	   (\1[ ]+)		# $5 - leading whitespace (attribution)
	   (--|-)		# $6 - attribution introducer
	   ([^\n]*?$)		# $7 - attribution line 1
	   ((\5[^\n]*?$)*)		# $8 - attributions lines 2-N
	   \s*\Z
	 /xsm
), "]\n";
=cut
	$para->{text} =~
		/ \A(\s*)		# $1 - leading whitespace (quotation)
	   (["']|``)		# $2 - opening quotemark
	   (.*)			# $3 - quotation
	   (''|\2)		# $4 closing quotemark
	   \s*?\n		# trailing whitespace
	   (\1[ ]+)		# $5 - leading whitespace (attribution)
	   (--|-)		# $6 - attribution introducer
	   (.*?$)		# $7 - attribution line 1
	   ((\5.*?$)*)		# $8 - attributions lines 2-N
	   \s*\Z
	 /xsm
	 or return;

	#print "[$1][$2][$3][$4][$5][$6][$7]\n";
	my $indent = length $1;
	my $text = $2.$3.$4;
	my $qindent = length $2;
	my $aindent = length $5;
	my $attribintro = $6;
	my $attrib = $7.$8;
	$text =~ s/\n/ /g;

	$_[0] .= 

				form {squeeze=>$args->{squeeze}, trim=>1,
          fill => $args->{expfill}
			       },
	   $format . q{ }x$indent . q{<}x$tlen,
             @$hang, $text,
	   $format . q{ }x($qindent) . q{[}x($tlen-$qindent), 
             @$hang, $text,
	   {squeeze=>0},
	   $format . q{ } x $aindent . q{>> } . q{[}x($tlen-$aindent-3),
             @$hang, $attribintro, $attrib;
	return 1;
}

package Hang;

# ROMAN NUMERALS

sub inv($@) { my ($k, %inv)=shift; for(0..$#_) {$inv{$_[$_]}=$_*$k} %inv } 
my @unit= ( "" , qw ( I II III IV V VI VII VIII IX ));
my @ten = ( "" , qw ( X XX XXX XL L LX LXX LXXX XC ));
my @hund= ( "" , qw ( C CC CCC CD D DC DCC DCCC CM ));
my @thou= ( "" , qw ( M MM MMM ));
my %rval= (inv(1,@unit),inv(10,@ten),inv(100,@hund),inv(1000,@thou));
my $rbpat= join ")(",join("|",reverse @thou), join("|",reverse @hund), join("|",reverse @ten), join("|",reverse @unit);
my $rpat= join ")(?:",join("|",reverse @thou), join("|",reverse @hund), join("|",reverse @ten), join("|",reverse @unit);

sub fromRoman($)
{
    return 0 unless $_[0] =~ /^.*?($rbpat).*$/i;
    return $rval{uc $1} + $rval{uc $2} + $rval{uc $3} + $rval{uc $4};
}

sub toRoman($$)
{
    my ($num,$example) = @_;
    return '' unless $num =~ /^([0-3]??)(\d??)(\d??)(\d)$/;
    my $roman = $thou[$1||0] . $hund[$2||0] . $ten[$3||0] . $unit[$4||0];
    return $example=~/[A-Z]/ ? uc $roman : lc $roman;
}

# BITS OF A NUMERIC VALUE

my $num = q/(?:\d{1,3}\b)/;
my $rom = qq/(?:(?=[MDCLXVI])(?:$rpat))/;
my $let = q/[A-Za-z]/;
my $pbr = q/[[(<]/;
my $sbr = q/])>/;
my $ows = q/[ \t]*/;
my %close = ( '[' => ']', '(' => ')', '<' => '>', "" => '' );

my $hangPS      = qq{(?i:ps:|(?:p\\.?)+s\\b\\.?(?:[ \\t]*:)?)};
my $hangNB      = qq{(?i:n\\.?b\\.?(?:[ \\t]*:)?)};
my $hangword    = qq{(?:(?:Note)[ \\t]*:)};
my $hangbullet  = qq{[*.+-]};
my $hang        = qq{(?:(?i)(?:$hangNB|$hangword|$hangbullet)(?=[ \t]))};

# IMPLEMENTATION

sub new { 
	my ($class, $orig) = @_;
	my $origlen = length $orig;
	my @vals;
	if ($_[1] =~ s#\A($hangPS)##) {
		@vals = { type => 'ps', val => $1 }
	}
	elsif ($_[1] =~ s#\A($hang)##) {
		@vals = { type => 'bul', val => $1 }
	}
	else {
		local $^W;
		my $cut;
		while (length $_[1]) {
			last if $_[1] =~ m#\A($ows)($abbrev)#
			     && (length $1 || !@vals);	# ws-separated or first

			$cut = $origlen - length $_[1];
			my $pre = $_[1] =~ s#\A($ows$pbr$ows)## ? $1 : "";
			my $val =  $_[1] =~ s#\A($num)##  && { type=>'num', val=>$1 }
			       || $_[1] =~ s#\A($rom)##i && { type=>'rom', val=>$1, nval=>fromRoman($1) }
			       || $_[1] =~ s#\A($let(?!$let))##i && { type=>'let', val=>$1 }
			       || { val => "", type => "" };
			$_[1] = $pre.$_[1] and last unless $val->{val};
			$val->{post} = $pre && $_[1] =~ s#\A($ows()[.:/]?[$close{$pre}][.:/]?)## && $1
		                     || $_[1] =~ s#\A($ows()[$sbr.:/])## && $1
		                     || "";
			$val->{pre}  = $pre;
			$val->{cut}  = $cut;
			push @vals, $val;
		}
		while (@vals && !$vals[-1]{post}) {
			$_[1] = substr($orig,pop(@vals)->{cut});
		}
	}
	# check for orphaned years...
	if (@vals==1 && $vals[0]->{type} eq 'num'
		     && $vals[0]->{val} >= 1000
		     && $vals[0]->{post} eq '.')  {
		$_[1] = substr($orig,pop(@vals)->{cut});

        }
	return NullHang->new if !@vals;
	bless \@vals, $class;
} 

sub incr {
	local $^W;
	my ($self, $prev, $prevsig) = @_;
	my $level;
	# check compatibility

	return unless $prev && !$prev->empty;

	for $level (0..(@$self<@$prev ? $#$self : $#$prev)) {
		if ($self->[$level]{type} ne $prev->[$level]{type}) {
			return if @$self<=@$prev;	# no incr if going up
			$prev = $prevsig;
			last;
		}
	}
	return unless $prev && !$prev->empty;
	if ($self->[0]{type} eq 'ps') {
		my $count = 1 + $prev->[0]{val} =~ s/(p[.]?)/$1/gi;
		$prev->[0]{val} =~ /^(p[.]?).*(s[.]?[:]?)/;
		$self->[0]{val} = $1  x $count . $2;
	}
	elsif ($self->[0]{type} eq 'bul') {
		# do nothing
	}
	elsif (@$self>@$prev) {	# going down level(s)
		for $level (0..$#$prev) {
				@{$self->[$level]}{'val','nval'} = @{$prev->[$level]}{'val','nval'};
		}
		for $level (@$prev..$#$self) {
				_reset($self->[$level]);
		}
	}
	else	# same level or going up
	{
		for $level (0..$#$self) {
			@{$self->[$level]}{'val','nval'} = @{$prev->[$level]}{'val','nval'};
		}
		_incr($self->[-1])
	}
}

sub _incr {
	local $^W;
	if ($_[0]{type} eq 'rom') {
		$_[0]{val} = toRoman(++$_[0]{nval},$_[0]{val});
	}
	else {
		$_[0]{val}++ unless $_[0]{type} eq 'let' && $_[0]{val}=~/Z/i;
	}
}

sub _reset {
	local $^W;
	if ($_[0]{type} eq 'rom') {
		$_[0]{val} = toRoman($_[0]{nval}=1,$_[0]{val});
	}
	elsif ($_[0]{type} eq 'let') {
		$_[0]{val} = $_[0]{val} =~ /[A-Z]/ ? 'A' : 'a';
	}
	else {
		$_[0]{val} = 1;
	}
}

sub stringify {
	my ($self) = @_;
	my ($str, $level) = ("");
	for $level (@$self) {
		local $^W;
		$str .= join "", @{$level}{'pre','val','post'};
	}
	return $str;
} 

sub val {
	my ($self, $i) = @_;
	return $self->[$i]{val};
}

sub fields { return scalar @{$_[0]} }

sub field {
	my ($self, $i, $newval) = @_;
	$self->[$i]{type} = $newval if @_>2;
	return $self->[$i]{type};
}

sub signature {
	local $^W;
	my ($self) = @_;
	my ($str, $level) = ("");
	for $level (@$self) {
		$level->{type} ||= "";
		$str .= join "", $level->{pre},
		                 ($level->{type} =~ /rom|let/ ? "romlet" : $level->{type}),
		                 $level->{post};
	}
	return $str;
} 

sub length {
	length $_[0]->stringify
}

sub empty { 0 }

package NullHang;

sub new       { bless {}, $_[0] }
sub stringify { "" }
sub length    { 0 }
sub incr      {}
sub empty     { 1 }
sub signature     { "" }
sub fields { return 0 }
sub field { return "" }
sub val { return "" }
1;

__END__

=head1 NAME

Text::Autoformat - Automatic text wrapping and reformatting

=head1 VERSION

This document describes version 1.12 of Text::Autoformat,
released May 27, 2003.

=head1 SYNOPSIS

 # Minimal use: read from STDIN, format to STDOUT...

	use Text::Autoformat;
	autoformat;

 # In-memory formatting...

	$formatted = autoformat $rawtext;

 # Configuration...

	$formatted = autoformat $rawtext, { %options };

 # Margins (1..72 by default)...

	$formatted = autoformat $rawtext, { left=>8, right=>70 };

 # Justification (left by default)...

	$formatted = autoformat $rawtext, { justify => 'left' };
	$formatted = autoformat $rawtext, { justify => 'right' };
	$formatted = autoformat $rawtext, { justify => 'full' };
	$formatted = autoformat $rawtext, { justify => 'centre' };

 # Filling (does so by default)...

	$formatted = autoformat $rawtext, { fill=>0 };

 # Squeezing whitespace (does so by default)...

	$formatted = autoformat $rawtext, { squeeze=>0 };

 # Case conversions...

	$formatted = autoformat $rawtext, { case => 'lower' };
	$formatted = autoformat $rawtext, { case => 'upper' };
	$formatted = autoformat $rawtext, { case => 'sentence' };
	$formatted = autoformat $rawtext, { case => 'title' };
	$formatted = autoformat $rawtext, { case => 'highlight' };

 # Selective reformatting

	$formatted = autoformat $rawtext, { ignore=>qr/^\t/ };


=head1 BACKGROUND

=head2 The problem

Perl plaintext formatters just aren't smart enough. Given a typical
piece of plaintext in need of formatting:

        In comp.lang.perl.misc you wrote:
        : > <CN = Clooless Noobie> writes:
        : > CN> PERL sux because:
        : > CN>    * It doesn't have a switch statement and you have to put $
        : > CN>signs in front of everything
        : > CN>    * There are too many OR operators: having |, || and 'or'
        : > CN>operators is confusing
        : > CN>    * VB rools, yeah!!!!!!!!!
        : > CN> So anyway, how can I stop reloads on a web page?
        : > CN> Email replies only, thanks - I don't read this newsgroup.
        : >
        : > Begone, sirrah! You are a pathetic, Bill-loving, microcephalic
        : > script-infant.
        : Sheesh, what's with this group - ask a question, get toasted! And how
        : *dare* you accuse me of Ianuphilia!

both the venerable Unix L<fmt> tool and Perl's standard Text::Wrap module
produce:

        In comp.lang.perl.misc you wrote:  : > <CN = Clooless Noobie>
        writes:  : > CN> PERL sux because:  : > CN>    * It doesn't
        have a switch statement and you have to put $ : > CN>signs in
        front of everything : > CN>    * There are too many OR
        operators: having |, || and 'or' : > CN>operators is confusing
        : > CN>    * VB rools, yeah!!!!!!!!!  : > CN> So anyway, how
        can I stop reloads on a web page?  : > CN> Email replies only,
        thanks - I don't read this newsgroup.  : > : > Begone, sirrah!
        You are a pathetic, Bill-loving, microcephalic : >
        script-infant.  : Sheesh, what's with this group - ask a
        question, get toasted! And how : *dare* you accuse me of
        Ianuphilia!

Other formatting modules -- such as Text::Correct and Text::Format --
provide more control over their output, but produce equally poor results
when applied to arbitrary input. They simply don't understand the
structural conventions of the text they're reformatting.

=head2 The solution

The Text::Autoformat module provides a subroutine named C<autoformat> that
wraps text to specified margins. However, C<autoformat> reformats its
input by analysing the text's structure, so it wraps the above example
like so:

        In comp.lang.perl.misc you wrote:
        : > <CN = Clooless Noobie> writes:
        : > CN> PERL sux because:
        : > CN>    * It doesn't have a switch statement and you
        : > CN>      have to put $ signs in front of everything
        : > CN>    * There are too many OR operators: having |, ||
        : > CN>      and 'or' operators is confusing
        : > CN>    * VB rools, yeah!!!!!!!!! So anyway, how can I
        : > CN>      stop reloads on a web page? Email replies
        : > CN>      only, thanks - I don't read this newsgroup.
        : >
        : > Begone, sirrah! You are a pathetic, Bill-loving,
        : > microcephalic script-infant.
        : Sheesh, what's with this group - ask a question, get toasted!
        : And how *dare* you accuse me of Ianuphilia!

Note that the various quoting conventions have been observed. In fact,
their structure has been used to determine where some paragraphs begin.
Furthermore C<autoformat> correctly distinguished between the leading
'*' bullets of the nested list (which were outdented) and the leading
emphatic '*' of "*dare*" (which was inlined).

=head1 DESCRIPTION

=head2 Paragraphs

The fundamental task of the C<autoformat> subroutine is to identify and
rearrange independent paragraphs in a text. Paragraphs typically consist
of a series of lines containing at least one non-whitespace character,
followed by one or more lines containing only optional whitespace.
This is a more liberal definition than many other formatters
use: most require an empty line to terminate a paragraph. Paragraphs may
also be denoted by bulleting, numbering, or quoting (see the following
sections).

Once a paragraph has been isolated, C<autoformat> fills and re-wraps its
lines according to the margins that are specified in its argument list.
These are placed after the text to be formatted, in a hash reference:

        $tidied = autoformat($messy, {left=>20, right=>60});

By default, C<autoformat> uses a left margin of 1 (first column) and a
right margin of 72.

You can also control whether (and how) C<autoformat> breaks words at the
end of a line, using the C<'break'> option:

	# Turn off all hyphenation
	use Text::Autoformat qw(autoformat break_wrap);
        $tidied = autoformat($messy, {break=>break_wrap});

	# Default hyphenation
	use Text::Autoformat qw(autoformat break_at);
        $tidied = autoformat($messy, {break=>break_at('-')});

	# Use TeX::Hyphen module's hyphenation (module must be installed)
	use Text::Autoformat qw(autoformat break_TeX);
        $tidied = autoformat($messy, {break=>break_TeX});


Normally, C<autoformat> only reformats the first paragraph it encounters,
and leaves the remainder of the text unaltered. This behaviour is useful
because it allows a one-liner invoking the subroutine to be mapped
onto a convenient keystroke in a text editor, to provide 
one-paragraph-at-a-time reformatting:

        % cat .exrc

        map f !Gperl -MText::Autoformat -e'autoformat'

(Note that to facilitate such one-liners, if C<autoformat> is called
in a void context without any text data, it takes its text from
C<STDIN> and writes its result to C<STDOUT>).

To enable C<autoformat> to rearrange the entire input text at once, the
C<all> argument is used:

        $tidied_all = autoformat($messy, {left=>20, right=>60, all=>1});

C<autoformat> can also be directed to selectively reformat paragraphs,
using the C<ignore> argument:

        $tidied_some = autoformat($messy, {ignore=>qr/^[ \t]/});

The value for C<ignore> may be a C<qr>'d regex, a subroutine reference,
or the special string C<'indented'>.

If a regex is specified, any paragraph whose original text matches that
regex will not be reformatted (i.e. it will be printed verbatim).

If a subroutine is specified, that subroutine will be called once for
each paragraph (with C<$_> set to the paragraph's text). The subroutine is
expected to return a true or false value. If it returns true, the
paragraph will not be reformatted.

If the value of the C<ignore> option is the string C<'indented'>,
C<autoformat> will ignore any paragraph in which I<every> line begins with a
whitespace.

=head2 Bulleting and (re-)numbering

Often plaintext will include lists that are either:

        * bulleted,
        * simply numbered (i.e. 1., 2., 3., etc.), or
        * hierarchically numbered (1, 1.1, 1.2, 1.3, 2, 2.1. and so forth).

In such lists, each bulleted item is implicitly a separate paragraph,
and is formatted individually, with the appropriate indentation:

        * bulleted,
        * simply numbered (i.e. 1., 2., 3.,
          etc.), or
        * hierarchically numbered (1, 1.1,
          1.2, 1.3, 2, 2.1. and so forth).

More importantly, if the points are numbered, the numbering is
checked and reordered. For example, a list whose points have been
rearranged:

        2. Analyze problem
        3. Design algorithm
        1. Code solution
        5. Test
        4. Ship

would be renumbered automatically by C<autoformat>:

        1. Analyze problem
        2. Design algorithm
        3. Code solution
        4. Ship
        5. Test

The same reordering would be performed if the "numbering" was by letters
(C<a.> C<b.> C<c.> etc.) or Roman numerals (C<i.> C<ii.> C<iii.)> or by
some combination of these (C<1a.> C<1b.> C<2a.> C<2b.> etc.) Handling
disordered lists of letters and Roman numerals presents an interesting
challenge. A list such as:

        C. Put cat in box.
        D. Close lid.
        E. Activate Geiger counter.

should be reordered as C<A.> C<B.> C<C.,> whereas:

        C. Put cat in box.
        D. Close lid.
        XLI. Activate Geiger counter.

should be reordered C<I.> C<II.> C<III.> 

The C<autoformat> subroutine solves this problem by always interpreting 
alphabetic bullets as being letters, unless the full list consists
only of valid Roman numerals, at least one of which is two or
more characters long.

If automatic renumbering isn't wanted, just specify the C<'renumber'>
option with a false value.

Note that numbers above 1000 at the start of a line are no longer
considered to be paragraph numbering. Numbered paragraphs running that
high are exceptionally rare, and much rarer than paragraphs that look
like this:

        Although it has long been popular (especially in the year
        2001) to point out that we now live in the Future, many
        of the promised miracles of Future Life have failed to
        eventuate. This is a new phenomenon (it didn't happen in
        1001) because the idea that the future might be different
        is a new phenomenon.

which the former numbering rules caused to be formatted like this:

        Although it has long been popular (especially in the year

        2001) to point out that we now live in the Future, many of the
              promised miracles of Future Life have failed to eventuate.
              This is a new phenomenon (it didn't happen in

        2002) because the idea that the future might be different is a
              new phenomenon.

but which are now formatted:

        Although it has long been popular (especially in the year 2001)
        to point out that we now live in the Future, many of the
        promised miracles of Future Life have failed to eventuate. This
        is a new phenomenon (it didn't happen in 1001) because the idea
        that the future might be different is a new phenomenon.

=head2 Quoting

Another case in which contiguous lines may be interpreted as belonging
to different paragraphs, is where they are quoted with distinct quoters.
For example:

        : > CN> So anyway, how can I stop reloads on a web page? Email
        : > CN> replies only, thanks - I don't read this newsgroup.
        : > Begone, sirrah! You are a pathetic, Bill-loving,
        : > microcephalic script-infant.
        : Sheesh, what's with this group - ask a question, get toasted!
        : And how *dare* you accuse me of Ianuphilia!

C<autoformat> recognizes the various quoting conventions used in this
example and treats it as three paragraphs to be independently
reformatted.

Block quotations present a different challenge. A typical formatter
would render the following quotation:

        "We are all of us in the gutter, but some of us are looking at
         the stars"
                                -- Oscar Wilde

like so:

        "We are all of us in the gutter, but some of us are looking at
        the stars" -- Oscar Wilde

C<autoformat> recognizes the quotation structure by matching the
following regular expression against the text component of each
paragraph:

        / \A(\s*) # leading whitespace for quotation (["']|``) # opening
        quotemark (.*) # quotation (''|\2) # closing quotemark \s*?\n #
        trailing whitespace after quotation (\1[ ]+) # leading
        whitespace for attribution
                                #   (must be indented more than
                                #   quotation)
          (--|-) # attribution introducer ([^\n]*?\n) # first
          attribution line ((\5[^\n]*?$)*) # other attribution lines
                                #   (indented no less than first line)
          \s*\Z # optional whitespace to end of paragraph /xsm

When reformatted (see below), the indentation and the attribution
structure will be preserved:

        "We are all of us in the gutter, but some of us are looking at
         the stars"
                                -- Oscar Wilde

=head2 Widow control

Note that in the last example, C<autoformat> broke the line at column
68, four characters earlier than it should have. It did so because, if
the full margin width had been used, the formatting would have left the
last two words by themselves on an oddly short last line:

        "We are all of us in the gutter, but some of us are looking at
        the stars"

This phenomenon is known as "widowing" and is heavily frowned upon in
typesetting circles. It looks ugly in plaintext too, so C<autoformat>
avoids it by stealing extra words from earlier lines in a paragraph, so
as to leave enough for a reasonable last line. The heuristic used is
that final lines must be at least 10 characters long (though this number
may be adjusted by passing a C<widow =E<gt> I<minlength>> argument to
C<autoformat>).

If the last line is too short, the paragraph's right margin is reduced
by one column, and the paragraph is reformatted. This process iterates
until either the last line exceeds nine characters or the margins have
been narrowed by 10% of their original separation. In the latter case,
the reformatter gives up and uses its original formatting.


=head2 Justification

The C<autoformat> subroutine also takes a named argument: C<{justify
=E<gt> I<type>}>, which specifies how each paragraph is to be justified.
The options are: C<'left'> (the default), C<'right',> C<'centre'> (or
C<'center'>), and C<'full'>. These act on the complete paragraph text
(but I<not> on any quoters before that text). For example, with
C<'right'> justification:

         R3>     Now is the Winter of our discontent made
         R4> glorious Summer by this son of York. And all
         R5> the clouds that lour'd upon our house In the
         R6>              deep bosom of the ocean buried.

Full justification is interesting in a fixed-width medium like plaintext
because it usually results in uneven spacing between words. Typically,
formatters provide this by distributing the extra spaces into the first
available gaps of each line:

         R7> Now is the Winter of our discontent made
         R8> glorious Summer by this son of York. And all
         R9> the clouds that lour'd upon our house In
        R10> the deep bosom of the ocean buried.

This produces a rather jarring visual effect, so C<autoformat> reverses
the strategy and inserts extra spaces at the end of lines:

        R11> Now is the Winter of our discontent made
        R12> glorious Summer by this son of York. And all
        R13> the clouds that lour'd upon our house In
        R14> the deep bosom of the ocean buried.

Most readers find this less disconcerting.

=head2 Implicit centring

Even if explicit centring is not specified, C<autoformat> will attempt
to automatically detect centred paragraphs and preserve their
justification. It does this by examining each line of the paragraph and
asking: "if this line were part of a centred paragraph, where would the
centre line have been?"

The answer can be determined by adding the length of leading whitespace
before the first word, plus half the length of the full set of words on
the line. That is, for a single line:

        $line =~ /^(\s*)(.*?)(\s*)$/ $centre =
        length($1)+0.5*length($2);

By making the same estimate for every line, and then comparing the
estimates, it is possible to deduce whether all the lines are centred
with respect to the same axis of symmetry (with an allowance of
E<plusmn>1 to cater for the inevitable rounding when the centre
positions of even-length rows were originally computed). If a common
axis of symmetry is detected, C<autoformat> assumes that the lines are
supposed to be centred, and switches to centre-justification mode for
that paragraph.

Note that this behaviour can to switched off entirely by setting the
C<"autocentre"> argument false.

=head2 Case transformations

The C<autoformat> subroutine can also optionally perform case
conversions on the text it processes. The C<{case =E<gt> I<type>}>
argument allows the user to specify five different conversions:

=over 4

=item C<'upper'>

This mode unconditionally converts every letter in the reformatted text
to upper-case;

=item C<'lower'>

This mode unconditionally converts every letter in the reformatted text
to lower-case;

=item C<'sentence'>

This mode attempts to generate correctly-cased sentences from the input
text. That is, the first letter after a sentence-terminating punctuator
is converted to upper-case. Then, each subsequent word in the sentence
is converted to lower-case, unless that word is originally mixed-case or
contains punctuation. For example, under C<{case =E<gt> 'sentence'}>:

        'POVERTY, MISERY, ETC. are the lot of the PhD candidate. alas!'

becomes:

        'Poverty, misery, etc. are the lot of the PhD candidate. Alas!'

Note that C<autoformat> is clever enough to recognize that the period
after abbreviations such as C<etc.> is not a sentence terminator.

If the argument is specified as C<'sentence '> (with one or more
trailing whitespace characters) those characters are used to replace the
single space that appears at the end of the sentence. For example,
C<autoformat($text, {case=E<gt>'sentence '}>) would produce:

        'Poverty, misery, etc. are the lot of the PhD candidate. Alas!'

=item C<'title'>

This mode behaves like C<'sentence'> except that the first letter of
I<every> word is capitalized:

        'What I Did On My Summer Vacation In Monterey'

=item C<'highlight'>

This mode behaves like C<'title'> except that trivial words are not
capitalized:

        'What I Did on my Summer Vacation in Monterey'

=back

=head2 Selective reformatting

You can select which paragraphs C<autoformat> actually reformats (or,
rather, those it I<doesn't> reformat) using the C<"ignore"> flag.

For example:

        # Reformat all paras except those containing "verbatim"...
        print autoformat { all => 1, ignore => qr/verbatim/i }, $text;

        # Reformat all paras except those less that 3 lines long...
        print autoformat { all => 1, ignore => sub { tr/\n/\n/ < 3
        } }, $text;

        # Reformat all paras except those that are indented...
        print autoformat { all => 1, ignore => qr/^\s/m }, $text;

        # Reformat all paras except those that are indented (easier)...
        print autoformat { all => 1, ignore => 'indented' }, $text;


=head1 SEE ALSO

The Text::Reform module

=head1 AUTHOR

Damian Conway (damian@conway.org)

=head1 BUGS

There are undoubtedly serious bugs lurking somewhere in code this funky
:-) Bug reports and other feedback are most welcome.

=head1 COPYRIGHT

Copyright (c) 1997-2000, Damian Conway. All Rights Reserved. This module
is free software. It may be used, redistributed and/or modified under
the terms of the Perl Artistic License (see
http://www.perl.com/perl/misc/Artistic.html)
