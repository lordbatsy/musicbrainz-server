package MusicBrainz::Server::Controller::Widgets;
use Moose;

BEGIN { extends 'MusicBrainz::Server::Controller'; }

sub artist : Path('artist') Args(1)
{

    my ($self, $c, $mbid) = @_;
    $c->stash(
        template => 'widgets/artist.tt',
        mbid => $mbid,
    );

}

sub release : Path('release') Args(2)
{

    my ($self, $c, $style, $mbid) = @_;
    $c->stash(
        style => $style,
        template => 'widgets/release.tt',
        mbid => $mbid,
    );

}


=head1 LICENSE

Copyright (C) 2011 MetaBrainz Foundation Inc.

This software is provided "as is", without warranty of any kind, express or
implied, including  but not limited  to the warranties of  merchantability,
fitness for a particular purpose and noninfringement. In no event shall the
authors or  copyright  holders be  liable for any claim,  damages or  other
liability, whether  in an  action of  contract, tort  or otherwise, arising
from,  out of  or in  connection with  the software or  the  use  or  other
dealings in the software.

GPL - The GNU General Public License    http://www.gnu.org/licenses/gpl.txt
Permits anyone the right to use and modify the software without limitations
as long as proper  credits are given  and the original  and modified source
code are included. Requires  that the final product, software derivate from
the original  source or any  software  utilizing a GPL  component, such  as
this, is also licensed under the GPL license.

=cut

1;
