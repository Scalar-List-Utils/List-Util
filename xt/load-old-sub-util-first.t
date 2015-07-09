use strict;
use warnings;
no warnings 'once';
$::LIST_UTIL_LAST = 1;
# will always exit or die
do 'xt/load-old-sub-util.t';
die $@;
