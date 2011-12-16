
=chapter Higher-Order Functions and Currying

Our F<memoize> function of R<Memoization|chapter> was a function
factory, building stub functions that served as replacements for other
functions.  The technique of using functions to build other functions
is extremely powerful.  In this chapter, we'll look at a technique
called I<currying>, which transforms an ordinary function into a
function factory for manufacturing more functions, and other
techniques for transforming one function into another.

A X<higher-order function> is a function that operates on other
functions instead of on data values.  Some of these take data
arguments and manufacture functions to order; others, like the F<imap>
function of X<imap|chapter>, transform one function into another one.

=section Currying

We have seen several times so far how to use callbacks to parametrize
the behavior of a function so that it can serve many purposes.  For
example, in R<dir_walk_callbacks|section> we saw how a generic
directory-walking function could be used to print a list of dangling
symbolic links, to return a list of interesting files, or to copy an
entire directory.

Callbacks are a way to make functions more general by supplying other
functions to them as arguments.  We saw how to write functions that
used closures to generate other functions as return values.  The
I<currying> technique we'll see combines closures and callbacks,
turning an ordinary function into a factory that manufactures
functions on demand.

Recall our F<walk_html> function from R<walk_html|chapter>.  Its
arguments were an HTML tree and a pair of callbacks, one to handle
plain text and one to handle tagged text.  We had found a way to use
this to extract all the text that was enclosed in T<h1> tags:

=inline extract_headers

We then observed that it would make sense to abstract the T<h1> out of
F<promote_if_h1tag>, to make it more general:

=inline promote_if

The second callback in F<walk_html> is rather peculiar.  It's an
anonymous function that we manufactured solely to call F<promote_if>
with the right arguments.  The previous version of the code was
tidier.  What we need is a way to get F<promote_if> to I<manufacture>
the F<promote_if_h1tag> function we need.  This seems like it should
be possible, since after all F<promote_if> already knows how to
perform the task that we want F<promote_if_h1tag> to perform.  All
that we need to do is to have F<promote_if> wrap up that behavior into
a new function:

=startlisting promote_if_curried        

        sub promote_if {
          my $is_interesting = shift;          
*         return sub {
            my $element = shift;
            if ($is_interesting->($element->{_tag}) {
              return ['keeper', join '', map {$_->[1]} @_];
            } else {
              return @_;
            }
*         }
        }
        
=contlisting promote_if_curried        

Instead of accepting both arguments right away, F<promote_if> now gets
the C<$is_interesting> callback only, and manufactures a new function
that, given an HTML element, promotes it if it's considered
interesting.  Making this change to F<promote_if>, to turn it from a
function of two arguments into a function of one argument that returns
a function of one argument, is called X<currying|d> it, and the
version of F<promote_if> immediately above is the X<curried|d> version
of F<promote_if>.N<Currying is so-named because it was popularized by
Haskell B. Curry in 1930, although it had been discovered by Gottlob
Frege in 1893 and rediscovered by Moses M<Schoenfinkel> in 1924.
X<Frege, Gottlob|i> X<Curry, Haskell B.|i> X<M<Schoenfinkel>,
Moses|i>>

The happy outcome is that the call to F<walk_html> is now much simpler:

          my @tagged_texts = walk_html($tree, 
                                       sub { ['maybe', $_[0]] }, 
                                       promote_if('h1'),
                                       });


Once you get used to the idea of currying, you start to see
opportunities to do it all over.  Recall our functions from R<power
series|chapter> for adding and multiplying two streams together
element-by-element: F<add2> and F<mul2>.

        sub add2 {
          my ($s, $t) = @_;
          return unless $s && $t;
          node(head($s) + head($t),
                       promise { add2(tail($s), tail($t)) });
        }

        sub mul2 {
          my ($s, $t) = @_;
          return unless $s && $t;
          node(head($s) * head($t),
                       promise { mul2(tail($s), tail($t)) });
        }

These functions are almost identical.  We saw in R<callback|chapter>
that two functions with similar code can often be combined into a
single function that accepts a callback parameter.  In this case, the
callback, C<$op>, specifies the operation to use to combine
C<head($s)> and C<head($t)>:

        sub combine2 {
          my ($s, $t, $op) = @_;
          return unless $s && $t;
          node($op->(head($s), head($t)),
               promise { combine2(tail($s), tail($t), $op) });
          
        }

Now we can build F<add2> and F<mul2> from F<combine2>:

        sub add2 { combine2(@_, sub { $_[0] + $_[1] }) }
        sub mul2 { combine2(@_, sub { $_[0] * $_[1] }) }

Since a major use of F<combine2> is to manufacture such functions, it
would be more convenient for F<combine2> to do what we wanted in the
first place.  We can turn F<combine2> into a factory that manufactures
stream-combining functions by currying it:

=startlisting combine2

        sub combine2 {
*         my $op = shift;
*         return sub {
*           my ($s, $t) = @_;
            return unless $s && $t;
            node($op->(head($s), head($t)),
*                promise { combine2($op)->(tail($s), tail($t)) });
*         };        
        }

=endlisting combine2

Now we simply have

        $add2 = combine2(sub { $_[0] + $_[1] });
        $mul2 = combine2(sub { $_[0] * $_[1] });

This may also be fractionally more efficient, since we won't have to do
an extra function call every time we call F<add2> or F<mul2>.  F<add2>
is the function to add the two streams, rather than a function that
re-invokes F<combine2> in a way that adds two streams.

If we want these functions to stick around, we can give them names, as
above; alternatively, we can use them anonymously:

        my $catstrs = combine2(sub { "$_[0]$_[1]" })->($s, $t);

=test catstrs

    use Stream qw(:all);
    do 'combine2';

    my $s = upto(1,4);
    my $t = upto(5,9);
    my $catstrs = combine2(sub { "$_[0]$_[1]" })->($s, $t);

    for my $want (qw(15 26 37 48)) {
        is(head($catstrs),$want);
        $catstrs = tail($catstrs);
    }   
    is($catstrs,undef);

=endtest

Instead of the F<scale> function we saw earlier, we might prefer this
curried version:

        sub scale {
          my $s = shift;
          return sub {
            my $c = shift;
            return if $c == 0;
            transform { $_[0] * $c } $s;
          }
        }

F<scale> is now a function factory.  Instead of taking a stream and a
number and returning a new stream, it takes a stream and manufactures
a function that produces new streams.  C<$scale_s = scale($s)> returns
a function for scaling C<$s>; given a numeric argument, say C<$n>,
C<$scale_s> produces a stream that has the elements of C<$s> scaled
by C<$n>.  For example C<$scale_s-\>(2)> returns a stream whose every
element is twice C<$s>'s, and C<$scale_s-\>(3)> returns a stream whose
every element is three times C<$s>'s.  If we're planning to scale the
same stream by several different factors, it might make sense to have
a single scale function to generate all the outputs.

Depending on how we're using it, we might have preferred to curry the
function arguments in the other order:

=listing scale

        sub scale {
*         my $c = shift;
          return sub {
*           my $s = shift;
            transform { $_[0] * $c } $s;
          }
        }

=endlisting scale

Now F<scale> is a factory for manufacturing scaling functions.
C<scale(2)> returns a function which takes any stream and doubles it;
C<scale(3)> returns a function which takes any stream and triples it.
We could write C<$double = scale(2)> and then use C<$double-\>($s)> to
double C<$s>, or C<scale(2)-\>($s)> to double C<$s>.

If you don't like the extra arrows in C<$double-\>($s)> you can get
rid of them by using Perl's I<glob> feature:

=note didn't you use this earlier in *sum?

        *double = scale(2);
        $s2 = double($s);

=note currying = closures + callbacks

=test scale

    use Stream qw(:all);
    do 'scale';

    my $double = scale(2);
    my $triple = scale(3);
    my $s = upto(1,3);
    my $s2 = $double->($s);
    my $s3 = $triple->($s);
    for my $want (qw(2 4 6)) {
        is(head($s2),$want);
        $s2 = tail($s2);
    }   
    is($s2,undef);
    for my $want (qw(3 6 9)) {
        is(head($s3),$want);
        $s3 = tail($s3);
    }   
    is($s3,undef);

=endtest scale

Similarly, in R<derivative|chapter>, we defined a F<slope> function
that returned the slope of some other function at a particular point:

        sub slope {
          my ($f, $x) = @_;
          my $e = 0.00000095367431640625;
          ($f->($x+$e) - $f->($x-$e)) / (2*$e);
        }

We could make this more flexible by currying the C<$x> argument:

=listing slope0

        sub slope {
*         my $f = shift;
          my $e = 0.00000095367431640625;
*         return sub {
*           my $x = shift;
            ($f->($x+$e) - $f->($x-$e)) / (2*$e);
*         };
        }

=endlisting slope0

=test slope0

    do 'slope0';

    my $d1 = slope( sub { 2 * $_[0] } );
    is($d1->(3)    ,2);    
    is($d1->(-1233),2);    

    my $d2 = slope( sub { cos( $_[0] ) } );
    is(int(10000*$d2->(0))     ,int(10000*-sin(0)));
    is(int(10000*$d2->(.1))     ,int(10000*-sin(.1)));
    is(int(10000*$d2->(3.14))   ,int(10000*-sin(3.14)));


=endtest slope0


F<slope> now takes a function and returns its derivative function!  By
evaluating the derivative function at a particular point, we compute
the slope at that point.  

If we like, we can use Perl's polymorphism to put both behaviors into
the same function:

=listing slope

        sub slope {
          my $f = shift;
          my $e = 0.00000095367431640625;
*         my $d = sub {
            my ($x) = shift;
            ($f->($x+$e) - $f->($x-$e)) / (2*$e);
          };
*         return @_ ? $d->(shift) : $d;
        }

=endlisting slope

Now we can call C<slope($f, $x)> as before, to compute the slope of
C<$f> at the point C<$x>, or we can call C<slope($f)> and get back the
derivative function of C<$f>.

=note if you get the kerning-pairs stuff back, then don't forget there
is an example there, F<increasing_value>, that uses it; bring this up.

=test slope

    do 'slope';

    my $d1 = slope( sub { 2 * $_[0] } );
    is($d1->(3)    ,2);    
    is($d1->(-1233),2);    

    is(slope( sub { 2 * $_[0] }, 12345 ), 2 );;

    my $d2 = slope( sub { cos( $_[0] ) } );
    is(int(10000*$d2->(0))     ,int(10000*-sin(0)));
    is(int(10000*$d2->(.1))     ,int(10000*-sin(.1)));
    is(int(10000*$d2->(3.14))   ,int(10000*-sin(3.14)));

=endtest slope

Currying can be a good habit to get into.  Earlier, we wrote

        sub iterate_function {
          my ($f, $x) = @_;
          my $s;         
          $s = node($x, promise { &transform($f, $s) });
        }

But it's almost as easy to write it this way instead:

=startlisting iterate_function

        sub iterate_function {
*         my $f = shift;
*         return sub { 
*           my $x = shift;
            my $s;         
            $s = node($x, promise { &transform($f, $s) });
*         };
        }

=endlisting iterate_function

It requires hardly any extra thought to do it this way, and the payoff
is substantially increased functionality.  We now have a function
which manufactures stream-building functions to order.  We could
construct F<upfrom> as a special case of F<iterate_function>, for
example:

        *upfrom = iterate_function(sub { $_[0] + 1 });

Or similarly, our earlier example of F<pow2_from>:

        *pow2_from = iterate_function(sub { $_[0] * 2 });

=test iterate_function

    use Stream qw(:all);
    do 'iterate_function';
    *upfrom    = iterate_function(sub { $_[0] + 1 });
    *pow2_from = iterate_function(sub { $_[0] * 2 });

    my $from3toinfinity = upfrom(3);
    for (qw(3 4 5)) {
        is( head($from3toinfinity) , $_);
        $from3toinfinity = tail($from3toinfinity);
    }
    # we're not going to infinity

    my $andbeyond       = pow2_from->(4);
    for (qw(4 8 16 32 64)) {
        is( head($andbeyond), $_);
        $andbeyond = tail($andbeyond);
    }

=endtest iterate_function

One final lexical point about currying: when currying a recursive
function, it's often possible to get a small time and memory
performance improvement by tightening up the recursion.  For example,
consider F<combine2> again:

        sub combine2 {
          my $op = shift;
          return sub {
            my ($s, $t) = @_;
            return unless $s && $t;
            node($op->(head($s), head($t)),
                 promise { combine2($op)->(tail($s), tail($t)) });
          };        
        }

C<combine2($op)> will return the same result function every time.  So
we should be able to get a speedup by caching its value and using the
cached value in the promise instead of repeatedly calling
jC<combine2($op)>.  Moreover, C<combine2($op)> is precisely the value
that F<combine2> is about to return anyway.  So we can change this to:

=listing combine2.1

        sub combine2 {
          my $op = shift;
*         my $r;
*         $r = sub {
            my ($s, $t) = @_;
            return unless $s && $t;
            node($op->(head($s), head($t)),
*                promise { $r->(tail($s), tail($t)) });
          };        
        }

=endlisting combine2.1

=test combine2.1

  use Stream qw(:all);
    do 'combine2.1';

    my $s = upto(1,4);
    my $t = upto(5,9);
    my $catstrs = combine2(sub { "$_[0]$_[1]" })->($s, $t);

    for my $want (qw(15 26 37 48)) {
        is(head($catstrs),$want);
        $catstrs = tail($catstrs);
    }   
    is($catstrs,undef);

=endtest combine2.1

Now the promise no longer needs to call F<combine2>; we've cached the
value that F<combine2> is about to return by storing it in C<$r>, and
the promise can call C<$r> directly.  The code is also more
perspicuous this way: now the promise says explicitly that the
function will be calling itself on the tails of the two streams.

These curried functions are examples of X<higher-order functions|d>.
Ordinary functions operate on values:  You put some values in, and you
get some other values out.  Higher-order functions are functions that
operate on other functions:  You put some functions in, and you get
some other functions out.  For example, in F<combine2> we put in a
function to operate on two scalars and we got out an analogous
function to operate on two streams.

=note multiple levels of currying

=note See SOAP thing in IDEAS file @20020227

=section Common Higher-Order Functions

Probably the two most fundamental higher-order functions for any list
or other kind of sequence are analogs of F<map> and F<grep>.  F<map>
and F<grep> are higher-order functions because each of them takes an
argument which is itself another function.  We've already seen
versions of F<map> and F<grep> for iterators and streams.  Perl's
standard F<map> and F<grep> each take a function and a list and return
a new list, for example

        map { $_ * 2 } (1..5);           # returns 2, 4, 6, 8, 10
        grep { $_ % 2 == 0 } (1..10);    # returns 2, 4, 6, 8, 10

Often it's more convenient to have curried versions of these:

=startlisting cmap

        sub cmap (&) {
          my $f = shift;
          my $r = sub {
            my @result;
            for (@_) {
              push @result, $f->($_);
            }
            @result;
          };
          return $r;
        }

=endlisting cmap

=test cmap-oops 1

        BEGIN { do "cmap" }
        my @a;
        # my @empty = cmap { $_ * 2 } @a;
        SKIP: {
          skip "this was to check if poymorphic cmap failed on an empty list", 1;
          is(scalar(@empty), 0, "oops");
        }

=endtest


=startlisting cgrep

        sub cgrep (&) {
          my $f = shift;
          my $r = sub {
            my @result;
            for (@_) {
              push @result, $_ if $f->($_);
            }
            @result;
          };
          return $r;
        }

=endlisting cgrep

These should be called like this:

        $double = cmap { $_ * 2 };
        $find_slashdot = cgrep { $_->{referer} =~ /slashdot/i };

After which C<$double-\>(1..5)> returns (2, 4, 6, 8, 10) and
C<$find_slashdot-\>(weblog())> returns the weblog records that
represent referrals from Slashdot.  

It may be tempting to try to make F<cmap> and F<cgrep> polymorphic, as
we did with F<slope>.  (I was tempted, anyway.)

*       sub cmap (&;@) {
          my $f = shift;
          my $r = sub {
            my @result;
            for (@_) {
              push @result, $f->($_);
            }
            @result;
          };
*         return @_ ? $r->(@_) : $r;
        }

Then we would also be able to use F<cmap> and F<cgrep> like regular
F<map> and F<grep>:

        @doubles = cmap { $_ * 2 } (1..5);
        @evens = cgrep { $_ % 2 == 0 } (1..10);

Unfortunately, this apparently happy notation hides an evil surprise:

        @doubles = cmap { $_ * 2 } @some_array;

If C<@some_array> is empty, C<@doubles> is assigned a reference to a
doubling function.  

=test cmapgrep 2

    BEGIN {
    do 'cmap';
    do 'cgrep';
    }

    $double = cmap { $_ * 2 };
    $find_evens = cgrep { $_ % 2 == 0 };

    is_deeply( [$double->(1..5)], [2,4,6,8,10] );
    is_deeply( [$find_evens->(1..10)], [2,4,6,8,10] );

    # SKIP: {
    #   skip "you took out the stuff about polymorphic cmap and cgrep", 2;
    #   @doubles = cmap { $_ * 2 }      (1..5);
    #   @evens = cgrep  { $_ % 2 == 0 } (1..10);
    #
    #   is_deeply( \@doubles, [2,4,6,8,10] );
    #   is_deeply( \@evens, [2,4,6,8,10] );
    # }
  
=endtest cmapgrep

=subsection Automatic Currying

We've written the same code several times to implement curried
functions:

        sub some_curried_function {
          my $first_arg = shift;
          my $r = sub { 
            ...
          };
          return @_ ? $r->(@_) : $r;
        }

(Possibly with the poymorphism trick omitted from the final line.)

As usual, once we recognize this pattern, we should see if it makes
sense to abstract it into a function:

=listing Curry.pm

        package Curry;
        use base 'Exporter';
        @EXPORT = ('curry');
        @EXPORT_OK = qw(curry_listfunc curry_n);

        sub curry_listfunc {
          my $f = shift;
          return sub { 
            my $first_arg = shift;
            return sub { $f->($first_arg, @_) };
          };
        }

        sub curry {
          my $f = shift;
          return sub { 
            my $first_arg = shift;
            my $r = sub { $f->($first_arg, @_) };
            return @_ ? $r->(@_) : $r;
          };
        }

        1;
    
=endlisting Curry.pm

F<curry> takes any function and returns a curried version of that
function.  For example, consider the F<imap> function from
R<Prog-imap|chapter>:

        sub imap (&$) {
          my ($transform, $it) = @_;
          return sub {
            my $next = NEXTVAL($it);
            return unless defined $next;
            return $transform->($next);
          }
        }

F<imap> is analogous to F<map>, but operates on iterators rather than
on lists.  We might use it like this:

        my $doubles_iterator = imap { $_[0] * 2 } $it;

If we end up doubling a lot of iterators, we have to repeat the 
C<{$_[0] * 2}> part:

        my $doubles_a = imap { $_[0] * 2 } $it_a;
        my $doubles_b = imap { $_[0] * 2 } $it_b;
        my $doubles_c = imap { $_[0] * 2 } $it_c;

We might wish we had a single, special purpose function for doubling
every element of an iterator, so we could write instead

        my $doubles_a = double $it_a;
        my $doubles_b = double $it_b;
        my $doubles_c = double $it_c;

Or even

        my ($doubles_a, $doubles_b, $doubles_c) 
          = map double($_), $it_a, $it_b, $it_c;

If we had written F<imap> in a curried style, we could have done

        *double = imap { $_[0] * 2 };

but we didn't, so we can't.  But that's no problem, because F<curry>
will manufacture a curried version of F<imap> on the fly:

        *double = curry(\&imap)->(sub { $_[0] * 2 });

Since the curried F<imap> function came in handy once, perhaps we
should keep it around in case we need it again:

        *c_imap = curry(\&imap);

Then to manufacture F<double> we do:

        *double = c_imap(sub { $_[0] * 2 });

=test curry

    use Curry;

    # easier to just drop this here, so we know what version we've got
        sub imap (&$) {
          my ($transform, $it) = @_;
          return sub {
            my $next = $it->();
            return unless defined $next;
            return $transform->($next);
          }
        }
        sub upto {
          my ($m, $n) = @_;
          return sub {
            return $m <= $n ? $m++ : undef;
          };
        }

    *c_imap = curry(\&imap);
    *double = c_imap(sub { $_[0] * 2 });
    my $it = upto(1,4);
    my $doubleit = double($it);
    is($doubleit->(),2);
    is($doubleit->(),4);
    is($doubleit->(),6);
    is($doubleit->(),8);
    is($doubleit->(),undef);

=endtest curry

=subsection Prototypes

The only drawback of this approach is that we lose F<imap>'s pretty
calling syntax, which is enabled by the C<(&@)> prototype at compile
time.  We can get it back, although the results are somewhat peculiar.  
First, we modify F<curry> so that the function it manufactures has the
appropriate prototype:

        sub curry {
          my $f = shift;
*         return sub (&;@) { 
            my $first_arg = shift;
            my $r = sub { $f->($first_arg, @_) };
            return @_ ? $r->(@_) : $r;
          };
        }

Then we call F<curry> at compile time instead of at run time:

        BEGIN { *c_imap = curry(\&imap); }

Now we can say

        *double = c_imap { $_[0] * 2 };

and we can still use F<c_imap> in place of regular F<imap>:

        $doubles_a = c_imap { $_[0] * 2 } $it_a;

=subsubsection Prototype Problems

The problem with this technique is that the prototype must be
hardwired into F<curry>, so now it will I<only> generate curried
functions with the prototype C<(&;@)>.  This isn't a problem for
functions like F<c_imap> or F<c_grep>, which would have had that
prototype anyway.  But that prototype is inappropriate for the curried
version of the F<scale> function from R<Prog-hamming.pl|chapter>.  The
uncurried version was:

        sub scale {
          my ($s, $c) = @_;
          $s->transform(sub { $_[0]*$c });
        }

C<curry(\&scale)> returns a function that behaves like this:

        sub { 
            my $s = shift;
            my $r = sub { scale($s, @_) };
            return @_ ? $r->(@_) : $r;
        }

The internals of this function are correct, and it will work just
fine, as long as it I<doesn't> have a C<(&;@)> prototype.  Such a
prototype would be inappropriate, since the function is expecting to
get one or two scalar arguments.  The correct prototype would be
C<($;$)>.  But if we did:

        BEGIN { *c_scale = curry(\&scale) }

then the resulting F<c_scale> function wouldn't work, because it would
have a C<(&;@)> prototype when we expectedto call it as though it had
a C<($;$)> prototype.  We want to call it in one of these two ways:

        my $double = c_scale(2);
        my $doubled_it = c_scale(2, $it);

but because F<c_scale> would have a prototype of C<(&;@)>, these both would
be syntax errors, yielding:

        Type of arg 1 to main::c_scale must be block or sub {} (not
        constant item)...

This isn't a show-stopper.  This works:

        *c_scale = curry(\&scale);
        my $double = c_scale(2);
        my $doubled_it = c_scale(2, $it);

Here the call to F<c_scale> is compiled, with no prototype,
before C<*c_scale> is assigned to; the call to F<curry> that sets up
the bad prototype occurs too late to foul up our attempt to
(correctly) call F<c_scale>.

But now we have a somewhat confusing situation.  Our F<curry> function
creates curried functions with C<(&;@)> prototypes, and these
prototypes may be inappropriate.  But the prototypes are inoperative
unless F<curry> is called in a C<BEGIN> block.  To add to the
confusion, this doesn't work:

        *c_scale = curry(\&scale);
        my $double = eval 'c_scale(2)';

because, once again, the call to F<c_scale> has been compiled after the
prototype was set up by F<curry>.

There isn't really any easy way to fix this.  The obvious thing to do
is to tell F<curry> what prototype we desire by supplying it with an
optional parameter:

        # Doesn't really work
        sub curry {
          my $f = shift;
*         my $PROTOTYPE = shift;
*         return sub ($PROTOTYPE) { 
            my $first_arg = shift;
            my $r = sub { $f->($first_arg, @_) };
            return @_ ? $r->(@_) : $r;
          };
        }

=note You can't just make shit up and expect the computer to know what
you mean, retardo!

Unfortunately, this is illegal; C<($PROTOTYPE)> does I<not> indicate
that the desired prototype is stored in C<$PROTOTYPE>.  Perl 5.8.1
provides a C<Scalar::Util::set_prototype> function to set the
prototype of a particular function:

=listing curry.set_prototype

        # Doesn't work before 5.8.1
*       use Scalar::Util 'set_prototype';
        
        sub curry {
          my $f = shift;
          my $PROTOTYPE = shift;
*         set_prototype(sub { 
            my $first_arg = shift;
            my $r = sub { $f->($first_arg, @_) };
            return @_ ? $r->(@_) : $r;
*         }, $PROTOTYPE);
        }

=endlisting curry.set_prototype

If you don't have 5.8.1 yet, the only way to dynamically specify the
prototype of a function is to use string C<eval>:

=listing curry.eval

        sub curry {
          my $f = shift;
          my $PROTOTYPE = shift;
*         $PROTOTYPE = "($PROTOTYPE)" if defined $PROTOTYPE;
*         my $CODE = q{sub PROTOTYPE { 
                         my $first_arg = shift;
                         my $r = sub { $f->($first_arg, @_) };
                         return @_ ? $r->(@_) : $r;
*                      }};
*         $CODE =~ s/PROTOTYPE/$PROTOTYPE/;
*         eval $CODE;
        }

=endlisting curry.eval

=note probably should test the curry.set_prototype and the curry.eval

=subsection More Currying

We can extend the idea of F<curry> and build a function that generates
a generic curried version of another function:

=contlisting Curry.pm

        sub curry_n {
          my $N = shift;
          my $f = shift;
          my $c;
          $c = sub {
            if (@_ >= $N) { $f->(@_) }
            else {
              my @a = @_;
              curry_n($N-@a, sub { $f->(@a, @_) });
            }
          };
        }

=endlisting Curry.pm

F<curry_n> takes two arguments: a number V<N>, and a function V<f>,
which expects at least V<N> arguments.  The result is a new function,
V<c>, which does the same thing V<f> does, but which accepts curried
arguments.  If V<c> is called with V<N> or more arguments, it just
passes them on to V<f> and returns the result.  If there are fewer
than V<N> arguments, V<c> generates a new function that remembers the
arguments that were passed; if this new function is called with the
remaining arguments, both old and new arguments are given to V<f>.
For example:

        *add = curry_n(2, sub { $_[0] + $_[1] });

And now we can call

        add(2, 3);      # Returns 5

or:

        *increment = add(1);
        increment(8);   # return 9

Or perhaps more realistically:

        *csubstr = curry_n(3, sub { defined $_[3] ?
                                       substr($_[0], $_[1], $_[2], $_[3]) :
                                       substr($_[0], $_[1], $_[2]) });

Then we can use any of:

        # Just like regular substr

        $ss = csubstr($target, $start, $length);
        csubstr($target, $start, $length, $replacement);

        # Not just like regular substr

        $target = "I like pie";

        # This '$part' function gets two arguments: a start position
        # and a length; it returns the apporpriate part of $target.

        $part = csubstr($target);
        my $ss = $part->($start, $length);  

        # This function gets an argument N and returns that many characters
        # from the beginning of $target.

        $first_N_chars = csubstr($target, 0);
        my $prefix_3 = $first_N_chars->(3);     # "I l"
        my $prefix_7 = $first_N_chars->(7);     # "I like "

=test curry_n

    use Curry 'curry_n';

     *add = curry_n(2, sub { $_[0] + $_[1] });

    is(add(2, 3), 5);

    *increment = add(1);
    is(increment(8),9);

    *csubstr = curry_n(3, sub { defined $_[3] ?
                                substr($_[0], $_[1], $_[2], $_[3]) :
                                substr($_[0], $_[1], $_[2]) });
    {
    my $target = "I like pie";
    is(csubstr($target, 2, 4), "like");
    is(csubstr($target, 2, 4, "eat"), "like");
    is($target, "I eat pie");
    }
    { # prove it works with substr too
    my $target = "I like pie";
    is(substr($target, 2, 4), "like");
    is(substr($target, 2, 4, "eat"), "like");
    is($target, "I eat pie");
    }

    # This '$part' function gets two arguments: a start position
    # and a length; it returns the apporpriate part of $target.
    {
    my $target = "I like pie";
    my $part = csubstr($target);
    is($part->(2,4), "like");

    my $ss = $part->(2,4,"eat");
    is($ss,"like");
    # hrm.  i expected this to work like the previous ones. - rspier
    # hrm.  me too. - mjd
    ### is($target,"I eat pie");
    }

    {
    my $target = "I like pie";
    my  $first_N_chars = csubstr($target, 0);
    is($first_N_chars->(3), "I l");
    is($first_N_chars->(7), "I like ");
    }

=endtest curry_n

        
=subsection Yet More Currying

Many of the functions we saw earlier in the book would benefit from
currying.  For example, F<dir_walk> from R<Prog-dir_walk_callbacks|chapter>:

=inline dir_walk_callbacks

Here we specify a top directory and two callback functions.  But the
callback functions are constant through any call to F<dir_walk>, and
we might like to specify them in advance, because we might know them
well before we know what directories we want to search.  The
conversion is easy:

=startlisting dir_walk_curried

         sub dir_walk {
*         unshift @_, undef if @_ < 3;
          my ($top, $filefunc, $dirfunc) = @_;

*         my $r;
*         $r = sub {
            my $DIR;
*           my $top = shift;
            if (-d $top) {
              my $file;
              unless (opendir $DIR, $top) {
                warn "Couldn't open directory $code: $!; skipping.\n";
                return;
              }

              my @results;
              while ($file = readdir $DIR) {
                next if $file eq '.' || $file eq '..';
*               push @results, $r->("$top/$file");
              }
              return $dirfunc->($top, @results);
            } else {
              return $filefunc->($top);
            }
          };
*         defined($top) ? $r->($top) : $r;
        }

We can still call C<dir_walk($top, $filefunc, $dirfunc)> and get the
same result, or we can omit the C<$top> argument (or pass C<undef>)
and get back a specialized file-walking function.  As a minor added
bonus, the recursive call will be fractionally more efficient because
the callback arguments don't need to be explicitly passed.

=endlisting dir_walk_curried


=note skipped testing for dir_walk_curried because of external dependencies -rsp

=test dir_walk_curried 3

        do "dir_walk_curried";  
        my @RESULT;
        sub accumulate { @_ }
        my $TOP = "Tests/TESTDIR";
        my @items = ($TOP, 
                    qw(a a/a1 a/a2 b b/b1 c c/c1 c/c2 c/c3 c/d c/d/d1 c/d/d2));

        @RESULT = dir_walk($TOP, \&accumulate, \&accumulate);
        s{^$TOP/}{}o for @RESULT;
        print "# @RESULT\n";
        is_deeply(\@RESULT, \@items,  "uncurried version");
        
        my $DW = dir_walk(\&accumulate, \&accumulate);
        @RESULT = $DW->($TOP);
        s{^$TOP/}{}o for @RESULT;
        print "# @RESULT\n";
        is_deeply(\@RESULT, \@items,  "curried version");

        $DW = dir_walk(undef, \&accumulate, \&accumulate);
        @RESULT = $DW->($TOP);
        s{^$TOP/}{}o for @RESULT;
        print "# @RESULT\n";
        is_deeply(\@RESULT, \@items,  "curried version");
        
=endtest


=section F<reduce> and F<combine>

The standard Perl X<C<List::Util> module> provides several commonly
requested functions that are not built in to Perl.  These include
F<max> and F<min> functions, which respectively return the largest and
smallest numbers in their argument lists, F<maxstr> and F<minstr>,
which are the analogous functions for strings, and F<sum>, which
returns the sum of the numbers in a list. 

If we write sample code for these five functions, we'll see the
similarity immediately:

        sub max { my $max = shift;
                  for (@_) { $max = $_ > $max ? $_ : $max }
                  return $max;
                }

        sub min { my $min = shift;
                  for (@_) { $min = $_ < $min ? $_ : $min }
                  return $min;
                }

        sub maxstr { my $max = shift;
                     for (@_) { $max = $_ gt $max ? $_ : $max }
                     return $max;
                   }

        sub minstr { my $min = shift;
                     for (@_) { $min = $_ lt $min ? $_ : $min }
                     return $min;
                   }

        sub sum { my $sum = shift;
                  for (@_) { $sum = $sum + $_ }
                  return $sum;
                }

Generalizing this gives us the F<reduce> function that is also
provided by C<List::Util>:

        sub reduce { my $code = shift;
                     my $val = shift;
                     for (@_) { $val = $code->($val, $_) }
                     return $val;
                   }
                     
(C<List::Util::reduce> is actually written in C for speed, but what it
does it equivalent to this Perl code.)  The idea is that we're going
to scan the list one element at a time, accumulating a 'total' of some
sort.  We provide a function (C<$code>) which says how to compute the
new 'total', given the old total (first argument) and the current
element (second argument).  If our goal is just to add up all the list
elements, then we compute the total at each stage by adding the
previous total to the current element:

        reduce(sub { $_[0] + $_[1] }, @VALUES) == sum(@VALUES)

If our goal is to find the maximum element, then the 'total' is
actually the maximum so far, then we compute the total at each stage
by taking whichever of the current maximum and the current element is
larger: 

        reduce(sub { $_[0] > $_[1] ? $_[0] : $_[1] }, @VALUES) == max(@VALUES)

The F<reduce> function provided by C<List::Util> is easier to call
than the one above.  It places the total-so-far in C<$a> and the
current list element into C<$b> before invoking the callback, so that
one can write

        reduce(sub { $a + $b }, @VALUES)
        reduce(sub { $a > $b ? $a : $b }, @VALUES)

We saw how to make this change back in R<Prog-imap|section>, when we
arranged to have F<imap>'s callback invoked with the current iterator
value in C<$_> in addition to C<$_[0]>; this allowed it to have a more
F<map>-line calling syntax.  We can arrange F<reduce> similarly:

        sub reduce (&@) { 
          my $code = shift;
          my $val = shift;
          for (@_) { 
*           local ($a, $b) = ($val, $_); 
            $val = $code->($val, $_) 
          }
          return $val;
        }
                     
Here we're using the global variables C<$a> and C<$b> to pass the
total and the current list element.  Use of global variables normally
causes a compile-time failure under X<C<strict 'vars'>>, but there is
a special exemption for the variables C<$a> and C<$b>.  The exemption
is there to allow usages just like this one, and in particular to
support the analogous feature of Perl's built-in F<sort> function.
The C<List::Util> version of F<reduce> already has this feature built
in.

If we curry the F<reduce> function, we can use it to I<manufacture>
functions like F<sum> and F<max>:

        BEGIN {
          *reduce = curry(\&List::Util::reduce);
          *sum = reduce { $a + $b };
          *max = reduce { $a > $b ? $a : $b };
        }

=note also 'every' and 'any'

This version of F<reduce> isn't quite as general as it could be.  All
the functions manufactured by F<reduce> have one thing in common:
given an empty list of arguments, they always return undef.  For
F<max> and F<min> this may be appropriate, but for F<sum> it's wrong;
the sum of an empty list should be taken to be 0.  (The F<sum>
function provided by C<List::Util> also has this defect.)  This small
defect masks a larger one: when the argument list is nonempty, the
F<reduce> above assumes that the 'total' should be initialized to the
first data item.  This happens to work for F<sum> and F<map>, but it
isn't appropriate for all functions.  C<reduce> can be made much more
general if we drop this assumption.  As a trivial example, suppose we
want a function to produce the length of a list.  This is I<almost>
what we want:

        reduce { $a + 1 };

But it only produces the correct length when given a list whose first
element is 1, since otherwise C<$val> is incorrectly initialized.  A
more general version of F<reduce> accepts an explicit parameter to say
what value should be returned for an empty list:

*       sub reduce (&$@) { 
          my $code = shift;
          my $val = shift;
          for (@_) { 
            local ($a, $b) = ($val, $_); 
            $val = $code->($val, $_) 
          }
          return $val;
        }

A version with optional currying is:

=listing reduce

        sub reduce (&;$@) { 
          my $code = shift;
          my $f = sub {
            my $base_val = shift;
            my $g = sub {
              my $val = $base_val;
              for (@_) { 
                local ($a, $b) = ($val, $_); 
                $val = $code->($val, $_);
              }
              return $val;
            };
            @_ ? $g->(@_) : $g;
          };
          @_ ? $f->(@_) : $f;
        }

=endlisting reduce

=note the above reduce function is missing a }; and it wouldn't hurt if $val was initialized

The list-length function is now

        *listlength = reduce { $a + 1 } 0;

where the C<0> here is the correct result for an empty list.
Similarly, 

        *product = reduce { $a * $b } 1;

is a function which multiplies all the elements in a list of numbers.
We can even use F<reduce> to compute both at the same time:

        *length_and_product = reduce { [$a->[0]+1, $a->[1]*$b] } [0, 1];

This makes only one pass over the list to compute both the length and
the product.  For an empty list, the result is C<[0, 1]>, and for a
list with one element V<x>, the result is C<[1, x]>.
F<List::Util::reduce> can only manufacture functions that return undef
for the empty list, and that return the first list element for a
single-element list.  The F<length_and_produce> function can't be
generated by F<List::Util::reduce> because it doesn't
have these properties.

=note counting function sub count { my $s = @_ } ?

=note hashpush %h, k=>v, k=>v,... ?

=test reduce

        sub reduce (&;$@);
    do 'reduce';
    # we're only testing the final super-duper version right now.


   # reduce(sub { $_[0] + $_[1] }, @VALUES) == sum(@VALUES)
   is(reduce(sub { $a + $b },1,2,3),6);
   # reduce(sub { $_[0] > $_[1] ? $_[0] : $_[1] }, @VALUES) == max(@VALUES)
   my $z = reduce { $_[0] > $_[1] ? $_[0] : $_[1] } 2,3,1;
   is($z, 3);

   *listlength = reduce { $a + 1 } 0;
   is(listlength(10..20), 11, "listlength nonempty");
   is(listlength(), 0, "listlength empty");

   *product = reduce { $a * $b } 1;
   is(product(2..7), 5040, "7!");
   is(product(), 1, "0!");

=endtest reduce

=note Here's a nice example.  fold() on gcd() produces a version of
gcd that works on multiple values instead of on only two.

A properly general version of F<reduce> gets an additional argument,
which says that the function should return when given an empty list as
its argument.  In the programming literature, the properly general
version of F<reduce> is more typically called F<fold>:

        sub fold {
          my $f = shift;
          my $fold;       
          $fold = sub {
            my $x = shift;
            sub {
              return $x unless @_;
              my $first = shift;
              $fold->($f->($x, $first), @_)
            }
          }
        }

Eliminating the recursion yields:

=startlisting fold

        sub fold {
          my $f = shift;
          sub {
            my $x = shift;
            sub {
              my $r = $x;
*             while (@_) {
*               $r = $f->($r, shift());
*             }
*             return $r;
            }
          }
        }

=endlisting fold

=test fold

    do 'fold';
    do 'gcd';

    my $gcdf = fold(\&gcd)->(0);
    is($gcdf->(6,9),3);
    is($gcdf->(7,5),1);
    is($gcdf->(9,81,15),3);
    is($gcdf->(9,81,15,2),1);
    is($gcdf->(9,81,18,27),9);

=endtest fold


=note we discussed 'reduce' for streams in Chapter VI already

=subsection Boolean operators

Back in R<Searching Databases Backwards|section> we saw a system that
would search backwards through a log file looking for records that
matched a simple query.  To extend this into a useful database system,
we need to be able to combine simple queries into more complex ones.

Let's suppose that C<$a> and C<$b> are iterators that will produce
data items that match queries V<A> and V<B>, respectively.  How can we
manufacture an iterator that matches the query M<A or B>?

One way we could do this is to interleave the elements of C<$a> and
C<$b>:

=listing interleave

        sub interleave {
          my ($a, $b) = @_;
          return sub {
            my $next = $a->();
            unless (defined $next) {
              $a = $b;
              $next = $a->();
             }
            ($a, $b) = ($b, $a);
            $next;
          }
        }

=endlisting interleave

=test interleave

   do 'interleave';
   sub upto {
      my ($m, $n) = @_;
      return sub { return $m <= $n ? $m++ : undef;  };
   }

   my $i1 = upto(1,3);
   my $i2 = upto(4,6);
   my $i = interleave($i1,$i2);
   for (qw(1 4 2 5 3 6)) {
     is($i->(),$_);
   }

   # this should be the end of stream, but it's returning a CODEref
   # instead.  $i->()->() == undef.  Is this just a sign of "the
   # interleaved outputs including some records (the end) more than
   # once?"
    
   is($i->(),undef);
   
=endtest interleave

But this has the drawback that if the record sets produced by C<$a>
and C<$b> happen to overlap, the interleaved outputs will include some
records more than once.

We can do better if we suppose that the records will be produced in
some sort of canonical order.  This assumption isn't unreasonable.
Typically, a database will have a natural order dictated by the
physical layout of the information on the disk and will always produce
records in this natural order, at least until the data is modified.
For example, our program for searching the web log file always
produces matching records in the order they appear in the file.  Even
DBM files, which don't appear to keep records in any particular order,
have a natural order; this is the order in which the records will be
generated by the F<each> function.  

Supposing that C<$a> and C<$b> will produce records in the same order,
we can perform an 'or' operation as follows:

=listing Iterator_Logic.pm

        package Iterator_Logic;
        use base 'Exporter';
        @EXPORT = qw(i_or_ i_or i_and_ i_and i_without_ i_without);
        
        sub i_or_ {
          my ($cmp, $a, $b) = @_;
          my ($av, $bv) = ($a->(), $b->());
          return sub {
            if (! defined $av && ! defined $bv) { return }
            elsif (! defined $av) { $rv = $bv; $bv = $b->() }
            elsif (! defined $bv) { $rv = $av; $av = $a->() }
            else {
              my $d = $cmp->($av, $bv);
              if    ($d < 0) { $rv = $av; $av = $a->() }
              elsif ($d > 0) { $rv = $bv; $bv = $b->() }
              else           { $rv = $av; $av = $a->(); $bv = $b->() }
            }
            return $rv;
          }
        }

        use Curry;
        BEGIN { *i_or = curry(\&i_or_) }

=endlisting Iterator_Logic.pm

F<i_or_> gets a comparator function, C<$cmp>, which defines the
canonical order, and two iterators, C<$a> and C<$b>.  It returns a new
iterator which returns the next record from either C<$a> or C<$b> in
the canonical order.  If C<$a> and C<$b> both produce the same record,
the duplicate is discarded.  It begins by kicking C<$a> and C<$b> to
obtain the next record from each.  If either is exhausted, it returns
the record from the other; if both are exhaused, it returns C<undef>
to indicate that there are no more records.  C<$rv> holds the record
that is to be the return value.

If both input iterators produce records, the new iterator compares the
records to see which should come out first.  If the comparator returns
zero, it means the two records are the same, and only one of them
should be emitted.  C<$rv> is assigned one of the two records, as
appropriate, and then one or both of the iterators is kicked to
produce new records for the next call.

The logic is very similar to the F<merge> function of
R<Prog-stream-merge|section>.  In fact, F<merge> is the stream analog of
the 'or' operator.

F<i_or> is a curried version of F<i_or_>, called like this:

        BEGIN { *numeric_or = i_or { $_[0] <=> $_[1] };
                *alphabetic_or = i_or { $_[0] cmp $_[1] };
         }

        $event_times =  numeric_or($access_request_times,
                        numeric_or($report_request_times,
                                   $server_start_times));



=note make sure you test this

'and' is similar:

=contlisting Iterator_Logic.pm

        sub i_and_ {
          my ($cmp, $a, $b) = @_;
          my ($av, $bv) = ($a->(), $b->());
          return sub {
            my $d;
            until (! defined $av || ! defined $bv || 
                   ($d = $cmp->($av, $bv)) == 0) {
              if ($d < 0) { $av = $a->() }
              else        { $bv = $b->() }
            }
            return unless defined $av && defined $bv;
            my $rv = $av;
            ($av, $bv) = ($a->(), $b->());
            return $rv;
          }
        }

        BEGIN { *i_and = curry \&i_and_ }

=endlisting Iterator_Logic.pm

=note the code here should be more nearly analogous to 'or'.

=test and-or

        use Curry;
        use Iterator_Logic;

        my @a = (2, 3, 5, 7, 11, 13, 17);
        my @b = (1, 2, 3, 4, 5, 6, 7);

        my (@and, @or);
        { my %count;
          for (@a, @b) { $count{$_}++ }
          @and = grep $count{$_}==2, sort { $a <=> $b } keys %count;
          @or  = grep $count{$_}!=0, sort { $a <=> $b } keys %count;
        }
        print "# and: @and\n";
        print "# or:  @or\n";

        sub l2i {
          my @a = @_;
          my $i = 0;
          return sub {
            $a[$i++];
          };
        }

        { 
          my $and = i_and(sub { $_[0] <=> $_[1] }, l2i(@a), l2i(@b));
          my $andf = i_and(sub { $_[0] <=> $_[1] });
          my $andc = $andf->(l2i(@a), l2i(@b));
          for (@and) {
            is($and->(),  $_, "and uncurried");
            is($andc->(), $_, "and curried");
          }
          is($and->(),  undef, "and uncurried exhausted");
          is($andc->(), undef, "and curried exhausted");
        }
        
        { 
          my $or = i_or(sub { $_[0] <=> $_[1] }, l2i(@a), l2i(@b));
          my $orf = i_or(sub { $_[0] <=> $_[1] });
          my $orc = $orf->(l2i(@a), l2i(@b));
          for (@or) {
            is($or->(),  $_, "or uncurried");
            is($orc->(), $_, "or curried");
          }
          is($or->(),  undef, "or uncurried exhausted");
          is($orc->(), undef, "or curried exhausted");
        }
        
=endtest and-or


=section Databases

Back in R<Prog-FlatDB.pm|section> we saw the beginnings of a
database system that would manufacture an iterator containing the
results of a simple query.  To open the database we did

        my $dbh = FlatDB->new($datafile);

and then to perform a query,

        $dbh->query($filename, $value);

or

        $dbh->callbackquery(sub { ... });

which selects the records for which the subroutine returns true.

Let's extend this system to handle compound queries.  Eventually,
we'll want the system to support calls like this:

        $dbh->select("STATE = 'NY' | 
                      OWES > 100 & STATE = 'MA'");

This will require parsing of the query string, which we'll see in
detail in R<parsing|chapter>.  In the meantime, we'll build the
internals that are required to support such queries.

The internals for simple queries like C<"STATE = 'NY'"> are already
done, since that's exactly what the C<$dbh-\>query('STATE', 'NY')>
does.  We can assume that other simple queries are covered by similar
simple functions, or perhaps by calls to F<callbackquery>.    What we
need now are ways to combine simple queries into compound queries.

=note figure out the details of simple queries.  For example, is there
a good way to specify the operator first and the filename and value
after?

The F<i_and> and F<i_or> functions we saw earlier will do what we
want, if we modify them suitably.  The main thing we need to arrange
is to define a canonical order for records produced by one of the
simple query iterators.  In particular, we need some way for the
F<i_and> and F<i_or> operators to recognize that their two argument
iterators have generated the same output record.

The natural way to do this is to tag each record with a unique ID
number as it comes out of the query.  Two different records will have
different ID numbers.  For flat-file databases, there's a natural
record ID number already to hand: the record number of the record in
the file.  We'll need to adjust the F<query> function so that the
iterators it returns will generate record numbers.  When we last saw
the F<query> function, it returned each record as a single string;
this is a good opportunity to have it return a more structured piece
of data:

=startlisting FlatDB_Composable.pm

        package FlatDB_Composable;
        use base 'FlatDB';
        use base 'Exporter';
        @EXPORT_OK = qw(query_or query_and query_not query_without);
        use Iterator_Logic;

        # usage: $dbh->query(fieldname, value)
        # returns all records for which (fieldname) matches (value)
        sub query {
          my $self = shift;
          my ($field, $value) = @_;
          my $fieldnum = $self->{FIELDNUM}{uc $field};
          return unless defined $fieldnum;
          my $fh = $self->{FH};
          seek $fh, 0, 0;
          <$fh>;                # discard header line
          my $position = tell $fh;
*         my $recno = 0;

          return sub {
            local $_;
            seek $fh, $position, 0;
            while (<$fh>) {
              chomp;
*             $recno++;
              $position = tell $fh;         
              my @fields = split $self->{FIELDSEP};
              my $fieldval = $fields[$fieldnum];
*             return [$recno, @fields] if $fieldval eq $value;
            }
            return;
          };
        }

=endlisting FlatDB_Composable.pm

=test query-composable

        use FlatDB_Composable;
        do 'query-composable';
        my $dbh = FlatDB_Composable->new('Programs/db.txt') or die $!;

        my $q = $dbh->query('STATE', 'NY');
        # assume order of records
        is_deeply($q->(),[1,'Adler','David','New York','NY','157.00']);
        is_deeply($q->(),[5,'Schwern','Michael','New York','NY','149658.23']);
        is($q->(),undef);

=endtest query-composable

It might be tempting to try to use Perl's built-in X<C<$.> variable>
here instead of carrying our own synthetic C<$recno>, but that's a bad
idea.  We took some pains to make sure that a single database
filehandle could be shared among more than one query.  However, the
information for C<$.> is stored inside the filehandle; since we don't
want the current record number to be shared between queries, we need
to store it in the query object (which is private) rather than in the
filehandle (which isn't).  An alternative to maintaining a special
C<$recno> variable would be to use C<$position> as a record
identifier, since it's already lying around, and since it has the
necesary properties of being different for different records and of
increasing as the query proceeds through the file.

Now we need to manufacture versions of F<i_and> and F<i_or> that use
the record ID numbers when deciding what to pass along.  Because these
functions are curried, we don't need to rewrite any code to do this:

=contlisting FlatDB_Composable.pm

        BEGIN { *query_or  =  i_or(sub { $_[0][0] <=> $_[1][0] });
                *query_and = i_and(sub { $_[0][0] <=> $_[1][0] });
              }

=endlisting FlatDB_Composable.pm

=contlisting FlatDB_Composable.pm invisible

        BEGIN { *query_without = i_without(sub { $_[0][0] <=> $_[1][0] }); }

        sub callbackquery {
          my $self = shift;
          my $is_interesting = shift;
          my $fh = $self->{FH};
          seek $fh, 0, SEEK_SET;
          <$fh>;                # discard header line
          my $position = tell $fh;
*         my $recno = 0;

          return sub {
            local $_;
            seek $fh, $position, SEEK_SET;
            while (<$fh>) {
              $position = tell $fh;         
              chomp;
*             $recno++;
              my %F;
              my @fieldnames = @{$self->{FIELDS}};
              my @fields = split $self->{FIELDSEP};
              for (0 .. $#fieldnames) {
                $F{$fieldnames[$_]} = $fields[$_];
              }
*             return [$recno, @fields] if $is_interesting->(%F);
            }
            return;
          };
        }

        1;


=endlisting FlatDB_Composable.pm

The comparator function says that arguments C<$_[0]> and C<$_[1]> will
be arrays of record data, and that we should compare the first element
of each, which is the record number, to decide which data should come
out first and to decide record identity.

=note with the provided dataset, this query isn't very interesting

In R<parser|chapter>, we'll build a parser which, given this query:

        "STATE = 'NY' | OWES > 100 & STATE = 'MA'"

makes this call:

        query_or($dbh->query('STATE', 'NY'),
                 query_and($dbh->callbackquery(sub { $F{OWES} > 100 }),
                           $dbh->query('STATE', 'MA')
                          ))

and returns the resulting iterator.  In the meantime, we can
manufacture the iterator manually.

=test query-or

 use Iterator_Logic;
 BEGIN {
 *query_or  =  i_or(sub { $_[0][0] <=> $_[1][0] });
 *query_and = i_and(sub { $_[0][0] <=> $_[1][0] });
 }

 use FlatDB_Composable;
 do 'query-composable';
 my $dbh = FlatDB_Composable->new('Programs/db.txt') or die $!;
 my $q = query_or($dbh->query('STATE', 'NY'),
                 query_and($dbh->callbackquery(sub { $F{OWES} > 100 }),
                           $dbh->query('STATE', 'MA')
                          ));
 is_deeply($q->(),[1,'Adler','David','New York','NY','157.00']);
 is_deeply($q->(),[5,'Schwern','Michael','New York','NY','149658.23']);
 is($q->(),undef);

=endtest query-or

The one important logical connective that's still missing is 'not'.
'not' is a little bit peculiar, logically, because its meaning is tied
to the original database.  If C<$q> is a query for all the people in a
database who are male, then C<query_not($q)> should produce all the
people from the database who are female.  But the C<query_not>
function can't do that without visiting the original database to find
the female persons.  Unlike the outputs of F<query_and> and
F<query_or>, the output of F<query_not> is not a selection of the
inputs.

One way around this is for each query to capture a reference back to
the original database that it's a query on.  An alternative is to
specify the database explicitly, as C<$dbh-\>query_not($q)>.  Then we
can implement a more general operator on queries, the so-called X<set
difference|d> operator, also known as X<without|d>. 

=contlisting Iterator_Logic.pm

        # $a but not $b
        sub i_without_ {
          my ($cmp, $a, $b) = @_;
          my ($av, $bv) = ($a->(), $b->());
          return sub {
            while (defined $av) {
              my $d;
              while (defined $bv && ($d = $cmp->($av, $bv)) > 0) {
                $bv = $b->();
              }
              if ( ! defined $bv || $d < 0 ) {
                my $rv = $av; $av = $a->(); return $rv;
              } else {
                $bv = $b->();
                $av = $a->();
              }
            }
            return;
          }
        }

        BEGIN {
          *i_without = curry \&i_without_;
          *query_without = 
            i_without(sub { my ($a,$b) = @_; $a->[0] <=> $b->[0] });
        }

        1;

=endlisting Iterator_Logic.pm

If C<$a> and C<$b> are iterators on the same database,
C<query_without($a, $b)> is an iterator which produces every record
that appears in C<$a> but I<not> in C<$b>.  This is useful on its own,
and it also gives us a base for 'not', which becomes something like
this:

=contlisting FlatDB_Composable.pm

        sub query_not {
          my $self = shift;
          my $q = shift;
          query_without($self->all, $q);
        }

C<$self-\>all> is a database method which performs a trivial query
that disgorges all the records in the database.  We could implement it
specially, or, less efficiently, we could simply use

        sub all {
          $_[0]->callbackquery(sub { 1 });
        }

        1;

=endlisting FlatDB_Composable.pm

A possibly amusing note is that once we have F<query_without>, we no
longer need F<query_and>, since (V<a> and V<b>) is the same as (V<a>
without (V<a> without V<b>)).

=note cartesian product corresponds to a table join

=test query-not 5
  
   use FlatDB_Composable;
   # MJD ???   
   # *FlatDB::query_without = i_without(sub { my ($a,$b) = @_; $a->[0] <=> $b->[0] });
   # do 'query-not';
  
   my $dbh = FlatDB_Composable->new('Programs/db.txt') or die $!;
   my $q = $dbh->query_not($dbh->query('STATE', 'NY'));
  
   # problem #1: the wrong query function is beign called.  we're
   # getting a string instead of an arrayref.  it has something to do
   # with the query_not.
  
   #while (my $t = $q->()) {
   #  ok(! ref $t, "$t is a plain string");
   #  unlike( $t, qr/:NY:/, "$t not in NY" )
   #}
  
   # arrayref version
   while (my $t = $q->()) { 
     print "# @$t\n";
     isnt( $t->[4], "NY", "$t->[4] is not NY");
     $count++;
   }
   is($count, 4, "four non-NY records");
  
=endtest query-not
  

=subsection Operator Overloading

R<operator-overloading|HERE>
Perl provides a feature called X<operator overloading|d> that lets us
write complicated query expressions more conveniently.  Operator
overloading allows us to redefine of Perl's built-in operator symbols
to have whatever meaning we like when they are applied to our
objects.   Enabling the feature is simple.  First we make a small
change to methods like F<query>  so that they return iterators that
are blessed into package C<FlatDB>.  Then we add

=startlisting FlatDB_Overloaded.pm invisible

        package FlatDB_Overloaded;
        BEGIN {
          for my $f (qw(and or without)) {
            *{"query_$f"} = \&{"FlatDB_Composable::query_$f"};
          }
        }
        use base 'FlatDB_Composable';

        sub query {
          $self = shift;
          my $q = $self->SUPER::query(@_);
          bless $q => __PACKAGE__;
        }

        sub callbackquery {
          $self = shift;
          my $q = $self->SUPER::callbackquery(@_);
          bless $q => __PACKAGE__;
        }

        1;

=endlisting FlatDB_Overloaded.pm

=contlisting FlatDB_Overloaded.pm

        use overload '|' => \&query_or,
                     '&' => \&query_and,
                     '-' => \&query_without,
                     'fallback' => 1;

=endlisting FlatDB_Overloaded.pm

at the top of F<FlatDB.pm>.  From then on, any time a C<FlatDB> object
participates in an C<|> or C<&> operation, the specified function will
be invoked instead.

Now, given the following simple queries:

        my ($ny, $debtor, $ma) = 
                ($dbh->query('STATE', 'NY'),
                 $dbh->callbackquery(sub { $F{OWES} > 100 }),
                 $dbh->query('STATE', 'MA')
                );

we'll be able to replace this:

        my $interesting = query_or($ny, query_and($debtor, $ma))

with this:

        my $interesting = $ny | $debtor & $ma;

The operators are still Perl's built-in operators, and so obey the
usual precedence and associativity rules.  In particular, C<&> has
higher precedence than C<|>.

=test query-overload

   use FlatDB_Overloaded;
  
   my $dbh = FlatDB_Overloaded->new('Programs/db.txt') or die $!;
   my ($ny, $debtor, $ma) = 
                  ($dbh->query('STATE', 'NY'),
                   $dbh->callbackquery(sub { $F{OWES} > 100 }),
                   $dbh->query('STATE', 'MA')
                  );

   my $q = $ny | $debtor & $ma;
   print "# --$q--\n"; # <-- perl bug?  note the non hex values
  
   is_deeply($q->(),[1,'Adler','David','New York','NY','157.00']);
   is_deeply($q->(),[5,'Schwern','Michael','New York','NY','149658.23']);
   is($q->(),undef);

   ($ny, $debtor, $ma) = 
                  ($dbh->query('STATE', 'NY'),
                   $dbh->callbackquery(sub { my %F=@_; $F{OWES} > 200 }),
                   $dbh->query('STATE', 'MA')
                  );

   my $q = $ny & $debtor | $ma;
   print "# --$q--\n"; # <-- perl bug?  note the non hex values
  
   is($q->()->[0],2);
   is($q->()->[0],4);
   is($q->()->[0],5);
   is($q->(),undef);

=endtest query-overload
  

=Stop

=section Products

So far nearly all of our transformations of stream values have been
essentially one-dimensional, like F<map> and F<grep>, which take as
input sequences of values and which emit sequences of new values in
the same order.  Similarly, functions like F<add2> take in two
sequences and return a single sequence.

One important type of operation we haven't covered so far produces a
fundamentally two-dimensional result.  The simplest example is called
the X<Cartesian product|d>.  Given two streams, (M<a_1>, M<a_2>,
M<a_3>, ...) and (M<b_1>, M<b_2>, M<b_3>, ...) the Cartesian product
contains all possible pairs of elements from the two streams:

        (a1, b1) (a1, b2) (a1, b3) ... 
        (a2, b1) (a2, b2) (a2, b3) ... 
        (a3, b1) (a3, b2) (a3, b3) ... 
        ...

To see why this might be useful, consider the Unix shell's wildcard
expansion.  An expression of the form C<{a,b,c}> in the shell will
expand to each of the strings C<a>, C<b>, and C<c>.  So, for example,
the command

        rm tricks.{ps,pdf}

is equivalent to 

        rm tricks.ps tricks.pdf

One can combine wildcards; this:

        rm tricks.{ps,pdf}{,.gz}

expands to this:

        rm tricks.ps tricks.ps.gz tricks.pdf tricks.pdf.gz

(The C<{,.gz}> expands to either the empty string or to "C<.gz>".)

The general rule for expanding such expressions is that an expression
of the form

        A{B,C,..,Y}Z

expands to

        ABZ ACZ ... AYZ

If any of C<B>, C<C>, ... C<Y>, or C<Z> contains further braces, then
the result above is expanded further.   So, returning the the example
above,         

        rm tricks.{ps,pdf}{,.gz}

is expanded first to

        rm tricks.ps{,.gz} tricks.pdf{,.gz}

(here C<A> is "C<tricks.>" and C<Z> is "C<{,.gz}>"); then
C<tricks.ps{,.gz}> is expanded:

        rm tricks.ps tricks.ps.gz tricks.pdf{,.gz}

and finally 

        rm tricks.ps tricks.ps.gz tricks.pdf tricks.pdf.gz

=endlisting i_without

=note missing section on products like cartesian product and 'zip'
Is pythagorean triples the best example you can come up with?

=note Example 1: Shell curly brace expansion.  Example 2: SQL table
joins.  Note that cartesian product of finite lists is easy; just use
nested loops.  This generates the matrix starting with the first row,
then the second row, etc.  This strategy clearly doesn't work for
infinite lists, because the first row of the resulting matrix is
infinite.  Instead we have to adopt a diagonal approach.
 
* Text-based database?  (Tibia?)  demonstrate composition operators

* 20010824 Program (with iterators) to generate all the strings that
  match a certain regex.  Use Japhy's parser?  Have a bounded-length
  and an unbounded-length version.  Interesting composition operators
  here.

* append, ordered merge, ordered and, cartesian product


* 20020121 Maybe move the currying section here from Chap. VI?

* 20020123  More examples of functions produced by 'reduce'?  Where
  did you read about the use of 'fold', anyway?  One of those papers
  in ~mjd/misc/papers/FP?  One possibility:  Graham Hutton's paper "A
  tutorial on the universality and expressiveness of fold" in
  .../fold.ps.  Also I think it was in the Bird and Wadler book on
  functional programming.

  Examples:  Given list of digits, construct base-10 number.
  Given list of path components, resolve to inodes.  (e.g., ("/",
  "usr", "local", "bin", "ezmlm", "ezmlm-make") => (2, 277985,
  2130089, 3229158, ...)  or resolve to true paths: -> ("/", "/usr",
  "/data/local", "/data/local/bin", ...).  Given a hash and a list of
  keys, produce a list of values.  

* 20020121 Don't forget to use game trees as an example somewhere.
  Reread the Hughes paprt on why FP matters; it has an extensive
  example of how to build a game tree search using functional
  techniques.

* 20020123 Function to turn streams into chapter-4 iterators.

* 20030919 Function that takes a binary operator and turns it into an
  any-ary operator.  e.g., turns a+b into sum(@p); gcd(a,b) into
  gcd(@p); concat2() into concatmany(); merge2 into merge

* You should be able to define generic and and or operators that work
  reasonably on any kind of iterator.

* Analogues of 'fold' for other data structures. Generic function for
  HTML trees: supply callback for empty tree, for text node, for tag
  node.  Generic function for directory hierarchies: Supply callback
  for directory, for nondirectory file.


I think they won't disappear entirely, but they will turn into a
single chapter.  Here's a revised outline:


        VII. Higher-order functions

        * Refer back to currying examples from Ch. VI; 'function factories'
          * Curried file tree walker (variation on Ch. I example)
          * curried version of ordered merge from Ch. VI

        * 'reduce' and 'combine' 
          * For lists
          * For streams
          * Abstract versions of 'reduce' and 'combine'
          * 'fold'
          * 'fold' is universal!

        * Extended example: Database queries
          * simple queries ('name = "Smith"')
          * 'and'; 'or'; 'not'
          * operator overloading  (sets up technique for Ch. IX)


