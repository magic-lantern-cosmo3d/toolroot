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
# ibMakeFileGroups.pl
#
# This file icompresses files using the install.dat files under the
# given directory.
#
# This file should be interpretted by perl 5.
#
# $Id: ibMakeFileGroups.pl,v 1.1 2004/05/26 19:36:06 msm Exp $
#
########################################################################

########################################################################
# UTIL package!
########################################################################

package util;
use English;  # nicer variable names for builtin perl variables!
use Cwd;      # get pathname of current working directory

$cwd = cwd();

# returns: first arg with whitespace at front and end removed
sub clip          
{
    # note: there must be a better implementation...
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

# effects: print message and exits
sub croak
{
    my $msg = shift;
    print "\n*** Croaking: $msg\n";
    exit(1);
}

# effects: print message
sub scold
{
    my $msg = shift;
    print "\n*** Scolding: $msg\n";
}

# returns: directory name (if any) of given path, or "."
#          (no trailing "/" either way!)
sub dirname
{
    # locals
    my $path = shift;

    #
    my $i = rindex( $path, "/" );
    if ($i == -1) {
        return ".";
    } 
    return substr( $path, 0, $i );
}

# returns: the basename of the given file
sub basename
{
    # parse args
    my $file = shift;

    #
    my @parts = split(m%[/:]%,$file);
    return $parts[ $#parts ];  # return last part
}

# returns: given string with /'s replaced by \'s
sub dosSlashes
{
    # parse args
    my $string = shift;

    $string =~ s:/:\\:g;
    
    return $string;
}

# returns: given string with \'s replaced by /'s
sub unixSlashes
{
    # parse args
    my $string = shift;

    $string =~ s:\\:/:g;
    
    return $string;
}

# effects: executes the given command (or croaks trying!)
# returns: a list ($status,"output of command, if any")
sub verboseSystem
{
    # parse args
    my $cmd = shift;

    # exec it
    open( CMD, "$cmd |" ) ||
        &util::croak( "internal error: couldn't system('$cmd')" );

    # get output
    my $output = join("", <CMD>);

    close(CMD);
    $status = $CHILD_ERROR;

    return ( $status, $output );
}

# effects: executes $cmd, printing output & croaking if it returns non-zero!
#          if pass optional second argument as 1, it will dump the output
#          either way!
sub croakingSystem
{
    # parse args
    my $cmd = shift;
    my $dumpAnyway = scalar( @_ );

    #
    my ($status, $output) = &util::verboseSystem( $cmd );
    
    if ( $status || $dumpAnyway ) {
        print $output;
    }

    if ( $status ) {
        &util::croak( "command failed: '$cmd'" ); 
    }
}

# effects: provides sub routines PACKAGE::get_XX & PACKAGE::dump_XX
#          for each string in the given list.
sub publishGetters
{
    my $attr;
    my $pkg = shift;
    for $attr (@_)
    {
        # print "attribute: $attr\n";
        eval "package $pkg; sub get_$attr { shift->{'$attr'} }";
        eval "package $pkg; sub dump_$attr 
            { print \"$attr: <\", shift->{'$attr'}, \">\n\" }";
    }
}

# returns: given string with \'s protected by \'ing them (ie: "\" becomes "\\")
sub protectBackslashes
{
    # parse args
    my $string = shift;

    $string =~ s:\\:\\\\:g;
    return $string;
}

# returns: value of STRING with any environment variables expanded OR croaks
# note:    backslashes are quoted before evaluation!
#          and variables with non-alphanumeric names are not expanded!
sub evalWithEnvVars
{
    # parse args
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

    # print "{$toEval}\n";

    my $expanded = eval $toEval;
    if ( $EVAL_ERROR ) {
        croak( "trouble with variables in <$string>" );
    }

    return $expanded;
}

# effects: DESTROYS the all contents of the given directory matching pattern
#          this includes subdirectories, and their all of their contents!
#          OR CROAKS IMMEDIATELY UPON FAILURE!
# WARNING: this logic only handles plain files & directories
sub destroyDirectoryContents
{
    # parse args
    my $dir     = shift;
    my $pattern = shift;

    #
    # destroy matching contents & find subdirectories
    #
    my @subdirs = ();

    opendir( DIRHANDLE, $dir );
    my $fileName = "";
    while( defined( $fileName = readdir( DIRHANDLE ) ) ) {

        if ( $fileName eq "." || $fileName eq ".." ) {
            # don't work on . or ..
            next;
        }

        if ( $fileName !~ m/$pattern/i ) {
            # doesn't match! get out!!!
            next;
        }

        my $path = "$dir/$fileName";
        if ( -f $path ) {
            #print "unlink( $path )\n";
            unlink( $path ) || &util::croak( "unlink($path) failed: $ERRNO" );
        }
        elsif ( -d $path ) {
            @subdirs = (@subdirs, $path);
        }
        else {
            &util::croak( "destroyDirectoryContents: <$path> isn't a directory or file!" );
        }
    }
    closedir( DIRHANDLE );

    # now recurse (note that we don't recurse with the DIRHANDLE open,
    #              to avoid having too many open & because DIRHANDLE isn't local)
    my $subdir;
    for $subdir (@subdirs) { 
        &destroyDirectoryContents( $subdir, ".*" );
        #print "rmdir( $subdir )\n";
        rmdir( $subdir ) || &util::croak( "rmdir($subdir) failed: $ERRNO" );        
    }
}

# returns: given path without consecutive slashes, and
#          without trailing slashes (if any). with .'s removed & ..'s applied.
sub canonicalPath
{
    # parse args
    my $path = shift;

    $path = &unixSlashes($path);

    my @parts    = split( m:/:, $path );
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
        # XXX: not worrying about symlinks since on PC
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

# returns: TRUE iff given path is relative
sub isRelativePath
{
    # parse args
    my $path = &canonicalPath(shift);

    #
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


# returns: given path made absolute.  (if relative, is relative to $cwd)
sub makeAbsolutePath
{
    #  parse args
    my $path = &canonicalPath(shift);

    #
    if ( ! &isRelativePath($path) ) {
        #already absolute!
        return $path;
    }

    my $absPath = &canonicalPath( "$cwd/$path" );
    return $absPath;
}


########################################################################
# MAIN package!
########################################################################

package main;
use English;  # nicer variable names for builtin perl variables!

#
# globals
# 

# set from command line
@main::collectionFiles = ();
$main::outputDir       = ".";
$main::baseDir         = defined($ENV{"IBBASEDIR"}) ? $ENV{"IBBASEDIR"} : "";
$main::quiet           = 0;
$main::expandEnvVars   = 1;  # by default expand envVars in filenames


# "constants"
$collectionHeader = "#InstallBuilder Collection 1.0";

##############################
&main;
exit(0);
##############################

sub main
{
    &parseCmdLine;

    &makeFileGroups(@main::collectionFiles);
}

# effects: prints a usage message
sub usage
{
    print <<EOS;
usage: perl ibMakeFileGroups.pl [options]
  options:
    -collect /path/to/collectionFile  -- what file to read what 
                                         to compress (required).
                                         may be given more than once
    -outputDir ../path/for/temp/files -- set path for output files
                                         (defaults to cwd)
    -baseDir /path/collection/is/relative/to -- (required!)
        (defaults to value of \$IBBASEDIR if it's set)
    note: later options will override earlier ones! (except -collect)
EOS
}

# effects: reads the command line, setting globals to reflect user's requests.
#         if there is a problem, it prints a usage message & croaks!
sub parseCmdLine
{
    # locals
    my $i = 0;
    my $argc  = scalar(@ARGV);

    while ( $i < $argc ) {
        my $argName  = $ARGV[$i];
        my $argValue = (($i+1)<$argc) ? $ARGV[$i+1] : "";

        if ( substr( $argName, 0, 1 ) ne "-" ) {
           # done with options, all the rest are files!
           last;
        }
        
        if ( $argName eq "-q" ) {
           $main::quiet = 1;
        }
        elsif ( $argName eq "-dontExpandEnvVars" ) {
            $expandEnvVars = 0;
        }
        elsif ( $argName eq "-collect" ) {
           push( @main::collectionFiles, $argValue );
           $i++;
        }
        elsif ( $argName eq "-baseDir" ) {
           $main::baseDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-outputDir" ) {
           $main::outputDir = $argValue;
           $i++;
        }
        else {
            &usage;
            &util::croak( "unexpected argument: '$argName'" );
        }

        $i++;
    }

    splice( @ARGV, 0, $i );  # remove used arguments!

    if ( scalar(@ARGV) > 0 ) {
        # there shouldn't be anything left!
        &usage;
        &util::croak( "unexpected arguments [@ARGV]" );
    }

    # check that all required variables are set & non-empty!
    for $varName ( "baseDir" ) {
        if ( eval("!defined(\$$varName) || (\$$varName eq '')") ) {
            &usage;
            &util::croak("a value must be given for '$varName'");
        }
    }

    # check that there were some collections given!
    if ( scalar( @collectionFiles ) == 0 ) {
        &usage;
        &util::croak("you must specify some collection files");
    }

    $main::baseDir  = &util::makeAbsolutePath($baseDir);
}

# returns: ($first, $rest) where first is the first
#          space delimited value (or first quoted value)
#         if the first value starts with a double quote.
#          and where rest is the rest of the string!
# croaks: if there is an opening quote, but no closing quote.
sub getFirstUsingSpaceAndQuotes
{
    my $in = shift;
    $in = &util::clip($in);

    if ( $in !~ m:^\": ) {
    # doesn't start with quote...
    if ( $in =~ m:^([^ ]+)(.*)$: ) {
        return ($1,$2);
    }
    }
    else {
    # starts with a quote...
    if ( $in =~ m:^\"([^\"]+)\"(.*)$: ) {
        return ($1,$2);
    }
    }

    # if got this far, there's a problem!
    &util::croak("syntax error (in getFirstUsingSpaceAndQuotes): <$in>");
}

# returns: (to,relativeFrom,tags) of the line
sub splitLine
{
    my $line = shift;

    # strip leading spaces & "file" & spaces...
    my $rest = $line;
    if ( $line =~ m/^\s*file\s+(.*)$/ ) {
    $rest = $1;
    }
    else {
    &util::croak("syntax error {in splitLine}: <$line>");
    }

    if ( $rest !~ m:\": ) {
    # there are no quotes in this line, so split using spaces!
    if ( $rest !~ m/^(\S+)\s+(\S+)\s+(.*)\s*$/ ) {
        &util::croak("syntax error (in splitLine): <$line>");
    }
    return ($1, $2, &util::clip($3));
    }

    # there are double-quotes, so take them into account
    # when splitting the lines...

    my ($to, $from, $tags);
    ($to,   $rest) = getFirstUsingSpaceAndQuotes( $rest );
    ($from, $rest) = getFirstUsingSpaceAndQuotes( $rest );
    $tags = &util::clip($rest);

    if ( $to eq "" || $from eq "" || $rest eq "" ) {
    &util::croak("syntax error [in splitLine]: <$line>");
    }

    # print "{$to}  {$from} {$tags}\n";
    
    return ($to, $from, $tags);
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

    #print "{$toEval}\n";

    my $expanded = eval $toEval;
    if ( $EVAL_ERROR ) {
        croak( "trouble with variables in <$string>" );
    }

    return $expanded;
}

#effects: icompresses files as described in the given files
sub makeFileGroups
{
    #args
    my @files = @_;

    # read the file into an array!
    my @lines = ();
    my $file;

    my %allTags;
    
    for $file (@files) {
      open(IN, "<$file") || &util::croak("can't read from $file: $ERRNO");
        # check header!
        my $firstLine = <IN>;
        chop( $firstLine );
        if ( &util::clip($firstLine) ne $collectionHeader ) {
              &util::croak( "Bad header in $file\n" .
               "\texpected '$collectionHeader' got '$firstLine'" );
        } 

        #get remaining lines
        my @fileLines;
        while ( <IN> ) {
            my $line = $_;
            if ( $expandEnvVars ) {
            $line = &evalWithEnvVars($line);
            }
            push( @fileLines, $line );
        }

        chop( @fileLines );                         #strip trailing \ns
        grep( s/#.*$//,  @fileLines );              #strip comments 
        @fileLines = grep( !/^\s*$/,  @fileLines ); #strip empty lines

      push( @lines, @fileLines );
      close( IN );
    }

    my $line;
    for $line (@lines) {
        # first, separate the line into parts!
        my ($to, $relFrom, $tags) = splitLine($line);

        # from is given in the collection file relative to $baseDir
        my $from = "$main::baseDir/$relFrom";

        if ( ! $main::quiet ) {
          print "from=<$from> to=<$to> tags=<$tags>\n";
        }
    
        if ( ! -f $from ) {
            &util::croak( "<$from> isn't a file" );
        }

        # $realFrom remembers where to icomp from
        # usually, its the same as $from, but the file is supposed
        # to have a different name once its installed, i copy
        # it first and reset $realFrom.
        my $realFrom = $from;

        #
        # make a dictionary from each TAG to a list of files for it
        #
        my $tag;
        for $tag ( split( /\s+/, $tags ) ) {
          &util::unixSlashes($realFrom);

          if ( !defined($tagFiles{$tag}) ) {
            $tagFiles{$tag} = [];
          }
          push( @{$tagFiles{$tag}}, $realFrom );

          $myAllTags{$tag} = $tag;
        }
    }

    for $tag ( keys %myAllTags ) {
        my $fgName = "$outputDir/$tag.fgl";
        open( FILEGROUP, ">$fgName" ) ||
        &util::croak( "can't open $fgName for writing: $ERRNO" );
        print FILEGROUP "[TopDir]\n";

        my $tagged = $tagFiles{$tag};
        my $taggedFile;
        my $count = 0;
        for $taggedFile ( @$tagged ) {
        $taggedFile = &util::dosSlashes($taggedFile);
        print FILEGROUP "file$count=$taggedFile\n";
        $count++;
        }

        print FILEGROUP <<EOS;
[General]
Type=FILELIST
Version=1.00.000
EOS

            close(FILEGROUP);
    }
}

