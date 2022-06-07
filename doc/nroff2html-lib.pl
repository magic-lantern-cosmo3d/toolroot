############################################################################
#									   #
# Copyright 1997 Silicon Graphics, Inc.  ALL RIGHTS RESERVED		   #
# 									   #
# UNPUBLISHED -- Rights reserved under the copyright laws of the United	   #
# States.   Use of a copyright notice is precautionary only and does not   #
# imply publication or disclosure.					   #
# 									   #
# U.S. GOVERNMENT RESTRICTED RIGHTS LEGEND:  Use, duplication or	   #
# disclosure by the Government is subject to restrictions as set forth in  #
# FAR 52.227.19(c)(2) or subparagraph (c)(1)(ii) of the Rights in	   #
# Technical Data and Computer Software clause at DFARS 252.227-7013        #
# and/or in similar or successor clauses in the FAR, or the DOD or NASA	   #
# FAR Supplement.  Contractor/manufacturer is Silicon Graphics, Inc.,	   #
# 2011 N. Shoreline Blvd. Mountain View, CA 94039-7311.  THE CONTENT OF    #
# THIS WORK CONTAINS CONFIDENTIAL AND PROPRIETARY INFORMATION OF SILICON   #
# GRAPHICS, INC. ANY DUPLICATION, MODIFICATION, DISTRIBUTION, OR           #
# DISCLOSURE IN ANY FORM, IN WHOLE, OR IN PART, IS STRICTLY PROHIBITED     #
#									   #
############################################################################
#
#ident "$Revision: 1.1 $"
#
# nroff2html-lib.pl
#
# Common variables and functions used to convert nroff formatted man
# pages and release notes into HTML.
# 
# This perl library requires perl5.
#
############################################################################

$bgcolor    = "#f9f9f9";
$textcolor  = "#000000";

$doctype    = "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 3.2//EN\">\n";
$bHTML	    = "<HTML>\n";
$eHTML	    = "</HTML>\n";

$svr_name = $ENV{'SERVER_NAME'};
$svr_port = $ENV{'SERVER_PORT'};
if($svr_name ne ""){
   $bTitle = "<HEAD>\n<!-- BASE HREF=\"http://$svr_name:$svr_port\" -->" .
             "\n   <TITLE>";
} else {
   $bTitle =  "<HEAD>\n   <TITLE>";
}

if($STYLESHEET){
    if($domain eq "man"){
    	$stylesheet_ext = "-man";
    }else{
    	$stylesheet_ext = "-relnote";
    }
    $Link = "<LINK  REL=StyleSheet HREF=\"" .
	"/infosearch/C/sgidoc${stylesheet_ext}.css\">\n" .
	"   <!-- File reference to style sheet for " .
	"preview in workarea -->\n   <LINK  REL=StyleSheet " .
	"HREF=\"file:/usr/lib/infosearch/C/sgidoc${stylesheet_ext}.css\">";
 
    $eTitle	    = "</TITLE>\n   $Link\n</HEAD>\n";
    $bBody	    = "<BODY>";
}else{
    $eTitle	    = "</TITLE>\n</HEAD>\n";
    $bBody	    = "<BODY BGCOLOR=\"$bgcolor\">";
}

$eBody	    = "</BODY>\n";
$bHeader1   = "<H3>";
$eHeader1   = "</H3>\n";
$bRelHeader1= "<H3>";
$eRelHeader1= "</H3>\n";
$bSection   = "\n<H4>";
$eSection   = "</H4>\n\n";
$bSubSection= "\n<H5>";
$eSubSection= "</H5>\n";

$bParagraph = "<P>";  
$eParagraph = "\n</P>\n";
$bPreformat = "\n<PRE>\n";
$ePreformat = "\n</PRE>\n";
$bFiles	    = "<DL>\n<DD>\n";
$eFiles	    = "\n</DD>\n</DL>\n";
$bList	    = "<DL>";
$eList	    = "\n</DL>";
$bListTitle = "\n<DT>";
$eListTitle = "</DT>";
$ListItem   = "<DD>";
$newline    = "<BR>\n";
$eListPara  = "\n";

# Character Formating Tags
$bItalic    = "<I>";
$eItalic    = "</I>";
$bBold	    = "<B>";
$eBold	    = "<\/B>";
$bTypeWriter= "<TT>";
$eTypeWriter= "</TT>";
$bUnderline = "<U>";
$eUnderline = "</U>";

# Character Entities
$lessThan   = "&lt;";
$greaterThan= "&gt;";
$space	    = "&nbsp;";
$amp	    = "&amp;";

$bRow   ="\t<TR VALIGN=TOP>\n";
$eRow   ="\n\t</TR>\n";
$bCol   ="\t\t<TD>";
$eCol   ="</TD>\n";

# List Formatting Tags
%bListTag   = ();
%bListItem  = ();
%eListItem  = ();
%eListTag   = ();

if($STYLESHEET){
$bListTag{"numbered"}	= "<OL>";
$bListTag{"bullet"}	= "<UL>";
}else{
$bListTag{"numbered"}	= "<OL TYPE=1>";
$bListTag{"bullet"}	= "<UL TYPE=DISC>";
}

$bListTag{"default"}	= "<DL>";

$bListItem{"numbered"}	= "<LI VALUE=X>";
$bListItem{"bullet"}	= "<LI>";
$bListItem{"default"}	= "<DD>";

if($STYLESHEET){
$eListItem{"numbered"}	= "\n</LI>";
$eListItem{"bullet"}	= "\n</LI>";
$eListItem{"default"}	= "</DD>";
}else{
$eListItem{"numbered"}	= "\n<BR>\n<BR>\n</LI>";
$eListItem{"bullet"}	= "\n<BR>\n<BR>\n</LI>";
$eListItem{"default"}	= "</DD>\n<DD><BR>\n</DD>\n";   
}

$eListTag{"numbered"}	= "</OL>";
$eListTag{"bullet"}	= "</UL>";
$eListTag{"default"}	= "</DL>";
$eListTag{"hanging"}	= "</DL>";


$lastSectionLevel=0;
$lastListType="";
$listType="";

$SecTitleComment= "\n<!-- Section Title -->";
$TitleComment	= "\n<!-- Hanging List: indent=I level=L" .
                  "/ Bindent=BI Blevel=BL -->\n";
$BodyComment	= "\n<!-- Body Paragraph: indent=I level=L last=X -->\n";
$UnknownComment	= "<!-- Unknown Format: indent=I level=L  -->\n";

$copyWriteComment="\n<!-- 
Copyright 1996 Silicon Graphics, Inc.
ALL RIGHTS RESERVED

UNPUBLISHED:  Rights reserved under the copyright laws of the United
States.   Use of a copyright notice is precautionary only and does not
imply publication or disclosure.

U.S. GOVERNMENT RESTRICTED RIGHTS LEGEND:
Use, duplication or disclosure by the Government is subject to restrictions
as set forth in FAR 52.227.19(c)(2) or subparagraph (c)(1)(ii) of the Rights
in Technical Data and Computer Software clause at DFARS 252.227-7013 and/or
in similar or successor clauses in the FAR, or the DOD or NASA FAR
Supplement.  Contractor/manufacturer is Silicon Graphics, Inc.,
2011 N. Shoreline Blvd. Mountain View, CA 94039-7311.
THE CONTENT OF THIS WORK CONTAINS CONFIDENTIAL AND PROPRIETARY
INFORMATION OF SILICON GRAPHICS, INC. ANY DUPLICATION, MODIFICATION,
DISTRIBUTION, OR DISCLOSURE IN ANY FORM, IN WHOLE, OR IN PART, IS STRICTLY
PROHIBITED WITHOUT THE PRIOR EXPRESS WRITTEN PERMISSION OF SILICON
GRAPHICS, INC.
-->";

$DEBUG=0; # Set to 1 to enable debug mode

#######################################################################
#
# void HTMLHeaderFormat(String $buf)
#
#######################################################################

sub HTMLHeaderFormat{

    my($title) = @_;
    my($prefix) = $domain;

    if($domain eq "relnotes"){
	$prefix="relnote";
    }

    print "${doctype}<!-- SGI ${prefix}2html VERSION 2.0 -->\n" , 
    "${bHTML}${bTitle}${title}${eTitle}${bBody}" ,
    "$copyWriteComment\n\n";

}

#######################################################################
#
# void headerNumberFormat(String_ref \$buf,int level)
#
# Output an HTML <H$level>$buf</H$level>
#
#######################################################################

sub headerNumberFormat{

    my($buf_ref,$level) = @_;

    print "<H${level}>$$buf_ref</H${level}>\n"; 

}

#######################################################################
#
# String setDomainRoot(String $srvConfigFile,String $domain)
#
#######################################################################

sub setDomainRoot{
    
    my($svrConfig,$domain) = @_;
    my($root) = "";
    
    if (-e $svrConfig){  # File may not exist - server subsystem
	
	open(CONFIG, $svrConfig) 
	    || die "Unable to open $svrConfig: $!\n";
	
	while(<CONFIG>){
	    if(/^${domain}Path\s*=\s*(.+)/){
	        $root=$1;
	    }	
        }
    
        if($domain eq "man"){
	    $root =~ s/\/usr\/share\/catman\/SGIindex//;
        }elsif($domain eq "relnotes"){
	    $root =~ s/\/usr\/relnotes\/SGIindex//;
        }
    }

    return($root);

}

#######################################################################
#
# void HTMLTrailerFormat(void)
#
#######################################################################

sub HTMLTrailerFormat{

    &endIndentedSection();     # Close any open lists
    print "${eBody}${eHTML}";

}

#######################################################################
#
# void HTMLCharFormat(String_ref \$buf)
#
#######################################################################

sub HTMLCharFormat{

    my($buf_ref) = @_;
 
    my($tmpLessThan)="\200";
    my($tmpGreaterThan)="\201";

    # Possible BUG - What about other entities?
    $$buf_ref =~ s/\&/$amp/go;
    
    # Temporily change < & > to another character
    $$buf_ref =~ tr/\</\200/;
    $$buf_ref =~ tr/\>/\201/;
    
    # F4 to Strong Typewriter  
    $$buf_ref =~ s/_\x8.\x8.\x8.\x8(.)/
	$bBold$bTypeWriter$1$eTypeWriter$eBold/gox;

    # F3 to Bold		
    $$buf_ref =~ s/.\x8.\x8.\x8(.)/$bBold$1$eBold/go;	
    
    # F2 to Italic
    $$buf_ref =~ s/_\x8(.)/$bItalic$1$eItalic/go;

    # Remove Duplicate (Nested) Formatting Tags
    $$buf_ref =~ s/$eItalic(\ *)$bItalic/$1/go;	
    $$buf_ref =~ s/$eBold(\ *)$bBold/$1/go;
    $$buf_ref =~ s/$eTypeWriter(\ *)$bTypeWriter/$1/go;
    $$buf_ref =~ s/$eTypeWriter$eBold(\ *)$bTypeWriter$bBold/$1/go;

    $$buf_ref =~ s/$tmpLessThan/$lessThan/go;
    $$buf_ref =~ s/$tmpGreaterThan/$greaterThan/go;

} 

#######################################################################
#
# void addLinks(String_ref \$buf)
#
#######################################################################

sub addLinks{

    my($buf_ref) = @_;
    my($script_name) = $ENV{SCRIPT_NAME} || "/cgi-bin/infosrch.cgi";
    my($cgi) = "$script_name\?cmd=getdoc&db=man&fname=";
    my($tag)="<[^>]+>";
    
    # Add_disk in fx(1) is broken.
    # Try to make this simplier & cleaner, but measure performance 

    # Match command(1M) and make it a hyperlink to 
    $$buf_ref =~ s/<B>([\w.\-_]+)<\/B>\(([1-8])[a-zA-Z]{0,2}\)/<A HREF="$cgi$2%20$1">$&<\/A>/go;

    $$buf_ref =~ s/<B><TT>([\w.\-_]+)<\/TT><\/B>\(([1-8])[a-zA-Z]{0,2}\)/<A HREF="$cgi$2%20$1">$&<\/A>/go;

    $$buf_ref =~ s/<I>([\w.\-_]+)<\/I>\(([1-8])[a-zA-Z]{0,2}\)/<A HREF="$cgi$2%20$1">$&<\/A>/go;

    $$buf_ref =~ s/<I>([\w.\-_]+)<\/I>\(<I>([1-8])[a-zA-Z]{0,2}<\/I>\)/<A HREF="$cgi$2%20$1">$&<\/A>/go;

    $$buf_ref =~ s/([\w.\-_]+)\(([1-8])[a-zA-Z]{0,2}\)/<A HREF="$cgi$2%20$1">$&<\/A>/go;

    $$buf_ref =~ s/($tag*\#include$tag*\s+$tag*\&lt\;)(\S+)(\&gt\;$tag*)/$1<A HREF=\"file:\/usr\/include\/$2\">$2<\/A>$3/go;

    # This fixes non-highlight #includes (Cosmo's csAction)
    # Fix $tag above to deal with both.  This is a bit trick, since we're grabbing
    # $2 & $3 and if we add more ()'s it'll throw if off. 
    $$buf_ref =~ s/(\#include\s+\&lt\;)(\S+)(\&gt\;)/$1<A HREF=\"file:\/usr\/include\/$2\">$2<\/A>$3/go;

}

#######################################################################
#
# void endIndentedSection(void) - end an indented section
#
#######################################################################

sub endIndentedSection{

    if($lastSectionLevel){
	
	$closeSection=&endListTag(0,$lastSectionLevel);

	print "<!-- End Indented Section: ",
	"lastSectionLevel=$lastSectionLevel -->\n" 
	    unless($DEBUG==0);

 	print "$closeSection\n";
    }

    $lastSectionLevel=0;    
    
}

#######################################################################
#
# void removeHTMLTags(String_ref \$buf)
#
# Only removes the very basic HTML formatting
#
# BUG: need to translate entities?
#
#######################################################################

sub removeHTMLTags{

    my($buf_ref) = @_;

    $$buf_ref =~ s/<[^>]*>//g;

    if($domain ne "man"){
	$$buf_ref =~ s/_/\ /g; # BUG - This breaks strtok_r man title
    }
}

#######################################################################
#
# int findIndent(String_ref \$buf,int tabsize)
#
#######################################################################

sub findIndent{

    my($buf_ref,$tabsize) = @_;

    my($isIndent) = 1;  
    my($indent) = 0;   
    my($c) = 0;

    while($isIndent == 1){
    	
	if (substr($$buf_ref, $c, 1) eq " " ){
	    $indent++;
	}
        elsif (substr($$buf_ref, $c, 1) eq "\t" ){
	    $indent = $indent + $tabsize;
	}
	else{
	    $isIndent=0;
	}
	$c++;
    }
   
    return($indent);
}

#######################################################################
#
# int findLastIndent(String_ref \$buf,int tabsize)
#
#######################################################################

sub findLastIndent{

    my($buf_ref,$tabsize) = @_;
    my($isIndent) = 1;  
    my($lindent,$c) = 0;  
    my($pos) = length($$buf_ref);

    $c = rindex($$buf_ref, "\n", $pos-1);
    $c++;

    while($isIndent == 1){
	
	if ( substr($$buf_ref, $c, 1) eq " " ){
	    $lindent++;
	}elsif ( substr($$buf_ref, $c, 1) eq "\t" ){
	    $lindent = $lindent + $tab;
	}else{
	    $isIndent=0;
	}
	$c++;
    }

    return($lindent);
}


#######################################################################
#
# int hasInternalSpace(String_ref \$buf)
#
# return the number of "gaps" found.  Don't count ".  " as
# a gap.
#
#######################################################################

sub hasInternalSpace{

    my $buf_ref = shift;

    # Don't match ".  " or ".)  " or ":  " or "\n  "
    # Or ".</TAG>  ", etc.

    my @spaces = ($$buf_ref =~ m/[^\.\ \n\:>\)](<\/[A-Z]{1,5}>)*\ {2,}\S/g);

    return($#spaces+1);

}

#######################################################################
#
# int getLines(String_ref \$buf)
#
# number of lines in the section
#
#######################################################################

sub getLines{
    
    my($buf_ref) = @_;
    my(@ncount)  = ($$buf_ref =~ m/\n/g);

    if($#ncount >= 0){
	return($#ncount + 2); 
    }
    return(1); 
    
}

#######################################################################
#
# int numColumns(String_ref \$buf) 
#
#######################################################################

sub numColumns{

    my($buf_ref) = @_;
    my($tmp) = $$buf_ref;
    my(@ncolumns) = split(/\ \ \ +/, $tmp);

    return($#ncolumns);

}

#######################################################################
#
# void determineFormat(String_ref \$buf,@format)
#
# Correctly indentify the paragraph & pass it into formatting function
#
#######################################################################

sub determineFormat{
    
    my($buf_ref,@format) = @_;

    if(&isList($buf_ref)){  # Bulleted or Numbered list
	&indentedSectionFormat($buf_ref, @format);
	return;
    }

    if(&isTable($buf_ref,@format)==1){
	&sectionTableFormat($buf_ref,$format[4]);
    }elsif(&isHangingList($buf_ref, @format)){
	&hangingListFormat($buf_ref, @format);
    }else{
	if(&hasInternalSpace($buf_ref) > 0){
	    &unknownFormat($buf_ref, $format[0]);
	}else{
	    if(&isStraightLeftMargin($buf_ref,@format)){
	       if(&isWrapped($buf_ref,$indentedPage)){
		   &indentedSectionFormat($buf_ref, @format);
	       }else{
		   &sectionListFormat($buf_ref,@format);
	       }
	   }else{
	       &unknownFormat($buf_ref, $format[0]);
	   }
	}
    } 
}

#######################################################################
#
# void sectionListFormat(String_ref \$buf,@format)
#
# Format a paragraph as a non-wrapping list of items - not 
# as a wrapping body of text.  Special treatment to allow
# wrapping of functions & command line options in the 
# man page SYNOPSIS section.
#
#######################################################################

sub sectionListFormat{

    my $buf_ref = shift;
    my(@format) = @_;
    my($indent,$lastIndent,$lines,$level,$tab) = @_;

    my($bTT) = ""; # For now, we will *not* automatically use
    my($eTT) = ""; # a fixed font.

    &endIndentedSection();
    
    print "\n<!-- Section List Paragraph:",
    "level=$level indent=$indent-->\n" 
	unless($DEBUG==0);
 
    print &dupTag("<DL>\n", $level); # Open the list
    $$buf_ref =~ s/^\s+//; # Remove leading spaces

    if ($STYLESHEET==1){
	$$buf_ref = "<DT>${bTT}$$buf_ref";
	$$buf_ref =~ s/\n\ +/${eTT}<\/DT>\n\<DT>${bTT}/go;
	$$buf_ref =~ s/$/${eTT}<\/DT>/o;
    }else{
	$$buf_ref = "<DD>${bTT}$$buf_ref";
	$$buf_ref =~ s/\n\ +/${eTT}<\/DD>\n\<DD>${bTT}/go;
	$$buf_ref =~ s/$/${eTT}<\/DD>/o;
    }
    
    # Clean up dup character tags:
    
    #$$buf_ref =~ s/${bTT}${bTT}/${bTT}/go;
    #$$buf_ref =~ s/${eTT}${eTT}/${eTT}/go;

    print $$buf_ref;				   # Print the list body
    print "\n<DD><BR>\n</DD>" unless($STYLESHEET); # Append vertical spacing
    print "\n" , &dupTag("</DL>\n", $level); 	   # Close the list

    $lastSectionLevel=0;
    
}

#######################################################################
#
# void bodyFormat(String_ref \$buf)
#
# This is a simple HTML body paragraph: <P>my para</P>.
# Should only be called when STYLESHEET==1
#
#######################################################################

sub bodyFormat{

    my($buf_ref) = @_;
   
    if($DEBUG){ 
	print "<!-- Body Paragraph -->\n";   
    }
    
    print "<P>\n", $$buf_ref, "\n</P>\n";
	    
    $lastListType	= $listType;
    $lastSectionLevel	= $level;
    
}

#######################################################################
#
# Boolean isHangingList(String_ref \$buf, @format)
#
#######################################################################

sub isHangingList{
    
    my($buf_ref,$indent,$lastIndent,$lines,$level,$tab) = @_;

    my($true) = 1;
    my($false) = 0;
   
    # 5 or more space followed by a title and a \n or at least 2 spaces
    # Add . at end to make sure we don't get a body para that ends in \n.

    if ($$buf_ref =~ /^\ {3,}\d{1,3}\.\s+/){  # Match "   1. "
	return($false);  # Don't match a numbered list
    }

    # BUG - 1 lines titles with only 1 space following the 
    # title will incorrectly return false.

    if($lines == 1){
	if($$buf_ref =~ /^\ {5,}([<\/BTI>\w]\ ?)*(\w)<\/(B|I)>\ {2,}[A-Z](\w\ ?)*(\w)/){
	    my $tmp_buf = $$buf_ref;
	    $tmp_buf = s/^\ {5,}(\w\ ?)*(\w)<\/(B|I)>\ {2,}//; # Remove title
	    if(&hasInternalSpace(\$tmp_buf) > 0){
		return($false);
	    }else{
		return($true);
	    }
	}else{
	    return($false);
	}

    }

    if ($$buf_ref =~ /^\ {3,}\S[\S\ ]*(<\/(B|I)>)?(\n|\ {2,})./){       
	if ($lines == 1){
	    return($true); 
	}elsif($indent < $lastIndent){ # Good Heuristic for a Section Header
	    # Make sure the valid body section
	    my($body_tmp) = $$buf_ref;
	    $body_tmp =~ s/^.+\n//g; # Remove the first line;
	    if(&hasInternalSpace($body_tmp) > 0){
		return($false);
	    }else{
		my(@format) = getIndentData(\$body_tmp,$tab);
		if(&isStraightLeftMargin($body_tmp,@format)){
		    return($true);
		}else{
		    return($false); 
		}
	    }
	}else{
	    return($false);  #This still could be a section header? 
	}
    }else{
	return($false);
    }    

}

#######################################################################
#
# void sectionHeaderFormat(String $buf)
#
#######################################################################

sub sectionHeaderFormat{
    
    my($buf) = @_;

    if ($DEBUG){
    	print "$SecTitleComment";
    }
    print $bSection, $buf, $eSection;

    $lastSectionLevel=0; 

}

#######################################################################
#
# void indentedSectionFormat(String_ref \$buf, @format);
#
#######################################################################

sub indentedSectionFormat{

    my($buf_ref,$indent,$lastIndent,$lines,$level,$tab) = @_;

    my $bulletItem = 0;
    my $deltaLevel = 0;
    my $startTag   = "";
    
    # Determine the type of list
    
    if ($$buf_ref =~ s/^\s+\+\x8o//){		# Bulleted List
	$listType = "bullet";
    }elsif($$buf_ref =~ s/^\s+\-(\s+)/$1/){	# Bulleted List
	$listType = "bullet";
    }elsif($$buf_ref =~ s/^\s+(\d{1,3})(\.|\))\s//){# Numbered List
	$listType = "numbered";
	$numValue = $1;  			# <LI VALUE=$number ($1)> 
    }else{					# Descriptive List
	$listType = "default";
    }
     
    if($STYLESHEET==1){
    	&endIndentedSection();
        $level--; 
	if (($level==0) && ($listType eq "default")){         
	    &bodyFormat($buf_ref);
	    return;  
	}
    }elsif($lastListType ne $listType){	
	&endIndentedSection();  
    }

    # Bullet & Numbered Lists need to be indented an extra 
    # level in man pages.
    
    if($STYLESHEET==0){
	if ($domain eq "man"){
	    if($listType ne "default"){
		$level++; # Bulleted & Numbered lists need extra indenting
		# or else they line up left of body paragraphs
	    }
	}else{
	    if($listType eq "numbered"){
		$level++; #Indent numbered list
	    }
	}
    }
    
    if($level < 1){  # We need at least 1 level to make sure we are in a list
    	$level=1;    # (proper open & close list tags)
    }
    
    if($DEBUG){
    	$comment = $BodyComment;
	$comment =~ s/=I/=$indent/;
	$comment =~ s/=L/=$level/;
	$comment =~ s/=X/=$lastSectionLevel/;

	print $comment, "<!-- $listType list-->\n";   
    }

    # Set the correct indentation level
    # Build a "startTag" which is inserted in front of 
    # the current paragraph.
    
    $deltaLevel=($level-$lastSectionLevel);

    if($deltaLevel > 0){ # Indent
	$startTag = 
	    &dupTag("$bListTag{$listType}\n",$deltaLevel);
    }elsif($deltaLevel < 0){	    # Exdent
	$startTag = 
	    &endListTag($level, $lastSectionLevel);
    } 
    # else startTag = ""; (Same Level)
    
    # Prepend & append the appropriate list tags
    
    $$buf_ref =~ s/^\s*/${startTag}$bListItem{$listType}/o;    
    $$buf_ref =~ s/$/$eListItem{$listType}/o;

    if ($listType eq "numbered"){
  	$$buf_ref =~ s/(<LI VALUE=)X/$1${numValue}/;
    }

    $lastListType	= $listType;
    $lastSectionLevel	= $level;
    
    print $${buf_ref};
    
}

#######################################################################
#
# String endListTag($currentLevel,$lastSectionLevel) 
#
# Ideally, we should pop list tags in LIFO order to close
# But, it's easier to close lists of differing types completely 
# before we start a new list.  So, we use the current list's
# end tag to close it out. Or, we could close each list after
# each paragraph.
#
#######################################################################

sub endListTag{

    my $closeLevels = ($_[1] - $_[0]);
    my $endTag     = "";
    my $j          = 0;

    for($j=0;$j < $closeLevels;$j++){
    	$endTag = "${endTag}$eListTag{$lastListType}\n";
    }
    
    return($endTag);
}

#######################################################################
#
# String dupTag(String $tag,int $deltaLevel) 
#
#######################################################################

sub dupTag{

    my $buf        = shift;
    my $deltaLevel = shift;
    my $dupTagStr  = "";
    my $j          = 0;

    for($j=0;$j < $deltaLevel;$j++){
	$dupTagStr = $dupTagStr . $buf;
    }

    return($dupTagStr);
}

#######################################################################
#
# int indent2Level(int $indent)
#
#######################################################################

sub indent2Level{

    my($indent) = @_;
    my($level)  = 0;

    # Figure out the pre-6.5 format bug and do a more accurate
    # job of guessing the level if we're pre-6.5.  If we are
    # rununing 6.5, this section should be simplified.

    if($tab==5){ # Man Page

	if($indent>=5 && $indent<=9){
	    $level=1;
	}elsif($indent>=10 || $indent<=12 ){
	    $level=2;
	}elsif($indent>=13 && $indent<=19){
	    $level=3;
	}elsif($indent>=20 && $indent<=24){
	    $level=4;
	}elsif($indent==28 || $indent==27){
	    $level=5
	    }elsif($indent==32){
		$level=6
		}else{
		    if($ASSERT){
			die "Unknown indent $indent\n";
		    }else{
			$level = ($indent/$tab);
		    }
		}
	
    }else{   # Release Note
	
	if ($indent>=7 && $indent<=9){
	    $level=1;
	}elsif($indent>=10 && $indent<=14){
	    $level=2;
	}elsif($indent>=15 && $indent<=20){
	    $level=3;
	}else{
	    if($ASSERT){
		die "Unknown indent $indent\n";
	    }else{
		$level = ($indent/$tab);
	    }
	}  	 
	
    }
    
    return($level);

}

#######################################################################
#
# Boolean isTable(String_ref \$buf) 
#
#######################################################################

sub isTable{

    my($buf_ref) = @_;
    my($true)    = 1; 
    my($false)   = 0;

    if(&hasInternalSpace($buf_ref) < 2){ # Min 2 line & 2 columns
	return($false); # Performance
    }

    my(@lines) = split(/\n/, $$buf_ref);

    if ($#lines < 1){  # 1 line or less ($#lines = 0 for 1 item)
	return($false);
    }
    
    $headerColumns = &numColumns(\$lines[0]); # First line
    $lastColumns   = &numColumns(\$lines[$#lines]); # Last line

    if($headerColumns >= 2){
	# Simple Table?
	if($headerColumns == $lastColumns){

	    # Check to make sure all lines have the same columns
	    # No need to check the first & last again

	    for($i=1;$i<$#lines;$i++){
		if($headerColumns != &numColumns(\$lines[$i])){
		    # If columns are not equal, check if this 
		    # is a wrapped relnote table or man FILE
		    # section & reformat it to look like a simple
		    # table.  Otherwise, return false.
		    if($domain ne "man" || $currentSectionName eq "FILES"){
			$tmp_ref = &mergeRelnoteTable($buf_ref);
			if(&isTable($tmp_ref) == $true){
			    $$buf_ref = $$tmp_ref;			    
			    return($true);		       
			}
		    }
		    return($false); # Not same num of columns
		}
	    }
	    my(@format) = getIndentData($buf_ref,$tab);
	    if(&isStraightLeftMargin($buf_ref,@format)){
		return($true); # All cols same as header - simple table
	    }else{
		return($false); # Tables with centered left columns
		                # are too hard to indent.  How do you 
		                # pick a consistent indent level.
		                # see osview(1).
	    }

	# Check for relnotes domain with wrapped 2nd column
	}elsif(($headerColumns + $lastColumns) == 3){

	    $tmp_ref = &mergeRelnoteTable($buf_ref);
	    if(&isTable($tmp_ref) == $true){
		$$buf_ref = $$tmp_ref;
		return($true);  # Is a wrapped table
	    }else{
		return($false); # Not a wrapped table
	    }
	    
	}else{
	    return($false); # Not a simple table
	}

    }
    return($false); # No columns in line 1
}

#######################################################################
#
# String_ref mergeRelnoteTable(String_ref)
#
# Fixed wrapped column lines in relnotes & man FILES
# section to make this into a simple table.
#
#######################################################################

sub mergeRelnoteTable{

    my($buf_ref)  = @_;
    my(@outTable) = ();

    my(@tableLines) = split(/\n/, $$buf_ref);

    foreach $tblLine (@tableLines){
	# What about more than 2 columns?
        if(&numColumns(\$tblLine) == 2){
            push(@outTable, $tblLine);
        }else{                        # Overflow from previous line
            $tblLine =~ s/^\s+/\ /;   # Remove proceding spaces
            if($#outTable ge 0){
                $outTable[$#outTable] =~ s/$/$tblLine/;
	    }else{
		return(""); # this is probably not a relnote table
	    }
        }
    }

    my($tmp_buf) = join("\n",@outTable);

    return(\$tmp_buf);

}

#######################################################################
#
# void hangingListFormat(String \$buf, @format)
#
# This function is very complex.  Run a full test suite after making 
# any changes here.  An error in this function can cause a "run-away"
# list which over-indents the output off the right of the page like 
# and inverted staircase.
#
#######################################################################

sub hangingListFormat{

    my($buf_ref,$indent,$lastIndent,$lines,$level,$tab) = @_;
    my($deltaLevel) = 0;
    my($startTag)   = "";
    my($lastLineIndent) = $indent+$tab;
    $listType       = "hanging";

    if($STYLESHEET==1){
	$level--;
	&endIndentedSection(); 
    }elsif($lastListType ne $listType){	
	&endIndentedSection();  
    }
    
    my($lastLineLevel) = $level+1;
    $deltaLevel =($level-$lastSectionLevel);

    # Remove leading spaces
    $$buf_ref =~ s/^\ +//;
    
    # Find the division between the title & the body & 
    # insert <\/DT>\n<DD>

    unless($$buf_ref =~ s/(^[^\.\n\:]+)(\ {2,})/$1<\/DT>\n<DD>/){
	# If we can't find a gap of 2 spaces or more,
	# then the entire first line is the title, or
	# we need to look for a trailing character format
	# followed by 1 space in the first line
        # Make sure we don't hit ".  " - which is the end
	# of a sentence.
	
	# Make sure we don't accidentally hit titles with multiple 
	# words and bold formatting like:
	# 
	# <B>Initialize</B> <B>a</B> <B>Disk</B>
	# 
	# from DiskManager(1) - added [^<] to fix bug #559451
	unless($$buf_ref =~ s/(^[^\.\n\:]+<\/B>)(\ )([^<]\S+)/$1<\/DT>\n<DD>$3/){
	    # Just take the whole first line
	    # Must have at least 2 lines to be a hanging list
	    $$buf_ref =~ s/(\n)/<\/DT>\n<DD>/;
	}
    }

    # Remove trailing spaces after the title (ideally, fix above)
    $$buf_ref =~ s/(\ +)<\/DT>/<\/DT>/;

    if ($deltaLevel == 0){  # Just another item in the same list

	if($DEBUG){	
	    print "\n<!-- Same indent level -->";
	}
	
    }elsif($deltaLevel > 0){  # Start another List to indent section
	
	if($DEBUG){ 
	    print "<!-- Move Indent In -->\n";
	}
	
	$startTag = &dupTag("<DL>", $deltaLevel);
	
    }else{ # Close the last list - "exdent" the section
	
	if($DEBUG){
	    print "\n<!-- Move Indent Out -->\n";
	} 
	
	# BUG: Or should this really be lastListType?
	$startTag=&dupTag("</DL>", (-1*$deltaLevel));
		
    }

    $$buf_ref =~ s/^/$startTag\n<DL>\n<DT>/;  
    $$buf_ref =~ s/$/<\/DD>/;

    if ($DEBUG){
	$aTitleComment = $TitleComment;
	$aTitleComment =~ s/=I/=$indent/;
	$aTitleComment =~ s/=BI/=$lastLineIndent/;
	$aTitleComment =~ s/=L/=$level/;
	$aTitleComment =~ s/=BL/=$lastLineLevel/;
	print "\n<!-- lines = $lines -->\n";
	print "$aTitleComment";
    }
    
    print "$${buf_ref}";      
    print "\n<DD><BR>\n</DD>\n" unless ($STYLESHEET==1);

    $lastSectionLevel  = $level+1;
    $lastListType      = "hanging";

    # Important safety tip: always close hanging list sections.

    &endIndentedSection();

}


#######################################################################
#
# @format getIndentData(String_ref \$buf, int $tabsize)
#
# Need to change this function to return an array of values,
# instead of using globals.
#
#######################################################################

sub getIndentData{

    my($buf_ref,$tab) = @_;

    my(@format) = ();

    # $indent  	  = $format[0];
    # $lastIndent = $format[1];
    # $numlines   = $format[2];
    # $level 	  = $format[3];
    # $tab        = $format[4];

    $format[0] = &findIndent($buf_ref, $tab);
    $format[1] = &findLastIndent($buf_ref, $tab);	    
    $format[2] = &getLines($buf_ref);
    $format[3] = &indent2Level($format[0]);
    $format[4] = $tab;

    return(@format);
    
}

#######################################################################
#
# void sectionTableFormat(String_ref \$buf, int $tabsize)
#
# Format a simple table will the same number of columns for 
# each row in the table. 
#
#######################################################################

sub sectionTableFormat{

    my($buf_ref,$tab) = @_;
    my($bTable,$eTable) = "";
    my($tabsp) = "$space$space$space$space$space";
    my(@lines) = split(/\n/, $$buf_ref);

    if($STYLESHEET==1){
	$bTable="<TABLE>\n";
	$eTable="</TABLE>\n";
    }else{
	$bTable="\n<DL>\n<DL>\n<TABLE CELLPADDING=0>\n";
	$eTable="</TABLE>\n</DL>\n<DD><BR>\n</DD>\n</DL>";
    }
    
    for($i=0;$i <= $#lines;$i++){
	
	if($STYLESHEET == 0){
	    $lines[$i] =~ s/^[\s]+/<TR VALIGN=TOP>\n<TD>/;
	    $lines[$i] =~ s/\ {3,}|\t+/${tabsp}<\/TD>\n\n<TD>/go;
        }else{
	    $lines[$i] =~ s/^[\s]+/<TR>\n<TD>/;
	    $lines[$i] =~ s/\ {3,}|\t+/<\/TD>\n\n<TD>/g; 
	}
        
        $lines[$i] =~ s/$/<\/TD>\n<\/TR>\n\n/;
    }

    &endIndentedSection();

    if($STYLESHEET == 0){
        print &dupTag("<DL>\n", $level);
    }

    print $bTable;
    print @lines;
    print $eTable;

    if($STYLESHEET == 0){
        print &dupTag("\n</DL>", $level);
    }

}


#######################################################################
#
# void unknownFormat(String_ref \$buf) 
#
#######################################################################

sub unknownFormat{

    my($buf_ref) = @_;

    if($DEBUG){
    	$aUnknownComment = $UnknownComment;
        $UnknownComment =~ s/=I/=$indent/;
        $UnknownComment =~ s/=L/=0/;
        $$buf_ref =~ s/^/$UnknownComment/;
    }  
    
    $startTag=&endListTag(0, $lastSectionLevel);
    $lastSectionLevel=0;
    
    print "$startTag$bPreformat", $$buf_ref, $ePreformat;

}

#######################################################################
#
# void header1Format(String $buf)
#
#######################################################################

sub header1Format{

    my($buf) = @_;

    print $bHeader1, $buf, $eHeader1;

}

#######################################################################
#
# Boolean isWrapped(String_ref $buf, int $exdented)
#
# Determine if this section should be formatted as a wrapping/flowing
# body of text, or as a list with hard <BR> after each item.
#
#######################################################################

sub isWrapped{

    my($buf_ref,$exdented) = @_;

    my($true)    = 1;
    my($false)   = 0;
    my($lineMax) = 78;
    my($line1)   = "";
    my($line2)   = ""; 
    my($wrappedWord) = "";

    # Bug, this hueristic only checks for wrapping in the first 
    # line of the paragraph.

    if($$buf_ref =~ /([^\n]*)\n([^\n]*)(\n|$)/){ # Take the first line
	$line1 = $1;
	$line2 = $2;

	if($line2 =~ /\s+(\S+)/){ # First word from the 2nd line
	    $wrappedWord  = $1; 
	}else{
	    return($false); # Or ASSERT?
	}

    }else{
	return($false);  # Not even 2 lines
    }
    
    $line1 = "$line1 $wrappedWord";

    # Replace HTML entities with a single char for length count
    $line1 =~ s/\&[a-z]{2,3}\;/E/; 
    &removeHTMLTags(\$line1); 

    $lineLength = length($line1);

    # A page formatted with standard marcos is "exdented" 5 spaces
    # so we need to add 10 back in (5 for line1 & 5 for line2).
    # Also, the lines are wrapped 7 spaces earlier.
 
    # One thing that is kind of bogus is that for man pages, 
    # $exdented is really a bool, and for relnotes (compiler
    # relnotes are the indented pages) it's the amount of 
    # indentation
   
    if($exdented >= 1){
	if($domain eq "man"){
	    $lineLength = $lineLength + 10; # (2*$tab)
	    $lineMax = $lineMax - 7;
        }else{
	    $lineLength = $lineLength + $exdented;
	}
    }

    if($domain ne "man"){
	$lineMax = $lineMax - 10;
    }

    print "\n<!-- Line Length = $lineLength; Max = $lineMax -->\n" 
	unless ($DEBUG==0);
    
    if($lineLength >= $lineMax){
	return($true);
    }else{
	return($false);
    }

}

#######################################################################
#
# Boolean isList(String_ref $buf)
#
# Determine if this section is a bulleted or numbered list
#
#######################################################################

sub isList{

    my($buf_ref) = @_;

    my($true)    = 1;
    my($false)   = 0;

    if($$buf_ref=~/\ {5,}\+\x8o/){      # Bulleted List
	return($true);
    }elsif($$buf_ref=~/^\ {5,}\-\s+/){   # Bullet List starting with "-"
	return($true);
    }elsif($$buf_ref=~/^\ {5,}(\d{1,3})(\.|\))\s{1,4}/){  # Numbered List
	return($true);
    }

    return($false);

}

#######################################################################
#
# Boolean isStraightLeftMargin(String_ref $buf,@format)
#
# Determine if this section should be formatted as a wrapping/flowing
# body of text or list (true), or as a preformatted section of 
# text (false).
#
#######################################################################

sub isStraightLeftMargin{

    my($buf_ref,$indent,$lastIndent,$lines,$level,$tab) = @_;

    my($true)    = 1;
    my($false)   = 0;

    if($lines == 1){
	return($true);
    }elsif($indent != $lastIndent){
	return($false);
    }

    my(@paraLines) = split(/\n/,$$buf_ref);

    foreach (@paraLines){
	if(&findIndent(\$_,$tab) != $indent){
	    return($false);
	}
    }

    return($true);
}

#######################################################################
#
# void pageBreakRemoval(String_ref $buf)
#
# Look at each "---PAGE BREAK---" and 
#
#######################################################################

sub pageBreakRemoval{

    my($buf_ref) = @_;
    my($pos,$preline_pos,$postline_post) = 0;
    my($preline,$postline) = "";
    my($preindent,$postindent) = "";
    my($true)  = 1;
    my($false) = 0;
    my($merge) = $false;
    my($subsystemline) = 
	"^\s+(<I>[^<]+<\/I>)\.?){3}\ {3,}";

    # Page 1 break, with no preceding paragraph
    $$buf_ref=~s/^\n*---PAGE\ BREAK---\n//;

    while(($pos=index($$buf_ref,"\n---PAGE BREAK---\n")) >= 0 ){

	$preindent = 0;
	$postindent = 0;  # What if lines aren't found?

	if(($preline_pos = rindex($$buf_ref,"\n",$pos-1)) >= 0){
	    $preline = substr($$buf_ref,$preline_pos+1,($pos-$preline_pos-1));
	    #print STDERR "$preline\n";
	    $preindent  = &findIndent(\$preline,$tab);
	}else{
	    print STDERR "Missed preline\n"
		unless($DEBUG==0);
	}

	if(($postline_pos = index($$buf_ref,"\n",$pos+18)) >= 0){
	    $postline = substr($$buf_ref,$pos+18,($postline_pos-($pos+18)));
	    #print STDERR "$postline\n";
	    $postindent = &findIndent(\$postline,$tab); 
	}else{
	    print STDERR "Missed postline\n"
		unless($DEBUG==0);
	}
 	
	# Assert of preindent or post = 0;

	# Merge pagebreaks in relnotes tables

	if($preline=~/^\s+(<I>[^<]+<\/I>\.?){3}\ {3,}/ 
	    && $domain ne "man"){ 
	    $merge = $true;
	}elsif($postline=~/^\s+(<I>[^<]+<\/I>\.?){3}\ {3,}/ 
	       && $domain ne "man"){
	    $merge = $true;    
	}elsif($preindent != $postindent){ # Split paragraphs  
		$merge = $false;
	}else{  # Same level - merge into 1 paragraph?

	    # If preline & post line have the same number of gaps,
	    # it's probably a table we need to merge.
	    my $prespaces = &hasInternalSpace(\$preline);

	    if(($prespaces > 1) && 
	       ($prespaces == &hasInternalSpace(\$preline))){
		$merge = $true; # Merge to sections of a table
	    }else{
		
		# Does preline end in a period? (Followed by </B> or &gt;)
		# Broken in serial(7)
		if($preline=~/\.(<\/[BIT]{1,2}>){0,2}|(&[a-z]{2,4}\;)?$/){
		    $merge = $false; 
		}else{
		    if($postline=~/^\s+((\d)|(\x8o)|(-))/){ # Start list
			$merge = $false;
		    }else{
			$merge = $true;
		    }
		}
	    }
	}

	if($merge == $true){
	    $$buf_ref =~ s/---PAGE\ BREAK---\n//;
	}else{
	    $$buf_ref =~ s/---PAGE\ BREAK---//;
	}
	$pos++;
        $pos=index($$buf_ref,"\n---PAGE BREAK---\n");
    } 


}

#######################################################################
#
# void outputHTMLPage(String $buf)
#
# Ungzip & filter page thru ss2nonss if needed 
#
#######################################################################

sub outputHTMLPage{

    my $gzfile = shift;

    # What about gzipped man pages that aren't HTML?
    # I can't find any examples of these pages
    # For now,  we'll assume they're all HTML:

    my($ss2nonss) = "/usr/lib/infosearch/bin/ss2nonss";

    # Test the browser-type to determine if it can 
    # handle stylesheets.  If it can't, pass it thru
    # ss2nonss.  For now, assume all are non-compliant            

    if(system("gzip -dc $gzfile | $ss2nonss")){
	die "gzip -dc $gzfile | $ss2nonss: !$\n";
    }

}

1; # Return true from nroff2html-lib.pl package include
