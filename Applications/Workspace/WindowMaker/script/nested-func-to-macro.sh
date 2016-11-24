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
# nested-func-to-macro.sh:
#   from a C source file specified with "-i", convert the functions
#   specified with "-f" into preprocessor macros ("#define") and save the
#   result as the file specified with "-o"
#
# The goal is to process nested functions (functions defined inside other
# functions), because some compilers do not support that, despite the
# advantages against macros:
#   - there is no side effect on arguments, like what macros does;
#   - the compiler can check the type used for arguments;
#   - the compiler can decide wether it is best to inline them or not;
#   - they are better handled by text editors, mainly for indentation but
# also because there is no more '\' at end of lines;
#   - generaly, error message from the compiler are a lot clearer.
#
# As opposed to simple static functions, there is a strong benefit because
# they can access the local variables of the function in which they are
# defined without needing extra arguments that may get complicated.
#
# These added values are important for developpement because they help keep
# code simple (and so maintainable and with lower bug risk).
#
# Because this script convert them to macros (only if 'configure' detected
# that the compiler does not support nested functions, see the macro
# WM_PROG_CC_NESTEDFUNC), there are a few constraints when writing such
# nested functions in the code:
#
#   - you cannot use the function's address (example: callback), but that
# would be a bad idea anyway (in best case there's a penalty issue, in
# worst case it can crash the program);
#
#   - you should be careful on what you're doing with the arguments of the
# function, otherwise the macro's side effects will re-appear;
#
#   - you may need some extra '{}' when calling the function in an
# if/for/while/... construct, because of the difference between a function
# call and the macro that will be replaced (the macro will contain its own
# pair of '{}' which will be followed by the ';' you use for the function
# call;
#
#   - the prototype of the function must be on a single line, it must not
# spread across multiple lines or replace will fail;
#
#   - you should follow the project's coding style, as hacky stuff may
# make the script generate crap. And you don't want that to happen.
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
    echo "$0: convert nested functions into macros in C source"
    echo "Usage: $0 [options...] input_file"
    echo "valid options are:"
    echo "  -f name : add 'name' to the list of function to process"
    echo "  -o file : set output file"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
	-f)
	    shift
	    echo "$1" | grep -q '^[A-Z_a-z][A-Z_a-z0-9]*$' || arg_error "function name \"$1\" is not valid"
	    function_list="$function_list $1"
	  ;;

	-h|-help|--help) print_help ;;
	-o) shift ; output_file="$1" ;;
	-*) arg_error "unknow option '$1'" ;;

	*)
	    [ "x$input_file" = "x" ] || arg_error "only 1 input file can be specified, not \"$input_file\" and \"$1\""
	    input_file="$1"
	  ;;
    esac
    shift
done

# Check consistency of command-line
[ "x$input_file" = "x" ] && arg_error "no source file given"
[ "x$function_list" = "x" ] && arg_error "no function name were given, nothing to do"
[ "x$output_file" = "x" ] && arg_error "no output file name specified"

[ -r "$input_file" ] || arg_error "source file \"$input_file\" is not readable"

# Declare a function that takes care of converting the function code into a
# macro definition. All the code is considered part of the C function's body
# until we have matched the right number of {} pairs
awk_function_handler='
function replace_definition(func_name)
{
   # Isolate the list of arguments from the rest of the line
   # This code could be updated to handle arg list over multiple lines, but
   # it would add unnecessary complexity because a function that big should
   # probably be global static
   arg_start = index($0, "(");
   arg_end   = index($0, ")");
   argsubstr = substr($0, arg_start + 1, arg_end - arg_start - 1);
   remain    = substr($0, arg_end);

   $0 = "#define " func_name "("

   # Remove the types from the list of arguments
   split(argsubstr, arglist, /,/);
   separator = "";
   for (i = 1; i <= length(arglist); i++) {
      argname = substr(arglist[i], match(arglist[i], /[A-Z_a-z][A-Z_a-z0-9]*$/));
      $0 = $0 separator argname;
      separator = ", ";
   }
   delete arglist;
   $0 = $0 remain;

   # Count the number of pairs of {} and take next line until we get our matching count
   is_first_line = 1;
   nb_pair = 0;
   while (1) {
      # Count the opening braces
      split($0, dummy, /\{/);
      nb_pair = nb_pair + (length(dummy) - 1);
      delete dummy;

      # Count the closing braces
      split($0, dummy, /\}/);
      nb_pair = nb_pair - (length(dummy) - 1);
      delete dummy;

      # If we found the end of the function, stop now
      if (nb_pair <= 0 && !is_first_line) {
         # Note that we count on awk that is always executing the match-all
         # pattern to print the current line in the $0 pattern
         break;
      }

      # Otherwise, print current line with the macro continuation mark and grab
      # next line to process it
      $0 = $0 " \\";
      print;
      getline;
      is_first_line = 0;
   }

   # We mark the current macro as defined so it can be undefined at the end
   func_defined[func_name] = 1;
}'

# Build the list of awk pattern matching for each function:
# The regular expression matches function definition by the name of the function
# that must be preceeded by at least one keyword (likely the return type), but
# nothing like a math operator or other esoteric sign
for function in $function_list ; do
    awk_function_handler="$awk_function_handler
/^[\\t ]*([A-Za-z][A-Za-z_0-9]*[\\t ])+${function}[\\t ]*\\(/ {
   replace_definition(\"${function}\");
}"
done

# Finishing, undefine the macro at the most appropriate place we can easily
# guess
awk_function_handler="$awk_function_handler
/^\\}/ {
   # If we are at the end of a function definition, undefine all macros that
   # have been defined so far
   for (func_name in func_defined) {
      print \"#undef \" func_name;
      delete func_defined[func_name];
   }
}
# Print all other lines as-is
{ print }
"

# Find the specified functions and transform them into macros
awk "$awk_function_handler" < "$input_file" > "$output_file"
