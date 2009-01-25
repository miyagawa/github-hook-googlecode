use inc::Module::Install;
name 'Github-Hook-GoogleCode';
all_from 'lib/Github/Hook/GoogleCode.pm';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
WriteAll;
