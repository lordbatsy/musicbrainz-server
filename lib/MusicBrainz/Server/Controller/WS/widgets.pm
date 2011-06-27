package MusicBrainz::Server::Controller::WS::widgets;

use Moose;
BEGIN { extends 'MusicBrainz::Server::Controller'; }
use MusicBrainz::Server::Data::Artist;
use MusicBrainz::Server::Data::Release;

sub bad_req : Private
{
    my ($self, $c) = @_;
    $c->res->status(400);
    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    $c->res->body($c->stash->{serializer}->output_error($c->stash->{error}));
}

sub begin : Private
{
}

sub end : Private
{
}

sub root : Chained('/') PathPart("ws/widgets") CaptureArgs(0)
{
    my ($self, $c) = @_;
}

# Release widget

sub releasewidget : Chained('root') PathPart('releasewidget') Args(0) {
    my ($self, $c) = @_;

    $c->res->content_type('text/javascript; charset=utf-8');
    $c->res->body(<<'RELEASE');
var releasewidget = '{\
\
	"mbid": "eefc59f9-9381-4ea3-a256-878aa83d378e",\
	"title": "Pokémon Christmas Bash",\
	"artist-credit": [{\
		"mbid": "89ad4ac3-39f7-470e-963a-56509c546377",\
		"link-phrase": "Various Artists"\
		}],\
	"date": "2001-10",\
	"tracklist": [[\
			{\
			"mbid": "3445bbcf-a505-4a89-94ba-17ed72618797",\
			"title": "Pokémon Christmas Bash",\
			"artist-credit": [{\
				"mbid": "9b012d6a-3fcb-4ed0-b81a-2e192c0c8df1",\
				"link-phrase": "Veronica Taylor",\
				"join-phrase": ", "\
				},\
				{\
				"mbid": "39c6af62-6918-4d1d-9666-1fc78149ea67",\
				"link-phrase": "Eric Stuart",\
				"join-phrase": ", "\
				},\
				{\
				"mbid": "94449da0-cd38-425c-ad05-cf526c296a49",\
				"link-phrase": "Rachael Lillis",\
				"join-phrase": " & "\
				},\
				{\
				"mbid": "cc8764e8-486d-4e44-818f-e9b66edb3f88",\
				"link-phrase": "Maddie Blaustein"\
				}]\
			},\
			{\
			"mbid": "5360160a-83b2-4085-b0a1-094536c02d03",\
			"title": "I\'m Giving Santa a Pikachu for Christmas",\
			"artist-credit": [{\
				"mbid": "9b012d6a-3fcb-4ed0-b81a-2e192c0c8df1",\
				"link-phrase": "Veronica Taylor",\
				"join-phrase": " & "\
				},\
				{\
				"mbid": "507e2de5-0ba4-4f58-9c11-73a1332da069",\
				"link-phrase": "Stan Hart"\
				}]\
			}\
		]],\
	"cover-art": "http://ec1.images-amazon.com/images/P/B00005NF1V.01.LZZZZZZZ.jpg"  \
\
}';
RELEASE

};


# Artist widget

sub artistwidget : Chained('root') PathPart('artistwidget') Args(0) {
    my ($self, $c) = @_;
    my $mbid = "39c6af62-6918-4d1d-9666-1fc78149ea67";

    my $artist_model = $c->model('Artist')->get_by_gid($mbid);
    my @releases_nonvarious = $c->model('Release')->find_by_artist(
                $artist_model->id, 3, 0, (), ()
    );

    my @releases_various = $c->model('Release')->find_for_various_artists(
                $artist_model->id, 3, 0, (), ()
    );

   @releases_various = $releases_various[0];
   @releases_nonvarious = $releases_nonvarious[0];

    my $artist_name = $artist_model->name;
    my $artist_gid = $artist_model->gid;
    my $release_block = "";
    my @releases = ();

#    while(scalar (@releases) < 3) {
#
#        if (scalar (@releases_various) != 0 && (scalar (@releases_nonvarious) == 0 || $releases_various[0]->{date} > $releases_nonvarious[0]->{date})) {
#            push(@releases, shift @releases_various)
#        }
#        elsif (scalar (@releases_nonvarious) != 0) {
#            push(@releases, shift @releases_nonvarious)
#        }
#        else {
#        last;
#        }
#    }

        foreach my $release (@releases_nonvarious) {
            
        }

    $c->res->content_type('text/javascript; charset=utf-8');
    $c->res->body(<<"ARTIST");
var artistwidget = '{\
	"mbid": "$artist_gid",\
	"name": "$artist_name",\

	"releases": [{\
		"mbid": "@releases_various[0]",\
		"title": "Yu-Gi-Oh! Music to Duel By",\
		"date": "2002-10-29"\
		},\

		{\
		"mbid": "eefc59f9-9381-4ea3-a256-878aa83d378e",\
		"title": "Pokémon Christmas Bash",\
		"date": "2001-10"\
		},\
		{\
		"mbid": "f3ed789e-c571-469e-a2c5-abe3c19fbb6c",\
		"title": "Pokémon 3: The Ultimate Soundtrack",\
		"date": "2001-04-03"\
		}\
		]\
}';
ARTIST

};



sub default : Path
{
    my ($self, $c, $resource) = @_;

    $c->stash->{error} = "Invalid resource: $resource";
    $c->detach('bad_req');
}

no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
