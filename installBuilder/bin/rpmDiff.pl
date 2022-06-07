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
# rpmDiff.pl
#
# This program compares two packages to determine if they are equal or not.
# The candidate may either be an installed RPM package, an RPM file (.rpm
# extension) or a file containing a list of files belonging to the package
# in question. Likewise, the master may either be an installed RPM package,
# an RPM file or a file containing the bill-of-materials against which the
# candidate is being compared with.
#   If the candidate is missing entries, they are placed in "missing".
#   If the candidate has extra entries, they are placed in "extra".
#   If the candidate had missing or extra, this program returns 1, else 0.
#
# This file should be interpretted by perl 5.
#
# $Id: rpmDiff.pl,v 1.1 2004/05/26 19:36:06 msm Exp $
#
########################################################################

use English;      # use more readable names for perl variables!
use Getopt::Long; # for parsing command line options

#globals set from command line
$candidateFile = "";
$masterFile     = "";
$expandEnvVars   = 1;  # by default expand envVars in filenames
@remainingArgs;

#the master & candidate!
# see "readCollection()" for a description of the format
%master    = ();
%candidate = ();
@masterDetail;
@candidateDetail;

#useful globals
#$cwd = &unixSlashes(`cd`);    chop($cwd);
$cwd = &unixSlashes(`pwd`);    chop($cwd);

# "constants"
$collectionHeader = "#RPM List Collection 1.0";
$missingFile      = "missing";
$extraFile        = "extra";

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

#
# Compare candidate to master, writing missing & extra if needed!
#
sub main
{
    my $status = 0;
    my @output = "";

    &parseCommandLine;

    # read master
    if ($mpackage) {
        # query list from a .rpm file
        my $cmd = join( " ", "rpm -qlp", $masterFile, "|" );
        ($status, %master) = &queryPackage( $masterFile, $cmd );
        if ( $status ) {
            &croak( "unable to query master $masterFile" );
	}

        if ( $detail ) {
            my $cmd = join( " ", "rpm -ql --dump -p", $masterFile, "|" );
            ($status, @masterDetail) = &queryPackageDetail( $masterFile, $cmd );
            if ( $status ) {
                &croak( "unable to query detail for master $masterFile" );
	    }
	}
    } elsif ($mlist) {
        # read list from a regular file
        %master = &readCollection( $masterFile );

        if ( $detail ) {
            @masterDetail = &readCollectionDetail( $masterFile );
	}
    } else {
        # query list from an installed package
        my $cmd = join( " ", "rpm -ql", $masterFile, "|" );
        ($status, %master) = &queryPackage( $masterFile, $cmd );
        if ( $status ) {
            &croak( "unable to query master $masterFile" );
	}

        if ( $detail ) {
            my $cmd = join( " ", "rpm -ql --dump", $masterFile, "|" );
            ($status, @masterDetail) = &queryPackageDetail( $masterFile, $cmd );
            if ( $status ) {
                &croak( "unable to query detail for master $masterFile" );
	    }
	}
    }

    # read candidate
    if ($cpackage) {
        # query list from a .rpm file
        my $cmd = join( " ", "rpm -qlp", $candidateFile, "|" );
        ($status, %candidate) = &queryPackage( $candidateFile, $cmd );
        if ( $status ) {
            &croak( "unable to query candidate $candidateFile" );
	}

        if ( $detail ) {
            my $cmd = join( " ", "rpm -ql --dump -p", $candidateFile, "|" );
            ($status, @candidateDetail) = &queryPackageDetail( $candidateFile, $cmd );
            if ( $status ) {
                &croak( "unable to query detail for candidate $candidateFile" );
	    }
	}
    } elsif ($clist) {
        # read list from a regular file
        %candidate = &readCollection( $candidateFile );

        if ( $detail ) {
            @candidateDetail = &readCollectionDetail( $candidateFile );
	}
    } else {
        # query list from an installed package
        my $cmd = join( " ", "rpm -ql", $candidateFile, "|" );
        ($status, %candidate) = &queryPackage( $candidateFile, $cmd );
        if ( $status ) {
            &croak( "unable to query candidate $candidateFile" );
	}

        if ( $detail ) {
            my $cmd = join( " ", "rpm -ql --dump", $candidateFile, "|" );
            ($status, @candidateDetail) = &queryPackageDetail( $candidateFile, $cmd );
            if ( $status ) {
                &croak( "unable to query detail for candidate $candidateFile" );
	    }
	}
    }

    # compare BOM lists
    @missing   = &findMissing( \%master,    \%candidate );
    @extra     = &findMissing( \%candidate, \%master    );

    # compare details of BOM contents
    if  ( $detail ) {
        # compare number of entries
        my $num = $#masterDetail;
        if ( $#masterDetail != $#candidateDetail ) {
            if ( $#masterDetail > $#candidateDetail ) {
                $num = $#candidateDetail;
	    } else {
                $num = $#masterDetail;
	    }
            print STDOUT "*** Warning: $masterFile and $candidateFile have different number of entries\n";
            print STDOUT "*** in detail section. Processing only the first $num entries.\n";
	}

        # compare actual details
        $detailsMismatch = compareDetails( \@masterDetail, \@candidateDetail, $num );
    }

    my $hasMissing = (scalar( @missing ) != 0);
    my $hasExtra   = (scalar( @extra   ) != 0);

    if ( $hasMissing ) {
        print STDERR join("\n\t", 
                  "*** Error: missing from $candidateFile:",
                  @missing ), "\n";
        &writeList( $missingFile, @missing );
    }

    if ( $hasExtra ) {
        print STDERR join("\n\t", 
                  "*** Error: extra in $candidateFile:",
                  @extra ), "\n";
        &writeList( $extraFile, @extra );
    }

    if ( $detailsMismatch ) {
        print STDERR join("\n\t", 
                  "*** Error: details broken in $candidateFile"), "\n";
    }

    if ( $hasMissing || $hasExtra || $detailsMismatch) {
        exit( 1 );
    }
    else {
        exit( 0 );
    }
}

#
# Output a "usage" message to STDERR
#
sub usage
{
    print STDERR <<EOS;
usage: $PROGRAM_NAME [--detail] [--mpackage= | --mlist=]master [--cpackage= | --clist=]candidate
EOS
}

#
# Set global variables based on command line arguments.
# Croaks with message & usage if there is a problem.
#
sub parseCommandLine
{
    my $numArgs = scalar( @ARGV );

    if ( $numArgs < 2 ) {
        &usage();
        &croak("too few arguments");
    }

    # parse options
    $status = GetOptions(
        "verbose" => \$verbose,        # --verbose
        "cpackage=s" => \$cpackage,    # --cpackage=string
        "clist=s" => \$clist,          # --clist=string
        "mpackage=s" => \$mpackage,    # --mpackage=string
        "mlist=s" => \$mlist,          # --mlist=string
        "detail" => \$detail,          # --detail
        "dontExpandEnvVars" => \$dontExpandEnvVars,
        "<>" => \&remainingArgs );     # parse non-option arguments
    if ( ! $status ) {
        &usage();
        &croak("unknown option.");
    }

    # check semantics
    if ($cpackage && $clist) {
        &usage();
        &croak( "--cpackage= and --clist= are mutually exclusive arguments." );
    }

    if ($mpackage && $mlist) {
        &usage();
        &croak( "--mpackage= and --mlist= are mutually exclusive arguments." );
    }

    # set candidate file
    if ($cpackage) {
        $candidateFile = $cpackage;
    } elsif ($clist) {
        $candidateFile = $clist;
    } else {
        $candidateFile = pop @remainingArgs;
    }

    # set master file
    if ($mpackage) {
        $masterFile = $mpackage;
    } elsif ($mlist) {
        $masterFile = $mlist;
    } else {
        $masterFile = pop @remainingArgs;
    }

    if ($dontExpandEnvVars) {
        $expandEnvVars = 0;
    }
}

#
# Process remaining arguments on the command line (non-options).
#
sub remainingArgs
{
    my $arg = shift;
    push( @remainingArgs, $arg );
}

#
# Return given string with \'s protected by \'ing them (ie: "\" becomes "\\")
#
sub protectBackslashes
{
    #args
    my $string = shift;

    $string =~ s:\\:\\\\:g;
    return $string;
}

#
# Returns a value of STRING with any environment variables expanded OR croaks.
#
# Note: Backslashes are quoted before evaluation!
#        and variables with non-alphanumeric names are not expanded!
#
sub evalWithEnvVars
{
    # args
    my $string = shift;
    
    # decide what to eval...
    $string = &protectBackslashes($string);   # protect \s from being used up!

    my $toEval = "";
    my $envVar;
    foreach $envVar ( keys %ENV ) {
        if ( $envVar =~ m/\W/ ) {
            # there are non-word characters in the envVar's name
            # skip it!
            #print "skipping <$envVar>\n";
            next;
        }

        my $envVarValue = $ENV{$envVar};
        # quote everything in sight!
        $envVarValue =~ s/(\W)/\\$1/g;   # see page 106 in perl book
        $toEval .= qq{\$$envVar = "$envVarValue";\n};
    }
    $toEval .= qq{\n\nqq\{$string\};};

    #printprint "{$toEval}\n";

    my $expanded = eval $toEval;
    if ( $EVAL_ERROR ) {
        &croak( "trouble with variables in <$string>" );
    }

    return $expanded;
}

#
# Return an associative array with each key being a string from the collection.
# The strings will be trimmed for leading/trailing whitespace
# and have sequences of whitespace compressed to one space.
#
# Note: croaks if can't read the file or there are duplicates in the file.
#
sub readCollection
{
    #args
    my @files = @_;

    #locals
    my $val;
    my $file;
    my @lines = ();

    for $file (@files) {
        my $listFound = 0;

        if ( $verbose ) {
            print STDOUT "Reading collection $file ...\n";
	}

        # read the file into an array!
        open(IN, "<$file") || &croak("can't read from $file: $ERRNO");

        # check header!
        my $firstLine = <IN>;
        chop( $firstLine );
        if ( &clip($firstLine) ne $collectionHeader ) {
          &croak( "Bad header in $file\n" .
               "\texpected '$collectionHeader' got '$firstLine'" );
        } 

        #get remaining lines
        my @fileLines;
        my $readList = 0;
        while ( <IN> ) {
            my $line = $_;

            chop( $line );
            if ( $line eq $sectionBegin{"list"} ) {
                $readList = 1;
                if ( $verbose ) {
                    print STDOUT "Processing List Section ...\n";
		}
                $listFound = 1;
                next;
	    } elsif ($line eq $sectionEnd{"list"} ) {
                $readList = 0;
                next;
	    }

            if ( $readList ) {
                if ( $expandEnvVars  ) {
                    $line = &evalWithEnvVars($line);
                }
                push( @fileLines, $line );
	    }
        }
        @lines = (@lines, @fileLines);

        close( IN );

        if ( ! $listFound ) {
            print STDERR "*** Error: List section not found in $file\n";
            exit( 1 );
        }
    }

    # trim & compress whitespace for each line
    grep( $_ = &clip(&compressWhitespace($_)), @lines );

    grep( s/#.*$//,  @lines );           # strip comments 
    @lines = grep( !/^\s*$/,  @lines );  # strip empty lines

    # remove empty lines
    my @nonEmptyLines = ();
    for $val ( @lines ) {
        @nonEmptyLines = (@nonEmptyLines, $val) if ($val ne "");
    }
    @lines = @nonEmptyLines;

    my @dups = &findDuplicates( @lines );
    if ( scalar(@dups) > 0 ) {
        &croak( join( "\n\t",
                  "there are duplicate entries in [@files]:",
                  @dups ) );
    }

    my %collection = ();
    for $val (@lines) {
        $collection{$val} = 1;
    }

    return %collection;
}

#
# Return an array of references to a collection record. Each record will
# contain information for each file in the BOM.
# The strings will be trimmed for leading/trailing whitespace
# and have sequences of whitespace compressed to one space.
#
# Note: croaks if can't read the file or there are duplicates in the file.
#
sub readCollectionDetail
{
    #args
    my @files = @_;

    #locals
    my $val;
    my $file;
    my @lines = ();

    for $file (@files) {
        my $detailFound = 0;

        if ( $verbose ) {
            print STDOUT "Reading detail for collection $file ...\n";
	}

        # read the file into an array!
        open(IN, "<$file") || &croak("can't read from $file: $ERRNO");

        # check header!
        my $firstLine = <IN>;
        chop( $firstLine );
        if ( &clip($firstLine) ne $collectionHeader ) {
          &croak( "Bad header in $file\n" .
               "\texpected '$collectionHeader' got '$firstLine'" );
        } 

        #get remaining lines
        my @fileLines;
        my $readList = 0;
        while ( <IN> ) {
            my $line = $_;

            chop( $line );
            if ( $line eq $sectionBegin{"detail"} ) {
                $readList = 1;
                if ( $verbose ) {
                    print STDOUT "Processing Detail Section ...\n";
		}
                $detailFound = 1;
                next;
	    } elsif ($line eq $sectionEnd{"detail"} ) {
                $readList = 0;
                next;
	    }

            if ( $readList ) {
                if ( $expandEnvVars  ) {
                    $line = &evalWithEnvVars($line);
                }
                push( @fileLines, $line );
	    }
        }
        @lines = (@lines, @fileLines);

        close( IN );

        if ( ! $detailFound ) {
            print STDERR "*** Error: Detail section not found in $file\n";
            exit( 1 );
        }
    }

    # trim & compress whitespace for each line
    grep( $_ = &clip(&compressWhitespace($_)), @lines );

    grep( s/#.*$//,  @lines );           # strip comments 
    @lines = grep( !/^\s*$/,  @lines );  # strip empty lines

    # remove empty lines
    my @nonEmptyLines = ();
    for $val ( @lines ) {
        @nonEmptyLines = (@nonEmptyLines, $val) if ($val ne "");
    }
    @lines = @nonEmptyLines;

    my @dups = &findDuplicates( @lines );
    if ( scalar(@dups) > 0 ) {
        &croak( join( "\n\t",
                  "there are duplicate entries in [@files]:",
                  @dups ) );
    }

    my @collection;
    for $val (@lines) {
        my $collectionRec = {};
        my @fields = split ' ', $val;

        $collectionRec->{"filename"} = $fields[0];
        $collectionRec->{"size"} = $fields[1];
        $collectionRec->{"modified"} = $fields[2];
        $collectionRec->{"checksum"} = $fields[3];
        $collectionRec->{"mode"} = $fields[4];
        $collectionRec->{"owner"} = $fields[5];
        $collectionRec->{"group"} = $fields[6];
        $collectionRec->{"config"} = $fields[7];
        $collectionRec->{"doc"} = $fields[8];
        $collectionRec->{"dev"} = $fields[9];
        $collectionRec->{"symlink"} = $fields[10];

        push @collection, $collectionRec;
    }

    #printDetails( \@collection );

    return @collection;
}

#
# Retrieve a list of files from an installed RPM package.
#
sub queryPackage
{
    my $packageName = shift;
    my $cmd = shift;

    if ( $verbose ) {
        print STDOUT "Querying package $packageName ...\n";
    }

    # exec command
    open( CMD, $cmd ) ||
         &croak( "internal error: couldn't system('$cmd')" );

    # get output
    my @output = <CMD>;

    close(CMD);
    $status = $CHILD_ERROR;

    my %collection = ();
    my $val;
    for $val (@output) {
        chop( $val );
        $collection{$val} = 1;
    }

    return( $status, %collection );
}

#
# Retrieve a list of files from an installed RPM package.
#
sub queryPackageDetail
{
    my $packageName = shift;
    my $cmd = shift;
    my @collection;

    if ( $verbose ) {
        print STDOUT "Querying package detail for $packageName ...\n";
    }

    # exec command
    open( CMD, $cmd ) ||
         &croak( "internal error: couldn't system('$cmd')" );

    # get output
    my @output = <CMD>;

    close(CMD);
    $status = $CHILD_ERROR;

    my $val;
    for $val (@output) {
        chop( $val );

        my $collectionRec = {};
        my @fields = split ' ', $val;

        $collectionRec->{"filename"} = $fields[0];
        $collectionRec->{"size"} = $fields[1];
        $collectionRec->{"modified"} = $fields[2];
        $collectionRec->{"checksum"} = $fields[3];
        $collectionRec->{"mode"} = $fields[4];
        $collectionRec->{"owner"} = $fields[5];
        $collectionRec->{"group"} = $fields[6];
        $collectionRec->{"config"} = $fields[7];
        $collectionRec->{"doc"} = $fields[8];
        $collectionRec->{"dev"} = $fields[9];
        $collectionRec->{"symlink"} = $fields[10];

        push @collection, $collectionRec;
    }

    #printDetails( \@collection );

    return( $status, @collection );
}

#
# Returns a list of keys in %$master which aren't in %$candidate.
#
sub findMissing
{
    #args
    my $master    = shift;
    my $candidate = shift;

    #
    my @missing = ();
    my $val;
    for $val (keys %$master) {
        if ( !defined( $$candidate{$val} ) ) {
            @missing = (@missing, $val);    
        }
    }

    return @missing;
}

#
# Output entries in given list to outputFile or croaks trying!
#
sub writeList
{
    #args
    my $file = shift;
    my @vals = @_;

    #
    open(OUTPUT,">$file") || &croak("can't open '$file' to write: $ERRNO");

    my $val;
    for $val ( @vals ) {
        print OUTPUT "$val\n";
    }

    close( OUTPUT );
}


#
# Print message and exits.
#
sub croak
{
    my $msg = shift;
    print "\n*** $PROGRAM_NAME Croaking: $msg\n";
    exit(1);
}

#
# Returns given string with \'s replaced by /'s.
#
sub unixSlashes
{
    #args
    my $string = shift;

    $string =~ s:\\:/:g;
    
    return $string;
}

#
# Returns the first arg with whitespace at front and end removed.
#
sub clip          
{
    #note: there must be a better implementation...
    local($_) = @_;
    while (length($_) && substr($_,0,1) =~ /\s/)
    {
        $_ = substr($_,1);
    }

    while (length($_) && substr($_,-1) =~ /\s/)
    {
        $_ = substr($_,0,length($_)-1);
    }
    return $_;
}

#
# Returns the first arg with sequences of whitespace compressed to a
# single space
#
sub compressWhitespace
{
    #args
    my $string = shift;

    $string =~ s/\s+/ /g;

    return $string;
}

#
# Returns TRUE if there are any duplicates in the given list.
#
sub hasDuplicates
{
    #args
    my @vals = @_;

    #
    my $numDuplicates = scalar( &findDuplicates(@vals) );
    return ($numDuplicates != 0);
}

#
# Returns list of duplicates in the given list.
#
sub findDuplicates
{
    #args
    my @vals = @_;

    # we check by adding each value in the list to a dictionary
    my %dupCheck = ();
    my $value;
    my @dups = ();
    for $value ( @vals ) {
        if ( defined( $dupCheck{ $value } ) ) {
            push( @dups, $value);
        }
        else {
            $dupCheck{ $value } = 1;
        }
    }

    return @dups;
}

sub printDetails
{
    my $collectionRef = shift;
    my @collection = @$collectionRef;

    print "Number of Entries: $#collection\n";
    for $i ( 0 .. $#collection ) {
        print "##### Next Record #####\n";
        print "Name: $collection[$i]{filename}\n";
        print "Size: $collection[$i]{size}\n";
        print "Modification Date: $collection[$i]{modified}\n";
        print "MD5 Checksum: $collection[$i]{checksum}\n";
        print "Mode: $collection[$i]{mode}\n";
        print "Owner: $collection[$i]{owner}\n";
        print "Group: $collection[$i]{group}\n";
        print "Configuration File: $collection[$i]{config}\n";
        print "Documentation File: $collection[$i]{doc}\n";
        print "Device File: $collection[$i]{dev}\n";
        print "Symbolic Link: $collection[$i]{symlink}\n";
    }
}

sub compareField
{
    my $masterField = shift;
    my $candidateField = shift;

    if ( $masterField eq $candidateField ) {
        return( 0 );
    } else {
        return( 1 );
    }
}

sub compareRecord
{
    my $masterRecordRef = shift;
    my $candidateRecordRef = shift;
    my $status = 0;
    my $result = 0;
    my %statusRecord = ();

    if ($ verbose ) {
        print STDOUT "Comparing detail: master=$masterRecordRef->{filename} candidate=$candidateRecordRef->{filename} ...\n";
    }

    # compare Name field
    $status = &compareField( $masterRecordRef->{filename},
                             $candidateRecordRef->{filename} );
    if ( $status ) {
        $statusRecord{filename} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tName Field FAILED\n";
	}
    } else {
        $statusRecord{filename} = 0;
        if ( $verbose ) {
            print STDOUT "\tName Field PASSED\n";
	}
    }

    # compare Size Filed
    $status = &compareField( $masterRecordRef->{size},
                             $candidateRecordRef->{size} );
    if ( $status ) {
        $statusRecord{size} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tSize Field FAILED\n";
	}
    } else {
        $statusRecord{size} = 0;
        if ( $verbose ) {
            print STDOUT "\tSize Field PASSED\n";
	}
    }

    # compare Modification field
    $status = &compareField( $masterRecordRef->{modified},
                             $candidateRecordRef->{modified} );
    if ( $status ) {
        $statusRecord{modified} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tModified Field FAILED\n";
	}
    } else {
        $statusRecord{modified} = 0;
        if ( $verbose ) {
            print STDOUT "\tModified Field PASSED\n";
	}
    }

    # compare MD5 Checksum field
    $status = &compareField( $masterRecordRef->{checksum},
                             $candidateRecordRef->{checksum} );
    if ( $status ) {
        $statusRecord{checksum} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tMD5 Checksum Field FAILED\n";
	}
    } else {
        $statusRecord{checksum} = 0;
        if ( $verbose ) {
            print STDOUT "\tMD5 Checksum Field PASSED\n";
	}
    }

    # compare Mode field
    $status = &compareField( $masterRecordRef->{mode},
                             $candidateRecordRef->{mode} );
    if ( $status ) {
        $statusRecord{mode} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tMode Field FAILED\n";
	}
    } else {
        $statusRecord{mode} = 0;
        if ( $verbose ) {
            print STDOUT "\tMode Field PASSED\n";
	}
    }

    # compare Owner field
    $status = &compareField( $masterRecordRef->{owner},
                             $candidateRecordRef->{owner} );
    if ( $status ) {
        $statusRecord{owner} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tOwner Field FAILED\n";
	}
    } else {
        $statusRecord{owner} = 0;
        if ( $verbose ) {
            print STDOUT "\tOwner Field PASSED\n";
	}
    }

    # compare Group field
    $status = &compareField( $masterRecordRef->{group},
                             $candidateRecordRef->{group} );
    if ( $status ) {
        $statusRecord{group} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tGroup Field FAILED\n";
	}
    } else {
        $statusRecord{group} = 0;
        if ( $verbose ) {
            print STDOUT "\tGroup Field PASSED\n";
	}
    }

    # compare Configuration File field
    $status = &compareField( $masterRecordRef->{config},
                             $candidateRecordRef->{config} );
    if ( $status ) {
        $statusRecord{config} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tConfiguration File Field FAILED\n";
	}
    } else {
        $statusRecord{config} = 0;
        if ( $verbose ) {
            print STDOUT "\tConfiguration File Field PASSED\n";
	}
    }

    # compare Documentation File field
    $status = &compareField( $masterRecordRef->{doc},
                             $candidateRecordRef->{doc} );
    if ( $status ) {
        $statusRecord{doc} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tDocumentation File Field FAILED\n";
	}
    } else {
        $statusRecord{doc} = 0;
        if ( $verbose ) {
            print STDOUT "\tDocumentation File Field PASSED\n";
	}
    }

    # compare Device File field
    $status = &compareField( $masterRecordRef->{dev},
                             $candidateRecordRef->{dev} );
    if ( $status ) {
        $statusRecord{dev} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tDevice File Field FAILED\n";
	}
    } else {
        $statusRecord{dev} = 0;
        if ( $verbose ) {
            print STDOUT "\tDevice File Field PASSED\n";
	}
    }

    # compare Symbolic Link field
    $status = &compareField( $masterRecordRef->{symlink},
                             $candidateRecordRef->{symlink} );
    if ( $status ) {
        $statusRecord{symlink} = 1;
        $result = 1;
        if ( $verbose ) {
            print STDOUT "\tSymbolic Link Field FAILED\n";
	}
    } else {
        $statusRecord{symlink} = 0;
        if ( $verbose ) {
            print STDOUT "\tSymbolic Link Field PASSED\n";
	}
    }

    return( $result, %statusRecord );
}

#
# Compare detail arrays gathered by readCollectionDetail() and/or
# queryPackageDetail().
#
# Note: this subroutine assumes that there are the same number of
# entries for both the master and candidate arrays. It also assumes
# that the entries will be in the same order.
#
sub compareDetails
{
    my $masterRef = shift;
    my $candidateRef = shift;
    my $num = shift;
    my @masterCollection = @$masterRef;
    my @candidateCollection = @$candidateRef;
    my $status = 0;
    my $result = 0;
    my %statusRecord = ();

    # ouput the results to a file
    open(OUTPUT,">detailLog.txt") || &croak("can't open 'detailLog.txt' to write: $ERRNO");

    for $i ( 0 .. $num ) {
        ( $status, %statusRecord ) = &compareRecord( $masterCollection[$i], $candidateCollection[$i] );
        if ( $status ) {
            $result = 1;

            print OUTPUT "##### Detail Entry $i Failed #####\n";
            print OUTPUT "Master Entry: $masterCollection[$i]{filename}\n";
            print OUTPUT "Candidate Entry: $candidateCollection[$i]{filename}\n";

            if ( $statusRecord{filename} eq 0 ) {
                print OUTPUT "Name Field PASSED\n";
            } else {
                print OUTPUT "Name Field FAILED\n";
            }
            if ( $statusRecord{size} eq 0 ) {
                print OUTPUT "Size Field PASSED\n";
            } else {
                print OUTPUT "Size Field FAILED\n";
            }
            if ( $statusRecord{modified} eq 0 ) {
                print OUTPUT "Modified Field PASSED\n";
            } else {
                print OUTPUT "Modified Field FAILED\n";
            }
            if ( $statusRecord{checksum} eq 0 ) {
                print OUTPUT "MD5 Checksum Field PASSED\n";
            } else {
                print OUTPUT "MD5 Checksum Field FAILED\n";
            }
            if ( $statusRecord{mode} eq 0 ) {
                print OUTPUT "Mode Field PASSED\n";
            } else {
                print OUTPUT "Mode Field FAILED\n";
            }
            if ( $statusRecord{owner} eq 0 ) {
                print OUTPUT "Owner Field PASSED\n";
            } else {
                print OUTPUT "Owner Field FAILED\n";
            }
            if ( $statusRecord{group} eq 0 ) {
                print OUTPUT "Group Field PASSED\n";
            } else {
                print OUTPUT "Group Field FAILED\n";
            }
            if ( $statusRecord{config} eq 0 ) {
                print OUTPUT "Configuration File Field PASSED\n";
            } else {
                print OUTPUT "Configuration File Field FAILED\n";
            }
            if ( $statusRecord{doc} eq 0 ) {
                print OUTPUT "Documentation File Field PASSED\n";
            } else {
                print OUTPUT "Documentation File Field FAILED\n";
            }
            if ( $statusRecord{dev} eq 0 ) {
                print OUTPUT "Device File Field PASSED\n";
            } else {
                print OUTPUT "Device File Field FAILED\n";
            }
            if ( $statusRecord{symlink} eq 0 ) {
                print OUTPUT "Symbolic Link Field PASSED\n";
            } else {
                print OUTPUT "Symbolic Link Field FAILED\n";
            }
	}
    }

    close( OUTPUT );

    return( $result );
}
