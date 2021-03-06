package MusicBrainz::Server::ControllerBase::WS::2;
use Moose;
BEGIN { extends 'Catalyst::Controller'; }

use DBDefs;
use MusicBrainz::Server::WebService::XMLSearch qw( xml_search );
use MusicBrainz::Server::Data::Utils qw( type_to_model );
use MusicBrainz::Server::Data::Utils qw( object_to_ids );
use Readonly;

Readonly my %serializers => (
    xml => 'MusicBrainz::Server::WebService::XMLSerializer',
);

with 'MusicBrainz::Server::Controller::Role::Profile' => {
    threshold => DBDefs::PROFILE_WEB_SERVICE()
};

# This defines what options are acceptable for WS calls.
# Note that the validator will automatically add inc= arguments to the allowed list
# based on other inc= arguments.  (puids are allowed if recordings are allowed, etc..)

sub bad_req : Private
{
    my ($self, $c) = @_;
    $c->res->status(400);
    $c->res->content_type("application/xml; charset=UTF-8");
    $c->res->body($c->stash->{serializer}->output_error($c->stash->{error}));
}

sub success : Private
{
    my ($self, $c) = @_;
    $c->res->content_type("application/xml; charset=UTF-8");
    $c->res->body($c->stash->{serializer}->output_success);
}

sub unauthorized : Private
{
    my ($self, $c) = @_;
    $c->res->status(401);
    $c->res->content_type("application/xml; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error("Your credentials ".
        "could not be verified.\nEither you supplied the wrong credentials ".
        "(e.g., bad password), or your client doesn't understand how to ".
        "supply the credentials required."));
}

sub not_found : Private
{
    my ($self, $c) = @_;
    $c->res->status(404);
    $c->res->content_type("application/xml; charset=utf-8");
    $c->res->body($c->stash->{serializer}->output_error("Not Found"));
}

sub invalid_mbid : Private
{
    my ($self, $c, $id) = @_;
    $c->stash->{error} = "Invalid mbid.";
    $c->detach('bad_req');
}

sub begin : Private { }
sub end : Private { }

sub root : Chained('/') PathPart("ws/2") CaptureArgs(0)
{
    my ($self, $c) = @_;

    $self->validate($c, \%serializers) or $c->detach('bad_req');

    $c->authenticate({}, 'musicbrainz.org') if ($c->stash->{authorization_required});
}

sub _error
{
    my ($self, $c, $error) = @_;

    $c->stash->{error} = $error;
    $c->detach('bad_req');
}

sub _search
{
    my ($self, $c, $entity) = @_;

    my $result = xml_search($entity, $c->stash->{args});
    $c->res->content_type($c->stash->{serializer}->mime_type . '; charset=utf-8');
    if (exists $result->{xml})
    {
        $c->res->body($result->{xml});
    }
    else
    {
        $c->res->status($result->{code});
        $c->res->body($c->stash->{serializer}->output_error($result->{error}));
    }
}

sub _tags_and_ratings
{
    my ($self, $c, $modelname, $entities, $stash) = @_;

    my %map = object_to_ids (@$entities);
    my $model = $c->model($modelname);

    if ($c->stash->{inc}->tags)
    {
        my @tags = $model->tags->find_tags_for_entities (map { $_->id } @$entities);

        for (@tags)
        {
            my $opts = $stash->store ($map{$_->entity_id}->[0]);

            $opts->{tags} = [] unless $opts->{tags};
            push @{ $opts->{tags} }, $_;
        }
    }

    if ($c->stash->{inc}->user_tags)
    {
        my @tags = $model->tags->find_user_tags_for_entities (
            $c->user->id, map { $_->id } @$entities);

        for (@tags)
        {
            my $opts = $stash->store ($map{$_->entity_id}->[0]);

            $opts->{user_tags} = [] unless $opts->{user_tags};
            push @{ $opts->{user_tags} }, $_;
        }
    }

    if ($c->stash->{inc}->ratings)
    {
        $model->load_meta(@$entities);

        for (@$entities)
        {
            if ($_->rating_count)
            {
                $stash->store ($_)->{ratings} = {
                    rating => $_->rating * 5 / 100,
                    count => $_->rating_count,
                };
            }
        }
    }

    if ($c->stash->{inc}->user_ratings)
    {
        $model->rating->load_user_ratings($c->user->id, @$entities);
        for (@$entities)
        {
            $stash->store ($_)->{user_ratings} = $_->user_rating * 5 / 100
                if $_->user_rating;
        }
    }
}

sub _limit_and_offset
{
    my ($self, $c) = @_;

    my $args = $c->stash->{args};
    my $limit = $args->{limit} ? $args->{limit} : 25;
    my $offset = $args->{offset} ? $args->{offset} : 0;

    return ($limit > 100 ? 100 : $limit, $offset);
}

sub make_list
{
    my ($self, $results, $total, $offset) = @_;

    return {
        items => $results,
        total => defined $total ? $total : scalar @$results,
        offset => defined $offset ? $offset : 0
    };
}

sub linked_artists
{
    my ($self, $c, $stash, $artists) = @_;

    $self->_tags_and_ratings($c, 'Artist', $artists, $stash);

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Artist')->alias->find_by_entity_id(map { $_->id } @$artists) };

        my %alias_per_artist;
        foreach (@aliases)
        {
            $alias_per_artist{$_->artist_id} = [] unless $alias_per_artist{$_->artist_id};
            push @{ $alias_per_artist{$_->artist_id} }, $_;
        }

        foreach (@$artists)
        {
            $stash->store ($_)->{aliases} = $alias_per_artist{$_->id};
        }
    }
}

sub linked_lists
{
    my ($self, $c, $stash, $lists) = @_;
}

sub linked_labels
{
    my ($self, $c, $stash, $labels) = @_;

    $self->_tags_and_ratings($c, 'Label', $labels, $stash);

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Label')->alias->find_by_entity_id(map { $_->id } @$labels) };

        my %alias_per_label;
        foreach (@aliases)
        {
            $alias_per_label{$_->label_id} = [] unless $alias_per_label{$_->label_id};
            push @{ $alias_per_label{$_->label_id} }, $_;
        }

        foreach (@$labels)
        {
            $stash->store ($_)->{aliases} = $alias_per_label{$_->id};
        }
    }
}

sub linked_recordings
{
    my ($self, $c, $stash, $recordings) = @_;

    if ($c->stash->{inc}->isrcs)
    {
        my @isrcs = $c->model('ISRC')->find_by_recording(map { $_->id } @$recordings);

        my %isrc_per_recording;
        for (@isrcs)
        {
            $isrc_per_recording{$_->recording_id} = [] unless $isrc_per_recording{$_->recording_id};
            push @{ $isrc_per_recording{$_->recording_id} }, $_;
        };

        for (@$recordings)
        {
            $stash->store ($_)->{isrcs} = $isrc_per_recording{$_->id};
        }
    }

    if ($c->stash->{inc}->puids)
    {
        my @puids = $c->model('RecordingPUID')->find_by_recording(map { $_->id } @$recordings);

        my %puid_per_recording;
        for (@puids)
        {
            $puid_per_recording{$_->recording_id} = [] unless $puid_per_recording{$_->recording_id};
            push @{ $puid_per_recording{$_->recording_id} }, $_;
        };

        for (@$recordings)
        {
            $stash->store ($_)->{puids} = $puid_per_recording{$_->id};
        }
    }

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$recordings);
    }

    $self->_tags_and_ratings($c, 'Recording', $recordings, $stash);
}

sub linked_releases
{
    my ($self, $c, $stash, $releases) = @_;

    $c->model('ReleaseStatus')->load(@$releases);
    $c->model('ReleasePackaging')->load(@$releases);

    $c->model('Language')->load(@$releases);
    $c->model('Script')->load(@$releases);
    $c->model('Country')->load(@$releases);

    my @mediums;
    if ($c->stash->{inc}->media)
    {
        @mediums = map { $_->all_mediums } @$releases;

        unless (@mediums)
        {
            $c->model('Medium')->load_for_releases(@$releases);
            @mediums = map { $_->all_mediums } @$releases;
        }

        $c->model('MediumFormat')->load(@mediums);
    }

    if ($c->stash->{inc}->discids)
    {
        my @medium_cdtocs = $c->model('MediumCDTOC')->load_for_mediums(@mediums);
        $c->model('CDTOC')->load(@medium_cdtocs);
    }

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$releases);
    }
}

sub linked_release_groups
{
    my ($self, $c, $stash, $release_groups) = @_;

    $c->model('ReleaseGroupType')->load(@$release_groups);

    if ($c->stash->{inc}->artist_credits)
    {
        $c->model('ArtistCredit')->load(@$release_groups);
    }

    $self->_tags_and_ratings($c, 'ReleaseGroup', $release_groups, $stash);
}

sub linked_works
{
    my ($self, $c, $stash, $works) = @_;

    if ($c->stash->{inc}->aliases)
    {
        my @aliases = @{ $c->model('Work')->alias->find_by_entity_id(map { $_->id } @$works) };

        my %alias_per_work;
        foreach (@aliases)
        {
            $alias_per_work{$_->work_id} = [] unless $alias_per_work{$_->work_id};
            push @{ $alias_per_work{$_->work_id} }, $_;
        }

        foreach (@$works)
        {
            $stash->store ($_)->{aliases} = $alias_per_work{$_->id};
        }
    }

    $self->_tags_and_ratings($c, 'Work', $works, $stash);
}

sub _validate_post
{
    my ($self, $c) = @_;

    my $h = $c->request->headers;

    unless ($h->content_type eq 'application/xml' &&
            $h->content_type_charset eq 'UTF-8') {
        $c->stash->{error} = '/ws/2/ only supports POST in application/xml; charset=UTF-8';
        $c->forward('bad_req');
        $c->res->status(415);
        $c->detach;
    }

    $self->_error ($c, "Please specify the name and version number of your client application.")
        unless $c->req->params->{client};
}

sub _validate_entity
{
    my ($self, $c) = @_;

    my $gid = $c->stash->{args}->{id};
    my $entity = $c->stash->{args}->{entity};
    $entity =~ s/-/_/;

    my $model = type_to_model ($entity);

    if (!$gid || !MusicBrainz::Server::Validation::IsGUID($gid))
    {
        $c->stash->{error} = "Invalid mbid.";
        $c->detach('bad_req');
    }

    if (!$model)
    {
        $c->stash->{error} = "Invalid entity type.";
        $c->detach('bad_req');
    }

    $entity = $c->model($model)->get_by_gid($gid);
    $c->detach('not_found') unless ($entity);

    return ($entity, $model);
}

no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation
Copyright (C) 2009 Lukas Lalinsky
Copyright (C) 2009 Robert Kaye

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
