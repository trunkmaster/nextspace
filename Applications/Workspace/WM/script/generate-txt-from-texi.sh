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
# generate-txt-from-texi.sh:
#   generate a plain text file from a texinfo documentation
#
# The goal is to achieve a result similar to:
#   texi2any --plaintext --no-split <filename>
#
# The reason for this script is that we do not want to add a strict
# dependancy on the 'makeinfo' tool suite (which has its own dependancies)
#
# There is also the problem that we use is to generate some documentations
# that should be available before the 'configure' script have been run
# (in the 'autogen.sh' script) because some of these documentation provide
# information for running the 'configure' script; We distribute these
# generated docs so normal user won't have the problem, but people that
# want to build from the Git repository.
#
# This script is not a reference for Texinfo syntax, so if you modified the
# texi source, you should really consider running texi2any at least once to
# make sure everything is still ok.
#
###########################################################################
#
# Despite trying to be close to the texi2any output, this script has a few
# known differences:
#
#  - texi2any does not generate a proper title header, it satisfy itself
# with a rudimentary single line; this script generates a better looking
# header with all the information provided
#
#  - the table of content contains the line number for the section to ease
# navigation contrary to texi2any that satisfy itself with a simplist toc
#
#  - the paragraphs are properly justified, contrary to texi2any which only
# flush left them in text outputs
#
#  - There are 2 blank lines instead of 1 before chapter/section to make
# them stand out more
#
#  - when making cross-references, generate a decent-looking string with
# the target line number, instead of the crypting "*Note:" label (inherited
# from "info" format) that looks out of place
#
#  - the line length is set to 76 instead of 72
#
#  - there are some difference in what characters are added when a style is
# used for a string (@emph, @file, @sc, ...) because it assumes the text
# will be read in a plain text tool with no special "smart" highlighting
#
#  - it does not check that the syntax is valid; there are some simple
# checks but it may misbehave, it does not replace a quality check with
# texi2any
#
#  - not all commands are implemented, some because they were not needed
# so far, probably a few because they would be too complex to implement
#
#
# There are a few limitations due to Texinfo being a cheesy format:
#
#  - the @node should be followed immediately by its @chapter/@section
# command, otherwise you may have mismatch on the line number if you make a
# cross-reference to that @node
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
    echo "$0: convert a Texinfo file into a plain text file"
    echo "Usage: $0 [options...] file.texi"
    echo "valid options are:"
    echo "  -Dvar=val  : set variable 'var' to value 'val'"
    echo "  -e email   : set email address in variable 'emailsupport'"
    echo "  -v version : version of the project"
    echo "  -o file    : name of text file to create"
    exit 0
}

# Extract command line arguments
while [ $# -gt 0 ]; do
    case $1 in

        -D*)
            echo "$1" | grep '^-D[a-zA-Z][a-zA-Z]*=' > /dev/null || arg_error "syntax error for '$1', expected -Dname=value"
            var_defs="$var_defs
`echo "$1" | sed -e 's/^-D/  variable["/ ; s/=/"] = "/ ; s/$/";/' `"
          ;;

        -e)
            shift
            var_defs="$var_defs
  variable[\"emailsupport\"] = \"@email{`echo "$1" | sed -e 's/@/@@/g' `}\";"
          ;;

        -h|-help|--help) print_help ;;

        -o)
            shift
            output_file="$1"
          ;;

        -v)
            shift
            project_version="$1"
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
[ "x$input_file" != "x" ] || arg_error "no input texi file given"
[ "x$output_file" != "x" ] || arg_error "no output file given"

###########################################################################
# The script works in 2 passes, in the first pass we generate an almost
# complete text file in the temporary file $temp_file, it also generates
# the table of content in $toc_file as a sed script.
# The second pass generate the $output_file from that $temp_file and the
# $toc_file
###########################################################################

# Create the temp file in the current directory
temp_file="`echo "$input_file" | sed -e 's,^.*/\([^/]*\)$,\1, ; s,\.[^.]*$,,' `.tmp"
toc_file="`echo "$temp_file" | sed -e 's,\.[^.]*$,,' `.toc"
xref_file="`echo "$temp_file" | sed -e 's,\.[^.]*$,,' `.xrf"

# Run awk for 1st pass, but if it fails stop now without deleting temp files
awk '
# Stop processing everything, print the message for user and return error code
# to tell "make" to not go further
function report_error(message) {
  print "Error: " message > "/dev/stderr";

  # When we call "exit", the block "END" is still called, we falsely set
  # this variable to skip a spurious second error message
  bye_marker_found = 1;

  # Code 1 is used when the script is invoked with incorrect arguments
  # Code 2 is used by awk to report problems
  exit 3;
}

# Conditionals for @ifXXX and @ifnotXXX commands
# stored in a stack to allow embedding conditionals inside other conditionals
# the global variable "cond_state" contains the current condition (0 or 1)
function start_conditional(name, value,         local_i) {
  cond_level++;
  cond_names[cond_level] = name;
  cond_value[cond_level] = value;
  cond_state = value;
  for (local_i = 1; local_i < cond_level; local_i++) {
    cond_state = cond_state && cond_value[local_i];
  }
}

function end_conditional(name,          local_i) {
  cond_level--;
  cond_state = 1;
  for (local_i = 1; local_i < cond_level; local_i++) {
    cond_state = cond_state && cond_value[local_i];
  }
}

# Texinfo Variables
# the texinfo standard allows to have variables set with @set and used
# with @value; they can also be defined from command-line (-D)
# they are stored in the global array "variable[name]"
function set_variable(line,          local_idx, local_name, local_value) {
  gsub(/^[ \t]+/, "", line);
  local_idx = match(line, /[ \t]/);
  if (local_idx > 0) {
    local_name  = substr(line, 1, local_idx - 1);
    local_value = substr(line, local_idx + 1);
    gsub(/^[ \t]+/, "", local_value);
  } else {
    local_name  = line;
    local_value = "";
  }
  variable[ local_name ] = local_value;
}

# Write a single line to the output
function write_line(line) {
  if (!cond_state) { return; }

  if (redirect_out == "no") {
    print line;
    line_number++;

  } else if (redirect_out == "copyright") {
    copyright_lines[copyright_count++] = line;

  } else {
    report_error("redirect output mode \"" redirect_out "\" is not supported (line " NR ")");
  }
}

# Paragraph modes
# the current mode for paragraph handling is a Stack to allow embedding
# modes inside other modes
# the global variable "par_mode" contains the active mode
function par_mode_push(mode,          local_i) {
  par_mode_count++;
  par_mode_save_previous[par_mode_count] = par_mode;
  par_mode_save_length[par_mode_count] = line_length;
  par_mode_save_prefix[par_mode_count] = line_prefix;
  par_mode_save_justify[par_mode_count] = par_justify;
  par_mode_save_itemmark[par_mode_count] = item_list_mark;
  par_mode = mode;

  # Check for quality of output
  if (length(line_prefix) + 25 > line_length) {
    print "Warning: too many paragraph modes imbricated at line " NR " for " mode > "/dev/stderr";
    line_length = length(line_prefix) + 25;
  }
}

function par_mode_pop(mode,          local_i) {
  if ((par_mode != mode) || (par_mode_count <= 0)) {
    report_error("found @end " mode " at line " NR " but not in @" mode " (current state is @" par_mode ")");
  }
  par_mode = par_mode_save_previous[par_mode_count];
  line_length = par_mode_save_length[par_mode_count];
  line_prefix = par_mode_save_prefix[par_mode_count];
  par_justify = par_mode_save_justify[par_mode_count];
  item_list_mark = par_mode_save_itemmark[par_mode_count];
  par_mode_count--;
}

# Discard all the lines in the file until the specified "@end" is found on a line by itself
function discard_block(name,          local_start_line) {
  local_start_line = NR;
  while (1) {
    if (getline == 0) { report_error("end of file reached while searching \"@end " name "\", started at line " local_start_line); }
    if ($0 == "@end " name) { break; }
  }
}

# Title Page generation
function generate_title_page() {
  if (!cond_state) { return; }

  if (par_nb_words > 0) {
    generate_paragraph();
    write_line(gen_underline(0, 76));
  }

  # Title page start with 5 blank lines so the "title" coming after will
  # stand out a little bit
  write_line("");
  write_line("");
  write_line("");
  par_mode_push("titlepage");
  line_prefix = "  ";
  line_length = 76 - 4;
}

function generate_title_page_title(title,          local_array, local_count, local_i) {
  if (!cond_state) { return; }

  if (par_mode != "titlepage") {
    report_error("command @title used outside @titlepage, at line " NR);
  }
  generate_paragraph();

  # Title deserves more space
  write_line("");
  write_line("");

  # Split long title
  if (length(title) < 60) {
    local_count = 1;
    local_array[1] = title;
  } else {
    local_count = int((length(title) + 59 ) / 60);
    sub_length = int((length(title) + local_count - 1) / local_count);

    local_count = 0;
    while (length(title) > 0) {
      if (length(title) > sub_length) {
        # Cut at first space before the length
        local_i = sub_length + 1;
        while (local_i > 0) {
          if (substr(title, local_i, 1) == " ") { break; }
          local_i--;
        }
        if (local_i == 0) {
          # Can not break first word, break at first possible place
          local_i = index(title, " ");
          if (local_i == 0) { local_i = length(title) + 1; }
        }
      } else {
        local_i = length(title) + 1;
      }

      local_count++;
      local_array[local_count] = substr(title, 1, local_i - 1);

      title = substr(title, local_i + 1);
    }
  }

  # Center the title
  for (local_i = 1; local_i <= local_count; local_i++) {
    write_line(gen_underline(-1, int((76 - length(local_array[local_i])) / 2)) local_array[local_i]);
  }

  write_line("");
  write_line("");
}

function generate_title_page_subtitle(title,          local_array, local_count, local_i) {
  if (!cond_state) { return; }

  if (par_mode != "titlepage") {
    report_error("command @subtitle used outside @titlepage, at line " NR);
  }
  generate_paragraph();

  # Split long lines
  if (length(title) < 65) {
    local_count = 1;
    local_array[1] = title;
  } else {
    local_count = int((length(title) + 64) / 65);
    sub_length = int((length(title) + local_count - 1) / local_count);

    local_count = 0;
    while (length(title) > 0) {
      if (length(title) > sub_length) {
        # Cut at first space before the length
        local_i = sub_length + 1;
        while (local_i > 0) {
          if (substr(title, local_i, 1) == " ") { break; }
          local_i--;
        }
        if (local_i == 0) {
          # Can not break first word, break at first possible place
          local_i = index(title, " ");
          if (local_i == 0) { local_i = length(title) + 1; }
        }
      } else {
        local_i = length(title) + 1;
      }

      local_count++;
      local_array[local_count] = substr(title, 1, local_i - 1);

      title = substr(title, local_i + 1);
    }
  }

  # Center the title
  for (local_i = 1; local_i <= local_count; local_i++) {
    write_line(gen_underline(-1, int((76 - length(local_array[local_i]) - 4) / 2)) "~ " local_array[local_i] " ~");
  }
}

# Generate separation line to simulate page breaks in plain text file
function generate_page_break() {
  if (!cond_state) { return; }

  generate_paragraph();
  if (par_mode = "titlepage") {
    write_line("");
  }
  write_line("");
  write_line(gen_underline(0, 76));
  par_indent = 1;
}

# Handle chapter and section declaration
# take care of the automatic numbering and to put the line in the table of
# content file, then generate the underlined line in output
function new_section(level, title, is_numbered,         local_i, local_line) {
  if (!cond_state) { return; }

  # Dump the current paragraph now
  generate_paragraph();

  # Update the counters
  if (is_numbered) {
    section[level]++;
    for (local_i = level + 1; local_i <= 4; local_i++) {
      section[local_i] = 0;
    }
  }

  # Generate the line to be displayed
  if (is_numbered) {
    local_line = section[1];
    for (local_i = 2; local_i <= level; local_i++) {
      local_line = local_line "." section[local_i];
    }
    local_line = local_line " " title;
  } else {
    local_line = title;
  }

  # Add the entry to the ToC
  toc_count++;
  toc_entry_level[toc_count] = level;
  toc_entry_name[toc_count] = local_line;
  for (local_i = 1; local_i < level; local_i++) {
    toc_entry_name[toc_count] = "  " toc_entry_name[toc_count];
  }
  toc_entry_line[toc_count] = line_number + 3;

  # Print the section description
  write_line("");
  write_line("");
  write_line(local_line);
  write_line(gen_underline(level, length(local_line)));
  par_indent = 0;
}

# Do not generate anything for Node command, but keep the line information so
# the nodes can be cross-referenced
function new_node(args,        local_nb, local_arr, local_i) {
  if (!cond_state) { return; }

  # Dump the current paragraph now
  generate_paragraph();

  # The command takes many arguments, separate them because we care only for the 1st
  local_nb = split(args, local_arr, ",");
  if ((local_nb < 1) || (local_nb > 4)) {
    report_error("bad number of argument " local_nb " for @node at line " NR);
  }
  gsub(/^[ \t]+/, "", local_arr[1]);
  gsub(/[ \t]*$/, "", local_arr[1]);
  if (local_arr[1] == "") {
    report_error("missing node name for @node at line " NR);
  }

  # Consistency check
  if (node_address[local_arr[1]] != "") {
    report_error("node \"" local_arr[1] "\" is redefined at line " NR ", previous definition at line " node_defline[local_arr[1]]);
  }

  # Add a +3 offset to compensate for the position of the real location that will be the
  # chapter/section that should be following
  node_address[local_arr[1]] = line_number + 3;
  node_defline[local_arr[1]] = NR;
}

# List of Items
function start_item_list(mark, type, default_mark) {
  par_mode_push(type);
  list_is_first_item = 1;
  list_item_wants_sepline = 0;
  par_indent = 1;
  if (line_prefix == "") {
    # First level of enumeration get one mode indentation space
    line_prefix = "     ";
  } else {
    line_prefix = line_prefix "    ";
  }
  if (mark == "") {
    item_list_mark = default_mark;
  } else {
    item_list_mark = execute_commands(mark);
  }
  write_line("");
}

# One item in a Table
function generate_item_in_table(line) {
  if (line !~ /^[ \t]*@itemx?[ \t]/) {
    report_error("bas usage for @item inside a @table, should be at start of line and followed by its value");
  }

  generate_paragraph();
  if (list_item_wants_sepline && !list_is_first_item) {
    write_line("");
  }

  # Apply the global table style to this item
  gsub(/^[ \t]*@itemx?[ \t]*/, "", line);
  line = execute_commands(item_list_mark "{" line "}");

  # Cancel the indentation added for the 2nd column for that line
  line = substr(line_prefix, 1, length(line_prefix)-5)  line;
  write_line(line);

  list_item_wants_sepline = 0;
}

# Generate Underline string with the specified length
function gen_underline(id, len,          local) {
  if (id == -1) { local = "          "; } else
  if (id == 1)  { local = "**********"; } else
  if (id == 2)  { local = "=========="; } else
  if (id == 3)  { local = "----------"; } else
  if (id == 4)  { local = ".........."; }
  else { local = "~~~~~~~~~~"; }
  while (length(local) < len) {
    local = local local;
  }
  return substr(local, 1, len);
}

# Generate text for an URL link
function generate_url_reference(args,          local_nb, local_arr) {
  local_nb = split(args, local_arr, ",");
  if (local_nb == 1) {
    return local_arr[1];

  } else if (local_nb == 2) {
    return execute_commands(local_arr[2]) " (" local_arr[1] ")";

  } else if (local_nb == 3) {
    return execute_commands(local_arr[3]);

  } else {
    report_error("bad number of argument " local_nb " for @uref at line " NR);
  }
}

# Generate text for a Cross-Reference into the document
function generate_cross_reference(args, cmd,          local_nb, local_arr, local_i) {
  local_nb = split(args, local_arr, ",");
  if ((local_nb < 1) || (local_nb > 5)) {
    report_error("bad number of argument " local_nb " for @" cmd " at line " NR);
  }

  local_arr[1] = execute_commands(local_arr[1]);
  for (local_i = 1; local_i <= local_nb; local_i++) {
    gsub(/^[ \t]+/, "", local_arr[local_i]);
    gsub(/[ \t]*$/, "", local_arr[local_i]);
  }

  if (local_arr[1] == "") {
    report_error("no node name specified in @" cmd " at line " NR);
  }

  if (local_arr[4] != "") {
    # If it is a link to an external documentation, do not create an xref_table entry
    local_i = "section [" local_arr[1] "]";
    if (local_arr[5] != "") {
      local_i = local_i " in " execute_commands("@cite{" local_arr[5] "}");
    } else {
      local_i = local_i " from " execute_commands("@file{" local_arr[4] "}");
    }
    return local_i;
  }

  # Build the string to be displayed
  if (local_arr[3] != "") {
    local_i = "section [" execute_commands(local_arr[3]) "]";
  } else {
    local_i = "section [" local_arr[1] "]";
  }

  xref_idcount++;
  xref_table[xref_idcount] = local_arr[1];
  xref_defline[xref_idcount] = NR;
  local_i = local_i sprintf(", at line @x%02X@", xref_idcount);
  return local_i;
}

# Generate a line with the name of an author
# note, we assume the name(s) always fit on a line
function generate_author_line(name,          local_offset, local_attach_to_par) {
  if (!cond_state) { return; }

  local_attach_to_par = (par_nb_words > 0);

  generate_paragraph();

  if (par_mode == "titlepage") {
    name = "--  " name "  --";
    local_offset = int((76 - length(name)) / 2);
    if (local_offset < 2) { local_offset = 2; }
    write_line("");
    write_line(gen_underline(-1, local_offset) name);

  } else if (par_mode == "quotation") {
    name = "-- " name;
    local_offset = int((line_length - length(line_prefix) - length(name)) * 2/3);
    if (local_offset < length(line_prefix) + 2) { local_offset = length(line_prefix) + 2; }
    if (!local_attach_to_par) { write_line(""); }
    write_line(line_prefix gen_underline(-1, local_offset) name);

  } else {
    report_error("command @author used in an inappropriate mode (" par_mode ") at line " NR);
  }
}

# Add the specified line to the curren paragraph being built, do not print anything yet
function add_text_to_paragraph(line) {
  nb = split(line, words, /[ \t]+/);
  for (i = 1; i <= nb; i++) {
    if (words[i] != "") {
      par_word[par_nb_words++] = words[i];
    }
  }
}

# Print the paragraph from all the lines read so far
function generate_paragraph(          local_prefix, local_line, local_length,
                                      idx_word_start, idx_word_end, local_i) {
  if (par_nb_words <= 0) { return; }

  local_line = line_prefix;

  if (par_mode == "list") {
    if (list_item_wants_sepline && !list_is_first_item) {
      write_line("");
    }
    list_is_first_item = 0;
    list_item_wants_sepline = 0;
    if (!par_indent) {
      local_prefix = item_list_mark " ";
      while (length(local_prefix) < 5) { local_prefix = " " local_prefix; }
      local_line = substr(local_line, 1, length(local_line) - 5) local_prefix;
    }

  } else if (par_mode == "enum") {
    if (list_item_wants_sepline && !list_is_first_item) {
      write_line("");
    }
    list_is_first_item = 0;
    list_item_wants_sepline = 0;
    if (!par_indent) {
      local_prefix = "  " item_list_mark ". ";
      local_line = substr(local_line, 1, length(local_line) - 5) local_prefix;

      # Increment the enumeration counter for the next item now
      if (item_list_mark + 0 == item_list_mark) {
        item_list_mark++;
      } else {
        local_i = index("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz", item_list_mark);
        if (local_i == 0) {
          report_error("value \"" item_list_mark "\" is not supported for enumerated list - invalid @enumerate argument or list too long?");
        }
        item_list_mark = substr("BCDEFGHIJKLMNOPQRSTUVWXYZ!bcdefghijklmnopqrstuvwxyz!", local_i, 1);
      }
    }

  } else if (par_mode == "table") {
    if (list_item_wants_sepline && !list_is_first_item) {
      write_line("");
    }
    list_is_first_item = 0;
    list_item_wants_sepline = 0;

  } else if (par_mode == "titlepage") {
    write_line("");

  } else if (par_mode == "par") {
    write_line("");
    if (par_indent) {
      local_line = local_line "   ";
    }

  } else if (par_mode == "quotation") {
    write_line("");
    # There is no extra indentation of paragraphs in this mode

  } else {
    report_error("paragraph mode \"" par_mode "\" is not supported in generate_paragraph (line " NR ")");
  }

  # Split the paragraph in lines
  idx_word_start = 0;
  while (idx_word_start < par_nb_words) {
    # First word is always printed, this makes sure that words too long for a line will
    # always be printed, very likely on a line by themselfs
    idx_word_end = idx_word_start;
    local_length = length(local_line) + length(par_word[idx_word_start]);
    idx_word_start++;

    # See how many word we can fit on the line
    while (idx_word_end < par_nb_words - 1) {
      if (local_length + 1 + length(par_word[idx_word_end + 1]) > line_length) { break; }
      idx_word_end++;
      local_length = local_length + 1 + length(par_word[idx_word_end]);
    }

    # Put all those words on the current line with the appropriate justification
    if (par_justify == "right") {
      local_line = local_line gen_underline(-1, line_length - local_length) par_word[idx_word_start - 1];
      while (idx_word_start <= idx_word_end) {
        local_line = local_line " " par_word[idx_word_start++];
      }
    } else {
      if ((par_justify == "left") || (idx_word_end == par_nb_words - 1) ||
          (local_length >= line_length) || (idx_word_end < idx_word_start)) {
        local_line = local_line par_word[idx_word_start - 1];
        while (idx_word_start <= idx_word_end) {
          local_line = local_line " " par_word[idx_word_start++];
        }
      } else {
        # We calculate the ideal size of a space (as a real number) which would
        # make all the words perfectly fill the line, the formula being
        #       ideal size = 1 +     needed_extra_spaces      /      number_of_spaces_in_line
        ideal_space_length = 1 + (line_length - local_length) / (idx_word_end - idx_word_start + 1);
        count_spaces = 0;
        for (local_i = idx_word_start; local_i <= idx_word_end; local_i++) {
          count_spaces = count_spaces + ideal_space_length;
          word_space[local_i] = gen_underline(-1, int(count_spaces + 0.5));
          count_spaces = count_spaces - length(word_space[local_i]);
        }

        local_line = local_line par_word[idx_word_start - 1];
        while (idx_word_start <= idx_word_end) {
          local_line = local_line word_space[idx_word_start] par_word[idx_word_start++];
        }
      }
    }

    write_line(local_line);

    # Reset for next line
    local_line = line_prefix;
  }
  par_nb_words = 0;
  par_indent = 1;
}

# Replace commands by text in the line, return the result
function execute_commands(line,               replaced_line, command) {
  replaced_line = "";
  while (1) {
    idx = match(line, /@([a-zA-Z]+|.)/);
    if (idx == 0) { break; }

    # Separate the command and its arguments from the rest of the line
    replaced_line = replaced_line substr(line, 1, idx - 1);
    command = substr(line, idx + 1, RLENGTH - 1);
    line = substr(line, idx + RLENGTH);

    if (line ~ /^\{/) {
      # Command has argument(s), extract them
      brace_count = 0;
      for (i = 1; i <= length(line); i++) {
        if (substr(line, i, 1) == "{") {
          brace_count++;
        }
        if (substr(line, i, 1) == "}") {
          brace_count--;
          if (brace_count == 0) { break; }
        }
      }
      if (brace_count != 0) {
        report_error("closing brace not found for command \"@" command "\", at line " NR);
      }

      cmdargs = substr(line, 2, i-2);
      line = substr(line, i + 1);

    } else {
      # Command does not have arguments, discard the spaces used to separate it
      # from the next text
      cmdargs = "";
      sub(/^[ \t]+/, "", line);
    }

    # Commands generating "special" characters #################################
    if (command == "@") {
      replaced_line = replaced_line "@";

    } else if (command == "bullet") {
      replaced_line = replaced_line "*";

    } else if (command == "copyright") {
      replaced_line = replaced_line "(c)";

    } else if (command == "minus") {
      replaced_line = replaced_line "-";

    } else if (command == "registeredsymbol") {
      replaced_line = replaced_line "(r)";

    } else if (command == "today") {
      # Make sure the date will be in english (we use "C" because it not certain
      # that the English locale is enabled on the machine of the user)
      replaced_line = replaced_line "'"`LANG=C date '+%d %B %Y' | sed -e 's,^0,,' `"'";

    # Commands to display text in a special style ##############################
    } else if (command == "asis") {
      line = cmdargs line;

    } else if (command == "b") { # bold
      line = "*" cmdargs "*" line;

    } else if (command == "emph") {
      line = cmdargs line;

    } else if ((command == "code") ||
               (command == "command") ||
               (command == "env") ||
               (command == "option") ||
               (command == "var")) {
      # Should be in fixed-spacing font; printed with single-quotes
      line = "'\''" cmdargs "'\''" line;

    } else if (command == "i") { # italic
      line = "_" cmdargs "_" line;

    } else if (command == "email") {
      line = "<" cmdargs ">" line;

    } else if (command == "file") {
      line = "\"" cmdargs "\"" line;

    } else if (command == "key") {
      line = "<" cmdargs ">" line;

    } else if (command == "r") { # roman font
      line = cmdargs line;

    } else if (command == "sc") {
      # Small-Caps, keep as-is in plain text
      line = cmdargs line;

    } else if (command == "t") { # typewriter-like
      line = cmdargs line;

    # References to other places ###############################################
    } else if (command == "anchor") {
      if (anchor_address[cmdargs] != "") {
        report_error("anchor \"" cmdargs "\" is redefined at line " NR ", previous definition at line " anchor_defline[cmdargs]);
      }
      # Set a -1 offset to compensate for the anchor being after the actual target
      anchor_address[cmdargs] = line_number - 1;
      anchor_defline[cmdargs] = NR;

    } else if (command == "cite") {
      # Reference to external document, we cannot do much
      line = cmdargs line;

    } else if (command == "pxref") {
      replaced_line = replaced_line "see " generate_cross_reference(cmdargs, command);

    } else if (command == "ref") {
      replaced_line = replaced_line generate_cross_reference(cmdargs, command);

    } else if (command == "uref") {
      replaced_line = replaced_line generate_url_reference(cmdargs);

    } else if (command == "xref") {
      replaced_line = replaced_line " See " generate_cross_reference(cmdargs, command);

    # Variable and Conditional commands ########################################
    } else if (command == "value") {
      if (variable[cmdargs] == "") {
        report_error("variable '" cmdargs "' is unknow, for @value at line " NR);
      }
      line = variable[cmdargs] line;

    # Miscelleanous commands ###################################################
    } else if (command == "c") {
      # Comments: ignore everything to the end of line
      line = "";

    } else {
      report_error("unknow command @" command " at line " NR);
    }

  }
  return (replaced_line line);
}

# Handle appropriately the "@end xxx"
function process_end(line) {
  if (line == cond_names[cond_level]) {
    end_conditional(line);
    return;
  }
  if (line == "copying") {
    generate_paragraph();
    redirect_out = "no";

  } else if (line == "enumerate") {
    generate_paragraph();
    par_mode_pop("enum");
    par_indent = 1;

  } else if (line == "example") {
    generate_paragraph();
    par_mode_pop("example");
    par_indent = 1;

  } else if (line == "flushleft") {
    generate_paragraph();
    par_mode_pop(par_mode);
    par_indent = 1;

  } else if (line == "flushright") {
    generate_paragraph();
    par_mode_pop(par_mode);
    par_indent = 1;

  } else if (line == "itemize") {
    generate_paragraph();
    par_mode_pop("list");
    par_indent = 1;

  } else if (line == "quotation") {
    generate_paragraph();
    par_mode_pop("quotation");
    par_indent = 1;

  } else if ((line == "table") || (line == "ftable") || (line == "vtable")) {
    generate_paragraph();
    par_mode_pop("table");
    par_indent = 1;

  } else if (line == "titlepage") {
    generate_page_break();
    par_mode_pop("titlepage");
    par_indent = 0;

  } else {
    report_error("unknow command @end " line " at line " NR);
  }
}

BEGIN {
  # Count the lines generated for the Table of Content
  line_number = 0;

  # To perform some basic checks on the file
  top_was_found = 0;
  bye_marker_found = 0;

  # Paragraph generation parameters
  par_mode_count = 0;
  par_mode = "par";
  par_nb_words = 0;
  par_indent = 1;
  par_justify = "justify";
  redirect_out = "no";
  line_length = 76;
  line_prefix = "";

  # To handle conditional code
  cond_level = 0;
  cond_state = 1;

  # Number of entries in the Table of Content
  toc_count = 0;
  toc_file = "'"$toc_file"'";

  # File to generate for the Cross-Reference tracking
  xref_file= "'"$xref_file"'";

  # Define a custom variable so it is possible to differentiate between
  # texi2any and this script
  variable["cctexi2txt"] = "1.0";

  # Variables inherited from the command line'"$var_defs"'
}

# First line is special, we always ignore it
(NR == 1) { next; }

/^[ \t]*@/ {
  # Treat the special commands that are supposed to be on a line by themselves
  idx = match($0, /^@([a-zA-Z]+)/);
  if (idx != 0) {
    # Remove the command from current line
    command = substr($0, idx + 1, RLENGTH - 1);
    line = substr($0, idx + 1 + RLENGTH);
    sub(/^[ \t]+/, "", line);

    # Commands for structuring the document ####################################
    if (command == "chapter") {
      new_section(1, execute_commands(line), 1);
      next;

    } else if (command == "section") {
      new_section(2, execute_commands(line), 1);
      next;

    } else if (command == "subsection") {
      new_section(3, execute_commands(line), 1);
      next;

    } else if (command == "subsubsection") {
      new_section(4, execute_commands(line), 1);
      next;

    } else if (command == "node") {
      new_node(execute_commands(line));
      next;

    } else if (command == "top") {
      # This is mandatory for "info" format, but useless for plain text
      if (top_was_found > 0) {
        report_error("command @top at line " NR " but was already found at line " top_was_found);
      }
      top_was_found = NR;
      next;

    } else if (command == "unnumbered") {
      new_section(1, execute_commands(line), 0);
      next;

    # Commands for content in the Title Page ###################################
    } else if (command == "author") {
      generate_author_line(execute_commands(line));
      next;

    } else if (command == "subtitle") {
      generate_title_page_subtitle(execute_commands(line));
      next;

    } else if (command == "title") {
      generate_title_page_title(execute_commands(line));
      next;

    # Commands changing the way paragraph are displayed ########################
    } else if (command == "copying") {
      generate_paragraph();
      redirect_out = "copyright";
      copyright_count = 0;
      next;

    } else if (command == "end") {
      process_end(line);
      next;

    } else if (command == "enumerate") {
      if (cond_state) {
        generate_paragraph();
        start_item_list(line, "enum", "1");
      }
      next;

    } else if (command == "example") {
      if (cond_state) {
        generate_paragraph();
        write_line("");
        par_mode_push("example");
        line_prefix = line_prefix "     ";
      }
      next;

    } else if (command == "flushleft") {
      if (cond_state) {
        generate_paragraph();
        par_mode_push(par_mode);
        par_justify = "left";
        par_indent = 0;
      }
      next;

    } else if (command == "flushright") {
      if (cond_state) {
        generate_paragraph();
        par_mode_push(par_mode);
        par_justify = "right";
        par_indent = 0;
      }
      next;

    } else if (command == "itemize") {
      if (cond_state) {
        generate_paragraph();
        start_item_list(line, "list", "*");
      }
      next;

    } else if (command == "menu") {
      generate_paragraph();
      discard_block(command);
      next;

    } else if (command == "quotation") {
      if (cond_state) {
        generate_paragraph();
        par_mode_push("quotation");
        line_prefix = line_prefix "    ";
        line_length = line_length - 4;
        if (line != "") {
          add_text_to_paragraph(execute_commands(line));
          # We add the ":" to the last word because we count on the function
          # "add_text_to_paragraph" to remove the trailing spaces on the line
          # first, which would not have happened if we just had appended the ":"
          # to the argument in the function call
          par_word[par_nb_words - 1] = par_word[par_nb_words - 1] ":";
          line = "";
        }
      }
      next;

    } else if ((command == "table") ||
               (command == "ftable") ||
               (command == "vtable")) {
      # "ftable" and "vtable" are the same as "table" except they are adding automatically
      # the item to the appropriate Index (respectively Function and Variable indexes).
      # As we do not generate index in the text file, we just treat them identically
      if (cond_state) {
        generate_paragraph();
        par_mode_push("table");
        list_is_first_item = 1;
        list_item_wants_sepline = 0;
        par_indent = 1;
        line_prefix = line_prefix "     ";
        gsub(/[ \t]/, "", line);
        if (line !~ /^@[a-z][a-z]*$/) {
          report_error("invalid usage of @table, expecting a single style-changing command");
        }
        item_list_mark = line;
        write_line("");
      }
      next;

    } else if (command == "titlepage") {
      generate_title_page();
      next;

    # Commands generating text automacitally ###################################
    } else if (command == "contents") {
      if (cond_state) {
        generate_paragraph();
        write_line("");
        write_line("");
        print "@table_of_content@";
      }
      next;

    } else if (command == "insertcopying") {
      if (cond_state) {
        generate_paragraph();
        # The copying block was already formatted, we just have to print it as-is
        for (i = 0; i < copyright_count; i++) {
          write_line(copyright_lines[i]);
        }
      }
      next;

    } else if (command == "page") {
      generate_page_break();
      next;

    } else if (command == "sp") {
      if (cond_state) {
        generate_paragraph();
        while (line > 0) {
          write_line("");
          line--;
        }
      }
      next;

    } else if (command == "vskip") {
      # Silently ignore, this is just for TeX
      if (cond_state) {
        generate_paragraph();
      }
      next;

    # Variable and Conditional commands ########################################
    } else if (command == "ifdocbook") {   start_conditional(command, 0); line = ""; next;
    } else if (command == "ifhtml") {      start_conditional(command, 0); line = ""; next;
    } else if (command == "ifinfo") {      start_conditional(command, 1); line = ""; next; # "for historical compatibility"
    } else if (command == "ifplaintext") { start_conditional(command, 1); line = ""; next;
    } else if (command == "iftex") {       start_conditional(command, 0); line = ""; next;
    } else if (command == "ifxml") {       start_conditional(command, 0); line = ""; next;

    } else if (command == "ifnotdocbook") {   start_conditional(command, 1); line = ""; next;
    } else if (command == "ifnothtml") {      start_conditional(command, 1); line = ""; next;
    } else if (command == "ifnotinfo") {      start_conditional(command, 0); line = ""; next; # "for historical compatibility"
    } else if (command == "ifnotplaintext") { start_conditional(command, 0); line = ""; next;
    } else if (command == "ifnottex") {       start_conditional(command, 1); line = ""; next;
    } else if (command == "ifnotxml") {       start_conditional(command, 1); line = ""; next;

    } else if (command == "ifclear") { start_conditional(command, (variable[line] == "")); next;
    } else if (command == "ifset") {   start_conditional(command, (variable[line] != "")); next;

    } else if (command == "clear") {
      if (cond_state) {
        variable[ execute_commands(line) ] = "";
      }
      next;

    } else if (command == "set") {
      if (cond_state) {
        set_variable(line);
      }
      next;

    # Miscelleanous commands ###################################################
    } else if (command == "bye") {
      # Mark the end of file, we are supposed to ignore everything after
      if (cond_state) {
        generate_paragraph();
        while (getline != 0) { }
        bye_marker_found = 1;
      }
      next;

    } else if (command == "c") {
      # Comments: ignore everything to the end of line
      next;

    } else if (command == "errormsg") {
      print "Error: " execute_commands(cmdargs) > "/dev/stderr";
      print "   (from \"'"$input_file"'\", line " NR ")" > "/dev/stderr";
      bye_marker_found = 1;
      exit 4;

    } else if (command == "finalout") {
      # Nothing to do, we are not generating anything in output file about long lines
      next;

    } else if (command == "ignore") {
      # These are multi-lines comments
      discard_block(command);
      next;

    } else if (command == "indent") {
      par_indent = 1;
      if (line == "") { next; }
      $0 = line;

    } else if (command == "noindent") {
      par_indent = 0;
      if (line == "") { next; }
      $0 = line;

    } else if (command == "setfilename") {
      # Should set the output file name automatically
      # at current time, we just ignore it
      next;

    } else if (command == "settitle") {
      # This is used for page headers
      # in a plain text file, it is useless
      next;

    }
    # Commands that were not recognised here may be commands that can be used
    # anywhere in a line but happenned to be at the beginning of the line this
    # time, we do nothing so they will be processed by "execute_commands"
  }
}

/@item/ {
  # We treat @item specially because it may generate more than 1 paragraph
  if (!cond_state) { next; }

  if (par_mode == "table") {
    generate_item_in_table($0);
    next;
  } else if ((par_mode != "list") && (par_mode != "enum")) {
    report_error("found @item at line " NR " but not inside an @itemize");
  }

  while (1) {
    idx = match($0, /@item/);
    if (idx == 0) { break; }

    # We generate paragraph with all the text seen so far, which is part of
    # the previous item
    add_text_to_paragraph(substr($0, 1, idx - 1));
    generate_paragraph();
    $0 = substr($0, idx + 5);

    # When an item is found, we clear "par_ident" to actually place the item
    # mark on the next paragragh
    par_indent = 0;
  }

  # If the item is on a line by itself, stop processing the line to avoid
  # skipping lines more than necessary
  if (/^[ \t]*$/) { next; }
}

# Non-empty lines are added to the current paragraph
{
  if (!cond_state) { next; }

  if ((par_mode == "list") ||
      (par_mode == "enum") ||
      (par_mode == "par") ||
      (par_mode == "table") ||
      (par_mode == "titlepage") ||
      (par_mode == "quotation")) {
    if (/^[ \t]*$/) {
      # Empty lines separate paragraphs
      generate_paragraph();
      # in list of items, they also tell us that user prefers an aerated list
      list_item_wants_sepline = 1;
    } else {
      add_text_to_paragraph(execute_commands($0));
    }

  } else if (par_mode == "example") {
    # Line is printed unmodified, not split and not merged, but with an indentation
    $0 = line_prefix execute_commands($0);
    sub(/[ \t]*$/, "");
    write_line($0);

  } else {
    report_error("paragraph mode \"" par_mode "\" is not supported for line processing (line " NR ")");
  }
}

END {
  if (!bye_marker_found) {
    report_error("command \"@bye\" missing at end of file");
  }
  if (!top_was_found) {
    report_error("command \"@top\" was not found in the file");
  }

  # Count the number of lines that the ToC will occupy
  # we assume the ToC is at the beginning, so all sections will be shifted
  # by this number of lines down
  toc_nb_lines = 0;
  for (i = 1; i <= toc_count; i++) {
    if ((i > 1) && (toc_entry_level[i] == 1)) {
      toc_nb_lines++;
    }
    toc_nb_lines++;
  }

  # Generate the ToC
  for (i = 1; i <= toc_count; i++) {
    if ((i > 1) && (toc_entry_level[i] == 1)) {
      print "" > toc_file;
    }

    $0 = "    " toc_entry_name[i] " ";
    if (length($0) % 2) { $0 = $0 " "; }
    while (length($0) < 76 - 4) {
      $0 = $0 " .";
    }

    target_line = toc_entry_line[i] + toc_nb_lines;

    $0 = substr($0, 1, (76 - 5) - length(target_line)) " " target_line;
    print > toc_file;
  }

  # Generate the Cross-Reference line number update script
  print "# Generated Cross-Reference script for SED" > xref_file;
  for (i = 1; i <= xref_idcount; i++) {
    if (anchor_address[xref_table[i]] != "") {
      target_line = anchor_address[xref_table[i]] + toc_nb_lines;
    } else if (node_address[xref_table[i]] != "") {
      target_line = node_address[xref_table[i]] + toc_nb_lines;
    } else {
      report_error("cross reference to undefined node/anchor \"" xref_table[i] "\" found at line " xref_defline[i]);
    }
    printf "s/@x%02X@/%5d/g\n", i, target_line > xref_file;
  }
}
' "$input_file" > "$temp_file" || exit $?

# Run awk for 2nd pass, if it fails also stop now without deleting temp files
awk '
/@table_of_content@/ {
  while (getline < "'"$toc_file"'") {
    print;
  }
  next;
}
{ print }
' "$temp_file" | sed -f "$xref_file" > "$output_file" || exit $?

# If all worked, remove the temp files
rm -f "$temp_file"
rm -f "$toc_file"
rm -f "$xref_file"
