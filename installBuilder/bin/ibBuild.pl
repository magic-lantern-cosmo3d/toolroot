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
# ibBuild.pl
#
# This file builds distribution packages for the following operating
# system configurations:
#
#   Windows XP/2k/NT/9x using InstallShield
#   Redhat Linux 6.0 using RPM packages
#
# This file should be interpretted by perl 5.
#
# $Id: ibBuild.pl,v 1.1 2004/05/26 19:36:06 msm Exp $
#
########################################################################

########################################################################
# UTIL package!
########################################################################

package util;
use English;  # nicer variable names for builtin perl variables!
use Cwd;      # get pathname of current working directory

if ($^O eq "MSWin32") {
$util::os = "MSWin32";
} else {
$util::os = "linux";
}

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

# returns: directory name (if any) of given path,
# or "." (no trailing "/" either way!)
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
    my $cmdRef = shift;    # a reference to an array of cmd references

    # print "**** SYSTEM COMMAND: @$cmdRef\n"

    # exec it
    my $output = system( @$cmdRef ) == 0
        or &util::croak( "internal error: couldn't system('@$cmdRef')" );

    $status = $CHILD_ERROR;

    return ( $status, $output );
}

# effects: executes $cmd, printing output & croaking if it returns non-zero!
#          if pass optional second argument as 1, it will dump the output
#          either way!
sub croakingSystem
{
    # parse args
    my $cmdRef = shift;    # a reference to an array of cmd references
    my $dumpAnyway = scalar( @_ );

    my ($status, $output) = &util::verboseSystem( $cmdRef );
    
    if ( $status || $dumpAnyway ) {
        print $output;
    }

    if ( $status ) {
        &util::croak( "command failed: '@$cmdRef'" ); 
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
        #print "attribute: $attr\n";
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

    #print "{$toEval}\n";

    my $expanded = eval $toEval;
    if ( $EVAL_ERROR ) {
        croak( "trouble with variables in <$string>" );
    }

    return $expanded;
}

# effects: DESTROYS all the contents of the given directory matching specified
#          pattern, this includes subdirectories, and all of their contents!
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
            &util::croak( "destroyDirectoryContents: $path isn't a directory or file!" );
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

# returns: the size of the contents of fileName (an icomp library), or 0
#          if it doesn't exist
sub getSizeOfContents
{
    my $fileName = shift;
    my $total    = 0;
    
    if ( ! -r $fileName ) {
        return 0;
    }

    # try to read list $fileName using icomp!
    my $output = "";
    open( LISTING, "$main::ibDir\\installshieldbin\\icomp $fileName -l|" );

    while ($_ = <LISTING>) {
        $output .= $_;  # stash it away in case there's an error!

        # if the line is similar to:
        #     "01-07-97 17:44 13438 A_R_ 4682 elements\SoLazyElement.h"
        if ( /^\s+\d\d-\d\d-\d\d\s+\d\d?:\d\d\s+(\d+)\s+\w+\s+\d+\s+\S*$/ ) {
            #print "got size: $1\n";
            $total += $1;
        }
        else {
            #print "didn't match! <$_>\n";
        }
    }
    my $status = close(LISTING);
    if ( $status ) {
        print $output;
        &util::croak( "error listing $fileName" );
    }

    return $total;
}

# returns: the contents of fileName in as a single string, or croaks!
sub fileToString
{
    # parse args
    my $fileName = shift;

    #
    open( SLURP, &dosSlashes($fileName) ) ||
        &util::croak( "can't open $fileName for reading: $ERRNO" );
    my $string = join("", <SLURP> );
    close( SLURP );

    return $string;
}

# returns: the shortPathName for the given path, or croaks
#          it will fail it the given path doesn't exist or "dosPath" ain't
#          executable
sub shortPath
{
    # parse args
    my $path = &util::dosSlashes(shift);

    # exec it
    my $cmd = "dosPath $path";
    open( CMD, "$cmd |" ) ||
        &util::croak( "internal error: couldn't open '$cmd'" );

    # get output
    my $output = join( "", <CMD> );

    close( CMD );

    my $status = $CHILD_ERROR;
    if ( $status ) {
        &util::croak( "can't find the short path for '$path': $output" );
    } 

    return $output;
}

# returns: given path without consecutive slashes, and
#          without trailing slashes (if any). with .'s removed & ..'s applied.
sub canonicalPath
{
    #arg
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

#returns: TRUE iff given path is relative
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

########################################################################
# Subsys package!
########################################################################
package Subsys;
use English;  # nicer variable names for builtin perl variables!

BEGIN {
    &util::publishGetters( "Subsys", "id", "uiName" );
}

$SubsysToken      = "subsys";
$EndSubsysToken   = "end$SubsysToken";
$UiNameToken      = "uiName";
$ExportToken      = "export";

# returns: new Subsys with given id
sub new
{
    # parse args
    my $class   = shift;
    my $id      = shift;

    #
    my $self = bless { "id" => $id, "exports" => [] };
    return $self;    
}

# returns: copy of exports list
sub get_exports
{
    # parse args
    my $self = shift;

    #
    return @{$self->{"exports"}};
}

# effects: prints out this object
sub dump
{
    # parse args
    my $self = shift;

    print "\t" . ref($self) . " {\n";
    print "\t\tid = <" . $self->get_id() . ">\n";
    print "\t\tuiName = <" . $self->get_uiName() . ">\n";
    print "\t\texports = [" . join(" && ", $self->get_exports()) . "]\n";
    print "\t}\n";
}

# effects: reads definition from main::FILE 
sub readFromFile
{
    # parse args
    my $self = shift;

    while ( <main::FILE> ) {
        s://.*$::;   # strip c++-style // comments
        s:#.*$::;   # strip shell-style # comments
 
        $_ = &util::clip( $_ );
        $_ = &util::evalWithEnvVars( $_ ) if ($_ ne "");

        if ( /^$UiNameToken\s+(.+)$/ ) {
            $self->{"uiName"} = $1;
        }
        elsif ( /^$ExportToken\s+(.*)$/ ) {
            my @rawExps = split( /\s+/, $1 );
            my $exps    = [];
            my $needAmpersands = 0;
            my $e;
            foreach $e ( @rawExps ) {
                if ( $needAmpersands ) {
                    if ( $e eq "&&") {
                        $needAmpersands = 0;                        
                    }
                    else {
                        &util::croak( "syntax error: $main::specFileName (#$INPUT_LINE_NUMBER): expecting a '&&'" );
                    }
                }
                else {  # don't need an ampersand!
                    if ( $e eq "&&" ) {
                        &util::croak( "syntax error: $main::specFileName (#$INPUT_LINE_NUMBER): unexpected '&&'??" );
                    }
                    else {
                        # NOTE: A similar check is being done in compressFiles!
                        if ( length($e) > 8 ) {
                            &util::croak( "$main::specFileName: Tag named '$e' is must be shorter than 8 characters!\n" .
                                       "\t(Because exebuilder uses 8.3 file names.)\n" );                     
                        }

                        @$exps = (@$exps, $e);    # add to exports list
                        $needAmpersands = 1;
                    }
                }
            }
            $self->{"exports"} = $exps;
        }
        elsif ( /^$EndSubsysToken$/ ) {
            return;
        }
        elsif ( /^$/ ) {
            # empty line...skip it!
        }
        else {
            &util::scold( "syntax error: $main::specFileName (#" . $. . "): $_" );
        }        
    }
}

# returns: the size of all the uncompressed files in this subsystem
sub get_uncompressedSize
{
    # parse args
    my $self = shift;

    #
    my $total = 0;

    my $exp;
    for $exp ($self->get_exports()) {
        $total += &util::getSizeOfContents( $exp . ".z" );
    }

    return $total;
}

########################################################################
# Product package!
########################################################################
package Product;
use English;  # nicer variable names for builtin perl variables!
use Cwd;      # get pathname of current working directory

#
# globals
#
$product::rpmSpecFile = "";

#constants
$ProductToken     = "product";
$EndProductToken  = "end$ProductToken";
$specHeader       = "#InstallBuilder Spec 1.0";
$DefaultInstallDirToken = "defaultInstallDir";

%subsysPkg = ();

BEGIN {
    &util::publishGetters( "Product",
                          "id", "version", "uiName", "defaultInstallDir" );
}

# returns: a new associative array whose keys are the id's of product and 
#          values are product objects. the dict is built created by reading
#         the specFileName.  if any trouble occurs, it croaks.
sub newDictFromFile
{
    # parse args
    my $class        = shift;
    my $specFileName = shift;

    #
    my $productDict = {};

    # open file
    open( main::FILE, $specFileName ) ||
        &util::croak( "Can't open $specFileName: " . $ERRNO );

    # check header!
    my $firstLine = <main::FILE>;
    chop( $firstLine );
    if ( &util::clip($firstLine) ne $specHeader ) {
        &util::croak( "Bad header in $specFileName\n" .
                      "\texpected '$specHeader' got '$firstLine'" );
    }

    #interpret each line!
    while ( <main::FILE> ) {
        s://.*$::;   # strip c++-style // comments
        s:#.*$::;   # strip shell-style # comments
 
        $_ = &util::clip( $_ );
        $_ = &util::evalWithEnvVars( $_ ) if ($_ ne "");

        if ( /^$ProductToken\s+(\w+)\s+(.+)$/ ) {
            my $id      = $1;
            my $version = &util::clip($2);

            if ( defined( $productDict->{$id} ) ) {
                &util::croak( "$specFileName #" . $. . ": already has product named '$id'\n" );
            }
            my $curProduct = new Product( $id, $version );
            $curProduct->readFromFile( main::FILE );
            $productDict{$id} = $curProduct;
        }
        elsif ( /^\s*$/ ) {
            # empty line...skip it!
        }
        else {
            &util::croak( "syntax error: $specFileName (#$INPUT_LINE_NUMBER): $_" );
        }
    }

    return %productDict;
}

# returns: new Product with given id & version
sub new
{
    # parse args
    my $class   = shift;
    my $id      = shift;
    my $version = shift;

    #
    my $self = bless { "id" => $id,
                       "version" => $version,
                       "subsystems" => {},  # a dict of id --> subsystem
                     };
    return $self;    
}

# effects: adds subsys to the given product (or croaks if already have
#          one with same name)
sub addSubsystem
{
    # parse args
    my $self   = shift;
    my $subsys = shift;

    #
    my $id = $subsys->get_id();

    if ( defined( $self->{"subsystems"}->{$id} ) ) {
        &util::croak( "$main::specFileName (#$INPUT_LINE_NUMBER): already have a subsystem named $id");
    }

    $self->{"subsystems"}->{$id} = $subsys;
}

# effects: reads definition from main::FILE
sub readFromFile
{
    # parse args
    my $self = shift;

    while ( <main::FILE> ) {
        s://.*$::;   # strip c++-style // comments
        s:#.*$::;   # strip shell-style # comments
 
        $_ = &util::clip( $_ );
        $_ = &util::evalWithEnvVars( $_ ) if ($_ ne "");

        if ( /^$Subsys::SubsysToken\s+(\w+)$/ ) {
            my $id     = $1; 
            my $subsys = new Subsys($id);
            $subsys->readFromFile( main::FILE );

            $self->addSubsystem( $subsys );
        }
        elsif ( /^$Subsys::UiNameToken\s+(.+)$/ ) {
            if ( defined( $self->{"uiName"} ) ) {
                &util::croak( "$main::specFileName (#$INPUT_LINE_NUMBER): already have a uiName for "
                          . $self->get_id() );
            }
            $self->{"uiName"} = $1;
        }
        elsif ( /^$DefaultInstallDirToken\s+(.*)$/ ) {
            if ( defined( $self->{"defaultInstallDir"} ) ) {
                &util::croak( "$main::specFileName (#$INPUT_LINE_NUMBER): already have a " .
                          "defaultInstallDir for " . $self->get_id() );                
            }
            $self->{"defaultInstallDir"} = &util::clip($1);
        }
        elsif ( /^$EndProductToken$/ ) {
            if ( !defined( $self->{"defaultInstallDir"} ) ) {
                &util::croak("missing defaultInstallDir for product '" . $self->get_id() . "'" );
            }
            if ( !defined( $self->{"uiName"} ) ) {
                &util::croak("missing uiName for product '" . $self->get_id() . "'" );
            }
            return;
        }
        elsif ( /^$/ ) {
            # empty line...skip it!
        }
        else {
            &util::scold( "syntax error: $main::specFileName (#" . $. . "): $_" );
        }
    }
}

# returns: the list of subsystems
sub get_subsystems
{
    # parse args
    my $self = shift;

    #
    return values %{$self->{"subsystems"}};
}

# effects: prints out this object
sub dump
{
    # parse args
    my $self = shift;

    print ref($self) . " {\n";

    my $key;
    for $key ( keys %$self ) {
        if ( $key eq "subsystems" ) {
            next;
        }
        print "\t$key --> <$self->{$key}>\n";
    }

    my $subsys;
    for $subsys ( $self->get_subsystems() ) {
        $subsys->dump();
    }

    print "}\n";
}

# returns: the name of this product's dist directory
sub get_distDirName
{
    # parse args
    my $self = shift;

    #
    if ($main::targetPlatform eq "windows") {
        return ($main::ibTmpDir . "\\" . $self->get_id() . "Dist");
    } else {
        return ($main::ibTmpDir . "/" . $self->get_id() . "Dist");
    }
}

#effects: makes a subdirectory of the current directory with the name
#         "productIdDist"
#         (or croaks!)
sub createDistributionDir
{
    # parse args
    my $self = shift;

    #
    my $dirName = $self->get_distDirName();
    mkdir( $dirName, 0777 ) ||
        &util::croak( "Couldn't make directory '$dirName': $ERRNO" );
}

# effects: copies all files from $main::ibDir/templates/installShieldDist
#          to this product's dist directory (or croaks)
sub copyInstallShieldFiles 
{
    # parse args
    my $self = shift;

    #
    my $distDir = $self->get_distDirName();
    my @cmd = (
       "cp",
       "${main::ibDir}/templates/installShieldDist/*.*",
       $distDir
    );
    my ($status,$output) = &util::verboseSystem( \@cmd );
    if ( $status ) {
        print $output;
        &util::croak( "Copy failed: '@cmd'" ); 
    }
}

#effects: writes setup.rul in the product's dist directory (or croaks)
sub generateSetupRules
{
    # parse args
    my $self = shift;

    # open file
    my $ruleFileName = $self->get_distDirName() . "/setup.rul"; 
    open( RULES, ">$ruleFileName" ) ||
        &util::croak( "can't open $ruleFileName for writing: $ERRNO" );

    my $ibDecls = &util::fileToString( "$main::ibDir/templates/ibDecls.rul" );
    my $ibBody  = &util::fileToString( "$main::ibDir/templates/ibBody.rul" );

    #
    # write header
    #
    print RULES <<EOS;
/*
 * Copyright (C) 2002, Wizzer Works
 *
 * DO NOT EDIT THIS FILE: it was generated by $PROGRAM_NAME 
 */

EOS

    #
    # compute variables for important product declarations
    #
    my $productName    = $self->get_uiName();
    my $productKey     = $self->get_id();
    my $productVersion = $self->get_version();
    my $defInstallDir  = $self->get_defaultInstallDir();

    print RULES <<EOS;

/*
 * Information about the product being installed ($productKey)
 */
#define PRODUCT_NAME    "$productName"
#define PRODUCT_VERSION "$productVersion"
#define PRODUCT_KEY     "$productKey"
#define COMPANY_NAME    "Wizzer Works"
#define UNINSTALL_KEY   PRODUCT_NAME
#define UNINSTALL_NAME  "$productName $productVersion"
#define DEFAULT_INSTALL_DIR "$defInstallDir"
EOS

    #
    # start the declaration section of the script
    #

    print RULES <<EOS;

declare
    prototype GetNumSubsystems();
    prototype GetIthSubsystemSize( number );
    // prototype GetIthSubsystemUiName( number );
    prototype DoCompressGets();

EOS

    #
    # write include of ibDecls.rul & ibBody.rul
    #

    print RULES <<EOS;

/*
 * Include the declarations of the script
 */

$ibDecls

/*
 * Include the main body of the script
 */

$ibBody

EOS

    #
    # write include of ibDecls.rul & ibBody.rul
    #

    my @subsystems = $self->get_subsystems();
    my $numSubsys  = scalar( @subsystems );
    my $subsys;
    my $sizeSwitchBody = "";
    my $nameSwitchBody = qq{MessageBox("GetIthSubsystemName: ain't implemented yet!", SEVERE ); abort;\n};
    my $compressGetBody = "";

    my $i = 0;
    for $subsys ( $self->get_subsystems() ) {
        my $size = $subsys->get_uncompressedSize();
        $sizeSwitchBody  .= qq{\t\tcase $i:\t return $size;\n};

        my $exp;
        for $exp ( $subsys->get_exports() ) {
            $compressGetBody .= qq{\tCompressGet( "$exp.z", "*.*", INCLUDE_SUBDIR );\n};
        }

        $i++;
    }
    

    print RULES <<EOS;

// returns: the number of subsystems in the product
function GetNumSubsystems()
  begin
    return $numSubsys;
  end;

// returns: the size (in bytes) of the ith subsystem
function GetIthSubsystemSize( i )
  begin
    switch( i )

$sizeSwitchBody
    endswitch;
  end;

function DoCompressGets()
  begin
    TARGETDIR = svMainDirectory;
$compressGetBody
  end;


EOS

    close RULES;    
}

# effects: compiles the generated setup.rul (or croaks)
sub compileSetupRules
{
    # parse args
    my $self = shift;

    #
    # because compile.exe doesn't handle long filenames
    # and a distDir might be long (ie: vivaDevDist),
    # we chdir into the distDir, compile, then chdir back out!
    #
    my $cwd = cwd();

    #
    my $dirName = $self->get_distDirName();
    chdir( $dirName ) || &util::croak( "can't chdir to $dirName" );
    # print "*** COMPILE DIRNAME: $dirName\n";

    my $shellCmd = "$main::commandShell";
    my $compileCmd = &util::dosSlashes("$main::ibDir\\installshieldbin\\compile");
    my @cmd = ( $shellCmd, "/c", $compileCmd, "setup.rul" );
    # print "*** COMPILE CMD: @cmd\n";

    &util::croakingSystem( \@cmd, 1 );

    chdir( $cwd ) || &util::croak( "can't chdir to $cwd" );
}

# effects: creates setup.lst in the distribution directory, copies the
#           exports to it, packlists it, and removes it
sub polishPackage
{
    # parse args
    my $self = shift;
    my $cwd;

    #
    $cwd = cwd();
    my $dirName = $self->get_distDirName();
    chdir( $dirName ) || &util::croak( "can't chdir to $dirName" );

    open( PACKLIST, ">setup.lst" ) ||
        &util::croak( "can't open setup.lst for writing: $ERRNO" );

    # write that next chunk of files is on "disk 1"  (all of our files are!)
    print PACKLIST "1;\n";

    my $subsys;
    foreach $subsys ($self->get_subsystems()) {
        my $exp;
        foreach $exp ( $subsys->get_exports ) {
            print PACKLIST "$exp.z\n";
            if ( ! -f "$main::ibTmpDir\\$exp.z" ) {
            &util::croak( "no files were put tagged $exp, " .
                          "yet " . $subsys->get_id() .
                          " includes that tag!" );
            }
            my @cmd= (
                "cp",
                &util::unixSlashes( "$main::ibTmpDir\\$exp.z" ),
                "."
            );
            &util::croakingSystem( \@cmd );
        }
    }

    close( PACKLIST );

    # packlist the list!
    my $shellCmd = "$main::commandShell";
    my $packlistCmd = &util::dosSlashes("$main::ibDir\\installshieldbin\\packlist");
    my @cmd = ( $shellCmd, "/c", $packlistCmd, "setup.lst" );
    # print "*** PACKLIST CMD: @args\n";
    &util::croakingSystem( \@cmd );

    chdir( $cwd ) || &util::croak( "can't chdir to $cwd" );
}

# effects: creates a Self Extracting Installer & puts it in the current
#          directory (or croaks)
sub createSEI
{
    # parse args
    my $self = shift;

    # initialize local variables
    my $productName    = $self->get_uiName();
    my $distDir        = &util::shortPath( $self->get_distDirName());
    my $destDir         = &util::shortPath( $main::ibTmpDir );

    # write ini file to automate exebuild
    my $ebIniFile = "$main::ibTmpDir\\eb.ini";
    open( EBINI, ">$ebIniFile" ) || &util::croak( "couldn't open eb.ini to write!" );
    print EBINI<<EOS;
[Exe Builder]
SrcDir=$distDir
DestDir=$destDir
CmdLine=setup.exe
Password=
Title=$productName
Compress=0
EOS
    close( EBINI );

    my $cwd = cwd();
    my $dirName = $self->get_distDirName();
    chdir( $dirName ) || &util::croak( "can't chdir to $dirName" );

    my $sei = $self->get_id() . "_Install.exe";
    my $shellCmd = "$main::commandShell";
    my $exebuildCmd = &util::dosSlashes( "$main::ibDir\\installshieldbin\\exebuild" );
    my $cmdEbIniFile = &util::dosSlashes( $ebIniFile );
#    my $startCmd = "C:\\Windows\\command\\start /w $exebuildCmd $cmdEbIniFile";
    my $startCmd = "start /w $exebuildCmd $cmdEbIniFile";
    my @cmd = ( $shellCmd, "/c", $startCmd );
    print "*** EXEBUILD CMD: @cmd\n";
    &util::croakingSystem( \@cmd );
    print "*** Sleeping to allow exebuild to finish ...\n";
    sleep( 15 );
    print "*** Done\n";

    @cmd = (
        "mv",
        &util::unixSlashes("$main::ibTmpDir\\setupex.exe"),
        &util::unixSlashes("$cwd\\$sei")
    );
    &util::croakingSystem( \@cmd );

    unlink( $ebIniFile ) ||
        &util::croak( "unlink($ebIniFile) failed: $ERRNO" );

    chdir( $cwd ) || &util::croak( "can't chdir to $cwd" );
}

sub buildRpmSpecFile
{
    #args
    my $self = shift;

    my $productName = $self->get_uiName();
    my $productId = $self->get_id();
    my $productVersion = $self->get_version();
    my $defInstallDir = $self->get_defaultInstallDir();
    my $rpmPreamble = "";
    my $rpmPrepScript = "";
    my $rpmBuildScript = "";
    my $rpmInstallScript = "";

    $product::rpmSpecFile = "$main::ibTmpDir/SPECS/$productId" . "Ism.spec";

    # determine which required templates to use for generating
    # the spec file
    if ( -f "$main::ibTmpDir/../rpmPreamble.txt" ) {
        $rpmPreamble = "$main::ibTmpDir/../rpmPreamble.txt";
    } else {
        $rpmPreamble = "$main::ibDir/templates/rpmPreamble.txt";
    }
    if ( -f "$main::ibTmpDir/../rpmPrepScript.txt" ) {
        $rpmPrepScript = "$main::ibTmpDir/../rpmPrepScript.txt";
    } else {
        $rpmPrepScript = "$main::ibDir/templates/rpmPrepScript.txt";
    }
    if ( -f "$main::ibTmpDir/../rpmBuildScript.txt" ) {
        $rpmBuildScript = "$main::ibTmpDir/../rpmBuildScript.txt";
    } else {
        $rpmBuildScript = "$main::ibDir/templates/rpmBuildScript.txt";
    }
    if ( -f "$main::ibTmpDir/../rpmInstallScript.txt" ) {
        $rpmInstallScript = "$main::ibTmpDir/../rpmInstallScript.txt";
    } else {
        $rpmInstallScript = "$main::ibDir/templates/rpmInstallScript.txt";
    }
    if ( ! -f $rpmPreamble ) {
        &util::croak( "rpmPreamble.txt is a required file: $ERRNO" );
    }
    if ( ! -f $rpmPrepScript ) {
        &util::croak( "rpmPrepScript.txt is a required file: $ERRNO" );
    }
    if ( ! -f $rpmBuildScript ) {
        &util::croak( "rpmBuildScript.txt is a required file: $ERRNO" );
    }
    if ( ! -f $rpmInstallScript ) {
        &util::croak( "rpmInstallScript.txt is a required file: $ERRNO" );
    }

    # Build RPM Spec File
    open( RPM_SPECFILE, "> $product::rpmSpecFile" );

    ($sec, $min, $hour, $day, $month, $year) = (localtime)[0..5];
    $dateStamp = $hour . ":" . $min . ":" . $sec;
    $dateStamp = $dateStamp . " ";
    $dateStamp = $dateStamp . ($month+1) . "/" . $day . "/" . ($year+1900);
    print RPM_SPECFILE "#\n";
    print RPM_SPECFILE "# RPM Spec file for $productId.\n";
    print RPM_SPECFILE "#\n";
    print RPM_SPECFILE "# This file was generated by ibBuild.pl.\n";
    print RPM_SPECFILE "#     Date: $dateStamp\n";
    print RPM_SPECFILE "#\n\n";

    # 1.a) add the prefix tag for relocatable packages
    if ( $main::relocatePrefix ne "" ) {
        print RPM_SPECFILE "#\n";
        print RPM_SPECFILE "# Prefix for relocatble packages.\n";
        print RPM_SPECFILE "#\n";
        print RPM_SPECFILE "Prefix: $main::relocatePrefix\n";
        print RPM_SPECFILE "\n";
    }

    # 1.b) the preamble section
    open( RPM_PREAMBLE, "< $rpmPreamble" );
    while ( <RPM_PREAMBLE> ) {
        my $line = $_;
        # replace summary of product with spec file summary
        if ( $line =~ /^Summary:/) {
            $line = "Summary: $productName\n";
        }
        # replace name of product with spec file name
        if ( $line =~ /^Name:/) {
            $line = "Name: $productId\n";
        }
        # replace version of product with spec file version
        if ( $line =~ /^Version:/) {
            $line = "Version: $productVersion\n";
        }
        print RPM_SPECFILE "$line";
    }
    print RPM_SPECFILE "\n";
    close( RPM_PREAMBLE );

    # 1.c) the preamble for each subpackage
    my $subsys;
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $summary = $subsys->get_uiName();
        my $rpmSubsysPreamble = "$main::ibTmpDir/../rpm";
        $rpmSubsysPreamble = $rpmSubsysPreamble . $id . "Preamble.txt";
        if ( -f $rpmSubsysPreamble ) {
            open( RPM_SUBSYSPREAMBLE, "< $rpmSubsysPreamble" );
            while ( <RPM_SUBSYSPREAMBLE> ) {
                my $line = $_;
                if ( $line =~ /^Summary:/) {
                    $line = "Summary: $summary\n";
                }
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSPREAMBLE );
        } else {
            print RPM_SPECFILE "\%package $id\n";
            print RPM_SPECFILE "Summary: $summary\n";
            print RPM_SPECFILE "Group: Applications\n";
            print RPM_SPECFILE "\n";
            print RPM_SPECFILE "\%description $id\n";
            print RPM_SPECFILE "This package contains stuff related to the $id subpackage of product $productId.\n";
            print RPM_SPECFILE "\n";
        }
    }

    # 2) the %prep section
    open( RPM_PREPSCRIPT, "< $rpmPrepScript" );
    while ( <RPM_PREPSCRIPT> ) {
        my $line = $_;
        print RPM_SPECFILE "$line";
    }
    print RPM_SPECFILE "\n";
    close( RPM_PREPSCRIPT );

    # 3) the %build section
    open( RPM_BUILDSCRIPT, "< $rpmBuildScript" );
    while ( <RPM_BUILDSCRIPT> ) {
        my $line = $_;
        print RPM_SPECFILE "$line";
    }
    print RPM_SPECFILE "\n";
    close( RPM_BUILDSCRIPT );

    # 4) the %install section
    open( RPM_INSTALLSCRIPT, "< $rpmInstallScript" );
    while ( <RPM_INSTALLSCRIPT> ) {
        my $line = $_;
        print RPM_SPECFILE "$line";
    }
    print RPM_SPECFILE "\n";
    close( RPM_INSTALLSCRIPT );

    # 5) the %clean section
    my $rpmCleanScript = "";
    if ( -f "$main::ibTmpDir/../rpmCleanScript.txt" ) {
        $rpmCleanScript = "$main::ibTmpDir/../rpmCleanScript.txt";
    }
    if ( -f $rpmCleanScript ) {
        open( RPM_CLEANSCRIPT, "< $rpmCleanScript" );
        while ( <RPM_CLEANSCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_CLEANSCRIPT );
    }

    # 6a) the %pre section
    my $rpmPreScript = "";
    if ( -f "$main::ibTmpDir/../rpmPreScript.txt" ) {
        $rpmPreScript = "$main::ibTmpDir/../rpmPreScript.txt";
    }
    if ( -f $rpmPreScript ) {
        open( RPM_PRESCRIPT, "< $rpmPreScript" );
        while ( <RPM_PRESCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_PRESCRIPT );
    }

    # 6b) the %pre section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysPreScript = "$main::ibTmpDir/../rpm";
        $rpmSubsysPreScript = $rpmSubsysPreScript . $id . "PreScript.txt";
        if ( -f $rpmSubsysPreScript ) {
            open( RPM_SUBSYSPRESCRIPT, "< $rpmSubsysPreScript" );
            while ( <RPM_SUBSYSPRESCRIPT> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSPRESCRIPT );
        }
    }

    # 7a) the %post section
    my $rpmPostScript = "";
    if ( -f "$main::ibTmpDir/../rpmPostScript.txt" ) {
        $rpmPostScript = "$main::ibTmpDir/../rpmPostScript.txt";
    }
    if ( -f $rpmPostScript ) {
        open( RPM_POSTSCRIPT, "< $rpmPostScript" );
        while ( <RPM_POSTSCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_POSTSCRIPT );
    }

    # 7b) the %post section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysPostScript = "$main::ibTmpDir/../rpm";
        $rpmSubsysPostScript = $rpmSubsysPostScript . $id . "PostScript.txt";
        if ( -f $rpmSubsysPostScript ) {
            open( RPM_SUBSYSPOSTSCRIPT, "< $rpmSubsysPostScript" );
            while ( <RPM_SUBSYSPOSTSCRIPT> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSPOSTSCRIPT );
        }
    }

    # 8a) the %preun section
    my $rpmPreunScript = "";
    if ( -f "$main::ibTmpDir/../rpmPreunScript.txt" ) {
        $rpmPreunScript = "$main::ibTmpDir/../rpmPreunScript.txt";
    }
    if ( -f $rpmPreunScript ) {
        open( RPM_PREUNSCRIPT, "< $rpmPreunScript" );
        while ( <RPM_PREUNSCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_PREUNSCRIPT );
    }

    # 8b) the %preun section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysPreunScript = "$main::ibTmpDir/../rpm";
        $rpmSubsysPreunScript = $rpmSubsysPreunScript . $id . "PreunScript.txt";
        if ( -f $rpmSubsysPreunScript ) {
            open( RPM_SUBSYSPREUNSCRIPT, "< $rpmSubsysPreunScript" );
            while ( <RPM_SUBSYSPREUNSCRIPT> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSPREUNSCRIPT );
        }
    }

    # 9a) the %postun section
    my $rpmPostunScript = "";
    if ( -f "$main::ibTmpDir/../rpmPostunScript.txt" ) {
        $rpmPostunScript = "$main::ibTmpDir/../rpmPostunScript.txt";
    }
    if ( -f $rpmPostunScript ) {
        open( RPM_POSTUNSCRIPT, "< $rpmPostunScript" );
        while ( <RPM_POSTUNSCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_POSTUNSCRIPT );
    }

    # 9b) the %postun section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysPostunScript = "$main::ibTmpDir/../rpm";
        $rpmSubsysPostunScript = $rpmSubsysPostunScript . $id . "PostunScript.txt";
        if ( -f $rpmSubsysPostunScript ) {
            open( RPM_SUBSYSPOSTUNSCRIPT, "< $rpmSubsysPostunScript" );
            while ( <RPM_SUBSYSPOSTUNSCRIPT> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSPOSTUNSCRIPT );
        }
    }

    # 10a) the %verifyscript section
    my $rpmVerifyScript = "";
    if ( -f "$main::ibTmpDir/../rpmVerifyScript.txt" ) {
        $rpmVerifyScript = "$main::ibTmpDir/../rpmVerifyScript.txt";
    }
    if ( -f $rpmVerifyScript ) {
        open( RPM_VERIFYSCRIPT, "< $rpmVerifyScript" );
        while ( <RPM_VERIFYSCRIPT> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_VERIFYSCRIPT );
    }

    # 10b) the %verifyscript section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysVerifyScript = "$main::ibTmpDir/../rpm";
        $rpmSubsysVerifyScript = $rpmSubsysVerifyScript . $id . "VerifyScript.txt";
        if ( -f $rpmSubsysVerifyScript ) {
            open( RPM_SUBSYSVERIFYSCRIPT, "< $rpmSubsysVerifyScript" );
            while ( <RPM_SUBSYSVERIFYSCRIPT> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSVERIFYSCRIPT );
        }
    }

    # 11a) the %files section
    my $rpmFiles = "";
    if ( -f "$main::ibTmpDir/../rpmFiles.txt" ) {
        $rpmFiles = "$main::ibTmpDir/../rpmFiles.txt";
    }
    if ( -f $rpmFiles ) {
        open( RPM_FILES, "< $rpmFiles" );
        while ( <RPM_FILES> ) {
            my $line = $_;
            print RPM_SPECFILE "$line";
        }
        print RPM_SPECFILE "\n";
        close( RPM_FILES );
    }

    # 11b) the %files section for each subpackage
    foreach $subsys ( $self->get_subsystems() ) {
        my $id = $subsys->get_id();
        my $rpmSubsysFiles = "$main::ibTmpDir/../rpm";
        $rpmSubsysFiles = $rpmSubsysFiles . $id . "Files.txt";
        if ( -f $rpmSubsysFiles ) {
            open( RPM_SUBSYSFILES, "< $rpmSubsysFiles" );
            while ( <RPM_SUBSYSFILES> ) {
                my $line = $_;
                print RPM_SPECFILE "$line";
            }
            print RPM_SPECFILE "\n";
            close( RPM_SUBSYSFILES );
        } else {
            print RPM_SPECFILE "\%files $id\n\n";
            foreach $tag ($subsys->get_exports()) {
                print RPM_SPECFILE "#\n";
                print RPM_SPECFILE "# $tag files\n";
                print RPM_SPECFILE "#\n";
                foreach $to (@{$Product::subsysPkg{$tag}}) {
                    if ( $main::relocatePrefix ne "" ) {
                        print RPM_SPECFILE "$main::relocatePrefix";
                        print RPM_SPECFILE "/";
                    }
                    print RPM_SPECFILE "$to\n";
                }
            }
            print RPM_SPECFILE "\n";
        }
    }

    print RPM_SPECFILE "# End of RPM spec file.\n";
    close( RPM_SPECFILE );
}

########################################################################
# MAIN package!
########################################################################

package main;
use English;  # nicer variable names for builtin perl variables!
use Cwd;      # get pathname of current working directory
if ($^O eq "MSWin32") {
use File::Path;
}

#
# globals
# 

# set from command line
$main::specFileName    = "";
$main::ibDir           = defined($ENV{"IBDIR"}) ? $ENV{"IBDIR"} : "";
$main::ibTmpDir        = ".";
@main::collectionFiles = ();
$main::baseDir         = defined($ENV{"IBBASEDIR"}) ? $ENV{"IBBASEDIR"} : "";
$main::quiet           = 0;
$main::nobuild         = 0;
$main::expandEnvVars   = 1;  # by default expand env variables in filenames
$main::targetPlatform  = "linux";
$main::relocatePrefix  = "/var/wizzer";
$main::commandShell    = defined($ENV{"COMSPEC"}) ? $ENV{"COMSPEC"} : "";


# "constants"
$collectionHeader = "#InstallBuilder Collection 1.0";

##############################
&main;
exit(0);
##############################

sub main
{
    &parseCmdLine;

    if (! (($main::targetPlatform eq "windows") ||
           ($main::targetPlatform eq "linux"))) {
        die ( "$main::targetPlatform not supported\n" );
    }

    my $origTmpDir = $main::ibTmpDir;
    if ($main::targetPlatform eq "windows") {
        # use Windows "\" to delimit directory hierarchy
        $main::ibTmpDir .= "\\instcruft";
    } else {
        # use Unix "/" to delimit directory hierarchy
        $main::ibTmpDir .= "/instcruft";
    }

    if ( -f $main::ibTmpDir ) {
        die ( "$main::ibTmpDir is not a directory\n" );
    }

    # clean up some!
    &util::destroyDirectoryContents( $origTmpDir, "instcruft" );
    if ($main::targetPlatform eq "windows") {
        &util::destroyDirectoryContents( ".", ".*Install\\.exe" );
    } elsif ($main::targetPlatform eq "linux") {
        &util::destroyDirectoryContents( ".", ".*Install\\.rpm" );
    }
    if ( ! -d $main::ibTmpDir ) {
        mkdir( $main::ibTmpDir, 0777 ) || &util::croak( "Couldn't make directory '$main::ibTmpDir': $ERRNO" );
    }

    if ($main::targetPlatform eq "linux") {
        my $rpmrcFile = "$main::ibTmpDir/rpmrc";
        my $rpmmacrosFile = "$main::ibTmpDir/rpmmacros";

        #
        # make required directories for RPM
        #
        mkdir( "$main::ibTmpDir/BUILD", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/BUILD': $ERRNO" );
        mkdir( "$main::ibTmpDir/RPMS", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/RPMS': $ERRNO" );
        mkdir( "$main::ibTmpDir/RPMS/i386", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/RPMS/i386': $ERRNO" );
        mkdir( "$main::ibTmpDir/SOURCES", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/SOURCES': $ERRNO" );
        mkdir( "$main::ibTmpDir/SPECS", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/SPECS': $ERRNO" );
        mkdir( "$main::ibTmpDir/SRPMS", 0777) ||
            &util::croak( "Couldn't make directory '$main::ibTmpDir/SRPMS': $ERRNO" );

        #
        # create required .rpmrc file
        #
        open( OUT, "> $rpmrcFile" );
        print OUT "macrofiles:        /usr/lib/rpm/macros:/usr/lib/rpm/\%{_target}/macros:/etc/rpm/macros:/etc/rpm/\%{_target}/macros:$rpmmacrosFile";
        close( OUT );

        #
        # create required .rpmmacros file
        #
        open( OUT, "> $rpmmacrosFile" );
        print OUT "%_topdir $main::ibTmpDir";
        close( OUT );
    }

    my %productDict = newDictFromFile Product( $specFileName );

    if ($main::targetPlatform eq "windows") {
        &icompFiles(@main::collectionFiles);

        my $product;
        foreach $product ( values %productDict ) {
            print "creating " . $product->get_id() . "\n";
            print $product->dump();

            $product->createDistributionDir();
            $product->copyInstallShieldFiles();
            $product->generateSetupRules();
            $product->compileSetupRules();
            $product->polishPackage();
            $product->createSEI();
        }
    }

    if ($main::targetPlatform eq "linux") {
        &icompFiles(@main::collectionFiles);

        my $product;
        foreach $product ( values %productDict ) {
            print "creating " . $product->get_id() . "\n";
            print $product->dump();

            $product->buildRpmSpecFile();
            #
            # print the contents of the packages
            #
            #foreach $tag (sort keys %Product::subsysPkg) {
            #    print "$tag:  @{$Product::subsysPkg{$tag}}\n";
            #}

            $product->createDistributionDir();

            if ( ! $main::nobuild ) {
                #
                # Build rpm command
                #
#                my $cmd = "rpm --rcfile /usr/lib/rpm/rpmrc:$main::ibTmpDir/rpmrc -bb $main::ibTmpDir/SPECS/ism.spec";
                my $cmd = "rpm --rcfile /usr/lib/rpm/rpmrc:$main::ibTmpDir/rpmrc -bb $product::rpmSpecFile";
                print "\nExecuting: $cmd\n";
                &util::croakingSystem( $cmd );

                $cmd = "cp $main::ibTmpDir/RPMS/i386/* .";
                &util::croakingSystem( $cmd );
            }
        }
    }

    if ( ! $main::nobuild ) {
        &util::destroyDirectoryContents( $origTmpDir, "instcruft" );
    }
}

# effects: prints a usage message
sub usage
{
    print <<EOS;
usage: perl buildInstallers.pl [options]
  options:
    -baseDir   /path/collection/is/relative/to -- (required!)
                 (defaults to value of \$IBBASEDIR if it's set)
    -collect   /path/to/collectionFile   -- file to read what
                 to compress (required). May be given more than once.
    -ibDir     /path/to/installBuilder   -- set the installBuilder's home 
                 (required, but defaults to value of \$IBDIR)
    -ibTmpDir  /path/for/temp/files      -- set path for temporary files
                 (defaults to cwd)
    -n                                   -- build staging directory,
                 but do not execute the rpm spec file
    -q                                   -- quiet mode
    -relocate  /path/to/relocation       -- relocation prefix
    -spec      /path/to/specFile         -- location of spec file
    -target    windows | linux (default) -- target platform

    Note: later options will override earlier ones! (except -collect)
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
        
        if ( $argName eq "-n" ) {
           $main::nobuild = 1;
        }
        elsif ( $argName eq "-q" ) {
           $main::quiet = 1;
        }
        elsif ( $argName eq "-dontExpandEnvVars" ) {
            $expandEnvVars = 0;
        }
        elsif ( $argName eq "-spec" ) {
           $main::specFileName = $argValue;
           $i++;
        }
        elsif ( $argName eq "-collect" ) {
           push( @main::collectionFiles, $argValue );
           $i++;
        }
        elsif ( $argName eq "-ibDir" ) {
           $main::ibDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-ibTmpDir" ) {
           $main::ibTmpDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-baseDir" ) {
           $main::baseDir = $argValue;
           $i++;
        }
        elsif ( $argName eq "-target" ) {
           $main::targetPlatform = $argValue;
           $i++;
        }
        elsif ( $argName eq "-relocate" ) {
           $main::relocatePrefix = $argValue;
           if ( $main::relocatePrefix eq "None" ) {
               $main::relocatePrefix = "";
           }
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
    for $varName ( "specFileName", "baseDir", "ibDir" ) {
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

    if ($main::ibTmpDir eq ".") {
        $main::ibTmpDir = cwd();
    }

    $main::ibDir    = &util::makeAbsolutePath($ibDir);
    $main::ibTmpDir = &util::makeAbsolutePath($ibTmpDir);
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

#effects: icompresses files as described in the given files
sub icompFiles
{
    # parse args
    my @files = @_;

    # read the file into an array!
    my @lines = ();
    my $file;
    
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
                $line = &util::evalWithEnvVars($line);
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
            &util::croak( "$from isn't a file" );
        }

        # $realFrom remembers where to icomp from
        # usually, its the same as $from, but the file is supposed
        # to have a different name once its installed, i copy
        # it first and reset $realFrom.
        my $realFrom = $from;

        # if needed, copy the file to the name we want it to install as
        if ( &util::basename($to) ne &util::basename($from) ) {
            $realFrom = "$ibTmpDir/" . &util::basename($to);

            my @cmd = ( "cp", $from, $realFrom );
            &util::croakingSystem( \@cmd );
        }

        #
        # do the icomp!
        #
        my $tag;
        for $tag ( split( /\s+/, $tags ) ) {
            if ($main::targetPlatform eq "windows") {
                my $shellCmd = "$main::commandShell";
                my $icompCmd = &util::dosSlashes( "$main::ibDir\\installshieldbin\\icomp" );
                my $icompFrom = &util::dosSlashes( "$realFrom" );
                my $icompTag = &util::dosSlashes( "$main::ibTmpDir\\$tag.z" );
                my $icompDir = &util::dosSlashes( &util::dirname($to) );
                my @cmd = ( $shellCmd, "/c", $icompCmd, $icompFrom, $icompTag, $icompDir );
                &util::croakingSystem( \@cmd );
            } elsif ($main::targetPlatform eq "linux") {
                # print "RealFrom: ", "$realFrom", "\n";
                # print "SubPackage: ", "$tag", "\n";
                # print "To: ", "$to", "\n";

                # build staging area
                my $toDir = "$main::ibTmpDir/BUILD";
                $toDir = $toDir . "/" . &util::dirname($to);
                # print "To Dir: ", $toDir, "\n";
                if ( ! -d $toDir ) {
#                   mkdir( "$toDir", 0777 ) ||
                        &util::croak( "Couldn't make directory '$toDir': $ERRNO" );
                    mkpath( "$toDir", 0, 0777 );
                }

                my $shellCmd = "$main::commandShell";
                my @cmd = ( $shellCmd, "/c", "cp", $realFrom, $toDir);
                &util::croakingSystem( \@cmd );

                # gather files with respective subpackages
                push( @{$Product::subsysPkg{$tag}}, $to );
            }
        }

        # if needed, delete the temporary copy!
        if ( $realFrom ne $from ) {
            # $realFrom is a copy, so toast it!
            unlink( $realFrom ) || 
                &util::croak( "unlink($realFrom) failed: $ERRNO" );
        }
    }
}
