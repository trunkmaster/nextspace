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
#  with this program. If not, see <http://www.gnu.org/licenses/>.
#
###########################################################################
#
# check-wmaker-loaddef-callbacks.sh:
#   Compare the type defined in a variable against the type use for the
#   associated call-back function.
#
# To load the configuration file, Window Maker is using a list of the known
# keywords in a structure with the name of the keyword, the call-back
# function that converts the string (from file) into the appropriate type,
# and a pointer to the variable where the result is saved.
#
# Because the structure requires a little bit of genericity to be usefull,
# it is not possible to provide the C compiler with the information to
# check that the variable from the pointer has the same type as what the
# conversion call-back assumes, so this script does that check for us.
#
# Unfortunately, the script cannot be completely generic and smart, but
# it still tries to be, despite being made explicitely for the case of the
# structures "staticOptionList" and "optionList" from Window Maker's source
# file "src/defaults.c"
#
###########################################################################
#
# For portability, we stick to the same sh+awk constraint as Autotools to
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
    echo "$0: check variable type against call-back expectation for WMaker's defaults.c"
    echo "Usage: $0 options..."
    echo "valid options are:"
    echo "  --callback \"name=type\" : specify that function 'name' expects a variable of 'type'"
    echo "  --field-callback idx   : index (from 1) of the callback function in the struct"
    echo "  --field-value-ptr idx  : index (from 1) of the pointer-to-value in the struct"
    echo "  --source file          : C source file with the array to check"
    echo "  --structure name       : name of the variable with the array of struct to check"
    echo "  --struct-def name=file : specify to get definition of struct 'name' from 'file'"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in
        --callback)
            shift
            deflist="$1,"
            while [ -n "$deflist" ]; do
                name_and_type=`echo "$deflist" | cut -d, -f1 | sed -e 's/^[ \t]*//;s/[ \t]*$//' `
                deflist=`echo "$deflist" | cut -d, -f2-`
                echo "$name_and_type" | grep '^[A-Za-z][A-Za-z_0-9]*[ \t]*=[^=][^=]*$' > /dev/null ||  \
                    arg_error "invalid callback function type specification '$name_and_type' (options: --callback)"
                name=`echo "$name_and_type" | sed -e 's/=.*$// ; s/[ \t]//g' `
                type=`echo "$name_and_type" | sed -e 's/^[^=]*=// ; s/^[ \t]*// ; s/[ \t][ \t]*/ /g' `
                awk_callback_types="$awk_callback_types
  callback[\"$name\"] = \"$type\";"
            done
          ;;

        --field-callback)
            shift
            [ -z "$field_callback" ] || arg_error "field number specified more than once (option: --field-callback)"
            field_callback="$1"
          ;;

        --field-value-ptr)
            shift
            [ -z "$field_value" ] || arg_error "field number specified more than once (option: --field-value-ptr)"
            field_value="$1"
          ;;

        --source)
            shift
            [ -z "$source_file" ] || arg_error "only 1 source file can be used (option: --source)"
            source_file="$1"
          ;;

        --structure)
            shift
            [ -z "$struct_name" ] || arg_error "only 1 structure can be checked (option: --structure)"
            struct_name="$1"
          ;;

        --struct-def)
	    shift
            echo "$1" | grep '^[A-Za-z][A-Z_a-z0-9]*=' > /dev/null || arg_error "invalid syntax in \"$1\" for --struct-def"
            [ -r "`echo $1 | sed -e 's/^[^=]*=//' `" ] || arg_error "file not readable in struct-def \"$1\""
            list_struct_def="$list_struct_def
$1"
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
[ -z "$source_file" ] && arg_error "no source file given (option: --source)"
[ -z "$struct_name" ] && arg_error "no variable name given for the array to check (option: --structure)"
[ -z "$field_value" ] && arg_error "index of the value pointer in the struct no specified (option: --field-value-ptr)"
[ -z "$field_callback" ] && arg_error "index of the call-back in the struct no specified (option: --field-callback)"

echo "$field_value"    | grep '^[1-9][0-9]*$' > /dev/null || arg_error "invalid index for the value pointer, expecting a number (option: --field-value-ptr)"
echo "$field_callback" | grep '^[1-9][0-9]*$' > /dev/null || arg_error "invalid index for the call-back function, expecting a number (option: --field-callback)"

###########################################################################

# This AWK script is extracting the types associated with the field members
# from a specific structure defined in the parsed C source file
awk_extract_struct='
# Parse all the lines until the end of current structure is found
function parse_structure(prefix) {
  while (getline) {

    # Discard C comments, with support for multi-line comments
    while (1) {
      idx = index($0, "/*");
      if (idx == 0) { break; }

      comment = substr($0, idx+2);
      $0 = substr($0, 1, idx-1);
      while (1) {
        idx = index(comment, "*/");
        if (idx > 0) { break; }
        getline comment;
      }
      $0 = $0 substr(comment, idx+2);
    }

    # skip line that define nothing interresting
    gsub(/^[ \t]+/, "");
    if (/^$/) { continue; }
    if (/^#/) { continue; }
    gsub(/[ \t]+$/, "");

    # end of current structure: extract the name and return it
    if (/^[ \t]*\}/) {
      gsub(/^\}[ \t]*/, "");
      name = $0;
      gsub(/[ \t]*;.*$/, "", name);
      gsub(/^[^;]*;/, "");
      return name;
    }

    # Handle structure inside structure
    if (/^(struct|union)[ \t]+\{/) {
      name = parse_structure(prefix ",!");

      # Update the name tracking the content of this struct to contain the name
      # of the struct itself
      match_prefix = "^" prefix ",!:";
      for (var_id in member) {
        if (var_id !~ match_prefix) { continue; }
        new_id = var_id;
        gsub(/,!:/, ":" name ".", new_id);
        member[new_id] = member[var_id];
        delete member[var_id];
      }
      continue;
    }

    if (!/;$/) {
      print "Warning: line " FILENAME ":" NR " not understood inside struct" > "/dev/stderr";
      continue;
    }
    gsub(/;$/, "");

    # Skip the lines that define a bit-field because they cannot be safely
    # pointed to anyway
    if (/:/) { continue; }

    separate_type_and_names();

    # In some rare case we cannot extract the name, that is likely a function pointer type
    if (type == "") { continue; }

    # Save this information in an array
    for (i = 1; i <= nb_names; i++) {
      # If it is an array, push that information into the type
      idx = index(name_list[i], "[");
      if (idx > 0) {
        member[prefix ":" substr(name_list[i], 1, idx-1) ] = type substr(name_list[i], idx);
      } else {
        member[prefix ":" name_list[i] ] = type;
      }
    }
  }
}

# Separate the declaration of an member of the struct: its type and the list of names
# The result is returned through variables "name_list + nb_names" and "type"
function separate_type_and_names() {
  # Separate by names first
  nb_names = split($0, name_list, /[ \t]*,[ \t]*/);

  # Separate the type from the 1st name
  if (name_list[1] ~ /\]$/) {
    idx = index(name_list[1], "[") - 1;
  } else {
    idx = length(name_list[1]);
  }
  while (substr(name_list[1], idx, 1) ~ /[A-Za-z_0-9]/) { idx--; }

  type = substr(name_list[1], 1, idx);
  name_list[1] = substr(name_list[1], idx + 1);

  if (type ~ /\(/) {
    # If therese is a parenthesis in the type, that means we are parsing a function pointer
    # declaration. This is not supported at current time (not needed), so we silently ignore
    type = "";
    return;
  }

  # Remove size information from array declarations
  for (i in name_list) {
    gsub(/\[[^\]]+\]/, "[]", name_list[i]);
  }

  # Parse the type to make it into a "standard" format
  gsub(/[ \t]+$/, "", type);
  nb_elem = split(type, type_list, /[ \t]+/);
  type = "";
  for (i = 1; i <= nb_elem; i++) {
    if (type_list[i] == "signed" || type_list[i] == "unsigned") {
      # The sign information is not a problem for pointer compatibility, so we do not keep it
      continue;
    }
    if (type_list[i] ~ /^\*+$/) {
      # If we have a pointer mark by itself, we glue it to the previous keyword
      type = type type_list[i];
    } else {
      type = type " " type_list[i];
    }
  }
  gsub(/^ /, "", type);
  if (type ~ /^\*/ || type == "") {
    # We have a signed/unsigned without explicit "int" specification, add it now
    type = "int" type;
  }
}

# The name of the variable is at the end, so find all structure definition
/^([a-z]*[ \t][ \t]*)*struct[ \t]/  {

  # Discard all words to find the first ; or {
  gsub(/^([A-Za-z_0-9]*[ \t][ \t]*)+/, "");

  # If not an { it is probably not what we are looking for
  if (/^[^\{]/) { next; }

  # Read everything until we find the end of the structure; we assume a
  # definition is limited to one line
  name = parse_structure("@");

  # If the name is what we expect, generate the appropriate stuff
  if (name == expected_name) {
    struct_found++;
    for (i in member) {
      $0 = i;
      gsub(/^@:/, expected_name ".");
      print "  variable[\"" $0 "\"] = \"" member[i] "\";";
    }
  }

  # Purge the array to not mix fields between the different structures
  for (i in member) { delete member[i]; }
}

# Check that everything was ok
END {
  if (struct_found == 0) {
    print "Error: structure \"" expected_name "\" was not found in " FILENAME > "/dev/stderr";
    exit 1;
  } else if (struct_found > 1) {
    print "Error: structure \"" expected_name "\" was defined more than once in " FILENAME > "/dev/stderr";
    exit 1;
  }
}

# Do not print anything else than what is generated while parsing structures
{ }
'

# Extract the information for all the structures specified on the command line
awk_array_types=`echo "$list_struct_def" | while
  IFS="=" read name file
do
  [ -z "$name" ] && continue

  awk_script="
BEGIN {
  struct_found = 0;
  expected_name = \"$name\";
}
$awk_extract_struct"

  echo "  # $file"

  awk "$awk_script" "$file"
  [ $? -ne 0 ] && exit $?

done`

###########################################################################

# Parse the source file to extract the list of call-back functions that are
# used; take the opportunity to extract information about the variable
# being pointed to now to avoid re-parsing too many times the file
awk_check_callbacks='
# Search the final } for the current element in the array, then split the
# elements into the array "entry_elements" and remove that content from $0
function get_array_element_and_split() {
  nb_elements = 1;
  entry_elements[nb_elements] = "";

  $0 = substr($0, 2);
  count_braces = 1;
  while (count_braces > 0) {
    char = substr($0, 1, 1);
    $0 = substr($0, 2);
    if (char == "{") {
      count_braces++;
    } else if (char == "}") {
      count_braces--;
    } else if (char ~ /[ \t]/) {
      # Just discard
    } else if (char == ",") {
      if (count_braces == 1) { nb_elements++; entry_elements[nb_elements] = ""; }
    } else if (char == "\"") {
      entry_elements[nb_elements] = entry_elements[nb_elements] extract_string_to_element();
    } else if (char == "/") {
      if (substr($0, 1, 1) == "/") {
        getline;
        while (/^#/) { getline; }
      } else if (substr($0, 1, 1) == "*") {
        $0 = substr($0, 2);
        skip_long_comment();
      } else {
        entry_elements[nb_elements] = entry_elements[nb_elements] char;
      }
    } else if (char == "") {
      getline;
      while (/^#/) { print "skip: " $0; getline; }
    } else {
      entry_elements[nb_elements] = entry_elements[nb_elements] char;
    }
  }
}

# When a string enclosed in "" is encountered as part of the elements of the
# array, it requires special treatment, not to extract the information (we are
# unlikely to care about these fields) but to avoid mis-parsing the fields
function extract_string_to_element() {
  content = "\"";
  while (1) {
    char = substr($0, 1, 1);
    $0 = substr($0, 2);
    if (char == "\\") {
      content = content char substr($0, 1, 1);
      $0 = substr($0, 2);
    } else if (char == "\"") {
      break;
    } else if (char == "") {
      getline;
    } else {
      content = content char;
    }
  }
  return content "\"";
}

# Wherever a long C comment (/* comment */) is encountered, it is discarded
function skip_long_comment() {
  while (1) {
    idx = index($0, "*/");
    if (idx > 0) {
      $0 = substr($0, idx + 2);
      break;
    }
    getline;
  }
}

# Search for the definition of an array with the good name
/^[ \t]*([A-Z_a-z][A-Z_a-z0-9*]*[ \t]+)+'$struct_name'[ \t]*\[\][ \t]*=[ \t]*\{/ {
  struct_found++;

  $0 = substr($0, index($0, "{") + 1);

  # Parse all the elements of the array
  while (1) {

    # Search for start of an element
    while (1) {
      gsub(/^[ \t]+/, "");
      if (substr($0, 1, 1) == "{") { break; }
      if (substr($0, 1, 1) == "}") { break; }
      if (substr($0, 1, 1) == "#") { getline; continue; }
      if ($0 == "") { getline; continue; }

      # Remove comments
      if (substr($0, 1, 2) == "//") { getline; continue; }
      if (substr($0, 1, 2) == "/*") {
        $0 = substr($0, 3);
        skip_long_comment();
      } else {
        print "Warning: line " NR " not understood in " FILENAME ", skipped" > "/dev/stderr";
        getline;
      }
    }

    # Did we find the end of the array?
    if (substr($0, 1, 1) == "}") { break; }

    # Grab the whole content of the entry
    entry_start_line = NR;
    get_array_element_and_split();
    gsub(/^[ \t]*,/, "");

    # Extract the 2 fields we are interrested in
    if ((entry_elements[src_fvalue] != "NULL") && (entry_elements[src_ffunct] != "NULL")) {

      if (substr(entry_elements[src_fvalue], 1, 1) == "&") {
        entry_elements[src_fvalue] = substr(entry_elements[src_fvalue], 2);
      } else {
        print "Warning: value field used in entry at line " entry_start_line " does not looke like a pointer" > "/dev/stderr";
      }

      if (variable[entry_elements[src_fvalue]] == "") {
        print "Warning: type is not known for \"" entry_elements[src_fvalue] "\" at line " entry_start_line ", cannot check" > "/dev/stderr";
      } else if (callback[entry_elements[src_ffunct]] == "") {
        print "Error: expected type for callback function \"" entry_elements[src_ffunct] "\" is not known, from " FILENAME ":" entry_start_line > "/dev/stderr";
        error_count++;
      } else if (callback[entry_elements[src_ffunct]] != variable[entry_elements[src_fvalue]]) {
        print "Error: type mismatch between function and variable in " FILENAME ":" entry_start_line > "/dev/stderr";
        print "  Function: " entry_elements[src_ffunct] " expects \"" callback[entry_elements[src_ffunct]] "\"" > "/dev/stderr";
        print "  Variable: " entry_elements[src_fvalue] " has type \"" variable[entry_elements[src_fvalue]] "\"" > "/dev/stderr";
        error_count++;
      }

    }
  }
}

# Final checks
END {
  if (error_count > 0) { exit 1; }
  if (struct_found == 0) {
    print "Error: structure \"'$struct_name'\" was not found in " FILENAME > "/dev/stderr";
    exit 1;
  } else if (struct_found > 1) {
    print "Error: structure \"'$struct_name'\" was defined more than once in " FILENAME > "/dev/stderr";
    exit 1;
  }
}

# Do not print anything else than what is generated while parsing the structure
{ }
'

awk_script="BEGIN {
$awk_array_types
$awk_callback_types

  # Info on structure to be checked
  src_fvalue = $field_value;
  src_ffunct = $field_callback;

  # For checks
  struct_found = 0;
  error_count  = 0;
}
$awk_check_callbacks"

awk "$awk_script" "$source_file" || exit $?
