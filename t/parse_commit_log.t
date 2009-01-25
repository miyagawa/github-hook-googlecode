use strict;
use Test::Base;
use Github::Hook::GoogleCode;

plan tests => 2 * blocks();
filters { id => 'chomp' };

run {
    my $block = shift;
    my $res = Github::Hook::GoogleCode::parse_commit_log(undef, $block->input);
    is delete $res->{id}, $block->id;

    my $attr = eval $block->attr;
    is_deeply $res, $attr;
};

__END__

===
--- input
Fixes foo. [#20]
--- id
20
--- attr
{}

===
--- input
Fixes foo. [#20 state:resolved]
--- id
20
--- attr
{state=>"resolved"}

===
--- input
[#20 state:resolved owner:jesse milestone:"Launch"]
--- id
20
--- attr
{state=>"resolved", owner => 'jesse', milestone => 'Launch'}

===
--- input
[#20 label:Foo label:Bar]
--- id
20
--- attr
{label => [ 'Foo', 'Bar' ]}


