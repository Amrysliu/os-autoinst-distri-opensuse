# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'netfilter' test case of 'audit-test' test suite
# Maintainer: Liu Xiaojing <xiaojing.liu@suse.com>
# Tags: poo#96540

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use lockapi;
use mmapi 'wait_for_children';
use audit_test qw(compare_run_log prepare_for_test upload_audit_test_logs);
use scheduler 'get_test_suite_data';
use Utils::Systemd qw(disable_and_stop_service);

sub run {
    my ($self) = shift;

    select_console 'root-console';

    zypper_call('in bridge-utils');
    disable_and_stop_service($self->firewall);

    # we need to do 'make netconfig' to generate 'lblnet_tst_server'
    prepare_for_test('netfilter', (make => 1, timeout => 900, make_netconfig => 1));

    # configure the network
    my $data = get_test_suite_data();

    my $role = get_required_var('ROLE');
    foreach my $key (keys %{$data->{$role}}) {
        my $n       = $data->{$role}->{$key};
        my $netcard = $n->{netcard};
        my $dev     = $netcard;
        assert_script_run("ip link add link eth0 address $n->{mac_add} $netcard type macvlan");

        # Network Bridge setting for Target of Evaluation(TOE)
        if ($role eq 'client' && $key eq 'second_interface') {
            assert_script_run('brctl addbr toebr');
            assert_script_run("brctl addif toebr $netcard");
            assert_script_run('brctl setageing toebr 3600');
            $dev = 'toebr';
        }

        assert_script_run("ip addr add $n->{ipv4} dev $dev");
        assert_script_run("ip addr add $n->{ipv6} dev $dev");
        assert_script_run("ip link set $netcard up");
        assert_script_run('ip link set toebr up') if ($role eq 'client' && $key eq 'second_interface');
        assert_script_run("ip -6 route add $n->{route} dev $dev");
    }

    # start lblnet_tst_server
    my $cmd        = "$audit_test::testdir$audit_test::testfile_tar/audit-test/utils/network-server/lblnet_tst_server";
    my $lblnet_pid = background_script_run($cmd);

    my $result = 'ok';
    if ($role eq 'server') {
        mutex_create('NETFILTER_SERVER_READY');
        wait_for_children;
    } else {
        mutex_wait('NETFILTER_SERVER_READY');

        # export the variables
        my $client_first  = $data->{client}->{first_interface};
        my $client_second = $data->{client}->{second_interface};
        my $server_first  = $data->{server}->{first_interface};
        my $server_second = $data->{server}->{second_interface};

        # Deal with ipv4 address: change 192.168.0.1/24 to 192.168.0.1
        $client_first->{ipv4}  =~ s/\/.*//g;
        $client_second->{ipv4} =~ s/\/.*//g;
        $server_first->{ipv4}  =~ s/\/.*//g;
        $server_second->{ipv4} =~ s/\/.*//g;

        script_run("export PASSWD=$testapi::password");
        script_run("export LOCAL_DEV=$client_first->{netcard}\@eth0");
        script_run("export LOCAL_SEC_DEV=$client_second->{netcard}\@eth0");
        script_run("export LOCAL_SEC_MAC=$client_second->{mac_add}");
        script_run("export LOCAL_IPV4=$client_first->{ipv4}");
        script_run("export LOCAL_IPV6=$client_first->{ipv6}");
        script_run("export LOCAL_SEC_IPV4=$client_second->{ipv4}");
        script_run("export LOCAL_SEC_IPV6=$client_second->{ipv6}");

        script_run("export LBLNET_SVR_IPV4=$server_first->{ipv4}");
        script_run("export LBLNET_SVR_IPV6=$server_first->{ipv6}");
        script_run("export SECNET_SVR_IPV4=$server_second->{ipv4}");
        script_run("export SECNET_SVR_IPV6=$server_second->{ipv6}");
        script_run("export SECNET_SVR_MAC=$server_second->{mac_add}");

        script_run('export BRIDGE_FILTER=toebr');

        run_audit_test($lblnet_pid, $cmd);

        # Compare current test results with baseline
        #        $result = compare_run_log('netfilter');
    }

    $self->result($result);
}

#
# This function is only used by client.
# When one case finishes, the port maybe hasn't been released, so we need to restart
# `lblnet_tst_server` in case the following test case ends with ERROR.
# So the test cases in netfilter will be run one by one.
#
sub run_audit_test {
    my ($pid, $lblnet_cmd) = @_;
    #    my $output = script_output('./run.bash --list');
    #    my @lines  = split(/\n/, $output);
    #    my @test_lists;
    #    foreach (@lines) {
    #        my $num;
    #        if ($_ =~ /\[(\d+)\]\s+\S+/) {
    #            $num = $1;
    #        } else {
    #            next;
    #        }
    #        my $cmd    = "./run.bash $num";
    #        my $result = script_output($cmd, timeout => 600);
    #
    #        # If the port is busy, the test case will end with error, we need to restart lblnet_tst_server
    #        if (index($result, 'could not setup remote test server') != -1) {
    #            script_run("kill -9 $pid");
    #            $pid = background_script_run($lblnet_cmd);
    #            # give more seconds for killing this process
    #            sleep 3;
    #            assert_script_run($cmd, timeout => 600);
    #        }
    #    }
    my $cmd = './run.bash 8 -d';
    my $result = script_output($cmd, timeout => 600);
    if (index($result, 'could not setup remote test server') != -1) {
        script_run("kill -9 $pid");
        $pid = background_script_run($lblnet_cmd);
        sleep 3;
        assert_script_run($cmd, timeout => 600);
    }
    # Upload logs
    upload_audit_test_logs();
}

1;
