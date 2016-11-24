#!/bin/sh
###########################################################################
#
#  Window Maker window manager
#
#  Copyright (c) 2014 Christophe CURIS
#  Copyright (c) 2014 Window Maker Team
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
# generate-mapfile-from-header.sh:
#   from a list of C header files, extract the name of the functions and
#   global variables that are considered public for a library, and generate
#   a 'version script' for ld with that list, so that all other symbols
#   will be considered local.
#
# The goal is that the symbol that are not part of the public API should
# not be visible to the user because it can be a source of problems (from
# name clash to evolutivity issues).
#
###########################################################################
#
# Please note that this script is writen in sh+awk on purpose: this script
# is gonna be run on the machine of the person who is trying to compile
# WindowMaker, and as such we cannot be sure to find any scripting language
# in a known version and that works (python/ruby/tcl/perl/php/you-name-it).
#
# So for portability, we stick to the same sh+awk constraint as Autotools
# to limit the problem, see for example:
#   http://www.gnu.org/savannah-checkouts/gnu/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html
#
###########################################################################

# Report an error on stderr and exit with status 1 to tell make could not work
arg_error() {
    echo "$0: $@" >&2
    exit 1
}

# print help and exit with success status
print_help() {
    echo "$0: generate a script for ld to keep only the symbols from C header"
    echo "Usage: $0 [options...] input_file[s]"
    echo "valid options are:"
    echo "  -l         : add symbol's definition line number for debug"
    echo "  -n name    : name to use for the library"
    echo "  -v version : set the library version for ld"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -l)
            debug_info='	/* " symbol_type " at " FILENAME ":" NR " */'
          ;;

        -n)
            shift
            echo "$1" | grep '^[A-Za-z][A-Za-z_0-9]*$' > /dev/null || arg_error "invalid name \"$1\" for a library"
            libname="$1"
          ;;

        -v)
            shift
            # Version may be 'x:y:z', we keep only 'x'
            version="`echo "$1" | sed -e 's,:.*$,,' `"
            # the version should only be a number
            echo "$version" | grep '^[1-9][0-9]*$' > /dev/null || \
                arg_error "version \"$1\" is not valid"
          ;;

        -h|-help|--help) print_help ;;
        -*) arg_error "unknow option '$1'" ;;

        *)
            [ -r "$1" ] || arg_error "source file \"$1\" is not readable"
            input_files="$input_files $1"
          ;;
    esac
    shift
done

# Check consistency of command-line
[ "x$input_files" = "x" ] && arg_error "no source file given"

# Automatic values
if [ -z "$libname" ]; then
    # build the library name from the first header name, remove path stuff, extension and invalid characters
    libname="`echo "$input_files" | sed -e 's,^ ,,;s, .*$,,;s,^.*/\([^/]*\)$,\1,;s,\.[^.]*$,,;s,[^A-Za-z_0-9],_,g;s,^_*,,' `"
fi

# Parse the input file and find the function declarations; extract the names
# and place them in the 'global' section so that ld will keep the symbols;
# generate the rest of the script so that other symbols will not be kept.
awk '
BEGIN {
  print "/* Generated version-script for ld */";
  print "";
  print "'"$libname$version"'";
  print "{";
  print "  global:";
}

/^#[ \t]*define/ {
  # Ignore macro definition because their content could be mis-interpreted
  while (/\\$/) {
    if (getline == 0) { break; }
  }
  next;
}

/\/\*/ {
  # Remove comments to avoid mis-detection
  pos = index($0, "/*");
  comment = substr($0, pos + 2);
  $0 = substr($0, 1, pos - 1);
  while (1) {
    pos = index(comment, "*/");
    if (pos > 0) { break; }
    getline comment;
  }
  $0 = $0 substr(comment, pos + 2);
}

/extern[ \t].*;/ {
  line = $0;

  # Remove everything from the ";"
  sub(/;.*$/, "", line);

  # Check if it is a global variable
  nb = split(line, words, /[\t *]/);

  valid = 1;
  for (i = 1; i < nb; i++) {
    # If the word looks valid, do not abort
    if (words[i] ~ /^[A-Za-z_0-9]*$/) { continue; }

    # Treat the case were the variable is an array, and there was space(s) after the name
    if (words[i] ~ /^\[/) { nb = i - 1; break; }

    # If we are here, the word is not valid; we stop processing the line here but we do
    # not use "next" so the line may match function prototype handler below
    valid = 0;
    break;
  }

  if (valid) {
    # Remove array size, if any
    sub(/\[.*$/, "", words[nb]);

    if (words[nb] ~ /^[A-Za-z][A-Za-z_0-9]*$/) {
      symbol_type = "variable";
      print "    " words[nb] ";'"$debug_info"'";
      next;
    }
  }
}

/^[ \t]*typedef/ {
  # Skip type definition because they could be mis-interpreted when it
  # defines a prototype for a callback function
  nb_braces = 0;
  while (1) {
    # Count the number of brace pairs to skip the content of the definition
    nb = split($0, dummy_array, /\{/);
    nb_braces = nb_braces + nb;

    nb = split($0, dummy_array, /\}/);
    nb_braces = nb_braces - nb;

    # Stop when we have out count of pair of braces and there is the final ";"
    if ((nb_braces == 0) && (dummy_array[nb] ~ /;/)) { break; }

    if (getline == 0) {
      break;
    }
  }
  next;
}

/[\t ]\**[A-Z_a-z][A-Z_a-z0-9]*[\t ]*\(/ {
  # Get everything until the end of the definition, to avoid mis-interpreting
  # arguments and attributes on next lines
  while (1) {
    pos = index($0, ";");
    if (pos != 0) { break; }

    getline nxt;
    $0 = $0 nxt;
  }

  # Remove the argument list
  sub(/[ \t]*\(.*$/, "");

  # Trim possible indentation at beginning of line
  sub(/^[\t ]*/, "");

  # If it does not start by a keyword, it is probably not a valid function
  if (!/^[A-Z_a-z]/) { next; }

  nb = split($0, words, /[\t *]/);
  for (i = 1; i < nb; i++) {
    # Do not consider "static" because it is used for functions to be inlined
    if (words[i] == "static") { next; }

    # Allow empty keyword, that were just "*"
    if (words[i] == "") { continue; }

    # If it does not match, it is unlikely to be a function
    if (words[i] !~ /^[A-Z_a-z][A-Z_a-z0-9]*$/) { next; }
  }

  # If we arrived so far, everything looks valid and the last argument of
  # the array contains the name of the function
  symbol_type = "function";
  print "    " words[nb] ";'"$debug_info"'";
}

END {
  print "";
  print "  local:";
  print "    *;";
  print "};";
}
' $input_files
