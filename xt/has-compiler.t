use strict;
use warnings;
use Test::More tests => 2;
use lib 'inc';
ok -f 'inc/ExtUtils/HasCompiler.pm', 'ExtUtils::HasCompiler exists in inc/';
require ExtUtils::HasCompiler;
cmp_ok(ExtUtils::HasCompiler->VERSION, '>=', '0.016',
  'bundled ExtUtils::HasCompiler is new enough');
