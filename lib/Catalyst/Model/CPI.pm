package Catalyst::Model::CPI;
# ABSTRACT: Business::CPI models for Catalyst
use Moose;
use Module::Pluggable (
    search_path => [ 'Business::CPI::Gateway' ],
    except      => [
        'Business::CPI::Gateway::Base',
        'Business::CPI::Gateway::Test',
    ],
    sub_name    => 'available_gateways',
    require     => 1,
);
use Moo::Role ();

extends 'Catalyst::Model';

our $VERSION = '0.01'; # VERSION

has _config_for_gateway => (
    isa     => 'HashRef',
    is      => 'ro',
    default => sub { +{} },
    traits  => ['Hash'],
    handles => {
        _get_config_for_gateway => 'get',
    },
);

has _req => ( is => 'rw' );
has _log => ( is => 'rw' );

around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;

    my $args = $self->$orig(@_);

    $args->{_config_for_gateway} = delete $args->{gateway};

    return $args;
};

before COMPONENT => sub {
    my ($self, $ctx) = @_;

    for ($self->available_gateways) {
        if ($_->isa('Business::CPI::Gateway::Base') && $_->can('notify')) {
            Moo::Role->apply_roles_to_package(
                $_, 'Business::CPI::Role::Request'
            );
        }
    }
};

sub ACCEPT_CONTEXT {
    my ($self, $ctx) = @_;

    $self->_req($ctx->req);
    $self->_log($ctx->log);

    return $self;
}

sub get {
    my ($self, $name) = @_;

    if (!$self->exists($name)) {
        local $" = ", ";
        my @plugins = $self->available_gateways;
        die "Can't get gateway $name. Available gateways are @plugins";
    }

    my $fullname = "Business::CPI::Gateway::$name";

    my %args = %{ $self->_get_config_for_gateway($name) };
    $args{req} = $self->_req;
    $args{log} = $self->_log;

    return $fullname->new(%args);
}

sub exists {
    my ($self, $name) = @_;

    my $fullname = "Business::CPI::Gateway::$name";

    for ($self->available_gateways) {
        return 1 if $_ eq $fullname;
    }

    return 0;
}


package # hide from PAUSE
    Business::CPI::Role::Request;
use Moo::Role;

has req => ( is => 'ro' );

around notify => sub {
    my $orig = shift;
    my $self = shift;

    if (scalar @_) {
        die "You are using Business::CPI from Catalyst.\n" .
            "You don't have to pass the request!\n";
    }

    return $self->$orig($self->req);
};

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Catalyst::Model::CPI - Business::CPI models for Catalyst

=head1 VERSION

version 0.01

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

=head2 available_gateways

List all the class names for the installed CPI gateways.

    my @gateways = $ctx->model('Payments')->available_gateways;

=head2 get

Returns a new instance of the gateway, with all the configuration passed as
arguments to the constructor.

    my $cart = $ctx->model('Payments')->get('PayPal')->new_cart(...);

=head2 exists

Check whether the provided gateway is really installed.

    if ($model->exists($gateway)) {
        ...
    }

=head2 ACCEPT_CONTEXT

Saves the request, so that C<< $gateway->notify >> can receive it
automatically. See the  L<Catalyst docs|Catalyst::Component/ACCEPT_CONTEXT> for
details.

=head1 CONFIGURATION

    <model Payments>
        <gateway PayPal>
            api_username   ...
            api_password   ...
            signature      ...
            receiver_email seller@test.com
            sandbox 1
        </gateway>

        <gateway PagSeguro>
            receiver_email seller@test.com
            ...
        </gateway>

        <gateway Custom>
            foo bar
        </gateway>
    </model>

=head1 AUTHOR

André Walker <andre@andrewalker.net>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by André Walker.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut