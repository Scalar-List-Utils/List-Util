# -*- perl -*-
BEGIN { require 5.006; }
use strict;
use warnings;
use ExtUtils::MakeMaker;
my $PERL_CORE = grep { $_ eq 'PERL_CORE=1' } @ARGV;

if (eval { require List::Util }
    && List::Util->VERSION <= 1.45) {
  package MY;
  no warnings 'once';

  *install = sub {
    my $self = shift;
    my $quote_literal = $self->can('quote_literal') ? 'quote_literal' : sub { $_[1] };
    return '
pure_site_install ::
	$(NOECHO) $(RM_F) ' . $self->$quote_literal(
      $self->catfile('$(DESTINSTALLSITEARCH)', 'List', 'Util.pm')
    ) . '
	$(NOECHO) $(RM_F) ' . $self->$quote_literal(
      $self->catfile('$(DESTINSTALLSITEARCH)', 'List', 'Util', 'PP.pm')
    ) . '
pure_perl_install ::
	$(NOECHO) $(RM_F) ' . $self->$quote_literal(
      $self->catfile('$(DESTINSTALLARCHLIB)', 'List', 'Util.pm')
    ) . '
	$(NOECHO) $(RM_F) ' . $self->$quote_literal(
      $self->catfile('$(DESTINSTALLARCHLIB)', 'List', 'Util', 'PP.pm')
    )
    . "\n" . $self->SUPER::install;
  };
}

WriteMakefile(
  NAME         => q[List::Util],
  ABSTRACT     => q[Common List utility subroutines],
  AUTHOR       => q[Graham Barr <gbarr@cpan.org>],
  VERSION_FROM => 'lib/List/Util.pm',

  ( $PERL_CORE
    ? ()
    : (
      INSTALLDIRS      => ($] < 5.011 ? q[perl] : q[site]),
      PREREQ_PM        => {'Test::More' => 0,},
      (eval { ExtUtils::MakeMaker->VERSION(6.31) } ? (LICENSE => 'perl') : ()),
      (eval { ExtUtils::MakeMaker->VERSION(6.48) } ? (MIN_PERL_VERSION => '5.006') : ()),
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
  (-f 'META.yml' ? () : ( test => { TESTS => 't/*.t xt/*.t' } )),
);

