#!/usr/bin/perl -w

use strict;
use IO::Socket;
use scigen;

my $sock = IO::Socket::INET->new( PeerAddr => "localhost", 
				  PeerPort => $scigen::SCIGEND_PORT,
				  Proto => 'tcp' );

if( defined $sock ) {
    $sock->autoflush;
    $sock->print( "SYSTEM_NAME\n" );

    while( <$sock> ) { 
	print $_; 
    }
    $sock->close();
    undef $sock;

} else {
    print STDERR "socket didn't work\n";
}

#print "$scigen::SCIGEND_PORT\n";
