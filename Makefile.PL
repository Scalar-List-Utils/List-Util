# -*- perl -*-
BEGIN { require 5.006; }
use strict;
use warnings;
use Config;
use File::Spec;
use ExtUtils::MakeMaker;
my $PERL_CORE = grep { $_ eq 'PERL_CORE=1' } @ARGV;

WriteMakefile(
  NAME         => q[List::Util::XS],
  ABSTRACT     => q[List utility subroutines],
  AUTHOR       => q[Paul Evans <leonerd@leonerd.org.uk>],
  DEFINE       => q[-DPERL_EXT],
  DISTNAME     => q[List-Util],
  VERSION_FROM => 'lib/List/Util.pm',

  # We go through the ListUtil.xs trickery to foil platforms
  # that have the feature combination of
  # (1) static builds
  # (2) allowing only one object by the same name in the static library
  # (3) the object name matching being case-blind
  # This means that we can't have the top-level util.o
  # and the extension-level Util.o in the same build.
  # One such platform is the POSIX-BC BS2000 EBCDIC mainframe platform.
  XS     => {'ListUtil.xs' => 'ListUtil.c'},
  OBJECT => 'ListUtil$(OBJ_EXT)',
  ( $PERL_CORE
    ? ()
    : (
      INSTALLDIRS      => ($] < 5.011 ? q[perl] : q[site]),
      PREREQ_PM        => {'Test::More' => 0,},
      MIN_PERL_VERSION => '5.006',
      (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
      ( eval { ExtUtils::MakeMaker->VERSION(6.46) } ? (
          META_MERGE => {
            'meta-spec' => { version => 2 },
            dynamic_config => 0,
            resources => {    ##
              repository => {
                url => 'https://github.com/Scalar-List-Utils/List-Util.git',
                web => 'https://github.com/Scalar-List-Utils/List-Util',
                type => 'git',
              },
              bugtracker => {
                mailto => 'bug-Scalar-List-Utils@rt.cpan.org',
                web => 'https://rt.cpan.org/Public/Dist/Display.html?Name=Scalar-List-Utils',
              },
            },
          }
          )
        : ()
      ),
    )
  ),
);

