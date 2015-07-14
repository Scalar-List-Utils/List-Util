# -*- perl -*-
BEGIN { require 5.006; }
use strict;
use warnings;
use Config;
use File::Spec;
use ExtUtils::MakeMaker;

use lib 'inc';
use ExtUtils::HasCompiler qw(can_compile_loadable_object);

if (eval { require List::Util }
    && List::Util->VERSION <= 1.42) {
  package MY;
  no warnings 'once';

  *install = sub {
    my $self = shift;
    return '
pure_site_install ::
	$(NOECHO) $(RM_F) ' . $self->quote_literal(
      $self->catfile('$(DESTINSTALLSITEARCH)', 'List', 'Util.pm')
    ) . "\n" . $self->SUPER::install;
  };
}

WriteMakefile(
  NAME         => q[List::Util],
  ABSTRACT     => q[List utility subroutines],
  AUTHOR       => q[Paul Evans <leonerd@leonerd.org.uk>],
  DISTNAME     => q[List-Util],
  VERSION_FROM => 'lib/List/Util.pm',

  INSTALLDIRS      => ($] < 5.011 ? q[perl] : q[site]),
  PREREQ_PM        => {
    (can_compile_loadable_object(quiet => 1) ? ("List::Util::XS" => "1.42_001") : ()),
    'Test::More' => 0,
  },
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
);

