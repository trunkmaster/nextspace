#!/usr/bin/perl
#
#
# kde2wmaker.pl:
#
#
# This script, made for users of Window Maker (http://windowmaker.info) is to
# be used along with KDE (http://www.kde.org).
#
#
# The default directory, /usr/share/applnk, will contain various
# sub-directories such as Development, Editors, Internet, etc. If for some
# reason, you wish to use an alternate (parent) directory that contains the
# various applnk files, it can be specified on the command line.
#
# The directory, if an alternate is specified, MUST be a parent directory to
# any/all sub-directories.
#
# Usage: kde2wmaker.pl [ Options... ]
#
#        Options:
#
#                -d <KDE App.kdelnk dir>
#                -f <output menufile>
#                -t <X terminal application>
#
# When the script is run, it will write out a proper Window Maker "External
# Menu" entry, that can be included in the menu. When the External Menu has
# been correctly configured, the root menu will display a sub-menu containing
# all of the KDE related items found. The script only needs to be run when/if
# KDE is updated.
#
# 
# Installation and Configuration:
#
# 1) If /usr/bin/perl is not the location of the perl binary on your system,
#    the first line should be changed to reflect upon it's location.
# 2) Run the script.
# 3) Configure Window Maker's menu by editing ~/GNUstep/Defaults/WMRootMenu
#    This could be done with any text editor, or by using WPrefs. Insert
#    the following line (if done with a text editor) into the WMRootMenu file.
#      ("External Menu", OPEN_MENU, "$HOME/.kde2wmaker.menu"),
#    If done using WPrefs, simply "Add External Menu" from the drop down menu,
#    then type: $HOME/.kde2wmaker.menu   into the "Menu Path/Directory List"
#    textbox.
# 4) Some KDE entries, such as "Pine" will require a terminal to
#    execute it.  There is a terminal variable below. You may use any
#    terminal, XTerm is the default. Any command line options such as:
#    -fg -bg, etc. can be specified in this variable as well.
#
#
# Michael Hokenson - logan@dct.com
#
#
#---------------------------------------------------------------------
#
# v1.2.0 -- 14th February 2001.
#
# Added alphabetic sorting of the menus.
#
# Directories are now displayed before files in the menu.
#
#---------------------------------------------------------------------
#
# v1.1.5 -- 3rd February 2001. (No public release)
#
# Unsupported applnk files have a fallback entry in the menu tree so
# that users can report menu entries that do not work. So far,
# wkdemenu.pl assumes that there is an Exec= line in the application
# definition, which is not always the case.
#
# --------------------------------------------------------------------
#
# v1.1.0 -- 29th January 2001.
#
# Code cleanup and bug fixes.
#
# --------------------------------------------------------------------
#
# v1.0.0 -- 21st January 2001.
#
# This script has been completely re-written to allow recursion of the
# KDE menu directories to an arbitrary depth, fixing a major
# functional limitation in the original script. To do this, I have
# rewritten the code to traverse directories recursively, introducing
# a subroutine, process_dir() to carry out the task.
#
# wkdemenu.pl provides an excellent extension to the user interface in
# Window Maker, working well with the "Generated Submenu" feature.
#
#
# Summary of New Features
# -----------------------
#
# Added support for menus of arbitrary depth.
#
# Added basic internationalisation based on KDE's language
# setting. The language is taken from "~/.kde/share/config/kdeglobals"
# or from "~/.kderc".
#
# Corrected the generation of menu names, incorporating
# internationalisation, where appropriate.
#
# Changed the double quotes to two single quotes in application names
# so that they do not break the Menu parser in Window Maker.
#
# Stripped off the arguments to commands on the Exec= line, except in
# a few KDE specific cases (e.g. kfmclient). The extra options are
# only usable by KDE and were preventing many applications from
# launching, since they could parse the option %c or %s, for example.
# This "feature" will probably need a more formal or interactive way
# of specifying exceptions in the future.
#
# Added a command line option for specifying the X terminal to
# use. This still defaults to xterm, but could be used to specify
# aterm, etc.
#
# Malcolm Cowe, malk@271m.net.
#
# --------------------------------------------------------------------
#
# To Do
# -----
#
# Programmatically determine the system location for the KDE menu
# directory. 
#
# Find a better way to parse the Exec= lines. In the short term,
# provide a user mechanism for generating exceptions to the curtailing
# of command line options. In the longer term, emulate what KDE does
# with these command line features.
#
# Optimise the code. This is my first proper PERL script, and I'm sure
# there's a better way. =)
#

#
# Variables
#

# The External Menu file, this should NEVER point to the root menu file
$menufile = "$ENV{'HOME'}/.kde2wmaker.menu";

# Base directory, location of all the KDE AppName.kdelnk files.

# Change the base directory default to point at the system files,
# not the user files. Need to find a way of determining the prefix
# programmatically.
$prefix="/usr";
$basedir = $prefix."/share/applnk";

# Terminal to use. May be specified on the command line with the -t
# switch. 
$term = "xterm";

# Xmessage command line to invoke (can vary platform to platform)
$ostype = `uname -s`;
if ($ostype =~ /^HP-UX$/) {
  $xmsg = "xmessage -geometry 400x100 -f -";
}
else {
  $xmsg = "xmessage -geometry 400x100 -file - -default \"okay\"";
}

# Print to STDOUT, default is YES, a filename is specified
$stdout = 1;

# KDE Locale Support

# Support for KDE internationalisation so that menu entries appear
# in the language chosen by the user. Also gets around some problems
# with the KDE applnk file format.

# The Locale is stored in one of two places, depending on the
# version of KDE that is running.
$kde2cf="$ENV{'HOME'}/.kde/share/config/kdeglobals";
$kde1cf="$ENV{'HOME'}/.kderc";
$kdeLanguage = "";

# Open the file, if it exists, otherwise provide a default language.
unless(open KDERC, $kde2cf) {
  unless(open KDERC, $kde1cf) {
    $kdeLanguage = "C";
  }
}

if ( $kdeLanguage == ""){
  $kdeLanguage = "C";
  # Search through the contents of the file
  while($line = <KDERC>) {
    chomp($line);
    # Grab the Language
    if($line =~ /^Language=/) {
      $kdeLanguage = $line;
      $kdeLanguage =~ s/Language=//;
      ($kdeLanguage) = split /:/,$kdeLanguage;
      last;
    }
  }
  close(KDERC);
}


#
# Begin Main Iteration.
#

# Process command line arguments
foreach $arg(@ARGV) {
  if($last) {
    if($last eq "-d") {
      $basedir = $arg;
    }
    elsif($last eq "-f") {
      $menufile = $arg;
      $stdout = 0;
    }
    elsif($last eq "-t") {
      $term = $arg;
    }
    undef($last);
  } elsif($arg =~ /^-/) {
    if($arg =~ /^-[dfst]$/) {
      $last = $arg;
    } else {
      die("Unknown option: $arg\n\nUsage: kde2wmaker.pl [ Options... ]\n".
	  "\n\tOptions:\n\n".
	  "\t\t-d <KDE App.kdelnk dir>\n".
	  "\t\t-f <output menufile>\n".
	  "\t\t-t <X terminal application>\n");
      &Usage;
    }
  }
}

# Make sure the KDE Menu's Top Level Directory exists.
if(-d $basedir) {
  # See if there is an old menu file. If there is, rename it
  unless($stdout) {
    if(-e $menufile) {
      print STDERR "\tFound $menufile, renaming\n\n";
      rename $menufile, "$menufile.old";
    }
    open(MENUFILE,"> $menufile");
  }

  # Start the main menu entry
  if($stdout) {
    print STDOUT "\"KDE Applications\" MENU\n";
    process_dir (STDOUT, $basedir);
    print STDOUT "\"KDE Applications\" END\n";
  } else {
    print MENUFILE "\"KDE Applications\" MENU\n";
    process_dir (MENUFILE, $basedir);
    print MENUFILE "\"KDE Applications\" END\n";
  }

} else {
  # Error out :/
  print STDERR "ERROR:\n\t$basedir not found\n\tTry another directory.\n";
  exit(0);
}

# End of Main Iteration.


# process_dir() works it's way through each file and directory in
# the tree and generates the menu output to be used by Window Maker.
sub process_dir {

  my $OUT = @_[0];
  my $path = @_[1];
  my $item;
  my @tld;
  my @tlf;
  my @klist;
  my ($gotLang, $gotDef, $gotExec, $inTerm);
  my $inDesktop;

  # tld == Top Level Directory.
  opendir(TLD, $path) || return;
  # In order to display directories before files, the directory
  # contents must be split. Directories are added to one array, files
  # to a second. The lists are then sorted alphabetically by name and
  # combined into a single list for processing by the rest of the
  # subroutine. 
  while (defined($file = readdir(TLD))) {
    next if $file =~ /^\./;
    if (-d "$path/$file") {
      @tld = (@tld, $file);
    }
    else {
      @tlf = (@tlf, $file);
    }
  }
  closedir(TLD);
  # At this stage, only sort the directories, since the application
  # sorting is done later, using the "Name=" field in the applnk file.
  @tld = sort (@tld);

  # Print out directory names first and then process the directories.
  foreach $item(@tld) {
    print $OUT "\"$item\" MENU\n";
    process_dir($OUT, "$path/$item");
    print $OUT "\"$item\" END\n";
  }

  # Process the applnk files in the current directory.
  foreach $item(@tlf) {
    $gotLang = 0;
    $gotDef = 0;
    $gotExec = 0;
    $inTerm = 0;
    $inDesktop = 0;

    # Process the contents of the applnk file to generate a menu
    # entry for the application.

    open(SUB,"$path/$item");

    # Set a default application warning to run in case there is no
    # Exec= line in the application definition. This will be
    # useful for debugging exceptions.
    $pname="$item";
    $pargs="echo \"Could not extract executable information from:\\n\\n$path/$item.\"|".$xmsg;

    # Search through the contents of the file. Exit the loop at the
    # EOF or if we have processed the [Desktop Entry Section] of the
    # file.
    while($line = <SUB>) {
      chomp($line);
      # Get the application's name. This is stored in the
      # [Desktop Entry] section of the applnk description.
      #
      # The application's name can have one of these forms:
      # Name=
      # Name[]=
      # Name[language]=
      #
      # Get the default name anyway (one of the first two, just
      # in case there is no language specific entry).
      if ($inDesktop) {
	# Make sure we are in fact still in the [Desktop Entry]
	# section.
	if ($line =~ /^\[/) {
	  $inDesktop = 0;
	}
	# Extract the Name of the Application
	elsif ($line =~ /^Name\[?\]?=/
	       && (!$gotDef || !gotLang)) {
	  $pname = $line;
	  $pname =~ s/^Name\[?\]?=//s;
	  $pname =~ s/\"/\'\'/g;
	  $gotDef = 1;
	}
	elsif ($line =~ /^Name\[$kdeLanguage\]=/ && !$gotLang) {
	  $pname = $line;
	  $pname =~ s/^Name\[$kdeLanguage\]=//s;
	  $pname =~ s/\"/\'\'/g;
	  $gotLang = 1;
	}
	# Grab the command
	elsif($line =~ /^Exec=/ && !$gotExec) {
	  $pargs = $line;
	  $pargs =~ s/^Exec=//s;
	  # Strip off all command line options unless the
	  # application is "kfmclient", etc.
	  if ($pargs !~ /^kfmclient/
	      && $pargs !~ /^kcm/
	      && $pargs !~ /^\/bin\/bash/
	      && $pargs !~ /^kdesu/){
	    ($pargs) = split(/\s/, $pargs);
	  }
	  else {
	    # A double check to remove any dubious characters from
	    # the command line of the exceptions listed in the
	    # above "if" statement. The only culprit so far is the
	    # KDE 1 kfmclient command line.
	    $pargs =~ s/\%[a-zA-Z]//g;
	  }
	  $gotExec = 1;
	}
	# If Terminal=1, then we need to execute application
	# within a terminal window.
	elsif($line =~ /^Terminal=(1|true)$/i) {
	  $inTerm=1;
	}
      }
      elsif ($line =~ /^\[(KDE\ )?Desktop\ Entry\]/){
	$inDesktop = 1;
      }
    }

    close(SUB);

    if ($inTerm) {
      $pargs = "$term -T \"$pname\" -e $pargs";
    }
    @klist = (@klist, "\t\"$pname\" EXEC $pargs\n");
  }

  @klist = sort(@klist);
  foreach (@klist) {
    print $OUT $_;
  }

  return;
}
