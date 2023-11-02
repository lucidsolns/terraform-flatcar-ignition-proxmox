#!/usr/bin/perl
#
# A hook script for PVE guests to allow multiple hookscript to be run for
# each PVE VM.
#
# Set the hookscript on the VM during creation with terraform, or set it manually:
#     `qm set <vm_id> -hookscript local:snippets/multi-hookscript.pl`
#
# Installation
# ============
#  - Put this script in '/var/lib/vz/snippets/multi-hookscript.pl' where
#    the 'local:' storage maps to the directory '/var/lib/vz'
#  - Ensure the script is executable
#  - Configure the VM with a description having lines of the form:
#        hook-script: local:/snippets/example.pl
#

use strict;
use warnings;

use PVE::QemuConfig;
use PVE::GuestHelpers;
use PVE::Tools;

# First argument is the vmid
my $vmid = shift;

# Second argument is the phase
my $phase = shift;

my $conf = PVE::QemuConfig->load_config($vmid);
# get the description from the VM configuration, this should be plain text
# decoded with PVE::Tools::decode_text(). This field is limited to 8kb.
my $description = $conf->{description};

while ($description =~ /^\s*hook-script:\s*([^\n]*)$/gm) {
    my $hookscript = $1;

    eval {
        my $script = PVE::GuestHelpers::check_hookscript($hookscript);
        die $@ if $@;

        PVE::Tools::run_command([$script, $vmid, $phase]);
    };
    if (my $err = $@) {
        my $errmsg = "hookscript error for $vmid on $phase: $err\n";
        die $errmsg if ($phase eq 'pre-start');
        warn $errmsg;
    }
}
