
=chapter Infinite Streams

R<Streams|HERE>
There's a special interface we can put on iterators that makes them
easier to deal with in many cases.  One drawback of the iterators
we've seen so far is that they were difficult or impossible to rewind;
once data came out of them, there was no easy way to put it back
again.  Later on, in R<parsing|chapter>, we will want to scan forward
in an input stream, looking for a certain pattern; if we don't see it,
we might want to rescan the same input, looking for a different
pattern.  This is inconvenient to do with the iterators of
R<iterators|chapter>, but the variation in this chapter is just the
thing, and we will use it extensively in R<parsing|chapter>.

What we need is a data structure more like an array or a list.  We can
make the iterators look like linked lists, and having done so we get
another benefit: we can leverage the enormous amount of knowledge and
technique that already exists for dealing with linked lists.

A linked list is a data structure common in most languages, but seldom
used in Perl, because Perl's arrays usually serve as a good enough
replacement.   We'll take a moment to review linked lists first.

=section Linked Lists

A X<linked list|d> is made up of X<node|of linked list|di>I<nodes>;
each node has two parts: a I<head>X<head|of linked list|di>, which
contains some data, and a I<tail>X<tail|of linked list|di>, which
contains (a pointer to) another linked list node, or possibly an
undefined value, indicating that the current node is the last one in
the list.

=startpicture linked-list

        +----+----+    +-----+----+    +----+-----+    
        | 12 | *------>|"foo"|  *----->| 28 |undef|
        +----+----+    +-----+----+    +----+-----+    

=endpicture linked-list

Here's typical Perl code, which uses arrays to represent nodes:

        sub node {
          my ($h, $t) = @_;
          [$h, $t];
        }

        sub head {
          my ($ls) = @_;
          $ls->[0];
        }

        sub tail {
          my ($ls) = @_;
          $ls->[1];
        }

        sub set_head {
          my ($ls, $new_head) = @_;
          $ls->[0] = $new_head;
        }

        sub set_tail {
          my ($ls, $new_tail) = @_;
          $ls->[1] = $new_tail;
        }

Linked lists are one of the data structures that's ubiquitous in all
low-level programming.  They hold a sequence of data, the way an array
does, but unlike an array they needn't be allocated all at once.  To
add a new data item to the front of a linked list, all that's needed
is to allocate a new node, store the new data item in the head of the
node, and store the address of the old first node into the tail of the
new node; none of the data need to be moved.  This is what F<node>
does:

        $my_list = node($new_data, $my_list);

In contrast, inserting a new item at the start of an array requires
all the array elements to be moved over one space to make room.

Similarly, it's easy to splice a data item into the middle of a linked
list by tweaking the tail of the node immediately before it:

        sub insert_after {
          my ($node, $new_data) = @_;
          my $new_node = node($new_data, tail($node));
          set_tail($node, $new_node);
        }

To splice data into the middle of an array requires that all the
following elements in the array be copied to make room, and the entire
array may need to be moved if there isn't any extra space at the end
for the last item to move into.

Scanning a linked list takes about twice as long as scanning the
corresponding array, since you spend as much time following the
pointers as you do looking at the data; with the array, there are no
pointers.  The big advantage of the array over the list is that the
array supports fast indexed access.  You can get or set array element
C<$a[$n]> instantly, regardless of what C<$n> is, but accessing the
V<n>th element of a list requires scanning the entire list starting
from the head, taking time proportional to V<n>.

=section Lazy Linked Lists

As you'll recall from R<Iterators|chapter>, one of the primary reasons
for using iterators is to represent lists that might be enormous, or
even infinite.  Using a linked list as an implementation of an
iterator won't work if all the list nodes must be in memory at the
same time.

The X<lazy computation> version of the linked list has a series of
nodes, just like a regular linked list.  And it might end with an
undefined value in the tail of the last node, just like a regular
linked list.  But the tail might instead be an object called a
X<promise|d>.  The promise is just that: a promise to compute the rest
of the list, if necessary.  We can represent it as an anonymous
function, which, if called, will return the rest of the list nodes.
We'll add code to the F<tail> function so that if it sees it's about
to return a promise, it will collect on the promise and return the
head node of the resulting list instead.  Nobody accessing the list
with the F<head> or F<tail> functions will be able to tell that
anything strange is going on.  

=startlisting Stream.pm

        package Stream;
        use base Exporter;
        @EXPORT_OK = qw(node head tail drop upto upfrom show promise
                        filter transform merge list_to_stream cutsort
                        iterate_function cut_loops);

        %EXPORT_TAGS = ('all' => \@EXPORT_OK);

        sub node {
          my ($h, $t) = @_;
          [$h, $t];
        }

        sub head {
          my ($s) = @_;
          $s->[0];
        }

        sub tail {
          my ($s) = @_;
*         if (is_promise($s->[1])) {
*           return $s->[1]->();
*         }
          $s->[1];
        }

*       sub is_promise {
*         UNIVERSAL::isa($_[0], 'CODE');
*       }

=note make sure you discuss UNIVERSAL::isa *somewhere* and explain why
to use that instead of just (ref $_[0] eq 'CODE').  It seems to be
first introduced in chapter III.

The modified version of the F<tail> function checks to see if the tail
is actually a promise; if so, it invokes the promise function to
manufacture the real tail, and returns that.  This is sometimes called
X<forcing|d> the promise.  

If nobody ever tries to look at the promise, then so much the better;
the code will never be invoked, and we'll never have to go to the
trouble of computing the tail.

We'll call these trick lists X<stream|di>I<streams>.  

=note You said:
We'll make
stream nodes objects, because the postfix method-style syntax turns
out to be easier to understand than the prefix function-style syntax.

=note when the time comes, point this out.
Hmm; maybe it's not actually true.

=note Also, it causes problems with constructions like
$s->tail->foo()  when $s might be defined but $s->tail not.

As is often the case, the most convenient representation of an empty
stream is an undefined value.  If we do this, we won't need a special
test to see if a stream is empty; a stream value will be true if and
only if it's nonempty.  This also means that we can create the last
node in a stream by calling C<node($value)>; the result is a stream
node whose head contains C<$value> and whose tail is undefined.

Finally, we'll introduce some syntactic sugar for making promises, as
we did for making iterators:

        sub promise (&) { $_[0] }

=endlisting Stream.pm

=subsection A Trivial Stream: F<upto>

To see how this all works, let's look at a trivial stream.  Recall the
F<upto> function from R<upto|subsection>: Given two numbers, V<m> and
V<n>, it returned an iterator which would return all the numbers
between V<m> and V<n>, inclusive.  Here's the linked list version:

        sub upto_list {
          my ($m, $n) = @_;
          return if $m > $n;
          node($m, upto_list($m+1, $n));
        }

This might consume a large amount of memory if C<$n> is much larger
than C<$m>.  Here's the lazy stream version:

=starttest upto 4

        use Stream;
        ok(1, "Stream.pm loaded");

        my $s = Stream::upto(7, 9);
        ok($s, "run upto()");

        for (7 .. 9) {
          push @a, Stream::drop($s);
        }
        is("@a", "7 8 9", "7..9");
        is(Stream::head($s), undef, "s is exhausted");

=endtest

=contlisting Stream.pm

        sub upto {
          my ($m, $n) = @_;
          return if $m > $n;
*         node($m, promise { upto($m+1, $n) } );
        }

It's almost exactly the same.  The only difference is that instead of
immediately making a recursive call to construct the tail of the list,
we defer the recursive call and manufacture a promise instead.  The
node we return has the right value (C<$m>) in the head, but the tail
is an IOU.  If someone looks at the tail, the F<tail> function sees
the promise and invokes the anonymous promise function, which in turn
invokes C<upto($m+1, $n)>, which returns another stream node.  The new
node's head is C<$m+1> (which is what was wanted) and its tail is
another IOU.

If we keep examining the successive tails of the list, we see node
after node, as if they had all been constructed in advance.
Eventually we get to the end of the list, and C<$m> is larger than
C<$n>; in this case when the F<tail> function invokes the promise, the
call to F<upto> returns an empty stream instead of another node.

If we want an I<infinite> sequence of integers, it's even easier: get
rid of the code that terminates the stream:

        sub upfrom {
          my ($m) = @_;
          node($m, promise { upfrom($m+1) } );
        }

=endlisting Stream.pm

=test upfrom 12

        use Stream;
        ok(1, "Stream.pm loaded");
        my $LONG = 10;

        my $s = Stream::upfrom(0);
        my $n = 0;
        for (0..$LONG-1) {
          is(Stream::head($s), $n, "element $_ is $n");
          $n++;
          Stream::drop($s);
          last unless $s;
        }
        is($n, $LONG, "stream is pretty long");        
        

=endtest


Let's return to F<upto>.  Notice that although the F<upto> function
was obtained by a trivial transformation from the recursive
F<upto_list> function, it is not itself recursive; it returns
immediately.  A later call to F<tail> may call it again, but the new
call will again return immediately.  Streams are therefore another way
of transforming recursive list functions into nonrecursive, iterative
functions.

We could perform the transformation in reverse on F<upfrom> and come
up with a recursive list version:

        sub upfrom_list {
          my ($m) = @_;
          node($m, upfrom_list($m+1) );
        }

This function does indeed compute an infinite list of integers, taking
an infinite amount of time and memory to do so.

=subsection Utilities for Streams

The first function you need when you invent a new data structure is a
diagnostic function that dumps out the contents of the data structure.
Here's a stripped-down version:

        sub show {
          my $s = shift;
          while ($s) {
            print head($s), $";
            $s = tail($s);
          }
          print $/;
        }

If the stream C<$s> is empty, the function exits, printing C<$/>,
normally a newline.  If not, it prints the head value of C<$s>
followed by C<$"> (normally a space), and then sets C<$s> to its tail
to repeat the process for the next node.

Since this prints every element of a stream, it's clearly not useful
for infinite streams; the C<while> loop will never end.  So the
version of F<show> we'll actually use will accept an optional
parameter V<n>, which limits the number of elements printed.  If V<n>
is specified, F<show> will print only the first V<n> elements:

=auxtest STDOUT.pm

        sub X::TIEHANDLE {
          my ($class, $ref) = @_;
          bless $ref => $class;
        }
        sub X::PRINT {
          my $self = shift;
          $$self .= join("", @_);
        }

        tie *STDOUT => 'X', \$OUTPUT;
        1;

=endtest

=test show 5

        use Stream;
        ok(1, "Stream.pm loaded");
        is($", " ", "\$\"");

        use STDOUT;

        print "Hello";
        is($OUTPUT, "Hello", "X test");
        $OUTPUT = "";

        my $s = Stream::upto(1, 10);
        Stream::show($s);
        is($OUTPUT, "1 2 3 4 5 6 7 8 9 10 \n", "upto 1..10");
        $OUTPUT = "";

        Stream::show($s, 5);
        is($OUTPUT, "1 2 3 4 5 \n", "upto 1..10 cut at 5");
        $OUTPUT = "";

=endtest

=contlisting Stream.pm

        sub show {
          my ($s, $n) = @_;
          while ($s && (! defined $n || $n-- > 0)) {
            print head($s), $";
            $s = tail($s);
          }
          print $/;
        }

=endlisting Stream.pm

For example:

=test show2 3

        is($", " ", "\$\"");

        use STDOUT;

        use Stream 'upfrom', 'show';
        ok(1, "Stream.pm loaded, imported upfrom and show");

        show(upfrom(7), 10);
        is($OUTPUT, "7 8 9 10 11 12 13 14 15 16 \n", "show-example-1");

=endtest

=startlisting show-example-1

        use Stream 'upfrom', 'show';

        show(upfrom(7), 10);

=endlisting show-example-1

This prints:

        7 8 9 10 11 12 13 14 15 16 

We can omit the second argument of F<show>, in which case it'll print
all the elements of the stream.  For an infinite stream like
C<upfrom(7)>, this takes a long time.  For finite streams, there's no
problem:

=test show3 3

        is($", " ", "\$\"");

        use STDOUT;        

        use Stream 'upto', 'show';
        ok(1, "Stream.pm loaded, imported upfrom and show");

        show(upto(3,6));
        is($OUTPUT, "3 4 5 6 \n", "show-example-2");


=endtest

=startlisting show-example-2

        use Stream 'upto', 'show';

        show(upto(3,6));

=endlisting show-example-2
        
The output:

        3 4 5 6


The line C<$s = tail($s)> in F<show> is a fairly common operation, so
we'll introduce an abbreviation:

=note this is tested by the upto tests

=contlisting Stream.pm

        sub drop {
          my $h = head($_[0]);
          $_[0] = tail($_[0]);
          return $h;
        }

=endlisting Stream.pm

Now we can call C<drop($s)>, which is analogous to C<pop> for arrays:
it removes the first element from a stream and returns that element.
F<show> becomes:

=test show-drop 3

        use Stream 'upto', 'upfrom';
        ok(1, "stream loaded");

        { package Stream;
          sub show {
            my ($s, $n) = @_;
            while ($s && (! defined $n || $n-- > 0)) {
              print drop($s), $";
            }
            print $/;
          }
        }

        use STDOUT;

        Stream::show(upto(3,6));
        is($OUTPUT, "3 4 5 6 \n", "show-example-2");
        $OUTPUT = "";

        Stream::show(upfrom(7), 10);
        is($OUTPUT, "7 8 9 10 11 12 13 14 15 16 \n", "show-example-2");
        $OUTPUT = "";

=endtest


        sub show {
          my ($s, $n) = @_;
          while ($s && (! defined $n || $n-- > 0)) {
*           print drop($s), $";
          }
          print $/;
        }


As with the iterators of R<iterators|chapter>, we'll want a few basic
utilities such as versions of C<map> and C<grep> for streams.

Once again, the analogue of C<map> is simpler:

=contlisting Stream.pm

        sub transform (&$) {
          my $f = shift;
          my $s = shift;
          return unless $s;
          node($f->(head($s)),
               promise { transform($f, tail($s)) });
        }

=endlisting Stream.pm

This example is prototypical of functions that operate on streams, so
you should examine it closely.  It's called in a way that's similar to
F<map>:

        transform {...} $s;

For example,

        my $evens = transform { $_[0] * 2 } upfrom(1);

generates an infinite stream of all positive even integers.  Or
rather, it generates the first node of such a stream, and a promise to
generate more, should we try to examine the later elements.

The analogue of F<grep> is only a little more complicated:

=contlisting Stream.pm

        sub filter (&$) {
          my $f = shift;
          my $s = shift;
          until (! $s || $f->(head($s))) {
            drop($s);
          }
          return if ! $s;
          node(head($s),
               promise { filter($f, tail($s)) });
        }

=endlisting Stream.pm

We scan the elements of C<$s> until either we run out of nodes (C<!
$s>) or the predicate function C<$f> returns true
(C<$f-\>(head($s))>).  In the former case, there are no matching
elements, so we return an empty stream; in the latter case, we return
a new stream whose head is the matching element we found and whose
tail is a promise to filter the rest of the stream in the same way.
It would probably be instructive to compare this with the F<igrep>
function of R<Prog-igrep|subsection>.

One further utility that will be useful is one to iterate a function
repeatedly.  Given an initial value V<x> and a function V<f>, it
produces the (infinite) stream containing V<x>, M<f(x)>, M<f(f(x))>,
... .  We could write it this way:

        sub iterate_function {
          my ($f, $x) = @_;
          node($x, promise { iterate_function($f, $f->($x)) });
        }

But there's a more interesting and even simpler way to do it that
we'll see later on instead.

=note
=subsection Some Interesting Example Here

=note
Perhaps reprising an example from chapter 4 or 5.  Preferably as mundane
as possible.  Log analysis perhaps?

=section Recursive Streams

The real power of streams arises from the fact that it's possible to
define a stream in terms of itself.  Let's consider the simplest
possible example, a stream that contains an infinite sequence of
carrots.  Following the F<upfrom> example of the previous section,
we begin like this:

        sub carrots {
          node('carrot', promise { carrots() });
        }
        my $carrots = carrots();

It's silly to define a function that we're only going to call from one
place; we might as well do this:

        my $carrots = node('carrot', promise { carrots() });

except that we now must eliminate the call to F<carrots> from inside the
promise.  But that's easy too, because the C<carrots()> and
C<$carrots> will have the same value:

        my $carrots = node('carrot', promise { $carrots });

This looks good, but it doesn't quite work, because an oddity in the
Perl semantics.  The scope of the C<my> variable C<$carrots> doesn't
begin until the I<next> statement, and that means that the two
mentions of C<$carrots> refer to different variables.  The declaration
creates a new lexical variable, which is assigned to, but the
C<$carrots> on the right-hand side of the assignment is the I<global>
variable C<$carrots>, not the same as the one we're creating.  The
line needs a tweak:

        my $carrots;
        $carrots = node('carrot', promise { $carrots });

We've now defined C<$carrots> as a stream whose head contains
C<'carrot'> and whose tail is a promise to produce the rest of the
stream---which is identical to the entire stream.  And it does work:

        show($carrots, 10);

The output:

        carrot carrot carrot carrot carrot carrot carrot carrot carrot carrot 

=test carrots 1

        use Stream 'node', 'promise', 'show';

        use STDOUT;

        my $carrots;
        $carrots = node('carrot', promise { $carrots });
        show($carrots, 10);
        is($OUTPUT, "carrot " x 10 . "\n", "carrots");

=endtest

=note actually $carrots here loses the promise entirely after you look
at the tail the first time, becoming a finite but looped stream, such
as you would have gotten by doing
        my $carrots;
        $carrots = ['carrot', $carrots];
should you mention this?  Is this technique useful in general?

=subsection Memoizing Streams

Let's look at an example that's a little less trivial than the one
with the carrots: we'll construct a stream of all powers of 2.  We
could follow the F<upfrom> pattern:

        sub pow2_from {
          my $n = shift;
          node($n, promise {pow2_from($n*2)})
        }
        my $powers_of_2 = pow2_from(1);

but again, we can get rid of the special-purpose F<pow2_from> function
in the same way that we did for the carrot stream.

        my $powers_of_2;
        $powers_of_2 = 
          node(1, promise { transform {$_[0]*2} $powers_of_2 });

=auxtest firstn.pl

        use Stream 'drop';

        sub firstn {
          my ($s, $n) = @_;
          my @result;
          while ($s && defined $n && $n--) {
            push @result, drop($s);
          }
          @result;
        }        

=endtest

=test pow2 1

        use Stream qw(node promise transform drop);
        require 'firstn.pl';

        my $powers_of_2;
        $powers_of_2 = 
          node(1, promise { transform {$_[0]*2} $powers_of_2 });

        my @a = firstn($powers_of_2, 10);
        is("@a", "1 2 4 8 16 32 64 128 256 512");

=endtest

This says that the stream of powers of 2 begins with the element 1,
and then follows with a copy of itself with every element doubled.
The stream itself contains 1, 2, 4, 8, 16, 32, ...; the doubled
version contains 2, 4, 8, 16, 32, 64, ...; and if you append a 1 to
the beginning of the doubled stream, you get the original stream back.

Unfortunately, a serious and subtle problem arises with this
definition.  It does produce the correct output:

        show($powers_of_2, 10);
        1 2 4 8 16 32 64 128 256 512 

But if we instrument the definition, we can see that the
transformation subroutine is being called too many times:

        $powers_of_2 = 
          node(1, promise { 
                    transform {
*                     warn "Doubling $_[0]\n";
                      $_[0]*2
                    } $powers_of_2
          });

The output is now:

        1 Doubling 1
        2 Doubling 1
        Doubling 2
        4 Doubling 1
        Doubling 2
        Doubling 4
        8 Doubling 1
        Doubling 2
        Doubling 4
        Doubling 8
        16 Doubling 1
        ...

=test pow2-warn 2

        use Stream qw(node promise transform drop);
        require 'firstn.pl';

        { package Stream;
          sub tail {
            my ($s) = @_;
            if (is_promise($s->[1])) {
              return $s->[1]->();
            }
            $s->[1];
          }
        }

        my $powers_of_2;
        $powers_of_2 = 
          node(1, promise { 
                    transform {
                      $warning .= "Doubling $_[0]\n";
                      $_[0]*2
                    } $powers_of_2
          });

        my @a = firstn($powers_of_2, 7);
        is("@a", "1 2 4 8 16 32 64");

        my $x = join "", map "Doubling $_\n", qw(1 1 2 1 2 4 1 2 4 8 1);
        is (substr($warning, 0, length($x)), $x, "warnings");

=endtest

The F<show> method starts by printing the head of the stream, which is
1.  Then it goes to get the tail, using the F<tail> method:

        sub tail {
          my ($s) = @_;
          if (is_promise($s->[1])) {
            return $s->[1]->();
          }
          $s->[1];
        }

=note I wonder if there's some way an illustration could make this
discussion clearer?

=startpicture powers-of-2-problem-a

        ILLUSTRATION TO COME

=endpicture powers-of-2-problem-a

Since the tail is a promise, this forces the promise, which calls
C<transform {...} $powers_of_2>.  F<transform> gets the head of
C<$powers_of_2>, which is 1, and doubles it, yielding a stream whose
head is 2 and whose tail is a promise to double the rest of the
elements of C<$powers_of_2>.  This stream is the tail of
C<$powers_of_2>, and F<show> prints its head, which is 2.

=note holy cow does this next paragraph need a diagram!

=startpicture powers-of-2-problem-b

        ILLUSTRATION TO COME

=endpicture powers-of-2-problem-b

F<show> now wants to get the tail of the tail.  It applies the F<tail>
method to the tail stream.  But the tail of the tail is a promise to
double the tail of C<$powers_of_2>.  This promise is invoked, and the
first thing it needs to do is to compute the tail of C<$powers_of_2>.
This is the key problem, because computing the tail of C<$powers_of_2>
is something we've already done.  Nevertheless, the promise is forced
a second time, causing another invocation of C<transform> and
producing a stream whose head is 2 and whose tail is a promise to
double the rest of the elements of C<$powers_of_2>.  

=startpicture powers-of-2-problem-c

        ILLUSTRATION TO COME

=endpicture powers-of-2-problem-c

C<transform> doubles the 2 and returns a new stream whose head is 4
and whose tail is (deep breath now) a promise to double the elements
of the tail of a stream which was created by doubling the elements of
the tail of $powers_of_2, which was itself created by doubling its own
tail.

=startpicture powers-of-2-problem-d

        ILLUSTRATION TO COME

=endpicture powers-of-2-problem-d

F<show> prints the 4, but when it tries to get the tail of the new
stream, it sets off a cascade of called promises, to get the tail of
the doubled stream, which itself needs to get the tail of another
stream, which is the doubled version of the tail of the main stream.  

Every element of the stream depends on calculating the tail of the
original stream, and every time we look at a new element, we calculate
the tail of C<$powers_of_2>, including the act of doubling the first
element.  We're essentially computing every element from scratch by
building it up from 1, and what we should be doing is building each
element on the previous element.  Our basic problem is that we're
forcing the same promises over and over.  But by now we have a
convenient solution to problems that involve repeating the same work
over and over: memoization.  We should remember the result whenever we
force a promise, and then if we need the same result again, instead of
calling the promise function, we'll get it from the cache.

There's a really obvious, natural place to cache the result of a
promise, too.  Since we don't need the promise itself any more, we can
store the result in the tail of the stream---which was where it would
have been if we hadn't deferred its computation in the first place.

The change to the code is simple:

=contlisting Stream.pm

        sub tail {
          my ($s) = @_;
          if (is_promise($s->[1])) {
*           $s->[1] = $s->[1]->();
          }
          $s->[1];
        }

=endlisting Stream.pm

=test pow2-warn2 2

        use Stream qw(node promise transform drop);

        my $powers_of_2;
        $powers_of_2 = 
          node(1, promise { 
                    transform {
                      $warning .= "Doubling $_[0]\n";
                      $_[0]*2
                    } $powers_of_2
          });
        
        require 'firstn.pl';

        my @a = firstn($powers_of_2, 7);
        is("@a", "1 2 4 8 16 32 64");

        my $x = join "", map "Doubling $_\n", qw(1 2 4 8 16 32);
        is (substr($warning, 0, length($x)), $x, "warnings");

=endtest

If the tail is a promise, we force the promise, and throw away the
promise and replace it with the result, which is the real tail.  Then
we return the real tail.  If we try to look at the tail again, the
promise will be gone, and we'll just see the correct tail.

With this change, the C<$powers_of_2> stream is both correct and
efficient.  The instrumented version produces output that looks like this:

        1 Doubling 1
        2 Doubling 2
        4 Doubling 4
        8 Doubling 8
        16 Doubling 16
        32 Doubling 32
        ...

=section The Hamming Problem

As an example of a problem that's easy to solve with streams, we'll
turn to an old chestnut of computer science, X<Hamming's
Problem>.N<Named for Richard W. Hamming, who also invented Hamming
codes.> Hamming's problem asks for a list of the numbers of the form
M<2^i3^j5^k>.  The list begins as follows:
X<Hamming, Richard W.|i>

        1 2 3 4 5 6 8 9 10 12 15 16 18 20 24 25 27 30 32 36 40 ...

It omits all multiples of 7, 11, 13, 17, and any other primes larger
than 5.
X<prime number|i>

The obvious method for generating the list is to try every number
starting with 1.  Say we want to learn whether the number V<n> is on
this list.  If V<n> is a multiple of 2, 3, or 5, then divide it by 2,
3, or 5 (respectively) until the result is no longer a multiple of 2,
3, or 5.  If the final result is 1, then the original number V<n> was
a Hamming number.  The code might look like this:

        sub is_hamming {
          my $n = shift;
          $n/=2 while $n%2 == 0;
          $n/=3 while $n%3 == 0;
          $n/=5 while $n%5 == 0;
          return $n == 1;
        }

        # Return the first $N hamming numbers
        sub hamming {
          my $N = shift;
          my @hamming;
          my $t = 1;
          until (@hamming == $N) {
            push @hamming, $t if is_hamming($t);
            $t++;
          }
          @hamming;
        }

Unfortunately, this is completely impractical.  It starts off well
enough.  But the example Hamming numbers above are
misleading---they're too close together.  As you go further out in the
list, the Hamming numbers get farther and farther apart.  The 2999th
Hamming number is 278,628,139,008.  Nobody has time to test
278,628,139,008 numbers; even if they did, they would have to test
314,613,072 more before they found the 3000th Hamming number.

But there's a better way to solve the problem.  There are four kinds
of Hamming numbers: multiples of 2, multiples of 3, multiples of 5,
and 1.  And moreover, every Hamming number except 1 is either 2, 3, or
5 times some other Hamming number.  Suppose we took the Hamming
sequence and doubled it, tripled it, and quintupled it:

        Hamming:  1  2  3  4  5  6  8  9 10 12 15 16 18  20 ...

        Doubled:  2  4  6  8 10 12 16 18 20 24 30 32 36  40 ...
        Tripled:  3  6  9 12 15 18 24 27 30 36 45 48 54  60 ...
     Quintupled:  5 10 15 20 25 30 40 45 50 60 75 80 90 100 ...

and then merged the doubled, tripled, and quintupled sequences in order:

         Merged:  2 3 4 5 6 8 9 10 12 15 16 18 20 24 25 27 30 32 36 40 ...

The result would be exactly the Hamming sequence, except for the 1 at
the beginning.  Except for the merging, this is similar to the way we
constructed the sequence of powers of 2 earlier.  To do it, we'll need
a merging function: R<Prog-stream-merge|HERE>

=contlisting Stream.pm

        sub merge {
          my ($S, $T) = @_;
          return $T unless $S;
          return $S unless $T;
          my ($s, $t) = (head($S), head($T));
          if ($s > $t) {
             node($t, promise {merge(     $S,  tail($T))});
           } elsif ($s < $t) {
             node($s, promise {merge(tail($S),      $T)});
           } else {
             node($s, promise {merge(tail($S), tail($T))});
           }
        }

=endlisting Stream.pm


=note Cross-reference this to the iterator ordered merge

=note also somewhere note the GC and time benefit of returning $S or
$T directly when the other is empty rather than wrapping another layer
of promises around them

This function takes two streams of numbers, C<$S> and C<$T>, which are
assumed to be in sorted order, and merges them into a single stream of
numbers whose elements are also in sorted order.  If either of C<$S>
or C<$T> is empty, the result of the merge is simply the other stream.
(If both are empty, the result is therefore an empty stream.)  If
neither is empty, the function examines the head elements of C<$S> and
C<$T> to decide which one should come out of the merged stream first.
It then constructs a stream node whose head is the lesser of the two
head elements, and whose tail is a promise to merge the rest of C<$S>
and C<$T> in the same way.  If the heads of C<$S> and C<$T> are the
same number, the duplicate is eliminated in the output.

To avoid cluttering up our code with many calls to F<transform>, we'll
build a utility that multiplies every element of a stream by a
constant:

=startlisting hamming.pl

        use Stream qw(transform promise merge node show);

        sub scale {
          my ($s, $c) = @_;
          transform { $_[0]*$c } $s;
        }


Now we can define a Hamming stream as a stream that begins with 1 and
is otherwise identical to the merge of the doubled, tripled, and
quintupled versions of itself:

        my $hamming;
        $hamming = node(1,
                        promise {
                          merge(scale($hamming, 2),
                          merge(scale($hamming, 3),
                                scale($hamming, 5),
                               ))
                        }
                       );


        show($hamming, 3000);

=endlisting hamming.pl

=startpicture hamming-structure

        ILLUSTRATION TO COME

=endpicture hamming-structure

=starttest hamming 4

        alarm(30);
        use STDOUT;

        require 'hamming.pl';
        ok(1, "got hamming.pl");

        my @hn = split /\s+/, $OUTPUT;

        is (join(" ", @hn[0..14]), "1 2 3 4 5 6 8 9 10 12 15 16 18 20 24",
                "initial segment");        
        is (scalar(@hn), 3000, "length");
        is ($hn[-1], 278942752080, "final number");

=endtest

This stream generates 3000 Hamming numbers (up to 278,942,752,080 =
M<2^4 3^20 5>) in about 14 seconds.

=note Idea: You can implement a non-streams version of this.  Store
the hamming numbers in an array initialized with (1).  Maintain three
indices into the array: p2, p3, and p5.  Then loop: Compute the
minimum of 2*$a[$p2], 3*$a[$p3], and 5*$a[$p5].  This is the next
hamming number H; append it to the array.  Then increment whichever of
the p_i has i*p_i = H.  Repeat.

=note Yes, this works great.  It's hamming-pr.pl.

=note The stream thing is probably simpler.  Also it has the benefit
that it garbage-collects the earlier elements of the sequence
automatically if possible.  To implement this into the iterative
algorithm is trickier; you have to shift the array and then adjust the
p_i.

=note does a stream version of the fib sequence lead to an analogous
efficient iterative version?

=note better come up with some plausible non-mathematical example.
Maybe recycle something from ch. 4?
Peephole optimization?

=note Loop detection with tortoise-hare algorithm.

=note funky quicksort oddity / Hoare's algorithm

=note SICP2 refers to the Hughes 'why functional programming matters'
paper for an example of lazy trees

=note You should emphasize that this is 'demand-driven' programming.
Do this in the Hamming section maybe?

=note symbolic computation?  You can represent cosine and exp as power
series, and then have an evaluation function for power series.
(Another application of currying:  eval($ps)->($x) = ps(x).)  SICP2
points out (ex 3.59) that you can define exp(x) implicitly by
observing that exp = cons(1, integrate(exp)).    Maybe save this
example for chapter 8, because the power series multiplication
function is so interesting?  Exercises 3.61 and 3.62 show how to
calculate a power series for a tangent function, which is of real
practical interest.

=note If mathematics seems too abstruse, try financial calculations.
Mortgages, bond yields, etc.  You have an example in 2001 Tricks of
the Wizards.

=section Regex String Generation

A question that comes up fairly often on IRC and in Perl-related
newsgroups is: given a regex, how can one generate a list of all the
strings matched by the regex?  The problem can be rather difficult to
solve.  But the solution with streams is straightforward and compact.

There are a few complications we should note first.  In the presence
of assertions and other oddities, there may not be any string that
matches a given regex. For example, nothing matches the regex
C</a\bz/>, because it requires the letters C<a> and C<z> to be
adjacent, with a zero-length word boundary in between, and by
definition, a word boundary does not occur between two adjacent
letters.  Similarly, C</a^b/> can't match any string, because the C<b>
must occur at the beginning of the string, but the C<a> must occur
I<before> the beginning of the string.

Also, if our function is going to take a real regex as input, we have
to worry about parsing regexes.  We'll ignore this part of the problem
until R<parsing|chapter>, where we'll build a parsing system that
plugs into the string generator we'll develop here.  

Most of the basic regex features can be reduced to combinations of
a few primitive operators.  These operators are concatenation,
union, and C<*>.N<The C<*> operator is officially called the X<closure
operator|d>, and the set of strings that match C</A*/> is the
I<closure> of the set that match C</A/>.  This has nothing to do with
anonymous function closures.> We'll review: if V<A> and V<B> are
regexes, then:

=bulletedlist

=item M<AB>, the concatenation of V<A> and V<B>, is a regex that
matches any string of the form V<ab>, where V<a> is a string that
matches V<A> and V<b> is a string that matches V<B>.

=item M<A|B>, the union of V<A> and V<B>, is a regex that matches any
string V<s> that matches V<A> or V<B>.

=item M<A*> matches the empty string, or the
concatenation of one or more strings that each individually match
V<A>.

=endbulletedlist

With these operators, and the trivial regexes that match literal
strings, we can build most of Perl's other regex operations.  For
example, C</A+/> is the same as C</AA*/>, and C</A?/> is the same as
C</|A/>.  Character classes are equivalent to unions; for example,
C</[abc]/> and C</a|b|c/> are equivalent.  Similarly C</./> is a union
of 255 different characters (everything but the newline.)

C<^> and C<$> are easier to remove than to add, so we'll include them
by default, so that all regexes are implicitly anchored at both ends.
Our system will only be able to generate the strings that match a
regex if the regex begins with C<^> and ends with C<$>.  This is
really no restriction at all, however.  If we want to generate the
strings that match C</A$/>, we can generate the strings that match
C</^.*A$/> instead; these are exactly the same strings.    Similarly
the strings that match C</^A/> are the same as those that match
C</^A.*$/> and the strings that match C</A/> are the same as those
that match C</^.*A.*$/>.  Every regex is therefore equivalent to one
that begins with C<^> and ends with C<$>.

We'll represent a regex as a (possibly infinite) stream of the strings
that it matches.  The C<Regex> class will import from C<Stream>:
R<regex-stream|HERE>
R<regex-string-generation|HERE>

=startlisting Regex.pm

        package Regex;
        use Stream ':all';
        use base 'Exporter';
        @EXPORT_OK = qw(literal union concat star plus charclass show
                        matches);

Literal regexes are trivial.  The corresponding stream has only one element:

        sub literal {
          my $string = shift;
          node($string, undef);
        }

=endlisting Regex.pm

=startpicture regex-literal

        ILLUSTRATION TO COME

=endpicture regex-literal

        show(literal("foo"));
*       foo

=test regex-literal 1

        use Stream 'show';
        use Regex 'literal';
        use STDOUT;

        show(literal("foo"));
        is($OUTPUT, "foo \n");        

=endtest

Union is almost as easy.  We have some streams, and we want to merge
all their elements into a single stream.  We can't append the streams
beginning-to-end as we would with ordinary lists, because the streams
might not have ends.   Instead, we'll interleave the elements.  Here's
a demonstration function that mingles two streams this way:

=contlisting Regex.pm

        sub mingle2 {
          my ($s, $t) = @_;
          return $t unless $s;
          return $s unless $t;
          node(head($s), 
               node(head($t), 
                        promise { mingle2(tail($s), 
                                          tail($t)) 
                                        }
              ));
        }


Later on it will be more convenient if we have a more general version
that can mingle any number of streams:
R<Prog-union|HERE>

        sub union {
          my ($h, @s) = grep $_, @_;
          return unless $h;
          return $h unless @s;
          node(head($h),
               promise {
                 union(@s, tail($h));
               });
        }

=endlisting Regex.pm

=startpicture regex-union

        ILLUSTRATION TO COME

=endpicture regex-union

=auxtest unordered-union.pl

        use Stream qw(head promise tail node);

        sub union {
          my ($h, @s) = grep $_, @_;
          return unless $h;
          return $h unless @s;
          node(head($h),
               promise {
                 union(@s, tail($h));
               });
        }
        *Regex::union = \&union;

=endtest

=starttest regex-mingle 1

        use Stream 'upfrom', 'upto';
        use Regex 'union';
        require 'firstn.pl';
        require 'unordered-union.pl';

        $s = union(upfrom(3), upto(10,12), upfrom(20));
        my @a = firstn($s, 12);
        is("@a", "3 10 20 4 11 21 5 12 22 6 23 7");

=endtest

=starttest regex-union 1

        use Stream 'upfrom', 'upto';
        use Regex 'union';
        require 'firstn.pl';
        require 'unordered-union.pl';

        $s = union(upfrom(3), upto(10,12), upfrom(20));
        my @a = firstn($s, 12);
        is("@a", "3 10 20 4 11 21 5 12 22 6 23 7");

=endtest

The function starts by throwing out any empty streams from the
argument list.  Empty streams won't contribute anything to the output,
so we can discard them.  If all the input streams were empty, F<union>
returns an empty stream.  If there was only one nonempty input stream,
F<union> returns it unchanged.  Otherwise, the function does the
mingle: the first element of the first stream is at the head of the
result, and the rest of the result is obtained by mingling the rest of
the streams with the rest of the first stream.  The key point here is
that the function puts C<tail($h)> at the I<end> of the argument list
in the recursive call, so that a different stream gets assigned to
C<$h> next time around.  This will ensure that all the streams get
cycled through the C<$h> position in turn.

Here's a simple example:

        # generate infinite stream ($k-1, $k-2, $k-3, ...)
        sub constant {
          my $k = shift;
          my $i = shift || 1;
          my $s = node("$k-$i", promise { constant($k, $i+1) });
        }

        my $fish = constant('fish');
        show($fish, 3);
*       fish-1 fish-2 fish-3

        my $soup = union($fish, constant('dog'), constant('carrot'));

        show($soup, 10);
        fish-1 dog-1 carrot-1 fish-2 dog-2 carrot-2 fish-3 dog-3 carrot-3 fish-4

=test regex-constant-union 2

        use Stream 'node', 'promise', 'show';
        use Regex 'union';
        require 'unordered-union.pl';
        use STDOUT;

        sub constant {
          my $k = shift;
          my $i = shift || 1;
          my $s = node("$k-$i", promise { constant($k, $i+1) });
        }

        my $fish = constant('fish');
        show($fish, 3);
        is($OUTPUT, "fish-1 fish-2 fish-3 \n", "fish 3");
        $OUTPUT = "";

        my $soup = union($fish, constant('dog'), constant('carrot'));

        show($soup, 10);
        is($OUTPUT, "fish-1 dog-1 carrot-1 fish-2 dog-2 carrot-2 fish-3 dog-3 carrot-3 fish-4 \n", "soup");
        
=endtest
        
Now we'll do concatenation.  If either of regexes V<S> or V<T> never
matches anything, then M<ST> also can't match anything.  Otherwise,
V<S> is matched by some list of strings, and this list has a head C<s>
and a tail M<s_{tail}>; similarly V<T> is matched by some other list
of strings with head C<t> and tail M<t_{tail}>. What strings are
matched by M<ST>?  We can choose one string that matches V<S> and one
that matches V<T>, and their concatenation is one of the strings that
matches M<ST>.  Since we split each of the two lists into two parts,
we have four choices for how to construct a string that matches M<ST>:

=bulletedlist

=item C<st> matches V<ST>

=item C<s> followed by any string from M<t_{tail}> matches V<ST>

=item Any string from M<s_{tail}> followed by C<t> matches V<ST>

=item Any string from M<s_{tail}> followed by any string from M<t_{tail}> matches V<ST>

=endbulletedlist

Notationally, we write

        (s|s_{tail}).(t|t_{tail) = s.t|s.t_{tail}|s_{tail}.t|s_{tail}.t_{tail}

The first of these only contains one string.  The middle two are
simple transformations of the tails of V<S> and V<T>.  The last one is
a recursive call to the F<concat> function itself.  So the code is
simple:
R<Prog-concat|HERE>

=contlisting Regex.pm

        sub concat {
          my ($S, $T) = @_;
          return unless $S && $T;

          my ($s, $t) = (head($S), head($T));

          node("$s$t", promise {
            union(postcat(tail($S), $t),
                   precat(tail($T), $s),
                  concat(tail($S), tail($T)),
                 )
          });
        }

=endlisting Regex.pm

=note The object-oriented version of this doesn't work in the regime
where empty streams are undef, because $S->tail might be undef and
then $S->tail->postcat($t) dies.  $S->tail ? $S->tail->postcat($t)
: () works, as would postcat($S->tail, $t) or postcat(tail($S),
$t).

=startpicture regex-concat

        ILLUSTRATION TO COME

=endpicture regex-concat

F<precat> and F<postcat> are simple utility functions that
concatenate a string to the beginning or end of every element of a
stream:

=contlisting Regex.pm

        sub precat {
          my ($s, $c) = @_;
          transform {"$c$_[0]"} $s;
        }

        sub postcat {
          my ($s, $c) = @_;
          transform {"$_[0]$c"} $s;
        }

=endlisting Regex.pm

=note currying here would have allowed
        *precat = transform {"$_[0]$c"};
and thus less notation

An example:

        # I'm /^(a|b)(c|d)$/
        my $z = concat(union(literal("a"), literal("b")),
                       union(literal("c"), literal("d")),
                      );
        show($z);
*       ac bc ad bd

=test regex-concat 1

        use Regex qw(concat union literal);                
        use STDOUT;
        require 'unordered-union.pl';
        use Stream 'show';

        my $z = concat(union(literal("a"), literal("b")),
                       union(literal("c"), literal("d")),
                      );
        show($z);
        is($OUTPUT, "ac bc ad bd \n");

=endtest

Now that we have F<concat>, the C<*> operator is trivial, because of
this simple identity:

        s* = "" | ss*

That is, M<s*> is either the empty string or else something that
matches V<s> followed by something else that matches M<s*>.  We want
to generate M<s*>; let's call this result V<r>.  Then

        r = "" | sr

Now we can use the wonderful recursive definition capability of
streams:

=contlisting Regex.pm

        sub star {
          my $s = shift;
          my $r;
          $r = node("", promise { concat($s, $r) });
        }

=endlisting Regex.pm

=startpicture regex-star

        ILLUSTRATION TO COME

=endpicture regex-star

C<$r>, the result, will be equal to the C<*> of C<$s>.  It begins with
the empty string, and the rest of C<$r> is formed by concatenating
something in C<$s> with C<$r> itself.

        # I'm /^(:\))*$/
        show(star(literal(':)')), 6)
*        :) :):) :):):) :):):):) :):):):):)

=test regex-star

        use Regex 'star', 'literal';
        use Stream 'show';
        require 'unordered-union.pl';
        use STDOUT;

        # I'm /^(:\))*$/
        show(star(literal(':)')), 6);
        is($OUTPUT, " :) :):) :):):) :):):):) :):):):):) \n");

=endtest 

The empty string is hiding at the beginning of that output line.  Let's
use a modified version of F<show> to make it visible:

=contlisting Regex.pm

        sub show {
          my ($s, $n) = @_;
          while ($s && (! defined $n || $n-- > 0)) {
*           print qq{"}, drop($s), qq{"\n};
          }
*         print "\n";
        }

=endlisting Regex.pm


Now the output is:

        ""
        ":)"
        ":):)"
        ":):):)"
        ":):):):)"
        ":):):):):)"

=test regex-star-altshow 1

        use Regex qw(star literal show);
        use STDOUT;

        # I'm /^(:\))*$/
        show(star(literal(':)')), 6);
        my @smiles = map ":)" x $_, 0..5;
        my @lines = map qq{"$_"\n}, @smiles;
        is($OUTPUT, join("", @lines) . "\n");

=endtest 

We can throw in a couple of extra utilities if we like:

=contlisting Regex.pm

        # charclass('abc') = /^[abc]$/
        sub charclass {
          my ($s, $class) = @_;
          union(map literal($_), split(//, $class));
        }

        # plus($s) = /^s+$/
        sub plus {
          my $s = shift;
          concat($s, star($s));
        }

        1;

=endlisting Regex.pm

And now a demonstration:

        use Regex qw(concat star literal show);

        # I represent /^ab*$/
        my $regex1 = concat(     literal("a"),
                            star(literal("b"))
                           );
        show($regex1, 10);

The output:

        "a"
        "ab"
        "abb"
        "abbb"
        "abbbb"
        "abbbbb"
        "abbbbbb"
        "abbbbbbb"
        "abbbbbbbb"
        "abbbbbbbbb"

=test regex-abbb 1

        use Regex qw(concat star literal show);
        require 'unordered-union.pl';
        use STDOUT;

        # I represent /^ab*$/
        my $regex1 = concat(     literal("a"),
                            star(literal("b"))
                           );
        show($regex1, 10);
        my @b = map "b"x$_, 0..9;
        my @str = map qq{"a$_"\n}, @b;
        is($OUTPUT, join("", @str)."\n");

=endtest


Let's try something a little more interesting:

        # I represent /^(aa|b)*$/
        my $regex2 = star(union(literal("aa"),
                                literal("b"),
                               ));
        show($regex2, 16);

The output:

        ""
        "aa"
        "b"
        "aaaa"
        "baa"
        "aab"
        "bb"
        "aaaaaa"
        "baaaa"
        "aabaa"
        "bbaa"
        "aaaab"
        "baab"
        "aabb"
        "bbb"
        "aaaaaaaa"
        ...

=test regex-a-or-bb 1

        use Regex qw(concat star literal show union);
        require 'unordered-union.pl';
        use STDOUT;

        # I represent /^(aa|b)*$/
        my $regex2 = star(union(literal("aa"),
                                literal("b"),
                               ));
        show($regex2, 16);

        my $target = qq{""\n"aa"\n"b"\n"aaaa"\n"baa"\n"aab"\n"bb"\n"aaaaaa"\n"baaaa"\n"aabaa"\n"bbaa"\n"aaaab"\n"baab"\n"aabb"\n"bbb"\n"aaaaaaaa"\n\n};
        my $len = length($target);
        is(substr($OUTPUT, 0, $len), $target);

=endtest


One last example:

        # I represent /^(ab+|c)*$/
        my $regex3 = star(union(concat(     literal("a"),
                                       plus(literal("b"))),
                                literal("c")
                               ));
        show($regex3, 20);


=test regex-ab-plus-or-c 1

        use Regex qw(concat plus star literal show);
        require 'unordered-union.pl';
        use STDOUT;

        # I represent /^(ab+|c)*$/
        my $regex3 = star(union(concat(     literal("a"),
                                       plus(literal("b"))),
                                literal("c")
                               ));
        show($regex3, 20);

        $target = qq{""\n"ab"\n"c"\n"abab"\n"cab"\n"abb"\n"abc"\n"abbab"\n"abbb"\n"ababab"\n"cc"\n"abbbb"\n"abcab"\n"abbc"\n"abbbbb"\n"ababb"\n"abbbab"\n"abbbbbb"\n"ababc"\n"cabab"\n\n};

        my $len = length($target);
        is(substr($OUTPUT, 0, $len), $target);

=endtest

Output:

        ""
        "ab"
        "c"
        "abab"
        "cab"
        "abb"
        "abc"
        "abbab"
        "abbb"
        "ababab"
        "cc"
        "abbbb"
        "abcab"
        "abbc"
        "abbbbb"
        "ababb"
        "abbbab"
        "abbbbbb"
        "ababc"
        "cabab"
        ...

=subsection Generating strings in order

It's hard to be sure, from looking at this last output, that it really
is generating all the strings that will match C</^(ab+|c)*/>.  Will
C<cccc> really show up?  Where's C<cabb>?  We might prefer the strings
to come out in some order, say in order by length.  It happens that
this is also rather easy to do.  Let's say that a stream of strings is
"ordered" if no string comes out after a longer string has come out,
and see what will be necessary to generate ordered streams.

The streams produced by F<literal> only contain one string, so those
streams are already ordered, because one item can't be
disordered.N<Perhaps I should have included a longer explanation of
this point, since I seem to be the only person in the world who is
bothered by the phrase "Your call will be answered in the order
it was received."  It always seems to me that my call could not
have an order.>  F<concat>, it turns out, is already generating its
elements in order as best it can.  The business end is:

          my ($s, $t) = (head($S), head($T));

          node("$s$t", promise {
            union( precat(tail($T), $s),
                  postcat(tail($S), $t),
                  concat(tail($S), tail($T)),
                 )
          });

Let's suppose that the inputs, C<$S> and C<$T>, are already ordered.
In that case, C<$s> is one of the shortest elements of C<$S> 
and C<$t> is one of the shortest elements of C<$T>.  C<$s$t> therefore
can't be any longer than any other concatenation of elements from
C<$S> and C<$T>, so it's all right that it will come out first.
As long as the output of the F<union> call is ordered, the output of
F<concat> will be too.

=note show union *before* the other functions; that way it'll look
more magical

F<union> does need some rewriting.  It presently cycles through its
input streams in sequence.  We need to modify it to find the input
stream whose head element is shortest and to process that stream
first.

=contlisting Regex.pm

        sub union {
          my (@s) = grep $_, @_;
          return unless @s;
          return $s[0] if @s == 1;
          my $si = index_of_shortest(@s);
          node(head($s[$si]),
                      promise {
                        union(map $_ == $si ? tail($s[$_]) : $s[$_], 
                                  0 .. $#s);
                      });
        }

The first two C<return>s correspond to the early C<return>s in the
original version of F<union>, handling the special cases of zero or
one argument streams.  If there's more than one argument stream, we
call F<index_of_shortest>, which will examine the heads of the streams
to find the shortest string.  F<index_of_shortest> returns C<$si>, the
index number of the stream with the shortest head string.  We pull off
this string and put it first in the output, then call F<union>
recursively to process the remaining data.  F<index_of_shortest> is
quite ordinary:

        sub index_of_shortest {
          my @s = @_;
          my $minlen = length(head($s[0]));
          my $si = 0;
          for (1 .. $#s) {
            my $h = head($s[$_]);
            if (length($h) < $minlen) {
              $minlen = length($h);
              $si = $_;
            }
          }
          $si;
        }

=endlisting Regex.pm

The last function to take care of is F<star>.  But F<star>, it turns
out, has taken care of itself:

        sub star {
          my $s = shift;
          my $r;
          $r = node("", promise { concat($s, $r) });
        }

The empty string, which comes out first, is certainly no longer than
any other element in C<$r>'s output.  And since we already know that
C<concat> produces an ordered stream, we're finished.

That last example again:

        # I represent /^(ab+|c)*$/
        my $regex3 = star(union(concat(     literal("a"),
                                       plus(literal("b"))),
                                literal("c")
                               ));
        $regex3->show(30);

=test regex-ab-plus-or-c-ordered 1

        use Regex qw(concat star literal show union plus);
        use STDOUT;

        # I represent /^(ab+|c)*$/
        my $regex3 = star(union(concat(     literal("a"),
                                       plus(literal("b"))),
                                literal("c")
                               ));
        show($regex3, 30);

        $target=qq{""\n"c"\n"ab"\n"cc"\n"abb"\n"cab"\n"ccc"\n"abc"\n"abbb"\n"cabb"\n"ccab"\n"cccc"\n"cabc"\n"abbc"\n"abab"\n"abcc"\n"abbbb"\n"cabbb"\n"ccabb"\n"cccab"\n"ccccc"\n"ccabc"\n"cabbc"\n"cabab"\n"cabcc"\n"abbbc"\n"ababb"\n"abcab"\n"abccc"\n"ababc"\n\n};

        my $len = length($target);
        is(substr($OUTPUT, 0, $len), $target);

=endtest

And the now-sorted output:

        ""
        "c"
        "ab"
        "cc"
        "abb"
        "cab"
        "ccc"
        "abc"
        "abbb"
        "cabb"
        "ccab"
        "cccc"
        "cabc"
        "abbc"
        "abab"
        "abcc"
        "abbbb"
        "cabbb"
        "ccabb"
        "cccab"
        "ccccc"
        "ccabc"
        "cabbc"
        "cabab"
        "cabcc"
        "abbbc"
        "ababb"
        "abcab"
        "abccc"
        "ababc"
        ...

Aha, C<cccc> and C<cabb> I<were> produced, after all.

=subsection Regex Matching

At this point we've built a system that can serve as a regex engine:
given a regex and a target string, it can decide whether the string
matches the regex.  A regex is a representation of a set of strings
which supports operations like concatenation, union, and closure.  Our
regex-string-streams fit the bill.  Here's a regex matching engine:

=contlisting Regex.pm

        sub matches {
          my ($string, $regex) = @_;
          while ($regex) {
            my $s = drop($regex);
            return 1 if $s eq $string;
            return 0 if length($s) > length($string);
          }
          return 0;
        }

=endlisting Regex.pm

The C<$regex> argument here is one of our regex streams.  (After we
attach the parser from R<parser|chapter>, we'll be able to pass in a
regex in standard Perl notation instead.)  We look at the shortest
string matched by the regex; if it's the target string, then we have a
match.  If it's longer than the target string, then the match fails,
because every other string in the regex is also too long.  Otherwise,
we throw away the head and repeat with the next string.  If the regex
runs out of strings, the match fails.

This is just an example; it should be emphasized that, in general,
streams are I<not> a good way to do regex matching.  To determine
whether a string matches C</^[ab]*$/>, this method generates all
possible strings of C<a>'s and C<b>'s and checks each one to see if it
is the target string.  This is obviously a silly way to do it.  The
amount of time it takes is exponential in the length of the target
string; an obviously better algorithm is to scan the target string
left to right, checking each character to make sure it is an C<a> or a
C<b>, which requires only linear time.  X<stupid-sort|i>

Nevertheless, in some ways this implementation of regex matching is
actually I<more> powerful than Perl's built-in matcher.  For example,
there's no convenient way to ask Perl if a string contains a balanced
arrangement of parentheses.  (Starting in 5.005, you can use the
C<(?{...})> operator, but it's
nasty.N<C</^(?{local$d=0})(?:\((?{$d++})|\)(?{$d--})(?(?{$d\<0})(?!))|(?\>[^()]*))*(?(?{$d!=0})(?!))$/>>)
But our 'regexes' are just lists of strings, and the lists can contain
whatever we want.  If we want a 'regex' that represents balanced
arrangements of parentheses, all we need to do is to construct a
stream that contains the strings we want.

Let's say that we would like to match strings of C<a>, C<(>, and C<)>
in which the parentheses are balanced.  That is, we'd like to match
the following strings:

        ""
        "a"
        "aa"
        "()"
        "aaa"
        "a()"
        "()a"
        "(a)"
        "aaaa"
        "aa()"
        "a()a"
        "()aa"
        "a(a)"
        "(a)a"
        "(aa)"
        "()()"
        "(())"
        "aaaaa"
        ...

Suppose V<s> is a regex that matches the expressions that are legal
between parentheses.  Then a sequence of these expressions with
properly-balanced parentheses is one of the following:

=bulletedlist

=item the empty string, or

=item something that matches V<s>, or

=item C<(>I<b>C<)>, where I<b> is some balanced string, or

=item a balanced string followed by one of the above

=endbulletedlist

Then we can almost read off the definition:

=contlisting Regex.pm

        sub bal {
          my $contents = shift;
          my $bal;
          $bal = node("", promise {
            concat($bal,
                   union($contents,
                         transform {"($_[0])"} $bal,
                        )
                  )
               });
        }

=endlisting Regex.pm

=test regex-bal 200

        my $Ntests = 100;

        use Regex;
        use Stream 'drop';

        sub is_balanced {
          my @chars = split //, shift();
          my $d = 0;
          for (@chars) {
            if ($_ eq "(") {
              $d++;
            } elsif ($_ eq ")") {
              $d--;
              return if $d < 0;
            } 
          }
          return $d == 0;
        }

        my $bal = Regex::bal(Regex::literal("a"));
        for (1..$Ntests) {
          die unless $bal;
          my $s = drop($bal);
          unlike($s, qr/[^a()]/, "element '$s' character check");
          ok(is_balanced($s), "'$s' balanced");
        }        

=endtest


And now the question "Does C<$s> contain a balanced sequence of
parentheses, C<a>'s, and C<b>'s" is answered by:

        if (match($s, bal(charclass('ab')))) {
          ...
        }

=subsection Cutsorting

The regex string generator suggests another problem which sometimes
comes up.  It presently generates strings in order by length, but
strings of the same length come out in no particular order, as in the
column on the left.  Suppose we want the strings of the same length to
come out in sorted order, as in the column on the right?

        ""                              ""     
        "c"                             "c"    
        "ab"                            "ab"   
        "cc"                            "cc"   
        "abb"                           "abb"  
        "cab"                           "abc"  
        "ccc"                           "cab"  
        "abc"                           "ccc"  
        "abbb"                          "abab" 
        "cabb"                          "abbb" 
        "ccab"                          "abbc" 
        "cccc"                          "abcc" 
        "cabc"                          "cabb" 
        "abbc"                          "cabc" 
        "abab"                          "ccab" 
        "abcc"                          "cccc" 
        "abbbb"                         "ababb"
        "cabbb"                         "ababc"
        "ccabb"                         "abbab"
        "cccab"                         "abbbb"
        "ccccc"                         "abbbc"
        "ccabc"                         "abbcc"
        "cabbc"                         "abcab"
        "cabab"                         "abccc"
        "cabcc"                         "cabab"
        "abbbc"                         "cabbb"
        "ababb"                         "cabbc"
        "abcab"                         "cabcc"
        "abccc"                         "ccabb"
        "ababc"                         "ccabc"
        "abbab"                         "cccab"
        "abbcc"                         "ccccc"
        ...                             ...

We should note first that although it's reasonable to ask for the
strings sorted into groups by length and then lexicographically within
each group, it's I<not> reasonable to ask for I<all> the strings to be
sorted lexicographically.  This is for two reasons.  First, even if we
could do it, the result wouldn't be useful:

        ""
        "ab"
        "abab"
        "ababab"
        "abababab"
        "ababababab"
        "abababababab"
        ...

None of the strings that contains C<c> would ever appear, because
there would always be some other string that was lexicographically
earlier that we had not yet emitted.  But the second reason is that in
general it's not possible to sort an infinite stream at all.  In this
example, the first string to be emitted is clearly the empty string.
The second string out should be C<"ab">.  But the sorting process
can't know that.  It can't emit the C<"ab"> unless it's sure that no
other string would come between C<""> and C<"ab">.  It doesn't know
that the one-billionth string in the input won't be C<"a">.  So it can
never emit the C<"ab">, because no matter how long it waits to do so,
there's always a possibility that C<"a"> will be right around the
corner.

But if we know in advance that the input stream will be sorted by
string length, and that there will be only a finite number of strings
of each length, then we certainly can sort each group of strings of
the same length.

In general, the problem with sorting is that, given some string we
want to emit, we don't know whether it's safe to emit it without
examining the entire rest of the stream, which might be infinite.  But
suppose we could supply a function which would say whether or not it
was safe.  If the input stream is already sorted by length, then at
the moment we see the first length=3 string in the input, we know it's
safe to emit all the length=2 strings that we've seen already; the
function could tell us this.  The function effectively 'cuts' the
stream off, saying that enough of the input has been examined to
determine the next part of the output, and that the cut-off part of
the input doesn't matter yet.

This idea is the basis of X<cutsorting|d>.  The cutting function will
get two arguments: the element we would like to emit, which should be
the smallest one we have seen so far, and the current element of the
input stream.  The cutting function will return true if we have seen
enough of the input stream to be sure that it's safe to emit the
element we want to, and false if the rest of the input stream might
contain an element that precedes the one we want the function to emit.

For sorting by length, the cutting function is trivial:

        sub cut_bylen {
          my ($a, $b) = @_;
          # It's OK to emit item $a if the next item in the stream is $b
          length($a) < length($b);
        }

Since the cutsorter may need to emit several items at a time, we'll
build a utility function for doing that:

=contlisting Stream.pm

        sub list_to_stream {
          my $node = pop;
          while (@_) {
            $node = node(pop, $node);
          }
          $node;
        }

C<list_to_stream(h1, h2, ... t)> returns a stream that starts with
C<h1>, C<h2>, ... and whose final tail is C<t>.  C<t> may be another
(possibly empty) stream or a promise.  C<list_to_stream(h, t)>  is
equivalent to C<node(h, t)>.

The cutsorting function gets four arguments: C<$s>, the stream to sort,
C<$cmp>, the sorting comparator (analogous to the X<comparator> function
of F<sort>), and C<$cut>, the cutting test.  It also gets an auxiliary
argument C<@pending> that we'll see in a moment:

        sub insert (\@$$);

        sub cutsort {
          my ($s, $cmp, $cut, @pending) = @_;
          my @emit;

          while ($s) {
            while (@pending && $cut->($pending[0], head($s))) {
              push @emit, shift @pending;
            }

            if (@emit) {
              return list_to_stream(@emit, 
                                    promise { cutsort($s, $cmp, $cut, @pending) });
            } else {
              insert(@pending, head($s), $cmp);
              $s = tail($s);
            }
          }

          return list_to_stream(@pending, undef);
        }

=endlisting Stream.pm

The idea of the cutsorter is to scan through the input stream,
maintaining a buffer of items that have been seen so far but not yet
emitted; this is C<@pending>.  C<@pending> is kept in sorted order, so
that if any element is ready to come out, it will be C<$pending[0]>.
The C<while(@pending...)> loop checks to see if any elements can be
emitted; if so, the emittable elements are transferred to C<@emit>.  If
there are any such elements, they are emitted immediately: F<cutsort>
returns a stream that begins with these elements and which ends with a
promise to cutsort the remaining elements of C<$s>.  Any unemitted
elements of C<@pending> are passed along in the promise to be emitted
later.

If no elements are ready for emission, the function discards the head
element of the stream after inserting it into C<@pending>.  F<insert>
takes care of inserting C<head($s)> into the appropriate place in
C<@pending> so that C<@pending> is always properly sorted.

If C<$s> is exhausted, all items in C<@pending> immediately become
emittable, so the function calls F<list_to_stream> to build a finite
stream that contains them and then ends with an empty tail.

Now if we'd like to generate strings in sorted order, we call F<cutsort>
like this:

        my $sorted = 
          cutsort($regex3,
                  sub { $_[0] cmp $_[1] },  # comparator
                  \&cut_bylen               # cutting function
                  );

=test sorted-regex 1

        use Stream 'cutsort';
        use Regex qw(concat star literal show union plus);
        use STDOUT;

        # I represent /^(ab+|c)*$/
        my $regex3 = star(union(concat(     literal("a"),
                                       plus(literal("b"))),
                                literal("c")
                               ));
        sub cut_bylen {
          my ($a, $b) = @_;
          # It's OK to emit item $a if the next item in the stream is $b
          length($a) < length($b);
        }

        my $sorted = 
          cutsort($regex3,
                  sub { $_[0] cmp $_[1] },  # comparator
                  \&cut_bylen               # cutting function
                  );

        show($sorted, 30);

        $target = qq{""\n"c"\n"ab"\n"cc"\n"abb"\n"abc"\n"cab"\n"ccc"\n"abab"\n"abbb"\n"abbc"\n"abcc"\n"cabb"\n"cabc"\n"ccab"\n"cccc"\n"ababb"\n"ababc"\n"abbab"\n"abbbb"\n"abbbc"\n"abbcc"\n"abcab"\n"abccc"\n"cabab"\n"cabbb"\n"cabbc"\n"cabcc"\n"ccabb"\n"ccabc"\n\n};

        my $len = length($target);
        is(substr($OUTPUT, 0, $len), $target);

=endtest


The one piece of this that we haven't seen is F<insert>, which inserts
an element into the appropriate place in a sorted array:

=contlisting Stream.pm

        sub insert (\@$$) {
          my ($a, $e, $cmp) = @_;
          my ($lo, $hi) = (0, scalar(@$a));
          while ($lo < $hi) {
            my $med = int(($lo + $hi) / 2);
            my $d = $cmp->($a->[$med], $e);
            if ($d <= 0) {
              $lo = $med+1;
            } else {
              $hi = $med;
            }
          }
          splice(@$a, $lo, 0, $e);
        }

=endlisting Stream.pm

X<prototypes|examples of|i>
This is straightforward, except possibly for the prototype.  The
I<prototype> C<(\@$$)> says that F<insert> will be called with three
arguments: an array and two scalars, and that it will be passed a
reference to the array argument instead of a list of its elements.  It
then performs a binary search on the array C<@$a>, looking for the
appropriate place to splice in the new element C<$e>.  A linear scan
is simpler to write and to understand than the binary search, but it's
not efficient enough for heavy-duty use.  

At all times, C<$lo> and C<$hi> record the indices of elements of
C<@$a> that are known to satisfy C<$a-\>[$lo] \<= $e \< $a-\>[$hi]>,
where C<\<=> here represents the comparision defined by the C<$cmp>
function.  Each time through the C<while> loop, we compare C<$e> to
the element of the array at the position halfway in between C<$lo> and
C<$hi>; depending on the outcome of the comparison, we now know a new
element C<$a-\>[$med]> with C<$a-\>[$med] \<= $e> or with C<$e \<
$a-\>[$med]>.  We can then replace either C<$hi> or C<$lo> with
C<$med> while still preserving the condition C<$a-\>[$lo] \<= $e \<
$a-\>[$hi]>.  When C<$lo> and C<$hi> are the same, we've located the
correct position for C<$e> in the array, and we use F<splice> to
insert it in the appropriate place.  For further discussion of binary
search, see X<Mastering Algorithms with Perl|I>, pp. 162--165.

=subsubsection Log Files

For a more practical example of the usefulness of cutsorting, consider
a program to process a mail log file.  The popular X<C<qmail>> mail system
generates a log in the following format:

        @400000003e382910351ebf4c new msg 706430
        @400000003e3829103573e42c info msg 706430: bytes 2737 from <boehm5@email.com> qp 31064 uid 1001
        @400000003e38291035d359ac starting delivery 190552: msg 706430 to local guitar-tpj-regex@plover.com
        @400000003e38291035d3cedc status: local 1/5 remote 2/10
        @400000003e3829113084e7f4 delivery 190552: success: did_0+1+0/qp_31067/
        @400000003e38291130aa3aa4 status: local 1/5 remote 2/10
        @400000003e3829120762c51c end msg 706430

The first field in each line is a time stamp in I<X<tai64n>> format.
The rest of the line describes what the mail system is doing.  C<new
msg> indicates that a new message has been added to one of the
delivery queues and includes the ID number of the new message.  C<info
msg> records the sender of the new message.  (A message always has
exactly one sender, but may have any number of recipients.)
C<starting delivery> indicates that a delivery attempt is being
started, the address of the intended recipient, and a unique delivery
ID number.  C<delivery> indicates the outcome of the delivery attempt,
which may be a successful delivery, or a temporary or permanent
failure, and includes the delivery ID number.  C<end msg> indicates
that delivery attempts to all the recipients of a message have ended
in success or permanent failure, and that the message is being removed
from the delivery queue.  C<status> lines indicate the total number of
deliveries currently in progress.

This log format is complete and not too difficult to process, but it
is difficult for humans to read quickly.  We might like to generate
summary reports in different formats; for example, we might like to
reduce the life of the previous message to a single line:

        706430 29/Jan/2003:14:18:30 29/Jan/2003:14:18:32 <boehm5@email.com> 1 1 0 0 

This records the message ID number, the times at which the message was
inserted into and removed from the queue, the sender, the total number
of delivery attempts, and the number of attempts that were
respectively successful, permanent failures, and temporary failures.

X<C<qmail>> writes its logs to a file called C<current>; when
C<current> gets sufficiently large, it is renamed and a new C<current>
file is started.  We'll build a stream that follows the C<current>
file, notices when a new C<current> is started, and switches files
when necessary.  First we need a way to detect when a file's identity
has changed.  On Unix systems, a file's identity is captured by two
numbers: the device number of the device on which it resides, and an
X<i-number|d> which is a per-device identification number.  Both
numbers can be obtained with the Perl F<stat> function:

=startlisting logfile-process

        sub _devino {
          my $f = shift;
          my ($dev, $ino) = stat($f);
          return unless defined $dev;
          "$dev;$ino";
        } 

The next function takes a filename, an open filehandle, and a device
and i-number pair and returns the next record from the filehandle.  If
the handle is at the end of its file, the function checks to see if
the filename now refers to a different file.  If so, the function
opens the handle to the new file and continues; otherwise it waits and
tries again:

        sub _next_record {
          while (1) {
            my ($fh, $filename, $devino, $wait) = @_;
            $wait = 1 unless defined $wait;
            my $rec = <$fh>;
            return $rec if defined $rec;
            if (_devino($filename) eq $devino) {
              # File has not moved
              sleep $wait;
            } else {
              # $filename refers to a different file
              open $_[0], "<", $filename or return;
              $_[2] = _devino($_[0]);
            }
          }
        }

Note that if C<$fh> and C<$devino> are initially unspecified,
C<_next_record> will initialize them when it is first called.

The next function takes a filename and returns a stream of records
from the file, using C<_next_record> to follow the file if it is replaced:

=note this implementation produces a bogus undef at the beginning of
the stream.  You may be able to fix this by tinkering with
iterate_function.  Or you can simply replace iterate_function() with
tail(iterate_function()). 

        sub follow_file {
          my $filename = shift;
          my ($devino, $fh);
          tail(iterate_function(sub { _next_record($fh, $filename, $devino) }));
        }
 
        my $raw_mail_log = follow_file('/service/qmail/log/main/current');


Now we can write functions to transform this stream.  For example, a
quick-and-dirty function to convert X<tai64n> format timestamps to
X<Unix epoch format> is:

        sub tai64n_to_unix_time {
          my $rec = shift;
          return [undef, $rec] unless s/^\@([a-f0-9]{24})\s+//;
          [hex(substr($1, 8, 8)) + 10, $rec];
        }

=note the + 10 is actually correct here.  The unix epoch occurred at
@400000000000000a.

        my $mail_log = &transform(\&tai64n_to_unix_time, $raw_mail_log);

Next is the function to analyze the log.  Its input is a stream of log
records from which the timestamps have been preprocessed by
F<tai64n_to_unix_time>, and its output is a stream of hashes, each of
which represents a single email message.  The function gets two
auxiliary arguments, C<$msg> and C<$del>, which are hashes that
represent the current state of the delivery queue.  The keys of
C<$del> are delivery ID numbers; each value is the ID number of the
message with which a delivery is associated.  The keys of C<$msg> are
message ID numbers; the values are structures that record information
about the corresponding message, including the time it was placed in
the queue, the sender, the total number of delivery attempts, and
other information.  A complete message structure looks like this:


=endlisting logfile-process

    {   
       'id' => 706430,         # Message ID number
       'bytes' => 2737,        # Message length
       'from' => '<boehm5@email.com>',  # Sender
       'deliveries' => [190552], # List of associated delivery IDs

       'start' => 1043867776,  # Start time
       'end' => 1043867778,    # End time

       'success' => 1,         # Number of successful delivery attempts
       'failure' => 0,         # Number of permanently failed delivery attempts
       'deferral' => 0,        # Number of temporarily failed delivery attempts
       'total_deliveries' => 1,# Total number of delivery attempts
    }

The stream produced by F<digest_maillog> is a sequence of these
structures.  To produce a structure, F<digest_maillog> scans the input
records, adjusting C<$msg> and C<$del> as necessary, until it sees an
C<end msg> line; at that point it knows that it has complete
information about a message, and it emits a single data item
representing that message.  If the input stream is exhausted,
F<digest_maillog> terminates the output:

=contlisting logfile-process

        sub digest_maillog {
          my ($s, $msg, $del) = @_;
          for ($msg, $del) { $_ = {} unless $_ }
          while ($s) {
            my ($date, $rec) = @{drop($s)};

            next unless defined $date;
            if ($rec =~ /^new msg (\d+)/) {
              $msg->{$1} = {start => $date, id => $1,
                           success => 0, failure => 0, deferral => 0};

            } elsif ($rec =~ /^info msg (\d+): bytes (\d+) from (<[^\>]*>)/) {
              next unless exists $msg->{$1};
              $msg->{$1}{bytes} = $2;
              $msg->{$1}{from} = $3;

            } elsif ($rec =~ /^starting delivery (\d+): msg (\d+)/) {
              next unless exists $msg->{$2};
              $del->{$1} = $2;
              push @{$msg->{$2}{deliveries}}, $1;

            } elsif ($rec =~ /^delivery (\d+): (success|failure|deferral)/) {
              next unless exists $del->{$1} && exists $msg->{$del->{$1}};
              $msg->{$del->{$1}}{$2}++;

            } elsif ($rec =~ /^end msg (\d+)/) {
              next unless exists $msg->{$1};
              my $m = delete $msg->{$1};
              $m->{total_deliveries} = @{$m->{deliveries}};
              for (qw(success failure deferral)) { $m->{$_} += 0 }
              for (@{$m->{deliveries}}) { delete $del->{$_} };
              $m->{end} = $date;
              return node($m, promise { digest_maillog($s, $msg, $del) });
            }
          }
          return;
        }


Now we can generate reports by transforming the stream of message
structures into a stream of log records:

        use POSIX 'strftime';

        sub format_digest {
          my $h = shift;
          join " ", 
            $h->{id},
            strftime("%d/%b/%Y:%T", localtime($h->{start})),
            strftime("%d/%b/%Y:%T", localtime($h->{end})),
            $h->{from},
            $h->{total_deliveries},
            $h->{success},
            $h->{failure},
            $h->{deferral},
              ;
        }

        show(&transform(\&format_digest, digest_maillog($mail_log)));

=endlisting logfile-process

=note need a better test here, I think

=test logfile-process-compiles 1

        system("perl -c Programs/logfile-process 2>&1 > /dev/null");
        is($?, 0);

=endtest 

Typical output looks like this:

        ...
        707045 28/Jan/2003:12:10:03 28/Jan/2003:12:10:03 <Paulmc@371.net> 1 1 0 0
        707293 28/Jan/2003:12:10:03 28/Jan/2003:12:10:06 <Paulmc@371.net> 1 1 0 0
        707045 28/Jan/2003:12:10:06 28/Jan/2003:12:10:07 <Paulmc@371.net> 4 3 1 0
        707293 28/Jan/2003:12:10:07 28/Jan/2003:12:10:07 <guido@odiug.zope.com> 1 1 0 0
        707670 28/Jan/2003:12:10:06 28/Jan/2003:12:10:08 <spam-return-133409-@plover.com-@[]> 2 2 0 0
        707045 28/Jan/2003:12:10:07 28/Jan/2003:12:10:11 <guido@odiug.zope.com> 1 1 0 0
        707293 28/Jan/2003:12:10:11 28/Jan/2003:12:10:11 <guido@odiug.zope.com> 1 1 0 0
        707045 28/Jan/2003:12:10:22 28/Jan/2003:12:10:23 <ezmlm-return-10817-mjd-ezmlm=plover.com@list.cr.yp.to> 1 1 0 0
        707045 28/Jan/2003:12:11:02 28/Jan/2003:12:11:02 <perl5-porters-return-71265-mjd-p5p2=plover.com@perl.org> 1 1 0 0
        707503 24/Jan/2003:11:29:49 28/Jan/2003:12:11:35 <perl-qotw-discuss-return-1200-@plover.com-@[]> 388 322 2 64
        707045 28/Jan/2003:12:11:35 28/Jan/2003:12:11:45 <> 1 1 0 0
        707293 28/Jan/2003:12:11:41 28/Jan/2003:12:11:46 <perl6-internals-return-14784-mjd-perl6-internals=plover.com@perl.org> 1 1 0 0
        ...

That was all a lot of work, and at this point it's probably not clear
why the stream method has any advantage over the more usual method of
reading the file one record at a time, tracking the same data
structures, and printing output records as we go, something like this:

        while (<LOG>) {
          # analyze current record
          # update $msg and $del
          if (/^end msg/) {
            print ...;
          }
        }

One advantage was that we could encapsulate the the
follow-the-changing-file behavior inside its own stream.  In a more
conventionally-structured program, the logic to track the moving file
would probably have been threaded throughout the rest of the program.
But we could also have accomplished this encapsulation by using a tied
filehandle.

A bigger advantage of the stream approach comes if we want to reorder
the output records.  As written, the output stream contains message
records in the order in which the messages were removed from the
queue; that is, the output is sorted by the third field.  Suppose we
want to see the messages sorted by the second field, the time at which
each message was first sent?  In the example output above, notice the
line for message 707503.  Although the time at which it was removed
from the queue (12:11:25 on 28 January) is in line with the
surrounding messages, the time it was sent (11:29:49 on 24 January) is
quite different.  Most messages are delivered almost immediately, but
this one took more than four days to complete.  It represents a
message that was sent to a mailing list with 324 subscribers.  Two of
the subscribers had full mailboxes, causing their mail systems to
temporararily refuse new message for these subscribers.  After four
days, the mail system finally gave up and removed the message from the
queue.  Similarly, message 707670 arrived a second earlier but was
delivered (to India) a second later than message 707293, which was
delivered (locally) immediately after it arrived.

The ordinary procedural loop provides no good way to emit the log
entries sorted in order by the date the messages were sent rather then
by the date that delivery was completed.  We can't simply use Perl's
F<sort> function, since it works only on arrays, and we can't put the
records into an array, because they extend into the indefinite future.

But in the stream-based solution, we can order the records with the
cutsorting method, using the prefabricated cutsorting function we have
already.  There's an upper bound on how long messages can remain in
the delivery queue; after 4 days any temporary delivery failures are
demoted to permanent failures, and the message bounces.  Suppose we
have in hand the record for a message that was first queued on January
1 and that has been completely delivered.  We can't emit it
immediately, since the next item out of the stream might be the record
for a message that was first queued on December 28 whose delivery
didn't complete until January 2; this record should come out before
the January 1 record because we're trying to sort the output by the
start date rather than the end date.  But we can tell the cutsorter
that it's safe to emit the January 1 record once we see a January 5
record in the stream, because by January 5 any messages queued before
January 1 will have been delivered one way or another.

        my $QUEUE_LIFETIME = 4;      # Days
        my $by_entry_date = 
          cutsort($mail_log,
                  sub { $_[0]{start} <=> $_[1]{start} },
                  sub { $_[1]{end} - $_[0]{end} >= $QUEUE_LIFETIME*86400 },
                 );

The first anonymous function argument to F<cutsort> says how to order
the elements of the output; we want them ordered by C<{start}>, the
date each message was placed into the queue.  The second anonymous
function argument is the cutting function; this function says that
it's safe to emit a record V<R> with a certain start date if the next
record in the stream was for a message that was completed at least
C<$QUEUE_LIFETIME> days after V<R> was; any record that was queued
before V<R> would have to be removed less than C<$QUEUE_LIFETIME> days
later, and therefore there are no such records remaining in the
stream.  The output from C<$by_entry_date> includes the records in the
sample above, but in a different order:

        ...
        707503 24/Jan/2003:11:29:49 28/Jan/2003:12:11:35 <perl-qotw-discuss-return-1200-@plover.com-@[]> 388 322 2 64

        ... (many records omitted) ...

        707045 28/Jan/2003:12:10:03 28/Jan/2003:12:10:03 <Paulmc@371.net> 1 1 0 0
        707293 28/Jan/2003:12:10:03 28/Jan/2003:12:10:06 <Paulmc@371.net> 1 1 0 0
        707045 28/Jan/2003:12:10:06 28/Jan/2003:12:10:07 <Paulmc@371.net> 4 3 1 0
        707670 28/Jan/2003:12:10:06 28/Jan/2003:12:10:08 <spam-return-133409-@plover.com-@[]> 2 2 0 0
        707293 28/Jan/2003:12:10:07 28/Jan/2003:12:10:07 <guido@odiug.zope.com> 1 1 0 0
        707045 28/Jan/2003:12:10:07 28/Jan/2003:12:10:11 <guido@odiug.zope.com> 1 1 0 0
        ...

Even on a finite segment of the log file, cutsorting offers advantages
over a regular sort.  To use regular sort, the program must first read
the entire log file into memory.  With cutsorting, the program can
begin producing output after only C<$QUEUE_LIFETIME> days worth of
records have been read in.

=note keen idea: sort by sender, cutting after 24 hours.  It's
impossible to sort by sender globally (because you might get a message
from Alan Abernathy Aardvark <aaaardvark@aaaa.com> next year.  But
with this cutting regime you get blocks of at least 24 hours in length
in which the froms are alphabetized.

=note OK, this didn't work at all.  We keep coming up with <>
addresses whose dates are later and later in the file; unless a day 
goes by with no <> senders, we'll never have any output at all.

=section The Newton-Raphson Method

How does Perl's F<sqrt> function work?  It probably uses some
variation of the X<Newton-Raphson method|d>.  You may have spent a lot
of time toiling in high school to solve equations; if so, rejoice,
because the Newton-Raphson method is a general technique for solving
any equation whatever.  N<Isaac Newton discovered and wrote about the
method first, but his writeup wasn't published until 1736.  Joseph
Raphson discovered the technique independently and published it in
1671.>

Suppose we're trying to calculate C<sqrt(2)>.  This is a number,
which, when multiplied by itself, will give 2.  That is, it's a number
V<x> such that M<x^2 = 2>, or, equivalently, such that M<x^2 - 2 = 0>.

If you plot the graph of M<y = x^2 - 2> you get a parabola:

=startpicture parabola

  ._
  ``'?""""""""'""""""""'"""""""`"""""""":""""""""'""""""""'""""""""'"""""""T
     %    `                             -                             `    |
     ?     :                            :                            `     |
     %      .                           .                           .'     |
   q.?.     .                           -                           .      {
     )       .                          :                          .       |
     ?        .                         .                         .        |
     ?        .                         -                         .        |
   . )         .                        :                        .         |
   `'?'         .                       .                       .          T
     ?          .                       -                       .          |
     )           .                      :                                  |
     ?            .                     .                     .'           |
   ~ $.            .                    -                    .             {
     ?              .                   :                                  |
     )               .                  .                   -              |
     ?                                  -                  -               |
   ,.?.               '                 :                 -                J
   " %                 '                .                -                 |
     %                  '               -               -                  |
     |                   '              :              -                   |
     %                    -             .             .                    |
   d->---------------------------------------------------------------------|
     :                                  :          -                       |
     :                        `         .        .                         |
     :                          `       -                                  |
  _, $________\________\_______,____:__.:.___:___\________\________\_______J
   ".,,      _,.      _o      ..,       o.       \       ,,       .,       ,.
              `        `        '       `        '        '        '


=endpicture parabola


Every point on the parabola has M<x^2 - 2 = y>.  Points on the V<x>
axis have M<y = 0>.  Where the parabola crosses the V<x> axis, we have
M<x^2 - 2 = 0>, and so the V<x> coordinate of the crossing point is
equal to M<sqrt(2)>.  This value is the solution, or I<root>, of the
equation.  X<root of equation|di>X<zero of polynomial|i>

The Newton-Raphson method takes an approximation to the root and
produces a closer approximation.  We get the method started by
guessing a root.  Techniques for making a good first guess are an
entire field of study themselves, but for the parabola above, any
guess except 0 will work.  To show that the initial guess doesn't have
to be particularly good, we'll guess that M<sqrt(2) = 2>.  The method
works by observing that a smooth curve, such as the parabola, can be
approximated by a straight line, and constructs the tangent line to
the curve at the current guess, which is M<x=2>.  This is the straight
line that touches the curve at that point, and which proceeds in the
same direction that the curve was going.  The curve will veer away
from the straight line (because it's a curve) and eventually intersect
the V<x> axis in a different place than the straight line does.  But
if the curve is reasonably well-behaved, it won't veer away too much,
so the line's intersection point will be close to the curve's
intersection point, and closer than the original guess was.

=note you need a picture here
 
The tangent line in this case happens to be the line M<y = 4x - 6>.
This line intersects the V<x> axis at M<x = 1.5>.  This value, 1.5, is
our new guess for the value of M<sqrt(2)>.  It is indeed more accurate
than the original guess.

To get a better approximation, we repeat the process.  The
tangent line to the parabola at the point (1.5, 0.25) has the equation
M<y = 3x - 4.25>.  This line intersects the V<x> axis at M<x =
1.41667>, which is correct to two decimal places.

Now we'll see how these calculations were done.  Let's suppose our
initial guess is V<g>, so we want to construct the tangent at M<(g,
g^2-2)>.  If a line has slope V<m> and passes through the point M<(p,
q)>, its equation is M<y - q = m(x - p)>.  We'll see later how to
figure out the slope of the tangent line without calculus, but in the
meantime calculus tells us that the slope of the tangent line to the
parabola at the point M<(g, g^2-2)> is M<2g>, and therefore that
the tangent line itself has the equation M<(y - (g^2-2)) = 2g(x - g)>.
We want to find the value of V<x> for which this line intersects the
V<x>-axis; that is, we want to find the value of V<x> for which V<y>
is 0.  This gives us the equation M<(0 - (g^2-2)) = 2g(x - g)>.
Solving for V<x> yields M<x = g - (g^2-2)/2g = (g^2 + 2)/2g>.  That
is, if our initial guess is V<g>, a better guess will be M<(g^2 +
2)/2g>.  A function which computes M<sqrt(2)> is therefore

=startlisting Newton.pm

        sub sqrt2 {
          my $g = 2;   # Initial guess
          until (close_enough($g*$g, 2)) {
            $g = ($g*$g + 2) / (2*$g);
          }
          $g;
        }

        sub close_enough {
          my ($a, $b) = @_;
          return abs($a - $b) < 1e-12;
        }

This code rapidly produces a good approximation to M<sqrt(2)>,
returning 1.414213562373095 after only 5 iterations.  (This is correct
to 15 decimal places.)  To calculate the square root of a different
number, we do the mathematics the same way, this time replacing the 2
with a variable V<n>; the result is:

        sub sqrtn {
          my $n = shift;
          my $g = $n;   # Initial guess
          until (close_enough($g*$g, $n)) {
            $g = ($g*$g + $n) / (2*$g);
          }
          $g;
        }

=endlisting Newton.pm

=test sqrt 21

        use Newton;
        my $s2 = sqrt2();
        ok(close_enough($s2, sqrt(2)), "sqrt(2) = sqrt2()");

        for (1 .. 20) {
          ok(close_enough(sqrtn($_), sqrt($_)), "sqrt($_) = sqrtn($_)");
        }

=endtest

=subsection Approximation Streams

But what does all this have to do with streams?  One of the most
useful and interesting uses for streams is to represent the results of
an approximate calculation.  Consider the following stream definition,
which delivers the same sequence of approximations that the F<sqrtn>
function above would compute:

=contlisting Newton.pm

        use Stream 'iterate_function';

        sub sqrt_stream {
          my $n = shift;
          iterate_function (sub { my $g = shift;
                                 ($g*$g + $n) / (2*$g);
                                },
                            $n);
        }

        1;

=endlisting Newton.pm

=test sqrt-stream

        use Newton;
        use Stream 'drop', 'head';
        my $s = sqrt_stream(2);
        drop($s) for 1..19;
        ok(close_enough(head($s), sqrt(2)), "20th element is close");

=endtest

We saw F<iterate_function> back in R<iterate_function|subsection>.
At the time, I promised a simpler and more interesting version.  Here
it is:

=contlisting Stream.pm

        sub iterate_function {
          my ($f, $x) = @_;
          my $s;         
          $s = node($x, promise { &transform($f, $s) });
        }

=endlisting Stream.pm

Recall that C<iterate_function($f, $x)> produces the stream C<$x,
$f-\>($x), $f-\>($f-\>($x)), ...>.  The recursive version above
relies on the observation that the stream begins with C<$x>, and the
rest of the stream can be gotten by applying the function C<$f> to
each element in turn.  The C<&> on the call to F<transform> disables
F<transform>'s prototype-derived special synatax.  Without it, we'd
have to write

        transform { $f->($_[0]) } $s

which would introduce an unnecessary additional function call.

=note Now show how to use the square root in something else that can
generate a stream of results.  Maybe the pendulum period formula?  
P = 2pi*sqrt(L/g).  Or perhaps the well-known quadratic solution.


=note also a version that delivers an error bound, which is nothing
more than the difference between the current and previous guesses.
(Double check the math on this.)
        

=subsection Derivatives

The problem with the Newton-Raphson method as I described it in the
previous section is that it requires someone to calculate the slope of
the tangent line to the curve at any point.  When we needed the slope
at any point of the parabola M<g^2 - 2>, I magically pulled out the
formula M<2g>.  The function M<2g> that describes the slope at the
tangent line at any point of the parabola M<g^2 - 2> is called the
X<derivative function|d> of the parabola; in general, for any
function, the related function that describes the slope is called the
derivative.  Algebraic computation of derivative functions is the
subject of the branch of mathematics called X<differential calculus>.

Fortunately, though, you don't need to know differential calculus to
apply the Newton-Raphson method.  There's an easy way to compute the
slope of a curve at any point.  What we really want is the slope of
the tangent line at a certain point.  But if we pick two points that
are close to the point we want, and compute the slope of the line
between them, it won't be too different from the slope of the actual
tangent line.  

For example, suppose we want to find the slope of the parabola M<y =
x^2 - 2> at the point (2, 2).  We'll pick two points close to that and
find the slope of the line that passes through them.  Say we choose
(2.001, 2.004001) and (1.999, 1.996001).  The slope of the line
through two points is the V<y> difference divided by the V<x>
difference; in this case, 0.008/0.002 = 4.  And this does match the
answer from calculus exactly.  It won't always be an exact match, but
it'll always be close, because differential calculus uses exactly the
same strategy, augmented with algebraic techniques to analyze what
happens to the slope as the two points get closer and closer together.

It's not hard to write code which, given a function, calculates the
slope at any point:

=contlisting Newton.pm

        sub slope {
          my ($f, $x) = @_;
          my $e = 0.00000095367431640625;
          ($f->($x+$e) - $f->($x-$e)) / (2*$e);
        }

=endlisting Newton.pm

=test slope 10

        use Newton;

        for (1..10) { 
          my $s = slope(sub { $_[0] * $_[0] - 2 }, $_);
          ok(close_enough($s, 2*$_), "Slope at $_");
        }

=endtest

=note I read somewhere this has unstable behavior, but it seems to
work fine.  What's the problem?

The value of C<$e> I chose above is exactly M<2^-20>; I picked it
because it was the power of 2 closest to one one-millionth.  Powers of
2 work better than powers of 10 because they can be represented
exactly; with a power of 10 you're introducing round-off error before
you even begin.  Smaller values of C<$e> will give us more accurate
answers, up to a point.  The computer's floating-point numbers have
only a fixed amount of accuracy, and as the numbers we deal with get
smaller, the round-off error will tend to dominate the answer.  For
the function C<$f = sub { $_[0] * $_[0] - 2 }> and C<$x = 2> the
F<slope> function above produces the correct answer (4) for values of
C<$e> down to M<2^-52>; at that point the round-off error takes over,
and when C<$e> is M<2^-54>, the calculated slope is 0 instead of 4.
It's not hard to see what has happened: C<$e> has become so small that
when it's added to or subtracted from C<$x>, and the result is rounded
off to the computer's precision, the C<$e> disappears entirely and
we're left with exactly 2.  So the calculated values of
C<$f-\>($x+$e)> and C<$f-\>($x-$e)> are both exactly the same, and the
F<slope> function returns 0.

=note this is a great example of how hard it can be to understand the
behavior of floating-point numbers.  It *looks* like a smaller value
of $e will yield a more accurate result, and it does, up to a point;
past this point everything goes haywire.  Other examples: (a+b)+c !=
a+(b+c).  e=2^-20 above works better than e=10^-6 or 10^-7.

Once we have this F<slope> function, it's easy to write a generic
equation solver using the Newton-Raphson method:

=contlisting Newton.pm

        # Return a stream of numbers $x that make $f->($x) close to 0
        sub solve {
          my $f = shift;
          my $guess = shift || 1;
          iterate_function(sub { my $g = shift;
                                 $g - $f->($g)/slope($f, $g);
                               },
                           $guess);
        }

=endlisting Newton.pm

Now if we want to find M<sqrt(2)>, we do:

        my $sqrt2 = solve(sub { $_[0] * $_[0] - 2 });

        { local $" = "\n";
          show($sqrt2, 10);
        }

=test solve 1

        use Newton;
        use Stream 'drop', 'head';
        my $sqrt2 = solve(sub { $_[0] * $_[0] - 2 });
        drop($sqrt2) for 1..9;
        ok(close_enough(head($sqrt2), sqrt(2)), "solve for sqrt(2)");        

=endtest


This produces the following output:

        1
        1.5
        1.41666666666667
        1.41421568627464
        1.41421356237469
        1.4142135623731
        1.41421356237309
        1.4142135623731
        1.41421356237309
        1.4142135623731

At this point the round-off error in the calculations has caused the
values to alternate between 1.41421356237309 and
1.4142135623731.N<Actually they're alternating between
1.414213562373094923430016933708 and 1.414213562373095145474621858739,
but who's counting?> The correct value is 1.41421356237309504880, so
our little bit of code has produced an answer that is accurate to
better than four parts per quadrillion.

If we want more accurate answers, we can use the standard Perl
multi-precision floating-point library, X<C<Math::BigFloat>>.  Doing so
requires only a little change to the code:

*       use Math::BigFloat;

        my $sqrt2 = solve(sub { $_[0] * $_[0] - 2 },
*                       Math::BigFloat->new(2));

=note move infectiousness discussion up here

Doing this produces extremely accurate answers, but after only a few
iterations, the numbers start coming out more and more slowly.
Because C<Math::BigFloat> I<never> rounds off, every multiplication of
two numbers produces a number twice as long.  The results increase in
size exponentially, and so do the calculation times.  The third
iteration produces 1.41666666666666666666666666666666666666667, which
is an extremely precise but rather inaccurate answer.  There's no
point in retaining or calculating with all the 6'es at the end,
because we know they're wrong, but C<Math::BigFloat> does it anyway,
and the fourth iteration produces a result that has five accurate
digits followed by 80 inaccurate digits.

One solution to this is to do more mathematics to produce an estimate
of how many digits are accurate, and to round off the approximations
to leave only the correct digits for later calculations.  But this
requires sophisticated technique.  A simple solution is to improve the
initial guess.  Since Perl has a built-in square root function which
is fast, we'll use that to generate our initial guess, which will
already be accurate to about thirteen decimal places.  Any work done
by C<Math::BigFloat> afterwards will only improve this.

        my $sqrt2 = solve(sub { $_[0] * $_[0] - 2 },
*                       Math::BigFloat->new(sqrt(2)));


The approximations still double in size at every step, and each one
still takes twice as long as the previous one, but many more of the
digits are correct, so the extra time spent isn't being wasted as it
was before.  You may wait twice as long to get the answer, but you get
an answer that has twice as many correct digits.  The second element
of the stream is
1.4142135623730950488016887242183652153338124600441037, of which the
first 28 digits after the decimal point are correct.  The next element
has 58 correct digits.  In general, the Newton-Raphson method will
double the number of correct digits at every step, so if you start
with a reasonably good guess, you can get extremely accurate results
very quickly.

=note Another (better) solution to this is the decimal number streams
you cut out.  There you get only the precision that you need for the
final result.

=note lots of opportunities for currying in this section.  Slope is
one; scale is another.

=subsection The Tortoise and the Hare

The C<$sqrt2> stream we built in the previous section is infinite, but
after a certain point the approximations it produces won't get any more
accurate because they'll be absorbed by the inherent error in the
computer's floating-point numbers.  The output of C<$sqrt2> was:

        1
        1.5
        1.41666666666667
        1.41421568627464
        1.41421356237469
        1.4142135623731
        1.41421356237309
        1.4142135623731
        1.41421356237309
        ...

C<$sqrt2> is stuck in a loop.  A process that was trying to use
C<$sqrt2> might decide that it needs more than 13 places of precision,
and might search further and further down the stream, hoping for a
better approximation that never arrives.  It would be better if we could
detect the loop in C<$sqrt2> and cut off its tail.  

The obvious way to detect a loop is to record every number that comes
out of the stream and compare it to the items that came out before; if
there is a repeat, then cut off the tail:

        sub cut_loops {
          my $s = shift;
          return unless $s;
          my @previous_values = @_;
          for (@previous_values) {
            if (head($s) == $_) {
              return;
            }
          }
          node(head($s), 
               promise { cut_loops(tail($s), head($s), @previous_values) });
        }

C<cut_loops($s)> constructs a stream which is the same as C<$s>, but
which stops at the point where the first loop begins.  Unfortunately,
it does this with a large time and memory cost.  If the argument
stream doesn't loop, the C<@previous_values> array will get bigger and
bigger and take longer and longer to search.  There is a better
method, sometimes called the X<tortoise and hare algorithm|d>.

Imagine that each value in the stream is connected to the next value by
an arrow.  If the values form a loop, the arrows will also.  Now imagine
that a tortoise and a hare both start at the first value and proceed
along the arrows.  The tortoise crawls from one value to the next,
following the arrows, but the hare travels twice as fast, leaping over
every other value.  If there is a loop, the hare will speed around the
loop and catch up to the tortoise from behind.  When this happens, you
know that the hare has gone all the way around the loop once.N<It may
not be obvious that the hare will necessarily catch the tortoise, but it
is true.  For details, see Knuth I<The Art of Computer Programming>:
Volume 2, I<Seminumerical Algorithms>, exercise 3.1.6.>  If there is no
loop, the hare will vanish into the distance and will never meet the
tortoise again.

=contlisting Stream.pm

        sub cut_loops {
          my ($tortoise, $hare) = @_;
          return unless $tortoise;

          # The hare and tortoise start at the same place
          $hare = $tortoise unless defined $hare;

          # The hare moves two steps every time the tortoise moves one
          $hare = tail(tail($hare));

          # If the hare and the tortoise are in the same place, cut the loop
          return if head($tortoise) == head($hare);

          return node(head($tortoise), 
                      promise { cut_loops(tail($tortoise), $hare) });
        }

=endlisting Stream.pm


=test cut-loops 6

        use Newton;
        my $sqrt2 = solve(sub { $_[0] * $_[0] - 2 });
        use Stream 'cut_loops', 'drop', 'iterate_function', 'node';
        my $z  = cut_loops($sqrt2);
        my $zz = Stream::cut_loops2($sqrt2);

        while ($n < 50 && $z) {
          $n++; drop($z);
        }
        ok(!$z, "sqrt(2) stream was cut");

        while ($nn < 50 && $zz) {
          $nn++; drop($zz);
        }
        ok(!$zz, "sqrt(2) stream was cut again");

        ok($nn >= $n, "cutloops2 cuts no earlier than cutloops ($nn > $n)");

        my $n = iterate_function(sub { 
          my $a = shift;
          $a % 2 ? 3*$a+1 : $a/2 
        }, 27);
        # Stream::show($n, 200);
        my $n1 = cut_loops($n);
        my $n2 = Stream::cut_loops2($n);

        while ($c1 < 200 && $n1) {
          $c1++; drop($n1);
        }
        ok(!$n1, "n1 stream was cut");

        while ($c2 < 200 && $n2) {
          $c2++; drop($n2);
        }
        ok(!$n2, "n2 stream was cut");
        ok($c2 >= $c1, "cutloops2 cuts no earlier than cutloops ($c2 > $c1)");

=endtest

C<show(cut_loops($sqrt2))> now generates

        1
        1.5
        1.41666666666667
        1.41421568627464
        1.41421356237469
        1.4142135623731 

and nothing else.

Notice that the entire loop didn't appear in the output.  The loop
consists of 

        1.4142135623731
        1.41421356237309

but we saw only the first of these.  The tortoise and hare algorithm
guarantees to cut the stream somewhere in the loop, I<before> the values
start to repeat; it might therefore place the cut sometime before all of
the values in the loop have appeared.  Sometimes this is acceptable
behavior.  If not, send the hare around the loop an extra time:

=contlisting Stream.pm

        sub cut_loops2 {
*         my ($tortoise, $hare, $n) = @_;
          return unless $tortoise;
          $hare = $tortoise unless defined $hare;

          $hare = tail(tail($hare));
          return if head($tortoise) == head($hare)
*                   && $n++;
          return node(head($tortoise), 
                      promise { cut_loops(tail($tortoise), $hare, $n) });
        }


=endlisting Stream.pm


=subsection Finance

The square root of two is beloved by the mathematics geeks, but normal
humans are motivated by other things, such as money.  Let's suppose I
am paying off a loan, say a mortgage.  Initially I owe V<P> dollars.
(V<P> is for "principal", which is the finance geeks' jargon word for
it.)  Each month, I pay V<pmt> dollars, of which some goes to pay the
interest and some goes to reduce the principal.  When the principal
reaches zero, I own the house.

For concreteness, let's say that the principal is $100,000, the
interest rate is 6% per year, or 0.5% per month, and the monthly
payment is $1,000.  At the end of the first month, I've racked up $500
in interest, so my $1,000 payment reduces the principal to $99,500.
At the end of the second month, the interest is a little lower, only
$99,500 M<\times> 0.5% = $495.50, so my payment reduces the principal
by $504.50, to $98,995.50.  Each month, my progress is a little
faster.  How long will it take me to pay off the mortgage at this
rate?

First let's figure out how to calculate the amount owed at the end of
any month.  The first two months are easy:

        Month           Amount owed

        0               P

In the first month, we pay interest on the principal in the amount of
M<P * .005>, bringing the total to M<P * 1.005>.  But we also make a
payment of V<pmt> dollars, so that at the end of month 1, the amount
owed is:

        1               P * 1.005 - pmt

The next month, we pay interest on the amount still owed.
That amount is M<P * 1.005 - pmt>, so the interest is
M<(P * 1.005 - pmt) * .005>, and the total is
M<(P * 1.005 - pmt) + (P * 1.005 - pmt) * .005>, or
M<(P * (1.005)^2 - pmt * 1.005>.  Then we make another payment,
bringing the total down to:

        2               P * (1.005)^2 - pmt(1 + 1.005)

The pattern continues in the third month:

        3               P * (1.005)^3 - pmt(1 + 1.005 + (1.005)^2)

        4               P * (1.005)^4 - pmt(1 + 1.005 + (1.005)^2 + (1.005)^3)


This pattern is simple enough that we can program it without much
trouble:

        sub owed {
          my ($P, $N, $pmt, $i) = @_;
          my $payment_factor = 0;
          for (0 .. $N-1) {     
            $payment_factor += (1+$i) ** $_;
          }
          return $P * (1+$i)**$N - $pmt * $payment_factor;
        }
          
It requires a little high school algebra to abbreviate the formula.
N<It also requires a bit of a trick.  Say 
V<S> = 1 + V<k> + M<k^2> + ... + M<k^(n-1)>.  
Multiplying both sides by V<k> gives 
M<Sk> =    V<k> + M<k^2> + ... + M<k^(n-1)> + M<k^n>.
These two equations are almost the same, and if we subtract one from
the other almost everything cancels out, leaving only 
M<Sk - k> = M<k^n - 1> and so 
     V<S> = M<(k^n - 1)/(k - 1)>.>
M<1 + 1.005 + (1.005)^2 + ... + (1.005)^(N+1)> is equal to M<(1.005^N
- 1)/ .005>, which is quicker to calculate.

        4               P * (1.005)^4 - pmt((1.005)^4 - 1)/0.005

        5               P * (1.005)^5 - pmt((1.005)^5 - 1)/0.005

        6               P * (1.005)^6 - pmt((1.005)^6 - 1)/0.005

so the code gets simpler:

=startlisting owed

        sub owed {
          my ($P, $N, $pmt, $i) = @_;
          return $P * (1+$i)**$N - $pmt * ((1+$i)**$N - 1) / $i;
         }

=endlisting owed

Now, the question that everyone with a mortgage wants answered: how
long before my house is paid off?

We could try solving the equation C<$P * (1+$i)**$N - $pmt *
((1+$i)**$N - 1) / $i> for C<$N>, but doing that requires a lot of
mathematical sophistication, much more than coming up with the formula
in the first place.N<I'm afraid I am out of tricks.> It's much easier
to hand the F<owed> function to F<solve> and let it find the answer:

        sub owed_after_n_months {
          my $N = shift;
          owed(100_000, $N, 1_000, 0.005);
        }

        my $stream = cut_loops(solve(\&owed_after_n_months));
        my $n;
        $n = drop($stream) while $stream;
        print "You will be paid off in only $n months!\n";

According to this, we'll be paid off in 138.9757 months, or 11 and a
half years.  This is plausible, since if there were no interest we
would clearly have the loan paid off in exactly 100 months.  Indeed,
after the 138th payment, the principal remains at $970.93, and a
partial payment the following month finishes off the mortgage.

But we can ask more interesting questions.  I want a thirty-year
mortgage, and I can afford to pay $1,300 per month, or $15,600 per
year.  The bank is offering a 6.75% annual interest rate.  How large a
mortgage can I afford?

        sub affordable_mortgage {
          my $mortgage = shift;
          owed($mortgage, 30, 15_600, 0.0675);
        }
        my $stream = cut_loops(solve(\&affordable_mortgage));
        my $n;
        $n = drop($stream) while $stream;
        print "You can afford a \$$n mortgage.\n";

Apparently with a $1,300 payment I can pay off any mortgage up to
$198,543.62 in 30 years.

=test owed

        use Newton;
        use Stream 'cut_loops', 'drop';
        do "owed";
        sub owed_after_n_months {
          my $N = shift;
          owed(100_000, $N, 1_000, 0.005);
        }

        my $x = cut_loops(solve(\&owed_after_n_months, 100));

        my $N;        
        while ($x) {
          $N = drop($x);
          print "# $N\n";
        }
        is(int($N), 138);

        sub affordable_mortgage {
          my $mortgage = shift;
          owed($mortgage, 30, 15_600, 0.0675);
        }
        my $stream = cut_loops(solve(\&affordable_mortgage));
        my $n;
        $n = drop($stream) while $stream;
        print "# $n\n";
        cmp_ok(abs(owed($n, 30, 15_600, 0.0675)), "<", 0.0001);

=endtest owed


X<Seven percent solution|i>

=section Power Series

We've seen that the Newton-Raphson method can be used to evaluate the
F<sqrt> function.  What about other built-in functions, such as F<sin>
and F<cos>?

The Newton-Raphson method won't work here.  To evaluate something like
C<sqrt(2)>, we needed to find a number V<x> with M<x^2 = 2>.  Then we
used the Newton-Raphson method, which required only simple arithmetic
to approximate a solution.  To evaluate something like C<sin(2)>, we
would need to find a number V<x> with M<asin(x) = 2>.  This is at
least as difficult as the original problem.  M<x^2> is easy to
compute; M<asin(x)> isn't.

=note explain 'transcendental functions'?

To compute values of the so-called 'X<transcendental functions>' like
F<sin> and F<cos>, the computer uses another strategy called 
X<power series expansion|d>.N<These series are often called X<I<Taylor series>>
or X<I<Maclaurin series>> after English mathematicians Brook Taylor
X<Taylor, Brook|i> and Colin Maclaurin X<Maclaurin, Colin|i> who
popularized them.  The general technique for constructing these series
was discovered much earlier by several people, including James Gregory
X<Gregory, James|i> and Johann Bernoulli X<Bernoulli, Johann|i>.>

A X<power series|d> is an expression of the form

    a_0 + a_1 x + a_2 x^2 + a_3 x^3 + ...

for some numbers M<a_0>, M<a_1>, M<a_2> , ... .  Many common functions
can be expressed as power series, and in particular, it turns out that
for all V<x>, M<sin(x) = x - x^3/3! + x^5/5! - x^7/7! + ...>.  (Here
M<a_0 = 0>, M<a_1 = 1>, M<a_2 = 0>, M<a_3 = -1/3!>, etc.)  The formula
is most accurate for V<x> close to 0, but if you carry it out to
enough terms, it works for any V<x> at all.  The terms themselves get
small rather quickly in this case, because the factorial function in
the denominator increases more rapidly than the power of V<x> in the
numerator, particularly for small V<x>.  For example, M<0.1 - 0.1^3/3!
+ 0.1^5/5!  - 0.1^7/7!> is .09983341664682539683; the value of
M<sin(0.1)> is .09983341664682B<815230>.  When the computer wants to
calculate the sine of some number, it plugs the number into the power
series above and calculates an approximation.  The code to do this is
simple:

=startlisting sine

        # Approximate sin(x) using the first n terms of the power series
        sub approx_sin {
          my $n = shift;
          my $x = shift;
          my ($denom, $c, $num, $total) = (1, 1, $x, 0);
          while ($n--) {
            $total += $num / $denom;
            $num *= $x*$x * -1;
            $denom *= ($c+1) * ($c+2);
            $c += 2;
          }
          $total;
        }

        1;

=endlisting sine

=auxtest close-enough.pl

        sub close_enough {
          my ($a, $b, $e) = @_;
          $e ||= 1e-12;
          abs($a-$b) < $e;
        }

=endtest

=test sine 12

        require 'close-enough.pl';
        require 'sine';
        my $pi = 3.141592654;
        for (1..12) {
          my $as = approx_sin(20, $pi*$_/6);
          my $s = sin($pi*$_/6);
          ok(close_enough($s, $as), "approx sine is close for $_/6 pi");
        }
        
=endtest

At each step, C<$num> holds the numerator of the current term and
C<$denom> holds the denominator.  This is so simple that it's even
easy in assembly language.

=note displayed equation for cos(x) and sin(x)

Similarly, M<cos(x) = 1 - x^2/2! + x^4/4! - x^6/6! + ...>.

Streams seem almost tailor-made for power series computations, because
the power series itself is infinite, and with a stream representation
we can look at as many terms as are necessary to get the accuracy we
want.  Once the terms become sufficiently small, we know that the rest
of the stream won't make a significant contribution to the
result.N<This shouldn't be obvious, since there are an infinite
number of terms in the rest of the stream, and in general the infinite
tail of a stream may make a significant contribution to the total.
However, in a power series, the additional terms I<do> get small so
quickly that they can be disregarded, at least for sufficiently small
values of V<x>.  For details, consult a textbook on numerical analysis
or basic calculus.>

We could build a C<sin> function which, given a numeric argument, used
the power series expansion to produce approximations to M<sin(x)>.
But we can do better: we can use a stream to represent the entire
power series itself, and then manipulate it as a single unit.

We will represent the power series M<a_0 + a_1x + a_2x^2 + ...> with a
stream that contains (M<a_0>, M<a_1>, M<a_2>, ...).  With this
interpretation, we can build a function that evaluates a power series
for a particular argument by substituting the argument into the series
in place of V<x>.

Since the V<n>th terms of these power series depend in simple ways on
V<n> itself, we'll make a small utility function to generate such
series:

=startlisting PowSeries.pm

        package PowSeries;
        use base 'Exporter';
        @EXPORT_OK = qw(add2 mul2 partial_sums powers_of term_values
                        evaluate derivative multiply recip divide
                        $sin $cos $exp $log_ $tan);
        use Stream ':all';

        sub tabulate {
          my $f = shift;
          &transform($f, upfrom(0));
        }

Given a function V<f>, this produces the infinite stream M<f(0),
f(1), f(2), ...>.  Now we can define F<sin> and F<cos>:

        my @fact = (1);
        sub factorial {
          my $n = shift;
          return $fact[$n] if defined $fact[$n];
          $fact[$n] = $n * factorial($n-1);
        }


        $sin = tabulate(sub { my $N = shift;
                              return 0 if $N % 2 == 0;
                              my $sign = int($N/2) % 2 ? -1 : 1;
                              $sign/factorial($N) 
                            });


        $cos = tabulate(sub { my $N = shift;
                              return 0 if $N % 2 != 0;
                              my $sign = int($N/2) % 2 ? -1 : 1;
                              $sign/factorial($N) 
                           });

=endlisting PowSeries.pm

=test powseries-sin-cos 13

        use PowSeries qw($sin $cos);
        require 'close-enough.pl';
        use Stream 'drop';
        my @sin = (0, 1, 0, -1/6, 0, 1/120, 0,);
        my @cos = (1, 0, -1/2, 0, 1/24, 0);

        my $N = 0;
        while (@sin) {
          my $a = drop($sin); 
          my $b = shift(@sin);
          ok(close_enough($a, $b), "sin coeff $N: ($a <=> $b)");
          $N++;
        }

        my $N = 0;
        while (@cos) {
          my $a = drop($cos); 
          my $b = shift(@cos);
          ok(close_enough($a, $b), "cos coeff $N: ($a <=> $b)");
          $N++;
        }

=endtest

C<$sin> is now a stream which begins (0, 1, 0, -0.16667, 0, 0.00833,
0, ...); C<$cos> begins (1, 0, -0.5, 0, 0.0416666666666667, ...).

Before we evaluate these functions, we'll build a few utilities for
performing arithmetic on power series.  First is F<add2>, which adds
the elements of two streams together element-by-element:

=contlisting PowSeries.pm

        sub add2 {
          my ($s, $t) = @_;
          return unless $s && $t;
          node(head($s) + head($t),
               promise { add2(tail($s), tail($t)) });
        }


C<add2($s, $t)> corresponds to the addition of two power series.
(Multiplication of power series is more complicated, as we will see
later.)  Similarly, C<scale($s, $c)>, which we've seen before,
corresponds to the multiplication of the power series C<$s> by the
constant C<$c>.

F<mul2>, which multiplies streams element-by-element, is similar to F<add2>:


        sub mul2 {
          my ($s, $t) = @_;
          return unless $s && $t;
          node(head($s) * head($t),
               promise { mul2(tail($s), tail($t)) });
        }


We will also need a utility function for summing up a series.  Given a
stream (M<a_0>, M<a_1>, M<a_2>, ...), it should produce the stream
(M<a_0>, M<a_0+a_1>, M<a_0+a_1+a_2>, ...) of successive partial sums
of elements of the first stream.  This function is similar to several
others we've already defined :

        sub partial_sums {
          my $s = shift;
          my $r;
          $r = node(head($s), promise { add2($r, tail($s)) });
        }

One of the eventual goals of all this machinery is to compute sines
and cosines.  To do that, we will need to evaluate the partial sums of
a power series for a particular value of V<x>.    This function takes
a number V<x> and produces the stream (1, V<x>, M<x^2>, M<x^3>, ...):

        sub powers_of {
          my $x = shift;
          iterate_function(sub {$_[0] * $x}, 1);
        }

When we multiply this stream elementwise by the stream of coefficients
that represents a power series, the result is a stream of the terms of
the power series evaluated at a point V<x>:

        sub term_values {
          my ($s, $x) = @_;
          mul2($s, powers_of($x));
        }

Given a power series stream C<$s> = (M<a_0>, M<a_1>, M<a_2>, ...), and
a value C<$x>, F<term_values> produces the stream (M<a_0>, M<a_1x>,
M<a_2x^2>, ...).  

Finally, F<evaluate> takes a function, as represented by a power
series, and evaluates it at a particular value of V<x>:

        sub evaluate {
          my ($s, $x) = @_;
          partial_sums(term_values($s, $x));
        }

=endlisting PowSeries.pm

And lo and behold, all our work pays off:

        my $pi = 3.1415926535897932;
        show(evaluate($cos, $pi/6), 20);

=test powseries-evaluate 12

        use PowSeries 'evaluate', '$cos';
        use Stream 'drop', 'head';
        require 'close-enough.pl';
        my $pi = 3.1415926535897932;
        for (1..12) {
          my $c = evaluate($cos, $pi*$_/6);
          drop($c) for 1..50;
          my $h = head($c);
          my $cv = cos($pi*$_/6);
          ok(close_enough($h, $cv), "$_ pi/6 => $h <=> $cv");
        }

=endtest

produces the following approximations to M<cos(pi/6)>:

        1
        1
        0.862922161095981
        0.862922161095981
        0.866053883415747
        0.866053883415747
        0.866025264100571
        0.866025264100571
        0.866025404210352
        0.866025404210352 
        0.866025403783554
        0.866025403783554
        0.866025403784440
        0.866025403784440
        0.866025403784439
        0.866025403784439
        0.866025403784439
        0.866025403784439
        0.866025403784439
        0.866025403784439 

This is correct.  (The answer happens to be exactly M<sqrt(3)/2>.)

We can even work it in reverse to calculate M<pi>:

=contlisting PowSeries.pm

        # Get the n'th term from a stream
        sub nth {
          my $s = shift;
          my $n = shift;
          return $n == 0 ? head($s) : nth(tail($s), $n-1);
        }

        # Calculate the approximate cosine of x
        sub cosine {
          my $x = shift;
          nth(evaluate($cos, $x), 20);
        }

If we know that M<cos(pi/6) = sqrt(3)/2>, then to find M<pi> we need
only solve the equation M<cos(x/6) = sqrt(3)/2>, or equivalently, 
M<cos(x/6) * cos(x/6) = 3/4>:

        sub is_zero_when_x_is_pi {
          my $x = shift;
          my $c = cosine($x/6);
          $c * $c - 3/4;
        }

=endlisting PowSeries.pm

        show(solve(\&is_zero_when_x_is_pi), 20);

=test powseries-pi 1

        use PowSeries;
        use Newton 'solve';
        use Stream 'drop', 'head';
        require 'close-enough.pl';
        my $z = solve(\&PowSeries::is_zero_when_x_is_pi);
        drop($z) for 1..20;
        my $pi1 = head($z);
        my $pi2 = atan2(0, -1);
        ok(close_enough($pi1, $pi2), "calculate pi ($pi1, $pi2)");

=endtest

And the output from this is

        1
        5.07974473179368
        3.19922525384188
        3.14190177620487
        3.14159266278343
        3.14159265358979
        3.14159265358979
        ...

which is correct.  (The initial guess of 1, you will recall, is the
default for F<solve>.  Had we explicitly specified a better guess, such
as 3, the process would have converged more quickly; had we specified a
much larger guess, like 10, the results would have converged to a
different solution, such as M<11pi>.)

=subsection Derivatives

We used F<slope> above to calculate the slope of the curve M<cos(x/6) *
cos(x/6) - 3/4> at various points; recall that F<slope> calculates an
approximation of the slope by picking two points close together on the
curve and calculating the slope of the line between them.  If we had
known the derivative function of M<cos(x/6) * cos(x/6) - 3/4>, we could
have plugged it in directly.  But calculating a derivative function
requires differential calculus.

However, if you know a power series for a function, calculating its
derivative is trivial.  If the power series for the function is
M<a_0 + a_1x + a_2x^2 + ...>, the power series for the derivative is
M<a_1 + 2*a_2x + 3*a_3x^2 + ...>. That is, it's simply:

=contlisting PowSeries.pm

        sub derivative {
          my $s = shift;
          mul2(upfrom(1), tail($s));
        }

=endlisting PowSeries.pm

If we do

        show(derivative($sin), 20);

we get exactly the same output as for

        show($cos, 20);

demonstrating that the cosine function is the derivative of the sine
function.

=test powseries-deriv

        use PowSeries 'derivative', '$sin', '$cos';
        use Stream 'head', 'drop';
        require 'close-enough.pl';
        my $sd = derivative($sin);
        for (0..19) {
          ok(close_enough(drop($cos), drop($sd)), "term $_");
        }

=endtest

=subsection Other functions

Many other common functions can be calculated with the power series
method.  For example, Perl's built-in F<exp> function is

=contlisting PowSeries.pm

        $exp = tabulate(sub { my $N = shift; 1/factorial($N) });

=endlisting PowSeries.pm

=test powseries-exp

        use PowSeries '$exp', 'evaluate';
        require 'close-enough.pl';
        my $e = PowSeries::nth(evaluate($exp, 1), 20);
        ok(close_enough($e, exp(1)), "calculate e ($e)");

=endtest

The X<hyperbolic functions> F<sinh> and F<cosh> are like F<sin>
and F<cos> except without the extra C<$sign> factor in the terms.
Perl's built-in F<log> function is almost:

=contlisting PowSeries.pm

        $log_ = tabulate(sub { my $N = shift; 
                               $N==0 ? 0 : (-1)**$N/-$N });

=endlisting PowSeries.pm

=test powseries-log 1

        use PowSeries '$log_', 'evaluate';
        require 'close-enough.pl';
        my $lg = PowSeries::nth(evaluate($log_, 0.5-1), 100);
        ok(close_enough($lg, log(0.5)), "calculate log(0.5) = $lg");

=endtest


This actually calculates M<log(x+1)>; to get M<log(x)>, subtract 1 from
V<x> before plugging it in.  (Unlike the others, it works only for V<x>
between -1 and 1.)  The power series method we've been using won't work
for an unmodified F<log> function, because it approximates every
function's behavior close to 0, and M<log(0)> is undefined.

The tangent function is more complicated.  One way to compute M<tan(x)>
is by computing M<sin(x)/cos(x)>.  We'll see another way in the next
section.

=subsection Symbolic Computation

R<power series|HERE>
As one final variation on power series computations we'll forget about
the numbers themselves and deal with the series as single units that
can be manipulated algebraically.  We've already seen hints of this
above.  If C<$f> and C<$g> are streams that represent the power series
for functions M<f(x)> and M<g(x)>, then C<add2($f, $g)> is the power
series for the function M<f(x) + g(x)>, C<scale($f, $c)> is the power
series for the function M<c*f(x)>, and C<derivative($f)> is the power
series for the function M<f'(x)>, the derivative of V<f>.

Multiplying and dividing power series is more complex.  In fact, it's
not immediately clear how to divide one infinite power series by
another.  Or even, for that matter, how to multiply them.  F<mul2> is
I<not> what we want here, because algebra tells us that M<(a_0 + a_1x +
...) * (b_0 + b_1x + ...)> = M<a_0b_0 + (a_0b_1 + a_1b_0)x + ...>,
and F<mul2> would give us M<a_0b_0 + a_1b_1x + ...> instead.

Our regex string generator comes to the rescue: power series
multiplication is formally almost identical to regex concatenation.
First note that if C<$S> represents some power series, say M<a_0 +
a_1x + a_2x^2 + ...> then C<tail($S)> represents M<a_1 + a_2x + a_3x^2
+ ...>.  Then:

        S = a_0     + a_1 x + a_2 x^2 + a_3 x^3 + ...
          = a_0     + x * (a_1 + a_2 x + a_3 x^2 + ...)
          = head(S) + x * tail(S)

Now we want to multiply two series, C<$S> and C<$T>:

        S   = head(S)         + x tail(S)
        T   = head(T)         + x tail(T)
        ------------------------------------
        S*T = head(S) head(T) + x head(S) tail(T) 
                              + x head(T) tail(S) + x^2 tail(T) tail(S)

            = head(S) head(T) + x (head(S) tail(T) + head(T) tail(S) + x ( tail(T) tail(S) ) )

The first term of the result, C<head(S) * head(T)>, is simply the
product of two numbers.  The rest of the terms can be found by summing
three series.  The first two are C<head(S) * tail(T)>, which is the
tail of V<T> scaled by C<head(S)>, or
C<scale(tail($T),  head($S))>, and 
C<head(T) * tail(S)>, which is
similar.  The last term, C<x * tail(S) * tail(T)>, is the product of two
power series and can be computed with a recursive call; the extra
multiplication by V<x> just inserts a 0 at the front of the stream,
since M<x * (a_0 + a_1x + a_2x^2 + ...)> = M<0 + a_0x + a_1x^2 + a_2x^3
+ ...>.

Here is the code:

=contlisting PowSeries.pm

        sub multiply {
          my ($S, $T) = @_;
          my ($s, $t) = (head($S), head($T));
          node($s*$t,
               promise { add2(scale(tail($T), $s),
                         add2(scale(tail($S), $t),
                              node(0,
                               promise {multiply(tail($S), tail($T))}),
                             ))
                       }
               );
        }

=endlisting PowSeries.pm

=auxtest oldmultiply.pl

        use Stream qw(head node tail promise);
        use PowSeries qw(add2);

        sub multiply {
          my ($S, $T) = @_;
          my ($s, $t) = (head($S), head($T));
          node($s*$t,
               promise { add2(PowSeries::scale(tail($T), $s),
                         add2(PowSeries::scale(tail($S), $t),
                              node(0,
                               promise {multiply(tail($S), tail($T))}),
                             ))
                       }
               );
        }
        *PowSeries::multiply = \&multiply;

=endtest

For power series, we can get a more efficient implementation by
optimizing F<scale> slightly.  

=contlisting PowSeries.pm

        sub scale {
          my ($s, $c) = @_;
*         return    if $c == 0;
*         return $s if $c == 1;
          transform { $_[0]*$c } $s;
        }

=endlisting PowSeries.pm

To test this, we can try out the identity M<sin^2(x) + cos^2(x) = 1>:

        my $one = add2(multiply($cos, $cos), multiply($sin, $sin));
        show($one, 20);

=test powseries-trig-oldmult

        use PowSeries qw($sin $cos add2 multiply);
        require 'oldmultiply.pl';
        require 'close-enough.pl';
        use Stream 'drop';
        my $one = add2(multiply($cos, $cos), multiply($sin, $sin));
        ok(close_enough(drop($one), 1), "first term is 1");
        for (2..11) {
          ok(close_enough(drop($one), 0), "$_'th term is 0");
        }
        
=endtest

        1 0 0 0 0 0 0 0 4.33680868994202e-19 0 0 0 0 0 0 0 0 0 6.46234853557053e-27 0

Exactly 1, as predicted, except for two insignificant round-off errors.

We might like to make F<multiply> a little cleaner and faster by
replacing the two calls to F<add2> with a single call to a function
that can add together any number of series:

=contlisting PowSeries.pm

        sub sum {
          my @s = grep $_, @_;
          my $total = 0;
          $total += head($_) for @s;
          node($total,
               promise { sum(map tail($_), @s) }
              );
        }

F<sum> first discards any empty streams from its arguments, since they
won't contribute to the sum anyway.  It then adds up the heads to get
the head of the result and returns a new stream with the sum at its
head; the tail promises to add up the tails similarly.  With this
new function, F<multiply> becomes:

        sub multiply {
          my ($S, $T) = @_;
          my ($s, $t) = (head($S), head($T));
          node($s*$t,
*              promise { sum(scale(tail($T), $s),
*                            scale(tail($S), $t),
                             node(0,
                               promise {multiply(tail($S), tail($T))}),
*                            )
                       }
               );
        }

=endlisting PowSeries.pm


=test powseries-trig

        use PowSeries qw($sin $cos add2 multiply);
        use Stream 'drop';
        require 'close-enough.pl';
        my $one = add2(multiply($cos, $cos), multiply($sin, $sin));
        ok(close_enough(drop($one), 1), "first term is 1");
        for (2..11) {
          ok(close_enough(drop($one), 0), "$_'th term is 0");
        }
        
=endtest

The next step is to calculate the reciprocal of a power series.  If
C<$s> is the power series for a function M<f(x)>, then the reciprocal
series C<$r> is the series for the function M<1/f(x)>.  To get this
requires a little bit of algebraic ingenuity.  Let's suppose that the
first term of C<$s> is 1.  (If it's not, we can scale C<$s>
appropriately, and then scale the result back when we're done.)

        r                  = 1/f(x)
        r                  = 1/s
        r                  = 1/(1 + tail(s))
        r * (1 + tail(s))  = 1
        r + r * tail(s)    = 1
        r                  = 1 - r * tail(s)

And now, amazingly, we're done.  We now know that the first term of
C<$r> must be 1, and we can compute the rest of the terms recursively by
using our trick of defining the C<$r> stream in terms of itself:

=contlisting PowSeries.pm

        # Only works if head($s) = 1
        sub recip {
          my ($s) = shift;
          my $r;
          $r = node(1, 
                    promise { scale(multiply($r, tail($s)), -1) });
        }

The heavy lifting is done; dividing power series is now a one-liner:
        
        sub divide {
          my ($s, $t) = @_;
          multiply($s, recip($t));
        }

        $tan = divide($sin, $cos);

=endlisting PowSeries.pm

        show($tan, 10);

*       0 1
*       0 0.333333333333333
*       0 0.133333333333333
*       0 0.053968253968254
*       0 0.0218694885361552 

=test powseries-tan 11

        use PowSeries '$tan';
        use Stream 'drop';
        require 'close-enough.pl';
        my @tan = (0, 1, 0, 1/3, 0, 2/15, 0, 17/315, 0, 62/2835, 0);
        my $N = 0;
        while (@tan) {
          ok(close_enough(drop($tan), shift(@tan)), "tan coeff $N");
          $N++;
        }

=endtest


My I<Engineering Mathematics Handbook> says that the coefficients are 0,
1, 0, 1/3, 0, 2/15, 0, 17/315, 0, 62/2835, ..., so it looks as though
the program is working properly.  If we would like the program to
generate the fractions instead of decimal approximations, we should
download the C<Math::BigRat> module from CPAN and use it to initialize
the F<factorial> function that is the basis of C<$sin> and C<$cos>.

C<Math::BigRat> values are infectious: if you combine one with an
ordinary number, the result is another C<Math::BigRat> object.  Since
the C<@fact> table is initialized with a C<Math::BigRat>, its other
elements will be constructed as C<Math::BigRat>s also; since the return
values of F<fact> are C<Math::BigRat>s, the elements of C<$sin> and
C<$cos> will be also; and since these are used in the computation of
C<$tan>, the end result will be C<Math::BigRat> objects.  Changing one
line in the source code causes a ripple effect that propagates all the
way to the final result:

=test powseries-tan-rat 11

        alarm(12);
        use PowSeries '$tan';
        use Stream 'drop';
        require 'close-enough.pl';
        use Math::BigRat;
        my @fact = (Math::BigRat->new(1));

        sub factorial {
          my $n = shift;
          return $fact[$n] if defined $fact[$n];
          $fact[$n] = $n * factorial($n-1);
        }
        *PowSeries::factorial = \&factorial;
        

        my @tan = qw(0 1 0 1/3 0 2/15 0 17/315 0 62/2835 0);
        my $N = 0;
        while (@tan) {
          is(drop($tan), shift(@tan), "tan coeff $N");
          $N++;
        }

=endtest

*       my @fact = (Math::BigRat->new(1));

        sub factorial {
          my $n = shift;
          return $fact[$n] if defined $fact[$n];
          $fact[$n] = $n * factorial($n-1);
        }

The output is now

        0 1 0 1/3 0 2/15 0 17/315 0 62/2835 

=Stop         





Outline:
* Streams of numeric approximations
** Newton-Raphson method
** Computational streams
*** Decimal number streams
**** Left-to-right addition
**** Carrying
**** Generalization to f(x,y) = (ax+by+c)/d; subtraction
**** Bounds checking
**** Preference
**** Multiplication and generalization to (axy+bx+cd+d)/(exy+fx+gy+h)
*** Continued fraction streams

Ideas:
- qsort / hoare's algorithm
- 'cutsort':  You have an infinite list, but for each element a, there
  is a predicate you can use to determine a point in the stream after
  which all subsequent elements will follow 'a' in sorted order.  So
  the sorting algorithm is:
  Get next element ('a')
  Scan stream until predicate says stop
  You have now found all the elements <= a.  Sort them and 
        output them.
  Proceed with the next unused element.
  You could use this on the Pythagorean triples, which increase, but
  not monotonically.
  You can also use this to sort the regex strings that are coming out
  already ordered by length.

- knotted lists and knotting function
  How *does* that function in Paulson work?


20021226 Given a regex, produce the list of strings that it matches.
20021227 Generate the strings in sorted order.
         Then, given a target string, determine if it matches the
         regex by searching for it in the generated-strings list.
         In fact, this only required a little change, and only to the
         'union' function; you just needed to turn it into a sorting
         union. 

         Then in chapter IX you can write a parser for regexes that
         turns /b*a/ into Regex::concat(Regex->literal('b')->star,
                                        Regex->literal('a')).

After collecting on the promise to find out the real tail, the F<tail>
function throws away the promise and replaces it with the real tail.
That way if anyone looks at the tail a second time, they'll see the
correct value with no extra computation.


    <li>Promises
    <li>Nonmemoizing streams
    <li>Memoizing streams
    <li>Streams with get-commit-rollback methods
    <li>Dataflow techniques

* 19990730

  Point out that a stream with side effects is going to be extremely
  unpredictable and difficult to understand.  Compare this with the
  memoization of an impure function.

* Analogous structure for lazy trees?  Lazy filesystem search tree?

20021227  Heuristically-guided filesystem search?

* 20021226

Notice you wrote this:

        sub combine {
          my ($op) = shift;
          sub {
            my @heads = map $_->head, @_;
            PowerSeries->node($op->(@heads),
                              promise { $combine->($op)->(map $_->tail, @_) }
                             );
          };
        }

But it would be more efficient like this:

        sub combine {
          my ($op) = shift;
*         my $f;
*         $f = sub {
            my @heads = map $_->head, @_;
            PowerSeries->node($op->(@heads),
*                             promise { $f->(map $_->tail, @_) }
                             );
          };
        }

Also: Are there dynamic scope problems with @_ here?  Do you need to
copy it to a lexical variable?  Answer: Yes.

Don't forget HARE AND TORTOISE technique

Converting generic iterator to stream:
        sub it2stream {
          my $it = shift;
          my $h = $it->();
          return unless defined $h;
          node($h, sub { it2stream($it) });
        }
 LocalWords:  startlisting endlisting upto contlisting upfrom ISA concat
 LocalWords:  postcat precat cutsorting cutsorter cutsort subsubsection




