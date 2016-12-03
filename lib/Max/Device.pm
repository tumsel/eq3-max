use strict;

package Max::Device;
use Carp qw(croak carp);
use MIME::Base64 qw(decode_base64 encode_base64);

my %modes = qw/0 auto 1 manual 2 vacation 3 boost/;
my %types = qw/0 cube 1 heater 2 heater+ 3 thermostat 4 shutter 5 button/;

sub new {
    my ($class, %p) = @_;
    return bless \%p, $class;
}

sub _set {
    my ($self, %p) = @_;
    @{ $self }{keys %p} = values %p;
}

sub addr        { shift->{addr} }
sub addr_hex    { lc unpack "H*", shift->{addr} }
sub serial      { shift->{serial} }
sub setpoint    { shift->{setpoint} }
sub valve       { shift->{valve} }
sub temperature { shift->{temperature} }

sub type_num {        shift->{type}  }
sub type     { $types{shift->{type}} }
sub mode_num {        shift->{mode}  }
sub mode     { $modes{shift->{mode}} }

sub name {
    my ($self, $new) = @_;
    return $self->{name} if not defined $new;
    return $self->{name} = $new;
}

sub display_name {
    my ($self, $include_addr) = @_;
    if (defined $self->{name} and length $self->{name}) {
        return "$self->{name}(" . $self->addr_hex . ")" if $include_addr;
        return $self->{name};
    }
    return $self->type . " " . $self->addr_hex;
}

sub display_name_room {
    my ($self) = @_;
    return $self->display_name . " in " . $self->room->display_name;
}

sub flags_as_string {
    my ($self) = @_;
    return join " ", grep $self->{flags}{$_}, sort keys %{ shift->{flags} };
}

sub has_temperature { shift->{type} == 3 }
sub has_valve       { $_[0]->{type} == 1 or $_[0]->{type} == 2 }
sub is_cube         { shift->{type} == 0 }

sub room {
    my ($self, $new) = @_;

    return $self->{room} if not defined $new;

    my $id = ref($new) ? $new->id : $new;
    $self->{max}->_send("s:", sprintf "000022000000%s00%02x",
        $self->addr_hex,
        $id
    );
    $self->{max}->_command_success("S") or return;

    my $room = $self->{max}->room($id);
    $room->add_device($self);

    return $self->{room} = $room;
}

sub add_link {
    my ($self, $other) = @_;
    $self->{max}->_send("s:", sprintf "000020000000%s%02x%s%02x",
        $self->addr_hex,
        $other->room->id,
        $other->addr_hex,
        $other->type_num,
    );
    return $self->{max}->_command_success("S");
}

sub config_display {
    my ($self, $setting) = @_;
    my $byte;
    $byte = 0 if $setting eq 'setpoint';
    $byte = 4 if $setting eq 'current';
    defined $byte or croak "Invalid setting for config_display: $setting";
    $self->type eq 'thermostat' or carp "config_display used on non-thermostat";

    $self->{max}->_send("s:", sprintf "000082000000%s%02x",
        $self->addr_hex,
        $byte,
    );
    return $self->{max}->_command_success("S");
}

1;
