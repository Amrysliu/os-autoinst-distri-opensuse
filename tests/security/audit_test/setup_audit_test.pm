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
# Summary: Implement CC audit_trail_protetion test case into openQA
#
# Maintainer: xiaojing liu <xiaojing.liu@suse.com>

use base 'opensusebasetest';
use testapi;
use strict;
use warnings;
use utils;
use power_action_utils "power_action";
use bootloader_setup 'add_grub_cmdline_settings';

sub run {
    my ($self) = @_;
    select_console("root-console");

    # Install 389-ds and create an server instance
    zypper_call("in --no-confirm --allow-downgrade --force-resolution -t pattern common-criteria", timeout => 600);
    zypper_call("in --no-confirm --allow-downgrade --force-resolution libcap-devel gcc libselinux-devel libcap-progs perl-Error audit-audispd-plugins", timeout => 600);

    add_grub_cmdline_settings('audit=1 selinux=1', update_grub => 1);    
    assert_script_run("sed -i '/[Service]/a StartLimitInterval=1' /usr/lib/systemd/system/auditd.service");

    assert_script_run("wget --no-check-certificate https://gitlab.suse.de/security/audit-test-sle15/-/archive/master/audit-test-sle15-master.tar");
    assert_script_run("tar -xf audit-test-sle15-master.tar");
    power_action("reboot", textmode => 1);
    $self->wait_boot(textmode => 1, ready_time => 600, bootloader_time => 300);
    select_console "root-console";
}

sub test_flags {
    return {fatal => 1};
}

1;
