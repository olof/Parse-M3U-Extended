package Parse::M3U::Extended;
use warnings;
use strict;
use Regexp::Grammars;

our $VERSION = 0.1;

require Exporter;
our @ISA = 'Exporter';
our @EXPORT_OK = qw(m3u_parser $m3u_parser);

=head1 NAME

Parse::M3U::Extended - a simple Regexp::Grammars based M3UE parser

=head1 SYNOPSIS
 
 use LWP::Simple;
 use Parse::M3U::Extended qw(m3u_parser);

 my $m3u = get("http://example.com/foo.m3u");
 my @items = m3u_parser($m3u);

=head1 DESCRIPTION

This module contains a simple parser for the Extended M3U format
as used in e.g. HTTP Live Streaming. It also supports the regular
M3U format, usually found with digital copies of music albums etc.

=cut

my $m3u_parser = qr{
	<[Line]>+

	##############
	<nocontext:>

	<token: Line>
		(?: <Item> | <Directive> | <Comment> ) \n

	<token: Directive>
		<Tag> (?: : (<Value>))?

	<token: Tag>
		\# <MATCH= (EXT[^:\n]+)>

	<token: Item>
		[^\#\n] [^\n]*

	<token: Comment>
		\# <MATCH= ([^\n]+)>

	<token: Value>
		[^\n]+
}xm;

=head1 SUBROUTINES

=head2 m3u_parser

Takes a m3u playlist as a string and returns a list, with each
element is a hashref with the keys type and value. If the
playlist's first line is "#EXTM3U\n", then the elements in the
returned list can have type "directive", which has a "tag" key
and the value key is optional.

 {
   type => 'comment',
   value => 'a comment',
 }

 {
   type => 'item',
   value => 'http://example.com/foo.mp3',
 }

 {
   type => 'directive',
   tag => 'EXTM3U',
 }

 {
   type => 'directive',
   tag => 'EXT-X-ALLOW-CACHE',
   value => 'YES',
 }

Internally, it's using Regexp::Grammars, and the returned result
hash is then flattned. If you want to work with the result hash,
you can use $Parse::M3U::Extended::parser directly, but
documenting its structure is outside the scope of this manual.
Please refer to L<Regexp::Grammars>.

If the playlist supplied does not match an M3U file, undef is
returned.

=cut

sub m3u_parser {
	my $playlist = shift;

	if ($playlist =~ /$m3u_parser/) {
		return __analyze(\%/);
	}
}

# The analyze subroutine are used to flatten the structured returned
# from Regexp::Grammars. If you want the full tree, you can use 
# $Parse::M3U::Extended::parser directly.
sub __analyze {
	my $res = shift;
	my $ext = 0;
	my @ret;

	# If the first line is #EXTM3U, then it's an M3UE
	if (exists $res->{Line}->[0]->{Directive} and
	    $res->{Line}->[0]->{Directive}->{Tag} eq 'EXTM3U') {
	    	$ext = 1;
	}

	for my $line (@{$res->{Line}}) {
		if (exists $line->{Directive} and !$ext) {
			my $dir = $line->{Directive};

			push @ret, {
				type => 'comment',
				value => "$dir->{Tag}:$dir->{Value}",
			};
		} elsif (exists $line->{Directive}) {
			my $dir = $line->{Directive};

			push @ret, {
				type => 'directive',
				tag => $dir->{Tag},
				exists $dir->{Value} ?
					(value => $dir->{Value}) :
					()
			};
		} elsif (exists $line->{Comment}) {
			push @ret, {
				type => 'comment',
				value => $line->{Comment}
			};
		} else {
			push @ret, {
				type => 'item',
				value => $line->{Item}
			};
		}
	}

	return @ret;
}

=head1 SEE ALSO

=over

=item * IETF Internet Draft: draft-pantos-http-live-streaming-08

=item * L<Regexp::Grammars>

=back

=head1 COPYRIGHT

Copyright (c) 2012 - Olof Johansson <olof@cpan.org>
All rights reserved.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

=cut

1;
