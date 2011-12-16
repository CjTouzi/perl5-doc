

=chapter Recursion and Callbacks

R<callback|HERE>
The first `advanced' technique we'll see is X<recursion>.
X<Recursion|d> is a method of solving a problem by reducing it to a
simpler problem of the same type.

Unlike most of the techniques in this book, recursion is already
well-known and widely-understood.  But it will underlie several of the
later techniques, and so we need to have a good understanding of its
fine points.

=section Decimal to Binary Conversion

Until the release of Perl 5.6.0, there was no good way to generate a
binary numeral in Perl.  Starting in 5.6.0, you can use
C<sprintf("%b", $dec)>, but before that the question of how to do this
was Frequently Asked.

Any whole number has the form M<2k+b>, where V<k> is some smaller
whole number and V<b> is either 0 or 1.  V<b> is the final bit of the
binary expansion.  It's easy to see whether this final bit is 0 or 1;
just look to see whether the input number is even or odd.  The rest of
the number is M<2k>, whose binary expansion is the same as for V<k>,
but shifted left one place.  For example, the number M<37 = 2 * 18 +
1>; here V<k> is 18 and V<b> is 1, so the binary expansion of 37
(100101) is the same as that for 18 (10010), but with an extra 1 on
the end.

How did I compute the expansion for 37?  It is odd, so the final bit
must be 1; the rest of the expansion will be the same as the expansion
for 18.  How can I compute the expansion for 18?  18 is even, so its
final bit is 0, and the rest of the expansion is the same as the
expansion for 9.  What is the binary expansion for 9?  9 is odd, so
its final bit is 1, and the rest of its binary expansion is the same
as the binary expansion of 4.  We can continue in this way, until
finally we ask about the binary expansion of 1, which of course is 1.

This procedure will work for any number at all. To compute the binary
expansion of a number V<n> we proceed as follows:

=numberedlist

=item If V<n> is 1, its binary expansion is 1,  and we may ignore the
      rest of the procedure.  Similarly, if V<n> is 0, the expansion
      is simply 0.
      Otherwise:

=item Compute V<k> and V<b> so that M<n = 2k + b> and M<b = 0 {\rm or} 1>.
      To do this, simply divide V<n> by 2; V<k> is the quotient, and M<b>
      is the remainder, 0 if V<n> was even, and 1 if V<n> was odd.

=item Compute the binary expansion for V<k>, using this same method.
      Call the result V<E>. 

=item The binary expansion for V<n> is M<Eb>.

=endnumberedlist

Let's build a function called F<binary> that does this.    Here
is the preamble, and step 1:

=listing binary

        sub binary {
          my ($n) = @_;
          return $n if $n == 0 || $n == 1; 

Here is step 2:

          my $k = int($n/2);
          my $b = $n % 2;

For the third step, we need to compute the binary expansion of V<k>.
How can we do that?  It's easy, because we have a handy function for
computing binary expansions, called F<binary>---or we will once we're
finished writing it.  We'll call F<binary> with V<k> as its argument:

          my $E = binary($k);

Now the final step is a string concatenation:


          return $E . $b;
        }

=endlisting binary

=test binary 51

        eval { require 'binary' };
        for (0..50) {
          my $bin = sprintf "%b", $_;
          my $b2 = binary($_);
          is($b2, $bin, "$_ => binary");
        }

=endtest


This works.  For example, if you invoke C<binary(37)> you get the
string C<100101>.

The essential technique here was to I<reduce the problem to a
simpler case.> We were supposed to find the binary expansion of a
number V<n>; we discovered that this binary expansion was the
concatenation of the binary expansion of a smaller number V<k> and a
single bit V<b>.  Then to solve the simpler case of the same problem,
we used the function F<binary> in its own definition.  When we
invoke F<binary> with some number as an argument, it needs to
compute F<binary> for a different, smaller argument, which in turn
computes F<binary> for an even smaller argument. Eventually, the
argument becomes 1, and F<binary> computes the trivial binary
representation of 1 directly.   

This final step, called the X<base case|d> of the recursion, is
important.  If we don't consider it, our function might never
terminate.  If, in the definition of F<binary> above, we had omitted
the line

          return $n if $n == 0 || $n == 1; 

then F<binary> would have computed forever, and would never have
produced an answer for any argument.

=section Factorial

Suppose you have a list of V<n> different items.  For concreteness,
we'll suppose that these items are letters.  How
many different orders are there for such a list?  Obviously, the
answer depends on V<n>, so it is a function of V<n>.  This function is
called the X<factorial function|d>.  The factorial of V<n>
is the number of different orders for a list of V<n> different items.
Mathematicians usually write it as a postfix M<!> mark, so that the
factorial of V<n> is M<n!>.  They also call the different orders
X<permutations|d> .  

Let's compute some factorials.  Evidently, there's only one way to
order a list of 1 item, so M<1! = 1>.  There are two permutations of a
list of two items: C<A-B> and C<B-A>, so M<2!=2>.  A little
pencil work will reveal that there are six permutations of three
items:

        C  AB        C  BA
        A C B        B C A
        AB  C        BA  C

How can we be sure we didn't omit anything from the list?  It's not
hard to come up with a method that constructs every possible ordering,
and in R<permutations|chapter> we will see a program to list them all.
Here is one way to do it.  We can make any list of three items by
adding a new item to a list of two items.  We have two choices for the
two-item list we start with: C<AB> and C<BA>.  In each case, we have
three choices about where to put the C<C>: at the beginning, in the
middle, or at the end. There are M<2\cdot3=6> ways to make the choices
together, and since each choice leads to a different list of three
items, there must be six such lists.  The left column above shows all
the lists we got by inserting the C<C> into C<AB>, and the right
column shows the lists we got by inserting the C<C> into C<BA>, so the
display above is complete.

Similarly, if we want to know how many permutations there are of four
items, we can figure it out the same way.  There are six different
lists of three items, and there are four positions that we could
insert the fourth item into each of the lists, for a total of
M<6\cdot4=24> total orders:

        D  ABC    D  ACB    D  BAC    D  BCA    D  CAB    D  CBA
        A D BC    A D CB    B D AC    B D CA    C D AB    C D BA
        AB D C    AC D B    BA D C    BC D A    CA D B    CB D A
        ABC  D    ACB  D    BAC  D    BCA  D    CAB  D    CBA  D


Now we'll write a function to compute, for any V<n>, how many
permutations there are of a list of V<n> elements. 

=note
%%  Why would we care?
%% Because lists are fundamental to computer programming and we need to
%% know many basic facts about them.  
%% Analogy with sin() and cos()

We've just seen that if we know the number of possible permutations of
M<n-1> things, we can compute the number of permutations of V<n>
things.  To make a list of V<n> things, we take one of the M<(n-1)!>
lists of M<n-1> things and insert the V<n>th thing into one of the
V<n> available positions in the list.  Therefore, the total number of
permutations of V<n> items is M<(n-1)!\cdot n>.

        sub factorial {
          my ($n) = @_;
          return factorial($n-1) * $n;
        }


Oops, this function is broken; it never produces a result for any
input, because we left out the termination condition.  To compute
C<factorial(2)>, it first tries to compute C<factorial(1)>.  To
compute C<factorial(1)>, it first tries to compute C<factorial(0)>.
To compute C<factorial(0)>, it first tries to compute
C<factorial(-1)>.  This process continues forever.  We can fix it by
telling the function explicitly what M<0!> is, so that when it gets to
0 it doesn't need to make a recursive call:

=listing factorial

        sub factorial {
          my ($n) = @_;
          return 1 if $n == 0;
          return factorial($n-1) * $n;
        }

=endlisting factorial

=test factorial 9

        eval { require 'factorial' };
        my @fact = (1, 1, 2, 6, 24, 120, 720, 5040, 40320);
        for (0 .. $#fact) {
          my $fact = factorial($_);
          is($fact, $fact[$_], "$_!");
        }

=endtest

Now the function works properly.

It may not be immediately apparent why the factorial of 0 is 1.  Let's
return to the definition.  C<factorial($n)> is the number of different
orders of a given list of C<$n> elements.  C<factorial(2)> is 2,
because there are two ways to order a list of 2 elements: C<('A',
'B')> and C<('B', 'A')>.  C<factorial(1)> is 1, because there is only
one way to order a list of 1 element: C<('A')>.  C<factorial(0)> is 1,
because there is only one way to order a list of 0 elements: C<()>.
Sometimes people are tempted to argue that M<0!> should be 0, but the
example of C<()> shows clearly that it isn't.  

Getting the base case right is vitally important in recursive
functions, because if you get it wrong, it will throw off all the
other results from the function.  If we were to erroneously replace
C<return 1> in the function above with C<return 0>, it would no longer
be function for computing factorials; instead, it would be a function
for computing zero.

=subsection Why Private Variables are Important

Let's spend a little while looking at what happens if we leave out the
C<my>.  The following version of F<factorial> is identical to the
previous version, except that it is missing the X<C<my> declaration>
on C<$n>.

=listing factorial_nonreentrant

        sub factorial {
          ($n) = @_;
          return 1 if $n == 0;
          return factorial($n-1) * $n;
        }

=endlisting factorial_nonreentrant

Now C<$n> is a global variable, because all Perl variables are global
unless they are declared with C<my>.  This means that even though
several copies of F<factorial> might be executing simultaneously,
they are all using the same global variable C<$n>.  What effect does this
have on the function's behavior?

Let's consider what happens when we call C<factorial(1)>.  Initially,
C<$n> is set to 1, and the test on the second line fails, so the
function makes a recursive call to C<factorial(0)>.  The invocation of
C<factorial(1)> waits around for the new function call to complete.
When C<factorial(0)> is entered, C<$n> is set to 0.  This time the
test on the second line is true, and the function returns immediately,
yielding 1.

The invocation of C<factorial(1)> that was waiting around for the
answer to C<factorial(0)> can now continue; the result from
C<factorial(0)> is 1.  C<factorial(1)> takes this 1, multiplies it by
the value of C<$n>, and returns the result.  But C<$n> is now 0, because
C<factorial(0)> set it to 0, so the result is M<1*0> = 0.  This is the
final, incorrect return value of C<factorial(1)>.  It should have been
1, not 0.

Similarly, C<factorial(2)> returns 0 instead of 2, and C<factorial(3)>
returns 0 instead of 6, and so on. 

In order to work properly, each invocation of F<factorial> needs to
have its own private copy of C<$n> that the other invocations won't
interfere with, and that's exactly what C<my> does.  Each time
F<factorial> is invoked, a new variable is created for that invocation
to use as its C<$n>.

Other languages that support recursive functions all have variables
that work something like Perl's C<my> variables, where a new one is
created each time the function is invoked.  For example, in C,
variables declared inside functions have this behavior by default,
unless declared otherwise.  (In C, such variables are called X<I<auto>
variables>, because they are automatically allocated and deallocated.)
Using global variables or some other kind of storage that isn't
allocated for each invocation of a function usually makes it
impossible to call that function recursively; such functions are
called X<non-reentrant|d>.  Non-reentrant functions were once quite
common in the days when people used languages like Fortran (which
didn't support recursion until 1990) and became less common as
languages with private variables, such as C, became popular.
X<Fortran programming language|i> X<C programming language|i>

=section The Tower of Hanoi

Both our examples so far have not actually required recursion; they
could both be rewritten as simple loops.

This sort of rewriting is always possible, because after all, the
machine language in your computer probably doesn't support recursion,
so in some sense it must be inessential.  For the factorial function,
the rewriting is easy, but this isn't always so.  Here's an example.
It's a puzzle that was first proposed by X<Edouard Lucas> in 1883,
called the X<Tower of Hanoi>.

You have three pegs, called A, B, and C.  On peg A is a tower of disks
of graduated sizes, with the largest on the bottom and the smallest on
the top.  

=startpicture hanoi-initial

                  |             |              |
                11111           |              |
                  |             |              |
               2222222          |              |
      The         |             |              |
      Big     333333333         |              |
      Disk        |             |              |
        .    44444444444        |              |
         `.       |             |              |
            5555555555555       |              |
                  |             |              |
          =============================================

                  A             B              C

=endpicture hanoi-initial

The puzzle is to move the entire tower from A to C, subject to the
following restrictions: you may move only one disk at a time, and no
disk may ever rest atop a smaller disk.  The number of disks varies
depending on who is posing the problem, but is traditionally 64.  We
will try to solve the problem in the general case, for V<n> disks.

Let's consider the largest of the V<n> disks, which is the one on the
bottom.  We'll call this disk `the Big Disk'.  The Big Disk starts on
peg A, and we want it to end on peg C.  If any other disks are on
peg A, they are on top of the Big Disk, so we will not be able to move
it.  If any other disks are on peg C, we will not be able to move the
Big Disk to C because then it would be atop some smaller disk.  So if
we want to move the Big Disk from A to C, all the other disks must be
heaped up on peg B, in size order, with the smallest one on top.

=startpicture hanoi-subgoal

                  |             |              |
                  |             |              |
                  |             |              |
                  |           11111            |
      The         |             |              |
      Big         |          2222222           |
      Disk        |             |              |
        .         |         333333333          |
         `.       |             |              |
            5555555555555  44444444444         |
                  |             |              |
          =============================================

                  A             B              C

=endpicture hanoi-subgoal

This means that to solve this problem, we have a subgoal:  we have to
move the entire tower of disks, except for the Big Disk, from A to B.
Only then we can transfer the Big Disk from A to C.  After we've done
that, we will be able to move the rest of the tower from B to C; this
is another subgoal.

Fortunately, when we move the smaller tower, we can ignore the Big
Disk; it will never get in our way no matter where it is.  This means
that we can apply the same logic to moving the smaller tower: at the
bottom of the smaller tower is a large disk; we will move the rest of
the tower out of the way, move this bottom disk to the right place,
and then move the rest of the smaller tower on top of it.  How do we
move the rest of the smaller tower?  The same way.

The process bottoms out when we have to worry about moving a smaller
tower that contains only one disk, which will be the smallest disk in
the whole set.  In that case our subgoals are trivial, and we just put
the little disk wherever we need to.  We know that there will never be
anything  on top of it (because that would be illegal) and we know
that we can always move it wherever we like; it's the smallest, so it
is impossible to put it atop anything smaller.

Our strategy for moving the original tower looks like this:

To move a tower of V<n> disks from the start peg to the end peg,

=numberedlist

=item If the `tower' is actually only one disk high, just move it.  Otherwise:

=item Move all the disks except for disk V<n> (the Big Disk) from the start peg to the extra peg, using this method

=item Move disk V<n> (the Big Disk) from the start peg to the end peg

=item Move all the other disks from the extra peg to the end peg, using this method

=endnumberedlist

It's easy to translate this into code:

=startlisting hanoi

    # hanoi(N, start, end, extra)
    # Solve Tower of Hanoi problem for a tower of N disks,
    # of which the largest is disk #N.  Move the entire tower from
    # peg `start' to peg `end', using peg `extra' as a work space
  
    sub hanoi {
      my ($n, $start, $end, $extra) = @_;
      if ($n == 1) { 
        print "Move disk #1 from $start to $end.\n";  # Step 1
      } else {
        hanoi($n-1, $start, $extra, $end);            # Step 2
        print "Move disk #$n from $start to $end.\n"; # Step 3
        hanoi($n-1, $extra, $end, $start);            # Step 4
      }
    }

=endlisting hanoi

=test hanoi 84

        eval { require "hanoi" };
        eval { require "check_move" };
        @position = qw(dummy P P P P P);
        use STDOUT;
        hanoi(5, "P", "Q", "R");
        my $N = 0;
        for my $line (split /^/, $OUTPUT) {
          $N++;
          my ($d, $s, $e) = ($line =~ /Move disk #(\d+) from ([PQR]) to ([PQR])\./);
          ok (defined($d) && defined($s) && defined($e), 
              "pattern match on move $N");
          eval { check_move($d, $s, $e) };
          ok (!$@, "checked move $N: disk $d from $s to $e ($@)");
        }

        $OUTPUT = "";
        @position = qw(dummy A A A);
        hanoi(3, "A", "C", "B");
        $N = 0;
        for my $line (split /^/, $OUTPUT) {
          $N++;
          my ($d, $s, $e) = ($line =~ /Move disk #(\d+) from ([ABC]) to ([ABC])\./);
          ok (defined($d) && defined($s) && defined($e), 
              "pattern match on move $N");
          eval { check_move($d, $s, $e) };
          ok (!$@, "checked move $N: disk $d from $s to $e ($@)");
        }

        $OUTPUT = "";
        $N = 0;
        hanoi(3, "A", "C", "B");
        my @a = split /\n/, $OUTPUT;
        chomp(my @x = grep /\S/, <DATA>);
        s/^\s+// for @x;
        is(scalar(@a), scalar(@x), "array lengths");
        for (0 .. $#a) {
          is($a[$_], $x[$_], "line $_");
        }
        
        __END__
        Move disk #1 from A to C.
        Move disk #2 from A to B.
        Move disk #1 from C to B.
        Move disk #3 from A to C.
        Move disk #1 from B to A.
        Move disk #2 from B to C.
        Move disk #1 from A to C.

=endtest

This function prints a series of instructions for how to move the
tower.  For example, to ask it for instructions for moving a tower of
three disks, we call it like this:

        hanoi(3, 'A', 'C', 'B');

Its output is:

        Move disk #1 from A to C.
        Move disk #2 from A to B.
        Move disk #1 from C to B.
        Move disk #3 from A to C.
        Move disk #1 from B to A.
        Move disk #2 from B to C.
        Move disk #1 from A to C.

=note move this following section about parametrization to somewhere else?

If we wanted a graphic display of moving disks instead of a simple
printout of instructions, we could replace the C<print> statements
with something fancier.  But we can make the software more flexible
almost for free by parametrizing the output behavior.  Instead of
having a C<print> statement hardwired in, F<hanoi> will accept an
extra argument that is a function that will be called each time
F<hanoi> wants to move a disk.  This function will print an
instruction, or update a graphical display, or do whatever else we
want.  The function will be passed the number of the disk, and the
source and destination pegs.  The code is almost exactly the same:

    sub hanoi {
*     my ($n, $start, $end, $extra, $move_disk) = @_;
      if ($n == 1) { 
*       $move_disk->(1, $start, $end);
      } else {
        hanoi($n-1, $start, $extra, $end, $move_disk);
*       $move_disk->($n, $start, $end);
        hanoi($n-1, $extra, $end, $start, $move_disk);
      }
    }

To get the behavior of the original version, we now invoke F<hanoi>
like this:

        sub print_instruction {
          my ($disk, $start, $end) = @_;
          print "Move disk #$disk from $start to $end.\n";
        }

        hanoi(3, 'A', 'C', 'B', \&print_instruction);

The C<\&print_instruction> expression generates a X<code reference|d>,
which is a scalar value that represents the function.  You can store
the code reference in a scalar variable just like any other scalar, or
pass it as an argument just like any other scalar, and you can also
use the reference to invoke the function that it represents.  To do
that, you write:

        $code_reference->(arguments...);

This invokes the function with the specified arguments.  N<This
notation was introduced in Perl 5.004; people with 5.003 or earlier
will have to use a much uglier notation instead:
C<&{$code_reference}(arguments...);> When the C<$code_reference>
expression is a simple variable, as in the example, the curly braces
may be omitted.> Code references are often referred to as
X<coderef|id>I<coderefs>.

The coderef argument to F<hanoi> is called a X<callback|d>, because it
is a function supplied by the caller of F<hanoi> that will be 'called
back' to when F<hanoi> needs help.  We sometimes also say that the
C<$move_disk> argument of F<hanoi> is a X<hook|d>, because it provides
a place where additional functionality may easily be hung.

Now that we have a generic version of F<hanoi>, we can test the
algorithm by passing in a C<$move_disk> function that keeps track of
where the disks are and checks to make sure we haven't done anything
illegal:

=listing check_move

        @position = (' ', ('A') x 3); # Disks are all initially on peg A

        sub check_move {
          my $i;
          my ($disk, $start, $end) = @_;

The F<check_move> function maintains an array, @position, that records
the current position of every disk.  Initially, every disk is on peg
A.  Here we assume that there are only three disks, so we set
C<$position[1]>, C<$position[2]>, and C<$position[3]> to C<'A'>.
C<$position[0]> is a dummy element that is never used because there is
no disk 0.  Each time the main F<hanoi> function wants to move a disk,
it calls F<check_move>.

          if ($disk < 1 || $disk > $#position) {
            die "Bad disk number $disk. Should be 1..$#position.\n";
          }

This is a trivial check to make sure that F<hanoi> doesn't try to
move a nonexistent disk.

          unless ($position[$disk] eq $start) {
            die "Tried to move disk $disk from $start, but it is on peg $position[$disk].\n";
          }

Here the function checks to make sure that F<hanoi> is not trying to
move a disk from a peg where it does not reside.  If the start peg
does not match F<check_move>'s notion of the current position of the
disk, the function signals an error.
   
          for $i (1 .. $disk-1) {
            if ($position[$i] eq $start) {
              die "Can't move disk $disk from $start because $i is on top of it.\n";
            } elsif ($position[$i] eq $end) {
              die "Can't move disk $disk to $end because $i is already there.\n";
            }
          }

This is the really interesting check.  The function loops over all the
disks that are smaller than the one F<hanoi> is trying to move, and
makes sure that the smaller disks aren't in the way.  The first C<if>
branch makes sure that each smaller disk is not on top of the one
F<hanoi> wants to move, and the second branch makes sure that F<hanoi>
is not trying to move the current disk onto the smaller disk.
    
          print "Moving disk $disk from $start to $end.\n";
          $position[$disk] = $end;
        }

=endlisting check_move

=test check-move

        ok(1);  # tested by 'hanoi' above

=endtest

Finally, the function has determined that there is nothing wrong with
the move, so it prints out a message as before, and adjusts the
C<@position> array to reflect the new position of the disk.

Running 

        hanoi(3, 'A', 'C', 'B', \&check_move);

yields the same output as before, and no errors---F<hanoi> is not
doing anything illegal. 

=note next sentence here is clumsy

This example demonstrates a valuable technique we'll see over and over
again: by parametrizing some part of a function to call some other
function instead of hardwiring the behavior, we can make it more
flexible.  This added flexibility will pay off when we want the
function to do something a little different, such as performing an
automatic self-check.  Instead of having to clutter up the function
with a lot of optional self-testing code, we can separate the testing
part from the main algorithm.  The algorithm remains as clear and
simple as ever, and we can enable or disable the self-checking code at
run time if we want to, by passing a different coderef argument.

=section Hierarchical Data

=note File::Find is missing from this section.  Get some discussion
from your iterators and generators class.

The examples I've showed give the flavor of what a recursive procedure
looks like, but they miss an important point.  In introducing the
Tower of Hanoi problem, I said that recursion is useful when you want
to solve a problem that can be reduced to simpler cases of the same
problem.  But it might not be clear that such problems are common.

Most recursive functions are built to deal with X<recursive data
structures>.  A recursive data structure is one like a list, tree, or
heap which is defined in terms of simpler instances of the same data
structure.  The most familiar example is probably a file system
directory structure.  A file is either:

=bulletedlist

=item a plain file, which contains some data, or

=item a directory, which contains a list of files

=endbulletedlist

A file might be a directory, which contains a list of files, some of
which might be directories, which in turn contain more lists of files,
and so on.  The most effective way of dealing with such a structure is
with a recursive procedure.  Conceptually, each call to such a
procedure handles a single file.  The file might be a plain file, or
it might be a directory, in which case the procedure makes recursive
calls to itself to handle any subfiles that the directory has.  If the
subfiles are themselves directories, the procedure will make more
recursive calls.

Here's an example of a function that takes the name of a directory as
its argument and computes the total size of all the files contained in
it, and in its subdirectories, and their subdirectories, and so on.

=listing total_size_broken

        sub total_size {
          my ($top) = @_;
          my $total = -s $top;

When we first call the function, it's with an argument C<$top>, which
is the name of the file or directory we want to examine.  The first
thing the function does is use the Perl C<-s> operator to find the
size of this file or directory itself.  This operator yields the size
of the file, in bytes.  If the file is a directory, it says how much
space the directory itself takes up on the disk, apart from whatever
files the directory may contain---the directory is a list of files,
remember, and the list takes up some space too.  If the top file is
actually a directory, the function will add the sizes of its contents
to a running total that it will keep in C<$total>.

          return $total if -f $top;
          unless (opendir DIR, $top) {
            warn "Couldn't open directory $top: $!; skipping.\n";
            return $total;
          }

The C<-f> operator checks to see if the argument is a plain file; if
so the function can return the total immediately.  Otherwise, it
assumes that the top file is actually a directory, and tries to open
it with C<opendir()>.  If the directory can't be opened, the function
issues a warning message and returns the total so far, which includes
the size of the directory itself, but not its contents.

          my $file;
          while ($file = readdir DIR) {
            next if $file eq '.' || $file eq '..';
            $total += total_size("$top/$file");
          }

The next block, the C<while> loop, is the heart of the function.  It
reads filenames from the directory one at a time, calls itself
recursively on each one, and adds the result to the running total.  

          closedir DIR;
          return $total;
        }

=endlisting total_size_broken

At the end of the loop, the function closes the directory and returns
the total.

In the loop, the function skips over the names C<.> and C<..>, which
are aliases for the directory itself and for its parent; if it didn't
do this, it would never finish, because it would try to compute the
total sizes of a lot of files with names like C<././././././fred> and
C<dir/../dir/../dir/../dir/fred>.

X<non-reentrant function|i>
X<function|non-reentrant|i>
This function has a gigantic bug, and in fact it doesn't work at all.
The problem is that directory handles, like C<DIR>, are global, and so
our function is not reentrant.  The function fails for essentially the
same reason that the C<my>-less version of F<factorial> failed.  The
first call goes ahead all right, but if F<total_size> calls itself
recursively, the second invocation will open the same dirhandle
C<DIR>.  Eventually, the second invocation will reach the end of its
directory, close C<DIR>, and return; when this happens, the first
invocation will try to continue, find that C<DIR> has been closed, and
exit the C<while> loop without having read all the filenames from the
top directory.  The second invocation will have the same problem if it
makes any recursive calls itself.

The result is that the function, as written, only looks down the first
branch of the directory tree.  If the directory hierarchy has a
structure like this:

=startpicture directory-hierarchy


                               top
                              / | \
                             /  |  \
                            a   b   c
                           /|\  |   |\
                          d e f g   h i
                         /|   |
                        j k   l

=endpicture

then our function will go down the I<top>-I<a>-I<d> path, see files
I<j> and I<k>, and report the total size of M<top+a+d+j+k>, without
ever noticing I<b>, I<c>, I<e>, I<f>, I<g>, I<h>, I<i>, or I<l>.

To fix it, we need to make the directory handle C<DIR> a private
variable, the way C<$top> and C<$total> are.  Instead of C<opendir
DIR, $top>, we'll use C<opendir $dir, $top>, where C<$dir> is a
private variable.  When the first argument to C<opendir> is an
undefined variable, C<opendir> will create a new, anonymous dirhandle
and store it into C<$dir>.N<This feature was introduced in Perl 5.6.0.
Users of earlier Perl versions will have to use the C<IO::Handle>
module to explicitly manufacture a dirhandle: C<my $dir =
IO::Handle-\>new; opendir $dir, $top;>>

Instead of doing this:

        opendir DIR, $somedir;
        print (readdir DIR);
        closedir DIR;

We can get the same effect by doing this instead:

        my $dir;
        opendir $dir, $somedir;
        print (readdir $dir);
        closedir $dir;

The big difference is that C<DIR> is a global dirhandle, and can be
read or closed by any other part of the program; the dirhandle in C<$dir>
is private, and can only be read or closed by the function that
creates it, or by some other function that is explicitly passed the
value of C<$dir>.

With this new technique, we can rewrite the F<total_size> function
so that it works properly:

=listing total_size

        sub total_size {
          my ($top) = @_;
          my $total = -s $top;
*         my $DIR;

          return $total if -f $top;
*         unless (opendir $DIR, $top) {
            warn "Couldn't open directory $top: $!; skipping.\n";
            return $total;
          }

          my $file;
*         while ($file = readdir $DIR) {
            next if $file eq '.' || $file eq '..';
            $total += total_size("$top/$file");
          }          
          
*         closedir $DIR;
          return $total;
        }

=endlisting total_size

=auxtest HandleSave.pm

        package HandleSave;
        sub save {
          my $class = shift;
          my $fhname = shift;
          my $fh = shift || *$fhname;
          my $fno = fileno($fh);
          my $nfh;
          open $nfh, ">&=$fno" or die $!;
          close $fh;
          open $fh, ">", "/dev/null" or die $!;
          bless [$fhname, $nfh, $fno] => $class;
        }

        sub DESTROY {
          my $self = shift;
          my ($name, $h, $no) = @$self;
          open $name, ">&=$no" or die $!;
        }
          

=endtest

=test total-size 1

        alarm(10);
        my $dir = shift || "Mod";
        eval { require "total_size" };
        use File::Find;
        use HandleSave;
        { my $save = HandleSave->save(STDERR);
          $size = total_size($dir);
        }
        my $size2 = 0;
        find({ wanted => sub { $size2 += -s }, 
               follow_fast => 1 }, $dir);
        is($size, $size2, "total_size of '$dir'");

=endtest

X<scope|i> Actually, the C<closedir> here is unnecessary, because
dirhandles created with this method close automatically when the
variables that contain them go out of scope.  When F<total_size>
returns, its private variables are destroyed, including C<$DIR>, which
contains the last reference to dirhandle object we opened.  Perl then
destroys the dirhandle object, and in the process, closes the
dirhandle.  We will omit the explicit C<closedir> in the future.

This function still has some problems: it doesn't handle symbolic
links correctly, and if a file has two names in the same directory, it
gets counted twice.  Also, on Unix systems, the space actually taken
up by a file on disk is usually different from the length reported by
C<-s>, because disk space is allocated in blocks of 1024 bytes at a
time.  But the function is good enough to be useful, and we might want
to apply it to some other tasks as well.  If we do decide to fix these
problems, we will only need to fix them in this one place, instead of
fixing the same problems in fifty slightly different directory-walking
functions in fifty different applications.

=section Applications and Variations of Directory Walking

Having a function that walks a directory tree is useful, and we might
like to use it for all sorts of things.  For example, if we want to
write a recursive file lister that works like the C<ls -R> command,
we'll need to walk the directory tree.  We might want our function to
behave more like the C<du> command, which prints out the total size of
every subdirectory, as well as the total for all the files it found.
We might want our function to search for dangling symbolic links; that
is, links that point to nonexistent files.  A frequently-asked
question in the Perl newsgroups and IRC channels is how to walk a
directory tree and rename each file or perform some other operation on
each file.

We could write many different functions to do these tasks, each one a
little different.  But the core part of each one is the recursive
directory walker, and so we'd like to abstract that out so that we can
use it as a tool.  If we can separate the walker, we can put it in a
library, and then anyone who needs a directory walker can use ours.  

An important change of stance occurred in the last paragraph.
Starting from here, and for most of the rest of the book, we are going
to take a point of view that you may not have seen before: we are no
longer interested in developing a complete program that we or someone
else might use entire.  Instead, we are going to try to write our code
so that it is useful to I<another programmer> who might want to re-use
it in another program.  Instead of writing a program, we are now
writing a library or module which will be used by other programs.

One direction that we could go from here would be to show how to write
a X<I<user interface>> for the F<total_size> function, which might
prompt the user for a directory name, or read a directory name from
the command line or from a graphical widget, and then would display
the result somehow.  We are not going to do this.  It is not hard to
add code to prompt the user for a directory name or to read the
command-line arguments.  For the rest of this book, we are not going
to be concerned with user interfaces; instead, we are going to look at
I<programmer> interfaces.  The rest of the book will talk about `the
user', but it's not the usual user.  Instead, the user is another
programmer who wants to use our code when writing their own programs.
Instead of asking how we can make our entire program simple and
convenient for an end-user to use, we will look at ways to make our
functions and libraries simple and convenient for other programmers to
use in their own programs.

There are two good reasons for doing this.  One is that if our
functions are well-designed for easy re-use, we will be able to re-use
them ourselves and save time and trouble.  Instead of writing similar
code over and over, we'll plug a familiar directory-walking
function into every program that needs one.  When we improve the
directory-walking function in one program, it will be automatically
improved in all our other programs as well.  Over time, we'll develop
a toolkit of useful functions and libraries that will make us more
productive, and we'll have more fun programming.

But more importantly, if our functions are well-designed for re-use,
other programmers will be able to use them, and will get the same
benefits that we do.  And being useful to other people is the reason
we're here in the first place.N<Some people find this unpersuasive, so
perhaps I should point out that if we make ourselves useful to other
people, they will love and admire us, and they might even pay us
more.>

With that change of stance clearly in mind, let's go on.  We had
written a function, F<total_size>, which contained useful
functionality: it walked a directory tree recursively.  If we could
cleanly separate the directory-walking part of the code from the
total-size-computing part, then we might be able to re-use the
directory-walking part in many other projects for many other purposes.
How can we separate the two functionalities?

As in the Tower of Hanoi program, the key here is to pass an
additional parameter to our function.  The parameter will itself be a
function that tells F<total_size> what we want it to do.  The code
will look like this:

=startlisting dir_walk_simple

        sub dir_walk {
          my ($top, $code) = @_;
          my $DIR;
          
          $code->($top);
          
          if (-d $top) {
            my $file;
            unless (opendir $DIR, $top) {
              warn "Couldn't open directory $top: $!; skipping.\n";
              return;
            }
            while ($file = readdir $DIR) {
              next if $file eq '.' || $file eq '..';
              dir_walk("$top/$file", $code);
            }
          }
        }

=endlisting dir_walk_simple

=test dir-walk-size 1

        my $dir = shift || "Mod";
        eval { require "dir_walk_simple" };
        use File::Find;
        use HandleSave;
        my $size;
        { my $save = HandleSave->save(STDERR);
          dir_walk($dir, sub { $size += -s $_[0] });
        }
        my $size2 = 0;
        find({ wanted => sub { $size2 += -s }, 
               follow_fast => 1 }, $dir);
        is($size, $size2, "total_size of '$dir'");

=endtest

This function, which I've renamed F<dir_walk> to honor its new
generality, gets two arguments.  The first, C<$top>, is the name of the
file or directory that we want it to start searching in, as before.
The second, C<$code>, is new.  It's a coderef that tells C<dir_walk> what
we want to do for each file or directory that we discover in the file
tree.  Each time F<dir_walk> discovers a new file or directory, it
will invoke our code with the filename as the argument.

Now whenever we meet another programmer who asks us ``How do I do V<X>
for every file in a directory tree?'' we can answer ``Use this
F<dir_walk> function, and give it a reference to a function that
does V<X>.''  The C<$code> argument is a callback.


For example, to get a program that prints out a list of all the files
and directories below the current directory, we can use

        sub print_dir {
          print $_[0], "\n";
        }

        dir_walk('.', \&print_dir );

=test dir-walk-printdir 2

        alarm 20;

        my $dir = shift || "Mod";
        eval { require "dir_walk_simple" };
        use File::Find;
        use STDOUT;
        use HandleSave;

        { my $save = HandleSave->save(STDERR);
          dir_walk($dir, \&print_dir );
        }
        my $out1 = $OUTPUT;

        alarm 30;
        $OUTPUT = "";
        find({ wanted => sub { print "$File::Find::name\n" },
               follow_fast => 1 }, $dir);
        my $out2 = $OUTPUT;

        my @lines1 = split /^/, $out2;        
        my @lines2 = split /^/, $out1;        
        for (@lines1) {
          $l1{$_} = 1;
        }
        for (@lines2) {
          warn "# $_\n" unless $l1{$_};
        }

        is(scalar(@lines1), scalar(@lines2), "same number of files");
        ok(eq_set(\@lines1, \@lines2), "same files");

        sub print_dir {
          print $_[0], "\n" 
         # Work around a bug in File::Find
                unless -l $_[0] && ! -e $_[0] 
           ;
        }

=endtest

This prints out something like this:

        .
        ./a
        ./a/a1
        ./a/a2
        ./b
        ./b/b1
        ./c
        ./c/c1
        ./c/c2
        ./c/c3
        ./c/d
        ./c/d/d1
        ./c/d/d2

(The current directory contains three subdirectories, named C<a>,
C<b>, and C<c>.  Subdirectory C<c> contains a sub-subdirectory, named
C<d>.)

C<print_dir> is so simple that it's a shame to have to waste time
thinking of a name for it.  It would be convenient if we could simply
write the function without having to write a name for it, analogous to
the way we can
write 

        $weekly_pay = 40 * $hourly_pay;

without having to name  the 40 or store it in a variable.  Perl does
provide a syntax for this:

        dir_walk('.', sub { print $_[0], "\n" } );

The C<sub { ... }> introduces an X<anonymous function|d>; that is, a
function with no name.  The value of the C<sub { ... }> construction
is a coderef that can be used to call the function.  We can store this
coderef in a scalar variable or pass it as an argument to a function
like any other reference.  This one line does the same thing as
the more verbose version above with the named C<print_dir> function.

If we want the function to print out sizes along with filenames, we
need only make a small change to C<$code>:

        dir_walk('.', sub { printf "%6d %s\n", -s $_[0], $_[0]} );

          4096 .
          4096 ./a
           261 ./a/a1
           171 ./a/a2
          4096 ./b
           348 ./b/b1
          4096 ./c
           658 ./c/c1
           479 ./c/c2
           889 ./c/c3
          4096 ./c/d
           568 ./c/d/d1
           889 ./c/d/d2

If we want the function to locate dangling symbolic links, it's just
as easy:

        dir_walk('.', sub { print $_[0], "\n" if -l $_[0] && ! -e $_[0]});

C<-l> tests the current file to see if it's a symbolic link, and C<-e>
tests to see if the file that the link points at exists.

But my promises fall a little short.  There's no simple way to get the
new F<dir_walk> function to aggregate the sizes of all the files it
sees.  C<$code> is invoked only for one file at a time, so it never
gets a chance to aggregate.  If the aggregation is sufficiently
simple, we can accomplish it with a variable defined outside the
callback:

        my $TOTAL = 0;
        dir_walk('.', sub { $TOTAL += -s $_[0] }); 
        print "Total size is $TOTAL.\n";

There are two drawbacks to this approach. One is that the callback
function must reside in the scope of the C<$TOTAL> variable, as must
any code that plans to use C<$TOTAL>. Often this isn't a problem, as
in this case, but if the callback were a complicated function in a
library somewhere, it might present difficulties.  We'll see a
solution to this problem in R<user parameter|section>.  

The other drawback is that it only works well when the aggregation is
extremely simple, as it is here.  Suppose instead of accumulating a
single total size, we wanted to build a hash structure of filenames
and sizes, like this one:

=testable sizehash-output

          {
            'a' => {
                     'a1' => '261',
                     'a2' => '171'
                   },
            'b' => {
                     'b1' => '348'
                   },
            'c' => {
                     'c1' => '658',
                     'c2' => '479',
                     'c3' => '889',
                     'd' => {
                              'd1' => '568',
                              'd2' => '889'
                            }
                   }
          }

=endtest sizehash-output

Here the keys are file and directory names.  The value for a filename
is the size of the file, and the value for a directory name is a hash
with keys and values that represent the contents of the directory.  It
may not be clear how we could adapt the simple C<$TOTAL>-aggregating
callback to produce a complex structure like this one.

Our C<dir_walk> function is not general enough.  We need it to perform
some computation involving the files it examines, such as computing
their total size, and to return the result of this computation to its
caller.  The caller might be the main program, or it might be another
invocation of F<dir_walk>, which can then use the value it receives
as part of the computation I<it> is performing for its caller.

How can F<dir_walk> know how to perform the computation?  In
F<total_size>, the addition computation was hardwired into the
function.  We would like F<dir_walk> to be more generally useful.

What we need is to supply two functions: one for plain files, and one
for directories.  F<dir_walk> will call the plain-file function when
it needs to compute its result for a plain file, and it will call the
directory function when it needs to compute its result for a
directory.  F<dir_walk> won't know anything about how to do these
computations itself; all it knows is that is should delegate the
actual computing to these two functions.

Each of the two functions will get a filename argument, and will
compute the value of interest, such as the size, for the file named by
its argument.  Since a directory is a list of files, the directory
function will also receive a list of the values that were computed for
each of its members; it may need these values when it computes the
value for the entire directory.  The directory function will know how
to aggregate these values to produce a new value for the entire
directory.

With this change, we'll be able to do our C<total_size> operation.
The plain file function will simply return the size of the file it's
asked to look at.  The directory function will get a directory name
and a list of the sizes of each file that it contains, add them all
up, and return the result.  The generic framework function looks like
this:

=startlisting dir_walk_callbacks

        sub dir_walk {
*         my ($top, $filefunc, $dirfunc) = @_;
          my $DIR;

          if (-d $top) {
            my $file;
            unless (opendir $DIR, $top) {
              warn "Couldn't open directory $code: $!; skipping.\n";
              return;
            }

*           my @results;
            while ($file = readdir $DIR) {
              next if $file eq '.' || $file eq '..';
*             push @results, dir_walk("$top/$file", $filefunc, $dirfunc);
            }
*           return $dirfunc->($top, @results);
*         } else {
*           return $filefunc->($top);
*         }
        }

=endlisting dir_walk_callbacks

To compute the total size of the current directory, we will use this:

        sub file_size { -s $_[0] }

        sub dir_size {
          my $dir = shift;
          my $total = -s $dir;
          my $n;
          for $n (@_) { $total += $n }
          return $total;
        }

        $total_size = dir_walk('.', \&file_size, \&dir_size);

=test dir-walk-callbacks

        my $dir = shift || 'Mod';
        eval { require "dir_walk_callbacks" };
        use File::Find;

        sub file_size { -s $_[0] }

        sub dir_size {
          my $dir = shift;
          my $total = -s $dir;
          my $n;
          for $n (@_) { $total += $n }
          return $total;
        }

        my $s1 = dir_walk($dir, \&file_size, \&dir_size);
        my $s2;
        find({wanted => sub { $s2 += -s }, follow_fast => 1}, $dir);

        is($s1, $s2, "sizes match");

=endtest

The F<file_size> function says how to compute the size of a plain
file, given its name, and the F<dir_size> function says how to compute
the size of a directory, given the directory name and the sizes of its
contents.  

If we want the program to print out the size of every
subdirectory, the way the C<du>X<C<du> program|i> command does, we
add one line:

        sub file_size { -s $_[0] }

        sub dir_size {
          my $dir = shift;
          my $total = -s $dir;
          my $n;
          for $n (@_) { $total += $n }
*         printf "%6d %s\n", $total, $dir;
          return $total;
        }

        $total_size = dir_walk('.', \&file_size, \&dir_size);

This produces an output like this:

         4528 ./a
         4444 ./b
         5553 ./c/d
        11675 ./c
        24743 .

To get the function to produce the hash structure we saw earlier,  we
can supply the following pair of callbacks:

=startlisting dir-walk-sizehash

        sub file {
          my $file = shift;
          [short($file), -s $file];
        }

        sub short {
          my $path = shift;
          $path =~ s{.*/}{};
          $path;
        }

The file callback returns an array with the abbreviated name of the
file (no full path) and the file size. The aggregation is, as before,
performed in the directory callback:

        sub dir {
          my ($dir, @subdirs) = @_;
          my %new_hash;
          for (@subdirs) {      
            my ($subdir_name, $subdir_structure) = @$_;
            $new_hash{$subdir_name} = $subdir_structure;
          }
          return [short($dir), \%new_hash];
        }

=endlisting dir-walk-sizehash

The directory callback gets the name of the current directory, and a
list of name-value pairs that correspond to the subfiles and
subdirectories.  It merges these pairs into a hash, and returns a new
pair with the short name of the current directory and the newly
constructed hash for the curent directory.

=test dir-walk-sizehash 

        do "dir_walk_callbacks";
        do "dir-walk-sizehash";
        my $x = do "sizehash-output";
        chdir("Tests/TESTDIR");
        my $res = dir_walk(".", \&file, \&dir);
        $res = $res->[1];
        is_deeply($res, $x);

=endtest dir-walk-sizehash 




The simpler functions that we wrote before are still easy.  Here's the
recursive file lister.  We use the same function for files and for
directories:

        sub print_filename { print $_[0], "\n" }
        dir_walk('.', \&print_filename, \&print_filename);

Here's the dangling symbolic link detector:

        sub dangles { 
          my $file = shift;
          print "$file\n" if -l $file && ! -e $file;
        }
        dir_walk('.', \&dangles, sub {});

We know that a directory can't possibly be a dangling symbolic link,
so our directory function is the X<null function|d> that returns
immediately without doing anything.  If we had wanted, we could have
avoided this oddity, and its associated function-call overhead, as
follows:

=startlisting dir_walk_callbacks_defaults

        sub dir_walk {
          my ($top, $filefunc, $dirfunc) = @_;
          my $DIR;

          if (-d $top) {
            my $file;
            unless (opendir $DIR, $top) {
              warn "Couldn't open directory $code: $!; skipping.\n";
              return;
            }

            my @results;
            while ($file = readdir $DIR) {
              next if $file eq '.' || $file eq '..';
              push @results, dir_walk("$top/$file", $filefunc, $dirfunc);
            }
*           return $dirfunc ? $dirfunc->($top, @results) : () ;
          } else {
*           return $filefunc ? $filefunc->($top): () ;
          }
        }

=endlisting dir_walk_callbacks_defaults

=test dir-walk-callbacks-defaults 3

        my $dir = shift || 'Mod';
        eval { require "dir_walk_callbacks_defaults" };
        use File::Find;
        alarm(10);

        sub file_size { -s $_[0] }

        sub dir_size {
          my $dir = shift;
          my $total = -s $dir;
          my $n;
          for $n (@_) { $total += $n }
          return $total;
        }

        my $s1 = dir_walk($dir, \&file_size, \&dir_size);
        my $s2 = 0;
        find({wanted => sub { $s2 += -s }, follow_fast => 1}, $dir);
        is($s1, $s2, "sizes match");
        alarm(10);

        $s1 = 0;
        dir_walk($dir, sub { $s1 += -s $_[0] });
        $s2 = 0;
        find({wanted => sub { $s2 += -s if -f }, follow_fast => 1}, $dir);
        is($s1, $s2, "sizes of files only match");
        alarm(10);

        $s1 = dir_walk($dir, undef, \&dir_size);
        $s2 = 0;
        find({wanted => sub { $s2 += -s if -d }, follow_fast => 1}, $dir);
        is($s1, $s2, "sizes of dirs only match");
        

=endtest

This allows us to write C<dir_walk('.', \&dangles)> instead of
C<dir_walk('.', \&dangles, sub {})>.

As a final example, let's use F<dir_walk> in a slightly different
way, to manufacture a list of all the plain files in a file tree,
without printing anything:

        @all_plain_files = 
          dir_walk('.', sub { $_[0] }, sub { shift; return @_ });

The file function returns the name of the file it's invoked on.  The
directory function throws away the directory name and returns the list
of the files it contains.  What if a directory contains no files at
all?  Then it returns an empty list to F<dir_walk>, and this empty
list will be merged into the results list for the other directories at
the same level.

=note
You want to have a section about walking the file tree to produce a
data structure, and then generic tree-walking functions to operate on
the data structure.  Postpone this to chapters VII and VIII on
higher-order functions.
Introduce by asking what if you want to walk the directory twice and
do different operations each time?  Rereading the directories both
times is wasteful.

=section Functional vs. Object-Oriented Programming

Now let's back up a moment and look at what we did.  We had a useful
function, F<total_size>, which contained code for walking a directory
structure that was going to be useful in other applications also.  So
we made F<total_size> more general by pulling out all the parts that
related to the computation of sizes, and replacing them with calls to
arbitrary user-specified functions.  The result was F<dir_walk>.  Now,
for any program that needs to walk a directory structure and do
something, F<dir_walk> handles the walking part, and the argument
functions handle the `do something' part.  By passing the appropriate
pair of functions to F<dir_walk>, we can make it do whatever we want
to.  We've gained flexibility and the chance to reuse the F<dir_walk>
code by factoring out the useful part and parametrizing it with two
functional arguments.  This is the heart of the X<functional
programming style|i> functional style of programming.

X<Object-oriented programming|compared with functional style|(>
Object-oriented programming style gets a lot more press these days.
The goals of the OO style are the same as those of the functional
style: we want to increase the reusability of software components by
separating them into generally useful parts.

In an OO system, we could have transformed F<total_size>
analogously, but the result would have looked different.  We would
have made F<total_size> into an abstract base class of
directory-walking objects, and these objects would have had a method,
F<dir_walk>, which in turn would make calls to two undefined virtual
methods called C<file> and C<directory>.  (In C++ jargon, these are
called X<pure virtual methods|d>.)  Such a class wouldn't have been
useful by itself, because the C<file> and C<directory> methods would
be missing.  To use the class, you would create a subclass that
defined the C<file> and C<directory> methods, and then create objects
in the subclass.  These objects would all inherit the same C<dir_walk>
method.

In this case, I think the functional style leads to a lighter-weight
solution that is easier to use, and which keeps the parameter
functions close to the places they are used instead of stuck off in a
class file.  But the important point is that although the styles are
different, the decomposition of the original function into useful
components has exactly the same structure.  Where the functional style
uses functional arguments, the object-oriented style uses pure virtual
methods.  Although the rest of this book is about the functional style
of programming, many of the techniques will be directly applicable to
object-oriented programming styles also.  X<Object-oriented
programming|compared with functional style|)>

=Section HTML

I promised that recursion was useful for operating on hierarchically
defined data structures, and I used the file system as an example.
But it's a slightly peculiar example of a data structure, since we
normally think of data structures as being in memory, not on the disk.

What gave rise to the tree structure in the file system was the
presence of directories, each of which contains a list of other files.
Any domain that has items which include lists of other items will
contain tree structures.  An excellent example is HTML data.

HTML data is a sequence of elements and plain text.  Each element has
some content, which is a sequence of more elements and more plain
text.  This is a recursive description, analogous to the description
of the file system, and the structure of an HTML document is analogous
to the structure of the file system.

Elements are tagged with a X<HTML start tag|Ii>I<start tag>, which
looks like this:

        <font>

and a corresponding I<end tag>X<HTML end tag|Ii>, which looks like this:

        </font>

The start tag may have a set of I<attribute/value pairs>X<HTML
attribute/value pairs|Ii>, in which case it might look something like
this instead:

        <font size=3 color="red">

The end tag is the same in any case.  It never has any attribute/value
pairs.  

In between the start and end tags can be any sequence of HTML text,
including more elements, and also plain text.  Here's a simple example
of an HTML document:

        <h1>What Junior Said Next</h1>

        <p>But I don't <font size=3 color="red">want</font>
        to go to bed now!</p>

=auxtest htmlsample.pl

        my @lines = split /^/, qq{<h1>What Junior Said Next</h1>

        <p>But I don't <font size=3 color="red">want</font>
        to go to bed now!</p>};

        s/^\s+// for @lines;
        $HTML = join "", @lines;

        use HTML::TreeBuilder;
        $TREE = HTML::TreeBuilder->new;
        $TREE->ignore_ignorable_whitespace(0);
        $TREE->parse($HTML);
        $TREE->eof();

        __END__

=endtest 


This document has the following structure:

=startpicture html-tree

                                      (document)
                                 ,------'-'  `---.
                          ,-----'    ,-'          `--.
                   ,-----'         ,'                 `---.
                <h1>          (newlines)                 <p>
                  |                                   ,--'/`--.
                  |                               ,--'   /     `-.
                  |                           ,--'      /         `-.
        What Junior Said Next           But I don't  <font>  to go to bed now!
                                                       |
                                                       |
                                                       |
                                                      want


=endpicture html-tree


The main document has three components: the T<h1> element, with its
contents; the T<p> element, with its contents; and the blank space in
between.  The T<p> element, in turn, has three components: the
untagged text before the T<font> element; the T<font> element, with
its contents, and the untagged text after the T<font> element.  The
T<h1> element has one component, which is the untagged text C<What
Junior Said Next>.

Later on, in R<parsing|chapter>, we'll see how to build a parser for
HTML.  In the meantime, we'll look at a semi-standard module,
C<HTML::TreeBuilder>, which converts an HTML document into a tree
structure.

Let's suppose that the HTML data is already in a variable, say
C<$html>.  We use C<HTML::TreeBuilder> to transform the text into an
explicit tree structure like this:

        use HTML::TreeBuilder;
        my $tree = HTML::TreeBuilder->new;
        $tree->ignore_ignorable_whitespace(0);
        $tree->parse($html);
        $tree->eof();

(The F<ignore_ignorable_whitespace> method tells C<HTML::TreeBuilder>
that it's not allowed to discard certain whitespace, such as the
newlines after the T<h1> element, that are normally ignorable.)

Now C<$tree> represents the tree structure.  It's a tree of hashes;
each hash is a node in the tree and represents one element.  Each hash
has a C<_tag> key whose value is its tag name, and a C<_content> key
whose value is a list of the element's contents, in order; each item
in the C<_content> list is either a string, representing tagless text,
or another hash, representing another element.  If the tag also has
attribute-value pairs, they're stored in the hash directly, with
attributes as hash keys and the corresponding values as hash values.

So for example, the tree node that corresponds to the T<font> element
in the example looks like this:

        { _tag => "font",
          _content => [ "want" ],
          color => "red",
          size => 3,
        }

The tree node that corresponds to the T<p> element contains the
T<font> node, and looks like this:

        { _tag => "p",
          _content => [ "But I don't ",
                        { _tag => "font",
                          _content => [ "want" ],
                          color => "red",
                          size => 3,
                        },
                        " to go to bed now!",
                      ],
        }


It's not hard to build a function that walks one of these HTML trees
and `untags' all the text, stripping out the tags.  For each item in a
C<_content> list, we can recognize it as an element with the C<ref()>
function, which will yield true for elements (which are hash
references) and false for plain strings.

=startlisting untag_html

        sub untag_html {
          my ($html) = @_;
          return $html unless ref $html;   # It's a plain string

          my $text = '';
          for my $item (@{$html->{_content}}) {
            $text .= untag_html($item);
          }
            
          return $text;
        }

=endlisting untag_html

We check to see if the HTML item passed in is a plain string, and if
so we return it immediately.  If it's not a plain string, we assume
that it is a tree node, as described above, and iterate over its
content, recursively converting each item to plain text, accumulating
the resulting strings, and returning the result.  For our example,
this is:

        What Junior Said Next But I don't want to go to bed now!

=test untag-html 1

        eval {require "untag_html" };
        require "htmlsample.pl";
        my $text = untag_html($TREE);
        like($text, qr/^\s*What Junior Said Next But I don't want to go to bed now!\s*$/, "untagged text");

=endtest

(Incidentally, Sean Burke, the author of C<HTML::TreeBuilder>, tells
me that accessing the internals of the C<HTML::TreeBuilder> objects
this way is naughty, because he might change them in the future.
Robust programs should use the accessor methods that the module
provides.  In these examples, we will continue to access the internals
directly.)

We can learn from F<dir_walk> and make this function more useful by
separating it into two parts:  the part that processes an HTML tree,
and the part that deals with the specific task of assembling plain
text:

=listing walk_html

        sub walk_html {
          my ($html, $textfunc, $elementfunc) = @_;
          return $textfunc->($html) unless ref $html;   # It's a plain string

          my @results;
          for my $item (@{$html->{_content}}) {
            push @results, walk_html($item, $textfunc, $elementfunc);
          }
          return $elementfunc->($html, @results);
        }

=endlisting walk_html

This function has exactly the same structure as F<dir_walk>.  It
gets two auxiliary functions as arguments: a C<$textfunc> that computes
some value of interest for a plain text string, and a C<$elementfunc> that
computes the corresponding value for an element, given the element and the
values for the items in its content.  C<$textfunc> is analogous to the
C<$filefunc> from F<dir_walk>, and C<$elementfunc> is analogous to the
C<$dirfunc>.

Now we can write our untagger like this:

        
        walk_html($tree, sub { $_[0] },                
                         sub { shift; join '', @_ });


=test walk-html-untag 1

        eval {require "walk_html" };
        require "htmlsample.pl";
        
        $text = 
        walk_html($TREE, sub { $_[0] },                
                         sub { shift; join '', @_ });

        like($text, qr/^\s*What Junior Said Next But I don't want to go to bed now!\s*$/, "untagged text");

=endtest

The C<$textfunc> argument is a function which returns its argument
unchanged.  The C<$elementfunc> argument is a function which throws away the
element itself, then concatenates the texts that were computed for its
contents, and returns the concatenation.  The output is identical to
that of F<untag_html>.

Suppose we want a document summarizer, that prints out the text that
is inside of T<h1> tags, and throws away everything else:

        sub print_if_h1tag {
          my $element = shift;
          my $text = join '', @_;
          print $text if $element->{_tag} eq 'h1';
          return $text;
        }
        walk_html($tree, sub { $_[0] }, \&print_if_h1tag);

This is essentially the same as F<untag_html>, except that when the
element function sees that it is processing an T<h1> 
element, it prints out the untagged text.  

If we want the function to I<return> the header text instead of
printing it out, we have to get a little trickier.  Consider an
example like this:

        <h1>Junior</h1>

        Is a naughty boy.

We would like to throw away the text C<Is a naughty boy>, so that it
doesn't appear in the result.  But to F<walk_html>, it is just
another plain text item, which looks exactly the same as C<Junior>,
which we I<don't> want to throw away.  It might seem that we should
simply throw away everything that appears inside a non-header tag, but
that doesn't work:

        <h1>The story of <b>Junior</b></h1>

We mustn't throw away C<Junior> here, just because he's inside a T<b>
tag, because that T<b> tag is itself inside an T<h1> tag, and we want
to keep it.

We could solve this problem by passing information about the current
tag context from each invocation of F<walk_html> to the next, but it
turns out to be simpler to pass information back the other way.  Each
text in the file is either a `keeper', because we know it's inside an
T<h1> element, or a `maybe', because we don't.  Whenever we process an
T<h1> element, we'll promote all the `maybes' that it contains to
`keepers'.  At the end, we'll print the `keepers' and throw away the
`maybes'.


=startlisting extract_headers

        @tagged_texts = walk_html($tree, sub { ['MAYBE', $_[0]] }, 
                                         \&promote_if_h1tag);
        
        sub promote_if_h1tag {
          my $element = shift;
          if ($element->{_tag} eq 'h1') {
            return ['KEEPER', join '', map {$_->[1]} @_];
          } else {
            return @_;
          }
        }

        
The return value from F<walk_html> will be a list of labeled text
items.  Each text item is an anonymous array whose first element is
either C<MAYBE> or C<KEEPER>, and whose second item is a string.  The
plain text function simply labels its argument as a C<MAYBE>.  For the
string C<Junior>, it returns the labeled item C<['MAYBE', 'Junior']>;
for the string C<Is a naughty boy.>, it returns C<['MAYBE', 'Is a
naughty boy.]>.  

The element function is more interesting.  It gets an element and a list of
labeled text items.  If the element represents an T<h1> tag, the function
extracts all the texts from its other arguments, joins them together,
and labels the result as a C<KEEPER>.  If the element is some other kind,
the function returns its tagged texts unchanged.  These texts will be
inserted into the list of labeled texts that are passed to the element
function call for the element that is one level up; compare this with the
final example of F<dir_walk>, which returned a list of filenames in
a similar way.

Since the final return value from F<walk_html> is a list of labeled
texts, we need to filter them and throw away the ones that are still
marked C<MAYBE>.  This final pass is unavoidable.  Since the function
treats an untagged text item differently at the top level than it does
when it is embedded inside an T<h1> tag, there must be some part of
the process that understands when something is at the top level.
F<walk_html> can't do that because it does the same thing at every
level.  So we must build one final function to handle the top-level
processing:


        sub extract_headers {
          my $tree = shift;
          my @tagged_texts = walk_html($tree, sub { ['MAYBE', $_[0]] }, 
                                              \&promote_if_h1tag);
          my @keepers = grep { $_->[0] eq 'KEEPER' } @tagged_texts;
          my @keeper_text = map { $_->[1] } @keepers;
          my $header_text = join '', @keeper_text;
          return $header_text;
        }

=endlisting extract_headers

=test extract-headers 1

        eval {require "extract_headers" };
        eval {require "walk_html" };
        require "htmlsample.pl";
        my $text = extract_headers($TREE);
        like($text, qr/^\s*What Junior Said Next\s*$/, "headers");

=endtest


Or we could write it more compactly:

        sub extract_headers {
          my $tree = shift;
          my @tagged_texts = walk_html($tree, sub { ['MAYBE', $_[0]] }, 
                                              \&promote_if_h1tag);
          join '', map { $_->[1] } grep { $_->[0] eq 'KEEPER' } @tagged_texts;
        }

=subsection More Flexible Selection

We just saw how to extract all the T<h1>-tagged text in an HTML
document.  The essential procedure was F<promote_if_h1tag>.  But we
might come back next time and want to extract a more detailed summary,
which included all the text from T<h1>, T<h2>, T<h3>, and any other
T<h> tags present.  To get this, we'd need to make a small change
to F<promote_if_h1tag> and turn it into a new function:

        sub promote_if_h1tag {
          my $element = shift;
*         if ($element->{_tag} =~ /^h\d+$/) {
            return ['keeper', join '', map {$_->[1]} @_];
          } else {
            return @_;
          }
        }

But if F<promote_if_h1tag> is more generally useful than we first
realized, it will be  a good idea to factor out the generally useful
part.    We can do that by parametrizing the part that varies:

=startlisting promote_if

        sub promote_if {
*         my $is_interesting = shift;          
          my $element = shift;
*         if ($is_interesting->($element->{_tag}) {
            return ['keeper', join '', map {$_->[1]} @_];
          } else {
            return @_;
          }
        }

=endlisting promote_if

Now instead of writing a special function, F<promote_if_h1tag>, we can
express the same behavior as a special case of F<promote_if>.
Instead of the following:

          my @tagged_texts = walk_html($tree, sub { ['maybe', $_[0]] }, 
                                              \&promote_if_h1tag);


we can use this:

=contlisting promote_if

          my @tagged_texts = walk_html($tree, 
                                       sub { ['maybe', $_[0]] }, 
                                       sub { promote_if(
                                               sub { $_[0] eq 'h1' },
                                               $_[0])
                                       });
        

=endlisting promote_if

=note
OK, don't do this following section yet.  Maybe save it for the HOF chapter?
It's tempting to do it here, but what we would really want is
a function factory that returns an anonymous closure with
$is_interesting bound to the appropriate predicate.

We'll see a tidier way to do this in R<currying|chapter>.

=section When Recursion Blows Up

Sometimes a problem appears to be naturally recursive, and then the
recursive solution is grossly inefficient.  A very simple example
arises when you want to compute Fibonacci numbers.  This is a rather
unrealistic example, but it has the benefit of being very simple.
We'll see a more practical example of the same thing in 
R<partitioning|section>.

=subsection Fibonacci Numbers

X<Fibonacci numbers|d> are named for X<Leonardo of Pisa>, whose
nickname was X<Fibonacci>, who discussed them in the 13th century in
connection with a mathematical problem about rabbits.  Initially, you
have one pair of baby rabbits.  Baby rabbits grow to adults in one
month, and the following month they produce a new pair of baby
rabbits, making two pair:

                        Pairs of                Pairs of                Total
        Month           Baby rabbits            Adult Rabbits           Pairs
          1               1                       0                       1
          2               0                       1                       1
          3               1                       1                       2

The following month, the baby rabbits grow up and the adults produce a
new pair of babies:

          4               1                       2                       3

The month after that, the babies grow up, and the two pairs of adults
each produce a new pair of babies:

          5               2                       3                       5

Assuming no rabbits die, and rabbit production continues, how many
pairs of rabbits are there in each month?

Let's let M<A(n)> be the number of pairs of adults alive in month V<n>
and M<B(n)> be the number of pairs of babies alive in month V<n>.  The
total number of pairs of rabbits alive in month V<n>, which we'll call
M<T(n)>, is therefore M<A(n) + B(n)>.

        T(n) = A(n)   + B(n)

It's also not hard to see that  the number of
baby rabbits one month is equal to the number of adult rabbits the
previous month, because each pair of adults gives birth to one pair of
babies.   In symbols, this is M<B(n) = A(n-1)>.  Substituting into the
formula above, we have:

        T(n) = A(n)   + A(n-1)


It's also not hard to see that each month, the number of adult rabbits
is equal to the total number of rabbits from the previous month,
because the babies from the previous month grow up and the adults from
the previous month are still alive.  In symbols, this is M<A(n) =
T(n-1)>.  Substituting into the previous equation, we get:

        T(n) = T(n-1) + T(n-2)

So the total number of rabbits in month V<n> is the sum of the number
of rabbits in months M<n-1> and M<n-2>.  Armed with this formula, we
can write down the function to compute the Fibonacci numbers:

=listing fib

        # Compute the number of pairs of rabbits alive in month n
        sub fib {
          my ($month) = @_;
          if ($month < 2) { 1 }
          else {
              fib($month-1) + fib($month-2);
          }
        } 

=endlisting fib

=test fib 14

        eval { require "fib" };
        my @fib = (1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377);
        for (0..$#fib) {
          is(fib($_), $fib[$_], "fib element $_");
        }

=endtest

This is perfectly straightforward, but it has a problem: except for
small arguments, it takes forever.N<One of the technical reviewers
objected that this was an exaggeration, and it is.  But I estimate
that calculating C<fib(100)> by this method would take about 2,241,937
billion billion years, which is close enough.> If you ask for
C<fib(25)>, for example, it needs to make recursive calls to compute
C<fib(24)> and C<fib(23)>.  But the call to C<fib(24)> I<also> makes a
recursive call to C<fib(23)>, as well as another to compute
C<fib(22)>.  Both calls to C<fib(23)> will I<also> call C<fib(22)>,
for a total of three times.  It turns out that C<fib(21)> is computed
five times, C<fib(20)> is computed eight times, and C<fib(19)> is
computed 13 times.

All this computing and recomputing has a heavy price.  On my small
computer, it takes about four seconds to compute C<fib(25)>; it makes
242,785 recursive calls while doing so.  It takes about 6.5 seconds to
compute C<fib(26)>, and makes 392,835 recursive calls, and about 10.5
seconds to make the 635,621 recursive calls for C<fib(27)>.  It takes
as long to compute C<fib(27)> as to compute C<fib(25)> and C<fib(26)>
put together, and so the running time of the function increases
rapidly, more than doubling every time the argument increases by
2.N<In fact, each increase of 2 in the argument increases the running
time by a factor of about 2.62.>

The running time blows up really fast, and it's all caused by our
repeated computation of things that we already computed.  Recursive
functions occasionally have this problem, and there's an easy solution
for it, which we'll see in R<memoizing|chapter>.

=subsection Partitioning

Fibonacci numbers are rather abstruse, and it's hard to find simple
realistic examples of programs that need to compute them.

=note Another possible application:  you are doing mass spectrometry.
You know the total mass of a molecule of the substance you are
analyzing.  You want to know its chemical composition.  Make a list of
atomic weights of atoms that might be included, and try to find a
selection of them that adds up to the target total mass.

Here's a somewhat more realistic example.  We have some valuable
items, which we'll call `treasures', and we want to divide them evenly
between two people.  We know the value of each item, and we would like
to ensure that both people get collections of items whose total value
is the same.  (Or, to recast the problem in a more mundane light: the
list of numbers represents the weight of the various groceries you
bought today, and since you're going to carry them home with one bag
in each hand, you want to distribute the weight evenly.)
 
To convince yourself that this can be a tricky problem, try dividing
up a set of ten items that have these dollar values:

        $9, $12, $14, $17, $23, $32, $34, $40, $42, and $49 

Since the total value of the items is $272, each person will have to
receive items totalling $136.   Then try:

        $9, $12, $14, $17, $23, $32, $34, $40, $38, and $49 

Here I replaced the $42 item with a $38 item, so each person will have
to receive items totalling $134.

This problem is called the X<partition problem|d>.  We'll generalize
the problem a little: instead of trying to divide a list of treasures
into two equal parts, we'll try to find some share of the treasures
whose total value is a given target amount.  Finding an even division
of the treasures is the same as finding a share whose value is half
of the total value of all the treasures; then the other share is the
rest of the treasures, whose total value is the same.  

If there is no share of treasures that totals the target amount, our
function will return C<undef>.

=listing find_share.pl

        sub find_share {
          my ($target, $treasures) = @_;
          return [] if $target == 0;
          return    if $target < 0 || @$treasures == 0;

We take care of some trivial cases first.  If the target amount is
exactly zero, then it's easy to produce a list of treasures that total
the target amount: the empty list is sure to have value zero, so we
return that right away.

If the target amount is less than zero, we can't possibly hit it,
because treasures are assumed to have positive value.  In this case no
solution can be found and we can immediately return failure.  If there
are no treasures, we know we can't make the target, since we already
know the target is larger than zero; we fail immediately.

Otherwise, the target amount is positive, and we will have to do
some real work:

          my ($first, @rest) = @$treasures;
          my $solution = find_share($target-$first, \@rest);
          return [$first, @$solution] if $solution;
          return         find_share($target       , \@rest);
        }


=endlisting find_share.pl

=test find-share 3

        eval { require "find_share.pl" };

        $share = find_share(136, [9, 12, 14, 17, 23, 32, 34, 40, 42, 49]);
        ok($share, "share for first set");
        $sum = 0;
        $sum += $_ for @$share;
        is($sum, 136, "first share sum");

        $share = find_share(134, [9, 12, 14, 17, 23, 32, 34, 40, 38, 49]);
        ok(!$share, "share for second set");

=endtest

=note The partition function in ~/FPP/partition/ is simpler and better

Here we copy the list of treasures, and then remove the first treasure
from the list.  This is because we're going to consider the simpler
problem of how to divide up the treasures without the first treasure.
There are two possible divisions: either this first treasure is in the
share we're computing, or it isn't.  If it is, then we have to find a
subset of the rest of the treasures whose total value is C<$target -
$first>.  If it isn't, then we have to find a subset of the rest of
the treasures whose total value is C<$target>.  The rest of the code
makes recursive calls to C<find_share> to investigate these two cases.
If the first one works out, it returns a solution that includes the
first treasure; if the second one works out, it returns a solution
that omits the first treasure; if neither works out, it returns
C<undef>.

Here's a trace of a sample run.  We'll call C<find_share(5, [1, 2, 4, 8])>:

        Share so far    Total     Target   Remaining
                        so far             treasures

                        0         5        1 2 4 8  

None of the trivial cases apply---the target is neither negative nor
zero, and the remaining treasure list is not empty---so the function
tries allocating the first item, 1, to the share; it then looks for
some set of the remaining items that can be made to add up to 4:

        Share so far    Total     Target   Remaining
                        so far             treasures

        1               1          4         2 4 8

The function will continue investigating this situation until it is
forced to give up.  

The function then allocates the first remaining item, 2, toward the
share of 4, and makes a recursive call to find some set of the last 2
elements that add up to 2.  

        1 2             3          2           4 8

Let's call this "situation V<a>".  The function will continue
investigating this situation until it concludes that situation V<a> is
hopeless.  It tries allocating the 4 to the share, but that overshoots
the target total:

        1 2 4           7         -2             8

so it backs up and tries continuing from situation V<a> I<without>
allocating the 4 to the share:

        1 2             3          2             8

The share is still wanting, so the function allocates the next item,
8, to the share, which obviously overshoots:

        1 2 8           11        -6 

Here we have C<$target \< 0>, so the function fails, and tries
omitting 8 instead.  This doesn't work either, as it leaves the share
short by 2 of the target, with no items left to allocate.  

        1 2             3          2

This is the C<if (@$treasures == 0) { return undef }> case.

The function has tried every possible way of making situation V<a>
work; they all failed.  It concludes that allocating both 1 and 2 to
the share doesn't work, and backs up and tries omitting 2 instead:

        1               1          4           4 8

It now tries allocating 4 to the share:

        1 4             5          0             8

Now the function has C<$target == 0>, so it returns success.

The idea of ignoring the first treasure and looking for a solution
among the remaining treasures, thus reducing the problem to a simpler
case, is natural.  A solution without recursion would probably end up
duplicating the underlying machinery of the recursive solution, and
simulating the behavior of the function call stack manually.

Now solving the partition problem is easy; it's a call to
F<find_share>, which finds the first share, and then some extra work
to compute the elements of the original array that are not included in
the first share:

=listing partition.pl

        sub partition {
          my $total = 0;
          for my $treasure (@_) {
            $total += $treasure;
          }

          my $share_1 = find_share($total/2, [@_]);
          return unless defined $share_1;

First the function computes the total value of all the treasures.
Then it asks F<find_share> to compute a subset of the original
treasures whose total value is exactly half.  If F<find_share> returns
an undefined value, there was no equal division, so F<partition>
returns failure immediately.  Otherwise, it will set about computing
the list of treasures that are I<not> in C<$share_1>, and this will be
the second share.
        
          my %in_share_1;
          for my $treasure (@$share_1) {
            ++$in_share_1{$treasure};
          }

          for my $treasure (@_) {
            if ($in_share_1{$treasure}) {
              --$in_share_1{$treasure};
            } else {
              push @$share_2, $treasure;
            }
          }
          
The function uses a hash to count up the number of occurrences of each
value in the first share, and then looks at the original list of
treasures one at a time.  If it saw that a treasure was in the first
share, it checks it off; otherwise, it put the treasure into the list
of treasures that make up share 2.

          return ($share_1, $share_2);
        }

When it's done, it returns the two lists of treasures.

=endlisting partition.pl

=test partition 5

        eval {require "partition.pl"};
        eval {require "find_share.pl"};

        ($s1, $s2) = partition(9, 12, 14, 17, 23, 32, 34, 40, 42, 49);
        ok($s1, "partitioned first set");
        $s = 0;
        $s += $_ for @$s1;
        is($s, 136, "first share sum");
        $s = 0;
        $s += $_ for @$s2;
        is($s, 136, "second share sum");

        ($s1, $s2) = partition(9, 12, 14, 17, 23, 32, 34, 40, 38, 49);
        ok(!$s1, "second set has no partition");
        ok(!$s2, "second set has no partition");

=endtest

There's a lot of code here, but it mostly has to do with splitting up
a list of numbers.  The key line is the call to C<find_share>, which
actually computes the solution; this is C<$share_1>.  The rest of the
code is all about producing a list of treasures that I<aren't> in
C<$share_1>; this is C<$share_2>.  

The C<find_share> function, however, has a problem: it takes much too
long to run, especially if there is no solution.  It has essentially
the same problem as C<fib> did: it repeats the same work over and
over.  For example, suppose it is trying to find a division of C<1 2 3
4 5 6 7> with target sum 14.  It might be investigating shares that
contain 1 and 3, and then look to see if it can make C<5 6 7> hit the
target sum of 10.  It can't, so it will look for other solutions.
Later on, it might investigate shares that contain 4, and again look to
see if it can make C<5 6 7> hit the target sum of 10.  This is a waste
of time; C<find_share> should remember that C<5 6 7> cannot hit a
target sum of 10 from the first time it investigated that.

We will see in R<memoizing|chapter> how to fix this.



=Stop


 LocalWords:  Edouard numberedlist endnumberedlist startlisting hanoi subfiles
 LocalWords:  endlisting endbulletedlist lister



