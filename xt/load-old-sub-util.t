use strict;
use warnings;
no warnings 'once';
# no Test::More because it uses Scalar::Util

print "1..4\n";
my $bad = 0;
my $tests = 0;
my $ok;

my %modules = (
  'Scalar/Util.pm' => <<'END_SCALAR_UTIL',
package Scalar::Util;
$VERSION = '1.5';
sub blessed { ref $_[0] }
$::blessed = \&blessed;
END_SCALAR_UTIL
  'Sub/Util.pm' => <<'END_SUB_UTIL',
package Sub::Util;
$VERSION = '1.0';
END_SUB_UTIL
);
unshift @INC, sub {
  if (my $code = $modules{$_[1]}) {
    open my $fh, '<', \$code;
    return $fh;
  }
  return;
};

# process needs to be warning free
$^W = 1;
$SIG{__WARN__} = sub { die "$_[0]" };

if ($::LIST_UTIL_LAST) {
  require Scalar::Util;
  require List::Util;
}
else {
  require List::Util;
  require Scalar::Util;
}

$tests++;
$bad++ unless $ok = $Scalar::Util::VERSION eq '1.5';
print +($ok ? '' : 'not ') . "ok $tests - Scalar::Util version maintained\n";

$tests++;
$bad++ unless $ok = \&Scalar::Util::blessed == $::blessed;
print +($ok ? '' : 'not ') . "ok $tests - Scalar::Util subs maintained\n";

$tests++;
$bad++ unless $ok = $Sub::Util::VERSION eq '1.0';
print +($ok ? '' : 'not ') . "ok $tests - Sub::Util version maintained\n";

$tests++;
$bad++ unless $ok = !exists $List::Util::{REAL_MULTICALL};
print +($ok ? '' : 'not ') . "ok $tests - List::Util not polluted\n";

exit($bad);
