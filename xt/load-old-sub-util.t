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
    if ("$]" >= 5.008) {
      open my $fh, '<', \$code
        or die "error loading module: $!";
      return $fh;
    }
    else {
      my $pos = 0;
      my $last = length $code;
      return (sub {
        return 0 if $pos == $last;
        my $next = (1 + index $code, "\n", $pos) || $last;
        $_ .= substr $code, $pos, $next - $pos;
        $pos = $next;
        return 1;
      });
    }
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
