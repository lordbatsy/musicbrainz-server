package MusicBrainz::Server::Edit::Generic::Delete;
use Moose;
use MooseX::ABC;

use MusicBrainz::Server::Constants qw( $EDIT_ARTIST_DELETE );
use MusicBrainz::Server::Data::Artist;
use MusicBrainz::Server::Edit::Exceptions;
use MusicBrainz::Server::Entity::Types;
use MooseX::Types::Moose qw( Int Str );
use MooseX::Types::Structured qw( Dict );

extends 'MusicBrainz::Server::Edit';
requires '_delete_model';

sub alter_edit_pending
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model);
    if ($model->does('MusicBrainz::Server::Data::Role::Editable')) {
        return {
            $self->_delete_model => [ $self->entity_id ]
        }
    } else {
        return { }
    }
}

sub related_entities
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model);
    if ($model->does('MusicBrainz::Server::Data::Role::LinksToEdit')) {
        return {
            $model->edit_link_table => [ $self->entity_id ]
        }
    } else {
        return { }
    }
}

sub entity_id { shift->data->{entity_id} }

has '+data' => (
    isa => Dict[
        entity_id => Int,
        name      => Str
    ]
);

sub build_display_data
{
    my $self = shift;
    return {
        name => $self->data->{name}
    };
}

sub initialize
{
    my ($self, %args) = @_;
    my $entity = delete $args{to_delete} or die "Required 'to_delete' object";

    $self->data({
        name      => $entity->name,
        entity_id => $entity->id,
    });
}

override 'accept' => sub
{
    my $self = shift;
    my $model = $self->c->model( $self->_delete_model );

    MusicBrainz::Server::Edit::Exceptions::FailedDependency->throw
          unless $model->can_delete( $self->entity_id );

    $model->delete($self->entity_id);
};

__PACKAGE__->meta->make_immutable;

no Moose;
1;