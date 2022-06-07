#!perl
#
#  Copyright (C) 2000  A Cool Computer Science Company
#  Copyright (C) 2000  Wizzer Works
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
#  of Wizzer Works at msm@wizzer.com.
#
########################################################################
#
# ibGenmake.pl
#
# This program will generate a Makefile hierarchy based on a reference
# directory.
#
########################################################################

use English;
use Getopt::Long;
use File::Basename;
use File::Path;
use File::Find;
use Cwd;

$VERSION_HEADER = "RPM Package Makefile 1.0";
$quietMode = 0;
$srcDirRoot = ".";
$destDirRoot = ".";
$referenceWorkarea = "";
$makefileWorkarea = "";
$topDir = "";
$cwd = "";
@remainingArgs = "";


&main;

sub main
{
    my $status;
    my $currentDir = ".";

    # Parse command line options.
    &parseCommandLine;

    # Set top directory and current working directory.
    $topDir = getcwd();
    if ( ! $quietMode ) {
        print "Current working directory: $topDir\n";
    }
    $cwd = $topDir;
    $currentDir = $topDir;

    # If reference workarea doesn't exist, exit.
    $referenceWorkarea = &makeAbsolutePath( $referenceWorkarea );
    if ( ! $quietMode ) {
        print "Checking reference workarea: $referenceWorkarea\n";
    }

    if ( ! -d $referenceWorkarea ) {
        print( "***** Error: Problem encountered with reference workarea.\n" );
        print( "*****        $referenceWorkarea is not a valid directory.\n" );
        exit( 1 );
    }

    # If makefile workarea doesn't exist, create it.
    $makefileWorkarea = &makeAbsolutePath( $makefileWorkarea );
    if ( ! $quietMode ) {
        print "Creating makefile workarea: $makefileWorkarea\n";
    }

    if ( ! -d $makefileWorkarea ) {
        if ( $quietMode ) {
            mkpath( $makefileWorkarea, 0, 0777 );
	} else {
            mkpath( $makefileWorkarea, 1, 0777 );
	}
    }

    # Traverse the reference workarea creating a parallel directory
    # structure under the makefile workarea. At each level in
    # the reference workarea hierarchy the following subroutine,
    # createMakefileWorkarea, is called.
    &createMakefileWorkarea( $referenceWorkarea );

    return( 0 );
}

#
# Ouput a "usage" message to STDERR
#
sub usage
{
    print STDERR <<EOS;
usage: $PROGRAM_NAME [--q] [--srcDirRoot sourceDirectory]
                     [--destDirRoot destinationDirectory]
                     referenceWorkarea makefileWorkarea
EOS
}

#
# This routine creates the makefile workarea recursively as each level
# in the reference workarea is visited.
#
sub createMakefileWorkarea
{
    my $directory = shift;
    my @sources;
    my @subdirs;
    my $file = "";
    my $status = 0;

    if ( ! $quietMode ) {
        print "Processing reference directory: $directory\n";
    }

    $status = opendir( THISDIR, $directory );
    if ( $status ) {
        while ( defined( $file = readdir THISDIR ) ) {
            next if $file =~ /^\.\.?$/;  # skip "." and ".."
            next if $file =~ /^CVS$/;    # skip CVS directories
            if ( -d join( "/", $directory, $file ) ) {
                push( @subdirs, $file );
                if ( ! $quietMode ) {
                    print "\tSub Directory: $file\n";
		}
	    }
            elsif ( -f join( "/", $directory, $file ) ) {
                push( @sources, $file );
                if ( ! $quietMode ) {
                    print "\tSource File: $file\n";
		}
	    }
            else {
                if ( ! $quietMode ) {
                    print "\tUnknown File: $file\n";
		}
	    }
	}
        closedir( THISDIR );
    }

    # Create Makefile workarea directory, if necessary.
    my $makefileWorkareaDir = "";
    my $commonPath = substr( $directory, length( $referenceWorkarea ) );
    $makefileWorkareaDir = join( "", $makefileWorkarea, $commonPath );
    if ( ! $quietMode ) {
        print "Creating makefile workarea: $makefileWorkareaDir\n";
    }
    if ( ! -d $makefileWorkareaDir ) {
        if ( $quietMode ) {
            mkpath( $makefileWorkareaDir, 0, 0777 );
	} else {
            mkpath( $makefileWorkareaDir, 1, 0777 );
	}
    }

    # Output Makefile
    my $filename = "$makefileWorkareaDir/Makefile.pkg";
    $status = &outputMakefile( $filename, \@sources, \@subdirs );

    # Process sub-directories, if necessary.
    for $file (@subdirs) {
        $directory = join( "/", $directory, $file );
        &createMakefileWorkarea( $directory );
    }
}

#
# Ouput the Makefile header section to MAKEFILE
#
sub outputHeader
{
    # Determine today's date
    ($sec, $min, $hour, $day, $month, $year) = (localtime)[0..5];
    $dateStamp = $hour . ":" . $min . ":" . $sec;
    $dateStamp = $dateStamp . " ";
    $dateStamp = $dateStamp . ($month+1) . "/" . $day . "/" . ($year+1900);

    print MAKEFILE <<EOS;
#!make
#
################################## Header ##################################
#
# This Makefile was created by ibGenmake.pl. It is used for building
# RPM packages using the Wizzer Works Toolroot (www.wizzer.com).
#
#   Copyright (C) 2000 A Cool Computer Science Company
#   Copyright (C) 2000 Wizzer Works
#
# Date: $dateStamp
# Version: $VERSION_HEADER
#
# This file is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

EOS
}

#
# Ouput the setup section to MAKEFILE
#
sub outputSetup
{
    my $depth = shift;

    print MAKEFILE <<EOS;
################################### Setup ##################################
#
# This section establishes the location of the Wizzer Works Toolroot and
# includes the common definitions.
#
WZDEV_DIR = \$(ROOT)/usr/local/wizzer

DEPTH = $depth

include \$(ROOT)/usr/local/wizzer/include/make/commondefs

EOS
}

#
# Output the sources to MAKEFILE
#
sub outputSourceList
{
    my $outputRef = shift;
    my $line;

    print MAKEFILE <<EOS;
############################### Source List ################################
#
# This section lists the files which are to be collected for the RPM
# package.
#
SOURCES = \\
EOS

    # Output each source file on a separate line
    foreach $line (@$outputRef) {
        print( MAKEFILE "\t$line \\\n" );
    }

    print MAKEFILE <<EOS;
	\$(NULL)

EOS
}

#
# Output the sub-directories to MAKEFILE
#
sub outputSubdirList
{
    my $outputRef = shift;
    my $line;

    print MAKEFILE <<EOS;
############################ Sub Directory List ############################
#
# This section lists the sub directories which need to be traversed next
# in the Makefile directory hierarchy.
#
SUBDIRS = \\
EOS

    # Output each source file on a separate line
    foreach $line (@$outputRef) {
        print( MAKEFILE "\t$line \\\n" );
    }

    print MAKEFILE <<EOS;
	\$(NULL)

EOS
}

#
# Output the collection target to MAKEFILE
#
sub outputCollectTarget
{
    my $currentDir = shift;
    my $srcDirRoot = shift;
    my $destDirRoot = shift;

    $currentDir = substr( $currentDir, length( $topDir ) + 1 );

    print MAKEFILE <<EOS;
include \$(DEPTH)/build/Makefile.pkg

default all: collect
	\$(SUBDIRS_PACKAGE_MAKERULE)

include \$(COMMONRULES)

############################ Collection Target ############################
#
# This section defines the collection target for building the collection
# log used by the Wizzer Works configuration managment process.
#
collect:
	\$(IBCOLLECT) -log \$(PKG_COLLECT_LOG) \
                     -srcDir . \
                     -destDir $currentDir \
                     -tags PKG \
                     Makefile.pkg
	\$(IBCOLLECT) -log \$(SOURCE_COLLECT_LOG) \
                     -srcDir $srcDirRoot/$currentDir \
                     -destDir $destDirRoot/$currentDir \
                     -tags SRC \
                     \$(SOURCES)

EOS
}

#
# Set the global variables based on command line input.
# Croaks with message & usage if there is a problem.
#
sub parseCommandLine
{
    my $numArgs = scalar( @ARGV );

    if ( $numArgs > 5 ) {
        &usage();
        &croak( "too many arguments" );
    }

    # parse options
    my $status = GetOptions(
        "q" => \$quietMode,               # --q
        "srcDirRoot=s" => \$srcDirRoot,   # --srcDirRoot sourceDirectory
        "destDirRoot=s" => \$destDirRoot, # --destDirRoot destinationDirectory
        "<>" => \&remainingArgs );        # parse non-option arguments
    if ( ! $status ) {
        &usage();
        &croak("unknown option.");
    }

    # set makefile workarea
    $makefileWorkarea = pop @remainingArgs;
    if ( $makefileWorkarea eq "" ) {
        &usage();
        &croak( "missing makefile workarea." );
    }

    # set reference workarea
    $referenceWorkarea = pop @remainingArgs;
    if ( $referenceWorkarea eq "" ) {
        &usage();
        &croak( "missing reference workarea." );
    }
}

#
# Retrieve the sources in the specified directory.
#
# XXX - Phil
# Please finish this routine.
#
sub getSources
{
    my $directory = shift;
    my $status = 0;
    my @sources = "";

    $status = opendir( THISDIR, $directory );
    if ( $status ) {
        @sources = grep !/^\.\.?$/, readdir THISDIR;
        closedir( THISDIR );
    }

    return( $status, @sources );
}

#
# Retrieve the sub-directories in the specified directory.
#
# XXX - Phil
# Please finish this routine.
#
sub getSubdirs
{
    my $directory = shift;
    my $status = 0;
    my @subdirs = "";

    $status = opendir( THISDIR, $directory );
    if ( $status ) {
         @subdirs = grep !/^\.\.?$/, readdir THISDIR;
         closedir( THISDIR );
    }

    return( $status, @subdirs );
}

#
# Calculate the depth of the specified directory. It should be relative
# to the directory path stored in the global variable $topDir. Note
# that the path which is passed into this routine should have been
# previously expanded into an absolute path.
#
sub getDepth
{
    my $directoryRoot = shift;
    my $directory = shift;
    my $status = 0;
    my $depth = ".";

    if ( $directory eq $directoryRoot ) {
        $status = 1;
    } else {
        my $name = "";
        my $path = "";
        my $suffix = "";

        ($name, $path, $suffix) = fileparse($directory);
        while ( $path ne "/" ) {
            $depth = "$depth/..";

            # remove trailing path delimeter
            chop $path;

            # check if we've reached the directory root
            if ( $path eq $directoryRoot ) {
                $status = 1;
                last;
	    }

            # parse remaining path
            $directory = $path;
            ($name, $path, $suffix) = fileparse($directory);
        }

        if ( ! $status ) {
            $depth = "";
	}
    }

    return( $status, $depth );
}

#
# Print Makefile
#
sub outputMakefile
{
    my $outputFile = shift;
    my $sources = shift;
    my $subdirs = shift;
    my $currentDir = dirname( $outputFile );
    my $depth = "";
    my $status = 0;

    # calculate depth of current directory
    ( $status, $depth ) = &getDepth( $topDir, $currentDir );
    if ( ! $status ) {
        print( "***** Error: Problem encountered with Makefile $outputFile\n" );
        print( "*****        Unable to calculate depth of current working directory: $currentDir\n" );
        exit( 1 );
    }

    # open output file
    $status = open( MAKEFILE, "> $outputFile" );

    # output file
    if ( $status ) {
        # output the header section
        &outputHeader();

        # output the setup section
        &outputSetup( $depth );

        # output the sources section
        &outputSourceList( $sources );

        # outout the sub-directories section
        &outputSubdirList( $subdirs );

        # output the collect target section
        &outputCollectTarget( $currentDir, $srcDirRoot, $destDirRoot );

    } else {
        print( "***** Error: Problem encountered with Makefile $outputFile\n" );
        print( "*****        Unable to open file for creation.\n" );
        exit( 1 );
    }

    # close output file
    close( MAKEFILE );

    return $status;
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

#
# Process given string with \'s replaced by /'s.
#
sub unixSlashes
{
    my $string = shift;

    $string =~ s:\\:/:g;
    
    return $string;
}

#
# Create a canonical path without consecutive slashes and
# without trailing slashes (if any). Specified path is
# processed with .'s removed & ..'s applied.
#
sub canonicalPath
{
    my $path = shift;

    $path = &unixSlashes($path);

    my @parts = split( m:/:, $path );
    my @outParts = ();
    my $i = 0;

    for( $i=0; $i<scalar(@parts); $i++ ) {
        my $ithPart = $parts[$i];
        #print "ithPart = <$ithPart>\n";

        if ( $ithPart eq "" ) {
            # empty...don't add it!
            next;
        }
        if (($ithPart eq "." ) &&              # got a .
            (scalar(@outParts) > 0) &&         # got somewhere to be
            ($outParts[$#outParts] ne ".")) {  # and it's not a . too!
            # useless, skip it!
            next;
        }
        if (($ithPart eq "..") &&              # got a ..
            (scalar(@outParts) > 0) &&         # got somewhere to go up from
            ($outParts[$#outParts] ne "..")) { # and it's not a .. too!

            # remove "parent" (last value) from output!
            # XXX: not worrying about symlinks yet
            splice( @outParts, $#outParts, 1 );
            next;
        }

        @outParts = (@outParts,$ithPart);
    }
    my $outPath = join("/",@outParts);

    # if the original $path starts with a slash, make sure that the
    # one we return does, too!
    $outPath = "/$outPath" if ($path =~ m:^/:);

    #print "outpath=<$outPath>\n";
    return $outPath;
}

#
# Return TRUE iff given path is relative.
#
sub isRelativePath
{
    # establish canonical path
    my $path = &canonicalPath(shift);

    # extract first and second characters
    my $firstChar  = (length($path) > 0) ? substr( $path, 0, 1 ) : "";
    my $secondChar = (length($path) > 1) ? substr( $path, 1, 1 ) : "";

    if ( $firstChar eq "/" ) {
        # starts with a slash...absolute!
        return 0;
    }
    elsif (($firstChar =~ m/[a-zA-Z]/) && ($secondChar eq ":")) {
        # starts with a drive letter...absolute!
        return 0;
    }

    # still here? must be relative
    return 1;
}

#
# Make specified path absolute; if relative, is relative to $cwd.
#
sub makeAbsolutePath
{
    # establish canonical path
    my $path = &canonicalPath(shift);

    # check if already absolute
    if ( ! &isRelativePath($path) ) {
        #already absolute!
        return $path;
    }

    my $absPath = &canonicalPath( "$cwd/$path" );
    return $absPath;
}
