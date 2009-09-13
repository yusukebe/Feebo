use inc::Module::Install;
name 'Feebo';
all_from 'lib/Feebo.pm';

# requires '';

tests 't/*.t';
author_tests 'xt';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
