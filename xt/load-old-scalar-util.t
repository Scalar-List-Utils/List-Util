use strict;
use warnings;
no warnings 'once';
# no Test::More because it uses Scalar::Util

use Config;
if (!-e "$Config{archlibexp}/List/Util.pm") {
  print "1..0 # SKIP No core XS List::Util found\n";
  exit 0;
}

# cut out all but core List::Util and the one we're testing
{
  my ($first) = grep { -e "$_/List/Util.pm" } @INC;
  $first =~ s{[\\/]\Q$Config{archname}\E[\\/]$}{};

  my $i = 0;
  $i++ until $INC[$i] =~ /^\Q$first/;
  $i++ until $INC[$i] !~ /^\Q$first/;
  splice @INC, $i, @INC - $i, @Config{qw(privlibexp archlibexp)};
}

print "1..4\n";
my $bad = 0;
my $tests = 0;
my $ok;

my %modules = (
  'Scalar/Util.pm' => <<'END_SCALAR_UTIL',
package Scalar::Util;
$VERSION = '1.0';
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
$bad++ unless $ok = $Scalar::Util::VERSION eq '1.0';
print +($ok ? '' : 'not ') . "ok $tests - Scalar::Util version maintained\n";

$tests++;
$bad++ unless $ok = defined &Scalar::Util::blessed;
print +($ok ? '' : 'not ') . "ok $tests - Scalar::Util sub installed\n";

$tests++;
$bad++ unless $ok = $Sub::Util::VERSION eq '1.0';
print +($ok ? '' : 'not ') . "ok $tests - Sub::Util version maintained\n";

$tests++;
$bad++ unless $ok = !exists $List::Util::{REAL_MULTICALL};
print +($ok ? '' : 'not ') . "ok $tests - List::Util not polluted\n";

exit($bad);
