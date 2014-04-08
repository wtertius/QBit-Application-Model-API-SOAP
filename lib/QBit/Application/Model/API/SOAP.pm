package Exception::API::SOAP;
use base qw(Exception::API);

package QBit::Application::Model::API::SOAP;

use qbit;

use base qw(QBit::Application::Model::API);

use SOAP::Lite;
use Data::Rmap;

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    if ($self->get_option('debug')) {
        eval "use SOAP::Lite '+trace';";
    } else {
        eval "use SOAP::Lite;";
    }

    $self->{'__SOAP__'} =
      SOAP::Lite->new()->proxy($self->get_option('url'), timeout => $self->get_option('timeout', 300))
      ->uri($self->get_option('uri'));

    return TRUE;
}

sub call {
    my ($self, $func, @opts) = @_;

    rmap {utf8::decode($_) if defined($_) and !utf8::is_utf8($_)} \@opts;

    my $result;
    my $error;

  TRY:
    for my $try (1 .. 3) {
        my $som;
        eval {$som = $self->{__SOAP__}->call($func, @opts);};

        $error = $@;

        if (!$error) {
            if ($som->fault) {
                $self->log(
                    {
                        proxy_url => $self->{__SOAP__}->proxy->endpoint,
                        uri       => $self->{__SOAP__}->uri,
                        method    => $func,
                        params    => \@opts,
                        content   => undef,
                        error     => $som->faultstring
                    }
                ) if $self->can('log');
                throw Exception::API::SOAP $som->faultstring;
            } else {
                $result = [$som->paramsall];
            }
            last TRY;
        }
        $self->pause();
    }

    $self->log(
        {
            proxy_url => $self->{__SOAP__}->proxy->endpoint,
            uri       => $self->{__SOAP__}->uri,
            method    => $func,
            params    => \@opts,
            content   => $result,
            error     => $error
        }
    ) if $self->can('log');

    throw Exception::API::SOAP $error unless $result;
    return $result;
}

sub pause() {
    sleep(1);
}

TRUE;
