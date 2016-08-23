use strict;
use warnings;
use List::Util;

print "1..1\n";

for my $mod (qw(List::Util List::Util::PP List::Util::XS Scalar::Util Sub::Util)) {
  no strict 'refs';
  my $v = ${$mod.'::VERSION'} || '';
  my $e = join(', ', sort @{$mod.'::EXPORT'});
  my $eo = join(', ', sort @{$mod.'::EXPORT_OK'});
  my $ef = join(', ', sort @{$mod.'::EXPORT_FAIL'});
  my $s = join(', ', sort grep !/::$/ && defined &{$mod.'::'.$_}, keys %{$mod.'::'});
  s/(?:^|\G)(?=.{64})(.{1,63}\S|\S+)\s+/$1\n                /gms
    for $e, $eo, $ef, $s;
  warn sprintf <<'END_REPORT', $mod, $v, $e, $eo, $ef, $s;
%s:
  $VERSION:     %s
  @EXPORT:      %s
  @EXPORT_OK:   %s
  @EXPORT_FAIL: %s
  subs:         %s

END_REPORT
}

print "ok 1\n";
exit 0;
