# List::Util::PP.pm
#
# Copyright (c) 1997-2009 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package List::Util::PP;

use strict;
use warnings;
require Exporter;

our @EXPORT_OK  = qw(
  first min max minstr maxstr reduce sum shuffle
  all any none notall product sum0
  pairs unpairs pairkeys pairvalues pairmap pairgrep pairfirst
);

our $VERSION = "1.42";
$VERSION = eval $VERSION;

our ($a, $b);

sub import {
  my $pkg = caller;

  # (RT88848) Touch the caller's $a and $b, to avoid the warning of
  #   Name "main::a" used only once: possible typo" warning
  no strict 'refs';
  ${"${pkg}::a"} = ${"${pkg}::a"};
  ${"${pkg}::b"} = ${"${pkg}::b"};

  goto &Exporter::import;
}

sub reduce (&@) {
  my $code = shift;
  unless ( ref $code && eval { \&$code } ) {
    require Carp;
    Carp::croak("Not a subroutine reference");
  }
  no strict 'refs';

  return shift unless @_ > 1;

  my $caller = caller;
  local(*{$caller."::a"}) = \my $a;
  local(*{$caller."::b"}) = \my $b;

  $a = shift;
  foreach (@_) {
    $b = $_;
    $a = &{$code}();
  }

  $a;
}

sub first (&@) {
  my $f = shift;
  unless ( ref $f && eval { \&$f } ) {
    require Carp;
    Carp::croak("Not a subroutine reference");
  }

  $f->() and return $_
    foreach @_;

  undef;
}

sub sum (@) {
  return undef unless @_;
  my $s = 0;
  $s += $_ foreach @_;
  return $s;
}

sub min (@) {
  return undef unless @_;
  my $min = shift;
  $_ < $min and $min = $_
    foreach @_;
  return $min;
}

sub max (@) {
  return undef unless @_;
  my $max = shift;
  $_ > $max and $max = $_
    foreach @_;
  return $max;
}

sub minstr (@) {
  return undef unless @_;
  my $min = shift;
  $_ lt $min and $min = $_
    foreach @_;
  return $min;
}

sub maxstr (@) {
  return undef unless @_;
  my $max = shift;
  $_ gt $max and $max = $_
    foreach @_;
  return $max;
}

sub shuffle (@) {
  my @a=\(@_);
  my $n;
  my $i=@_;
  map {
    $n = rand($i--);
    (${$a[$n]}, $a[$n] = $a[$i])[0];
  } @_;
}

sub all (&@) {
  my $f = shift;
  $f->() or return 0
    foreach @_;
  return 1;
}

sub any (&@) {
  my $f = shift;
  $f->() and return 1
    foreach @_;
  return 0;
}

sub none (&@) {
  my $f = shift;
  $f->() and return 0
    foreach @_;
  return 1;
}

sub notall (&@) {
  my $f = shift;
  $f->() or return 1
    foreach @_;
  return 0;
}

sub product (@) {
  my $p = 1;
  $p *= $_ foreach @_;
  return $p;
}

sub sum0 (@) {
  my $s = 0;
  $s += $_ foreach @_;
  return $s;
}

sub pairs (@) {
  if (@_ % 2) {
    warnings::warnif('misc', 'Odd number of elements in pairs');
  }

  return
    map { bless [ @_[$_, $_ + 1] ], 'List::Util::PP::_Pair' }
    map $_*2,
    0 .. int($#_/2);
}

sub unpairs (@) {
  map @{$_}[0,1], @_;
}

sub pairkeys (@) {
  if (@_ % 2) {
    warnings::warnif('misc', 'Odd number of elements in pairkeys');
  }

  return
    map $_[$_*2],
    0 .. int($#_/2);
}

sub pairvalues (@) {
  if (@_ % 2) {
    require Carp;
    warnings::warnif('misc', 'Odd number of elements in pairvalues');
  }

  return
    map $_[$_*2 + 1],
    0 .. int($#_/2);
}

sub pairmap (&@) {
  my $f = shift;
  if (@_ % 2) {
    warnings::warnif('misc', 'Odd number of elements in pairmap');
  }

  my $pkg = caller;

  return
    map {
      no strict 'refs';
      local *{"${pkg}::a"} = \($_[$_]);
      local *{"${pkg}::b"} = \($_[$_+1]);
      $f->();
    }
    map $_*2,
    0 .. int($#_/2);
}

sub pairgrep (&@) {
  my $f = shift;
  if (@_ % 2) {
    warnings::warnif('misc', 'Odd number of elements in pairgrep');
  }

  my $pkg = caller;

  return
    map {
      no strict 'refs';
      local *{"${pkg}::a"} = \($_[$_]);
      local *{"${pkg}::b"} = \($_[$_+1]);
      $f->() ? (wantarray ? @_[$_,$_+1] : 1) : ();
    }
    map $_*2,
    0 .. int ($#_/2);
}

sub pairfirst (&@) {
  my $f = shift;
  if (@_ % 2) {
    warnings::warnif('misc', 'Odd number of elements in pairfirst');
  }

  my $pkg = caller;
  foreach my $i (map $_*2, 0 .. int($#_/2)) {
    no strict 'refs';
    local *{"${pkg}::a"} = \($_[$i]);
    local *{"${pkg}::b"} = \($_[$i+1]);
    return wantarray ? @_[$i,$i+1] : 1
      if $f->();
  }
  return ();
}

sub List::Util::PP::_Pair::key   { $_[0][0] }
sub List::Util::PP::_Pair::value { $_[0][1] }

1;
