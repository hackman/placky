#!/usr/bin/perl
use strict;
use warnings;
use CGI qw(param);
use JSON::XS;
my $VERSION = 2.2;

umask(077);
my $t = int time().'000';

sub web_error {
	print "ERROR: $_[0]";
	die "$_[0]";
}

sub read_file {
	my $iface = shift;
	my $name = shift;
	my $save_file = "/var/spool/traffstats/$iface-$name";
	my $save = 0;
	my $content = 0;

	if ( -f $save_file ) {
		open my $read, '<', $save_file or web_error "Unable to open $save_file($!)";
		$save = <$read>;
		close $read;
	}

	open my $file, '<', "/sys/class/net/$iface/statistics/$name";
	$content = <$file>;
	close $file;
	$content =~ s/[\r\n\s]*$//g;

	open my $write, '>', $save_file or web_error "Unable to write to $save_file($!)";
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
	if (!defined $iface) {
		web_error 'Undefined param iface!';
	}
	if ($iface !~ /^[a-zA-Z0-9]+[._-]?([a-zA-Z0-9]+)*$/) {
		web_error 'Invalid interface name!';
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
	return %hash;
}

my @ret;
my @interface = sort(list_interfaces());
my $json = JSON::XS->new->ascii->pretty->allow_nonref;

print "Content-type: text/json\r\n\r\n";
# Default to the first interface in the interface array
if (defined(param('iface')) && param('iface') ne '') {
	my $req_iface = param('iface');
	my @interfaces = ();
	if ($req_iface =~ /^[a-z0-9.:-]+$/) {
		$req_iface =~ s/\.\././g;	# prevent path traversal
	} else {
		web_error "Invalid interface supplied\n";
	}
	if ($req_iface =~ /:/) {
		@interfaces = split /:/, $req_iface;
	} else {
		push(@interfaces, $req_iface);
	}
	foreach my $iface (@interfaces) {
		# Check if the interface actually exists
		if ( ! -d '/sys/class/net/' . $iface ) {
			web_error "Invalid interface selected";
		}
		push(@ret, [ $iface,  get_iface($iface) ]);
	}
}

if (defined(param('a')) && param('a') eq 'list') {
    print $json->encode(\@interface);
} else {
    print $json->encode(\@ret);
}
