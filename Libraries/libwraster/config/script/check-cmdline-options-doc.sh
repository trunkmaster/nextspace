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
# check-cmdline-options-doc.sh:
#   Compare the options listed in a program's --help text against its
#   documentation, check that all options are described and that there are
#   not deprecated options in the doc.
#
# A know limitation is that it assumes the help text from the program is
# in line with what the program actually supports, because it would be too
# complicated to actually check also in the sources the supported options.
#
###########################################################################
#
# For portability, we stick to the same sh+sed constraint as Autotools to
# limit problems, see for example:
#   http://www.gnu.org/software/autoconf/manual/autoconf-2.69/html_node/Portable-Shell.html
#
###########################################################################

# Report an error on stderr and exit with status 2 to tell make that we could
# not do what we were asked
arg_error() {
    echo "`basename $0`: $@" >&2
    exit 2
}

# print help and exit with success status
print_help() {
    echo "$0: check program's list of options against its documentation"
    echo "Usage: $0 options..."
    echo "valid options are:"
    echo "  --ignore-prg arg  : ignore option '--arg' from program's output"
    echo "                (syntax: 'arg1,arg2,... # reason', args without leading '--')"
    echo "  --man-page file   : program's documentation file, in man format"
    echo "  --program name    : name of the program to run with '--help'"
    echo "  --text-doc file   : program's documentation file, in plain text format"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --ignore-prg)
            shift
            echo "$1" | grep '#' > /dev/null || echo "Warning: no reason provided for --ignore-prg on \"$1\"" >&2
            for arg in `echo "$1" | sed -e 's/#.*$// ; s/,/ /g' `
            do
                ignore_arg_program="$ignore_arg_program
--$arg"
            done
          ;;

	--man-page)
            shift
            [ -z "$man_page$text_doc" ] || arg_error "only 1 documentation file can be used (option: --man-page)"
            man_page="$1"
	  ;;

	--program)
            shift
            [ -z "$prog_name" ] || arg_error "only 1 program can be used (option: --program)"
            prog_name="$1"
          ;;

        --text-doc)
            shift
            [ -z "$man_page$text_doc" ] || arg_error "only 1 documentation file can be used (option: --text-doc)"
            text_doc="$1"
          ;;

        -h|-help|--help) print_help ;;
        -*) arg_error "unknow option '$1'" ;;

        *)
            arg_error "argument '$1' is not understood"
          ;;
    esac
    shift
done

# Check consistency of command-line
[ -z "$prog_name" ] && arg_error "no program given (option: --program)"
[ -z "$man_page$text_doc" ] && arg_error "no documentation given"

[ -z "$man_page" ] || [ -r "$man_page" ] || arg_error "man page file '$man_page' is not readable (option: --man-page)"
[ -z "$text_doc" ] || [ -r "$text_doc" ] || arg_error "text file '$text_doc' is not readable (option: --text-doc)"

# Make sure the program will not be searched in $PATH
if ! echo "$prog_name" | grep '/' > /dev/null ; then
    prog_name="./$prog_name"
fi

[ -x "$prog_name" ] || arg_error "program '$prog_name' does not exist or is not executable"

# Get the list of options that the program claims it supports
# -----------------------------------------------------------
# We suppose (it is common practice) that the options are listed one per line
# with no other text at the beginning of the line
# If the line contains both a short option followed by a long option, we keep only the long
# option because it is better to check for it
prog_options=`$prog_name --help | sed -n '/^[ \t]*-/ { s/^[ \t]*// ; s/^-[^-],[ \t]*--/--/ ; s/[^-A-Z_a-z0-9].*$// ; p }' `

[ "x$prog_options" = "x" ] && arg_error "program '$prog_name --help' did not return any option"

# We filter options that user wants us to, but we warn if the user asked to filter an option that is
# not actually present, to make sure his command line invocation stays up to date
for filter in $ignore_arg_program
do
  if echo "$prog_options" | grep "^$filter\$" > /dev/null ; then
    prog_options=`echo "$prog_options" | grep -v "^$filter\$" `
  else
    echo "Warning: program's option does not contain \"$filter\", specified in \"--ignore-prg\""
  fi
done


if [ -n "$man_page" ]; then
  # In the man page format, the options must be grouped in the section "OPTIONS"
  # The name of the option is on the first line after the '.TP' command
  # The format requires the use of a backslash before the dash ('\-')
  sed_script='/^\.SH[ \t]*"*OPTIONS"*/,/^\.SH/ {
                 /^\.TP/ {
                    n
                    s/^\.[A-Z]*//
                    s/^[ \t]*//
                    s/^\([^ \t]*\)[ \t].*$/\1/
                    s/\\-/-/g
                    p
                 }
              }'
  doc_options=`sed -n "$sed_script" "$man_page" `
fi

# If no problem is found, we will exit with status OK
exit_status=0


if [ -n "$text_doc" ]; then
  # In the plain-text format, there is no specific identification for the options,
  # as they may be described anywhere in the document. So we first try to get
  # everything that looks like a long option:
  sed_script=':restart
              /^\(.*[^-A-Za-z_0-9]\)*--[A-Za-z0-9]/ {
                h
                s/^.*--/--/
                s/[^-A-Z_a-z0-9].*$//
                p

                g
                s/^\(.*\)--[A-Za-z0-9][-A-Z_a-z0-9]*/\1/
                b restart
              }'
  doc_options=`sed -n "$sed_script" "$text_doc" `

  # then we also explicitely search for the short options we got from the program
  for opt in `echo "$prog_options" | grep '^-[^-]' `
  do
    if grep "^\\(.*[^-A-Za-z_0-9]\\)*$opt\\([^-A-Za-z_0-9].*\\)\$" "$text_doc" > /dev/null ; then
      doc_options="$doc_options
$opt"
    fi
  done
fi


# Check that all program options are documented
for opt in $prog_options
do
  if ! echo "$doc_options" | grep "^$opt\$" > /dev/null ; then
    echo "Error: program option '$opt' is not in the documentation '$man_page$text_doc'"
    exit_status=1
  fi
done

# Check that all documentation options are listed by the program
for opt in $doc_options
do
  if ! echo "$prog_options" | grep "^$opt\$" > /dev/null ; then
    echo "Error: option '$opt' is documented, but not in '$prog_name --help'"
    exit_status=1
  fi
done

# It is recommended to list options in alphabetical order because it is then
# easier to search for one
if [ -n "$man_page" ]; then
  if ! echo "$doc_options" | sed -e 's/^-*//' | sort -c ; then
    echo "Error: options are not sorted alphabetically in '$man_page'"
    exit_status=1
  fi
fi

# exit with appropriate return code, wether discrepancies were found or not
exit $exit_status
