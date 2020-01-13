package Reform; # modified by JS: remove Text:: package

# See the bottom of this file for copyright and owner information.
# Modified by Jeremy Stribling to work with SCIgen, 2/2005.

use strict; use vars qw($VERSION @ISA @EXPORT @EXPORT_OK); use Carp;
use 5.005;
$VERSION = '1.11';

require Exporter;

@ISA = qw(Exporter);
@EXPORT = qw( form );
@EXPORT_OK = qw( tag break_with break_at break_wrap break_TeX debug );

my @bspecials = qw( [ | ] );
my @lspecials = qw( < ^ > );
my $ljustified = '[<]{2,}[>]{2,}';
my $bjustified = '[[]{2,}[]]{2,}';
my $bsingle    = '~+';
my @specials = (@bspecials, @lspecials);
my $fixed_fieldpat = join('|', ($ljustified, $bjustified,
				$bsingle,
				map { "\\$_\{2,}" } @specials));
my ($lfieldmark, $bfieldmark, $fieldmark, $fieldpat, $decimal);
my $emptyref = '';

sub import
{
	use POSIX qw( localeconv );
	$decimal = localeconv()->{decimal_point} || '.';

	my $lnumerical = '[>]+(?:'.quotemeta($decimal).'[<]{1,})';
	my $bnumerical = '[]]+(?:'.quotemeta($decimal).'[[]{1,})';

	$fieldpat = join('|', ($lnumerical, $bnumerical,$fixed_fieldpat));

	$lfieldmark = join '|', ($lnumerical, $ljustified, map { "\\$_\{2}" } @lspecials);
	$bfieldmark = join '|', ($bnumerical, $bjustified, $bsingle, map { "\\$_\{2}" } @bspecials);
	$fieldmark  = join '|', ($lnumerical, $bnumerical,
				 $bsingle,
				 $ljustified, $bjustified,
				 $lfieldmark, $bfieldmark);

	Reform->export_to_level(1, @_);
}

sub carpfirst {
	our %carped;
	my ($msg) = @_;
	return if $carped{$msg}++;
	carp $msg;
}

###### USEFUL TOOLS ######################################

#===== form =============================================#

sub BAD_CONFIG { 'Configuration hash not allowed between format and data' }

sub break_with
{
	my $hyphen = $_[0];
	my $hylen = length($hyphen);
	my @ret;
	sub
	{
		if ($_[2]<=$hylen)
		{
			@ret = (substr($_[0],0,1), substr($_[0],1))
		}
		else
		{
			@ret = (substr($_[0],0,$_[1]-$hylen),
				substr($_[0],$_[1]-$hylen))
		}
		if ($ret[0] =~ /\A\s*\Z/) { return ("",$_[0]); }
		else { return ($ret[0].$hyphen,$ret[1]); }
	}

}

sub break_at {
	my $hyphen = $_[0];
	my $hylen = length($hyphen);
	my @ret;
	sub
	{
		my $max = $_[2]-$hylen;
		if ($max <= 0) {
			@ret = (substr($_[0],0,1), substr($_[0],1))
		}
		elsif ($_[0] =~ /(.{1,$max}$hyphen)(.*)/s) {
			@ret = ($1,$2);
		}
		elsif (length($_[0])>$_[2]) {
			@ret = (substr($_[0],0,$_[1]-$hylen).$hyphen,
				substr($_[0],$_[1]-$hylen))
		}
		else {
			@ret = ("",$_[0]);
		}
		if ($ret[0] =~ /\A\s*\Z/) { return ("",$_[0]); }
		else { return @ret; }
	}

}

sub break_wrap
{
	return \&break_wrap unless @_;
	my ($text, $reqlen, $fldlen) = @_;
	if ($reqlen==$fldlen) { $text =~ m/\A(\s*\S*)(.*)/s }
	else                  { ("", $text) }
}

my %hyp;
sub break_TeX
{
	my $file = $_[0] || "";

	croak "Can't find TeX::Hypen module"
		unless require "TeX/Hyphen.pm";

	$hyp{$file} = TeX::Hyphen->new($file||undef)
			|| croak "Can't open hyphenation file $file"
		unless $hyp{$file};

	return sub {
		for (reverse $hyp{$file}->hyphenate($_[0])) {
			if ($_ < $_[1]) {
				return (substr($_[0],0,$_).'-',
					substr($_[0],$_) );
			}
		}
		return ("",$_[0]);
	}
}

my $debug = 0;
sub _debug { print STDERR @_, "\n" if $debug }
sub debug { $debug = 1; }

sub notempty
{
	my $ne = ${$_[0]} =~ /\S/;
	_debug("\tnotempty('${$_[0]}') = $ne\n");
	return $ne;
}

sub replace($$$$)   # ($fmt, $len, $argref, $config)
{
	my $ref = $_[2];
	my $text = '';
	my $rem = $_[1];
	my $config = $_[3];
	my $filled = 0;

	if ($config->{fill}) { $$ref =~ s/\A\s*// }
	else		     { $$ref =~ s/\A[ \t]*// }

	my $fmtnum = length $_[0];

	if ($$ref =~ /\S/ && $fmtnum>2)
	{
	NUMERICAL:{
		use POSIX qw( strtod );
		my ($ilen,$dlen) = map {length} $_[0] =~ m/([]>]+)\Q$decimal\E([[<]+)/;
		my ($num,$unconsumed) = strtod($$ref);
		if ($unconsumed == length $$ref)
		{
			$$ref =~ s/\s*\S*//;
			redo NUMERICAL if $config->{numeric} =~ m/\bSkipNaN\b/i
				       && $$ref =~ m/\S/;
			$text = '?' x $ilen . $decimal . '?' x $dlen;
			$rem = 0;
			return $text;
		}
		my $formatted = sprintf "%$fmtnum.${dlen}f", $num;
		$text = (length $formatted > $fmtnum)
			? '#' x $ilen . $decimal . '#' x $dlen
			: $formatted;
		$text =~ s/(\Q$decimal\E\d+?)(0+)$/$1 . " " x length $2/e
			unless $config->{numeric} =~ m/\bAllPlaces\b/i
			    || $num =~ /\Q$decimal\E\d\d{$dlen,}$/;
		if ($unconsumed)
		{
			if ($unconsumed == length $$ref)
				{ $$ref =~ s/\A.[^0-9.+-]*// }
			else
				{ substr($$ref,0,-$unconsumed) = ""}
		}
		else            { $$ref = "" }
		$rem = 0;
	    }
	}
	else
	{
		while ($$ref =~ /\S/)
		{
			if (!$config->{fill} && $$ref=~s/\A[ \t]*\n//)
				{ $filled = 2; last }
			last unless $$ref =~ /\A(\s*)(\S+)(.*)\z/s;
			my ($ws, $word, $extra) = ($1,$2,$3);
			my $nonnl = $ws =~ /[^\n]/;
			$ws =~ s/\n/$nonnl? "" : " "/ge if $config->{fill};
			my $lead = ($config->{squeeze} ? ($ws ? " " : "") : $ws);
			my $match = $lead . $word;
			_debug "Extracted [$match]";
			last if $text && $match =~ /\n/;
			my $len1 = length($match);
			if ($len1 <= $rem)
			{
				_debug "Accepted [$match]";
				$text .= $match;
				$rem  -= $len1;
				$$ref = $extra;
			}
			else
			{
				_debug "Need to break [$match]";
				# was: if ($len1 > $_[1] and $rem-length($lead)>$config->{minbreak})
				if ($rem-length($lead)>$config->{minbreak})
				{
					_debug "Trying to break '$match'";
					my ($broken,$left) =
						$config->{break}->($match,$rem,$_[1]);	
					$text .= $broken;
					_debug "Broke as: [$broken][$left]";
					$$ref = $left.$extra;
					$rem -= length $broken;
				}
				last;
			}
		}
		continue { $filled=1 }
	}

	if (!$filled && $rem>0 && $$ref=~/\S/ && length $text == 0)
	{
		$$ref =~ s/^\s*(.{1,$rem})//;
		$text = $1;
		$rem -= length $text;
	}

	if ( $text=~/ / && $_[0] eq 'J' && $$ref=~/\S/ && $filled!=2 ) {
							# FULLY JUSTIFIED
		$text = reverse $text;
		$text =~ s/( +)/($rem-->0?" ":"").$1/ge while $rem>0;
		$text = reverse $text;
	}
	elsif ( $_[0] =~ /\>|\]/ ) {			# RIGHT JUSTIFIED
		substr($text,0,0) =
			substr($config->{filler}{left} x $rem, -$rem)
				if $rem > 0;
	}
	elsif ( $_[0] =~ /\^|\|/ ) {			# CENTRE JUSTIFIED
	    if ($rem>0) {
		my $halfrem = int($rem/2);
		substr($text,0,0) =
			substr($config->{filler}{left}x$halfrem, -$halfrem);
		$halfrem = $rem-$halfrem;
		$text .= substr($config->{filler}{right}x$halfrem, 0, $halfrem);
	    }
	}
	else {						# LEFT JUSTIFIED
		$text .= substr($config->{filler}{right}x$rem, 0, $rem)
			if $rem > 0;
	}

	return $text;
}

my %std_config =
(
	header	   => sub{""},
	footer	   => sub{""},
	pagefeed   => sub{""},
	pagelen	   => 0,
	pagenum	   => undef,
	pagewidth  => 72,
	break	   => break_with('-'),
	minbreak   => 2,
	squeeze	   => 0,
	filler     => {left=>' ', right=>' '},
	interleave => 0,
	numeric	   => "",
	_used      => 1,
);

sub lcr {
	my ($data, $pagewidth, $header) = @_;
	$data->{width}  ||= $pagewidth;
	$data->{left}   ||= "";
	$data->{centre} ||= $data->{center}||"";
	$data->{right}  ||= "";
	return sub {
		my @l = split "\n", (ref $data->{left} eq 'CODE'
				? $data->{left}->(@_) : $data->{left}), -1;
		my @c = split "\n", (ref $data->{centre} eq 'CODE'
				? $data->{centre}->(@_) : $data->{centre}), -1;
		my @r = split "\n", (ref $data->{right} eq 'CODE'
				? $data->{right}->(@_) : $data->{right}), -1;
		my $text = "";
		while (@l||@c||@r) {
			my $l = @l ? shift(@l) : "";
			my $c = @c ? shift(@c) : "";
			my $r = @r ? shift(@r) : "";
			my $gap = int(($data->{width}-length($c))/2-length($l));
			if ($gap < 0) {
				$gap = 0;
				carpfirst "\nWarning: $header is wider than specified page width ($data->{width} chars)" if $^W;
			}
			$text .= $l . " " x $gap
			       . $c . " " x ($data->{width}-length($l)-length($c)-$gap-length($r))
			       . $r
			       . "\n";
		}
		return $text;
	}
}

sub fix_config(\%)
{
	my ($config) = @_;
	if (ref $config->{header} eq 'HASH') {
		$config->{header} =
			lcr $config->{header}, $config->{pagewidth}, 'header';
	}
	elsif (ref $config->{header} eq 'CODE') {
		my $tmp = $config->{header};
		$config->{header} = sub {
			my $header = &$tmp;
			return (ref $header eq 'HASH')
				? lcr($header,$config->{pagewidth},'header')->()
				: $header;
		}
	}
	else {
		my $tmp = $config->{header};
		$config->{header} = sub { $tmp }
	}
	if (ref $config->{footer} eq 'HASH') {
		$config->{footer} =
			lcr $config->{footer}, $config->{pagewidth}, 'footer';
	}
	elsif (ref $config->{footer} eq 'CODE') {
		my $tmp = $config->{footer};
		$config->{footer} = sub {
			my $footer = &$tmp;
			return (ref $footer eq 'HASH')
				? lcr($footer,$config->{pagewidth},'footer')->()
				: $footer;
		}
	}
	else {
		my $tmp = $config->{footer};
		$config->{footer} = sub { $tmp }
	}
	unless (ref $config->{pagefeed} eq 'CODE')
		{ my $tmp = $config->{pagefeed}; $config->{pagefeed} = sub { $tmp } }
	unless (ref $config->{break} eq 'CODE')
		{ $config->{break} = break_at($config->{break}) }
	if (defined $config->{pagenum} && ref $config->{pagenum} ne 'SCALAR') 
		{ my $tmp = $config->{pagenum}+0; $config->{pagenum} = \$tmp }
	unless (ref $config->{filler} eq 'HASH') {
		$config->{filler} = { left  => "$config->{filler}",
			  	      right => "$config->{filler}" }
	}
}

sub FormOpt::DESTROY
{
	print STDERR "\nWarning: lexical &form configuration at $std_config{_line} was never used.\n"
		if $^W && !$std_config{_used};
	%std_config = %{$std_config{_prev}};
}

sub form
{
	our %carped;
	local %carped;
	my $config = {%std_config};
	my $startidx = 0;
	if (@_ && ref($_[0]) eq 'HASH')		# RESETTING CONFIG
	{
		if (@_ > 1)			# TEMPORARY RESET
		{
			$config = {%$config, %{$_[$startidx++]}};
			fix_config(%$config);
			$startidx = 1;
		}
		elsif (defined wantarray)	# CONTEXT BEING CAPTURED
		{
			$_[0]->{_prev} = { %std_config };
			$_[0]->{_used} = 0;
			$_[0]->{_line} = join " line ", (caller)[1..2];;
			%{$_[0]} = %std_config = (%std_config, %{$_[0]});
			fix_config(%std_config);
			return bless $_[0], 'FormOpt';
		}
		else				# PERMANENT RESET
		{
			$_[0]->{_used} = 1;
			$_[0]->{_line} = join " line ", (caller)[1..2];;
			%std_config = (%std_config, %{$_[0]});
			fix_config(%std_config);
			return;
		}
	}
	$config->{pagenum} = do{\(my $tmp=1)}
		unless defined $config->{pagenum};

	$std_config{_used}++;
	my @ref = map { ref } @_;
	my @orig = @_;
	my $caller = caller;
	no strict;

	for (my $nextarg=0; $nextarg<@_; $nextarg++)
	{
		my $next = $_[$nextarg];
		if (!defined $next) {
			my $tmp = "";
			splice @_, $nextarg, 1, \$tmp;
		}
		elsif ($ref[$nextarg] eq 'ARRAY') {
			splice @_, $nextarg, 1, \join("\n", @$next)
		}
		elsif ($ref[$nextarg] eq 'HASH' && $next->{cols} ) {
			croak "Missing 'from' data for 'cols' option"
				unless $next->{from};
			croak "Can't mix other options with 'cols' option"
				if keys %$next > 2;
			my ($cols, $data) = @{$next}{'cols','from'};
			croak "Invalid 'cols' option.\nExpected reference to array of column specifiers but found " . (ref($cols)||"'$cols'")
				unless ref $cols eq 'ARRAY';
			croak "Invalid 'from' data for 'cols' option.\nExpected reference to array of hashes or arrays but found " . (ref($data)||"'$data'")
				unless ref $data eq 'ARRAY';
			splice @_, $nextarg, 2, columns(@$cols,@$data);
			splice @ref, $nextarg, 2, ('ARRAY')x@$cols;
			$nextarg--;
		}
		elsif (!defined eval { local $SIG{__DIE__};
				       $_[$nextarg] = $next;
				       _debug "writeable: [$_[$nextarg]]";
				       1})
		{
		        _debug "unwriteable: [$_[$nextarg]]";
			my $arg = $_[$nextarg];
			splice @_, $nextarg, 1, \$arg;
		}
		elsif (!$ref[$nextarg]) {
			splice @_, $nextarg, 1, \$_[$nextarg];
		}
                elsif ($ref[$nextarg] ne 'HASH' and $ref[$nextarg] ne 'SCALAR')
                {
			splice @_, $nextarg, 1, \"$next";
                }
	}

	my $header = $config->{header}->(${$config->{pagenum}});
	$header.="\n" if $header && substr($header,-1,1) ne "\n";

	my $footer = $config->{footer}->(${$config->{pagenum}});
	$footer.="\n" if $footer && substr($footer,-1,1) ne "\n";

	my $prevfooter = $footer;

	my $linecount = $header=~tr/\n/\n/ + $footer=~tr/\n/\n/;
	my $hfcount = $linecount;

	my $text = $header;
	my @format_stack;

	LINE: while ($startidx < @_ || @format_stack)
	{
		if (($ref[$startidx]||'') eq 'HASH')
		{
			$config = {%$config, %{$_[$startidx++]}};
			fix_config(%$config);
			next;
		}
		unless (@format_stack) {
			@format_stack = $config->{interleave}
				? map "$_\n", split /\n/, ${$_[$startidx++]}||""
				: ${$_[$startidx++]}||"";
		}
		my $format = shift @format_stack;
		_debug("format: [$format]");
	
		my @parts = split /(\n|(?:\\.)+|$fieldpat)/, $format;
		push @parts, "\n" unless @parts && $parts[-1] eq "\n";
		my $fieldcount = 0;
		my $filled = 0;
		my $firstline = 1;
		while (!$filled)
		{
			my $nextarg = $startidx;
			my @data;
			foreach my $part ( @parts )
			{
				if ($part =~ /\A(?:\\.)+/)
				{
					_debug("esc literal: [$part]");
					my $tmp = $part;
					$tmp =~ s/\\(.)/$1/g;
					$text .= $tmp;
				}
				elsif ($part =~ /($lfieldmark)/)
				{
					if ($firstline)
					{
						$fieldcount++;
						if ($nextarg > $#_)
							{ push @_,\$emptyref; push @ref, '' }
						my $type = $1;
						$type = 'J' if $part =~ /$ljustified/;
						croak BAD_CONFIG if ($ref[$startidx] eq 'HASH');
						_debug("once field: [$part]");
						_debug("data was: [${$_[$nextarg]}]");
						$text .= replace($type,length($part),$_[$nextarg],$config);
						_debug("data now: [${$_[$nextarg]}]");
					}
					else
					{
						$text .= substr($config->{filler}{left} x length($part), -length($part));
						_debug("missing once field: [$part]");
					}
					$nextarg++;
				}
				elsif ($part =~ /($fieldmark)/ and substr($part,0,2) ne '~~')
				{
					$fieldcount++ if $firstline;
					if ($nextarg > $#_)
						{ push @_,\$emptyref; push @ref, '' }
					my $type = $1;
					$type = 'J' if $part =~ /$bjustified/;
					croak BAD_CONFIG if ($ref[$startidx] eq 'HASH');
					_debug("multi field: [$part]");
					_debug("data was: [${$_[$nextarg]}]");
					$text .= replace($type,length($part),$_[$nextarg],$config);
					_debug("data now: [${$_[$nextarg]}]");
					push @data, $_[$nextarg];
					$nextarg++;
				}
				else
				{
					_debug("literal: [$part]");
					my $tmp = $part;
					$tmp =~ s/\0(\0*)/$1/g;
					$text .= $tmp;
					if ($part eq "\n")
					{
						$linecount++;
						if ($config->{pagelen} && $linecount>=$config->{pagelen})
						{
							_debug("\tejecting page:  $config->{pagenum}");
							carpfirst "\nWarning: could not format page ${$config->{pagenum}} within specified page length"
								if $^W && $config->{pagelen} && $linecount > $config->{pagelen};
							${$config->{pagenum}}++;
							my $pagefeed = $config->{pagefeed}->(${$config->{pagenum}});
							$header = $config->{header}->(${$config->{pagenum}});
							$header.="\n" if $header && substr($header,-1,1) ne "\n";
							$text .= $footer
							       . $pagefeed
							       . $header;
							$prevfooter = $footer;
							$footer = $config->{footer}->(${$config->{pagenum}});
							$footer.="\n" if $footer && substr($footer,-1,1) ne "\n";
							$linecount = $hfcount =
								$header=~tr/\n/\n/ + $footer=~tr/\n/\n/;
							$header = $pagefeed
								. $header;
						}
					}
				}
				_debug("\tnextarg now:  $nextarg");
				_debug("\tstartidx now: $startidx");
			}
			$firstline = 0;
			$filled = ! grep { notempty $_ } @data;
		}
		$startidx += $fieldcount;
	}

	# ADJUST FINAL PAGE HEADER OR FOOTER AS REQUIRED
	if ($hfcount && $linecount == $hfcount)		# UNNEEDED HEADER
	{
		$text =~ s/\Q$header\E\Z//;
	}
	elsif ($linecount && $config->{pagelen})	# MISSING FOOTER
	{
		$text .= "\n" x ($config->{pagelen}-$linecount)
		       . $footer;
		$prevfooter = $footer;
	}

	# REPLACE LAST FOOTER
	
	if ($prevfooter) {
		my $lastfooter = $config->{footer}->(${$config->{pagenum}},1);
		$lastfooter.="\n"
			if $lastfooter && substr($lastfooter,-1,1) ne "\n";
		my $footerdiff = ($lastfooter =~ tr/\n/\n/)
			       - ($prevfooter =~ tr/\n/\n/);
		# Enough space to squeeze longer final footer in?
		my $tail = '^[^\S\n]*\n' x $footerdiff;
		if ($footerdiff > 0 && $text =~ /($tail\Q$prevfooter\E)\Z/m) {
			$prevfooter = $1;
			$footerdiff = 0;
		}
		# Apparently, not, so create an extra (empty) page for it
		if ($footerdiff > 0) {
			${$config->{pagenum}}++;
			my $lastheader = $config->{header}->(${$config->{pagenum}});
			$lastheader.="\n"
				if $lastheader && substr($lastheader,-1,1) ne "\n";
			$lastfooter = $config->{footer}->(${$config->{pagenum}},1);
			$lastfooter.="\n"
				if $lastfooter && substr($lastfooter,-1,1) ne "\n";

			$text .= $lastheader
			       . ("\n" x ( $config->{pagelen}
					- ($lastheader =~ tr/\n/\n/)
				        - ($lastfooter =~ tr/\n/\n/)
					)
				 )
			       . $lastfooter;
		}
		else {
                        $lastfooter = ("\n"x-$footerdiff).$lastfooter;
                        substr($text, -length($prevfooter)) = $lastfooter;
		}
	}

        # RESTORE ARG LIST
        for my $i (0..$#orig)
        {
                if ($ref[$i] eq 'ARRAY')
                        { eval { @{$orig[$i]} = map "$_\n", split /\n/, ${$_[$i]} } }
                elsif (!$ref[$i])
                        { eval { _debug("restoring $i (".$_[$i].") to " .
                                 defined($orig[$i]) ? $orig[$i] : "<undef>");
                                 ${$_[$i]} = $orig[$i] } }
        }

        ${$config->{pagenum}}++;
        $text =~ s/[ ]+$//gm if $config->{trim};
        return $text unless wantarray;
        return map "$_\n", split /\n/, $text;
}


#==== columns ========================================#

sub columns {
        my @cols;
        my (@fullres, @res);
        while (@_) {
                my $arg = shift @_;
                my $type = ref $arg;
                if ($type eq 'HASH') {
                        push @{$res[$_]}, $arg->{$cols[$_]} for 0..$#cols;
                }
                elsif ($type eq 'ARRAY') {
                        push @{$res[$_]}, $arg->[$cols[$_]] for 0..$#cols;
                }
                else {
                        if (@res) {
                                push @fullres, @res;
                                @res = @cols = ();
                        }
                        push @cols, $arg;
                }
        }
        return @fullres, @res;
}


#==== tag ============================================#

sub invert($)
{
        my $inversion = reverse $_[0];
        $inversion =~ tr/{[<(/}]>)/;
        return $inversion;
}

sub tag         # ($tag, $text; $opt_endtag)
{
        my ($tagleader,$tagindent,$ldelim,$tag,$tagargs,$tagtrailer) = 
                ( $_[0] =~ /\A((?:[ \t]*\n)*)([ \t]*)(\W*)(\w+)(.*?)(\s*)\Z/ );

        $ldelim = '<' unless $ldelim;
        $tagtrailer =~ s/([ \t]*)\Z//;
        my $textindent = $1||"";

        my $rdelim = invert $ldelim;

        my $i;
        for ($i = -1; -1-$i < length $rdelim && -1-$i < length $tagargs; $i--)
        {
                last unless substr($tagargs,$i,1) eq substr($rdelim,$i,1);
        }
        if ($i < -1)
        {
                $i++;
                $tagargs = substr($tagargs,0,$i);
                $rdelim = substr($rdelim,$i);
        }

        my $endtag = $_[2] || "$ldelim/$tag$rdelim";

        return "$tagleader$tagindent$ldelim$tag$tagargs$rdelim$tagtrailer".
                join("\n",map { "$tagindent$textindent$_" } split /\n/, $_[1]).
                "$tagtrailer$tagindent$endtag$tagleader";

}


1;

__END__

=head1 NAME

Text::Reform - Manual text wrapping and reformatting

=head1 VERSION

This document describes version 1.11 of Text::Reform,
released May  7, 2003.

=head1 SYNOPSIS

        use Text::Reform;

        print form $template,
                   $data, $to, $fill, $it, $with;


        use Text::Reform qw( tag );

        print tag 'B', $enboldened_text;


=head1 DESCRIPTION

=head2 The C<form> sub

The C<form()> subroutine may be exported from the module.
It takes a series of format (or "picture") strings followed by
replacement values, interpolates those values into each picture string,
and returns the result. The effect is similar to the inbuilt perl
C<format> mechanism, although the field specification syntax is
simpler and some of the formatting behaviour is more sophisticated.

A picture string consists of sequences of the following characters:

=over 8

=item <

Left-justified field indicator.
A series of two or more sequential <'s specify
a left-justified field to be filled by a subsequent value.
A single < is formatted as the literal character '<'

=item >

Right-justified field indicator.
A series of two or more sequential >'s specify
a right-justified field to be filled by a subsequent value.
A single < is formatted as the literal character '<'

=item <<<>>>

Fully-justified field indicator.
Field may be of any width, and brackets need not balance, but there
must be at least 2 '<' and 2 '>'.

=item ^

Centre-justified field indicator.
A series of two or more sequential ^'s specify
a centred field to be filled by a subsequent value.
A single ^ is formatted as the literal character '<'

=item >>>.<<<<

A numerically formatted field with the specified number of digits to
either side of the decimal place. See L<Numerical formatting> below.


=item [

Left-justified block field indicator.
Just like a < field, except it repeats as required on subsequent lines. See
below.
A single [ is formatted as the literal character '['

=item ]

Right-justified block field indicator.
Just like a > field, except it repeats as required on subsequent lines. See
below.
A single ] is formatted as the literal character ']'

=item [[[]]]

Fully-justified block field indicator.
Just like a <<<>>> field, except it repeats as required on subsequent lines. See
below.
Field may be of any width, and brackets need not balance, but there
must be at least 2 '[' and 2 ']'.

=item |

Centre-justified block field indicator.
Just like a ^ field, except it repeats as required on subsequent lines. See
below.
A single | is formatted as the literal character '|'

=item ]]].[[[[

A numerically formatted block field with the specified number of digits to
either side of the decimal place.
Just like a >>>.<<<< field, except it repeats as required on
subsequent lines. See below. 


=item ~

A one-character wide block field.

=item \

Literal escape of next character (e.g. C<\~> is formatted as '~', not a one
character wide block field).

=item Any other character

That literal character.

=back

Any substitution value which is C<undef> (either explicitly so, or because it
is missing) is replaced by an empty string.



=head2 Controlling line filling.

Note that, unlike the a perl C<format>, C<form> preserves whitespace
(including newlines) unless called with certain options.

The "squeeze" option (when specified with a true value) causes any sequence
of spaces and/or tabs (but not newlines) in an interpolated string to be
replaced with a single space.

A true value for the "fill" option causes (only) newlines to be squeezed.

To minimize all whitespace, you need to specify both options. Hence:

        $format = "EG> [[[[[[[[[[[[[[[[[[[[[";
        $data   = "h  e\t l lo\nworld\t\t\t\t\t";

        print form $format, $data;              # all whitespace preserved:
                                                #
                                                # EG> h  e            l lo
                                                # EG> world


        print form {squeeze=>1},                # only newlines preserved:
                   $format, $data;              #
                                                # EG> h e l lo
                                                # EG> world


        print form {fill=>1},                   # only spaces/tabs preserved:
                    $format, $data;             #
                                                # EG> h  e        l lo world


        print form {squeeze=>1, fill=>1},       # no whitespace preserved:
                   $format, $data;              #
                                                # EG> h e l lo world


Whether or not filling or squeezing is in effect, C<form> can also be
directed to trim any extra whitespace from the end of each line it
formats, using the "trim" option. If this option is specified with a
true value, every line returned by C<form> will automatically have the
substitution C<s/[ \t]+$//gm> applied to it.

Hence:

        print length form "[[[[[[[[[[", "short";
        # 11

        print length form {trim=>1}, "[[[[[[[[[[", "short";
        # 6


It is also possible to control the character used to fill lines that are
too short, using the 'filler' option. If this option is specified the
value of the 'filler' flag is used as the fill string, rather than the
default C<" ">.

For example:

        print form { filler=>'*' },
                "Pay bearer: ^^^^^^^^^^^^^^^^^^^",
                '$123.45';

prints:

        Pay bearer: ******$123.45******

If the filler string is longer than one character, it is truncated
to the appropriate length. So:

        print form { filler=>'-->' },
                "Pay bearer: ]]]]]]]]]]]]]]]]]]]",
                ['$1234.50', '$123.45', '$12.34'];

prints:

        Pay bearer: ->-->-->-->$1234.50
        Pay bearer: -->-->-->-->$123.45
        Pay bearer: >-->-->-->-->$12.34

If the value of the 'filler' option is a hash, then it's 'left' and
'right' entries specify separate filler strings for each side of
an interpolated value. So:

        print form { filler=>{left=>'->', right=>'*'} },
                "Pay bearer: <<<<<<<<<<<<<<<<<<",
                '$123.45',
                "Pay bearer: >>>>>>>>>>>>>>>>>>",
                '$123.45',
                "Pay bearer: ^^^^^^^^^^^^^^^^^^",
                '$123.45';

prints:

        Pay bearer: $123.45***********
        Pay bearer: >->->->->->$123.45
        Pay bearer: >->->$123.45******


=head2 Temporary and permanent default options

If C<form> is called with options, but no template string or data, it resets
it's defaults to the options specified. If called in a void context:

        form { squeeze => 1, trim => 1 };

the options become permanent defaults.

However, when called with only options in non-void context, C<form>
resets its defaults to those options and returns an object. The reset
default values persist only until that returned object is destroyed.
Hence to temporarily reset C<form>'s defaults within a single subroutine:

        sub single {
                my $tmp = form { squeeze => 1, trim => 1 };

                # do formatting with the obove defaults

        } # form's defaults revert to previous values as $tmp object destroyed



=head2 Multi-line format specifiers and interleaving

By default, if a format specifier contains two or more lines
(i.e. one or more newline characters), the entire format specifier
is repeatedly filled as a unit, until all block fields have consumed
their corresponding arguments. For example, to build a simple
look-up table:

        my @values   = (1..12);

        my @squares  = map { sprintf "%.6g", $_**2    } @values;
        my @roots    = map { sprintf "%.6g", sqrt($_) } @values;
        my @logs     = map { sprintf "%.6g", log($_)  } @values;
        my @inverses = map { sprintf "%.6g", 1/$_     } @values;

        print form
        "  N      N**2    sqrt(N)      log(N)      1/N",
        "=====================================================",
        "| [[  |  [[[  |  [[[[[[[[[[ | [[[[[[[[[ | [[[[[[[[[ |
        -----------------------------------------------------",
        \@values, \@squares, \@roots, \@logs, \@inverses;

The multiline format specifier:
        
        "| [[  |  [[[  |  [[[[[[[[[[ | [[[[[[[[[ | [[[[[[[[[ |
        -----------------------------------------------------",

is treated as a single logical line. So C<form> alternately fills the
first physical line (interpolating one value from each of the arrays)
and the second physical line (which puts a line of dashes between each
row of the table) producing:

          N      N**2    sqrt(N)      log(N)      1/N
        =====================================================
        | 1   |  1    |  1          | 0         | 1         |
        -----------------------------------------------------
        | 2   |  4    |  1.41421    | 0.693147  | 0.5       |
        -----------------------------------------------------
        | 3   |  9    |  1.73205    | 1.09861   | 0.333333  |
        -----------------------------------------------------
        | 4   |  16   |  2          | 1.38629   | 0.25      |
        -----------------------------------------------------
        | 5   |  25   |  2.23607    | 1.60944   | 0.2       |
        -----------------------------------------------------
        | 6   |  36   |  2.44949    | 1.79176   | 0.166667  |
        -----------------------------------------------------
        | 7   |  49   |  2.64575    | 1.94591   | 0.142857  |
        -----------------------------------------------------
        | 8   |  64   |  2.82843    | 2.07944   | 0.125     |
        -----------------------------------------------------
        | 9   |  81   |  3          | 2.19722   | 0.111111  |
        -----------------------------------------------------
        | 10  |  100  |  3.16228    | 2.30259   | 0.1       |
        -----------------------------------------------------
        | 11  |  121  |  3.31662    | 2.3979    | 0.0909091 |
        -----------------------------------------------------
        | 12  |  144  |  3.4641     | 2.48491   | 0.0833333 |
        -----------------------------------------------------

This implies that formats and the variables from which they're filled
need to be interleaved. That is, a multi-line specification like this:

        print form
        "Passed:                      ##
           [[[[[[[[[[[[[[[             # single format specification
        Failed:                        # (needs two sets of data)
           [[[[[[[[[[[[[[[",          ##

        \@passes, \@fails;            ##  data for previous format

would print:

        Passed:
           <pass 1>
        Failed:
           <fail 1>
        Passed:
           <pass 2>
        Failed:
           <fail 2>
        Passed:
           <pass 3>
        Failed:
           <fail 3>

because the four-line format specifier is treated as a single unit,
to be repeatedly filled until all the data in C<@passes> and C<@fails>
has been consumed.

Unlike the table example, where this unit filling correctly put a
line of dashes between lines of data, in this case the alternation of passes
and fails is probably I<not> the desired effect.

Judging by the labels, it is far more likely that the user wanted:

        Passed:
           <pass 1>
           <pass 2>
           <pass 3>
        Failed:
           <fail 4>
           <fail 5>
           <fail 6>

To achieve that, either explicitly interleave the formats and their data
sources:

        print form 
        "Passed:",               ## single format (no data required)
        "   [[[[[[[[[[[[[[[",    ## single format (needs one set of data)
            \@passes,            ## data for previous format
        "Failed:",               ## single format (no data required)
        "   [[[[[[[[[[[[[[[",    ## single format (needs one set of data)
            \@fails;             ## data for previous format


or instruct C<form> to do it for you automagically, by setting the
'interleave' flag true:

        print form {interleave=>1}
        "Passed:                 ##
           [[[[[[[[[[[[[[[        # single format
        Failed:                   # (needs two sets of data)
           [[[[[[[[[[[[[[[",     ##

                                 ## data to be automagically interleaved
        \@passes, \@fails;        # as necessary between lines of previous
                                 ## format


=head2 How C<form> hyphenates

Any line with a block field repeats on subsequent lines until all block fields
on that line have consumed all their data. Non-block fields on these lines are
replaced by the appropriate number of spaces.

Words are wrapped whole, unless they will not fit into the field at
all, in which case they are broken and (by default) hyphenated. Simple
hyphenation is used (i.e. break at the I<N-1>th character and insert a
'-'), unless a suitable alternative subroutine is specified instead.

Words will not be broken if the break would leave less than 2 characters on
the current line. This minimum can be varied by setting the 'minbreak' option
to a numeric value indicating the minumum total broken characters (including
hyphens) required on the current line. Note that, for very narrow fields,
words will still be broken (but I<unhyphenated>). For example:

        print form '~', 'split';

would print:

        s
        p
        l
        i
        t

whilst:

        print form {minbreak=>1}, '~', 'split';

would print:

        s-
        p-
        l-
        i-
        t

Alternative breaking subroutines can be specified using the "break" option in a
configuration hash. For example:

        form { break => \&my_line_breaker }
             $format_str,
             @data;

C<form> expects any user-defined line-breaking subroutine to take three
arguments (the string to be broken, the maximum permissible length of
the initial section, and the total width of the field being filled).
The C<hypenate> sub must return a list of two strings: the initial
(broken) section of the word, and the remainder of the string
respectively).

For example:

        sub tilde_break = sub($$$)
        {
                (substr($_[0],0,$_[1]-1).'~', substr($_[0],$_[1]-1));
        }

        form { break => \&tilde_break }
             $format_str,
             @data;


makes '~' the hyphenation character, whilst:

        sub wrap_and_slop = sub($$$)
        {
                my ($text, $reqlen, $fldlen) = @_;
                if ($reqlen==$fldlen) { $text =~ m/\A(\s*\S*)(.*)/s }
                else                  { ("", $text) }
        }

        form { break => \&wrap_and_slop }
             $format_str,
             @data;

wraps excessively long words to the next line and "slops" them over
the right margin if necessary.

The Text::Reform package provides three functions to simplify the use
of variant hyphenation schemes. The exportable subroutine
C<Text::Reform::break_wrap> generates a reference to a subroutine
implementing the "wrap-and-slop" algorithm shown in the last example,
which could therefore be rewritten:

        use Text::Reform qw( form break_wrap );

        form { break => break_wrap }
             $format_str,
             @data;

The subroutine C<Text::Reform::break_with> takes a single string
argument and returns a reference to a sub which hyphenates by cutting 
off the text at the right margin and appending the string argument.
Hence the first of the two examples could be rewritten:

        use Text::Reform qw( form break_with );

        form { break => break_with('~') }
             $format_str,
             @data;

The subroutine C<Text::Reform::break_at> takes a single string
argument and returns a reference to a sub which hyphenates by
breaking immediately after that string. For example:

        use Text::Reform qw( form break_at );

        form { break => break_at('-') }
               "[[[[[[[[[[[[[[",
	       "The Newton-Raphson methodology";

	# returns:
	#
	#       "The Newton-
	#        Raphson 
	#        methodology"

Note that this differs from the behaviour of C<break_with>, which
would be:

        form { break => break_with('-') }
               "[[[[[[[[[[[[[[",
	       "The Newton-Raphson methodology";

	# returns:
	#
	#       "The Newton-R-
	#        aphson metho-
	#        dology"

Hence C<break_at> is generally a better choice.

The subroutine C<Text::Reform::break_TeX> 
returns a reference to a sub which hyphenates using 
Jan Pazdziora's TeX::Hyphen module. For example:

        use Text::Reform qw( form break_wrap );

        form { break => break_TeX }
             $format_str,
             @data;

Note that in the previous examples there is no leading '\&' before
C<break_wrap>, C<break_with>, or C<break_TeX>, since each is being
directly I<called> (and returns a reference to some other suitable
subroutine);


=head2 The C<form> formatting algorithm

The algorithm C<form> uses is:

        1. If interleaving is specified, split the first string in the
           argument list into individual format lines and add a
           terminating newline (unless one is already present).
           Otherwise, treat the entire string as a single "line" (like
           /s does in regexes)

        2. For each format line...

                2.1. determine the number of fields and shift
                     that many values off the argument list and
                     into the filling list. If insufficient
                     arguments are available, generate as many 
                     empty strings as are required.

                2.2. generate a text line by filling each field
                     in the format line with the initial contents
                     of the corresponding arg in the filling list
                     (and remove those initial contents from the arg).

                2.3. replace any <,>, or ^ fields by an equivalent
                     number of spaces. Splice out the corresponding
                     args from the filling list.

                2.4. Repeat from step 2.2 until all args in the
                     filling list are empty.

        3. concatenate the text lines generated in step 2

        4. repeat from step 1 until the argument list is empty


=head2 C<form> examples

As an example of the use of C<form>, the following:

        $count = 1;
        $text = "A big long piece of text to be formatted exquisitely";

        print form q
        q{       ||||  <<<<<<<<<<   },
        $count, $text,
        q{       ----------------   },
        q{       ^^^^  ]]]]]]]]]]|  },
        $count+11, $text,
        q{                       =  
                 ]]].[[[            },
        "123 123.4\n123.456789";

produces the following output:

                 1    A big long
                ----------------
                 12     piece of|
                      text to be|
                       formatted|
                      exquisite-|
                              ly|
                                =
                123.0
                                =
                123.4
                                =
                123.456

Note that block fields in a multi-line format string,
cause the entire multi-line format to be repeated as
often as necessary.

Picture strings and replacement values are interleaved in the
traditional C<format> format, but care is needed to ensure that the
correct number of substitution values are provided. Another
example:

        $report = form
                'Name           Rank    Serial Number',
                '====           ====    =============',
                '<<<<<<<<<<<<<  ^^^^    <<<<<<<<<<<<<',
                 $name,         $rank,  $serial_number,
                ''
                'Age    Sex     Description',
                '===    ===     ===========',
                '^^^    ^^^     [[[[[[[[[[[',
                 $age,  $sex,   $description;


=head2 How C<form> consumes strings

Unlike C<format>, within C<form> non-block fields I<do> consume the text
they format, so the following:

        $text = "a line of text to be formatted over three lines";
        print form "<<<<<<<<<<\n  <<<<<<<<\n    <<<<<<\n",
                    $text,        $text,        $text;

produces:

        a line of
          text to
            be fo-

not:

        a line of
          a line 
            a line

To achieve the latter effect, convert the variable arguments
to independent literals (by double-quoted interpolation):

        $text = "a line of text to be formatted over three lines";
        print form "<<<<<<<<<<\n  <<<<<<<<\n    <<<<<<\n",
                   "$text",      "$text",      "$text";

Although values passed from variable arguments are progressively consumed
I<within> C<form>, the values of the original variables passed to C<form>
are I<not> altered.  Hence:

        $text = "a line of text to be formatted over three lines";
        print form "<<<<<<<<<<\n  <<<<<<<<\n    <<<<<<\n",
                    $text,        $text,        $text;
        print $text, "\n";

will print:

        a line of
          text to
            be fo-
        a line of text to be formatted over three lines

To cause C<form> to consume the values of the original variables passed to
it, pass them as references. Thus:

        $text = "a line of text to be formatted over three lines";
        print form "<<<<<<<<<<\n  <<<<<<<<\n    <<<<<<\n",
                    \$text,       \$text,       \$text;
        print $text, "\n";

will print:

        a line of
          text to
            be fo-
        rmatted over three lines

Note that, for safety, the "non-consuming" behaviour takes precedence,
so if a variable is passed to C<form> both by reference I<and> by value,
its final value will be unchanged.

=head2 Numerical formatting

The ">>>.<<<" and "]]].[[[" field specifiers may be used to format
numeric values about a fixed decimal place marker. For example:

        print form '(]]]]].[[)', <<EONUMS;
                   1
                   1.0
                   1.001
                   1.009
                   123.456
                   1234567
                   one two
        EONUMS

would print:
                   
        (    1.0 )
        (    1.0 )
        (    1.00)
        (    1.01)
        (  123.46)
        (#####.##)
        (?????.??)
        (?????.??)

Fractions are rounded to the specified number of places after the
decimal, but only significant digits are shown. That's why, in the
above example, 1 and 1.0 are formatted as "1.0", whilst 1.001 is
formatted as "1.00".

You can specify that the maximal number of decimal places always be used
by giving the configuration option 'numeric' a value that matches
/\bAllPlaces\b/i. For example:

        print form { numeric => AllPlaces },
                   '(]]]]].[[)', <<'EONUMS';
                   1
                   1.0
        EONUMS

would print:
                   
        (    1.00)
        (    1.00)

Note that although decimal digits are rounded to fit the specified width, the
integral part of a number is never modified. If there are not enough places
before the decimal place to represent the number, the entire number is 
replaced with hashes.

If a non-numeric sequence is passed as data for a numeric field, it is
formatted as a series of question marks. This querulous behaviour can be
changed by giving the configuration option 'numeric' a value that
matches /\bSkipNaN\b/i in which case, any invalid numeric data is simply
ignored. For example:


        print form { numeric => 'SkipNaN' }
                   '(]]]]].[[)',
                   <<EONUMS;
                   1
                   two three
                   4
        EONUMS

would print:
                   
        (    1.0 )
        (    4.0 )


=head2 Filling block fields with lists of values

If an argument corresponding to a field is an array reference, then C<form>
automatically joins the elements of the array into a single string, separating
each element with a newline character. As a result, a call like this:

        @values = qw( 1 10 100 1000 );
        print form "(]]]].[[)", \@values;

will print out

         (   1.00)
         (  10.00)
         ( 100.00)
         (1000.00)

as might be expected.

Note however that arrays must be passed by reference (so that C<form>
knows that the entire array holds data for a single field). If the previous
example had not passed @values by reference:

        @values = qw( 1 10 100 1000 );
        print form "(]]]].[[)", @values;

the output would have been:

         (   1.00)
         10
         100
         1000

This is because @values would have been interpolated into C<form>'s
argument list, so only $value[0] would have been used as the data for
the initial format string. The remaining elements of @value would have
been treated as separate format strings, and printed out "verbatim".

Note too that, because arrays must be passed using a reference, their
original contents are consumed by C<form>, just like the contents of
scalars passed by reference.

To avoid having an array consumed by C<form>, pass it as an anonymous
array:

        print form "(]]]].[[)", [@values];


=head2 Headers, footers, and pages

The C<form> subroutine can also insert headers, footers, and page-feeds
as it formats. These features are controlled by the "header", "footer",
"pagefeed", "pagelen", and "pagenum" options.

The "pagenum" option takes a scalar value or a reference to a scalar
variable and starts page numbering at that value. If a reference to a
scalar variable is specified, the value of that variable is updated as
the formatting proceeds, so that the final page number is available in
it after formatting. This can be useful for multi-part reports.

The "pagelen" option specifies the total number of lines in a page (including
headers, footers, and page-feeds).

The "pagewidth" option specifies the total number of columns in a page.

If the "header" option is specified with a string value, that string is
used as the header of every page generated. If it is specified as a reference
to a subroutine, that subroutine is called at the start of every page and
its return value used as the header string. When called, the subroutine is
passed the current page number.

Likewise, if the "footer" option is specified with a string value, that
string is used as the footer of every page generated. If it is specified
as a reference to a subroutine, that subroutine is called at the I<start>
of every page and its return value used as the footer string. When called,
the footer subroutine is passed the current page number.

Both the header and footer options can also be specified as hash references.
In this case the hash entries for keys "left", "centre" (or "center"), and
"right" specify what is to appear on the left, centre, and right of the
header/footer. The entry for the key "width" specifies how wide the
footer is to be. If the "width" key is omitted, the "pagewidth" configuration
option (which defaults to 72 characters) is used.

The  "left", "centre", and "right" values may be literal
strings, or subroutines (just as a normal header/footer specification may
be.) See the second example, below.

Another alternative for header and footer options is to specify them as a
subroutine that returns a hash reference. The subroutine is called for each
page, then the resulting hash is treated like the hashes described in the
preceding paragraph. See the third example, below.

The "pagefeed" option acts in exactly the same way, to produce a
pagefeed which is appended after the footer. But note that the pagefeed
is not counted as part of the page length.

All three of these page components are recomputed at the start of each
new page, before the page contents are formatted (recomputing the header
and footer first makes it possible to determine how many lines of data to
format so as to adhere to the specified page length).

When the call to C<form> is complete and the data has been fully formatted,
the footer subroutine is called one last time, with an extra argument of 1.
The string returned by this final call is used as the final footer.

So for example, a 60-line per page report, starting at page 7,
with appropriate headers and footers might be set up like so:

        $page = 7;

        form { header => sub { "Page $_[0]\n\n" },
               footer => sub { my ($pagenum, $lastpage) = @_;
                               return "" if $lastpage;
                               return "-"x50 . "\n"
                                             .form ">"x50, "...".($pagenum+1);
                              },
               pagefeed => "\n\n",
               pagelen  => 60
               pagenum => \$page,
             },
             $template,
             @data;

Note the recursive use of C<form> within the "footer" option!

Alternatively, to set up headers and footers such that the running
head is right justified in the header and the page number is centred
in the footer:

        form { header => { right => "Running head" },
               footer => { centre => sub { "Page $_[0]" } },
               pagelen  => 60
             },
             $template,
             @data;

The footer in the previous example could also have been specified the other
way around, as a subroutine that returns a hash (rather than a hash containing
a subroutine):

        form { header => { right => "Running head" },
               footer => sub { return {centre => "Page $_[0]"} },
               pagelen  => 60
             },
             $template,
             @data;


=head2 The C<cols> option

Sometimes data to be used in a C<form> call needs to be extracted from a
nested data structure. For example, whilst it's easy to print a table if
you already have the data in columns:

        @name  = qw(Tom Dick Harry);
        @score = qw( 88   54    99);
        @time  = qw( 15   13    18);

        print form
        '-------------------------------',
        'Name             Score     Time',
        '-------------------------------',
        '[[[[[[[[[[[[[[   |||||     ||||',
         \@name,          \@score,  \@time;


if the data is aggregrated by rows:

        @data = (
            { name=>'Tom',   score=>88, time=>15 },
            { name=>'Dick',  score=>54, time=>13 },
            { name=>'Harry', score=>99, time=>18 },
        );

you need to do some fancy mapping before it can be fed to C<form>:

        print form
        '-------------------------------',
        'Name             Score     Time',
        '-------------------------------',
        '[[[[[[[[[[[[[[   |||||     ||||',
        [map $$_{name},  @data],
        [map $$_{score}, @data],
        [map $$_{time} , @data];

Or you could just use the C<'cols'> option:

        use Text::Reform qw(form columns);

        print form
        '-------------------------------',
        'Name             Score     Time',
        '-------------------------------',
        '[[[[[[[[[[[[[[   |||||     ||||',
        { cols => [qw(name score time)],
          from => \@data
        };

This option takes an array of strings that specifies the keys of the
hash entries to be extracted into columns. The C<'from'> entry (which
must be present) also takes an array, which is expected to contain a
list of references to hashes. For each key specified, this option
inserts into C<form>'s argument list a reference to an array containing
the entries for that key, extracted from each of the hash references
supplied by C<'from'>. So, for example, the option:

        { cols => [qw(name score time)],
          from => \@data
        }

is replaced by three array references, the first containing the C<'name'>
entries for each hash inside C<@data>, the second containing the
C<'score'> entries for each hash inside C<@data>, and the third
containing the C<'time'> entries for each hash inside C<@data>.

If, instead, you have a list of arrays containing the data:

        @data = (
                # Time  Name     Score
                [ 15,   'Tom',   88 ],
                [ 13,   'Dick',  54 ],
                [ 18,   'Harry', 99 ],
        );

the C<'cols'> option can extract the appropriate columns for that too. You
just specify the required indices, rather than keys:

        print form
        '-----------------------------',   
        'Name             Score   Time',   
        '-----------------------------',   
        '[[[[[[[[[[[[[[   |||||   ||||',
        { cols => [1,2,0],
          from => \@data
        }

Note that the indices can be in any order, and the resulting arrays are
returned in the same order.

If you need to merge columns extracted from two hierarchical 
data structures, just concatenate the data structures first,
like so:

        print form
        '---------------------------------------',   
        'Name             Score   Time   Ranking
        '---------------------------------------',   
        '[[[[[[[[[[[[[[   |||||   ||||   |||||||',
        { cols => [1,2,0],
          from => [@data, @olddata],
        }

Of course, this only works if the columns are in the same positions in
both data sets (and both datasets are stored in arrays) or if the
columns have the same keys (and both datasets are in hashes). If not,
you would need to format each dataset separately, like so:

        print form
        '-----------------------------',   
        'Name             Score   Time'
        '-----------------------------',   
        '[[[[[[[[[[[[[[   |||||   ||||',
        { cols=>[1,2,0],  from=>\@data },
        '[[[[[[[[[[[[[[   |||||   ||||',
        { cols=>[3,8,1],  from=>\@olddata },
        '[[[[[[[[[[[[[[   |||||   ||||',
        { cols=>[qw(name score time)],  from=>\@otherdata };


=head2 The C<tag> sub

The C<tag> subroutine may be exported from the module.
It takes two arguments: a tag specifier and a text to be
entagged. The tag specifier indicates the indenting of the tag, and of the
text. The sub generates an end-tag (using the usual "/I<tag>" variant),
unless an explicit end-tag is provided as the third argument.

The tag specifier consists of the following components (in order):

=over 4

=item An optional vertical spacer (zero or more whitespace-separated newlines)

One or more whitespace characters up to a final mandatory newline. This
vertical space is inserted before the tag and after the end-tag

=item An optional tag indent

Zero or more whitespace characters. Both the tag and the end-tag are indented
by this whitespace.

=item An optional left (opening) tag delimiter

Zero or more non-"word" characters (not alphanumeric or '_').
If the opening delimiter is omitted, the character '<' is used.

=item A tag

One or more "word" characters (alphanumeric or '_').

=item Optional tag arguments

Any number of any characters

=item An optional right (closing) tag delimiter

Zero or more non-"word" characters which balance some sequential portion
of the opening tag delimiter. For example, if the opening delimiter
is "<-(" then any of the following are acceptible closing delimiters:
")->", "->", or ">".
If the closing delimiter is omitted, the "inverse" of the opening delimiter 
is used (for example, ")->"),

=item An optional vertical spacer (zero or more newlines)

One or more whitespace characters up to a mandatory newline. This
vertical space is inserted before and after the complete text.

=item An optional text indent

Zero or more space of tab characters. Each line of text is indented
by this whitespace (in addition to the tag indent).


=back

For example:

        $text = "three lines\nof tagged\ntext";

        print tag "A HREF=#nextsection", $text;

prints:

        <A HREF=#nextsection>three lines
        of tagged
        text</A>

whereas:

        print tag "[-:GRIN>>>\n", $text;

prints:

        [-:GRIN>>>:-]
        three lines
        of tagged
        text
        [-:/GRIN>>>:-]

and:

        print tag "\n\n   <BOLD>\n\n   ", $text, "<END BOLD>";

prints:

S< >

           <BOLD>

              three lines
              of tagged
              text

           <END BOLD>

S< >

(with the indicated spacing fore and aft).

=head1 AUTHOR

Damian Conway (damian@conway.org)

=head1 BUGS

There are undoubtedly serious bugs lurking somewhere in code this funky :-)
Bug reports and other feedback are most welcome.

=head1 COPYRIGHT

Copyright (c) 1997-2000, Damian Conway. All Rights Reserved.
This module is free software. It may be used, redistributed
and/or modified under the terms of the Perl Artistic License
  (see http://www.perl.com/perl/misc/Artistic.html)
