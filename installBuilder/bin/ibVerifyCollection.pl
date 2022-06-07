#!perl
#
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
#  of Wizzer Works Inc. at msm@wizzer.com.
#
########################################################################
#
# ibVerifyCollection.pl
#
# This program compares a collection file (candidate) 
# to a master collection file (master).
#   If the candidate is missing entries, they are placed in "missing".
#   If the candidate has extra entries, they are placed in "extra".
#   If the candidate had missing or extra, this program returns 1, else 0.
#   (It is analogous to "install" during make rawidb on the SGI platform)
#
# This file should be interpretted by perl 5.
#
# $Id: ibVerifyCollection.pl,v 1.1 2004/05/26 19:36:06 msm Exp $
#
########################################################################

use English;  # use more readable names for perl variables!
use Cwd;

#globals set from command line
@candidateFiles = ();
$masterFile     = "";
$expandEnvVars   = 1;  # by default expand envVars in filenames


#the master & candidate!
# see "readCollection()" for a description of the format
%master    = ();
%candidate = ();

#useful globals
#$cwd = &unixSlashes(`cd`);    chop($cwd);
#$cwd = &unixSlashes(`pwd`);    chop($cwd);
$cwd = cwd();

# "constants"
$collectionHeader = "#InstallBuilder Collection 1.0";
$missingFile      = "missing";
$extraFile        = "extra";


&main;

#effects: compare candidate to master, writing missing & extra if needed!
sub main
{
    &parseCommandLine;

    # read master
    %master = &readCollection( $masterFile );

    # read candidates
    %candidate = &readCollection( @candidateFiles );

    @missing   = &findMissing( \%master,    \%candidate );
    @extra     = &findMissing( \%candidate, \%master    );

    my $hasMissing = (scalar( @missing ) != 0);
    my $hasExtra   = (scalar( @extra   ) != 0);

    if ( $hasMissing ) {
        print STDERR join("\n\t", 
                  "missing from @candidateFiles:",
                  @missing ), "\n";
        &writeList( $missingFile, @missing );
    }

    if ( $hasExtra ) {
        print STDERR join("\n\t", 
                  "extra in @candidateFiles:",
                  @extra ), "\n";
        &writeList( $extraFile, @extra );
    }

    if ( $hasMissing || $hasExtra ) {
        exit( 1 );
    }
    else {
        exit( 0 );
    }
}

#effects: writes a "usage" message to STDERR
sub usage
{
    print STDERR <<EOS;
usage: $PROGRAM_NAME master candidate [candidate ...]
EOS
}


# effects: sets global variables based on command line
#          croaks with message & usage if there is a problem
sub parseCommandLine
{
    #args

    #
    my $numArgs = scalar( @ARGV );

    if ( $numArgs < 2 ) {
        &usage();
        &croak("too few arguments");
    }

    my $i = 0;  # used below for indexing argv!
    if ( $ARGV[0] eq "-dontExpandEnvVars" ) {
        $expandEnvVars = 0;
        $i = 1;
    }
    
    $masterFile = &unixSlashes( $ARGV[$i]);
    $i++;

    @candidateFiles = ();
    for ( ; $i<$numArgs; $i++ ) {
        push(@candidateFiles, &unixSlashes($ARGV[$i]));
    }

    #
    # check that the file names are all unique!
    #
    if ( &hasDuplicates( $masterFile, @candidateFiles ) ) {
       &croak( "some of your file names are the same!" );
    }
}

# returns: given string with \'s protected by \'ing them (ie: "\" becomes "\\")
sub protectBackslashes
{
    #args
    my $string = shift;

    $string =~ s:\\:\\\\:g;
    return $string;
}

#returns: value of STRING with any environment variables expanded OR croaks
#note:    backslashes are quoted before evaluation!
#         and variables with non-alphanumeric names are not expanded!
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
        croak( "trouble with variables in <$string>" );
    }

    return $expanded;
}

#returns: an associative array with each key being a string from the collection
#         the strings will be trimmed for leading/trailing whitespace
#             and have sequences of whitespace compressed to one space
#note: croaks if can't read the file or there are duplicates in the file
sub readCollection
{
    #args
    my @files = @_;

    #locals
    my $val;
    my $file;
    my @lines = ();

    for $file (@files) {
        # read the file into an array!
        open(IN, "<$file") || &croak("can't read from $file: $ERRNO");

        # check header!
        my $firstLine = <IN>;
        chop( $firstLine );
        if ( &clip($firstLine) ne $collectionHeader ) {
          croak( "Bad header in $file\n" .
               "\texpected '$collectionHeader' got '$firstLine'" );
        } 

        #get remaining lines
        my @fileLines;
        while ( <IN> ) {
            my $line = $_;
            if ( $expandEnvVars  ) {
            $line = &evalWithEnvVars($line);
            }
            push( @fileLines, $line );
        }
        chop( @fileLines );
        @lines = (@lines, @fileLines);

        close( IN );
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

#returns: a list of keys in %$master which aren't in %$candidate.
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

#effects: writes entries in given list to outputFile or croaks trying!
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


#effects: print message and exits
sub croak
{
    my $msg = shift;
    print "\n*** $PROGRAM_NAME Croaking: $msg\n";
    exit(1);
}

# returns: given string with \'s replaced by /'s
sub unixSlashes
{
    #args
    my $string = shift;

    $string =~ s:\\:/:g;
    
    return $string;
}


#returns: first arg with whitespace at front and end removed
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

#returns: first arg with sequences of whitespace compressed to a single space
sub compressWhitespace
{
    #args
    my $string = shift;

    $string =~ s/\s+/ /g;

    return $string;
}


#returns: TRUE if there are any duplicates in the given list
sub hasDuplicates
{
    #args
    my @vals = @_;

    #
    my $numDuplicates = scalar( &findDuplicates(@vals) );
    return ($numDuplicates != 0);
}

#returns: list of duplicates in the given list
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
