#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(param);
use JSON::XS;
my $VERSION = 1.0;

print "Content-type: text/json\r\n\r\n";
umask(077);
my $t = int time().'000';

sub read_file {
	my $iface = shift;
	my $name = shift;
        if(!defined $iface || !defined $name){
            die "Undefined params!";
        }
	my $save_file = "/var/spool/traffstats/$iface-$name";
	my $save = 0;
	my $content = 0;

	if ( -f $save_file ) {
		open my $read, '<', $save_file or die $!;
		$save = <$read>;
		close $read;
	}

	open my $file, '<', "/sys/class/net/$iface/statistics/$name";
	$content = <$file>;
	close $file;
	$content =~ s/[\r\n\s]*$//g;

	open my $write, '>', $save_file or die $!;
	print $write $content;
	close $write; 
	return $content - $save;
}

sub list_interfaces {
	my @dirlist;
	opendir my $sys, '/sys/class/net/';
	while(my $entry = readdir($sys)) {
		next if ($entry =~ /^[._]/);
		next if ($entry eq 'lo');
		push(@dirlist, $entry);
	}
	closedir $sys;
	return @dirlist;
}

sub get_iface {
	my $iface = shift;
        if(!defined $iface){
            die "Undefined param iface!";
        }
	my $rx_bytes = read_file($iface, 'rx_bytes');
	my $tx_bytes = read_file($iface, 'tx_bytes');
	my $rx_packets = read_file($iface, 'rx_packets');
	my $tx_packets = read_file($iface, 'tx_packets');
	my %hash = (
		"rx_bytes" => [$t,$rx_bytes/1000],
		"tx_bytes"=> [$t,$tx_bytes/1000],
		"rx_packets" => [$t,$rx_packets],
		"tx_packets" => [$t,$tx_packets]
	);
        return $hash;
}

my %ret;
my @interface = list_interfaces();
my $json = JSON::XS->new->ascii->pretty->allow_nonref;

# Default to the first interface in the interface array
if (defined(param('iface')) && param('iface') ne '') {
	# Check if the interface actually exists
	if ( ! -d "/sys/class/net/" . param('iface') ) {
		die "Invalid interface selected";
	}
	%ret = get_iface(param('iface'));
} else {
	%ret = get_iface($interface[0]);
}

if (defined(param('a')) && param('a') eq 'list') {
    print $json->encode(\@interface);
} else {
    print $json->encode(\%ret);
}
