package t::MusicBrainz::Server::Edit::Medium::MoveDiscID;
use Test::Routine;
use Test::More;
use Test::Fatal;

with 't::Context';

use MusicBrainz::Server::Constants qw( $EDIT_MEDIUM_MOVE_DISCID );
use MusicBrainz::Server::Test qw( accept_edit reject_edit );

BEGIN { use MusicBrainz::Server::Edit::Medium::MoveDiscID }

test all => sub {

my $test = shift;
my $c = $test->c;

MusicBrainz::Server::Test->prepare_test_database($c, '+cdtoc');
MusicBrainz::Server::Test->prepare_test_database($c, <<'SQL');
    SET client_min_messages TO warning;
    TRUNCATE artist CASCADE;
    DELETE FROM medium_cdtoc WHERE id = 2;
SQL

my ($new_medium, $medium_cdtoc) = reload_data($c);

my $edit = create_edit($c, $new_medium, $medium_cdtoc);
($new_medium, $medium_cdtoc) = reload_data($c);

ok($edit->is_open);
is($medium_cdtoc->medium_id, 1);
is($medium_cdtoc->edits_pending, 1);
is($medium_cdtoc->medium->release->edits_pending, 1);

reject_edit($c, $edit);
($new_medium, $medium_cdtoc) = reload_data($c);

is($medium_cdtoc->medium_id, 1);
is($medium_cdtoc->edits_pending, 0);
is($medium_cdtoc->medium->release->edits_pending, 0);

$edit = create_edit($c, $new_medium, $medium_cdtoc);
accept_edit($c, $edit);
($new_medium, $medium_cdtoc) = reload_data($c);

is($medium_cdtoc->medium_id, 2);
is($medium_cdtoc->edits_pending, 0);
is($medium_cdtoc->medium->release->edits_pending, 0);

};

test 'Cannot move to non-existant medium' => sub {
    my $test = shift;
    my $c = $test->c;

    MusicBrainz::Server::Test->prepare_test_database($c, '+cdtoc');

    my $edit = create_edit($c, reload_data($c));
    $c->model('Medium')->delete(2);
    isa_ok exception { $edit->accept },
        'MusicBrainz::Server::Edit::Exceptions::FailedDependency';
};

sub create_edit {
    my ($c, $new_medium, $medium_cdtoc) = @_;
    return $c->model('Edit')->create(
        edit_type => $EDIT_MEDIUM_MOVE_DISCID,
        editor_id => 1,
        new_medium => $new_medium,
        medium_cdtoc => $medium_cdtoc,
    );
}

sub reload_data {
    my $c = shift;
    my $new_medium = $c->model('Medium')->get_by_id(2);
    my $medium_cdtoc = $c->model('MediumCDTOC')->get_by_id(1);
    $c->model('Medium')->load($medium_cdtoc);
    $c->model('Release')->load($new_medium, $medium_cdtoc->medium);

    return ($new_medium, $medium_cdtoc);
}

1;
