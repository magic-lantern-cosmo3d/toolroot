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
# ibCollect.pl
#
# This program records what files should be collected during installation.
# (It is analogous to "install" during make rawidb on the SGI systems.)
#
# This file should be interpretted by perl 5.
#
# $Id: ibCollect.pl,v 1.1 2004/05/26 19:36:06 msm Exp $
#
########################################################################

use English;  # use more readable names for perl variables!
use Cwd;      # get pathname of current working directory

#useful globals
#$cwd = &unixSlashes(`cd`);    chop($cwd);
#$cwd = &unixSlashes(`pwd`);    chop($cwd);
$cwd = cwd();

#globals set from command line
$logFileName = "";
$baseDir     = defined($ENV{"IBBASEDIR"}) ? $ENV{"IBBASEDIR"} : "";
$srcDir      = $cwd;
$destDir     = "";
$dest        = "";
$tags        = "";
$quiet       = 0;
@files         = ();

# "constants"
$collectionHeader = "#InstallBuilder Collection 1.0";

&main;
exit(0);

#effects: adds an entry to logFile based on the command line args
#         (may add header if it will be first line of file!)
sub main
{
    &parseCommandLine;
    open( LOG, ">>$logFileName" ) || &croak( "can't open
          '$logFileName': $ERRNO " );

    if ( getFileSize( $logFileName ) == 0 ) {
       # the file was empty, so add header!
       my $line = "$collectionHeader\n";
       print $line; # if ( ! $quiet );
       print LOG $line;
    }

    &logCollectionRecord;
    close( LOG );
}

#effects: writes a "usage" message to STDERR
sub usage
{
    print STDERR <<EOS;
usage: $PROGRAM_NAME options file ...
  -q                        -- run "quietly" (optional)
  -log      logFileName     -- where to record the collection (required)
  -baseDir  baseDir         -- root for source file entries in log (required)
                               (defaults to value of \$IBBASEDIR if it's set)
  -srcDir   srcDir          -- directory containing file (defaults to cwd)
  -destDir  destDir         -- directory to install into (required)
  -dest     destFileName    -- file name to store file in 
                               (only use when renaming a file & 
                                can only use when have 1 file)
  -tags     "tagName ..."   -- the tag for these files (at least one required)
  note: later options will override earlier ones!
EOS
}


# effects: sets global variables based on command line
#          croaks with message & usage if there is a problem
sub parseCommandLine
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
           $quiet = 1;
        }
        elsif ( $argName eq "-log" ) {
           $logFileName = $argValue;
           $i++;
        }
        elsif ( $argName eq "-baseDir" ) {
           $baseDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-srcDir" ) {
           $srcDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-destDir" ) {
           $destDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-dest" ) {
           $dest = $argValue;
           $i++;
        }
        elsif ( $argName eq "-tags" ) {
           $tags = $argValue;
           $i++;
        }
        else {
            &usage;
            &croak( "unexpected argument: '$argName'" );
        }

        $i++;
    }
    # check that all required variables are set & non-empty!
    for $varName ( "logFileName", "baseDir", "destDir", "tags" ) {
        if ( eval("!defined(\$$varName) || (\$$varName eq '')") ) {
            &usage;
            &croak("a value must be provided for '$varName'");
        }
    }

    splice( @ARGV, 0, $i );  # remove used arguments!
    @files = @ARGV;          # whatever's left are files
    @ARGV = ();         # we've used everything up now!

    $logFileName = &makeAbsolutePath( $logFileName );
    $baseDir     = &makeAbsolutePath( $baseDir );
    $srcDir      = &makeAbsolutePath( $srcDir );
    $destDir     = &canonicalPath( $destDir );
    $dest        = ($dest eq "") ? &canonicalPath( $dest ) : "";

    my $numFiles = scalar( @files );

    if ( $dest ne "" ) {
        if ( $numFiles != 1 ) {
            usage();
            croak("if you use -dest, you may only " .
                  "specify one file\n\tbut files=[@files]" );
        }
    }

    if ( !&isRelativePath($destDir ) ) {
        # can't install to absolute locations!
        &croak( "the destDir mustn't be absolute ($destDir)" );
    }

    if ( $numFiles <= 0 ) {
        usage();
        croak( "you must specify at least one file" );
    }
}

sub quoteIfSpace
{
    my $val = shift;
    
    if ( $val =~ m: : ) {
    return "\"$val\"";
    }
    else {
    return $val;
    }
}

#effects: writes an entry to LOG for each file
sub logCollectionRecord
{
    #
    my $file;
    foreach $file ( @files ) {
    # where is the file coming from?
    my $from = &canonicalPath( "$srcDir/$file" );
    my $relFrom = &makeRelativeTo( $baseDir, $from );

    # where will it be installed?
    my $to = &canonicalPath( $destDir . "/" . &getOutputTo( $from ) );

    if ( ! -f $from ) {
        &croak( "$from either doesn't exist or isn't a file!" );
    }

    $to      = &quoteIfSpace( $to );
    $relFrom = &quoteIfSpace( $relFrom );

    my $line = "file $to $relFrom $tags\n";
    print $line if ( ! $quiet );
    print LOG $line;
    }
}

# returns: the "to" string for the install.raw file
# we put the file into $destDir
#   if $dest is set, we use $dest as its filename
#   otherwise,       we use its name
sub getOutputTo
{
    #args
    my $file = shift;

    if ( $dest eq "" ) {
    return &basename( $file );
    }
    else {
    return $dest;
    }
}

# returns: $path relative to $baseDir (or croaks if it's not a prefix)
# XXX: what about drive letters?
sub makeRelativeTo
{
    # args
    my $baseDir = &canonicalPath( shift );
    my $path    = &canonicalPath( shift );

    #
    my $index = index( $path, $baseDir );
    if ( $index == ($[-1) ) {
    &croak( "baseDir '$baseDir' isn't an ancestor of '$path'" );
    }

    my $relFrom = substr( $path, length($baseDir) );

    if ( substr( $relFrom, 0, 1 ) eq "/" ) {
    #first character is a /, so ditch it
    $relFrom = substr( $relFrom, 1 );
    }

    return $relFrom;
}

#effects: print message and exits
sub croak
{
    my $msg = shift;
    print "\n*** $PROGRAM_NAME Croaking: $msg\n";
    exit(1);
}

# returns: given path without consecutive slashes, and
#          without trailing slashes (if any). with .'s removed & ..'s applied.
sub canonicalPath
{
    #arg
    my $path = shift;

    $path = $path;

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
        ($outParts[$#outParts] ne ".")) { # and it's not a . too!
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

#returns: TRUE iff given path is relative
sub isRelativePath
{
    #args
    my $path = &canonicalPath(shift);

    #
    my $firstChar  = (length($path) > 0) ? substr( $path, 0, 1 ) : "";
    my $secondChar = (length($path) > 1) ? substr( $path, 1, 1 ) : "";

    if ( $firstChar eq "/" ) {
    # starts with a slash...absolute!
    return 0;
    }
    elsif ( $firstChar eq "" ) {
    return 0;
    }
    elsif (($firstChar =~ m/[a-zA-Z]/) &&
    ($secondChar eq ":")) {
    # starts with a drive letter...absolute!
    return 0;
    }

    # still here? must be relative
    return 1;
}


# returns: given path made absolute.  (if relative, is relative to $cwd)
sub makeAbsolutePath
{
    # args
    my $path = &canonicalPath(shift);

    #
    if ( ! &isRelativePath($path) ) {
    #already absolute!
    return $path;
    }

    my $absPath = &canonicalPath( "$cwd/$path" );
    return $absPath;
}

# returns: the basename of the given file
sub basename
{
    #args
    my $file = shift;

    #
    my @parts = split(m%[/:]%,$file);
    return $parts[ $#parts ];  # return last part
}

# returns: given string with \'s replaced by /'s
sub unixSlashes
{
    #args
    my $string = shift;

    $string =~ s:\\:/:g;
    
    return $string;
}



# returns: file size or 0 if the stat fails!
sub getFileSize
{
    #args
    my $file = shift;

    #
    my @stats = stat( $file );

    if ( scalar(@stats) == 0 ) {
        # stat failed, return 0
        return 0;
    }
    else {
        return $stats[7];
    }
}

##################################################################
#$argDesc =
#    {
#        # name,        req?, takes value, envVar,           default
#        "q",       => [ 0,   0,           "",                0  ],
#        "log"      => [ 1,   1 ],
#        "baseDir"  => [ 1,   1,           "IBBASEDIR"],
#        "srcDir"   => [ 1,   1,           "IBSRCDIR",        $cwd],
#        "destDir"  => [ 1,   1 ],
#        "dest"     => [ 0,   1 ],
#        "tags"     => [ 1,   1 ]
#    };
#
#
## returns: a reference to an associative array (argName-->value)
##          based on a given argDesc table or croaks with message & usage.
##          argDesc is an associative array, mapping argNames to attributes
##          those attributes provide the following info:
##        * is the attribute required?
##          (if it's required & missing & no default is found, croak!)
##        * does it take a value?
##        * 
#sub parseArgs
#{
#    #args
#    my $argDesc = shift;
#
#    #locals
#    my $args = {};
#    my @rest = ();
#
#    # 
#    
#
#}
