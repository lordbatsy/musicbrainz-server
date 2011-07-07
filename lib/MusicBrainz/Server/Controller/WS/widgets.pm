package MusicBrainz::Server::Controller::WS::widgets;

use Moose;
BEGIN { extends 'MusicBrainz::Server::Controller'; }
use Data::OptList;
use MusicBrainz::Server::Data::Artist;
use MusicBrainz::Server::Data::Release;
use MusicBrainz::Server::WebService::JSONSerializer;
use MusicBrainz::Server::WebService::Validator;
use Readonly;

my $ws_defs = Data::OptList::mkopt([
    "artistwidget" => {
        method => 'GET',
    },
    "releasewidget" => {
        method => 'GET',
    }
]);

with 'MusicBrainz::Server::WebService::Validator' =>
{
     defs => $ws_defs,
     version => 'widgets',
     default_serialization_type => 'json',
};

Readonly my %serializers => (
    json => 'MusicBrainz::Server::WebService::JSONSerializer',
);

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
    $self->validate($c, \%serializers) or $c->detach('bad_req');
}

# Release widget

sub releasewidget : Chained('root') PathPart('releasewidget') Args(0) {
    my ($self, $c) = @_;
    my $releasewidget = { mbid => "", name => "", artistcredit => [], date =>"", mediums => []};
   
    my $mbid = "eefc59f9-9381-4ea3-a256-878aa83d378e";

    my $release_model = $c->model('Release')->get_by_gid($mbid);
    $c->model('Release')->load_meta($release_model);

    $releasewidget->{name} = $release_model->name;
    $releasewidget->{mbid} = $release_model->gid;
    $releasewidget->{date} = $release_model->date->format();
    $c->model('ArtistCredit')->load($release_model);

        foreach my $artist (@{$release_model->artist_credit->names}) {

            my $this_artist = { mbid => "", link_phrase => "", join_phrase => "" };

            $this_artist->{mbid} = $artist->{artist}->{gid};
            $this_artist->{link_phrase} = $artist->{name};
            $this_artist->{join_phrase} = $artist->{join_phrase};

            push(@{$releasewidget->{artistcredit}}, $this_artist);
        }

    $c->model('Medium')->load_for_releases($release_model);
    $c->model('Tracklist')->load($release_model);
    my @tracklists = grep { defined } map { $_->tracklist } $release_model->all_mediums;
    $c->model('Track')->load_for_tracklists(@tracklists);
    $c->model('ArtistCredit')->load(map { $_->all_tracks } @tracklists);

        foreach my $medium($release_model->all_mediums) {

            my $this_medium = { name => "", position => "", tracklist => [] };

            $this_medium->{name} = $medium->{name}; 
            $this_medium->{position} = $medium->{position};

            foreach my $track (@{$medium->tracklist->tracks}) {

                my $this_track = { position => "", name => "", artistcredit => []};

                $this_track->{position} = $track->{position};
                $this_track->{name} = $track->{name};
   
                foreach my $artist (@{$track->artist_credit->names}) {

                    my $this_artist = { mbid => "", link_phrase => "", join_phrase => "" };

                    $this_artist->{mbid} = $artist->{artist}->{gid};
                    $this_artist->{link_phrase} = $artist->{name};
                    $this_artist->{join_phrase} = $artist->{join_phrase};

                    push(@{$this_track->{artistcredit}}, $this_artist);
                }

                push(@{$this_medium->{tracklist}}, $this_track);
            }

            push(@{$releasewidget->{mediums}}, $this_medium);

        }

    $c->res->content_type('text/javascript; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('generic', $releasewidget));

};


# Artist widget

sub artistwidget : Chained('root') PathPart('artistwidget') Args(0) {
    my ($self, $c) = @_;
    my $artistwidget = { mbid => "", name => "", releasegroups => []};
   
    my $mbid = "39c6af62-6918-4d1d-9666-1fc78149ea67";

    my $artist_model = $c->model('Artist')->get_by_gid($mbid);
    my @releases_nonvarious = $c->model('ReleaseGroup')->find_by_artist(
                $artist_model->id, 3, 0, undef, 'DESC'
    );

    my @releases_various = $c->model('ReleaseGroup')->find_by_track_artist(
                $artist_model->id, 3, 0, 'DESC'
    );

   @releases_various = @{ $releases_various[0] };
   @releases_nonvarious =@{ $releases_nonvarious[0] };

    $artistwidget->{name} = $artist_model->name;
    $artistwidget->{mbid} = $artist_model->gid;

    my @releases = ();

    while(scalar (@releases) < 3) {

        if (scalar (@releases_various) != 0 && (scalar (@releases_nonvarious) == 0 || $releases_various[0]->{date} > $releases_nonvarious[0]->{date})) {
            push(@releases, shift @releases_various)
        }
        elsif (scalar (@releases_nonvarious) != 0) {
            push(@releases, shift @releases_nonvarious)
        }
        else {
        last;
        }
    }

        foreach my $release (@releases) {

            my $this_release = { mbid => "", title => "", date => "" };

            $this_release->{mbid} = $release->gid;
            $this_release->{title} = $release->name;
            $this_release->{date} = $release->first_release_date->format();

            push(@{$artistwidget->{releasegroups}}, $this_release);
        }

    $c->res->content_type('text/javascript; charset=utf-8');
    $c->res->body($c->stash->{serializer}->serialize('generic', $artistwidget));

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
