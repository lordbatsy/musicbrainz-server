package MusicBrainz::Server::EditSearch::Query;
use Moose;

use CGI::Expand qw( expand_hash );
use MooseX::Types::Moose qw( Any ArrayRef Bool Int Maybe Str );
use MooseX::Types::Structured qw( Map Tuple );
use Moose::Util::TypeConstraints qw( enum role_type );
use MusicBrainz::Server::EditSearch::Predicate::Date;
use MusicBrainz::Server::EditSearch::Predicate::ID;
use MusicBrainz::Server::EditSearch::Predicate::Set;
use MusicBrainz::Server::EditSearch::Predicate::LinkedEntity;
use Try::Tiny;

my %field_map = (
    id => 'MusicBrainz::Server::EditSearch::Predicate::ID',
    open_time => 'MusicBrainz::Server::EditSearch::Predicate::Date',
    close_time => 'MusicBrainz::Server::EditSearch::Predicate::Date',
    expire_time => 'MusicBrainz::Server::EditSearch::Predicate::Date',
    type => 'MusicBrainz::Server::EditSearch::Predicate::Set',
    status => 'MusicBrainz::Server::EditSearch::Predicate::Set',
    no_votes => 'MusicBrainz::Server::EditSearch::Predicate::ID',
    yes_votes => 'MusicBrainz::Server::EditSearch::Predicate::ID',

    map {
        $_ => 'MusicBrainz::Server::EditSearch::Predicate::' . ucfirst($_) 
    } qw( artist label recording release release_group work )
);

has negate => (
    isa => Bool,
    is => 'ro',
    default => 0
);

has combinator => (
    isa => enum([qw( or and )]),
    is => 'ro',
    required => 1,
    default => 'and'
);

has auto_edit_filter => (
    isa => Maybe[Bool],
    is => 'ro',
    default => undef
);

has join => (
    isa => ArrayRef[Str],
    is => 'bare',
    default => sub { [] },
    traits => [ 'Array' ],
    handles => {
        join => 'elements',
        add_join => 'push',
    }
);

has join_counter => (
    isa => Int,
    is => 'ro',
    default => 0,
    traits => [ 'Counter' ],
    handles => {
        inc_joins => 'inc',
    }
);

has where => (
    isa => ArrayRef[ Tuple[ Str, ArrayRef[Any] ] ],
    is => 'bare',
    traits => [ 'Array' ],
    default => sub { [] },
    handles => {
        where => 'elements',
        'add_where' => 'push',
    }
);

has fields => (
    isa => ArrayRef[ role_type('MusicBrainz::Server::EditSearch::Predicate') ],
    is => 'bare',
    required => 1,
    traits => [ 'Array' ],
    handles => {
        fields => 'elements',
    }
);

sub new_from_user_input {
    my ($class, $user_input) = @_;
    my $input = expand_hash($user_input);
    my $ae = $input->{auto_edit_filter};
    $ae = undef if $ae =~ /^\s*$/;
    return $class->new(
        negate => $input->{negation},
        combinator => $input->{combinator},
        auto_edit_filter => $ae,
        fields => [
            map {
                $class->_construct_predicate($_)
            } grep { defined } @{ $input->{conditions} }
        ]
    );
}

sub _construct_predicate {
    my ($class, $input) = @_;
    return try {
        my $predicate_class = $field_map{$input->{field}} or die 'No predicate for field ' . $input->{field};
        $predicate_class->new_from_input(
            $input->{field},
            $input
        )
    } catch { return () };
}

sub valid {
    my $self = shift;
    my $valid = 1;
    $valid &&= $_->valid for $self->fields;
    return $valid
}

sub as_string {
    my $self = shift;
    $_->combine_with_query($self) for $self->fields;
    my $comb = $self->combinator;
    my $ae_predicate = defined $self->auto_edit_filter ?
        'autoedit = ? AND ' : '';
    return 'SELECT edit.* FROM edit ' .
        join(' ', $self->join) .
        ' WHERE ' . $ae_predicate . ($self->negate ? 'NOT' : '') . ' (' .
            join(" $comb ", map { '(' . $_->[0] . ')' } $self->where) .
        ') LIMIT 500 OFFSET ?';
}

sub arguments {
    my $self = shift;
    return (
        $self->auto_edit_filter // (),
        map { @{$_->[1]} } $self->where
    );
}

1;
