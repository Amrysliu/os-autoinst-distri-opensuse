# Copyright (C) 2021 SUSE LLC
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, see <http://www.gnu.org/licenses/>.
#
# Summary: Run "audit-tools" test case of "audit-test" test suite
# Maintainer: liuxiaojing <xiaojing.liu@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use audit_test;
use Data::Dumper;

sub run {
    my ($self) = shift;

    select_console "root-console";
    assert_script_run('sed -i \'/\[Unit\]/a\StartLimitIntervalSec=0\' /usr/lib/systemd/system/auditd.service');
    assert_script_run("systemctl daemon-reload");
    assert_script_run("sed -i 's/-a task,never/#-a task,never/' /etc/audit/audit.rules");
    
    # Run test case
    assert_script_run("cd $audit_test::testdir/$audit_test::testfile_tar/audit-test/");
    assert_script_run("make");
    assert_script_run("export MODE=64");
    assert_script_run("cd syscalls/");
    assert_script_run('./run.bash', timeout => 900);

    my $output = script_output('cat ./rollup.log');
    my @lines = split(/\n/, $output);
    my $current_results = audit_test::lxj_parse_lines(\@lines); 
    upload_logs('baseline_run.log');

    # Compare current test results with baseline
    my $result = audit_test::lxj_compare_run_log($current_results, "syscalls-baseline_run.log");
    $self->result($result);
    upload_logs("run.log");
}

sub test_flags {
    return {no_rollback => 1};
}

1;
