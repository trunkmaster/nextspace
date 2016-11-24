#!/bin/sh
###########################################################################
#
#  Window Maker window manager
#
#  Copyright (c) 2014-2015 Christophe CURIS
#  Copyright (c) 2015 Window Maker Team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
###########################################################################
#
# check-translation-sources.sh:
#   Make sure that the list of source files given as reference in a 'po/'
#   is aligned against the list of source files in the compilation
#   directory;
#   It also checks that the list of '*.po' files set in EXTRA_DIST is
#   aligned with the list of files in the repository. This is should be
#   checked by 'make distcheck' but today it is complicated to do that
#   automatically, so better safe than sorry...
#
###########################################################################
#
# For portability, we stick to the same sh+awk constraint as Autotools to
# limit problems, see for example:
#   http://www.gnu.org/software/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html
#
###########################################################################

# Report an error on stderr and exit with status 1 to tell make could not work
arg_error() {
    echo "`basename $0`: $@" >&2
    exit 1
}

# print help and exit with success status
print_help() {
    echo "$0: check list of source files for translation against compiled list"
    echo "Usage: $0 [options...] [translation_directory]"
    echo "valid options are:"
    echo "  -s file : makefile.am for the compilation (the Source)"
    echo "  -v name : name of the variable in source makefile defining the sources"
    echo "  (the variable used in translation makefile is assumed to be 'POTFILES')"
    exit 0
}

# Default setting
trans_dir="."

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
	-s)
	    shift
	    [ -z "$src_make" ] || arg_error "only 1 Makefile can be used for source (option: -s)"
	    src_make="$1"
	  ;;

	-v)
	    shift
	    echo "$1" | grep -q '^[A-Za-z][A-Z_a-z0-9]*$' || arg_error "variable name \"$1\" is not valid (option: -v)"
	    src_variables="$src_variables $1"
	  ;;

	-h|-help|--help) print_help ;;
	-*) arg_error "unknow option '$1'" ;;

	*)
	    [ "x$trans_dir" != "x" ] || arg_error "only 1 directory can be specified for translation"
	    trans_dir="$1"
	  ;;
    esac
    shift
done

# Check consistency of command-line
[ -z "$src_make" ] && arg_error "no makefile given for the compilation sources (option: -s)"

[ -r "$src_make" ] || arg_error "source makefile '$src_make' is not readable (option: -s)"
[ -d "$trans_dir" ] || arg_error "directory for translations is not a directory"

# Detect what is the Makefile to use for the translations
for mfile in Makefile.am Makefile.in Makefile ; do
  if [ -r "$trans_dir/$mfile" ] ; then
    trans_mfile="$trans_dir/$mfile"
    break
  fi
done
[ -z "$trans_mfile" ] && arg_error "could not find a Makefile in the translation directory"

# Build the list of PO files that we will compare against EXTRA_DIST by the awk script
awk_po_file_list="`ls "$trans_dir" | grep '\.po$' | sed -e 's/^/  pofile["/ ; s/$/"] = 1;/' `"
[ -z "$awk_po_file_list" ] && arg_error "no \".po\" file found in translation directory, wrong path?"

# If the list of sources was not specified, deduce it using Automake's syntax
if [ -z "$src_variables" ]; then
    src_variables="`awk '
      /^[A-Za-z][A-Za-z_0-9]*_SOURCES[ \t]*=/ { printf " %s", $1 }
      { }
    ' "$src_make" `"
fi

# Build the list of Source files defined in the compilation makefile
awk_src_script='
function add_source_to_list()
{
  # We assume the first instance is "=" and the next are "+="
  # The script would misunderstand if the content of the variable is reset, but
  # that would be considered bad coding style anyway
  sub(/^[^=]*=/, "");

  # Concatenate everything as long as there is a final back-slash on the line
  while (sub(/\\$/, "") > 0) {
    getline nxt;
    $0 = $0 nxt;
  }

  # Generate awk command to add the file(s) to the list
  split($0, list_src);
  for (key in list_src) {
    # We filter headers because it is very bad practice to include translatable strings
    # in a header. This script does not check this validity but assumes the code is ok
    if (list_src[key] !~ /\.h$/) {
      print "  srcfile[\"" list_src[key] "\"] = 1;";
    }
    delete list_src[key];
  }
}'
for variable in $src_variables ; do
  awk_src_script="$awk_src_script
/^[ \t]*$variable[ \t]* \+?=/ { add_source_to_list(); }"
done
# Tell awk to not print anything other than our explicit 'print' commands
awk_src_script="$awk_src_script
{ }"

awk_src_file_list="`awk "$awk_src_script" "$src_make" `"

# Generate the script that performs the check of the Makefile in the Translation directory
awk_trans_script='
function basename(filename, local_array, local_count)
{
  local_count = split(filename, local_array, "/");
  return local_array[local_count];
}
function remove_source_from_list()
{
  # We make the same assumption on "=" versus "+="
  sub(/^[^=]*=/, "");

  # Concatenate also every line with final back-slash
  while (sub(/\\$/, "") > 0) {
    getline nxt;
    $0 = $0 nxt;
  }

  # Remove source that are found, complain about extra files
  split($0, list_src);
  for (key in list_src) {
    file = basename(list_src[key]);

    if (srcfile[file]) {
      delete srcfile[file];
    } else {
      print "Error: file \"" file "\" defined as source in Translation but is not in Compile makefile";
      error_count++;
    }

    delete list_src[key];
  }
}
function remove_dist_po_files()
{
  # We make the same assumption on "=" versus "+="
  sub(/^[^=]*=/, "");

  # Concatenate also every line with final back-slash
  while (sub(/\\$/, "") > 0) {
    getline nxt;
    $0 = $0 nxt;
  }

  # Remove PO files that are listed, complain about extra PO files
  split($0, list_file);
  for (key in list_file) {
    if (pofile[list_file[key]]) {
      delete pofile[list_file[key]];
    } else if (list_file[key] ~ /\.po$/) {
      print "Error: file \"" list_file[key] "\" defined in EXTRA_DIST but was not found in translation dir";
      error_count++;
    }
    delete list_file[key];
  }
}'

awk_trans_script="$awk_trans_script
BEGIN {
  error_count = 0;
$awk_src_file_list
$awk_po_file_list
}
/^[ \\t]*POTFILES[ \\t]* \\+?=/ { remove_source_from_list(); }
/^[ \\t]*EXTRA_DIST[ \\t]* \\+?=/ { remove_dist_po_files(); }
END {
  # Make sure there is no un-translated source file
  for (key in srcfile) {
    print \"Error: source file \\\"\" key \"\\\" is not in the translation list\";
    error_count++;
  }

  # Make sure there is no PO file left outside EXTRA_DIST
  for (key in pofile) {
    print \"Error: translation file \\\"\" key \"\\\" is not in EXTRA_DIST\";
    error_count++;
  }

  # If error(s) occured, use non-zero status to stop 'make'
  # We use 3 to distinguish for awk's possible own problems (status 1 or 2)
  if (error_count > 0) { exit 3 }
}"

# Run the script; we use 'exec' so we are sure the exit code seen by 'make' will
# come from 'awk'
exec awk "$awk_trans_script" "$trans_mfile"
