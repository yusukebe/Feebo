package Feebo;
use Moose;
use Moose::Util::TypeConstraints;
use Params::Coerce ();
use AnyEvent::Feed;
use AnyEvent::IRC::Client;
use AnyEvent;
use Encode;
use URI;
with 'MooseX::Getopt';
our $VERSION = '0.01';

subtype 'Uri' => as 'Object' => where { $_->isa('URI') };
coerce 'Uri'  => from 'Str'  => via   { URI->new($_) };
MooseX::Getopt::OptionTypeMap->add_option_type_to_map( 'Uri' => '=s' );

has 'channel' => ( is => 'rw', isa => 'Str', required => 1 );
has 'server' => ( is => 'rw', isa => 'Str', default => 'irc.freenode.net' );
has 'port'   => ( is => 'rw', isa => 'Int', default => 6667 );
has 'nick'   => ( is => 'rw', isa => 'Str', default => 'feed_bot' );
has 'interval' => ( is => 'rw', isa => 'Int', default => 60 * 5 );
has 'feed' => ( is => 'rw', isa => 'Uri', coerce => 1 );

no Mouse;

sub run {
    my $self = shift;
    my $cv   = AnyEvent->condvar;

    my $pc = AnyEvent::IRC::Client->new;
    $pc->reg_cb(
        connect => sub {
            my ( $pc, $err ) = @_;
            if ( defined $err ) {
                print "Couldn't connect to server: $err\n";
            }
        },
        registered => sub {
            printf "Join: %s\n", $self->channel;
            $pc->clear_chan_queue( $self->channel );
            $pc->enable_ping(60);
        },
       disconnect => sub {
            print "Disconnected: $_[1]!\n";
        }
    );
    $pc->send_srv( "JOIN", $self->channel );
    $pc->connect( $self->server, $self->port,
              { nick => $self->nick, user => $self->nick, real => $self->nick } );
    my $feed = AnyEvent::Feed->new(
        url      => $self->feed,
        interval => $self->interval,
        on_fetch => sub {
            my ( $fee, $ent, $feed, $er ) = @_;
            if ( defined $er ) {
                print "Error: $er\n";
                $cv->send;
                return;
            }
            my @msg;
            for (@$ent) {
                my $str = sprintf "%s %s", encode('utf8', $_->[1]->title ), $_->[1]->link;
                $str =~ s/\n//gm;
                $str =~ s/^\s+//gm;
                $pc->send_chan( $self->channel, "NOTICE", $self->channel, $str );
            }
        }
    );
    $cv->recv;
}

1;

__END__

=head1 NAME

Feebo - Bot for posting feed entries to IRC channel

=head1 SYNOPSIS

  use Feebo;

=head1 DESCRIPTION

Feebo is

=head1 AUTHOR

Yusuke Wada E<lt>yusuke at kamawada.comE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
