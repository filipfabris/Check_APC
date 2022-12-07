#!/usr/bin/perl -w

use strict 'vars';
use Net::SNMP qw(ticks_to_time);;
use Switch;
use Getopt::Std;
use Time::Local;

# Command arguments
my %options=();
getopts("H:C:l:p:t:w:c:hu", \%options);

# Help message etc
(my $script_name = $0) =~ s/.\///;

my $help_info = <<END;
\n$script_name - v2.2

Usage:
-H  Address of hostname of UPS (required)
-C  SNMP community string (required)
-l  Command (optional, see command list)
-p  SNMP port (optional, defaults to port 161)
-t  Connection timeout (optional, default 10s)
-w  Warning threshold (optional, see commands)
-c  Critical threshold (optional, see commands)
-h  Use High Precision values for InputVoltage/OutputVoltage/OutputCurrent
-u  Script / connection errors will return unknown rather than critical

Commands (supplied with -l argument):

    manufacturer
        manufacturer details

    bat_status
        The status of the UPS batteries

    bat_capacity
        The remaining battery capacity expressed in percent of full capacity

Example:
$script_name -H ups1.domain.local -C public -l bat_status
END

# OIDs for the checks
my $oid_upsBasicIdentModel              = ".1.3.6.1.4.1.318.1.1.1.1.1.1.0";     # DISPLAYSTRING
my $oid_upsAdvIdentSerialNumber         = ".1.3.6.1.4.1.318.1.1.1.1.2.3.0";     # DISPLAYSTRING
my $oid_upsBasicBatteryStatus           = ".1.3.6.1.4.1.318.1.1.1.2.1.1.0";     # INTEGER {unknown(1),batteryNormal(2),batteryLow(3)}
my $oid_upsAdvBatteryCapacity           = ".1.3.6.1.4.1.318.1.1.1.2.2.1.0";     # GAUGE
my $oid_manufacturer = "1.3.6.1.4.1.534.1.1.1.0";

# Nagios exit codes
my $OKAY        = 0;
my $WARNING     = 1;
my $CRITICAL    = 2;
my $UNKNOWN     = 3;

# Command arguments and defaults
my $snmp_host           = $options{H};
my $snmp_community      = $options{C};
my $snmp_port           = $options{p} || 161;   # SNMP port default is 161
my $connection_timeout  = $options{t} || 10;    # Connection timeout default 10s
my $default_error       = (!defined $options{u}) ? $CRITICAL : $UNKNOWN;
my $high_precision      = (defined $options{h}) ? 1 : 0;
my $check_command       = $options{l};
my $critical_threshold  = $options{c};
my $warning_threshold   = $options{w};
my $session;
my $error;
my $exitCode;

# APCs have a maximum length of 15 characters for snmp community strings
if(defined $snmp_community) {$snmp_community = substr($snmp_community,0,15);}

# If we don't have the needed command line arguments exit with UNKNOWN.
if(!defined $options{H} || !defined $options{C}){
	print "$help_info Not all required options were specified.\n\n";
	exit $UNKNOWN;
}

# Setup the SNMP session
($session, $error) = Net::SNMP->session(
    -hostname   => $snmp_host,
    -community  => $snmp_community,
    -timeout    => $connection_timeout,
    -port       => $snmp_port,
    -translate  => [-timeticks => 0x0]
);

# If we cannot build the SMTP session, error and exit
if (!defined $session) {
    my $output_header = ($default_error == $CRITICAL) ? "CRITICAL" : "UNKNOWN";
    printf "$output_header: %s\n", $error;
    exit $default_error;
}

# Determine what we need to do based on the command input
if (!defined $options{l}) {  # If no command was given, just output the UPS model
    my $ups_model = query_oid($oid_upsBasicIdentModel);
    $session->close();
    print "$ups_model\n";
    exit $OKAY;
} else {    # Process the supplied command. Script will exit as soon as it has a result.
    switch($check_command){

        case "bat_status" {
            my $bat_status = query_oid($oid_upsBasicBatteryStatus);
            $session->close();
            if ($bat_status==2) {
                print "OK: Battery Status is Normal\n";
                exit $OKAY;
            } elsif ($bat_status==3) {
                print "CRITICAL: Battery Status is LOW and the UPS is unable to sustain the current load.\n";
                exit $CRITICAL;
            } else {
                print "UNKNOWN: Battery Status is UNKNOWN.\n";
                exit $UNKNOWN;
            }
        }
        case "bat_capacity" {
            my $bat_capacity = query_oid($oid_upsAdvBatteryCapacity);
            $session->close();
            if (defined $critical_threshold && defined $warning_threshold && $critical_threshold>$warning_threshold) {
                print "ERROR: Warning Threshold should be GREATER than Critical Threshold!\n";
                $exitCode = $UNKNOWN;
            } else {
                if (defined $critical_threshold && $bat_capacity <= $critical_threshold){
                    print "CRITICAL: Battery Capacity $bat_capacity% is LOWER or Equal than the critical threshold of $critical_threshold%";
                    $exitCode = $CRITICAL;
                } elsif (defined $warning_threshold && $bat_capacity <= $warning_threshold){
                    print "WARNING: Battery Capacity $bat_capacity% is LOWER or Equal than the warning threshold of $warning_threshold%";
                    $exitCode = $WARNING;
                }else{
                    print "OK: Battery Capacity is: $bat_capacity%";
                    $exitCode = $OKAY; 
                }
                print "|'Battery Capacity'=$bat_capacity".";$warning_threshold;$critical_threshold;0;100\n";
            }
            exit $exitCode;
        } case "manufacturer" {
            my $manufacturer = query_oid($oid_manufacturer);
            $session->close();
            if ($manufacturer eq "") {
                print "Could not read maufacturer name\n";
                exit $OKAY;
            } else {
                print "Manufacturer: ${manufacturer}.\n";
                exit $UNKNOWN;
            }
        } else {
            print "$script_name - '$check_command' is not a valid comand\n";
            exit $UNKNOWN;
        }

    }
}

sub query_oid {
# This function will poll the active SNMP session and return the value
# of the OID specified. Only inputs are OID. Will use global $session 
# variable for the session.
    my $oid = $_[0];
    my $response = $session->get_request(-varbindlist => [ $oid ],);

    # If there was a problem querying the OID error out and exit
    if (!defined $response) {
        my $output_header = ($default_error == $CRITICAL) ? "CRITICAL" : "UNKNOWN";
        printf "$output_header: %s\n", $session->error();
        $session->close();
        exit $default_error;
    }

    return $response->{$oid};
}

# The end. We shouldn't get here, but in case we do exit unknown
print "UNKNOWN: Unknown script error\n";
exit $UNKNOWN;
