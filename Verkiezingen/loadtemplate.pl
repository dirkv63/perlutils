=head1 NAME

loadtemplate.pl - This script will load agent template file on agent systems.

=head1 VERSION HISTORY

version 1.1 - 7 September 2006 DV

=over 4

=item *

Added Template Directory

=item *

Allow comments and empty lines in host file

=back

version 1.0 - 3 September 2006 DV

=over 4

=item *

Initial Release.

=back

=head1 DESCRIPTION

The purpose of this application is to load a template file on Unicenter Agents. The application needs the list of hosts and the commandfile to be executed. The template is copied to each host, then the commands to reload the template are executed. Finally the log file is copied to the central system and renamed for further reference.

=head2 Copy caiUxOs template to all hosts

 perl loadtemplate.pl -u username -p password -s UxHosts.txt -c loadUx.txt -a caiUxOs.config

=head2 Copy caiUxOs template to one particular host

 perl loadtemplate.pl -u username -p password -i hostname -c loadUx.txt -a caiUxOs.config

=head2 Copy and load all templates to all hosts

 perl loadtemplate.pl -u username -p password -s UxHosts.txt -c loadConfigs.txt -d template-directory

=head2 Copy and load all templates to one particular host

 perl loadtemplate.pl -u username -p password -i hostname -c loadConfigs.txt -d template-directory

=head2 Copy orapattern and restart log agent on one host

 perl loadtemplate.pl -u username -p password -i hostname -c loadorapattern.txt -a orapattern.txt

=head2 Copy Application Pattern and restart log agent on one host

 perl loadtemplate.pl -u username -p password -i hostname -c loadpatt.txt -a patt.txt

=head2 Command File loadConfigs.txt

Contents of the loadConfigs.txt command file: 

    # This script will stop the caiUxOs agent, load the template and
    # restart the caiUxOs agent.
    . /etc/profile
    echo load loadConfigs template at `date` > log.txt
    echo awservices status >> log.txt
    awservices status >> log.txt 2>&1
    echo clean_sadmin >> log.txt
    clean_sadmin >> log.txt 2>&1
    echo aws_sadmin start >> log.txt
    aws_sadmin start
    echo $AGENTWORKS_DIR/services/tools/foreach . "*.config" $AGENTWORKS_DIR/services/bin/ldconfig >> log.txt
    $AGENTWORKS_DIR/services/tools/foreach . "*.config" $AGENTWORKS_DIR/services/bin/ldconfig
    echo awservices stop >> log.txt
    awservices stop
    echo awservices start >> log.txt
    awservices start >> log.txt 2>&1

=head2 Command File loadorapattern.txt

Contents of the loadorapattern.txt command file:

    # This script will copy the reviewed orapattern.txt to 
    # its location and recycles the log agent.
    . /etc/profile
    echo Implement orapattern.txt at `date` > log.txt
    echo awservices status >> log.txt
    awservices status >> log.txt 2>&1
    echo cp orapattern.txt $AGENTWORKS_DIR/agents/config/caiLogA2  >> log.txt
    cp orapattern.txt $AGENTWORKS_DIR/agents/config/caiLogA2 >> log.txt 2>&1
    echo caiLogA2 stop >> log.txt
    caiLogA2 stop >> log.txt 2>&1
    echo caiLogA2 start >> log.txt
    caiLogA2 start >> log.txt 2>&1

=head2 Command File loadpatt.txt

Contents of the loadpatt.txt command file:

    # This script will copy the reviewed patt.txt to 
    # its location and recycles the log agent.
    . /etc/profile
    echo Implement patt.txt at `date` > log.txt
    echo awservices status >> log.txt
    awservices status >> log.txt 2>&1
    echo cp patt.txt $AGENTWORKS_DIR/agents/config/caiLogA2  >> log.txt
    cp patt.txt $AGENTWORKS_DIR/agents/config/caiLogA2 >> log.txt 2>&1
    echo caiLogA2 stop >> log.txt
    caiLogA2 stop >> log.txt 2>&1
    echo caiLogA2 start >> log.txt
    caiLogA2 start >> log.txt 2>&1

=head1 SYNOPSIS

 loadtemplate.pl [-t] [-l logfile_directory]  [-u username] [-p password] [-s hosts-file | -i host] -c command-file [-a agent-template | -d template-directory]

 loadtemplate.pl -h	Usage Information
 loadtemplate.pl -h 1	Usage Information and Options description
 loadtemplate.pl -h 2	Full documentation

=head1 OPTIONS

=over 4

=item B<-t>

if set, then trace messages will be displayed. 

=item B<-l logfile_directory>

default: c:\temp

=item B<-u username>

Username that can execute commands.

=item B<-p password>

Password associated with username.

=item B<-s hosts-file>

File containing hostnames to check. Each hostname must be on a single line. Empty lines or lines starting with # are ignored.

=item B<-i host>

Single host where to send opreload command to.

=item B<-c command-line>

File containing all commands to be executed. Each command must log output to the file log.txt in the default directory.

=item B<-a agent-template>

Agent template file that will be copied to the remote system containing the new configuration.

=item B<-d template_directory>

Template directory that will be copied to the remote system containing the new configurations. The script will add /*.config to the agent directory. Either the agent template or the template directory must be specified.

=back

=head1 ADDITIONAL DOCUMENTATION

=cut

###########
# Variables
###########

my ($logdir, $username, $pwd, $hostfile, $hostname, $cmds, $template, $scriptname);
my $cfg_dir = "D:/dirk/NSM.config/atech/configsets";

#####
# use
#####

use warnings;			    # show warnings
use strict 'vars';
use strict 'refs';
use strict 'subs';
use Getopt::Std;		    # Input parameter handling
use Pod::Usage;			    # Usage printing
use File::Basename;		    # For logfilename translation
use Log;
use OpexAccess;

#############
# subroutines
#############

sub exit_application($) {
    my($return_code) = @_;
    close HOSTS;
    logging("Exit application with return code $return_code\n");
    close_log();
    exit $return_code;
}

=pod

=head2 Trim

This section is used to get rid of leading or trailing blanks. It has been
copied from the Perl Cookbook.

=cut

sub trim {
    my @out = @_;
    for (@out) {
        s/^\s+//;
        s/\s+$//;
    }
    return wantarray ? @out : $out[0];
}

=pod

=head2 Execute Command

This procedure accepts a system command, executes the command and checks on a 0 return code. If no 0 return code, then an error occured and control is transferred to the Display Error procedure.

=cut

sub execute_command($) {
    my ($command) = @_;
    if (system($command) == 0) {
	logging("Command $command - Return code 0");
    } else {
	my $ErrorString = "Could not execute command $command";
	error($ErrorString);
	exit_application(1);
#	display_error($ErrorString);
    }
}

sub handle_host($) {
    my ($host) = @_;
    # Verify if $host exist
    # Copy template file to $host
    my $cmd = "pscp -pw $pwd $template $username"."@"."$host:";
    execute_command($cmd);
    # Execute commands on $host
    $cmd = "putty -ssh -pw $pwd -m $cmds $username"."@"."$host";
    execute_command($cmd);
    # Copy logfile to local system, rename
    my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    my $datetime = sprintf("%04d%02d%02d%02d%02d%02d", $year+1900, $mon+1, $mday,$hour,$min,$sec);
    $cmd = "pscp -pw $pwd $username"."@"."$host:log.txt $logdir/".$host."_".$scriptname."_".$datetime."_log.txt";
    execute_command($cmd);
}

######
# Main
######

# Handle input values
my %options;
getopts("l:th:u:p:s:c:a:d:i:", \%options) or pod2usage(-verbose => 0);
# Print Usage
if (defined $options{"h"}) {
    if ($options{"h"} == 0) {
        pod2usage(-verbose => 0);
    } elsif ($options{"h"} == 1) {
        pod2usage(-verbose => 1);
    } else {
	pod2usage(-verbose => 2);
    }
}
# Trace required?
if (defined $options{"t"}) {
    Log::trace_flag(1);
    trace("Trace enabled");
}
# Find log file directory
if ($options{"l"}) {
    $logdir = logdir($options{"l"});
} else {
    $logdir=logdir();
}
if (-d $logdir) {
    trace("Logdir: $logdir");
} else {
    pod2usage(-msg     => "Cannot find log directory ".logdir,
	      -verbose => 0);
}
# Logdir found, start logging
open_log();
logging("Start application");
# Find source directory
if ($options{"u"}) {
    $username = $options{"u"};
} else {
    $username = $atechUser;
}
if ($options{"p"}) {
    $pwd = $options{"p"};
} else {
    $pwd = $atechKey;
}
if ($options{"s"}) {
    $hostfile = $options{"s"};
    if (not(-r $hostfile)) {
	error("Serverfile $hostfile not readable, exiting...");
	exit_application(1);
    }
}
if ($options{"i"}) {
    $hostname = $options{"i"};
}
if ($options{"c"}) {
    $cmds = $options{"c"};
} else {
    error ("Command file not defined, exiting...");
    exit_application(1);
}
if (not(-r $cmds)) {
    error("Commandfile $cmds not readable, exiting...");
    exit_application(1);
}
if ($options{"a"}) {
    $template = $options{"a"};
    if (not(-r $template)) {
	error("Agenttemplate $template not readable, exiting...");
	exit_application(1);
    }
}
if ($options{"d"}) {
    if (defined $template) {
	my $errmsg = "Template file $template already specified, cannot specify directory " . $options{"d"} . " as well, exiting...";
	error($errmsg);
	exit_application(1);
    }
    $template = $options{"d"};
    if (-d $template) {
	$template .= "/*.config";
    } else {
	error("Template directory $template not a directory, exiting...");
	exit_application(1);
    }
}
while (my($key, $value) = each %options) {
    logging("$key: $value");
    trace("$key: $value");
}
# End handle input values

# Verify that Template has been defined
if (not defined $template) {
    error("Template file or directory not defined, exiting...");
    exit_application(1);
}

# Now verify that one and only one option is selected (hostname or hostfile)
if ((not defined $hostname) and (not defined $hostfile)) {
    error("Hostname or hostfile not specified, exiting...");
    exit_application(1);
}
if ((defined $hostname) and (defined $hostfile)) {
    error("Hostname $hostname and hostfile $hostfile both defined, please select only one of both.");
    exit_application(1);
}

# Find scriptname to store in host logfile
($scriptname, undef) = split(/\./, basename($0));

if (defined $hostfile) {
    # Read hosts file, handle hosts one by one
    my $openres = open(HOSTS, $hostfile);
    if (not(defined $openres)) {
	error("Could not open serverfile $hostfile for reading, exiting...");
	exit_application(1);
    }
    while (my $host = <HOSTS>) {
	chomp $host;
	# Ignore any line that does not start with character
	if ($host =~ /^[A-Za-z]/) {
	    $host = trim($host);
	    handle_host($host);
	}
    }
} else {
    handle_host($hostname);
}

exit_application(0);

=pod

=head1 To Do

=over 4

=item *

Add possibility to specify one host only.

=item *

Implement host verification

=back

