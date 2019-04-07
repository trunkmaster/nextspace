#!/bin/sh
###########################################################################
#
#  Window Maker window manager
#
#  Copyright (c) 2015 Christophe CURIS
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
# replace-ac-keywords.sh:
#   generate text file from a template text file, processing @keywords@
# from configure's detected stuff
#
# This follows the principle similar to what Autoconf does for the files
# defined in AC_CONFIG_FILES; the reasons for this script are:
#
#  - Autoconf recommends to only defined Makefiles in that macro and to
# process the rest (if possible) through a Make rule;
#
#  - we also take the opportunity to get access to the AC_DEFINE stuff
# without needing to AC_SUBST them, which would grow unnecessarily the
# makefile;
#
#  - contrary to Autoconf, we also give the possibility to completely
# remove lines from the template, where Autoconf only comments them (when
# using AM_CONDITIONAL for example)
#
###########################################################################
#
# Please note that this script is writen in sh+sed on purpose: this script
# is gonna be run on the machine of the person who is trying to compile
# WindowMaker, and as such we cannot be sure to find any scripting language
# in a known version and that works (python/ruby/tcl/perl/php/you-name-it).
#
# So for portability, we stick to the same sh+awk constraint as Autotools
# to limit the problem, see for example:
#   http://www.gnu.org/savannah-checkouts/gnu/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html
#
###########################################################################

# Report an error on stderr and exit with status 2 to tell make that we could
# not do what we were asked
arg_error() {
    echo "$0: $@" >&2
    exit 2
}

# print help and exit with success status
print_help() {
    echo "$0: convert a Texinfo file into a plain text file"
    echo "Usage: $0 [options...] <template-file>"
    echo "valid options are:"
    echo "  -Dkey=value   : define 'key' to the value 'value'"
    echo "  --filter key  : remove lines containing @key@ if it is undefined"
    echo "  --header file : C header file to parse for #define"
    echo "  -o file       : name for the output file"
    echo "  --replace key : replace @key@ with its value"
    exit 0
}

# Parse a C header file and add the defined lines to the list of known keys+values
# We explicitely excludes macros defined on multiple lines and macros with arguments
# Skip value defined to '0' to consider them as undefine
extract_vars_from_c_header ()
{
  sed -n '/^#[ \t]*define[ \t][ \t]*[A-Za-z][A-Za-z_0-9]*[ \t].*[^\\]$/ {
            s/^#[ \t]*define[ \t]*//
            s/[ \t][ \t]*/=/
            /=0$/d
            p
          }' "$1"
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in

        -D*)
            echo "$1" | grep '^-D[a-zA-Z][a-z_A-Z0-9]*=' > /dev/null || arg_error "syntax error for '$1', expected -Dname=value"
            var_defs="$var_defs
`echo "$1" | sed -e 's/^-D//' `"
          ;;

        --filter)
            shift
            list_filters="$list_filters $1"
          ;;

        --header)
            shift
            [ -r "$1" ] || arg_error "header file \"$1\" is not readable"
            var_defs="$var_defs
`extract_vars_from_c_header "$1" `"
          ;;

        -h|-help|--help) print_help ;;

        -o)
            shift
            output_file="$1"
          ;;

        --replace)
            shift
            list_replaces="$list_replaces $1"
          ;;

        -*) arg_error "unknow option '$1'" ;;

        *)
            [ "x$input_file" = "x" ] || arg_error "only 1 input file can be specified, not \"$input_file\" and \"$1\""
            input_file="$1"
          ;;
    esac
    shift
done

# Check consistency of command-line
[ "x$input_file" != "x" ] || arg_error "no input template file given"
[ "x$output_file" != "x" ] || arg_error "no output file given"

[ "x$list_replaces$list_filters" != "x" ] || arg_error "no key to process from template"

###########################################################################

# Generate the SED commands to replace the requested keys
for key in $list_replaces
do
  # if there are multiple possible values, keep the last
  value=`echo "$var_defs" | grep "^$key=" | tail -1 `
  [ "x$value" != "x" ] || arg_error "key \"$key\" does not have a value"
  sed_cmd="$sed_cmd
    s#@$key@#`echo "$value" | sed -e 's/^[^=]*=//' `#"
done

# Generate the SED commands to filter lines with the specified keys
for key in $list_filters
do
  if echo "$var_defs" | grep "^$key=" > /dev/null ; then
    sed_cmd="$sed_cmd
      s#@$key@##
      /@!$key@/d"
  else
    sed_cmd="$sed_cmd
      s#@!$key@##
      /@$key@/d"
  fi
done

###########################################################################

sed -e "$sed_cmd" < "$input_file" > "$output_file"
