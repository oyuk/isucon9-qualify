#!/usr/bin/perl

use strict;
use warnings;
use JSON::PP;
use Test::More;

sub cmd_json {
    my @cmd_args = @_;
    my @cmd = qw!/usr/local/bin/aliyun --mode EcsRamRole --region=ap-northeast1!;
    push @cmd, @cmd_args;
    open(my $pipe, "-|", @cmd) or die $!;
    my $buffer="";
    while (<$pipe>) {
        $buffer .= $_;
    }
    close($pipe) or die $!;
    JSON::PP::decode_json($buffer);
}

sub instance_id {
    my @cmd = qw!curl -s http://100.100.100.200/latest/meta-data/instance-id!;
    open(my $pipe, "-|", @cmd) or die $!;
    my $buffer="";
    while (<$pipe>) {
        $buffer .= $_;
    }
    close($pipe) or die $!;
    return $buffer;
}

# AccountId
my $identity = eval {
    cmd_json('sts','GetCallerIdentity');
};
die "Failed to retrieve Instance information. RAM role is not setup correctly: $@" if $@;

printf("AccountId: %s\n", $identity->{AccountId});

# Instance ID
my $instace_id = eval {
    instance_id();
};
die "Failed to retrieve Instance ID. Could not access metadata api: $@" if $@;
printf("InstanceId: %s\n", $instace_id);

# Instances
my $instaces = cmd_json(qw/ecs DescribeInstances --RegionId ap-northeast-1/);
my @instaces = @{$instaces->{Instances}->{Instance}};

my $instance;
for my $i (@instaces) {
    next if $i->{InstanceId} ne $instace_id;
    next if $i->{Status} ne "Running";
    $instance = $i;
}

die "Could not find this instance. id: $instace_id" unless $instance;

my $disks = cmd_json(qw/ecs DescribeDisks --RegionId ap-northeast-1 --InstanceId/,$instance->{InstanceId});
my @disks = @{$disks->{Disks}->{Disk}};

is($instance->{InstanceChargeType},'PostPaid','InstanceChargeType should be PostPaid');
is($instance->{ZoneId},'ap-northeast-1a','ZoneId should be ap-northeast-1a');
is($instance->{InstanceType},'ecs.sn1ne.large','InstanceType should be ecs.sn1ne.large');
is($instance->{Cpu},'2','Cpu should be 2 vCPU');
is($instance->{Memory},'4096','Memory should be 4096 MB');
is($instance->{InternetChargeType},'PayByTraffic','InternetChargeType should be PayByTraffic');
is($instance->{InternetMaxBandwidthOut},'100','InternetMaxBandwidthOut should be 100');

is(scalar @disks, 1, 'number of Disks should be 1');

for my $disk (@disks) {
    is($disk->{Type}, 'system', 'Disk Type should be system');
    is($disk->{Size}, '40', 'Disk Size should be 40 GiB');
    is($disk->{Category}, 'cloud_efficiency', 'Disk Category should be cloud_efficiency(Ultra Disk)');
}

done_testing();
