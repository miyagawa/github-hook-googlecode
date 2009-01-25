use inc::Module::Install;
name 'Github-Hook-GoogleCode';
all_from 'lib/Github/Hook/GoogleCode.pm';

requires 'Moose';
requires 'JSON', 2.0;
requires 'HTTP::Cookies';
requires 'WWW::Mechanize';
requires 'MooseX::Getopt';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
install_script 'github-hook-googlecode';

WriteAll;
