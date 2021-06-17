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

use base 'consoletest';
use testapi;
use strict;
use warnings;
use utils;
use Data::Dumper;

sub run {
    select_console("root-console");
    assert_script_run("cd audit-test-sle15-master/audit-test/audit-trail-protection/");
    assert_script_run("make MODE=64");
    my $result = script_output("./run.bash");
    diag("the result is " .Dumper($result));
}

1;
