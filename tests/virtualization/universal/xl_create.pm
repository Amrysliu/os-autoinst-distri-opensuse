# Copyright (C) 2019 SUSE LLC
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
# Package: libvirt-daemon xen-tools nmap
# Summary: Export XML from virsh and create new guests in xl stack
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use base "consoletest";
use virt_autotest::common;
use strict;
use warnings;
use testapi;
use utils;

sub run {
    record_info "XML", "Export the XML from virsh and convert it into Xen config file";
    assert_script_run "virsh dumpxml $_ > $_.xml"                         foreach (keys %virt_autotest::common::guests);
    assert_script_run "virsh domxml-to-native xen-xl $_.xml > $_.xml.cfg" foreach (keys %virt_autotest::common::guests);

    record_info "Name", "Change the name by adding suffix _xl";
    assert_script_run "sed -rie 's/(name = \\W)/\\1xl-/gi' $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat $_.xml.cfg | grep name"                     foreach (keys %virt_autotest::common::guests);

    record_info "UUID", "Change the UUID by using f00 as three first characters";
    assert_script_run "sed -rie 's/(uuid = \\W)(...)/\\1f00/gi' $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "cat $_.xml.cfg | grep uuid"                          foreach (keys %virt_autotest::common::guests);

    record_info "Start", "Start the new VM";
    assert_script_run "xl create $_.xml.cfg" foreach (keys %virt_autotest::common::guests);
    assert_script_run "xl list xl-$_"        foreach (keys %virt_autotest::common::guests);

    record_info "SSH", "Test that the new VM listens on SSH";
    script_retry "nmap $_ -PN -p ssh | grep open", delay => 30, retry => 12 foreach (keys %virt_autotest::common::guests);

}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;

