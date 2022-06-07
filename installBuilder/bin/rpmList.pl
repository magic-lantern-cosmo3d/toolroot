#!perl
#
#  Copyright (C) 2000  Wizzer Works Inc.
#
#  This Perl script is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  any later version.
#
#  This Perl script is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this Perl script; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
#  For information concerning this Perl script, contact Mark S. Millard,
#  of Wizzer Works Inc. at msm@wizzer.com.
#
########################################################################
#
# rpmList.pl
#
# This program will create a distribution list or BOM which will
# be compatible with rpmDiff.pl.
#
########################################################################

use English;
use Getopt::Long;
use File::Basename;

$VERSION_HEADER = "#RPM List Collection 1.0";
$rpmFile = 0;
$rpmInfo = 0;
$rpmDetail = 0;
$packageName = "";
@remainingArgs;

%sectionBegin = (
     "header" => "Begin Header {",
     "info" => "Begin Info {",
     "list" => "Begin List {",
     "detail" => "Begin Detail {",
);

%sectionEnd = (
    "header" => "}",
    "info" => "}",
    "list" => "}",
    "detail" => "}",
);

&main;

sub main
{
    my $status;
    my @info;
    my @detail;
    my @list;

    &parseCommandLine;

    # retrieve formatted info from package
    if ( $rpmInfo ) {
        ( $status, @info ) = &getInfo();
    }

    # retrieve list of files
    ( $status, @list ) = &getList();

    # retrieve detailed information
    if ( $rpmDetail ) {
        ( $status, @detail ) = &getDetail();
    }

    # output file
    if ( ! $status ) {
        # output the header section
        &outputHeader( $packageName );

        # output the info section
        if ( $rpmInfo ) {
            &outputInfo( \@info );
	}

        # output the list section
        &outputList( \@list );

        # outout the detail section
        if ( $rpmDetail ) {
            &outputDetail( \@detail );
	}

    } else {
        print( "***** Error: Problem encountered with package $packageName\n" );
        print( "*****        Valid package name?\n" );
        exit( 1 );
    }

    return( 0 );
}

#
# Ouput a "usage" message to STDERR
#
sub usage
{
    print STDERR <<EOS;
usage: $PROGRAM_NAME [--p] [--info] [--detail] package
EOS
}

#
# Ouput the BOM header section to STDOUT
#
sub outputHeader
{
    my $packageName = shift;
    my $name = basename( $packageName );

    ($sec, $min, $hour, $day, $month, $year) = (localtime)[0..5];
    $dateStamp = $hour . ":" . $min . ":" . $sec;
    $dateStamp = $dateStamp . " ";
    $dateStamp = $dateStamp . ($month+1) . "/" . $day . "/" . ($year+1900);

    print STDOUT <<EOS;
$VERSION_HEADER
#
################################## Header ##################################
#
# This data was created by rpmList.pl. It is a bill-of-materials
# collection for an RPM package. It may be used in conjunction with
# the rpmDiff.pl tool from Wizzer Works (www.wizzer.com).
#
$sectionBegin{"header"}
Package: $name
Date: $dateStamp
$sectionEnd{"header"}
EOS
}

#
# Ouput the BOM info section to STDOUT
#
sub outputInfo
{
    my $outputRef = shift;
    my $line;

    print STDOUT <<EOS;
#
################################### Info ###################################
#
# This section is created by using the '--queryformat' switch to rpm.
#
$sectionBegin{"info"}
EOS

    foreach $line (@$outputRef) {
        chop( $line );
        print ("$line\n" );
    }

    print STDOUT <<EOS;
$sectionEnd{"info"}
EOS
}

#
# Output the BOM to STDOUT
#
sub outputList
{
    my $outputRef = shift;
    my $line;

    print STDOUT <<EOS;
################################### List ###################################
#
# This section is created by using the '-l' switch to rpm.
#
$sectionBegin{"list"}
EOS

    foreach $line (@$outputRef) {
        chop( $line );
        print ("$line\n" );
    }

    print STDOUT <<EOS;
$sectionEnd{"list"}
EOS
}

#
# Output a detailsed BOM to STDOUT
#
sub outputDetail
{
    my $outputRef = shift;
    my $line;

    print STDOUT <<EOS;
################################## Detail ##################################
#
# This section is created by using the '--dump' switch to rpm.
#
# Format:
#     File Name
#     File Size
#     File Modification Date
#     MD5 Checksum               (128 bits)
#     File Mode
#     File Owner
#     File Group
#     Configuration File         (0 = no, 1 = yes)
#     Documentation File         (0 = no, 1 = yes)
#     Symbolic Link              (X = none)
#
$sectionBegin{"detail"}
EOS

    foreach $line (@$outputRef) {
        chop( $line );
        print ("$line\n" );
    }

    print STDOUT <<EOS;
$sectionEnd{"detail"}
EOS
}

#
# Set the global variables based on command line input.
# Croaks with message & usage if there is a problem.
#
sub parseCommandLine
{
    my $numArgs = scalar( @ARGV );

    if ( $numArgs > 4 ) {
        &usage();
        &croak( "too many arguments" );
    }

    # parse options
    my $status = GetOptions(
        "p" => \$rpmFile,              # --p
        "info" => \$rpmInfo,           # --info
        "detail" => \$rpmDetail,       # --detail
        "<>" => \&remainingArgs );     # parse non-option arguments
    if ( ! $status ) {
        &usage();
        &croak("unknown option.");
    }

    # set package name
    $packageName = pop @remainingArgs;
    if ( $packageName eq "" ) {
        &usage();
        &croak( "missing package name." );
    }
}

#
# Query RPM package and return output.
#
sub queryPackage
{
    my $packageName = shift;
    my $cmd = shift;

    # exec command
    #print( "Executing $cmd\n" );
    open( CMD, $cmd ) ||
         &croak( "internal error: couldn't system('$cmd')" );

    # get output
    my @output = <CMD>;

    close(CMD);
    my $status = $CHILD_ERROR;

    return( $status, @output );
}

#
# Query RPM package for info
#
sub getInfo
{
    my $status;
    my @info;

    my %infoFormat = (
        "name" => "\'Name: \%{NAME}\n'",
        "version" => "\'Version: \%{VERSION}\n'",
        "release" => "\'Release: \%{RELEASE}\n'",
        "installDate" => "\'Install Date: \%{INSTALLTIME:date}\n'",
        "group" => "\'Group: \%{GROUP}\n'",
        "size" => "\'Size: \%{SIZE}\n'",
        "packager" => "\'Packager: \%{PACKAGER}\n'",
        "relocation" => "\'Relocation: \%{INSTPREFIXES}\n'",
        "vendor" => "\'Vendor: \%{VENDOR}\n'",
        "buildDate" => "\'Build Date: \%{BUILDTIME:date}\n'",
        "buildHost" => "\'Build Host: \%{BUILDHOST}\n'",
        "source" => "\'Source RPM: \%{SOURCERPM}\n'",
        "license" => "\'License: \%{LICENSE}\n'",
        "summary" => "\'Summary: \%{SUMMARY}\n'",
        "description" => "\'Description: \%{DESCRIPTION}\n'",
    );

    if ( ! $rpmFile ) {
        # query installed RPM package
        my $cmd = join( " ", "rpm -q",
            "--queryformat", $infoFormat{"name"},
            "--queryformat", $infoFormat{"version"},
            "--queryformat", $infoFormat{"release"},
            "--queryformat", $infoFormat{"installDate"},
            "--queryformat", $infoFormat{"group"},
            "--queryformat", $infoFormat{"size"},
            "--queryformat", $infoFormat{"relocation"},
            "--queryformat", $infoFormat{"packager"},
            "--queryformat", $infoFormat{"vendor"},
            "--queryformat", $infoFormat{"buildDate"},
            "--queryformat", $infoFormat{"buildHost"},
            "--queryformat", $infoFormat{"source"},
            "--queryformat", $infoFormat{"license"},
            "--queryformat", $infoFormat{"summary"},
            "--queryformat", $infoFormat{"description"},
            $packageName, "|" );
        ( $status, @info ) = &queryPackage( $packageName, $cmd );
    } else {
        # query uninstalled RPM package file
        my $cmd = join( " ", "rpm -q",
            "--queryformat", $infoFormat{"name"},
            "--queryformat", $infoFormat{"version"},
            "--queryformat", $infoFormat{"release"},
            "--queryformat", $infoFormat{"installDate"},
            "--queryformat", $infoFormat{"group"},
            "--queryformat", $infoFormat{"size"},
            "--queryformat", $infoFormat{"relocation"},
            "--queryformat", $infoFormat{"packager"},
            "--queryformat", $infoFormat{"vendor"},
            "--queryformat", $infoFormat{"buildDate"},
            "--queryformat", $infoFormat{"buildHost"},
            "--queryformat", $infoFormat{"source"},
            "--queryformat", $infoFormat{"license"},
            "--queryformat", $infoFormat{"summary"},
            "--queryformat", $infoFormat{"description"},
            "-p", $packageName, "|" );
        ( $status, @info ) = &queryPackage( $packageName, $cmd );
    }

    return( $status, @info );
}

#
# Retrieve list of files in RPM package
#
sub getList
{
    my $status;
    my @list;

    if ( ! $rpmFile ) {
        # query installed RPM package
        my $cmd = join( " ", "rpm -ql", $packageName, "|" );
        ( $status, @list ) = &queryPackage( $packageName, $cmd );
    } else {
        # query uninstalled RPM package file
        my $cmd = join( " ", "rpm -qlp", $packageName, "|" );
        ( $status, @list ) = &queryPackage( $packageName, $cmd );
    }

    return( $status, @list );
}

#
# Retrieve detailed list of files in RPM package
#
sub getDetail
{
    my $status;
    my @list;

    if ( ! $rpmFile ) {
        # query installed RPM package
        my $cmd = join( " ", "rpm -ql --dump", $packageName, "|" );
        ( $status, @list ) = &queryPackage( $packageName, $cmd );
    } else {
        # query uninstalled RPM package file
        my $cmd = join( " ", "rpm -ql --dump -p", $packageName, "|" );
        ( $status, @list ) = &queryPackage( $packageName, $cmd );
    }

    return( $status, @list );
}

#
# Process remaining arguments in command line (non-options)
#
sub remainingArgs
{
    my $arg = shift;
    push( @remainingArgs, $arg );
}

#
# Print message and die.
#
sub croak
{
    my $msg = shift;
    print "\n*** $PROGRAM_NAME Croaking: $msg\n";
    exit( 1 );
}
