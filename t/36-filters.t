#!/usr/bin/perl -w
# vim:filetype=perl

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

# SQL::Translator::Filter::HelloWorld - Test filter in a package
#=============================================================================
package SQL::Translator::Filter::HelloWorld;

use strict;
use vars qw/$VERSION/;
$VERSION=0.1;

sub filter {
    my ($schema,$args) = (shift,shift);

    my $greeting = $args->{greeting} || "Hello";
    $schema->add_table(
        name => "HelloWorld",
    );
}

# Hack to allow sqlt to see our module as it wasn't loaded from a .pm
$INC{'SQL/Translator/Filter/HelloWorld.pm'}
    = 'lib/SQL/Translator/Filter/HelloWorld.pm';

#=============================================================================

package main;

use strict;
use Test::More;
use Test::Exception;
use Test::SQL::Translator qw(maybe_plan);

use Data::Dumper;

BEGIN {
    maybe_plan(14, 'Template', 'Test::Differences')
}
use Test::Differences;
use SQL::Translator;

my $in_yaml = qq{--- #YAML:1.0
schema:
  tables:
    person:
      name: person
      fields:
        first_name:
          data_type: foovar
          name: First_Name
};

my $ans_yaml = qq{--- #YAML:1.0
schema:
  procedures: {}
  tables:
    HelloWorld:
      comments: ''
      constraints: []
      fields: {}
      indices: []
      name: HelloWorld
      options: []
      order: 2
    PERSON:
      comments: ''
      constraints: []
      fields:
        first_name:
          data_type: foovar
          default_value: ~
          extra: {}
          is_nullable: 1
          is_primary_key: 0
          is_unique: 0
          name: first_name
          order: 1
          size:
            - 0
      indices: []
      name: PERSON
      options: []
      order: 1
  triggers: {}
  views: {}
translator:
  add_drop_table: 0
  filename: ~
  no_comments: 0
  parser_args: {}
  parser_type: SQL::Translator::Parser::YAML
  producer_args: {}
  producer_type: SQL::Translator::Producer::YAML
  show_warnings: 1
  trace: 0
  version: 0.06
};

# Parse the test XML schema
my $obj;
$obj = SQL::Translator->new(
    debug          => 0,
    show_warnings  => 1,
    parser         => "YAML",
    data           => $in_yaml,
    to             => "YAML",
    filters => [
        # Check they get called ok
        sub {
            pass("Filter 1 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 1, arg0 ");
            ok( ref($_[1]) eq "HASH", "Filter 1, arg1 is a hashref ");
        },
        sub {
            pass("Filter 2 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 2, arg0 ");
            ok( ref($_[1]) eq "HASH", "Filter 2, arg1 is a hashref ");
        },

        # Sub filter with args
        [ sub {
            pass("Filter 3 called");
            isa_ok($_[0],"SQL::Translator::Schema", "Filter 3, arg0 ");
            ok( ref($_[1]) eq "HASH", "Filter 3, arg1 is a hashref ");
            is( $_[1]->{hello}, "world", "Filter 3, got args ");
        },
        { hello=>"world" } ],

        # Uppercase all the table names.
        sub {
            my $schema = shift;
            foreach ($schema->get_tables) {
                $_->name(uc $_->name);
            }
        },

        # lowercase all the field names.
        sub {
            my $schema = shift;
            foreach ( map { $_->get_fields } $schema->get_tables ) {
                $_->name(lc $_->name);
            }
        },

        # Filter from SQL::Translator::Filter::*
        [ 'HelloWorld' ],
    ],

) or die "Failed to create translator object: ".SQL::Translator->error;

my $out;
lives_ok { $out = $obj->translate; }  "Translate ran";
is $obj->error, ''                   ,"No errors";
ok $out ne ""                        ,"Produced something!";
eq_or_diff $out, $ans_yaml           ,"Output looks right";