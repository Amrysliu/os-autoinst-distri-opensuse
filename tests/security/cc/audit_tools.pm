# SUSE's openQA tests
#
# Copyright © 2021 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.
#
# Summary: Run 'audit-tools' test case of 'audit-test' test suite
# Maintainer: llzhao <llzhao@suse.com>
# Tags: poo#94450

use base 'audit_test';
use strict;
use warnings;
use testapi;
use utils;

sub run {
    my ($self) = shift;

    select_console 'root-console';

    # Run test case
    $self->run_testcase('audit-tools');

    # Compare current test results with baseline
    my $result = $self->compare_run_log('audit_tools');
    $self->result($result);
}

1;
