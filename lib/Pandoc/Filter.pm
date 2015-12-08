package Pandoc::Filter;
use 5.010;
use strict;
use warnings;

our $VERSION = '0.11';

use JSON;
use Carp;
use Scalar::Util 'reftype';
use List::Util;
use Pandoc::Walker;
use Pandoc::Elements ();

use parent 'Exporter';
our @EXPORT = qw(pandoc_filter pandoc_walk stringify);

sub stringify {
    $_[0]->string
}

sub pandoc_walk(@) { ## no critic
    my $filter = Pandoc::Filter->new(@_);
    my $ast = Pandoc::Elements::pandoc_json(<STDIN>);
    binmode STDOUT, ':encoding(UTF-8)';
    $filter->apply($ast);
}

sub pandoc_filter(@) { ## no critic
    my $ast = pandoc_walk(@_);  # implies binmode STDOUT UTF-8
    my $json = JSON->new->allow_blessed->convert_blessed->encode($ast);
    #my $json = $ast->to_json;  # does not want binmode STDOUT UTF-8
    say STDOUT $json;
}

# constructor and methods

sub new {
    my $class = shift;
    if ( @_ and !(ref $_[0] or @_ % 2) ) {
        my @actions;
        # TODO: partly duplicated code in Pandoc::Walker
        for( my $i=0; $i<@_; $i+=2 ) {
            my @names  = split /\|/, $_[$i];
            my $action = $_[$i+1];
            push @actions, sub {
                return unless List::Util::first { $_[0]->name eq $_ } @names;
                $_=$_[0];
                $action->($_);
            };
        }
        bless \@actions, $class;
    } else {
        if ( grep { !reftype $_ or reftype $_ ne 'CODE' } @_ ) {
            croak $class.'->new expects a hash or list of CODE references';
        }
        bless \@_, $class;
    }
}

sub apply {
    my ($self, $ast, $format, $meta) = @_;
    $meta ||= eval { $ast->[0]->{unMeta} } || { };

    foreach my $action (@$self) {
        Pandoc::Walker::transform($ast, $action, $format || '', $meta);
    }
    $ast;
}

1;
__END__

=encoding utf-8

=head1 NAME

Pandoc::Filter - process Pandoc abstract syntax tree 

=head1 SYNOPSIS

The following filter C<flatten.pl>, adopted from L<pandoc scripting
documentation|http://pandoc.org/scripting.html> converts level 2+ headers to
regular paragraphs.

    use Pandoc::Filter;
    use Pandoc::Elements;

    pandoc_filter Header => sub {
        return unless $_->level >= 2;
        return Para [ Emph $_->content ];
    };

To apply this filter on a Markdown file:

    pandoc --filter flatten.pl -t markdown < input.md

See L<https://metacpan.org/pod/distribution/Pandoc-Elements/examples/> for more 
examples of filters.

=head1 DESCRIPTION

Pandoc::Filter is a port of
L<pandocfilters|https://github.com/jgm/pandocfilters> from Python to modern
Perl.  The module provide provides functions to aid writing Perl scripts that
process a L<Pandoc|http://pandoc.org/> abstract syntax tree (AST) serialized as
JSON. See L<Pandoc::Elements> for documentation of AST elements.

This module is based on L<Pandoc::Walker> and its function C<transform>. Please
consider using its function interface (C<transform>, C<query>, C<walk>) instead
of this module.

=head1 METHODS

=head2 new( @actions | %actions )

Create a new filter with one or more action functions, given as code
reference(s). Each function is expected to return an element, an empty array
reference, or C<undef> to modify, remove, or keep a traversed element in the
AST. The current element is passed to an action function both as first argument
and in the special variable C<$_>. 

If actions are given as hash, key values are used to check which elements to
apply for, e.g. 

    Pandoc::Filter->new( 
        Header                 => sub { ... }, 
        'Suscript|Superscript' => sub { ... }
    )

=head2 apply( $ast [, $format [ $metadata ] ] )

Apply all actions to a given abstract syntax tree (AST). The AST is modified in
place and also returned for convenience. Additional argument format and
metadata are also passed to the action function. Metadata is taken from the
Document by default (if the AST is a Document root).

=head1 FUNCTIONS

The following functions are exported by default.

=head2 pandoc_walk( @actions | %actions )

Read a single line of JSON from STDIN and walk down the AST.  Implicitly sets
binmode UTF-8 for STDOUT.

=head2 pandoc_filter( @actions | %actions )

Read a single line of JSON from STDIN, apply actions and print the resulting
AST as single line of JSON. This function is roughly equivalent to

    my $ast = Pandoc::Elements::pandoc_json(<>);
    Pandoc::Filter->new(@actions)->apply($ast);
    say $ast->to_json;

=head2 stringify( $ast )

Walks the ast and returns concatenated string content, leaving out all
formatting. This function is also accessible as method of L<Pandoc::Element>
since version 0.12, so I<it will be removed as exportable function> in a later
version.

=head1 SEE ALSO

Script L<pandoc-walk> installed with this module facilitates execution of
C<pandoc_walk> to traverse a document.

=head1 COPYRIGHT AND LICENSE

Copyright 2014- Jakob Voß

GNU General Public License, Version 2

This module is heavily based on Pandoc by John MacFarlane.

=cut
