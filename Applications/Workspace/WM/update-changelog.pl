#!/usr/bin/perl

# Update Window Maker ChangeLog from git log
# Copyright (C) 2014 Window Maker Developers Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# DESCRIPTION
#
# This script adds the subject line and author of every commit since ChangeLog
# was last touched by git, in a style consistent with the entries up to version
# 0.92.0.

use warnings;
use strict;
use File::Slurp qw(read_file prepend_file edit_file);
use Git::Repository;
use Git::Repository::Log::Iterator;
use Text::Wrap;

$Text::Wrap::columns = 80;

my $text = read_file('ChangeLog');
my ($initial_entry) = $text =~ /(Changes.+?\n)\nChanges/s;

my $r = Git::Repository->new();
my $initial_commit = $r->run('log', '-n 1', '--pretty=%H', '--', 'ChangeLog');
my $initial_tag = $r->run('describe', '--abbrev=0', $initial_commit);
my $current_entry = '';
my $initial_author = '';

# start a new entry
if ($r->run('describe', $initial_commit) eq $initial_tag) {
	my ($version) = $initial_tag =~ /wmaker-(.+)/;
	$current_entry .= "Changes since version $version:\n";
	for (my $i = 0; $i < 23 + length($version); $i++) {
		$current_entry .= '.';
	}
	$current_entry .= "\n\n";
} else {
# append to an old entry
	($initial_author) = $initial_entry =~ /\n  (.+)\n$/;
	edit_file {s/\Q$initial_entry//} 'ChangeLog';
	$initial_entry =~ s/\n(.+)\n$/\n/;
	$current_entry = $initial_entry;
}

my $iter = Git::Repository::Log::Iterator->new( $r, '--reverse', "$initial_commit..HEAD");
my $previous_author = '';
my $previous_tag = $initial_tag;

while ( my $log = $iter->next ) {
	my $current_author = '(' . $log->author_name . ' <' . $log->author_email . '>)';

# print the author of previous commit if different from current commit
	if ($initial_author) {
		if ($initial_author ne $current_author) {
			chomp $current_entry;
			$current_entry .= "  $initial_author\n";
		}
		$initial_author = '';
	}
	if ($previous_author ne $current_author) {
		if ($previous_author) {
			$current_entry .= "  $previous_author\n";
		}
		$previous_author = $current_author;
	}

	$current_entry .= wrap('- ', '  ', $log->subject . "\n");
	my $current_commit = $log->commit;
	my $current_tag = $r->run('describe', '--abbrev=0', $current_commit);

# start a new entry if new tag
	if ($current_tag ne $previous_tag) {
		$current_entry .= "  $previous_author\n\n";
		$previous_author = '';
		prepend_file('ChangeLog', $current_entry, binmode => ':raw' );
		$current_entry = '';
		my ($version) = $current_tag =~ /wmaker-(.+)/;
		$current_entry .= "Changes since version $version:\n";
		for (my $i = 0; $i < 23 + length($version); $i++) {
			$current_entry .= '.';
		}
		$current_entry .= "\n\n";
		$previous_tag = $current_tag;
	}
}
$current_entry .= "  $previous_author\n\n";
prepend_file('ChangeLog', $current_entry, binmode => ':raw' );
