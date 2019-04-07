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
# generate-po-from-template.sh:
#   update an existing <lang>.po file from the POT (gettext template for
#   translations)
#
# The goal is to take the opportunity to do a little bit more than what
# msgmerge does, including:
#  - copying the full template if the language file does not yet exist;
#  - post-process a few fields that it does not change but we may wish to
# see updated (project name, version, ...)
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
    echo "$0: update language po file from xgettext template"
    echo "Usage: $0 [options...] po_file"
    echo "valid options are:"
    echo "  -b email   : email address to place in 'Report-Msgid-Bugs-To'"
    echo "  -n name    : name of the project, to place in 'Project-Id-Version'"
    echo "  -t file    : template file to be used"
    echo "  -v version : version of the project, to place in 'Project-Id-Version'"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        -b)
            shift
            project_email="$1"
          ;;

        -h|-help|--help) print_help ;;

        -n)
            shift
            project_name="$1"
          ;;

        -t)
            shift
            [ "x$template" = "x" ] || arg_error "template already set to \"$template\", can't use also \"$1\""
            template="$1"
            [ -r "$template" ] || arg_error "template file \"$1\" is not readable"
          ;;

        -v)
            shift
            project_version="$1"
          ;;

        -*) arg_error "unknow option '$1'" ;;

        *)
            [ "x$lang_file" = "x" ] || arg_error "only 1 po file can be specified, not \"$lang_file\" and \"$1\""
            lang_file="$1"
          ;;
    esac
    shift
done

# Check consistency of command-line
[ "x$lang_file" != "x" ] || arg_error "no po file given"
[ "x$template" != "x" ] || arg_error "no template file given"

# Generate the <lang>.po using the usual method if possible
if [ -r "$lang_file" ] ; then
    msgmerge --update --silent "$lang_file" "$template"

    # Fuzzy matching is generally not great, so print a little message to make
    # sure the user will think about taking care of it
    grep ', fuzzy' "$lang_file" > /dev/null && \
        echo "Warning: fuzzy matching was used in \"$lang_file\", please review"
else
    # If the <lang>.po file does not exist, we create a dummy one now from the
    # template, updating a few fields that 'msgmerge' will not do:
    # - it won't touch 'Language', so let's handle it for the user;
    # - it won't like 'CHARSET' in content-type, we place a safe 'UTF-8' as default;
    echo "Warning: creating new \"$lang_file\""
    lang="`echo "$lang_file" | sed -e 's,^.*/\([^/]*\)$,\1,' -e 's/\..*$//' `"
    sed -e '/^"Language:/s,:.*\\n,: '"$lang"'\\n,' \
        -e '/^"Content-Type:/s,CHARSET,UTF-8,' < "$template" > "$lang_file"
fi

# We need to post-process the generated file because 'msgmerge' does not do
# everything, there are some field for which we can give a value to xgettext
# but msgmerge will not take the new value of the header on update
temp_file="`echo "$lang_file" | sed -e 's,^.*/\([^/]*\)$,\1,' -e 's/\.po$//' `.tmp"

# The 'PO-Revision-Date' is supposed to be automatically updated by the user's
# po edition tool, but in case it does not, we feel safer with at least the
# current date
cmd_update="/PO-Revision-Date:/s,:.*\\\\n,: `date +"%Y-%m-%d %H:%M%z" `\\\\n,"

# We update the 'Project-Id-Version', because for historical reasons the PO
# files did not have had a consistent name; it is also the opportunity to
# place the current version of the project in the field
if [ "x$project_name$project_version" != "x" ]; then
    cmd_update="$cmd_update;/Project-Id-Version:/s,:.*\\\\n,: $project_name $project_version\\\\n,"
fi

# We update the 'Report-Msgid-Bugs-To', because for historical reasons the PO
# files probably did not have this information; it is also an opportunity to be
# sure it is in line with project's latest value
if [ "x$project_email" != "x" ]; then
    cmd_update="$cmd_update;/Report-Msgid-Bugs-To:/s,:.*\\\\n,: $project_email\\\\n,"
fi

mv "$lang_file" "$temp_file"
sed -e "$cmd_update" < "$temp_file" > "$lang_file"
rm -f "$temp_file"
