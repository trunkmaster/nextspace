#!/usr/bin/env python2
# encoding: utf-8

import click
import os
import random
import subprocess
import sys
import textwrap
import time
from collections import namedtuple
from itertools import compress, imap, ifilter


Test = namedtuple("Test", "name group")

TESTS = [
    Test('after',           'default'),
    Test('api',             'default'),
    Test('apply',           'default'),
    Test('c99',             'default'),
    Test('cascade',         'default'),
    Test('context_for_key', 'default'),
    Test('data',            'default'),
    Test('debug',           'default'),
    Test('io',              'default'),
    Test('io_net',          'default'),
    Test('overcommit',      'default'),
    Test('pingpong',        'default'),
    Test('plusplus',        'default'),
    Test('priority',        'default'),
    Test('priority2',       'default'),
    Test('proc',            'default'),
    Test('queue_finalizer', 'default'),
    Test('read',            'default'),
    Test('read2',           'default'),
    Test('readsync',        'default'),
    Test('select',          'default'),
    Test('sema',            'default'),
    Test('starfish',        'default'),
    Test('suspend_timer',   'default'),
    Test('timer',           'default'),
    Test('timer_bit31',     'default'),
    Test('timer_bit63',     'default'),
    Test('timer_set_time',  'default'),
    Test('timer_short',     'default'),
    Test('timer_timeout',   'default'),
    Test('vm',              'default'),
    Test('vnode',           'default'),
    Test('concur',          'slow'),
    Test('drift',           'slow'),
    Test('group',           'slow'),
]


class SetDiff(click.ParamType):
    name = 'comma-separated-list'

    def convert(self, value, param, ctx):
        if not value:
            return {}
        try:
            entries = value.split(',')
        except ValueError:
            self.fail('%s is not a valid comma separed list' %
                      value, param, ctx)
        result = {}
        for entry in ifilter(bool, entries):
            if entry[0] == '+':
                result[entry[1:]] = '+'
            elif entry[0] == '-':
                result[entry[1:]] = '-'
            else:
                result[entry] = '+'

        return result

class CommaSeparatedList(click.ParamType):
    name = 'comma-separated-list'

    def convert(self, value, param, ctx):
        if not value:
            return []
        try:
            return value.split(',')
        except ValueError:
            self.fail('%s is not a valid comma separed list' %
                      value, param, ctx)


TestResult = namedtuple('TestResult', 'name succeeded')

def run_test(test, test_folder):
    test_name = test.name
    command = []
    command.append(
        os.path.join(test_folder, 'dispatch_{0}'.format(test_name)))
    try:
        ret = subprocess.call(command)
    except OSError as e:
        click.echo(e)
        return TestResult(test_name, False)
    else:
        return TestResult(test_name, ret == 0)

def remove_if(list_, predicate):
    for i, s in enumerate(compress(list_, imap(predicate, list_))):
        list_[i] = s
    del list_[i + 1:]  # trim the end of the list

def get_tests_to_run(test_groups, tests, random_seed=None):
    predicates = [
        lambda t: test_groups.get(t.group, '?'),
        lambda t: tests.get(t.name, '?'),
    ]
    def is_included(test):
        reducer = lambda y, z: z == '?' and y or z
        result = reduce(reducer, (p(test) for p in predicates), '-')
        return result == '+'

    tests_to_run = [test for test in TESTS if is_included(test)]

    if random_seed:
        random.seed(random_seed)
        random.shuffle(tests_to_run)

    return tests_to_run

DIR_TYPE = click.Path(exists=True, file_okay=False, dir_okay=True)

@click.command()
@click.option('--test-groups', default='default', type=SetDiff())
@click.option('--tests', default='', type=SetDiff())
@click.option('--permitted-failures', default='', type=CommaSeparatedList())
@click.option('--random-seed', type=int, default=None)
@click.argument('test-folder', required=True, default=os.getcwd, type=DIR_TYPE)
def cli(test_groups, tests, permitted_failures, test_folder, random_seed):
    tests_to_run = get_tests_to_run(test_groups, tests, random_seed)

    results = dict(successes=[], permitted_failures=[], failures=[])

    for test in tests_to_run:
        click.secho("==== {0} ====".format(test.name), fg='blue')
        start = time.time()
        result = run_test(test, test_folder)
        elapsed = time.time() - start

        if result.succeeded:
            click.secho("* Succeeded: ", fg='green', nl=False)
            results['successes'].append(test.name)
        elif result.name in permitted_failures:
            click.secho("* Failed (but ignored): ", fg='yellow', nl=False)
            results['permitted_failures'].append(test.name)
        else:
            click.secho("* Failed: ", fg='red', nl=False)
            results['failures'].append(test.name)

        click.echo("{} ({:.1f}s)".format(test.name, elapsed))
        click.echo()

    wrapper = textwrap.TextWrapper()

    click.echo("==================================================")
    click.echo("                    SUMMARY                       ")
    click.echo("==================================================")
    click.echo()

    def print_results(kind, colour, results):
        click.echo("{RESULT}: {num}\n{tests}".format(
                RESULT=click.style(kind, fg=colour, bold=True),
                num=len(results),
                tests=wrapper.fill(", ".join(sorted(results)))))
        if results:
            click.echo()

    print_results(
        'SUCCEEDED', 'green', results['successes'])
    print_results(
        'FAILED (but ignored)', 'yellow', results['permitted_failures'])
    print_results(
        'FAILED', 'red', results['failures'])

    sys.exit(results['failures'] and 1 or 0)


if __name__ == '__main__':
    cli.main()

