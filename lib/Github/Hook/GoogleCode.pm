package Github::Hook::GoogleCode;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use Moose;
use base qw( HTTP::Server::Simple::CGI );

use JSON;
use HTTP::Cookies;
use WWW::Mechanize;

with 'MooseX::Getopt';

has 'port' => (
    is => 'rw', isa => 'Int', default => 9999,
);

has 'path' => (
    is => 'rw', isa => 'Str', default => '/',
);

has 'project' => (
    is => 'rw', isa => 'Str', required => 1,
);

has 'email' => (
    is => 'rw', isa => 'Str', required => 1,
);

has 'password' => (
    is => 'rw', isa => 'Str',
);

has 'mech' => (
    is => 'rw', lazy => 1, default => sub {
        my $cookie = HTTP::Cookies->new; # on-memory cookie for Google Code
        return WWW::Mechanize->new( cookie_jar => $cookie );
    }
);

no Moose;
__PACKAGE__->meta->make_immutable;

sub run {
    my $self = shift;
    while (!defined $self->password or $self->password eq '') {
        require Term::ReadPassword;
        my $pass = Term::ReadPassword::read_password("password: ");
        $self->password($pass);
    }
    $self->SUPER::run(@_);
}

sub handle_request {
    my($self, $cgi) = @_;

    my $path = $cgi->path_info;
    if ($path eq $self->path) {
        return $self->dispatch_hook($cgi);
    }

    print "HTTP/1.0 404 Not found\r\n";
    print $cgi->header, "Not found";
}

sub dispatch_hook {
    my($self, $cgi) = @_;

    my $json = from_json($cgi->param('payload'));

    my @tickets;
    if ($json->{commits}) {
        for my $commit (@{$json->{commits}}) {
            my $res = $self->parse_commit_log($commit->{message});
            if ($res->{id}) {
                $self->update_ticket($res, $commit);
                push @tickets, $res->{id};
            }
        }
    }

    print "HTTP/1.0 200 OK\r\n";
    print $cgi->header, "Success ";
    print join(", ", @tickets);
}

sub update_ticket {
    my($self, $res, $commit) = @_;

    $self->get_ticket_page($res->{id});
    if ($self->mech->content =~ m!www.google.com/accounts/Login!) {
        $self->signin_google_code;
        $self->get_ticket_page($res->{id});
    }

    $self->mech->form_with_fields('summary', 'comment');
    my $fields = $self->setup_fields($res, $commit);
    $self->mech->submit_form(fields => $fields);
}

sub signin_google_code {
    my $self = shift;

    $self->mech->follow_link( url_regex => qr!^http://www\.google\.com/accounts/Login! );
    $self->mech->submit_form(
        with_fields => {
            Email  => $self->email,
            Passwd => $self->password,
        },
    );
    if ($self->mech->uri !~ /CheckCookie/) {
        die "Login to Google Code failed.";
    }

    return 1;
}

sub setup_fields {
    my($self, $res, $commit) = @_;

    my %fields = (
        comment => "Fixed by " . $commit->{author}{name} . " with " . substr($commit->{id}, 0, 7) . "\n" .
            $commit->{url} . "\n\n" . $commit->{message},
    );

    if (my $status = $res->{state} || $res->{status}) {
        $fields{status} = ucfirst $status;
    }
    if ($res->{owner}) {
        $fields{owner} = $res->{owner};
    }

    my @labels;
    for my $key (qw( type priority milestone )) {
        if ($res->{$key}) {
            push @labels, ucfirst($key) . "-" . ucfirst($res->{$key});
        }
    }

    if ($res->{label} && ref $res->{label} eq 'ARRAY') {
        push @labels, @{$res->{label}};
    } elsif ($res->{label}) {
        push @labels, $res->{label};
    }

    push @labels, map $_->value, $self->mech->find_all_inputs(name => 'label');

    # There should be at most one Type, Priority, Milestone labels
    my %seen;
    @labels = grep {
        my $at_most_one = /^(Type|Priority|Milestone)-/;
        ($at_most_one and !$seen{$1}++) or (!$at_most_one);
    } @labels;

    my $i = 1;
    for my $label (@labels) {
        $self->mech->field(label => $label, $i++);
    }

    return \%fields;
}

sub get_ticket_page {
    my($self, $id) = @_;
    $self->mech->get("http://code.google.com/p/" . $self->project . "/issues/detail?id=" . $id);
}

sub parse_commit_log {
    my($self, $text) = @_;

    my $res;
    if ($text =~ /\[\#(\d+)([^\]]*)\]/) {
        $res->{id} = $1;

        my @attrs = $2 =~ /(\S+)/g;
        for my $attr (@attrs) {
            my($key, $value) = split /:/, $attr, 2;
            $value =~ s/^(["'])(.*)?\1$/$2/;
            if (exists $res->{$key}) {
                $res->{$key} = [ $res->{$key} ] unless ref $res->{$key};
                push @{$res->{$key}}, $value;
            } else {
                $res->{$key} = $value;
            }
        }
    }

    return $res;
}

1;
__END__

=encoding utf-8

=for stopwords

=head1 NAME

Github::Hook::GoogleCode -

=head1 SYNOPSIS

  use Github::Hook::GoogleCode;

=head1 DESCRIPTION

Github::Hook::GoogleCode is

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@cpan.orgE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

=cut
