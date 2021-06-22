# SUSE's openQA tests
#
# Copyright © 2020 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Package: docker podman
# Summary: Pull and test several base images (alpine, openSUSE, debian, ubuntu, fedora, centos, ubi) for their base functionality
#          Log the test results in containers_3rd_party.txt
#          Docker or Podman tests can be skipped by setting SKIP_DOCKER_IMAGE_TESTS=1 or SKIP_PODMAN_IMAGE_TESTS=1 in the job
# Maintainer: qa-c team <qa-c@suse.de>

use base 'consoletest';
use strict;
use warnings;
use testapi;
use utils;
use version_utils;
use containers::common;
use registration;

sub skip_docker {
    return check_var("SKIP_DOCKER_IMAGE_TESTS", 1);
}

sub skip_podman {
    return ((is_sle and !is_sle('>=15-sp1')) or check_var("SKIP_PODMAN_IMAGE_TESTS", 1));
}

sub run_image_tests {
    my $engine = shift;
    my @images = @_;
    foreach my $image (@images) {
        record_info('IMAGE', "Testing $image with $engine");
        if ((check_var('ARCH', 's390x')) && ($image =~ /leap/)) {
            record_soft_failure("bsc#1171672 Missing Leap:latest container image for s390x");
        } elsif ((check_var('ARCH', 's390x')) && ($image =~ /centos/)) {
            record_info("Skip centos image", "Missing centos container image for s390x.");
        } elsif ((check_var('ARCH', 's390x')) && ($image =~ /ubuntu/)) {
            record_soft_failure("poo#72124 Ubuntu image (occasionaly) fails on s390x");
        } else {
            test_container_image(image => $image, runtime => $engine);
            script_run("echo 'OK: $engine - $image:latest' >> /var/tmp/containers_3rd_party_log.txt");
        }
    }
}

sub upload_image_logs {
    # Rename for better visibility in Uploaded Logs
    if (script_run('mv /var/tmp/containers_3rd_party_log.txt /tmp/containers_3rd_party.txt') != 0) {
        record_info("No logs", "No logs found");
    } else {
        upload_logs("/tmp/containers_3rd_party.txt");
        script_run("rm /tmp/containers_3rd_party.txt");
    }
}

sub run {
    my ($self) = @_;
    $self->select_serial_terminal;

    my ($running_version, $sp, $host_distri) = get_os_release;

    # Define test images here
    my $ex_reg = get_var('REGISTRY', 'docker.io');
    my @images = (
        "registry.opensuse.org/opensuse/leap",
        "registry.opensuse.org/opensuse/tumbleweed",
        "$ex_reg/library/alpine",
        "$ex_reg/library/debian",
        "$ex_reg/library/ubuntu",
        "$ex_reg/library/centos",
        "$ex_reg/library/fedora",
        "registry.access.redhat.com/ubi7/ubi",
        "registry.access.redhat.com/ubi7/ubi-minimal",
        "registry.access.redhat.com/ubi7/ubi-init",
        "registry.access.redhat.com/ubi8/ubi",
        "registry.access.redhat.com/ubi8/ubi-minimal",
        "registry.access.redhat.com/ubi8/ubi-init");

    script_run('echo "Container base image tests:" > /var/tmp/containers_3rd_party_log.txt');
    # Run docker tests
    if (skip_docker) {
        record_info("Skip Docker", "Docker image tests skipped");
        script_run("echo 'INFO: Docker image tests skipped' >> /var/tmp/containers_3rd_party_log.txt");
    } else {
        install_docker_when_needed($host_distri);
        allow_selected_insecure_registries(runtime => 'docker');
        run_image_tests('docker', @images);
        clean_container_host(runtime => 'docker');
    }
    # Run podman tests
    if (skip_podman) {
        record_info("Skip Podman", "Podman image tests skipped");
        script_run("echo 'INFO: Podman image tests skipped' >> /var/tmp/containers_3rd_party_log.txt");
    } else {
        # In SLE we need to add the Containers module
        install_podman_when_needed($host_distri);
        allow_selected_insecure_registries(runtime => 'podman');
        run_image_tests('podman', @images);
        clean_container_host(runtime => 'podman');
    }
}

sub post_fail_hook {
    upload_image_logs();
}

sub post_run_hook {
    upload_image_logs();
}

1;
