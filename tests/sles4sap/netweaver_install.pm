# SUSE's openQA tests
#
# Copyright 2017-2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Perform an unattended installation of SAP NetWeaver
# Requires: ENV variable NW pointing to installation media
# Maintainer: QE-SAP <qe-sap@suse.de>

use base "sles4sap";
use testapi;
use lockapi;
use hacluster;
use strict;
use warnings;

sub run {
    my ($self) = @_;
    my ($proto, $path) = $self->fix_path(get_required_var('NW'));
    my $instance_type = get_required_var('INSTANCE_TYPE');
    my $instance_id = get_required_var('INSTANCE_ID');
    my $sid = get_required_var('INSTANCE_SID');
    my $hostname = get_var('INSTANCE_ALIAS', '$(hostname)');
    my $params_file = "/sapinst/$instance_type.params";
    my $timeout = 900 * get_var('TIMEOUT_SCALE', 1);    # Time out for NetWeaver's sources related commands
    my $product_id = undef;

    # Set Product ID depending on the type of Instance
    if ($instance_type eq 'ASCS') {
        $product_id = 'NW_ABAP_ASCS';
    }
    elsif ($instance_type eq 'ERS') {
        $product_id = 'NW_ERS';
    }

    my @sapoptions = qw(SAPINST_START_GUISERVER=false SAPINST_SKIP_DIALOGS=true SAPINST_SLP_MODE=false IS_HOST_LOCAL_USING_STRING_COMPARE=true);
    push @sapoptions, "SAPINST_USE_HOSTNAME=$hostname";
    push @sapoptions, "SAPINST_INPUT_PARAMETERS_URL=$params_file";
    push @sapoptions, "SAPINST_EXECUTE_PRODUCT_ID=$product_id:NW750.HDB.ABAPHA";

    $self->select_serial_terminal;

    # This installs Netweaver's ASCS. Start by making sure the correct
    # SAP profile and solution are configured in the system
    $self->prepare_profile('NETWEAVER');

    # Mount media
    $self->mount_media($proto, $path, '/sapinst');

    # Define a valid hostname/IP address in /etc/hosts, but not in HA
    $self->add_hostname_to_hosts if (!get_var('HA_CLUSTER'));

    # Use the correct Hostname and InstanceNumber in SAP's params file
    # Note: $hostname can be '$(hostname)', so we need to protect with '"'
    assert_script_run "sed -i -e \"s/%HOSTNAME%/$hostname/g\" -e 's/%INSTANCE_ID%/$instance_id/g' -e 's/%INSTANCE_SID%/$sid/g' $params_file";

    # Create an appropiate start_dir.cd file and an unattended installation directory
    my $cmd = 'cd /sapinst ; ls | while read d; do if [ -d "$d" -a ! -h "$d" ]; then echo $d; fi ; done | sed -e "s@^@/sapinst/@" ; cd -';
    assert_script_run 'mkdir -p /sapinst/unattended';
    assert_script_run "($cmd) > /sapinst/unattended/start_dir.cd";
    script_run 'cd -';

    # Create sapinst group
    assert_script_run "groupadd sapinst";
    assert_script_run "chgrp -R sapinst /sapinst/unattended";
    assert_script_run "chmod 0775 /sapinst/unattended";

    # Start the installation
    enter_cmd "cd /sapinst/unattended";
    $cmd = '../SWPM/sapinst ' . join(' ', @sapoptions);

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && !is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }

    if ($instance_type eq 'ASCS') {
        assert_script_run $cmd, $timeout;
    }
    elsif ($instance_type eq 'ERS') {
        # We have to workaround an installation issue:
        # ERS installation try to stop the ASCS server but that doesn't work
        #  because ASCS is running on the first node!
        # It's "normal" and documentation says that we have to install ERS on the 2nd node
        #  in order to have the SAP environment correctly set-up.
        script_run $cmd, $timeout;

        # So we have to check in the log file that's the installation goes well
        # We simply checking for the ASCS stop error message!
        # TODO: maybe change this to something more robust!
        assert_script_run "grep -q 'Cannot stop instance.*ASCS' /sapinst/unattended/sapinst.log";
    }

    # Synchronize with other nodes
    if (get_var('HA_CLUSTER') && is_node(1)) {
        my $cluster_name = get_cluster_name;
        barrier_wait("ASCS_INSTALLED_$cluster_name");
    }

    # Allow SAP Admin user to inform status via $testapi::serialdev
    $self->set_sap_info($sid, $instance_id);
    $self->ensure_serialdev_permissions_for_sap;
}

1;
