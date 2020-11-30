# SUSE openQA tests
#
# Copyright (C) 2017-2020 SUSE LLC
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

# Summary: Register system against SCC after installation
# Maintainer: Michal Nowak <mnowak@suse.com>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils 'zypper_call';
use version_utils qw(is_sle is_microos);
use registration;

sub run {
    return if get_var('HDD_SCC_REGISTERED');
    my $self       = shift;
    my $reg_code   = get_required_var('SCC_REGCODE');
    my $cmd        = "SUSEConnect -r $reg_code";
    my $scc_addons = get_var('SCC_ADDONS', '');

    if ($reg_code !~ /^INTERNAL-USE-ONLY.*/i || is_microos) {
        $cmd .= ' --url ' . (get_required_var 'SCC_URL');
    }

    select_console('root-console');
    assert_script_run $cmd;
    unless (is_microos('suse')) {
        assert_script_run 'SUSEConnect --list-extensions';
        assert_screen 'activated-with-suseconnect';
        assert_script_run 'SUSEConnect --list-extensions | grep "$(echo -en \'    \e\[1mServer Applications Module\')"';
        assert_script_run 'SUSEConnect --list-extensions | grep "$(echo -en \'        \e\[1mWeb and Scripting Module\')"';
    }

    # add modules
    if (is_sle '15+') {
        register_addons_cmd;
    }
    # Check that repos actually work
    zypper_call('refresh');
}

sub post_fail_hook {
    my ($self) = shift;
    $self->SUPER::post_fail_hook;
    verify_scc;
    investigate_log_empty_license;
}

sub test_flags {
    return {fatal => 1, milestone => 1};
}

1;
