

=chapter Declarative Programming

=note need discussion of declarative programming.  Why do you have to
specify the algorithm?  You should just be able to specify the
constraints, and have it figure out how to calculate them.

Beginning programmers often wish for a way to just tell the computer
what they want, and have the computer figure out how to do it.
Declarative programming is an attempt to do that.  The idea is that
the programmer will put in the specifications for the value to be
computed, and the computer will use the appropriate algorithm.

Nobody knows how to do this in general, and it may turn out to be
impossible.  But there are some interesting results one can get in
specific problem domains.  Regular expressions are a highly successful
example of declarative programming.  You write a pattern which
represents the form of the text you are looking for, and then sit back
and let the regex engine figure out the best way of locating the
matching text.

Searching in general lends itself to declarative methods: the
programmer specifies what they are searching for, and then lets a
generic heuristic searching algorithm look for it.  Database query
languages are highly visible examples of this; consider X<SQL>, or the
query language of R<Database Query Parsing|chapter>.  The programming
language X<Prolog> is an extension of this idea to allow general
computations.  We've seen searching in some detail already, so in this
chapter we'll look at some other techniques and applications of
declarative programming.

=Section Constraint Systems

Suppose you wrote a program to translate Fahrenheit temperatures into
Celsius:

        sub f2c {
          my $f = shift;
          return ($f - 32) * 5/9;
        }

Now you'd like to have a program to perform the opposite conversion,
from Celsius to Fahrenheit.  Although this calculation is in some
sense the same, we have to write completely new code, from scratch:

        sub c2f {
          my $c = shift;
          return 9/5 * $c + 32;
        }

The idea of constraint systems is to permit the computer to be able to
run this sort of calculation in either direction.

=section Local Propagation Networks

One approach that seems promising is to distribute the logic for the
calculation amongst several objects in a X<constraint network|d> like
this:

=picture constraint-network-F-to-C

        +---+   i
        | f +---.
        +---+    `---+---+   k
                     | - +---.          m
        +---+    ,---+---+    `---+---+   +---+
        | 32+---'                 | * +---+ c |
        +---+   j    +---+    ,---+---+   +---+
                     |5/9+---'
                     +---+    l

=endpicture constraint-network-F-to-C

There is a node in the network for each constant, variable, and
operator.  Lines between the nodes communicate numeric values between
nodes, and are called X<wires|d>.  A node can set the value on one of
its wires; this sends a notification to the node at the other end of
the wire that the value has changed.  Because values are propagated
only from nodes to their adjacent wires to the nodes attached at the
other end of the wire, the network is called a X<local propagation
network|d>.

A constant node has one incident wire, and when the network is started
up, the constant node immediately tries to set its wire to the
appropriate constant value.  In the network above, wire I<j> initially
has the value 32, and wire I<l> initially has the value 5/9.

The nodes marked with variable names, C<c> and C<f> in this example,
are input-output nodes.  Initially, they do nothing, but the user of
the program has the option to tell them to set their incident wires to
certain values; that is how the user sends input into the network.  If
an input-output node notices that its incident wire has changed value,
it announces that fact to the user; that's how output is emitted from
the network.

We'll use the network above to calculate the Celsius equivalent for
212 Fahrenheit.  We start by informing the C<f> node that we want V<f>
to have the value 212.  The C<f> node obliges by setting the value of
wire I<i> to 212.  

The change on wire I<i> wakes up the attached C<-> node, which notices
that both of its input wires now have values: wire I<i> has the value
212 and wire I<j> has the value 32.  The C<-> node performs
subtraction; it subtracts 32 from 212 and sets its output wire I<k> to
the difference, 180.  

The change on wire I<k> wakes up the attached C<*> node, which notices
that both of I<its> input wires now have values: wire I<k> has the
value 180 and wire I<l> has the value 5/9.  The C<*> node performs
multiplication; it multiplies 180 from 5/9 and sets its output wire
I<m> to the product, 100.

The change on wire I<m> wakes up the attached input-output node C<c>,
which notices that its input wire now has the value 100.  It announces
this fact to the user, saying something like

        c = 100

which is in fact the Celsius equivalent of 212 Fahrenheit.

What makes this interesting is that the components are so simple and
so easily reversible.  There's nothing about this process that
requires that the calculation proceed from left to right.  Let's
suppose that instead of calculating the Celsius equivalent of 212
Fahrenheit, we wanted the Fahrenheit equivalent of 37 Celsius.  We
begin by informing the C<c> input-output node that we want the value
of V<c> to be 37.  The C<c> node will set wire I<m> to value 37.  This
will wake up the C<*> node, which will notice that two of its three
incoming wires have values: I<l> has value 5/9 and I<m> has value 37.
It will then conclude that wire I<k> must have the value M<37/(5/9)>
= 66.6, and set wire I<k> accordingly.

The change in the value of wire I<k> will wake up the attached C<->
node, which will notice that the subtrahend I<j> is 32 and the
difference I<k> is 66.6, and conclude that the minuend, I<i>, must
have the value 98.6.  It will then set I<i> to 98.6.  This will wake
up the attached C<f> node, which will announce something like

        f = 98.6

which is indeed the Fahrenheit equivalent of 37 Celsius.

It's no trouble to attach more input-output nodes to the network to
have it calculate several things at once.  For example, we might
extend the network like this:

=picture constraint-network-F-to-C-to-K

        +---+   i
        | f +---.
        +---+    `---+---+   k
                     | - +---.           
        +---+    ,---+---+    `---+---+   +---+
        | 32+---'                 | * +-+-+ c |
        +---+   j    +---+    ,---+---+ | +---+
                     |5/9+---'          |
                     +---+              +---------.          p
                                      m            '---+---+   +---+
                                                       | - +---+ k |
                                       +------+    ,---+---+   +---+
                                       |273.15+---'
                                       +------+    n


=endpicture constraint-network-F-to-C-to-K


Now setting C<c> to 37 causes values to propagate in two directions.
The 37 will propagate left along wire I<m> as before, eventually
causing node C<f> to announce the value 98.6.  But wire I<m> now has
three ends, and the 37 will also propagate rightward, causing the
C<-> node to set wire I<p> to 310.15, which is the value announced by
the C<k> node.  The output looks something like

        f = 98.6
        k = 310.15

which are the Fahrenheit and kelvin equivalents of 37 Celsius.
Alternatively, we could have set node C<k> to 0, which would have
resulted in wire I<m> being set to -273.15.  Node C<c> would announce
that fact, and the C<*> node would also take note; eventually wire
I<i> would be set to -459.67, and the output from the entire network
would be

        c = -273.15
        f = -459.67

which are the Celsius and Fahrenheit temperatures of X<absolute zero>.

=subsection Implementing a Local Propagation Network

Clearly we will have two kinds of objects: wires and nodes.  Wires
store values.  When a wire's value is set by a node, the wire
remembers the value and also which node was responsible for setting
it.  This is so that the node can change or retract the value later.
If the wire didn't remember the original source of its information, it
wouldn't be able to distinguish the situation where the source changed
its mind from the situation in which it was being given conflicting
information.  We'd like it to diagnose the latter but not the former.

=note this is the code from network/network15.pl

=startlisting Wire.pm

        package Wire;

        my $N = 0;
        sub new {
          my ($class, $name) = @_;
          $name ||= "wire" . ++$N;
          bless { N => $name, S => undef, V => undef, A => [] } => $class;
        }

The C<$name> here is used for debugging purposes; we can supply a name
to the constructor, or else the constructor will auto-generate
one. C<V> will be the stored value, initially undefined.  C<S> will be
the identity of the node that supplied the stored value ('settor'),
also initially undefined.  C<A> is a list of attached nodes.  When the
wire's value changes, it will notify the attached nodes. 

It's common to need to manufacture several wires at once, so here's a
utility function that does that:

        sub make {
          my $class = shift;
          my $N = shift;
          my @wires;
          push @wires, $class->new while $N--;
          @wires;
        }

C<Wire-\>make(5)> returns a list of five new wires.

The principal C<Wire> method is C<set>, which assigns a value to a
wire:

        sub set {
          my ($self, $settor, $value) = @_;
          if (! $self->has_settor || $self->settor_is($settor)) {
            $self->{V} = $value;
            $self->{S} = $settor;
            $self->notify_all_but($settor, $value);
          } elsif ($self->has_settor) {
            unless ($value == $self->value) {
              my $v = $self->value;
              my $N = $self->name;
              warn "Wire $N inconsistent value ($value != $v)\n";
            }
          }
        }

The normal case is if the wire had no value before (C<!
$self-\>has_settor>) or if the old settor is changing the value, in
which case the wire remembers the new value and the settor, and then
calls F<notify_all_but> to notify the other attached nodes that the
value has changed.

The other case of interest occurs when some other node, not the
original settor, tries to notify the wire of a new value.  In this
case, if the old and new values are the same, all is well, and nothing
need be done.  But if the values differ, the wire should issue a
diagnostic message.  This might occur, for example, if we set the
Fahrenheit input of a network to 212, and then tried to set the
Celsius input to something other than 100.

The F<notify_all_but> function takes care of notifying the attached
nodes of a change in value:

        sub notify_all_but {
          my ($self, $exception, $value) = @_;
          for my $node ($self->attachments) {
            next if $node == $exception;
            $node->notify;
          }
        }

When a wire is set to a certain value, it notifies all its attached
nodes of the change I<except> the one that set the value in the first
place; this avoids infinite loops.

The accessors for attachments are trivial:

        sub attach {
          my ($self, @nodes) = @_;
          push @{$self->{A}}, @nodes;
        }

        sub attachments { @{$_[0]->{A}} }


The other  C<Wire> accessor methods are similarly trivial:

        sub name {
          $_[0]{N} || "$_[0]";
        }

        sub settor { $_[0]{S} }
        sub has_settor { defined $_[0]{S} }
        sub settor_is { $_[0]{S} == $_[1] }

The only unusual method here is F<settor_is>.
C<$wire-\>settor_is($node)> asks if the wire's settor is C<$node>, and
returns true if so.  Note that objects can be compared for identity
with the C<==> operator; this actually compares the underlying machine
addresses at which the objects are stored.

The opposite of F<set> is F<revoke>, which it allows the settor node
to revoke a previously set value:

        sub revoke {
          my ($self, $revoker) = @_;
          return unless $self->has_value;
          return unless $self->settor_is($revoker);
          undef $self->{V};
          $self->notify_all_but($revoker, undef);
          undef $self->{S};
        }

        1;

As far as the attached nodes are concerned, a revocation of a value is
the same as setting the value to C<undef>.  

The final methods in the C<Wire> class are the ones that query a wire
for its current value.  The code is short, but a little tricky.
They're I<almost> straightforward accessors, simply returning the
value of C<$self-\>{V}> or its definedness:

        sub value { my ($self, $querent) = @_;
                    return if $self->settor_is($querent);
                    $self->{V};
                  }

        sub has_value { my ($self, $querent) = @_;
                        return if $self->settor_is($querent);
                        defined $_[0]{V};
                      }

The exception is if the wire's settor is asking about the value.  In
this case, the wire returns undef, indicating that it doesn't know.
This is necessary to support revocation of values.  To see the reason
for this, consider an adder node with addend wires V<A> and V<B>, and
sum wire V<C>.  Suppose V<A> and V<B> have been set to 1 and 2 by some
other components; the adder node itself then sets the sum V<C> to 3.  Now
suppose the value of V<B> is revoked.  The adder node receives a
notification and inspects the values of the wires.  If not for the
special case in F<value>, it would learn that V<A> had value 1 and
V<C> had value 3, and conclude that V<B> must have value 2, a
conclusion that isn't actually warranted.  To avoid this, wire V<C>
will report a value of 3 to any I<other> node that asks, but if the
adder itself asks, the wire will say C<undef>, meaning "If you're not
sure what my value is supposed to be, then I'm not sure either."

=endlisting Wire.pm

We'll use an abstract class to represent nodes.  We could subclass
this to make the various node types, but since most of the node
behavior is the same in all node types, we won't bother; that variable
part of the behavior can be specified by supplying an anonymous
function which will be stored in the node object.  

Here's the generic constructor:

=startlisting Node.pm

        package Node;
        my %NAMES;
        sub new {
          my ($class, $base_name, $behavior, $wiring) = @_;
          my $self = {N => $base_name . ++$NAMES{$base_name}, 
                      B => $behavior,
                      W => $wiring,
                     };
          for my $wire (values %$wiring) {
            $wire->attach($self);
          }
          bless $self => $class;
        }

The constructor's first argument is a node type name, such as
C<adder>, which is used to construct a name for debugging.  
The important arguments are the other two.  C<$behavior> is a function
which is invoked when one of the attached wires changes values; it is
the responsibility of C<$behavior> to calculate new values and to
propagate them through the network.  C<$wiring> is a hash whose values
are the wires themselves; each wire is associated with a name, through
which C<$behavior> will access it.

The primary method is F<notify>.  When a node is notified that a wire
has changed, it builds a hash of its current wire values, and passes
the hash to its behavior function:

        sub notify {
          my $self = shift;
          my %vals;
          while (my ($name, $wire) = each %{$self->{W}}) {
            $vals{$name} = $wire->value($self);
          }
          $self->{B}->($self, %vals);
        }

The rest of the C<Node> methods are simple utilities, intended to be
used by the behavior function:

        sub name {
          my $self = shift;
          $self->{N}|| "$self";
        }

        sub wire { $_[0]{W}{$_[1]} }

F<wire> takes a name and returns the associated wire object.

        sub set_wire {
          my ($self, $wire, $value) = @_;
          my $wire = $self->wire($wire);
          $wire->set($self, $value);
        }

        sub revoke_wire {
          my ($self, $wire) = @_;
          my $wire = $self->wire($wire);
          $wire->revoke($self);
        }

=endlisting Node.pm

We're finally at the meat of the program; we're ready to see the
components themselves.  Here's the behavior function for an adder:

        {
          my $adder = sub {
            my ($self, %v) = @_;
            if (defined $v{A1} && defined $v{A2}) {
              $self->set_wire('S', $v{A1} + $v{A2});
            } else {
              $self->revoke_wire('S');
            }
            if (defined $v{A1} && defined $v{S}) {
              $self->set_wire('A2', $v{S} - $v{A1});
            } else {
              $self->revoke_wire('A2');
            }
            if (defined $v{A2} && defined $v{S}) {
              $self->set_wire('A1', $v{S} - $v{A2});
            } else {
              $self->revoke_wire('A1');
            }
          };

          # continues...

An adder has three wires: two addends, named C<A1> and C<A2>, and a
sum, named C<S>.  When it receives a notification, it checks to see if
C<A1> and C<A2> both have values; if so, it sets C<S> to be the sum;
if not, it revokes any value that it might have given to C<S>.  Note
that if C<S> has no value, or if some other component was responsible
for setting C<S>, the revocation is harmless, because of our
definition of the F<Wire::revoke> method.  There are two other blocks
of code for inferring the two addends from the sum.

The function to build an adder node gets three wires as arguments and
invokes F<Node::new> to build a node with those three wires and the
adder behavior function:

          # continued...

          sub new_adder {
            my ($a1, $a2, $s) = @_;
            Node->new('adder',
                      $adder,
                      { A1 => $a1, A2 => $a2, S => $s });
          }
        }


The behavior function for a multiplier node is a little more
complicated.  Not only does it need to infer a product from the two
factors, and vice versa, but when a factor is 0, it can infer the product
even without the other factor:

        {
          my $multiplier = sub {
            my ($self, %v) = @_;
            if (defined $v{F1} && defined $v{F2}) {
              $self->set_wire('P', $v{F1} * $v{F2});
            } elsif (defined $v{F1} && $v{F1} == 0) {
              $self->set_wire('P', 0);
            } elsif (defined $v{F2} && $v{F2} == 0) {
              $self->set_wire('P', 0);
            } else {
              $self->revoke_wire('P');
            }

          # continues...

The price of this free inference, however, is that the wires can be in
an inconsistent state, which corresponds to a division by zero.  If
one factor is zero while the product is nonzero, the node won't be
able to reason backwards, and will become upset:

          # continued...

            if (defined $v{F1} && defined $v{P}) {
              if ($v{F1} != 0) {
                $self->set_wire('F2', $v{P} / $v{F1});
              } elsif ($v{P} != 0) {
                warn "Division by zero\n";
              }
            } else {
              $self->revoke_wire('F2');
            }

            if (defined $v{F2} && defined $v{P}) {
              if ($v{F2} != 0) {
                $self->set_wire('F1', $v{P} / $v{F2});
              } elsif ($v{P} != 0) {
                warn "Division by zero\n";
              }
            } else {
              $self->revoke_wire('F1');
            }

          };

          # continues...

The function for building a multiplier node, F<new_multiplier>, is
just like F<new_adder>:

          # continued...

          sub new_multiplier {
            my ($f1, $f2, $p) = @_;
            Node->new('multiplier', $multiplier,
                      { F1 => $f1, F2 => $f2, P => $p });
          }
        }

We could go on and build a subtraction node, but there's no need.
Here's a typical subtraction node:

=picture constraint-network-subtraction

           A ---.
                 `---+---+   
                     | - +--- C 
                 ,---+---+    
           B ---'               


=endpicture constraint-network-subtraction

This network fragment expresses the constraint M<A - B = C>.  But
that's the same as M<C + B = A>, so this network expresses the same
thing:

=picture constraint-network-addition

           C ---.
                 `---+---+   
                     | + +--- A
                 ,---+---+    
           B ---'               

=endpicture constraint-network-addition

With this transformation, our Fahrenheit-to-Celsius network becomes

=picture constraint-network-F-to-C-addition

                     +---+     i
                     | 32+---.          j
                     +---+    '---+---+   +---+
                                  | + +---+ f |
                              ,---+---+   +---+
                            ,'
                         k  |
                            '.          m
                              `---+---+   +---+
                                  | * +---+ c |
                     +---+    ,---+---+   +---+
                     |5/9+---'
                     +---+    l

=endpicture constraint-network-F-to-C-addition

But for convenience, we could define

          # S - M = D
          sub new_subtractor {
            my ($s, $m, $d) = @_;
            new_adder($d, $m, $s);
          }

          # V / S = Q
          sub new_divider {
            my ($v, $s, $q) = @_;
            new_multiplier($q, $s, $v);
          }

if we wanted.  

Now all we need are constant nodes and input-output nodes.  Constants,
as you would expect, are very simple:

        sub new_constant {
          my ($val, $w) = @_;
          my $node = Node->new('constant',
                               sub {},
                               {'W' => $w},
                              );
          $w->set($node, $val);
          $node;
        }

The two arguments here are C<$val>, the constant value, and C<$w>, the
outgoing wire.  The behavior function is trivial and does nothing.
The only fine point is that the constructor needs to notify the
attached wire of the outgoing constant value immediately after
constructing the node, before anything else happens in the network.

Most of the code for IO nodes is  for announcing changes in values on
the one attached wire.  C<$announce> is a curried function.  Its
argument is the name of the IO node, and it returns a behavior
function for that node:

        {
          my $announce = sub {
            my $name = shift;
            sub {
              my ($self, %val) = @_;
              my $v = $val{W};
              if (defined $v) {
                print "$name : $v\n";
              } else {
                print "$name : no longer defined\n";
              }
            };
          };

          # continues...

The IO node itself is an ordinary node with this announcing behavior:

          # continued...

          sub new_io {
            my ($name, $w) = @_;
            Node->new('io',
                      $announce->($name),
                      { W => $w });
          }
        }


There are two utility functions exposed to the main program for
setting and revoking the values of IO nodes:

        sub input {
          my ($self, $value) = @_;
          $self->wire('W')->set($self, $value);
        }

        sub revoke {
          my $self = shift;
          $self->wire('W')->revoke($self);
        }

We can now build local propagation networks:

=note optional names list after number arg in ->make call
Then "Wire wire3 inconsistent"  becomes "Wire k inconsistent".

        my ($F, $C);
        { my ($i, $j, $k, $l, $m) = Wire->make(5);
          $F = new_io('Fahrenheit', $i);
          $C = new_io('Celsius', $m);
          new_constant(32, $j);
          new_constant(5/9, $l);
          new_adder($i,$k,$j);
          new_multiplier($k,$l,$m);
        }

And now we can use the network to calculate values:

        input($F, 212);
*               Celsius : 100
        input($F, 32);
*               Celsius : 0
        revoke($F);
*               Celsius : no longer defined
        input($C, 37);
*               Fahrenheit : 98.6
        input($F, 100);
*               Wire wire3 inconsistent value (100 != 98.6)
        revoke($C);
*               Fahrenheit : no longer defined
        input($F, 100);
*               Celsius : 37.7777777777778


We can extend the network to handle kelvins by adding:

        my ($F, $C);
*       my $K;
        { my ($i, $j, $k, $l, $m) = Wire->make(5);
          $F = new_io('Fahrenheit', $i);
          $C = new_io('Celsius', $m]);
          new_constant(32, $j);
          new_constant(5/9, $l);
          new_adder($i,$k,$j);
          new_multiplier($k,$l,$m);
*         my ($n, $p) = Wire->make(2);
*         $K = new_io('Kelvin', $n);
*         new_constant(273.15, $p);
*         new_adder($m, $p, $n);
        }

The final adder node expresses the constraint that M<C + 273.15 = K>.
Note that the wire C<$m> has been attached to three nodes, as in the
diagram:

=picture constraint-network-F-to-C-to-K-addition

                     +---+     i
                     | 32+---.          j
                     +---+    '---+---+   +---+
                                  | + +---+ f |
                              ,---+---+   +---+
                            ,'
                         k  |
                            '.          m
                              `---+---+   +---+
                                  | * +-+-+ c |
                     +---+    ,---+---+ | +---+
                     |5/9+---'          |
                     +---+    l         '.
                                          `---+---+ n +---+
                                   +------+   | + +---| k |
                                   |273.15+---+---+   +---+
                                   +------+ p

=endpicture constraint-network-F-to-C-to-K-addition

These definitions of local propagation networks are quite verbose, but
it's easy to imagine attaching a front-end which allows the programmer
to enter the desired constraints in ordinary algebraic notation:

        C = (F+32)*5/9 ;
        K = C + 273.15 ;

The front end would have a parser for expressions like the ones we've
already seen.  The output from the parser would be a constraint
network corresponding to the input expressions.  Central to the parser
would be productions like these, which would build up the appropriate
constraint network as the input expression was analyzed:

        $expression = operator($Term,
                               [lookfor(['OP', '+']), 
                                sub { my $sum = Wire->new;
                                      new_adder($_[0], $_[1], $sum);
                                      return $sum;
                                    }
                               [lookfor(['OP', '-']), 
                                sub { my $difference = Wire->new;
                                      new_adder($difference, $_[1], $_[0]);
                                      return $difference;
                                    }
                              );


=subsection Problems with Local Propagation

If you've ever seen a discussion of local propagation networks before,
you've probably seen the Fahrenheit-Celsius converter example.
There's a good reason for this: it's one of the few examples for which
local propagation actually works.

Let's consider a different problem, almost as simple.  Suppose we're
building a drawing system.  A horizontal line has two endpoints at
M<(x1, y)> and M<(x2, y)>.  Its center point is at M<(c, y)>, and its
length is V<l>.  V<y> is independent of the other parameters, but any
two of V<x1>, V<x2>, V<c>, and V<l> determine the other two.  We might
reason that the center point is the one that is the same distance from
each endpoint, and define the center point with the equation

        c - x1 = x2 - c

The length, of course, is the distance between the endpoints:

        x2 - x1 = l

These two constraints yield the following network:

=note maybe just leave out l?

=picture constraint-network-cycle


                      ,---------------+---+       +----+
                    ,'                | + +---+---+ x2 |
                 m  |            n  ,-+---+   |   +----+
                    '.            .'          |
                      `---+---+   |   +---+   |o
            +----+        | + +---+---+ c |   |
            | x1 +---+----+---+       +---+   |
            +----+   |                        |
                     ',                       |
                     p `--------------+---+  ,'
                             +---+    | + +-'
                             | l +----+---+
                             +---+  q


=endpicture constraint-network-cycle

If we set V<x1> to 3 and V<c> to 5, everything works out.  The 5 is
propagated along wire V<n> to the leftmost C<+> node, which sets
wire V<m> to 2.  This value, plus the 5 reaching the upper C<+> node
along wire V<n>, causes wire V<o> to be set to 7, which is reported as
the value of V<x2>.  Wire V<o>, carrying 7, and wire V<p>, carrying
V<x1>'s value of 3, arrive at the lower C<+> node, allowing the
network to deduce that the value of V<l> is 4.

But suppose instead we set V<x1> to 3 and V<x2> to 7.  The two values
arrive at the lower C<+> node, allowing the calculation of V<l> as
before.  But there's a problem in the upper part of the diagram.  Each
of the two upper C<+> nodes has only one defined input.  Neither of
V<m> or V<n> is defined, and each is needed for the deduction of the
other one.  Since wire V<n> defines the value of V<c>, the network has
failed.  Similarly, although the network above can compute V<x2> from
V<x1> and V<l>, it fails to compute V<c>.

This kind of problem usually arises when local constraint networks
contain loops.  In general, we can't avoid constraints that result in
loops, so we need another technique.

One technique that's commonly used in such cases is called
X<relaxation|d>.  We tell the network to I<guess> a value for V<c>,
and to compute the consequences of the guess.  In general, this will
result in an inconsistent network.  In the example above, we might
guess that V<c> is 0.  This means that V<n> is 0, and then the two
upper addition nodes can compute values for wire V<m>.  The leftmost
one computes that V<m> is -3, and the rightmost one that V<m> is -7.
These are inconsistent, so the network averages them, getting -4, and
tries that out as a value for V<m>.  If V<m> is -4, then then the two
addition nodes want to set wire V<n> to -1 and to 11, respectively.
So the network once again tries the average, 5, for V<n>.  This time,
the two addition nodes agree that V<m> should be 2---so the relaxation
is complete, and has solved the constraint equations.

As with nearly all numerical techniques, relaxation is fraught with
peril.  Sometimes the relaxation process will diverge: instead of
reaching the correct value, the successive steps produce more and more
grossly incorrect values.  Sometimes the relaxation process converges
slowly to the correct values, getting closer and closer but never quite
making it.  

Getting local propagation networks to work well is an active research
area.  I introduced the technique because it's an interesting exercise
and a good introduction to the idea of constraint systems.  But for
the rest of the chapter, we're going to go a different way.

=section Linear Equations

As a large example, we'll develop a system, called C<linogram>, for drawing
diagrams.


=note explain this in more detail

=note quote from Kernighan "What you see is all you get"

Diagrams are usually drawn with a X<WYSIWYG> structured drawing
system.  The big drawback of this kind of system is that if you want
to change the diagram globally, you essentially have to start over.
For example, suppose you were drawing a family tree, and you decided
to represent each person with a rectangle 0.75 inches wide by 0.5
inches tall.  You get the diagram done, but then you learn that the
diagram will need to be printed in landscape mode, rather than
portrait mode.  You want to make the boxes shorter, to fit on the
shorter page, but wider, to fit the text in--say 1 inch wide and only
0.4 inches tall.  Also, you want to see how the diagram looks if the
corners of the boxes are rounded off.

In the typical structured drawing system, you'd have to manually
adjust each box and the text inside it.  In a declarative drawing
system, however, this kind of change is easy.  A diagram is like a
program, and there is a definition in the program which describes the
kind of box you want to use for a person.  By changing the definition,
you change every box of that type in the entire diagram.

In the declarative drawing system, you can tell the computer to
calculate the positions and sizes of drawing elements based on the
positions and sizes of other elements.  So, for example, you can
easily tell the system that you want all the squares to be made into
rectangles, or all the straight arrows made into curved arrows, or all
the part of the diagram that represent X<widgets> to be drawn with
three round knobs instead of two square knobs, just by changing a
small part of the description of the diagram.

Since the input to the declarative system is a plain text file, it's
also easy to get another program to generate diagrams as output.

If we're going to describe objects by giving constraints, we need some
way of solving the constraints to figure out where the objects
actually are.  As we saw, local propagation won't do it.  In general,
the problem is very difficult, because constraints are equations, so
solving constraints means solving equations.  If solving equations
were easy, we wouldn't have to suffer through four years of high
school algebra learning how to do it, and we wouldn't need
mathematicians to figure it out.

For general geometric problems, we have to solve general sorts of
equations; these may involve higher algebra, or even trigonometry.
There is one kind of equation, however, that's easy to solve.  Linear
equations are easy.  The solution of


        ax + b = c

is

        x = (c-b)/a

Because diagrams usually involve a lot of straight lines, linear
equations usually do most of what we want.  The kind of curves that
appear in diagrams are unusually simple and highly constrained.  It
may require advanced mathematics to find the intersection of a
lemniscate and a cardioid, but how often do you draw a diagram with a
lemniscate and a cardioid?  Diagrams do involve circles (which
potentially opens up the can of trigonometry worms), but typically the
circle is used as just another kind of box.  If we allow drawing
elements to be attached to circles only at the 'corners' (the
northmost, northwestmost, etc. points) then the circle is essentially
an octagon as far as the equations are concerned; then once we figure
out where the corners are located, we can join them with curves
instead of straight sides.

=section C<linogram>: a drawing system

The entities with which our program deals are called "features".  A
feature represents something like a box or a line.  It might contain
sub-features; for example, a box feature contains four sub-features
that represent its four sides.  A feature also contains a list of
constraint equations that define the relationships between its
sub-features; for example, in a box feature, the top and left sides
are constrained to start at the same point.

The input to the drawing system will be a specification for a large
compound feature, called the X<root feature|d>, which represents the
entire drawing.  Here's an example specification for a root feature:

        box F, plus, con32, times, C, con59;
        line i, j, k, l, m;
        number hspc, vspc, boxht, boxwd;

        constraints {
          boxht = 1; boxwd = 1;
          hspc = 1 + boxwd; vspc = 1 + boxht;

          F.ht = boxht; F.wd = boxwd;

          plus = F + (hspc, 0);
          con32 = plus + (hspc, 0);
          times = plus + (0, vspc);
          C = times + (hspc, 0);
          con59 + (hspc, 0) = times;

          i.start = F.e;     i.end = plus.nw;
          j.start = plus.e;  j.end = con32.w;
          k.start = plus.sw; k.end = times.nw;
          l.start = con59.e; l.end = times.sw;
          m.start = times.e; m.end = C.w;

          F.nw = (0,0);
        }

The first three lines declare the sub-features of the root feature; it
contains six boxes, five lines, and four numbers.  Numbers are
primitive, and don't contain subfeatures.  The numbers C<hspc> and
C<vspc> will be used to determine the amount of space between the
boxes.  If we want to move all the boxes closer together in the
horizontal direction, we will only need to change the definition of
C<hspc> to a smaller value.  Similarly, C<boxht> and C<boxwd> will be
the height and width of each of the six boxes.

The C<constraints> section is the really interesting part.  It's a
list of linear equations that specify the sizes and relative locations
of the boxes and lines.  The first four equations define the four
numeric parameters C<boxht>, C<boxwd>, C<hspc>, and C<vspc>.  C<hspc>
represents the minimum center-to-center horizontal separation of two
nearby boxes, so it's defined in terms of C<boxwd>: the distance
between the two centers is the width of one box, plus one unit of
space.  

The next two equations define the height and the width of the C<F>
box by establishing constraints on its subfeatures C<F.ht> and C<F.wd>.
The definition of the C<box> type (which we'll see later)  contains
a declaration like

        number ht, wd;

to say that every box has these two properties, and other declarations
that relate these numbers to the positions of the four sides.

The next equation,

        plus = F + (hspc, 0);

constrains the size, shape, and position of the C<plus> box.  The
C<(hspc, 0)> is called a X<tuple expression|d> and represents a
displacement.  The constraint says that the box C<plus> is exactly
like C<F>, only displaced eastward by C<hspc> units and southward by 0
units.  Internally, this will translate into a series of constraints
that force each of C<plus> four corners and four sides to be C<hspc>
units east and 0 units south of the corresponding corners and sides of
C<F>.

Although this equation looks like an assignment, it isn't; it's a
declaration.  If C<linogram> knows about C<F>, it can deduce the
corresponding information about C<plus>---or vice versa.  It can also
deduce complete information about both from partial information.  For
example, if only the left side of C<F> and the top side of C<plus> are
known, then the other sides of the two boxes can all be deduced: the
left side of C<plus> is like the left side of C<F>, and the top side
of C<F> is like the top side of C<plus>.

We could also have written this equation in any of these
mathematically equivalent forms:

        F + (hspc, 0) = plus;
        plus + (-hspc, 0) = F;
        plus - F = (-hspc, 0);
        plus - (hspc, 0) - F = 0;

Sometimes it's convenient to write equations like this.  For example,
suppose we had four features, C<A>, C<B>, C<C>, and C<D>.  We're not
sure where C<A>, C<B>, and C<C> are, but we know that we C<D>'s
position relative to C<C> to be the same as C<B>'s position relative
to C<A>---if C<B> is one furlong due north of C<A>, we want C<D> one
furlong due north of C<C>, or whatever.  It's quite straightforward
and intuitive to express it like this:

        D - C = B - A;

Or suppose we wanted point C<Z> to be one-third of the way from C<X>
to C<Y> along the straight line between them:

      Z - X = 1/3 * (Y - X);

In addition to a height and a width, every box has thirteen more
subfeatures: four lines and nine points.  The lines represent the four
sides, and are named C<top>, C<bottom>, C<left>, and C<right>.  The
points aren't strictly necessary, but they're convenient.  They are
the four corner points, called C<nw>, C<ne>, C<sw>, and C<se>, the
midpoints of the four sides, called C<n>, C<s>, C<e>, and C<w>, and
the center point, called C<c>.  

Similarly, a line contains two sub-features, called C<start> and
C<end>, which denote its two endpoints.  


The next few declarations in our specification define the endpoints of
the five lines C<i> through C<m>.

The declarations

          i.start = F.e;     i.end = plus.nw;

constrain line C<i> to start at the midpoint of C<F>'s east side, and
to end at the northwest corner of box C<plus>.

Finally, we have to tell the program the absolute location of at least
one of the features, or it won't be able to figure out where anything is
located.  We force the issue by attaching the northwest corner of box
C<F> arbitrarily to C<(0,0)>, although it doesn't really matter; we
could as easily have attached any other point of any of the boxes.

In addition to these manifest constraints, there are a large number of
hidden constraints that we don't see, inherent in the definitions of
the C<box> and C<line> types.  For example, the definition of C<box>
has, among others,

        top.start = left.start;
        nw = top.start;
        top.start + wd = top.end;
        n = top.center;
        ...

and the definition of C<line> has

        center = (start + end)/2;

Again, although this looks like an assignment, it isn't; it's
symmetric.  If the start and end points of the line are known, the
center will be calculated from them; if the start and center are known
instead, the position of the end point will be calculated instead.
Any two of the points imply the third.

The program's strategy for drawing a diagram is as follows.  First it
will read in the definition of the root feature, including the implied
definitions of common subfeatures such as C<box>.  It will accumulate
a large set of linear constraint equations.  These will include the
explicit constraints, as well as many automatically generated implicit
constraints.  If the root feature contains a C<box> named C<F>, then
it will also include C<F>'s constraints implicitly, in the form of
equations like these:

        F.top.start = F.left.start;
        F.nw = F.top.start;
        F.top.start + F.wd = F.top.end;
        F.n = F.top.center;
        ...

In fact, since C<F> itself contains several subfeatures, it will
inherit constraints from these.  C<F>'s top side is a line, so C<F>
will inherit the constraint

        top.center = (top.start + top.end)/2;

from the definition of C<line>; this will in turn be inherited by the
root feature as

        F.top.center = (F.top.start + F.top.end)/2;

After accumulating all the constraint equations, the program will
solve the equations.  The result will be a complete description of
where every part of every feature is located.

Associated with each feature will be one or more drawing functions.
The program will invoke the drawing functions for each feature,
passing them a hash containing the relevant variables.  It's up to the
drawing functions to generate the appropriate output.  The output
might be instructions in X<PostScript> to be sent to a printer, or
perhaps a "canvas" object containing a bitmap of the finished diagram.

Before we go any further with the main program, let's look at the
definitions of the simpler subfeatures such as boxes, which will be
instructive.  The simplest features that the program deals with are
numbers, which are atomic.  These are the only features whose
definitions are built into the program.  All other features are
defined by a library file, which specifies the feature's subfeatures,
constraints, and drawing methods.

Next to a number, the simplest feature is a C<point>, which has C<x>
and C<y> coordinates, but no constraints on them:

        define point {
          number x, y;
        }

When C<linogram> wants to draw a feature, its default behavior is to
recursively draw all the feature's subfeatures.  Thus it draws a C<point>
by trying to "draw" the two numbers C<x> and C<y>.  Numbers are
considered to be invisible, so the aggregate behavior for drawing a
point is also to do nothing.  The simplest visible feature is a line,
which has start and end points:

        define line {
          point start, end, center;
          constraints { center = (start + end)/2; }
          draw { &draw_line; }
        }

As mentioned before, a line also has a C<center> point, for
convenience; it's constrained to be halfway between the start and end
points.  

=startpicture line-subfeatures

        ILLUSTRATION TO COME

=endpicture line-subfeatures


The C<draw> section is new.  The declaration shown here is the name of
a Perl subroutine responsible for drawing the feature.  The C<&> is a
lexical marker that indicates that this is the name of a subroutine.
When invoked, the subroutine will be passed a hash that indicates the
positions of the subfeatures of the line:

        ("start.x" => 5, "start.y" => 3,
         "end.x" => 3, "end.y" => 7,
         "center.x" => 4, "center.y" => 5,
        )

If any of the subfeatures are unknown, they'll be omitted from the
hash; in that case, the function should complain.  Since this chapter
is about declarative programming, and not about graphics, we'll weasel
out of doing any actual drawing, and use the following drawing
function, which claims to draw lines even though it doesn't really
draw anything.  It does, however, give us a clear description of the
line it I<would> have drawn, which is enough to see whether the
program is doing what it should be doing.


        sub draw_line {
          my $env = shift;
          my $GOOD = 1;
          for my $k (qw(start.x start.y end.x end.y)) {
            unless (defined $env->{$k}) {
              warn "Can't draw line because '$k' is missing\n";
              $GOOD = 0;
            }
          }
          if ($GOOD) {
            print "Drawing line from ($env->{'start.x'}, $env->{'start.y'})
        	   to ($env->{'end.x'}, $env->{'end.y'})\n";
          }
        }

Given the hash above, this will produce the output:

        Drawing line from (5, 3) to (3, 7)

(Even though we weaseled out of the drawing, creating a diagram in
X<PostScript> is barely more difficult.  We would need to generate
output something like this:

        50 30 moveto 30 70 lineto stroke

This is almost the same, but there are a (very) few additional
complications that I didn't want to have to consider, so we'll stick
with the weasel drawing technique.)

The other possible inhabitants of a C<draw> section are the names of
some of the subfeatures that make up the feature.  Only these subfeatures
will be drawn.  If there is no C<draw> section at all, the default is
to draw all the subfeatures.

We have enough machinery now to define boxes directly, but C<linogram>'s
standard library goes through a set of intermediate definitions first.
The top and bottom sides of a box are constrained to be horizontal,
and it's convenient to define a new feature type to represent a
horizontal line:

        define hline extends line {
          number y, length;
          constraints {
            start.y = end.y;
            start.y = y;
            start.x + length = end.x;
          }
        }

This defines a new type, called C<hline>, which has all of the
subfeatures and constraints that an ordinary C<line> has, and some
additional ones.  The start and end points must have the same
V<y>-coordinate, and an C<hline> also has an additional sub-feature,
called C<y>, which is defined to be equal to the V<y>-coordinate.  If
we were trying to specify the location of a box C<F>, this would allow
us to abbreviate C<F.top.start.y> as simply C<F.top.y>, which is more
natural.  An C<hline> also has a length, which is the distance between
the endpoints.  In general, the length of a line is not a linear
function of the positions of the endpoints (because M<length =
sqrt((end.x-start.x)^2 + (end.y-start.y)^2)>) and computing one point
given the length and the other endpoint requires trigonometry, which
C<linogram> won't do.  But for horizontal lines, the calculation is
trivial.

The constraints in this definition are adjoined to those inherited
from C<line>, which imply the position of the C<center> point of an
C<hline>, even though we never mentioned it explicitly.  The C<draw>
section is also inherited from C<line>, so that the Perl C<draw_line>
function will be used for C<hline> as well.

Vertical lines are almost exactly the same:

        define vline  extends line {
          number x, height;
          constraints {
            start.x = end.x;
            start.x = x;
            start.y + height = end.y;
          }
        }

Now we're ready to define C<box>.  it has a lot of machinery, but none
of it is new:

        define box {
          vline left, right;
          hline top, bottom;
          point nw, n, ne, e, se, s, sw, w, c;
          number ht, wd;

          constraints {
            left.start  = top.start;
            right.start = top.end;
            left.end    = bottom.start;
            right.end   = bottom.end;

            nw = left.start;
            ne = right.start;
            sw = left.end;
            se = right.end;
            n = top.center;
            s = bottom.center;
            w = left.center;
            e = right.center;

            c = (n + s)/2;

            ht = left.height;
            wd = top.length;
          }
        }

A box has a left and a right side, which are C<vline>s, and a top and
a bottom side, which are C<hline>s.  It has nine other named points,
which are identical to various parts of the four sides, except for
C<c>, the center, which is halfway between the north and south points.
It also has a height and a width, which are the same as the lengths of
the left and top sides, respectively.  We didn't need to require that
C<ht = right.height>; this is already implicit in the other equations,
although it wouldn't have hurt to put it in.

=startpicture box-subfeatures

        ILLUSTRATION TO COME

=endpicture box-subfeatures

The C<box> definition doesn't contain a C<draw> section either.  The
default behavior is for C<linogram> to draw a box by drawing each of its
fifteen subfeatures.  For the nine points and the two numbers, this does
nothing at all; the other four subfeatures are the four sides, which
C<linogram> draws by calling C<draw_line>.  Each box will therefore result
in four calls to C<draw_line>, which is just what we want.

To define a square, we need only write:

        define square extends box {
          constraints { ht = wd; }
        }

which defines a C<square> to be the same as a C<box> but with the
height and width constrained to be equal.  Another common constituent
of diagrams is an arrow.  From C<linogram>'s point of view, this is
nothing more than an oddly-drawn line:

        define arrow extends line {
          draw { &draw_arrow; }
        }

An arrow has a start and end point, just like a line; these are the
start and end points of the arrow's shaft.  The C<draw_arrow> function
is responsible for drawing the shaft (which it can do by calling
C<draw_line>) and then filling in the two whiskers at the endpoint.

If we're feeling creative, we might go on:

        define golden_rectangle extends box {
          constraints { ht * 1.618 = wd; }
        }

        define circle {
          number r, d;
          point c, nw, n, ne, e, se, s, sw, w;
          constraints {
            d = 2*r;

            n = c - (0, r);
            s = c + (0, r);
            e = c + (r, 0);
            w = c - (r, 0);

            se = c + ( r, r)/1.4142;
            sw = c + (-r, r)/1.4142;
            ne = c + ( r,-r)/1.4142;
            nw = c + (-r,-r)/1.4142;
          }
          draw { &draw_circle; }
        }

        define diamond extends box {
          line nw_side(start=n, end=w), 
               sw_side(start=s, end=w), 
               ne_side(start=n, end=e), 
               se_side(start=s, end=e);
          draw { nw_side; 
                 sw_side;
                 ne_side;
                 se_side;
          }
        }

The C<nw_side(start=n, end=w)> declaration in the last definition is a
shorthand for 

        line nw_side;   
        constraints { nw_side.start = n;
                      nw_side.end = w;
                    }

C<linogram> has a few other features, but we'll see them in the course
of seeing the program code.  The program code comprises three major
classes and several less important classes.  The three major classes
are C<Constraint>, which represents constraints, C<Type>, which
represents feature types such as C<box> and C<line>, and C<Value>,
which represents the value of an expression as it is being converted
to a set of constraints.  We'll see constraints and equations first.

=subsection Equations

=note example of CPAN Gaussian elimination module?

The heart of C<linogram> will be the module that solves systems of
linear equations.  The usual way to do this is to represent the system
as a matrix, and then perform sequences of matrix transformations on
it until the matrix is in a canonical form; this is called X<Gaussian
elimination|d>.  Methods for doing this are well-studied, and also
available on CPAN.  But for various reasons, the CPAN modules I found
for solving linear equations didn't seem to be what I wanted, so I'll
develop one here.

An C<Equation> object is a hash.  The equation

        14 x + 9 y - 3.5 z = 28

is represented by the hash

        { "x" => 14,
          "y" => 9,
          "z" => -3.5,
          ""  => -28,
        }

The values 14, 9, and -3.5, are called the X<coefficients|d> of V<x>,
V<y>, and V<z>, respectively.  The -28 is the X<constant part|d>.
It's negative because the equation is actually

        14 x + 9 y - 3.5 z - 28 = 0

The C<""> key in the hash is mandatory because every linear equation
has a constant part, even if the constant part is 0.  The equation

         x = 0

corresponds to the hash

        { "x" => 1,
          ""  => 0,
        }

and the trivial equation M<0 = 0> is represented by the hash 
C<{ "" =\> 0 }>.  

Manipulating equations through these hashes is straightforward and
easy to debug, although slow.  If speed is an issue, the C<Equation>
module of the program should be replaced with one that uses a more
abbreviated representation of equations, perhaps one implemented in C.

The constructor function takes an argument hash and puts it into a
canonical form:

=startlisting Equation.pm

        sub new {
          my ($base, %self) = @_;
          $class = ref($base) || $base;
          $self{""} = 0 unless exists $self{""};
          for my $k (keys %self) {
            if ($self{$k} == 0 && $k ne "") { delete $self{$k} }
          }
          bless \%self => $class;
        }

=endlisting Equation.pm

If the constant part is missing, the constructor sets it to 0; if the
coefficients of any of the variables are 0, they are deleted.  For
example, C<-\>new("x" =\> 0, "y" =\> 1)>, which represents 
M<0x + 1y = 0>, is turned into C<{"y" =\> 1, "" =\> 0}>.

=subsubsection C<ref($base) || $base>

One idiom used here and elsewhere that you may not have seen is the
C<ref($base) || $base> trick.  The goal is to  write a function which
can be called as either an object or a class method, either as

        Equation->new(...)

or as

        $some_equation->new(...)

In the former case, C<$base> is the string C<Equation>, and C<ref
$base> is false, since C<$base> is a string rather than a reference.
C<$class> is therefore set equal to C<$base>.  In the latter case,
C<$base> is the object C<$some_equation>, and C<ref($base)> is the
class into which C<$some_equation> was blessed.  C<$class> is
therefore set equal to C<$some_equation>'s class.  This is convenient
when we'll be writing several other constructor methods that might get
an C<Equation> object as an argument and will want to create another
object similar to it.  For example, here's a method which makes a copy
of an C<Equation> object:

        sub duplicate {
          my $self = shift;
          $self->new(%$self);
        }

Note that

        # WRONG!        
        sub duplicate {
          my $self = shift;
*         Equation->new(%$self);
        }

doesn't work properly if its argument is an object of a class derived
from C<Equation>.  The correct code creates a new object from the same
derived subclass; the incorrect code creates a new C<Equation> object
regardless.

=subsubsection Solving Equations

For convenience, we set up a constant for the important trivial
equation M<0 = 0>:

=contlisting Equation.pm

        BEGIN { $Zero = Equation->new() }

Equations have three important accessors.  One retrieves the coefficient
of a given variable:

        sub coefficient {
          my ($self, $name) = @_;
          $self->{$name} || 0;
        }

The second recovers the constant part:

        # Constant part of an equation
        sub constant {
          $_[0]->coefficient("");
        }

The other returns the names of all the variables that the equation
mentions:

        sub varlist {
          my $self = shift;
          grep $_ ne "", keys %$self;
        }

=endlisting Equation.pm

All equations can be scaled and added.  If an equation is known to be
true, you can multiply its constant and its coefficients by any number
V<n>, and the resulting equation is also true.  For example, if

        14 x + 9 y - 3.5 z = 28

then we can scale all the numbers by 2 and get 
        
        28 x + 18 y - 7 z = 56

which is equivalent.  

If we have two equations that are true, we can add them together and
get another true equation.  For example, suppose we have

        x = 13
        2y = 7

we can add these, getting

        x + 2y = 20

These two operations are fundamental to all methods of solving linear
equations.  For example, suppose we have

        x + y = 12
        x - y = 2

If we add these two equations together, the M<+y> in the first and the
M<-y> in the second cancel, yielding

        2x    = 14

which we can then scale (by M<1/2>) to yield

         x    = 7

We can then scale this by -1, yielding

        -x    = -7

.  When we add this last equation to the very first equation, the
V<x>'s cancel, and we're left with

         y    = 5

And in fact M<x=7>, M<y=5> is the solution of the equations.  

The most important function in the C<Equation> module is
F<arithmetic>, which scales and adds equations:

=contlisting Equation.pm

        sub arithmetic {
          my ($a, $ac, $b, $bc) = @_;
          my %new;
          for my $k (keys(%$a), keys %$b) {
            my ($av) = $a->coefficient($k);
            my ($bv) = $b->coefficient($k);
            $new{$k} = $ac * $av + $bc * $bv;
          }
          $a->new(%new);
        }

Given two equations, C<$a> and C<$b>, and two numbers, C<$ac> and
C<$bc>, F<arithmetic> scales C<$a> by C<$ac>, scales C<$b> by C<$bc>,
and adds the two scaled equations together.  Built atop this base are
several simpler utility functions.  For example, to add two equations
together, we use F<arithmetic>, with both scale factors set to 1:

        sub add_equations {
          my ($a, $b) = @_;

          arithmetic($a, 1, $b, 1);
        }


Similarly, to subtract one equation from another is the same as adding
them, but with the second one negated:

        sub subtract_equations {
          my ($a, $b) = @_;

          arithmetic($a, 1, $b, -1);
        }

Scaling a single equation is yet another special case, where the
second equation is zero:

        sub scale_equation {
          my ($a, $c) = @_;
          arithmetic($a, $c, $Zero, 0);
        }

=endlisting Equation.pm

Now suppose we have two equations:

         a x + some other stuff = c

         b x + more stuff = d

Here we can eliminate V<x> from the first equation by scaling the
second by M<-a/b> and adding the result to the first equation.    The
function F<substitute_for> is for eliminating a variable from an
equation.  The call

        $first->substitute_for("x", $second);

eliminates variable C<"x"> from equation C<$first> in this way, by
combining it with an appropriately scaled version of C<$second>:

=contlisting Equation.pm

        # Destructive
        sub substitute_for {
          my ($self, $var, $value) = @_;
          my $a = $self->coefficient($var);
          return if $a == 0;
          my $b = $value->coefficient($var);
          die "Oh NO" if $b == 0;  # Should never happen

          my $result = arithmetic($self, 1, $value, -$a/$b);
          %$self = %$result;
        }

=endlisting Equation.pm

If C<$a> is zero, then the first equation didn't contain the variable
we were trying to eliminate, so nothing needs to be done.  The C<"Oh
NO"> case occurs when the second equation doesn't contain the
variable we're trying to eliminate; in this case there's no way to use
it to eliminate the variable from the first equation.  Note that the
function is destructive: it modifies C<$self> in place.

The cost of eliminating a variable like V<x> is that the resulting
equation might be more complicated than what we started with,
depending on what's else is in the equation we're using to reduce it.
If we're not careful, we might even get stuck in an infinite loop.
Suppose we had

        x + y = 3
        y + z = 5

and we scale the second equation by -1 and add it to the first, to
eliminate V<y>:

        x - z = -2

If we then add I<this> equation to the second one to eliminate V<z>,
we're back where we started.

We'll adopt a simple strategy that prevents infinite loops.  We'll
take the first equation and use it to completely eliminate one of its
variables from all the other equations.  The variable will be present
in that first equation only, so as long as we don't use it again, we
can't possibly reintroduce that variable.  We'll then move to the
second equation and use I<it> to eliminate one of I<its> variables
from all the other equations.  We'll repeat this for each equation.

To that end, here's a method that returns an arbitrarily chosen
variable from an equation:

=contlisting Equation.pm

        sub a_var {
          my $self = shift;
          my ($var) = $self->varlist;
          $var;
        }

=endlisting Equation.pm

Let's see a small example of how this works.  Consider the equations

      A:   x + 2y = 8
      B:   2y + z = 10
      C:   x + y + 2z = 13

First we use V<A> to eliminate V<x> from the other two equations.
For equation V<B> there is nothing to do; eliminating V<x> from V<C>
leaves:

      A:   x + 2y = 8
      B:   2y + z = 10
      C:   -y + 2z = 5

Now we use V<B> to eliminate V<y> from the other two equations.
Eliminating V<y> from V<A> leaves:

      A:   x - z = -2
      B:   2y + z = 10
      C:   -y + 2z = 5

Eliminating V<y> from V<C> leaves:

      A:   x - z = -2
      B:   2y + z = 10
      C:   2.5z = 10

Finally, we use V<C> to eliminate V<z> from the other two equations:

      A:   x = 2
      B:   2y = 6
      C:   2.5z = 10

At this point we have finished one complete pass through all the
equations, so we are done.  There's a final step that needs to be done
to put the equations in standard form: we must adjust the coefficients
to 1:

      A:   x = 2
      B:   y = 3
      C:   z = 4

but this is a simple scaling operation.  

Solving entire systems of equations is the job of the
C<Equation::System> module, whose objects represent whole systems of
equations:

=contlisting Equation.pm

        package Equation::System;

        sub new {
          my ($base, @eqns) = @_;
          my $class = ref $base || $base;
          bless \@eqns => $class;
        }


In the course of solving a system of equations, we often find that
some of them are redundant.  The way this appears in the mathematics
is that we reduce an equation and find that we have nothing left.
(That is, nothing but M<0 = 0>, which adds no useful information.)  We
can detect such a ghostly equation with C<Equation::is_tautology>:

        package Equation;

        sub is_tautology {
          my $self = shift;
          return $self->constant == 0 && $self->varlist == 0;
        }

In such a case, we'll replace the ghostly equation with C<undef>.

The important accessor for an C<Equation::System> recovers the current
list of equations, ignoring the ones we have nulled out:

        package Equation::System;

        sub equations {
          my $self = shift;
          grep defined, @$self;
        }

A typical operation on a system of equations will be to transform each
equation in some way:

        sub apply {
          my ($self, $func) = @_;
          for my $eq ($self->equations) {
            $func->($eq);
          }
        }

Now we're ready to see C<Equation::System::solve>, the end product of
all this machinery.

        sub solve {
          my $self = shift;
          my $N = my @E = $self->equations;
          for my $i (0 .. $N-1) {
            next unless defined $E[$i];
            my $var = $E[$i]->a_var;
            for my $j (0 .. $N-1) {
              next if $i == $j;
              next unless defined $E[$j];
              next unless $E[$j]->coefficient($var);
              $E[$j]->substitute_for($var, $E[$i]);
              if ($E[$j]->is_tautology) { 
                undef $E[$j]; 
              } elsif ($E[$j]->is_inconsistent) {
                return ;
              }
            }
          }
          $self->normalize;
          return 1;
        }

=endlisting Equation.pm

The main loop selects an equation number V<i>, selects one if its
variables, C<$var>, and then scans over all the other equations V<j>
reducing each one to remove C<$var>.  If the result is the trivial
equation M<0 = 0>, equation V<j> is nulled out.

After each reduction, we test the resulting equation to make sure it
makes sense.  If we get an equation like M<1 = 0>, we know something
has gone wrong.  This will occur if the original equations were
inconsistent.  For example:

        start.y = 1;
        y = 2;
        start.y - y = 0;

Eliminating V<start.y> from the others yields

        start.y = 1;
        y = 2;
        -y = -1;

Then using the second equation to eliminate V<y> from the others yields

        start.y = 1;
        y = 2;
        0 = 1;

which is no good, because it says that M<0 = 1>.  The
C<Equation::is_inconsistent> method detects bad equations like M<0 = 1>
which have no variables, but whose constant part is nonzero:
  
=contlisting Equation.pm

        package Equation;

        sub is_inconsistent {
          my $self = shift;
          return $self->constant != 0 && $self->varlist == 0;
        }

=endlisting Equation.pm

When the main loop is finished, we hope that the equations in the
system have been reduced to the point where they contain only one
variable each.  As we saw, the equations might need one final
adjustment.  An equation like this:

        2y = 6

should be adjusted to this:

         y = 3

The C<Equation::System::normalize> method adjusts the equations in
this way.

=contlisting Equation.pm

        package Equation::System;

        sub normalize {
          my $self = shift;
          $self->apply(sub { $_[0]->normalize });
        }

To normalize a single equation, we scale it appropriately:

        package Equation;

        sub normalize {
          my $self = shift;
          my $var = $self->a_var;
          return unless defined $var;
          %$self = %{$self->scale_equation(1/$self->coefficient($var))};
        }

An equation like M<y = 3> is so simple that even the computer
understands what it means.  We say that this equation I<defines> the
variable V<y>.  The F<defines_var> method reports on whether an
equation defines a variable.

        sub defines_var {
          my $self = shift;
          my @keys = keys %$self;
          return unless @keys == 2;
          my $var = $keys[0] || $keys[1];
          return $self->{$var} == 1 ? $var : () ;
        }

To define a variable, an equation must have the form M<var = val>, and
so must contain exactly two keys.  One is the name of the variable;
the other is the constant value.  Moreover, the coefficient of the one
variable must be 1.  If all this is true, F<defines_var> returns the
name of the variable so defined.  The value of the variable can be
recovered with C<- $equation-\>constant>.  (The minus sign is because
M<y = 7> is represented as M<y - 7 = 0>, which is 
C<{ y =\> 1, "" =\> -7 }>.

The main entry to the equation-solving subsystem for outside functions
is the F<values> method.  This takes a system of equations, solves the
equations, and returns a hash that maps the names of known variables
to their values.

        package Equation::System;

        sub values {
          my $self = shift;
          my %values;
          $self->solve;
          for my $eqn ($self->equations) {
            if (my $name = $eqn->defines_var) {
              $values{$name} = -$eqn->constant;
            }
          }
          %values;
        }

        1;

=endlisting Equation.pm

=subsubsection Constraints

C<linogram> will have another class, called C<Constraint>, which represents
constraints.  Since constraints are essentially equations,
C<Constraint> will be a derived class of C<Equation>.

=startlisting Constraint.pm

        package Constraint;
        use Equation;
        @Constraint::ISA = qw(Equation);

C<Constraint> adds a few utility methods to C<Equation> that make more
sense in the context of C<linogram> than in the general context of equation
solving.  The most important is F<qualify>.  A type like C<hline>
contains the constraint C<start.y - y = 0>.  But when considered as
part of a C<box>, the C<hline> has a name like C<top> or C<bottom>,
and the constraint, when translated into the context of the box, turns
into M<top.start.y - top.y = 0>.  F<qualify> takes a constraint and a
name prefix and produces a new, transformed constraint:

        sub qualify {
          my ($self, $prefix) = @_;
          my %result = ("" => $self->constant);
          for my $var ($self->varlist) {
            $result{"$prefix.$var"} = $self->coefficient($var);
          }
          $self->new(%result);
        }

C<Constraint>'s other methods are simple things.  In some places
inside C<linogram>, constraints are used as if they were expressions;
when there is an expression with an addition in the drawing
specification, we have to add together constraints.  We'll see this in
more detail later; in the meantime, F<new_constant> manufactures a
constraint like M<0 = 0> or V<0 = 1> which plays the role of a
constant expression:

        sub new_constant {
          my ($base, $val) = @_;
          my $class = ref $base || $base;
          $class->new("" => $val);
        }

F<add_constant> adds a constant to a constraint, transforming
something like M<x = 0> to something like M<x = 3>, and
F<mul_constant> multiplies a constraint by a constant transforming
something like M<x = 3> to something like M<4x = 12>.

        sub add_constant {
          my ($self, $v) = @_;
          $self->add_equations($self->new_constant($v));
        }

        sub mul_constant {
          my ($self, $v) = @_;
          $self->scale_equation($v);
        }


All the other methods of C<Constraint> are inherited from C<Equation>.
 
Analogous to C<Constraint>, there is a C<Constraint_Set> class that is
derived from C<Equation::System>.  It's even simpler than
C<Constraint>.  It has only one extra method:

        package Constraint_Set;
        @Constraint_Set::ISA = 'Equation::System';

        sub constraints {
          my $self = shift;
          $self->equations;
        }

        1;

=endlisting Constraint.pm

=subsection Values

In the course of reading and parsing the specification, we'll need to
deal with expressions.  We saw the parsing end of this in detail in
C<parsing|Chapter>.  The question that arises is what the values of
the expressions will be; the answer turns out to be quite interesting.
Values are not always numbers.  For example:

        point P, Q;
        P + (2, 3) = Q;

Here we have an expression C<P + (2, 3)>.  The value of this
expression isn't a simple number.  It implies parts of two
constraints, involving V<P.x> and V<P.y>.   Later on, these partial
constraints must be combined with V<Q> to yield the complete
constraints, which are M<P.x + 2 = Q.x> and M<P.y + 3 = Q.y>.  

One of C<linogram>'s main classes is C<Value>, which represents the value
of an expression.  Value is where the most interesting arithmetic
takes place inside of C<linogram>.  C<Value>s come in three kinds.
C<Value::Constant> represents a scalar constant value such as 3.
C<Value::Tuple> represents a lone tuple, such as C<(2, 3)>, or a sum
of tuples.  And C<Value::Feature> represents a feature type, even a scalar
feature type, such as V<P> or V<Q> or C<P + (2, 3)>.  C<Value> itself is
an abstract base class, and doesn't represent anything; it's only
there to provide methods that are inherited by the other classes,
primarily for doing arithmetic.

C<Value> objects have one generic accessor, called F<kindof>, which
returns C<CONSTANT>, C<TUPLE>, or C<FEATURE>, depending on what kind of
object it is called on.  The other methods are arithmetic.  The entry
to these from the parser is via a quartet of operation methods called
F<add>, F<sub>, F<mul>, and F<div>, which are just thin wrappers
around the real workhorse, F<op>:

        sub add { $_[0]->op("add", $_[1]) }
        sub sub { $_[0]->op("add", $_[1]->negate) }
        sub mul { $_[0]->op("mul", $_[1]) }
        sub div { $_[0]->op("mul", $_[1]->reciprocal) }

Note that subtraction and division are defined in terms of addition
and multiplication, which cuts down on the amount of work we need to
do for F<op>.

F<op> itself is driven by a dispatch table because otherwise it would
be quite complicated.  The dispatch table is indexed by the operation
name (either C<add> or C<mul>) and by the kinds of the two operands.
It looks like this:

=startlisting Value.pm

        package Value;

        my %op = ("add" => 
                  {
                   "FEATURE,FEATURE"     => 'add_features',
                   "FEATURE,CONSTANT"   => 'add_feature_con',
                   "FEATURE,TUPLE"      => 'add_feature_tuple',
                   "TUPLE,TUPLE"       => 'add_tuples',
                   "TUPLE,CONSTANT"    => undef,
                   "CONSTANT,CONSTANT" => 'add_constants',
                   NAME => "Addition",
                  },
                  "mul" => 
                  {
                   NAME => "Multiplication",
                   "FEATURE,CONSTANT"   => 'mul_feature_con',
                   "TUPLE,CONSTANT" => 'mul_tuple_con',
                   "CONSTANT,CONSTANT" => 'mul_constants',
                  },
                 );


Addition, surprisingly, turns out to be more complicated than
multiplication.  This is because we've restricted our system to linear
operations, which means that multiplication is forbidden, except to
multiply by constant values.  Given two C<Value> objects and an
operation tag, F<op> consults the dispatch table, dispatches the
appropriate arithmetic function, and returns the result:

        sub op {
          my ($self, $op, $operand) = @_;
          my ($k1, $k2) = ($self->kindof, $operand->kindof);
          my $method;
          if ($method = $op{$op}{"$k1,$k2"}) {
            $self->$method($operand);
          } elsif ($method = $op{$op}{"$k2,$k1"}) {
            $operand->$method($self);
          } else {
            my $name = $op{$op}{NAME} || "'$op'";
            die "$name of '$k1' and '$k2' not defined";
          }
        }

The two operands are C<$self> and C<$operand>.  F<op> starts by
finding out what sorts of values these are, using C<kindof>, which
returns C<CONSTANT> for C<Value::Constant> objects, C<TUPLE> for
C<Value::Tuple> objects, and so forth.  It then looks in the dispatch
table under the operator name (C<"add"> or C<"mul">) and the value
kinds.  If it doesn't find anything, it tries the operands in the
opposite order, since a function for adding a tuple to a feature is the
same as one for adding a feature to a tuple; this cuts down on the
number of functions we have to write.  If neither operand order works,
then the C<op> function fails with a message like C<"Addition of
'CONSTANT' and 'TUPLE' not defined">.

The only other generic methods in C<Value> are for F<negate>, which
is required for subtraction, and F<reciprocal>, which is required for
division.  F<negate> passes the buck to a general scaling method,
which will be defined differently in each of the various subclasses:

        sub negate { $_[0]->scale(-1) }

F<reciprocal> is even simpler, because in general it's illegal.
You're not allowed to divide by a tuple (what would it mean?) or by a
feature (since this would mean that the equations were nonlinear;
consider M<x = 1/y>) so the default F<reciprocal> method dies:

        sub reciprocal { die "Nonlinear division" }

You I<are> allowed to divide by a constant, so
F<Value::Constant::reciprocal> will override this definition.

=subsubsection Constant Values

Of the three kinds of C<Value>, we'll look at C<Value::Constant>
first, because it's by far the simplest.  C<Value::Constant> objects
are essentially numbers.  The object is a hash with two members.  One
is the kind, which is C<CONSTANT>; the other is the numeric value.
The constructor accepts a number and generates a C<Value::Constant>
value with the number inside it:

        package Value::Constant;
        @Value::Constant::ISA = 'Value';

        sub new {
          my ($base, $con) = @_;
          my $class = ref $base || $base;
          bless { WHAT => $base->kindof,
                  VALUE => $con,
                } => $class;
        }

        sub kindof { "CONSTANT" }

        sub value { $_[0]{VALUE} }

To perform the F<scale> operation, we multiply the constant by the
argument:

        sub scale {
          my ($self, $coeff) = @_;
          $self->new($coeff * $self->value);
        }

Division is defined for constants, so we must override the fatal
F<reciprocal> method with one that actually performs division.  The
reciprocal of a constant is a new constant with the reciprocal value:

        sub reciprocal {
          my ($self, $coeff) = @_;
          my $v = $self->value;
          if ($v == 0) {
            die "Division by zero";
          }
          $self->new(1/$v);
        }

Finally, the dispatch table contains two methods for operating on
constants.  One adds two constants, and the other multiplies them:

        sub add_constants {
          my ($c1, $c2) = @_;
          $c1->new($c1->value + $c2->value);
        }

        sub mul_constants {
          my ($c1, $c2) = @_;
          $c1->new($c1->value * $c2->value);
        }

=subsubsection Tuple Values

Tuples represent displacements.  A tuple like C<(2, 3)> represents a
displacement of 2 units in the V<x> direction (east) and 3 units in
the V<y> direction (south).  As we'll see, C<linogram> isn't restricted to
two-dimensional drawings, so C<(2, 3, 4)> could also be a legal
displacement.  Although it's unlikely that any four-dimensional beings
will be using C<linogram>, there's no harm in making it as general as
possible, so internally, a tuple is a hash.  The keys are component
names (V<x>, V<y>, and so forth) and the values are the components.
The tuple C<(2, 3)> is represented by the hash C<{ x =\> 2, y =\> 3 }>.
C<(2, 3, 4)> is represented by the hash C<{ x =\> 2, y =\> 3, z =\> 4 }>.
The tuple class itself doesn't care what the component names are,
although this version of C<linogram> will refuse to generate tuples with
any components other than C<x>, C<y>, and possibly C<z>.

One possibly fine point is that tuple components need not be numbers;
they might be arbitrary C<Value>s.  A tuple like C<(3, hspc)> will
have a V<y> component which is a C<Value::Feature>.  It's even
conceivable that we could have a tuple whose components are other
tuples.  We'll take some pains to forbid this last possibility, since
it doesn't seem to have any meaning in the context of drawings.

Here is the constructor, which gets a component hash and returns a
tuple value object:

        package Value::Tuple;
        @Value::Tuple::ISA = 'Value';

        sub kindof { "TUPLE" }

        sub new {
          my ($base, %tuple) = @_;
          my $class = ref $base || $base;
          bless { WHAT => $base->kindof,
                  TUPLE => \%tuple,
                } => $class;
        }

it has a few straightforward accessors:

        sub components { keys %{$_[0]{TUPLE}} }
        sub has_component { exists $_[0]{TUPLE}{$_[1]} }
        sub component { $_[0]{TUPLE}{$_[1]} }
        sub to_hash { $_[0]{TUPLE} }

To perform subtraction on tuples, we will need a F<scale> operation
which multiplies a tuple by a number.   This is done componentwise.
C<2 * (2, 3)> is C<(4, 6)>.

        sub scale {
            my ($self, $coeff) = @_;
            my %new_tuple;
            for my $k ($self->components) {
              $new_tuple{$k} = $self->component($k)->scale($coeff);
            }
            $self->new(%new_tuple);
        }

Note that we must use C<$self-\>component($k)-\>scale($coeff)> rather
than C<$self-\>component($k) * $coeff>, because the component value
might not be a number.

Adding tuples will also be done componentwise.  We want to make sure
that the user doesn't try to add tuples with different components.
It's not clear what C<(2, 3) + (2, 3, 4)> would mean, for example.
This function takes two tuples and returns true if their component
lists are identical:

        sub has_same_components_as {
          my ($t1, $t2) = @_;
          my %t1c;
          for my $c ($t1->components) {
            return unless $t2->has_component($c);
            $t1c{$c} = 1;
          }
          for my $c ($t2->components) {
            return unless $t1c{$c};
          }
          return 1;
        }

Adding two tuples is one of the functions from the dispatch table:

        sub add_tuples {
          my ($t1, $t2) = @_;
          croak("Nonconformable tuples") unless $t1->has_same_components_as($t2);

          my %result ;
          for my $c ($t1->components) {
            $result{$c} = $t1->component($c) + $t2->component($c);
          }
          $t1->new(%result);
        }

The other dispatch table function that can return a tuple involves
multiplying a tuple by a constant.  This is a simple application of
F<scale>:

        sub mul_tuple_con {
          my ($t, $c) = @_;

          $t->scale($c->value);
        }


=subsubsection Feature Values

The code for handling feature values isn't much longer than the code for
handling tuples or constants, but it's more complex, because
arithmetic of features is more complex.   This is partly
because it's not really clear what it should mean to add two boxes
together.

What I<does> it mean to add two boxes together?  Suppose that V<A> and
V<B> are C<hline>s, and that we have the constraint M<A = B>, or,
equivalently, M<A - B = 0>, which involves a subtraction of two
C<hline> features.  What does this mean?

V<A> contains several X<intrinsic constraints>, including C<A.start.x
+ A.length = A.end.x>, and V<B> similarly contains C<B.start.x +
B.length = B.end.x>.  The end value of M<A - B> must contain both of
these constraints.  The subtraction won't affect them at all.  We will
need to carry along all the intrinsic constraints from both input
features into the result, but these intrinsic constraints don't
otherwise participate in the arithmetic.

But the end value also must include some constraints that relate the
two inputs, such as C<A.end.y - B.end.y = 0>, C<A.end.x - B.end.x =
0>, and so on.  We'll call these X<synthetic constraints|d>, because
they must be synthesized out of information that we find in the input
values.

A feature value has two parts, the X<intrinsic constraints|d> and the
X<synthetic constraints|d>.  Each is a set of constraints.  The
intrinsic constraints are those contributed by the definitions of the
features themselves, and are internal to particular features.  The
X<synthetic constraints> are those derived from the structure of the
expression and the interactions between the features in the expression.
The intrinsic constraints don't participate in arithmetic, and the
synthetic constraints do.

When we want to add (or subtract) two boxes, we unite their two
intrinsic constraint sets into a single set, which becomes the
intrinsic constraint set of the result.  But to combine the two
synthetic constraint sets, we perform arithmetic on I<corresponding>
synthetic constraints.  To keep track of which synthetic constraints
correspond, each one is labeled with a string.  A synthetic constraint
that involves the C<start.x> components of two C<hline>s will be
labeled with the string C<start.x> and will be combined with the
C<start.x> components of any other lines involved in the expression.
Synthetic  constraint sets will therefore be hashes.

=subsubsection Intrinsic Constraints

Intrinsic constraint sets are represented by the class
C<Intrinsic_Constraint_Set>.   An intrinsic constraint set is a simple
container class that holds a list of C<Constraint> objects.

        package Intrinsic_Constraint_Set;

        sub new {
          my ($base, @constraints) = @_;
          my $class = ref $base || $base;
          bless \@constraints => $class;
        }

        sub constraints  { @{$_[0]} }

It has only a few methods.  One is a C<map>-like function for invoking
a callback on each constraint in the set, and returning the set of the
results:

        sub apply {
          my ($self, $func) = @_;
          my @c = map $func->($_), $self->constraints;
          $self->new(@c);
        }

This is used by F<qualify>, which qualifies all the constraints in the
set:

        sub qualify {
          my ($self, $prefix) = @_;
          $self->apply(sub { $_[0]->qualify($prefix) });
        }


Last is F<union>, which takes one or more intrinsic constraint sets
and generates a new set that contains all the constraints in the input
sets:

        sub union {
          my ($self, @more) = @_;
          $self->new($self->constraints, map {$_->constraints} @more);
        }

=subsubsection Synthetic Constraints

C<Synthetic_Constraint_Set> is more interesting, because it supports
arithmetic rather than mere aggregation.    As mentioned earlier, a
synthetic constraint set is essentially a hash, because each
constraint in the set has a label which is used to determine which
constraints in other sets it will fraternize with.  For convenience,
the constructor accepts either a regular hash or a reference to a
hash:

        package Synthetic_Constraint_Set;

        sub new { 
          my $base = shift;
          my $class = ref $base || $base;

          my $constraints;
          if (@_ == 1) {
            $constraints = shift;
          } elsif (@_ % 2 == 0) {
            my %constraints = @_;
            $constraints = \%constraints;
          } else {
            my $n = @_;
            require Carp;
            Carp::croak("$n arguments to Synthetic_Constraint_Set::new");
          }

          bless $constraints => $class;
        }


It has the usual accessors:

        sub constraints { values %{$_[0]} }
        sub constraint { $_[0]->{$_[1]} }
        sub labels { keys %{$_[0]} }
        sub has_label { exists $_[0]->{$_[1]} }


Also a method for appending another constraint to the set:

        sub add_labeled_constraint {
          my ($self, $label, $constraint) = @_;
          $self->{$label} = $constraint;
        }

It has another C<map>-like function which applies a callback to each
constraint and returns a new set with the results.  It leaves the
labels unchanged:

        sub apply {
          my ($self, $func) = @_;
          my %result;
          for my $k ($self->labels) {
            $result{$k} = $func->($self->constraint($k));
          }
          $self->new(\%result);
        }

This function seems to be a good target for currying, but I decided to
postpone that change.

Like C<Intrinsic_Constraint_Set>, C<Synthetic_Constraint_Set> also has
a method for qualifying all of its constraints:

        sub qualify {
          my ($self, $prefix) = @_;
          $self->apply(sub { $_[0]->qualify($prefix) });
        }


I<Unlike> C<Intrinsic_Constraint_Set>, whose constraints are not
involved in arithmetic, C<Synthetic_Constraint_Set> has a method for
scaling all of its constraints:

        sub scale {
          my ($self, $coeff) = @_;
          $self->apply(sub { $_[0]->scale_equation($coeff) });
        }

Yet another C<map>-like function takes I<two> synthetic constraint
sets and applies the callback function to pairs of corresponding
constraints, building a new set of the results:

        sub apply2 {
          my ($self, $arg, $func) = @_;
          my %result;
          for my $k ($self->labels) {
            next unless $arg->has_label($k);
            $result{$k} = $func->($self->constraint($k), 
                                   $arg->constraint($k));
          }
          $self->new(\%result);
        }

=endlisting Value.pm

This function will be used for addition of features.  F<apply2> will be
called to add the matching constraints from the sets of its two
operands.  

This brings up a fine point:  what if the labels in the two sets don't
match?  For example, what if we have

        line L;
        hline H;
        L + H = ... ;

Here C<H> will have synthetic constraints

        center.x => H.center.x = 0
        center.y => H.center.y = 0
        end.x    => H.end.x = 0
        end.y    => H.end.y = 0
        length   => H.length = 0
        start.x  => H.start.x = 0
        start.y  => H.start.y = 0
        y        => H.y = 0

but C<L> will be missing a few of these, and will have only:

        center.x => L.center.x = 0
        center.y => L.center.y = 0
        end.x    => L.end.x = 0
        end.y    => L.end.y = 0
        start.x  => L.start.x = 0
        start.y  => L.start.y = 0

What happens to C<H>'s V<length> and V<y> constraints?  The right
thing to do here is to discard them.  The result set is

        center.x => L.center.x + H.center.x = 0
        center.y => L.center.y + H.center.y = 0
        end.x    => L.end.x + H.end.x = 0
        end.y    => L.end.y + H.end.y = 0
        start.x  => L.start.x + H.start.x = 0
        start.y  => L.start.y + H.start.y = 0

Thus the result of adding an C<hline> and a C<line> is just a C<line>.
Similarly if we try to equate an C<hline> and a C<vline>, the
resulting expression contains synthetic constraints only for the parts
they have in common.  The horizontalness and verticalosity are handled
by the intrinsic constraint sets instead.  There should probably be a
check to make sure that the two operands in an addition are of
compatible types, but that's something for the next version.  In the
meantime, the code in F<apply2> silently discards constraints with
labels present in one but not both argument sets.

The final method in C<Synthetic_Constraint_Set> is a special one for
handling arithmetic involving features and tuples.  Adding a feature to a
tuple is interesting. The trick here is that the tuple's V<x>
component must be added to all the synthetic constraints that
represent V<x> coordinates, and similarly for the V<y> component.
(And similarly also the V<z> component in a three-dimensional
drawing.)  Suppose we had

        hline H;
        H + (3, 4) = ...

The synthetic constraint set for C<H> is

        center.x => H.center.x = 0
        center.y => H.center.y = 0
        end.x    => H.end.x = 0
        end.y    => H.end.y = 0
        length   => H.length = 0
        start.x  => H.start.x = 0
        start.y  => H.start.y = 0
        y        => H.y = 0

The synthetic constraint set of the sum is:

        center.x => H.center.x + 3 = 0
        center.y => H.center.y + 4 = 0
        end.x    => H.end.x + 3 = 0
        end.y    => H.end.y + 4 = 0
        length   => H.length = 0
        start.x  => H.start.x + 3 = 0
        start.y  => H.start.y + 4 = 0
        y        => H.y = 0


How do we decide whether a synthetic constraint represents an V<x> or
a V<y> coordinate?  C<linogram> assumes that any feature named V<x> is an
V<x> coordinate, and that any feature named V<y> is a V<y> coordinate.
The tuple's V<x> component should be combined with any synthetic
constraint whose label ends in C<.x> or is plain C<x>.
This selective combination is handled by yet another C<map>-like
function, F<apply_hash>:

=contlisting Value.pm

        sub apply_hash {
          my ($self, $hash, $func) = @_;
          my %result;
          for my $c (keys %$hash) {
            my $dotc = ".$c";
            for my $k ($self->labels) {
              next unless $k eq $c || substr($k, -length($dotc)) eq $dotc;
              $result{$k} = $func->($self->constraint($k), $hash->{$c});
            }
          }
          $self->new(\%result);
        }

Each component of the argument hash has a label, C<$c>.  The function
scans the labels of the constraints in the set, which are indexed by
C<$k>.  If the constraint label matches the tuple component label, the
callback is invoked and its return value is added to the result set.
The labels match if they are equal (as with C<x> and C<x>) or if the
constraint label ends with a dot followed by the tuple label (as with
C<start.x> and C<x>.)  The dot is important, because we don't want a
label like C<max> or C<box> to match C<x>.

=subsubsection Feature Value Methods

Now we can see the methods for operating on feature value objects.  The
objects themselves contain nothing more than an intrinsic and a
synthetic constraint set:

        package Value::Feature;
        @Value::Feature::ISA = 'Value';

        sub kindof { "FEATURE" }

        sub new {
            my ($base, $intrinsic, $synthetic) = @_;
            my $class = ref $base || $base;
            my $self = {WHAT => $base->kindof,
                        SYNTHETIC => $synthetic,
                        INTRINSIC => $intrinsic,
                       };
            bless $self => $class;
        }

There's another very important constructor in the C<Value::Feature>
class.  Instead of building a value from given sets of constraints, it
takes a C<Type> object, which represents a type such as C<box> or
C<line>, figures out what its constraint sets should be, and builds a
new value with those constraint sets:

        sub new_from_var {
          my ($base, $name, $type) = @_;
          my $class = ref $base || $base;
          $base->new($type->qualified_intrinsic_constraints($name),
                     $type->qualified_synthetic_constraints($name),
                    );
        }

C<Value::Feature> naturally has two accessors, one for the intrinsic and
one for the synthetic constraint sets:

        sub intrinsic { $_[0]->{INTRINSIC} }
        sub synthetic { $_[0]->{SYNTHETIC} }

For its scaling operation, it passes the buck to the synthetic
constraint set.  The intrinsic constraints don't participate in
arithmetic, so they remain the same:

        sub scale {
          my ($self, $coeff) = @_;
          return 
            $self->new($self->intrinsic, 
                       $self->synthetic->scale($coeff),
                      );
        }

The four other methods are the ones from the dispatch table.  To add
two features, we unite their intrinsic constraint sets, and add
corresponding constraints from their synthetic constraint sets:

        sub add_features {
          my ($o1, $o2) = @_;
          my $intrinsic = $o1->intrinsic->union($o2->intrinsic);
          my $synthetic = $o1->synthetic->apply2($o2->synthetic,
                                                 sub { $_[0]->add_equations($_[1]) },
                                                );
          $o1->new($intrinsic, $synthetic);
        }

Adding constraints is performed by F<add_equations>, which is
inherited from C<Equation>.

As with tuples, multiplying a feature by a constant is trivial, since
it's the same as F<scale>:

        sub mul_feature_con {
          my ($o, $c) = @_;
          $o->scale($c->value);
        }


Adding a feature to a constant isn't hard, once we decide what it should
mean.  The current version of C<linogram> adds the constant to every
synthetic constraint.  This happens to be correct for features that
represent numbers, since, as we'll see, they have a single synthetic
constraint with label C<"">.  But it doesn't make much sense for most
other features.  Probably this function should contain a type check to
make sure that its feature argument represents a scalar, but that isn't
present in this version.

        sub add_feature_con {
          my ($o, $c) = @_;
          my $v = $c->value;
          my $synthetic = $o->synthetic->apply(sub { $_[0]->add_constant($v) });
          $o->new($o->intrinsic, $synthetic);
        }

Once again, the intrinsic constraints don't participate in arithmetic,
so they're unchanged.

The final method is for adding a feature to a tuple.  We use the
F<apply_hash> function that was specifically intended for adding
features to tuples.  its callback argument is complicated by the fact
that tuple components might not be simple numbers.  If the component
I<is> a simple number (a C<Value::Constant> object) then we use the
F<add_constant> method as in the previous function;

        sub add_feature_tuple {
          my ($o, $t) = @_;
          my $synthetic = 
            $o->synthetic->apply_hash($t->to_hash, 
                                      sub { 
                                        my ($constr, $comp) = @_;
                                        my $kind = $comp->kindof;
                                        if ($kind eq "CONSTANT") {
                                          $constr->add_constant($comp->value);

If the tuple component is a feature, we assume that it's a scalar, which
has only a single constraint, with label C<"">:

                                        } elsif ($kind eq "FEATURE") {
                                          $constr->add_equations($comp->synthetic->constraint(""));

If the tuple component is another tuple, we croak, because that's not
allowed.  This freak tuple should have been forbidden earlier, but
there's little harm in adding more than one check for the same thing.

                                        } elsif ($kind eq "TUPLE") {
                                          die "Tuple with subtuple component";
                                        } else {
                                          die "Unknown tuple component type '$kind'";
                                        }
                                      },
                                     );
          $o->new($o->intrinsic, $synthetic);
        }

        1;

=endlisting Value.pm

Once again, the intrinsic constraints are unchanged because they don't
participate in arithmetic.

=subsection Feature Types

Where do the constraints come from?  If the equation solver is the
heart of C<linogram>, then its liver is the parser, which parses the input
specification, including the constraint equations.  The result of
parsing is a hierarchy of feature types such as C<box> and C<line>.
These are Perl objects from the class C<Type>.  Each type of feature is
represented by a C<Type> object, which records the sub-features, the
constraints, and the other properties of that kind of feature object.

To construct a new type, we call C<Type::new>:

=startlisting Type.pm

        package Type;

        sub new {
          my ($old, $name, $parent) = @_;
          my $class = ref $old || $old;
          my $self = {N => $name, P => $parent, C => [], 
                      O => {}, D => [], 
                     };
          bless $self => $class;
        }

C<$name> is the name of the new type.  C<$parent> is optional, and, if
present, is a C<Type> object representing the type from
which the new type is extended.  For example, the parent of C<vline> is
C<line>; the parent of C<line> is undefined.  The parent type is
stored under member C<P> for "parent"; the name is stored under C<N>.

The other members of the C<Type> object are:

=bulletedlist

=item B<C>: The constraints defined for the object.

=item B<O>: The subfeatures of the type.  This is a hash.  The keys are
the names of the subfeatures, and the values are the C<Type> objects
representing the types of the subfeatures.

=item B<D>: A list of "drawables", either Perl code references or
subfeature names.  

=endbulletedlist

=subsubsection Scalar Types

C<Type> has a subclass, C<Type::Scalar>, which represents trivial
types, such as C<number>, that have no constraints and no subfeatures.
C<linogram> has no scalar types other than C<number>, but a future version
might introduce one.

Sometimes these types behave a little differently from compound types
such as points and boxes, so it's convenient to put their methods into
another class.  One principal difference is the trivial C<is_scalar>
method, which returns true for a scalar type object and false for a
nonscalar object.  C<Type::Scalar> also overrides the methods that are
used to install constraints and subfeatures into type objects:

        package Type::Scalar;
        @Type::Scalar::ISA = 'Type';

        sub is_scalar { 1 }

        sub add_constraint { 
          die "Added constraint to scalar type";
        }

        sub add_subfeature { 
          die "Added subfeature to scalar type";
        }

We should never be extending scalar types like C<number> with subfeatures
or constraints, so overriding these methods provides us with early
warning if something is going terribly wrong.  

=subsubsection C<Type> methods

The simplest C<Type> method says that types are not scalars, except
when the method is overridden by the C<Type::Scalar> version of the
method:

        package Type;

        sub is_scalar { 0 }

Many of the accessor methods on C<Type> objects are straightforward;
for example

        sub parent { $_[0]{P} }

But in some cases, an accessor needs to be referred up the derivation
chain to the parent type.  For example, a C<vline> also has a subfeature
named C<start>, but it's not stored in the type object for C<vline>;
it's inherited from C<line>.  So if we want find out about the type of
the C<start> subfeature of C<vline>, we must search in C<line>.
Moreover, a C<vline> does have a subfeature named C<start.x>, which is
the C<x> subfeature of the C<start> subfeature.  The C<subfeature> method
handles all of these situations:

        sub subfeature { 
          my ($self, $name, $nocroak) = @_;
          return $self unless defined $name;
          my ($basename, $suffix) = split /\./, $name, 2;
          if (exists $_[0]{O}{$basename}) {
            return $_[0]{O}{$basename}->subfeature($suffix); 
          } elsif (my $parent = $self->parent) {
            $parent->subfeature($name);
          } elsif ($nocroak) {
            return;
          } else {
            Carp::croak("Asked for nonexistent subfeature '$name' of type '$self->{N}'");
          }
        }

C<$type-\>subfeature($name)> returns the type of the subfeature of
C<$type> with name C<$name>.  If C<$name> is a compound name, which
contains a dot, it is split into a C<$basename> (the component before
the first dot) and a C<$suffix> (everything after the first dot); the
C<$basename> is looked up directly, and the C<$suffix> is referred to
a recursive call to C<subfeature>.  If the specified type does not
contain a subfeature with the appropriate basename, then its parent
object is consulted instead.  If there is no parent type, then the
requested subfeature doesn't exist, and the function croaks.  This is
because the error is most likely to be caused by an incorrect
specification in the drawing, asking for a nonexistent subfeature.  To
disable the croaking behavior, the user of the function can pass the
optional third parameter, which makes the function return false
instead.  An example of this is the simple C<has_subfeature> method,
which returns true if the target has a subfeature of the specified name,
and false if not:

        sub has_subfeature
         {
          my ($self, $name) = @_;
          defined($self->subfeature($name, "don't croak"));
        }

=endlisting Type.pm

The recursion in F<subfeature> is in two different directions.
Sometimes we recurse from a feature to one of its subfeatures, and
sometimes we recurse of the type inheritance tree to the parent type.
Suppose C<$box>, C<$hline>, C<$line>, C<$point>, and C<$number> are
the C<Type> objects that represent the indicated types.
Let's see how the call C<$box-\>subfeature("top.start.x")> is resolved:

        $box->subfeature("top.start.x")

C<$box> has a subfeature called C<"top">, which is an C<hline>, so the
call is referred to the subfeature type:

        $hline->subfeature("start.x");

C<$hline> has no subfeature called C<"start">, so the call is referred to
the parent type:

        $line->subfeature("start.x");

C<$line> does have a subfeature called C<"start">, which is a C<point>,
so the call is referred to the subfeature type:

        $point->subfeature("x");

C<$point> does have a subfeature called C<"x">, which is a C<number>,
so the call is referred to the subfeature type:

        $number->subfeature(undef);

The call reaches the base case and returns C<$number>, which is indeed
the type of the C<top.start.x> feature of C<box>.

A similar process occurs in the C<Type::constraints> method,
which delivers an array of all the constraints of a type, including
those implied by the subfeatures and the parent type.  

=contlisting Type.pm

        sub constraints {
          my $self = shift;

First the function obtains the constraints inherent in the type
itself:

          my @constraints = @{$self->{C}};

Then it obtains the constraints that are inherited from the parent
type, and, via recursion, from all the ancestor types:

          my $p = $self->parent;
          if (defined $p) { push @constraints, @{$p->constraints} }

Then it obtains the constraints that it gets from its subfeatures,
including any constraints that I<they> inherit from their ancestor
types:

          while (my ($name, $type) = each %{$self->{O}}) {
            my @subconstraints = @{$type->constraints};
            push @constraints, map $_->qualify($name), @subconstraints;
          }
          \@constraints;
        }


F<constraint_set> is the same, except that it returns a
C<Constraint_Set> object instead of a raw array reference.

        sub constraint_set {
          my $self = shift;
          Constraint_Set->new(@{$self->constraints});
        }

These constraints are precisely the X<intrinsic constraints> that are
used by C<Value::Feature> objects, so we have

        sub intrinsic_constraints {
          my $constraints = $_[0]->constraints;
          Intrinsic_Constraint_Set->new(@$constraints); 
        }

The C<new_from_type> method of C<Value::Feature> actually wants the
I<qualified> intrinsic constraints:

        sub qualified_intrinsic_constraints {
          $_[0]->intrinsic_constraints->qualify($_[1]);
        }

=endlisting Type.pm

As usual, the synthetic constraints for a type are rather more
interesting.  In the absence of any other information, an expression
like C<P> is interpreted as the constraint M<P = 0>.  Later, the M<P =
0> might be combined with a M<Q = 0> to produce M<P + Q = 0> or M<P -
Q = 0>, and we'll see that we can treat M<P = Q> as if it were M<P - Q
= 0>.  So figuring out the synthetic constraints for a type like
C<point>  involves locating all the scalar type subfeatures of C<point>,
and then setting each one to 0.

The recursive auxiliary method F<all_leaf_subfeatures> recovers the
names of all the scalar subfeatures of the given type.  Its name refers
to the fact that the subfeature relation makes each type into a tree.
For example:

=picture subfeature-tree

                         (hline)
                        ,-'/|`-.-.
                     ,-' ,' (   `.`-.
                  ,-'   /    \    `. `--.
               ,-'     /     (      `.   `-.
            ,-'       /       \       `-.   `--.
        center      end     length     start    y
          ) \       /\                  /(
         /  (      /  \                /  \
        x    y    x    y              x    y


=endpicture subfeature-tree

The scalar subfeatures are the leaves of the tree.

=contlisting Type.pm

        sub all_leaf_subfeatures {
          my $self = shift;
          my @all;
          my %base = $self->subfeatures;
          while (my ($name, $type) = each %base) {
            push @all, map {$_ eq "" ? $name : "$name.$_"} 
              $type->all_leaf_subfeatures;
          }
          @all;
        }

We start by getting all the direct subfeatures.  These include those
defined directly by the target type and also those defined by its
ancestor types.  Some of these subfeatures might be compound features and
have subfeatures of their own, and some might be leaves.  We loop over
them to do the recursion on each one.  The function qualifies the
names appropriately and adds the information to the result array.  The
special case in the C<map> is to avoid extra periods from appearing at
the end of the key names in some cases.

To build the synthetic constraint set for a particular type, we locate
all the scalar subfeatures and make a constraint for each one.  If
V<name> is the name of a scalar subfeature, we introduce the synthetic
constraint that has M<name = 0> with label V<name>.  

        sub synthetic_constraints {
          my @subfeatures = $_[0]->all_leaf_subfeatures;
          Synthetic_Constraint_Set->new(map {$_ => Constraint->new($_ => 1)}
                                                  @subfeatures
                                                 );
        }

        sub qualified_synthetic_constraints {
          $_[0]->synthetic_constraints->qualify($_[1]);
        }


All but one of the remaining C<Type> methods are accessors, most of
them fairly simple.  

        sub add_drawable {
          my ($self, $drawable) = @_;
          push @{$self->{D}}, $drawable;
        }

F<subfeatures> returns all the direct subfeatures of a type, but not the
sub-subfeatures.  For C<box>, it will return C<top> and C<nw>, but not
C<top.center> or C<nw.y>.

        sub subfeatures {
          my $self = shift;
          my %all;
          while ($self) {
            %all = (%{$self->{O}}, %all);
            $self = $self->parent;
          }
          %all;
        }

The function that retrieves the list of drawable subfeatures and drawing
functions for a type recurses up the type inheritance tree using
F<subfeatures>.  It doesn't need to recurse into the subfeatures, because
the drawing method will do that itself.  We'll see the drawing method
later; here's the F<drawables> method, which returns a list of the
drawables:

        sub drawables {
          my ($self) = @_;
          return @{$self->{D}} if $self->{D} && @{$self->{D}};
          if (my $p = $self->parent) {
            my @drawables = $p->drawables;
            return @drawables if @drawables;
          }

          my %subfeature = $self->subfeatures;
          my @drawables = grep ! $subfeature{$_}->is_scalar, keys %subfeature;
          @drawables;
        }
                

If the type definition contains an explicit drawable list, the method
returns it.  If not, it uses the drawable list of its parent object,
if it has one.  If the type has no parent type, the method generates
and returns the default, which is a list of all the subfeatures that
aren't scalars.  There's no point returning scalars, since they're not
drawable, so they're filtered out.

New subfeatures are installed into a type with F<add_subfeature>.  Its
arguments are a name and a subfeature type:

        sub add_subfeature {
          my ($self, $name, $type) = @_;
          $self->{O}{$name} = $type;
        }

Similarly, new constraints are installed into a type with
F<add_constraints>.  Its argument are  C<Value::Feature> objects.   The
method extracts the constraints from the values and inserts them into
the C<Type> object:

        sub add_constraints {
          my ($self, @values) = @_;
          for my $value (@values) {
            next unless $value->kindof eq 'FEATURE';
            push @{$self->{C}}, 
              $value->intrinsic->constraints, 
              $value->synthetic->constraints;
          }
        }

I've left the most important C<Type> method for the end.  It's the
most important method in the entire program, because it's the method
that actually draws the picture.  Its primary argument is a C<Type>
object.  When invoked for the root type, it draws the entire picture.
It's a little longer than the other methods, so we'll see it a bit at
a time.

        sub draw {
          my ($self, $env) = @_;

The primary argument, C<$self>, is the type to draw.  The other
argument is an X<environment|d>, which belongs to an C<Environment>
class we didn't see.  The environment is nothing more than a hash with
the names and values of the solutions of the constraints.N<In an
earlier version of this program, the environment parameter was more
interesting.  Features could contain local variables, which didn't
participate in the constraint solving (and which therefore didn't have
to be linear) and parameters passed in from the containing feature.  In
the interests of clear exposition, I trimmed these features out.> The
initial call to F<draw>, which draws the root feature, omits the
environment, because the equations haven't been solved yet; the
missing C<$env> parameter triggers F<draw> to solve the equations:

          unless ($env) {
            my $equations = $self->constraint_set;
            my %solutions = $equations->values;
            $env = Environment->new(%solutions);
          }

The rest of the function does the actual drawing.  It scans the list
of drawables for the type.  If the drawable is a reference to an
actual drawing function, the function is invoked, and is passed the
environment.

          for my $name ($self->drawables) {
            if (ref $name) { 		# actually a coderef, not a name
              $name->($env);

Otherwise, the drawable is the name of a subfeature on which the F<draw>
method is recursively called.  The function recovers the type of the
subfeature.  It also uses the F<Environment::subset> method to construct
a new environment which contains only the variables relevant to that
subfeature.  

            } else {
              my $type = $self->subfeature($name);
              my $subenv = $env->subset($name);
              $type->draw($subenv);
            }
          }
        }

        1;

=endlisting Type.pm

For completeness, here is F<Environment::subset>:


=startlisting Environment.pm

        sub subset {
          my ($self, $name) = @_;
          my %result;
          for my $k (keys %$self) {
            my $kk = $k;
            if ($kk =~ s/^\Q$name.//) {
              $result{$kk} = $self->{$k};
            }
          }
          $self->new(%result);
        }

=endlisting Environment.pm


=subsection The Parser

We're now ready to see the core of C<linogram>, which is the parser that
parses drawing specifications. First, the X<lexer>, which is
straightforward:

=test linogram 1

        is(system("perl -IPrograms -c Program/linogram.pl 2>&1 >>/dev/null"),
           0, "syntax check");

=endtest

=startlisting linogram.pl

        use Parser ':all';
        use Lexer ':all';

        my $input = sub { read INPUT, my($buf), 8192 or return; $buf };

        my @keywords = map [uc($_), qr/\b$_\b/],
          qw(constraints define extends draw);

        my $tokens = iterator_to_stream(
              make_lexer($input,
                         @keywords,
                         ['ENDMARKER',  qr/__END__.*/s,
                          sub {
                            my $s = shift;
                            $s =~ s/^__END__\s*//;
                            ['ENDMARKER', $s]
                          } ],
                         ['IDENTIFIER', qr/[a-zA-Z_]\w*/],
                         ['NUMBER', qr/(?: \d+ (?: \.\d*)?
                                       | \.\d+)
                                       (?: [eE]  \d+)? /x ],
                         ['FUNCTION',   qr/&/],
                         ['DOT',        qr/\./],
                         ['COMMA',      qr/,/],
                         ['OP',         qr|[-+*/]|],
                         ['EQUALS',     qr/=/],
                         ['LPAREN',     qr/[(]/],
                         ['RPAREN',     qr/[)]/],
                         ['LBRACE',     qr/[{]/],
                         ['RBRACE',     qr/[}]\n*/],
                         ['TERMINATOR', qr/;\n*/],
                         ['WHITESPACE', qr/\s+/, sub { "" }],
                         ));


=endlisting linogram.pl

Only a few of these need comment.  C<IDENTIFIER> is a simple variable
name, such as C<box> or C<start>.  Compound names like C<start.x> will
be assembled later, by the parser.

C<ENDMARKER> consists of the sequence
C<__END__> and I<all> the following text up to the end of the file.
The lexer preprocesses this to delete the C<__END__> itself, leaving
only the following text.

Several similar definitions for the C<CONSTRAINTS>, C<DEFINE>,
C<EXTENDS>, and C<DRAW> tokens are generated programmatically, and are
inserted at the beginning of the lexer definition via the C<@keywords>
array.

Whitespace, as in earlier parsers, is discarded.

=subsubsection Parser Extensions

The parser module use in C<linogram> is based on our functional parser
library of R<parser|chapter>, with some additions.  Suppose that C<$A>
and C<$B>  are parsers.  Recall the following features supplied by
the parser of R<parser|chapter>:

=bulletedlist

=item C<empty()> is a parser that consumes no tokens and always succeeds.

=item C<$A - $B> ("V<A>, then V<B>") is a parser that matches whatever
C<$A> matches, consuming the appropriate tokens, and then applies
C<$B> to the remaining input, possibly consuming more tokens.  It
succeeds only if both C<$A> and C<$B> succeed in sequence.

=item C<$A | $B> ("V<A> or V<B>") is a parser that tries to apply
C<$A> to its input, and, if that doesn't work, tries C<$B> instead.  It
succeeds if either of C<$A> or C<$B> succeeds.

=item C<star($A)> matches zero or more occurrences of whatever C<$A>
matches; it is equivalent to C<empty() | $A - star($A)>.

=endbulletedlist

To these operations, we'll add a few extras.

=bulletedlist 

=item C<_(...)> is a synonym for C<lookfor([...])>, which builds a
parser that looks for a single token of the indicated kind.  If the
next token is of the correct kind, it is consumed and the parser
succeeds; otherwise the parser fails.  X<lookfor|fi>

=item C<$A \>\> $coderef> is a synonym for C<T($A, $coderef)>, a
parser that applies C<$A> to its input stream, and then uses
C<$coderef> to transform the result returned by C<$A> into a different
form.  It assumes that C<$A> is a concatenation of other parsers.

=item C<option($item)> indicates that the syntax matched by the
C<$item> parser is optional.  It builds a parser equivalent to

        $item | empty()

=item C<labeledblock($label, $contents)> is for matching labeled blocks like

        draw { 
          ...
        }

and

        define line {
          ...
        }

It's equivalent to 

        $label - _('LBRACE') - star($contents) -_('RBRACE')
          >> sub { [ $_[0], @{$_[2]} ] }


=item C<commalist($item, $separator)> is for matching comma-separated
lists of items.  The C<$separator> defaults to C<_('COMMA')>.  It is
otherwise equivalent to

        $item - star($separator - $item >> sub { $_[1] }) 
              - option($separator)
          >> sub { [ $_[0], @{$_[1]} ] }
        
The first C<sub> throws away the values associated with the
separators, leaving only the values of the items.  The second C<sub>
accumulates all the item values into a single array, which is the
value returned by the C<commalist> parser.

=item C<$parser \> $coderef> is like C<$parser \>\> $coderef>, except
that it doesn't assume that C<$parser> is a concatenation.  Instead of
assuming that the value returned by C<$parser> is an array reference, and
passing the elements of the array to the coderef, it passes the
value returned by C<$parser> directly to C<$coderef> as a single
argument.

=item C<$parser / $condition> is like C<$parser>, with a side
condition on the result.  It runs C<$parser> as usual, and then passes
the resulting value to the coderef in C<$condition>.  If the condition
returns true, the parser succeeds, and the final result is that same
value originally returned by C<$parser>.  If the coderef returns
false, the parser fails.

=endbulletedlist

=startlisting Parser_Lino.pm invisible

        package Parser_Lino;
        use Parser ':all';
        @EXPORT_OK = (@Parser::EXPORT_OK, 
                        '_', 'option', 'labeledblock', 'commalist');
        %EXPORT_TAGS = (all => \@EXPORT_OK);

        use overload ('-' => 

        sub parser (&) {
          my $p = shift;
          bless $b => __PACKAGE__;
        }

=endlisting Parser_Lino.pm 

=subsubsection C<%TYPES>

The main data structure in C<linogram> is C<%TYPES>, which is a hash that
maps known type names to the C<Type> objects that represent
them.  When the program starts, C<%TYPES> is initialized with two
predefined types:

=contlisting linogram.pl

        my $ROOT_TYPE = Type->new('ROOT');
        my %TYPES = ('number' => Type::Scalar->new('number'),
                     'ROOT'   => $ROOT_TYPE,
                    );

Initially, C<linogram> knows about the type C<number>, which is a trivial
type with no subfeatures and no constraints, and the type C<ROOT>,
which represents the entire diagram.

=subsubsection Programs

A program in C<linogram> is a series of subtype definitions and feature and
constraint declarations which together define the root type.  As
subtype definitions are encountered, the corresponding C<Type> objects
are manufactured and installed in C<%TYPES>.  As feature and constraint
declarations are encountered, they are installed into the root type
object.

The top level parser looks like this:

        $program = star($Definition 
                      | $Declaration
                        > sub { add_declarations($ROOT_TYPE, $_[0]) }
                      )
                 - option($Perl_code) - $End_of_Input
          >> sub {
            $ROOT_TYPE->draw();
          };

The C<$definition> parser will take care of manufacturing new type
objects and installing them into C<%TYPES>.  When a declaration is
parsed, F<add_declarations> will install it into the root type object
C<$ROOT_TYPE>.  The program may be followed with an optional section
of plain Perl code, which is a convenient place to stick auxiliary
functions like C<draw_line>.  When the parser finishes parsing the
entire specification, it invokes the C<draw> method on the root type
object, drawing the entire diagram.

C<$perl_code> is an optional section at the end of the drawing
specification.  It's an arbitrary segment of perl code, separated from
the rest of the specification with the endmarker C<__END__>:

        $perl_code = _("ENDMARKER") > sub { eval $_[0];
                                            die if $@; 
                                          };

=endlisting linogram.pl

The lexer has already trimmed off the endmarker itself.  The Perl code
is then passed to C<eval>, which compiles the Perl code and installs
it into the program.  The C<$perl_code> section is a convenient place
to put auxiliary functions such as drawing functions.

=subsubsection Definitions

A C<$definition> is a parser for a block of the form

        define point { ... }

or
          
        define hline extends line { ... }

We use the C<labeledblock> function to construct this parser:

        $definition = labeledblock($Defheader, $Declaration)
          >> sub { ... } ;

C<$declaration> is the parser for a declaration, which will see
shortly.  C<$defheader> is the part of the definition block before the
curly braces:

=contlisting linogram.pl

        $defheader = _("DEFINE") - _("IDENTIFIER") - $Extends
          >> sub { ["DEFINITION", @_[1,2] ]};

        $extends = option(_("EXTENDS") - _("IDENTIFIER") >> sub { $_[1] }) ;


The value from the C<$definition> parser is passed to a postprocessing
function which is responsible for constructing a new C<Type> object
and installing it into C<%TYPES>; the code is all straightforward.
For a definition that begins C<define hline extends line>, C<$name> is
C<hline> and C<$extends> is C<$line>.


        $definition = labeledblock($Defheader, $Declaration)
          >> sub {
             my ($defheader, @declarations) = @_;
             my ($name, $extends) = @$defheader[1,2];
             my $parent_type = (defined $extends) ? $TYPES{$extends} : undef;
             my $new_type;

             if (exists $TYPES{$name}) {
               lino_error("Type '$name' redefined");
             }
             if (defined $extends && ! defined $parent_type) {
               lino_error("Type '$name' extended from unknown type '$extends'");
             }

             $new_type = Type->new($name, $parent_type);

             add_declarations($new_type, @declarations);

             $TYPES{$name} = $new_type;
          };

=endlisting linogram.pl

=subsubsection Declarations

A declaration takes one of three forms.  One is the declaration of one
or more subfeatures:

          hline top, bottom;

Two others are C<constraints> and C<draw> sections:

          constraints { ... }
          draw { ... }

Here's the declaration parser again:

        $declaration = $Type - commalist($Declarator) - _("TERMINATOR")
                         >> sub { ... } 
                     | $Constraint_section 
                     | $Draw_section
                     ;

A C<$type> is the same as an identifier, with the side condition that
it must be mentioned in the C<%TYPES> hash:

=contlisting linogram.pl

        $type = lookfor("IDENTIFIER",
                        sub {
                          exists($TYPES{$_[0][1]}) || lino_error("Unrecognized type '$_[0][1]'");
                          $_[0][1];
                        }
                       );


=endlisting linogram.pl

A declaration might declare more than one variable, as with

        hline top, bottom;

Each of the sub-parts of the declaration is called a X<declarator|d>;
the declaration above has two declarators.    In its simplest form, a
declarator is nothing more than a variable name:

=contlisting linogram.pl

        $declarator = _("IDENTIFIER") 
                    - option(_("LPAREN")  - commalist($Param_Spec) - _("RPAREN")
                             >> sub { $_[1] }
                            )
          >> sub {
            { WHAT => 'DECLARATOR',
              NAME => $_[0],
              PARAM_SPECS => $_[1],
            };
          };

=endlisting linogram.pl

The optional section in the middle is for a parenthesis-delimited list
of "parameter specifications".  A declarator might look like this:

        ... F(ht=3, wd=boxwid), ...

which is equivalent to

        ... F, ...
        F.ht = 3;
        F.wd = boxwid;

The C<sub { $_[1] }> discards the parentheses; the parameter
specifications are packaged into the resulting value under the key
C<PARAM_SPECS>.  The format of a parameter specification is simple:

=contlisting linogram.pl

        $param_spec = _("IDENTIFIER") - _("EQUALS") - $Expression
          >> sub {
            { WHAT => "PARAM_SPEC",
              NAME => $_[0],
              VALUE => $_[2],
            }
          }
          ;

=endlisting linogram.pl

Thus the value manufactured for the declarator C<F(ht=3, wd=boxwid)>
looks like this:

        { WHAT => 'DECLARATOR',
          NAME => 'F',
          PARAM_SPECS => 
            [ { WHAT => 'PARAM_SPEC',
                NAME => 'ht',
                VALUE => (expression representing constant 3),
              },
              { WHAT => 'PARAM_SPEC',
                NAME => 'wd',
                VALUE => (expression representing variable 'boxwid'),
              },
            ]
        }
                
We haven't yet seen the representation for expressions.

The C<$declaration> parser gets a type name and a list of declarators
and manufactures a declaration value; later on, the
F<add_declarations> function will install this declaration into the
appropriate C<Type> object.  The declaration value is manufactured as
follows:

=contlisting linogram.pl

        $declaration = $Type - commalist($Declarator) - _("TERMINATOR")
                         >> sub { my ($type, $decl_list) = @_;
                                  unless (exists $TYPES{$type}) {
                                    lino_error("Unknown type name '$type' in declaration '@_'\n");
                                  }
                                  for (@$decl_list) {
                                    $_->{TYPE} = $type;
                                    check_declarator($TYPES{$type}, $_);
                                  }
                                  {WHAT => 'DECLARATION', 
                                   DECLARATORS => $decl_list };
                                }

=endlisting linogram.pl

                      ....

=contlisting linogram.pl invisible

                     | $Constraint_section 
                     | $Draw_section
                     ;

=endlisting linogram.pl

The construction function checks to make sure the type used in the
declaration actually exists.  It then installs the type into each
declarator value, transforming

        { WHAT => 'DECLARATOR',
          NAME => 'F',
          PARAM_SPECS => [ ... ],
        }

into 

        { WHAT => 'DECLARATOR',
          NAME => 'F',
          PARAM_SPECS => [ ... ],
*         TYPE => $type,        
        }

Each declarator is also checked to make sure the names in its
parameter specifications are actually the names of subfeatures of its
type.  C<box F(ht=3);> passes the check, but C<box F(age=34)> fails,
because boxes don't have ages.  This check is performed by
F<check_declarator>:

=contlisting linogram.pl

        sub check_declarator {
          my ($type, $declarator) = @_;
          for my $pspec (@{$declarator->{PARAM_SPECS}}) {
            my $name = $pspec->{NAME};
            unless ($type->has_subfeature($name)) {
              lino_error("Declaration of '$declarator->{NAME}' " 
                       . "specifies unknown subfeature '$name' "
                       . "for type '$type->{N}'\n");  
            }
          }
        }

=endlisting linogram.pl


Declarator values are combined into declaration values; a typical
declaration value, for the declaration C<box C, F(ht=3, wd=boxwid);>,
looks like this:

        { WHAT => 'DECLARATION',
          DECLARATORS => 
            [ { WHAT => 'DECLARATOR',
                NAME => 'C',
                PARAM_SPECS => [],
                TYPE => 'box',
              },
              { WHAT => 'DECLARATOR',
                NAME => 'F',
                PARAM_SPECS => 
                  [ { WHAT => 'PARAM_SPEC',
                      NAME => 'ht',
                      VALUE => (expression representing constant 3),
                    },
                    { WHAT => 'PARAM_SPEC',
                      NAME => 'wd',
                      VALUE => (expression representing variable 'boxwid'),
                    },
                  ]
                TYPE => 'box',
              },
            ]
        }

The other two kinds of declarations we've seen before have been
constraint and draw sections, which have their own productions in the
grammar:


        $declaration = ...
                     | $Constraint_section 
                     | $Draw_section
                     ;


Constraint sections are a little simpler, so we'll see them first.
The overall structure of a constraint section is a block, labeled
with the word C<constraints>:


=contlisting linogram.pl


        $constraint_section = labeledblock(_("CONSTRAINTS"), $Constraint)
          >> sub { shift;
                   { WHAT => 'CONSTRAINTS', CONSTRAINTS => [@_] }
                 };

A constraint is simply an equation, which is a pair of expressions
with an equals sign in between them:

        $constraint = $Expression - _("EQUALS") - $Expression - _("TERMINATOR")
          >> sub { Expression->new('-', $_[0], $_[2]) } ;

=endlisting linogram.pl

The value of the constraint is not actually a C<Constraint>
object, but rather an C<Expression> object.  Since the constraint M<A
= B> is semantically equivalent to M<A - B = 0>, we compile it into an
expression that represents C<A - B> and leave it at that.  The
finished value for a constraint section, say for

        constraints { start.x = end.x;
                      start.x = x;
                      start.y + height = end.y;
                    }

is the hash

        { WHAT => 'CONSTRAINTS',
          CONSTRAINTS => 
            [ (expression representing start.x - end.x),
              (expression representing start.x - x),
              (expression representing start.y + height - end.y),
            ]
        }

The third sort of declaration is a C<draw> section, which might look
like this:

        draw { &draw_line; }

or like this:

        draw { top; bottom; left; right; }

Once again, it is a labeled block, very similar to the definition of
the constraint section:

=contlisting linogram.pl

        $draw_section = labeledblock(_("DRAW"), $Drawable)
          >> sub { shift; { WHAT => 'DRAWABLES', DRAWABLES => [@_] } };

Since there are two possible formats for a drawable, however, the
definition of C<$drawable> is a little more complicated than the
definition of C<$constraint>:

        $drawable = $Name - _("TERMINATOR")
                        >> sub { { WHAT => 'NAMED_DRAWABLE',
                                   NAME => $_[1],
                                 }
                               }
                  | _("FUNCTION") - _("IDENTIFIER") - _("TERMINATOR")
                         >> sub { my $ref = \&{$_[1]};
                                  { WHAT => 'FUNCTIONAL_DRAWABLE',
                                    REF => $ref,
                                    NAME => $_[1],
                                  };
                                };

=endlisting linogram.pl

The first clause handles the case where the drawable is the name
of a subfeature of the feature being defined, say C<top;>.  In this
case we construct the value

        { WHAT => 'NAMED_DRAWABLE',     
          NAME => 'top',
        }

The other clause handles the case where the drawable is the name of a
Perl function, say C<&draw_line;>.  In this case we construct the value

        { WHAT => 'FUNCTIONAL_DRAWABLE',     
          NAME => 'draw_line',
          REF => \&draw_line,
        }

The C<NAME> member here is just for debugging purposes; only the
reference is actually used.  Drawables of both types may be mixed in
the same C<draw> section.  A draw section like C<draw { top;
&draw_line; }> turns into the value

        { WHAT => 'DRAWABLES',
          DRAWABLES => [ { WHAT => 'NAMED_DRAWABLE',
                           NAME => 'TOP',
                         },
                         { WHAT => 'FUNCTIONAL_DRAWABLE',     
                           NAME => 'draw_line',
                           REF => \&draw_line,
                         },
                       ]
        }

When a complete type definition has been parsed, several values will
be available: the type name; the name of the parent type, if there is
one; and the list of declarations.  The parser function manufactures a
new type object from class C<Type>, and calls
F<add_declarations> to install the declarations into the new object.

F<add_declarations> is rather complicated, because it has many
different branches to handle the different kinds of declarations.
Each branch individually is simple, which argues for a dispatch table
structure.  

=contlisting linogram.pl

        my %add_decl = ('DECLARATION' => \&add_subfeature_declaration,
                        'CONSTRAINTS' => \&add_constraint_declaration,
                        'DRAWABLES' => \&add_draw_declaration,
                        'DEFAULT' =>  sub {
                          lino_error("Unknown declaration kind '$[1]{WHAT}'");
                        },
                       );

        sub add_declarations {
          my ($type, @declarations) = @_;

          for my $declaration (@declarations) {
            my $decl_kind = $declaration->{WHAT};
            my $func = $add_decl{$decl_kind} || $add_decl{DEFAULT};
            $func->($type, $declaration);
          }
        }

Subfeature declarations to C<Type> objects are added by this function,
which loops over the declarators, adding them one at a time:

        sub add_subobj_declaration {
          my ($type, $declaration) = @_;
          my $declarators = $declaration->{DECLARATORS};
          for my $decl (@$declarators) {
            my $name = $decl->{NAME};
            my $decl_type = $decl->{TYPE};
            my $decl_type_obj = $TYPES{$decl_type};

C<$decl_type> is the name of the type of the subfeature being declared;
C<$decl_type_obj> is the C<Type> object that represents that type.
The first thing we do is record the name and the type of the new
subfeature:

            $type->add_subfeature($name, $decl_type_obj);

Unless the declarator came with parameter specifications, we're done.
If there were parameter specifications, we turn them into constraints
and add them to the type's list of constraints:

            for my $pspec (@{$decl->{PARAM_SPECS}}) {
              my $pspec_name = $pspec->{NAME};
              my $constraints = convert_param_specs($type, $name, $pspec);
              $type->add_constraints($constraints);
            }
          }
        }

F<convert_param_specs> turns the parameter specifications into
constraints.  We'll see this function later, after we've discussed the
way in which expressions are turned into constraints.


        sub add_constraint_declaration {
          my ($type, $declaration) = @_;
          my $constraint_expressions = $declaration->{CONSTRAINTS};
          my @constraints 
            = map expression_to_constraints($type, $_), 
                  @$constraint_expressions;
          $type->add_constraints(@constraints);
        }

This function is invoked to install a C<constraints> block into a type
object.  The contents of the C<constraints> block have been turned
into C<Expression> objects, but these objects are still essentially
abstract syntax trees, and haven't yet been turned into constraints.
The function F<expression_to_constraints> performs that conversion.
F<add_constraints> then inserts the new constraints into the type
object's constraint list.  We'll see F<expression_to_constraints>
later, along with the other functions that deal with expressions.

The third sort of declaration is a C<draw> section, whose contents are
drawables.    These are installed into a type object by
F<add_draw_declaration>:

        sub add_draw_declaration {
          my ($type, $declaration) = @_;
          my $drawables = $declaration->{DRAWABLES};

          for my $d (@$drawables) {
            my $drawable_type = $d->{WHAT};
            if ($drawable_type eq "NAMED_DRAWABLE") {
              unless ($type->has_subfeature($d->{NAME})) {
                lino_error("Unknown drawable feature '$d->{NAME}'");
              }
              $type->add_drawable($d->{NAME});
            } elsif ($drawable_type eq "FUNCTIONAL_DRAWABLE") {
              $type->add_drawable($d->{REF});
            } else {
              lino_error("Unknown drawable type '$type'");
            }
          }
        } 

There are two branches here, for the two kinds of drawables.  One is a
functional drawable, typified by C<&draw_line>; here we insert a
reference to the Perl C<draw_line> function into the drawables list.
The other kind of drawable is a named drawable, which is the name of a
subfeature; here we insert the name into the drawables list.  The only
real difference in handling is that we make sure that the name of a
named drawable is already known.

=subsubsection Expressions

The expression parser is similar to the ones we saw in
R<parser|chapter>.  Its output is essentially an X<abstract syntax
tree>, blessed into the C<Expression> class.  Expressions appear in
constraints and and on the right-hand sides of parameter
specifications.  The grammar is:

        $expression = operator($Term,
                               [_('OP', '+'), sub { Expression->new('+', @_) } ],
                               [_('OP', '-'), sub { Expression->new('-', @_) } ],
                              );

        $term = operator($Atom, 
                               [_('OP', '*'), sub { Expression->new('*', @_) } ],
                               [_('OP', '/'), sub { Expression->new('/', @_) } ],
                        );


which is nothing new.  Expressions, as mentioned before, are nothing
more than abstract syntax trees.  F<Expression::new> is trivial.  

        package Expression;

        sub new {
          my ($base, $op, @args) = @_;
          my $class = ref $base || $base;
          unless (exists $eval_op{$op}) {
            die "Unknown operator '$op' in expression '$op @args'\n";
          }
          bless [ $op, @args ] => $class;
        }

The C<$atom> parser accepts the usual numbers and parenthesized
compound expressions.  But there are a few additional atoms of
interest:

        package main;

        $atom = $Name
              | $Tuple
              | lookfor("NUMBER", sub { Expression->new('CON', $_[0][1]) })
              | _('OP', '-') - $Expression
                  >> sub { Expression->new('-', Expression->new('CON', 0), $_[1]) }
              | _("LPAREN") - $Expression - _("RPAREN") >> sub {$_[1]};


The C<_('OP', '-')> production handles unary minus expressions such as
C<-A>; this is compiled as if it had been written C<0-A>.

C<$name> is a variable name, possibly a compound variable name
containing dots; it is turned into an expression object containing
C<['VAR', $varname]>:

        $name = $Base_name 
              - star(_("DOT") - _("IDENTIFIER") >> sub { $_[1] })
              > sub { Expression->new('VAR', join(".", $_[0], @{$_[1]})) }
              ;

        $base_name = _"IDENTIFIER";

=endlisting linogram.pl

Similarly, a number is turned into an expression object containing
C<['CON', $number]>.  (C<CON> is an abbreviation for "constant".)

C<$tuple> is  a tuple expression, which we saw before in connection
with the constraint

        plus = F + (hspc, 0);

The C<(hspc, 0)> is a tuple expression.  Syntactically, a tuple is a
parenthesized, comma-separated list of expressions.  But its parser
has some interesting features:

=contlisting linogram.pl

        $tuple = _("LPAREN")
               - commalist($Expression) / sub { @{$_[0]} > 1 }
               - _("RPAREN")

The side condition C<sub { @{$_[0]} \> 1 }> requires that the
comma-separated list have more than one value in it.  This prevents
something like C<(3)> from ever being parsed as a 1-tuple.

The value of the tuple expression is generated as follows:

          >> sub {
            my ($explist) = $_[1];
            my $N = @$explist;
            my @axis = qw(x y z);
            if ($N == 2 || $N == 3) {
              return [ 'TUPLE',
                       { map { $axis[$_] => $explist->[$_] } (0 .. $N-1) }
                     ];
            } else {
              lino_error("$N-tuples are not supported\n");
            }
          } ;

=endlisting linogram.pl

This does two things.  First, it checks to make sure that the tuple
has exactly 2 or 3 elements.  For two-dimensional diagrams, only
2-tuples make sense.  

3-tuples are supported because C<linogram> might as easily be used for
three-dimensional diagrams.  One would have to write another standard
library, including definitions like

        define point { number x, y, z; }

and with replacement drawing functions that understood about
perspective.  But once this was done, C<linogram> would handle
three-dimensional diagrams as well as it handles two-dimensional ones.
Many of the standard library definitions would remain exactly the
same.  For example, the definition of C<line> would not need to
change; a line is determined by its two endpoints, regardless of
whether those endpoints are considered to be points in two or three
dimensions.  V<n>-tuples for V<n> larger than three are forbidden
until someone thinks of a use for them.

The value returned from the tuple parser for a tuple such as C<(5,
12)> is

        [ 'TUPLE',
          { x => 5,
            y => 12,
          }
        ]

For 3-tuples, there is an additional C<z> member of the hash.  The
special treatment of the names C<x>, C<y>, and C<z> comes ultimately
from here.

The result of parsing an expression, as mentioned before, is an
X<abstract syntax tree>.   For the expression C<x + 2 * y>, the tree
is

        [ '+', ['VAR', 'x'],
               ['*', ['CON', 2],
                     ['VAR', 'y'],
               ],
        ]

which should be familiar.

When constraint and parameter declarations are processed, they contain
these raw C<Expression> objects.  Later, expressions need to be
converted to constraints.  This is probably the most complicated part
of the program.  The process of conversion is essentially evaluation,
except that instead of producing a number result, the result is an
object from class C<Value>.  This
evaluation is performed by the function F<expression_to_constraints>.

=contlisting linogram.pl

        sub expression_to_constraints {
          my ($context, $expr) = @_;

=endlisting linogram.pl

Variables in an expression have associated types, and to map from a
variable's name to its type we need a context.  To see why, consider
the following example:

        define type_A {
          number age;
          age = 4;
        }

        define type_B {
          box age;
          age = 4;
        }

The constraint C<age = 4> in the first definition makes sense, but the
same constraint in the second definition does not make sense because 4
is not a box.  More generally, the meaning of a constraint might
depend in a complex way on the types of the variables it contains.  So
C<expression_to_constraints> requires a context which maps variable
names to their types.  This is nothing more than a C<Type>
object; the mapping is performed by F<Type::subfeature>.

Continuing with the evaluation function:

=contlisting linogram.pl

          unless (defined $expr) {
            Carp::croak("Missing expression in 'expression_to_constraints'");
          }
          my ($op, @s) = @$expr;

Here we break up the top-level expression into an operator C<$op> and
zero or more subexpressions, C<@s>.  We then switch on the operator
type.  It might be a variable, a constant, a tuple, or some binary
operator such as C<+> or C<*>.

          if ($op eq 'VAR') {
            my $name = $s[0];
            return Value::Feature->new_from_var($name, $context->subfeature($name));

If it's a variable, we build a new C<Value::Feature> object of the
indicated name and type.  F<new_from_var>, which we saw earlier, is
responsible for manufacturing the appropriate
set of constraints.

          } elsif ($op eq 'CON') {
            return Value::Constant->new($s[0]);

If the expression is a constant, the code is simple; we build a
C<Value::Constant> object.

Tuples are where things start to get interesting.  As we saw earlier,
tuples are I<not> required to be constants; C<(hspc + 3, 2 *
top.start.y)> is a perfectly legitimate tuple.  Since the components
of a tuple may be arbitrary expressions, we call
F<expression_to_constraints> recursively:

          } elsif ($op eq 'TUPLE') {
            my %components;
            for my $k (keys %{$s[0]}) {
              $components{$k} = expression_to_constraints($context, $s[0]{$k});
            }
            return Value::Tuple->new(%components);
          }

There should probably be a check here to make sure that the resulting
component values are not themselves tuples.  At present, C<((1, 2),
(3, 4))>, which is illegal, is not diagnosed until later, when the
malformed tuple participates in an arithmetic operation.

If the argument expression was neither a tuple, a variable, or a
constant, then it's a compound expression.  We start by evaluating the
two operands:

          my $e1 = expression_to_constraints($context, $s[0]);
          my $e2 = expression_to_constraints($context, $s[1]);

We then dispatch an appropriate method to combine the two operands
into a single expression.  When the operator is C<+>, we use the
C<add> method, and so on:

          my %opmeth = ('+' => 'add',
                        '-' => 'sub',
                        '*' => 'mul',
                        '/' => 'div',
                       );

          my $meth = $opmeth{$op};
          if (defined $meth) {
            return $e1->$meth($e2);
          } else {
            lino_error("Unknown operator '$op' in AST");
          }
        }

=endlisting linogram.pl


This is what connects the parser with the arithmetic functions from
class C<Value>.  

The one important function we haven't seen is F<convert_param_specs>,
which takes the parameter specifications in a declaration like C<hline
L(end=Q+R)> and converts them to constraints.  The arguments are a
context, the subfeature type (C<hline> in the example) and a parameter
specification value, something like

        { WHAT => 'PARAM_SPEC',
          NAME => 'end',
          VALUE => [ '+', ['VAR', 'Q'],
                          ['VAR', 'R'],
                   ],
        }

The only fine point here is that parameter specifications are
asymmetric.  The name C<end> on the left side is interpreted as a
subfeature of C<L>, but the named C<Q> and C<R> on the right side are
interpreted as subfeatures of the outer context in which C<L> is being
defined.  F<convert_param_specs> builds a new C<Value::Feature> object
for the left side by making two calls to F<subfeature>, one to find
the type of the feature that's being defined, C<L> in the example, and
then one more to find the type of the parameter name, C<end> in the
example.  It uses the F<expression_to_constraints> function to convert
the right-hand side, and then subtracts right from left to produce the
final constraint.

=contlisting linogram.pl

        sub convert_param_specs {
          my ($context, $subobj, $pspec) = @_;
          my @constraints;
          my $left = Value::Feature->new_from_var("$subobj." . $pspec->{NAME}, 
                                                  $context->subfeature($subobj)
                                                  ->subfeature($pspec->{NAME})
                                                 );
          my $right = expression_to_constraints($context, $pspec->{VALUE});
          return $left->sub($right);
        }

=endlisting linogram.pl

=subsection Missing Features

C<linogram> is missing a few valuable features.  Some are easier to
fix than others.  It doesn't support varying thickness lines, colored
lines, or filled boxes.  These are easy to add, and in fact an earlier
version of C<linogram> supports them; I took the feature out for
pedagogical reasons.  The technical support for the feature was to
allow "X<parameter>" declarations, like this:

        define line {
          point x, y;
*         param number thickness = 1;
*         param string color = "black";
          draw { &draw_line; }
        }

A parameter is just another subfeature, except that it doesn't
participate in the system of linear equations.  Like any other
subfeature, it may be constrained by the root feature or some other
feature that includes it.  The following root feature definition
draws a vertical black line crossed by a horizontal red line:

        vline v;
        hline h(color="red");
        constraints { v.center = h.center; }

The C<color="red"> parameter specification overrides the default of
C<"black">.  The parameter values are then included in the environment
hash that is passed to the drawing functions.  When C<draw_line> sees
that the color is specified as C<"red"> it is responsible for drawing
a red line instead of a black one.

With the parameter feature, we can support the placement of objects
that contain text:

        define text extends box {
          param string text = "";
          param number font_size = 9;
          param string font = "courier";
          draw { &draw_text }
        }

and now we have something that has a top, bottom, left, northwest
corner, and so forth, like a box, but whose four sides are invisible.
Instead, the C<draw_text> function is responsible for placing the text
appropriately, or for issuing an error message if it doesn't fit.

The value of a parameter must be completely determined before the
constraint system is solved, either by a declaration like C<hline
h(color="red")>, or by a specified default.  If neither is present, it
is a fatal error.

Parameters can be used for other applications:

        define marked_line extends vline {
          hline mark;
          param number markpos = 50;
          constraints {
            mark.length =  0.02;
            mark.center = (center.x, start.y + markpos/100 * height);
          }
        }

This defines a feature that is a vertical line with a horizontal tick
mark across it.  By default, the tick mark is halfway up the line, but
this depends on the value of V<markpos>, which can be between 0 and
100 to indicate a percentage of the way to the end of the C<vline>.
If V<markpos> is 100, the tick mark is at the end of the C<vline>; if
V<markpos> is 75, the tick mark is one-quarter of the way from the
end.

If V<markpos> were not a C<param>, the definition would be illegal,
because the expression C<markpos/100 * height> is nonlinear.  But
parameters do not participate in linear equation solving.  The rules
for parameters say that V<markpos> must be specified somewhere before
the equation solving begins.  Suppose it has been specified to be 75.
Then the constraint is effectively

            mark.center = (center.x, start.y + 75/100 * height);

which I<is> linear.  This feature lends a great deal of flexibility to
the system. 

One major feature that is missing is splines.  A spline is a curved
line whose path is determined by one or more X<control points>.  The
spline wiggles along, starting at its first control point and heading
towards the second, then veering off toward the third, and so on,
until it ends at the last control point.  The main impediment here is
that unlike the other features we've seen, the number of control
points of a spline isn't known in advance.  We could conceivably get
around this by defining a series of spline types:

        define spline2 {
          point p1, p2;
          draw { &draw_spline; }
        }

        define spline3 extends spline2 {
          point p3;
        }

        define spline4 extends spline3 {
          point p4;
        }

        ...

but this is awfully clumsy.  What C<linogram> really needs to support
features like splines and polygons is a way to specify a
parametrizable array of features and their associated constraints,
perhaps something like this:

        define polygon(N) {
          point v[N];
          line s[N];
          constraints {
            when j is 1 .. N   { s[j].start = v[j]; }
            when j is 1 .. N-1 { s[j].end   = v[j+1]; }
            s[N].end = v[1];
          }
        }

There are a few missing syntactic features.   A declaration like

        number hsize = 12;

would be convenient, as would equations with multiple equals signs:

        A.sw = B.n = C.s;

=section Conclusion

C<linogram> is a substantial application, one that might even be
useful.  I have been using the venerable C<pic>X<pic|iC> system,
developed at Bell Labs, for years, and it convinced me that defining
diagrams by writing a text file of constraints is a good general
strategy.  But I've never been entirely happy with C<pic>, and I
wanted to see what else I could come up with.

I also wanted to finish the book with a serious example which would
demonstrate how the techniques we've studied could be integrated into
real Perl programs.  C<linogram> totals about 1,300 lines of code,
counting the parsing system we developed in R<parsing|chapter>, but
not counting comments, white space, curly braces, or the like.  It
would have been very difficult to build without the techniques of
earlier chapters.  The parsing system itself was essential; the clean
design of the parsing system depends heavily on the earlier work on
lazy streams and iterators.  We used recursion and dispatch tables
throughout to reduce and reorganize the code.  Although the program
doesn't use any explicit currying or memoization, there are several
places where the code would probably be improved by its
introduction---the functions based on F<apply>, and the F<subfeature>
function spring to mind.

=Stop

Instead of a picture layout language like pic or ideal, how about an
HTML rendering engine?




 LocalWords:  definedness linogram
