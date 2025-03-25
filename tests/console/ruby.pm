# Copyright 2025 SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later

# Package: ruby
# Summary: -  Install ruby package
#          -  run a simple ruby program
# Maintainer: QE Core <qe-core@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use serial_terminal 'select_serial_terminal';
use utils;

sub run {
    select_serial_terminal;
    my $ruby = script_output("zypper se -s ruby | awk -F '|' '{ print \$2 }' | grep -oE 'ruby[0-9|.]+' | sort -V | tail -n 1");
    record_info("Version $ruby");
    if (!defined $ruby || $ruby eq "") {
        die "Could find out the ruby package" . script_output('zypper se ruby');
    }

    # Install ruby
    zypper_call("in $ruby");

    # Find our ruby command
    my $ruby_shell = script_output("ruby-find-versioned | grep $ruby");
    record_info("$ruby_shell");

    # Prepare test file
    my $test_string = "Hello, World";
    my $test_script = "test_ruby";
    assert_script_run("echo 'puts $test_string' > $test_script");
    validate_script_output "$ruby_shell $test_script", sub { m/$test_script/ };
    script_run("rm -f $test_script");
}

1;
