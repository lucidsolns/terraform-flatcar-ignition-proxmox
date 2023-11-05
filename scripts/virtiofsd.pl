#!/usr/bin/perl
#
# A hook script for PVE guests to allow support mounting PVE host directories
# inside the VM using virtiofs and the rust virtiofsd daemon.
#
# Installation
# ============
#  - Put this script in '/var/lib/vz/snippets/virtiofsd.pl' where
#    the 'local:' storage maps to the directory '/var/lib/vz'
#  - Ensure the script is executable
#  - Configure the VM with a description having lines of the form:
#        virtiofs: path=/... socket=...
#
# see:
#  - https://lists.proxmox.com/pipermail/pve-devel/2023-June/057270.html
#  - https://metacpan.org/pod/Getopt::Long
#  - https://share.lucidsolutions.co.nz/pub/debian/bookworm/virtiofsd-1.8.0/
use strict;
use warnings;

use PVE::QemuConfig;
use PVE::GuestHelpers;
use PVE::Tools;
use Getopt::Long qw(GetOptionsFromString);

sub mount_virtiofsd {
    my ($vmid, $phase) = @_;

    my $conf = PVE::QemuConfig->load_config($vmid);
    # get the description from the VM configuration, this should be plain text
    # decoded with PVE::Tools::decode_text(). This field is limited to 8kb.
    my $description = $conf->{description};

    mkdir("/run/virtiofsd"); # only needs to be created once on the host

    while ($description =~ /^\s*virtiofs:\s*([^\r\n]*)$/gm) {
        my $virtiofs_spec = $1;

        my $socket_path = "";
        my $shared_dir = "";

        GetOptionsFromString(
            $virtiofs_spec,
            "socket=s" => \$socket_path,
            "path=s" => \$shared_dir) or die("Error in virtio filesystem specification ($virtiofs_spec)");
        my $pid_path = "$socket_path.pid";

        # hard code the path, tag and socket name for now (c.f. parsing the virtiofs spec
        PVE::Tools::run_command([
            "/usr/sbin/start-stop-daemon",
            "--start",
            "--background",
            "--pidfile=$pid_path",  # virtiofsd will write the pid file
            "--exec=/usr/local/bin/virtiofsd",
            "--",
            "--socket-path=$socket_path",
            "--syslog",
            "--shared-dir=$shared_dir"
        ]);
    }
}

sub umount_virtiofsd {
    my ($vmid, $phase) = @_;
    my $conf = PVE::QemuConfig->load_config($vmid);
    # get the description from the VM configuration, this should be plain text
    # decoded with PVE::Tools::decode_text(). This field is limited to 8kb.
    my $description = $conf->{description};
    while ($description =~ /^\s*virtiofs:\s*([^\r\n]*)$/gm) {
        my $virtiofs_spec = $1;

        my $socket_path = "";
        my $shared_dir = "";

        GetOptionsFromString(
            $virtiofs_spec,
            "socket=s" => \$socket_path,
            "path=s" => \$shared_dir) or die("Error in virtio filesystem specification ($virtiofs_spec)");
        my $pid_path = "$socket_path.pid";

        PVE::Tools::run_command([
            "/usr/sbin/start-stop-daemon",
            "--stop",
            "--pidfile=$pid_path",  # virtiofsd will write the pid file
            "--exec=/usr/local/bin/virtiofsd",
        ]);
    }
}

# First argument is the vmid
my $vmid = shift;
# Second argument is the phase
my $phase = shift;

if ($phase eq 'pre-start') {
    mount_virtiofsd($vmid, $phase);
}
elsif ($phase eq 'post-start') {
    # nothing to do
}
elsif ($phase eq 'pre-stop') {
    # nothing to do
}
elsif ($phase eq 'post-stop') {
    umount_virtiofsd($vmid, $phase);
}
else {
    die "got unknown phase '$phase'\n";
}

exit(0);
