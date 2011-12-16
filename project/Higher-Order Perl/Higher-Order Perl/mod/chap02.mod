=note I added chomp to all the read_config functions.

=chapter Dispatch Tables

In the previous chapter, we were able to make functions more flexible
by parametrizing their behaviors in terms of other functions.  For
example, instead of hardwiring the F<hanoi> function to print a
certain message every time it wanted to move a disk, we had it call a
secondary function that was passed in from outside.  By supplying an
appropriate secondary function, we could make F<hanoi> print out a
list of instructions, or check its own moves, or generate a graphic
display, without recoding the basic algorithm.  Similarly, we were
able to abstract the directory-walking behavior away from the
file-size-computing behavior of our F<total_size> function to get a
more useful and generally applicable F<dir_walk> function that could
be used to do all sorts of different things.

To abstract behavior out of F<hanoi> and F<dir_walk>, we made use of
X<code references>.  We passed F<hanoi> and F<dir_walk> additional
functions as arguments, effectively treating the secondary functions
as pieces of data.  Code references make this possible.

Now we'll leave recursion for a while and go off in a different
direction which shows another use of code references.

=section Configuration File Handling

Let's suppose that we have an application that reads in a
configuration file in the following format:

        VERBOSITY       8
        CHDIR           /usr/local/app
        LOGFILE         log
        ...             ...

We would like to read in this configuration file and take an
appropriate action for each directive.  For example, for the
C<VERBOSITY> directive, we just want to set a global variable.  But
for the C<LOGFILE> directive, we want to immediately redirect our
diagnostic messages to the specified file.  For C<CHDIR> we might like
to C<chdir> to the specified directory so that subsequent file
operations are relative to the new directory.  This means that in the
example above the C<LOGFILE> is C</usr/local/app/log>, and not the
C<log> file in whatever directory the user happened to be at the time
the program was run.

Many programmers would see this problem and immediately envision a
function with a giant C<if-else> switch in it, perhaps something like
this:

        sub read_config {
          my ($filename) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            chomp;
            my ($directive, $rest) = split /\s+/, $_, 2;
            if ($directive eq 'CHDIR') {
              chdir($rest) or die "Couldn't chdir to `$rest': $!; aborting";
            } elsif ($directive eq 'LOGFILE') {
              open STDERR, ">> $rest"
                or die "Couldn't open log file `$rest': $!; aborting";
            } elsif ($directive eq 'VERBOSITY') {
              $VERBOSITY = $rest;
            } elsif ($directive eq ...) {
              ...
            } ...
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }

This function is in two parts.  The first part opens the file and
reads lines from it one at a time.  It separates each line into a
C<$directive> part (the first word) and a C<$rest> part (the rest).
The C<$rest> part contains the arguments to the directive, such as the
name of the log file to open when supplied with the C<LOGFILE>
directive.  The second part of the function is a big C<if-else> tree
that checks the C<$directive> variable to see which directive it is,
and aborts the program if the directive is unrecognized.
         
This sort of function can get very large, because of the large number
of alternatives in the C<if-else> tree.  Every time someone wants to
add another directive, they change the function by adding another
C<elsif> clause.  The contents of the branches of the C<if-else> tree
don't have much to do with each other, except for the inessential fact
that they're all configurable.  Such a function violates an important
law of programming: related things should be kept together; unrelated
things should be separated.

Following this law suggests a different structure for this function:
The part that reads and parses the file should be separate from the
actions that are performed when the configuration directives are
recognized.  Moreover, the code for implementing the various unrelated
directives should not all be lumped together into a single function.

=subsection Table-driven configuration

=note Is 'flexibility' the word you want here?

We can do better by separating the code for opening, reading, and
parsing the configuration file from the unrelated segments that
implement the various directives.  Dividing the program into two
halves like this will give us better flexibility to modify each of the
halves, and to separate the code for the directives.

Here's a replacement for F<read_config>:

=listing read_config_tabular

        sub read_config {
          my ($filename, $actions) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            chomp;
            my ($directive, $rest) = split /\s+/, $_, 2;
            if (exists $actions->{$directive}) {
              $actions->{$directive}->($rest);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }
                
=endlisting read_config_tabular

We open, read, and parse the configuration file exactly as before.
But we dispense with the giant C<if-else> switch.  Instead, this
version of C<read_config> receives an extra argument, C<$actions>,
which is a table of actions; each time F<read_config> reads a
configuration directive, it will perform one of these actions.  This
table is called a X<dispatch table|d>, because it contains the
functions to which F<read_config> will dispatch control as it reads
the file.  The C<$rest> variable has the same meaning as before, but
now it is passed to the appropriate action as an argument.

A typical dispatch table might look like this:
        
        $dispatch_table = 
          { CHDIR      => \&change_dir,
            LOGFILE    => \&open_log_file,
            VERBOSITY  => \&set_verbosity,
            ... =>  ...,
          };

The dispatch table is a hash, whose keys (generically called
X<tags|d>) are directive names, and whose values are X<actions|d>,
references to subroutines that are invoked when the appropriate
directive name is recognized.  Action functions expect to receive the
C<$rest> variable as an argument; typical actions look like these:
        
        sub change_dir { 
          my ($dir) = @_;
          chdir($dir)
            or die "Couldn't chdir to `$dir: $!; aborting"; 
        }
        
        sub open_log_file { 
          open STDERR, ">>",  $_[0]
            or die "Couldn't open log file `$_[0]': $!; aborting"; 
        }

        sub set_verbosity {
          $VERBOSITY = shift 
        }

If the actions are small, we can put them directly into the dispatch
table:

        $dispatch_table = 
          { CHDIR      => sub { my ($dir) = @_;
                               chdir($dir) or     
                                 die "Couldn't chdir to `$dir: $!; aborting"; 
                              },

            LOGFILE   => sub { open STDERR, ">> $_[0]" or 
                                 die "Couldn't open log file `$_[0]': $!; aborting"; 
                             },

            VERBOSITY => sub { $VERBOSITY = shift },
            ... =>  ...,
          };


By switching to a dispatch table, we've eliminated the huge C<if-else>
tree, but in return we've gotten a table that is only a little
smaller.  That might not seem like a big win.  But the table provides
several benefits.

=test read_config

    do 'read_config_tabular';
    use File::Temp qw(tempfile);
    my ($fh, $filename) = tempfile();
    print $fh "ONE dog\nTWO 3\nONE cat\nTWO 1\n";
    close($fh);
    my $x = 0;
    my $y = "";
    my $dispatch_table = 
       { ONE => \&one,
         TWO => sub { $x+=$_[0] },
       };
    sub one { $y .= $_[0]; chomp $y }
    read_config($filename,$dispatch_table);
    is($x,4);
    is($y,"dogcat");

=endtest read_config

=subsection Advantages of Dispatch Tables

The dispatch table is data, instead of code, so it can be modified at
run-time.  For example, you can insert new directives into the table
whenever you want to.  Suppose the table has:

        'DEFINE' => \&define_config_directive,

where F<define_config_directive> is:

=startlisting define_config_directive

        sub define_config_directive {
          my $rest = shift;
          $rest =~ s/^\s+//;
          my ($new_directive, $def_txt) = split /\s+/, $rest, 2;

          if (exists $CONFIG_DIRECTIVE_TABLE{$new_directive}) {
            warn "$new_directive already defined; skipping.\n";
            return;
          }

          my $def = eval "sub { $def_txt }";
          if (not defined $def) {
            warn "Could not compile definition for `$new_directive': $@; skipping.\n";
            return;       
          }

          $CONFIG_DIRECTIVE_TABLE{$new_directive} = $def;
        }
        
=endlisting define_config_directive

=note Not testing this version.  Testing define_config_directive_tablearg below instead

The configurator now accepts directives like this:

        DEFINE HOME       chdir('/usr/local/app');

F<define_config_directive> puts C<HOME> into C<$new_directive> and
C<chdir('/usr/local/app');> into C<$def_txt>.  It uses X<eval|C> to
compile the definition text into a subroutine, and installs the new
subroutine into a master configuration table,
C<%CONFIG_DIRECTIVE_TABLE>, using C<HOME> as the key.  If
C<%CONFIG_DIRECTIVE_TABLE> was in fact the dispatch table that was
passed to F<read_config> in the first place, then F<read_config> will
see the new definition, and will have an action associated with
C<HOME> if it sees the C<HOME> directive on a later line of the input
file.  Now a config file can say

        DEFINE HOME       chdir('/usr/local/app');
        CHDIR /some/directory
        ...
        HOME

The directives in C<...> are invoked in the directory
C</some/directory>, and when the processor reaches C<HOME>, it returns
to its home directory.  We can also define a more robust version of
the same thing:

        DEFINE PUSHDIR   use Cwd; push @dirs, cwd(); chdir($_[0])
        DEFINE POPDIR    chdir(pop @dirs)

C<PUSHDIR> V<dir> uses the F<cwd> function provided by the standard
C<Cwd> module to figure out the name of the current directory. It saves
the name of the current directory in the variable C<@dirs>, and then
changes to V<dir>.  C<POPDIR> undoes the effect of the last
C<PUSHDIR>.

        PUSHDIR /tmp
        A
        PUSHDIR /usr/local/app
        B
        POPDIR
        C
        POPDIR

The program changes to C</tmp>, then executes directive A.
Then it changes to C</usr/local/app> and executes directive B.
The following C<POPDIR> returns the program to C</tmp>, where it
executes directive C; finally the second C<POPDIR> returns it to
wherever it started out.

In order for C<DEFINE> to modify the configuration table, we had to
store it in a global variable.  It's probably better if we pass the
table to C<define_config_directive> explicitly.  To do that we need to
make a small change to C<read_config>:

=listing read_config_tablearg

        sub read_config {
          my ($filename, $actions) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            chomp;
            my ($directive, $rest) = split /\s+/, $_, 2;
            if (exists $actions->{$directive}) {
*              $actions->{$directive}->($rest, $actions);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }
                
=endlisting read_config_tablearg

Now C<define_config_directive> can look like this:

=startlisting define_config_directive_tablearg

        sub define_config_directive {
*         my ($rest, $dispatch_table) = @_;
          $rest =~ s/^\s+//;
          my ($new_directive, $def_txt) = split /\s+/, $rest, 2;

*         if (exists $dispatch_table->{$new_directive}) {
            warn "$new_directive already defined; skipping.\n";
            return;
          }

          my $def = eval "sub { $def_txt }";
          if (not defined $def) {
            warn "Could not compile definition for `$new_directive': $@; skipping.\n";
            return;       
          }

*         $dispatch_table->{$new_directive} = $def;
        }
        
=endlisting define_config_directive_tablearg

With this change, we can add a really useful configuration directive:

        DEFINE INCLUDE   read_config(@_);

This installs a new entry into the dispatch table that looks like this:

        INCLUDE => sub { read_config(@_) }

Now, when we write this in the configuration file:

        INCLUDE extra.conf

the main F<read_config> will invoke the action, passing it two
arguments.  The first argument will be the C<$rest> from the
configuration file; in this case the filename C<extra.conf>.  The
second argument to the action will be the dispatch table again.  These
two arguments will be passed directly to a recursive call of
C<read_config>.  C<read_config> will read C<extra.conf>, and when it's
finished it will return control to the main invocation of
C<read_config> which will continue with the main configuration file,
picking up where it left off.

In order for the recursive call to work properly, F<read_config> must
be X<reentrant>.  The easiest way to break reentrancy is to use a
global variable, for example by using a global filehandle instead of
the X<lexical filehandle> we did use.  If we had used a global
filehandle, the recursive call to F<read_config> would open
C<extra.conf> with the same filehandle that was being used by the main
invocation; this would close the main configuration file.  When the
recursive call returned, F<read_config> would be unable to read the
rest of the main file, because its filehandle would have been closed.

The C<INCLUDE> definition was very simple and very useful.  But it was
also ingenious, and it might not have occurred to us when we were
writing C<read_config>.  It would have been easy to say `Oh,
C<read_config> doesn't need to be reentrant.'  But if we had written
C<read_config> in a nonreentrant way, the useful and ingenious
C<INCLUDE> definition wouldn't have worked.  There's an important
lesson to learn here: make functions reentrant by default, because
sometimes the usefulness of being able to call a function recursively
will be a surprise.

=test read_config_again


    do 'read_config_tablearg';
    do 'define_config_directive_tablearg';
    my @known = qw(/tmp /usr /var /usr /home);
    use File::Temp qw(tempfile);
    my ($fh0, $temp0) = tempfile();

    my $file0=<<"    EOF";
    DEFINE PUSHDIR   use Cwd; push \@dirs, cwd(); chdir(\$_[0])
    DEFINE POPDIR    chdir(pop \@dirs)
    EOF

    $file0 =~ s/^\s+//mg;
    print $fh0 $file0;
    close($fh0);
    
    my ($fh1, $temp1) = tempfile();
    my $file1=<<"    EOF";
    DEFINE HOME chdir('/home')
    INCLUDE $temp0
    CHDIR /tmp
    CHECK
    PUSHDIR /usr
    CHECK
    PUSHDIR /var
    CHECK
    POPDIR
    CHECK
    HOME
    CHECK
    EOF

    $file1 =~ s/^\s+//mg;
    print $fh1 $file1;
    close($fh1);

    my $x = 0;
    my $y = "";
    my $dispatch_table = 
       { 
         INCLUDE => sub { read_config(@_) },
         DEFINE  => \&define_config_directive,
         CHDIR      => sub { my ($dir) = @_;
                             chdir($dir) or     
                              die "Couldn't chdir to `$dir: $!; aborting"; 
                           },
         CHECK => \&check,
       };
    read_config($temp1,$dispatch_table);
    use Cwd;
    sub check {
        is( shift(@known), Cwd::getcwd );
    }

=endtest read_config_again

X<reentrant functions|why|(>
Reentrant functions exhibit a simpler and more predictable behavior
than nonreentrant functions.  They are more flexible, because they 
can be called recursively.  Our C<INCLUDE> example above shows that we
might not always anticipate all the reasons why someone might want to
invoke a function recursively.  It's better and safer to make
everything reentrant if we can.
X<reentrant functions|why|)>

Another advantage of the dispatch table over hard-wired code in
F<read_config> is that we can use the same C<read_config> function to
process two unrelated files that have totally different directives,
just by passing a different dispatch table to F<read_config> each
time.  We can put the program into `beginner mode' by passing a
stripped-down dispatch table to F<read_config>.  Or we can reuse
F<read_config> to process a different file with the same basic syntax
by passing it a table with a different set of directives.

=subsection Dispatch Table Strategies

R<user parameter|HERE>
In our implementation of C<PUSHDIR> and C<POPDIR>, the action
functions used a global variable, C<@dirs>, to maintain the stack of
pushed directories.  This is unfortunate.  We can get around this, and
make the system more flexible, by having F<read_config> support a
X<user parameter|d>.  This is an argument, supplied by the caller of
F<read_config>, which is passed verbatim to the actions:

=listing read_config_userparam

        sub read_config {
*         my ($filename, $actions, $user_param) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            my ($directive, $rest) = split /\s+/, $_, 2;
            if (exists $actions->{$directive}) {
*               $actions->{$directive}->($rest, $userparam, $actions);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }
                
=endlisting read_config_userparam

=note not testing read_config_userparam.  combining with read_config_default

This eliminates the global variable, because we can now define
C<PUSHDIR> and C<POPDIR> like this:

        DEFINE PUSHDIR   use Cwd; push @{$_[1]}, cwd(); chdir($_[0])
        DEFINE POPDIR    chdir(pop @{$_[1])

The C<$_[1]> parameter refers to the user parameter argument that is
passed to F<read_config>.  If F<read_config> is called with

        read_config($filename, $dispatch_table, \@dirs);

then C<PUSHDIR> and C<POPDIR> will use the array  C<@dirs> as their
stack; if it is called with

        read_config($filename, $dispatch_table, []);

then they will use a fresh, anonymous array as the stack.

It's often useful to pass an action callback the name of the tag on
whose behalf it was invoked.  To do this, we change F<read_config>
like this:

=listing read_config_tagarg

        sub read_config {
          my ($filename, $actions, $userparam) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            my ($directive, $rest) = split /\s+/, $_, 2;
            if (exists $actions->{$directive}) {
*             $actions->{$directive}->($directive, $rest, $actions, $userparam);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }
                
=endlisting read_config_tagarg

=note not testing read_config_tagarg.  combining with read_config_default

Why is this useful?  Consider the action we defined for the
C<VERBOSITY> directive:

        VERBOSITY => sub { $VERBOSITY = shift },

It's easy to imagine that there might be several configuration
directives that all follow this general pattern:

        VERBOSITY => sub { $VERBOSITY = shift },
        TABLESIZE => sub { $TABLESIZE = shift },
        PERLPATH  => sub { $PERLPATH  = shift },
        ... etc ...

We would like to merge the three similar actions into a single
function that does the work of all three.  To do that, the function
needs to know the name of the directive so that it can set the
appropriate global variable:

        VERBOSITY => \&set_var,
        TABLESIZE => \&set_var,
        PERLPATH  => \&set_var,
        ... etc ...

        sub set_var {
          my ($var, $val) = @_;
          $$var = $val;
        }

Or, if you don't like a bunch of global variables running around
loose, you can store configuration information in a hash, and pass a
reference to the hash as the user parameter:

        sub set_var {
          my ($var, $val, undef, $config_hash) = @_;
          $config_hash->{$var} = $val;
        }

For this example, not much is saved, because the action is so simple.
But there might be several configuration directives that need to share
a more complicated function.  Here's a slightly more complicated
example:

        sub open_input_file {
          my ($handle, $filename) = @_;
          unless (open $handle, $filename) {    
            warn "Couldn't open $handle file `$filename': $!; ignoring.\n";
          }
        }

This F<open_input_file> function can be shared by many configuration
directives.  For example, suppose a program has three sources of
input:  a history file, a template file, and a pattern file.  We would
like the locations of all three files to be configurable in the
configuration file; this requires three entries in the dispatch table.
But the three entries can all share the same F<open_input_file> function:

        ...
        HISTORY  => \&open_input_file,
        TEMPLATE => \&open_input_file,
        PATTERN  => \&open_input_file,
        ...

Now suppose the configuration file says:

        HISTORY           /usr/local/app/history
        TEMPLATE          /usr/local/app/templates/main.tmpl
        PATTERN           /home/bill/app/patterns/default.pat

F<read_config> will see the first line and dispatch to the
F<open_input_file> function, passing it the argument list
C<('HISTORY', '/usr/local/app/history')>.  F<open_input_file> will
take the C<HISTORY> argument as a filehandle name, and open the
C<HISTORY> filehandle to come from the C</usr/local/app/history> file.
On the second line, F<read_config> will dispatch to the
F<open_input_file> again, this time passing it C<('TEMPLATE',
'/usr/local/app/templates/main.tmpl')>. This time,
F<open_input_file> will open the C<TEMPLATE> filehandle instead of
the C<HISTORY> filehandle.

=subsection Default Actions

Our example F<read_config> function dies when it encounters an
unrecognized directive.  This behavior is hardwired in.  It would be
better if the dispatch table itself carried around the information
about what to do for an unrecognized directive. It's easy to add this
feature:

=listing read_config_default

        sub read_config {
          my ($filename, $actions, $userparam) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
            chomp;
            my ($directive, $rest) = split /\s+/, $_, 2;
*           my $action = $actions->{$directive} || $actions->{_DEFAULT_};
*           if ($action) {
*             $action->($directive, $rest, $actions, $userparam);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }
                
=endlisting read_config_default

Here we look in the action table for the specified directive; if it
isn't there, we look for a C<_DEFAULT_> action, and die only if there
is no default specified in the dispatch table.  We saw an example of
this earlier, in connection with reading an address file as if it were
a configuration file.  Here's a more typical C<_DEFAULT_> action:

        sub no_such_directive {
          my ($directive) = @_;
          warn "Unrecognized directive $directive at line $.; ignoring.\n";
        }

Since the directive name is passed as the first argument to the action
function, the default action knows what unrecognized directive it was
called on behalf of.  Since the F<no_such_directive> function also
gets passed the entire dispatch table, it can extract the real
directive names and do some pattern-matching to figure out what was
meant.  Here F<no_such_directive> uses a hypothetical F<score_match>
function to decide which table entries are good matches for the
unrecognized directive.

        sub no_such_directive {
          my ($bad, $rest, $table) = @_;
          my ($best_match, $best_score) ;
          for my $good (keys %$table) {
            my $score = score_match($bad, $good);
            if ($score > $best_score) {
              $best_score = $score;
              $best_match = $good;
            }
          }
          print STDERR "Unrecognized directive $bad at line $.;\n";
          print STDERR "\t(perhaps you meant $best_match?)\n";
        }

The system we have now has only a little code, but it's extremely
flexible.  Suppose our program is also going to read a list of user
ids and email addresses in the following format:

        fred            fred@example.com
        bill            bvoehno@plover.com
        warez           warez-admin@plover.com
        ...             ...

We can re-use F<read_config> and have it read and parse this file,
simply by supplying the appropriate dispatch table:

        $address_actions = 
          { _DEFAULT_ => sub { my ($id, $addr, $act, $aref) = @_;
                               push @$aref, [$id, $addr];
                             },
          };

        read_config($ADDRESS_FILE, $address_actions, \@address_array);

Here we've given F<read_config> a very small dispatch table; all it
has is a C<_DEFAULT_> entry.  F<read_config> will call this default
entry once for each line in the address file, passing it the
`directive name' (which is actually the user id) and the address
(which is the C<$rest> value.)  The default action will take this
information and add it to C<@address_array>, which can be used by the
program later.

=test read_config_three

    # need to test default, userparam, and tag
    do 'read_config_default';

    use File::Temp qw(tempfile);
    my ($fh, $tempfile) = tempfile();

    my $data =<<"    EOF";
    fred            fred\@example.com
    bill            bvoehno\@plover.com
    warez           warez-admin\@plover.com
    EOF

    $data =~ s/^\s+//mg;
    print $fh $data;
    close($fh);

    my $address_actions = 
          { _DEFAULT_ => sub { my ($id, $addr, $act, $aref) = @_;
                               push @$aref, [$id, $addr];
                             },
          };

    my @address_array;
    read_config($tempfile, $address_actions, \@address_array);
    is_deeply(\@address_array,
               [[fred => 'fred@example.com'],
                [bill => 'bvoehno@plover.com'],
                [warez=> 'warez-admin@plover.com']]);

=endtest read_config_three

=section Calculator

Let's get away from the configuration file example for a while.
Obviously, dispatch tables are going to make sense in many similar
situations.  For example, a conversational program that must process
commands from a user can use a dispatch table to dispatch the user's
commands.  Here's a different example: it's a very simple calculator.

The input to this calculator is a string that contains an arithmetic
expression in X<reverse Polish notation|d>.  Conventional arithmetic
notation is ambiguous: if you write M<2+3*4> it's not immediately
clear whether we do the addition or the multiplication first.  We have
to have special conventions to say that multiplication always happens
before addition, or we have to disambiguate the expression by
inserting parentheses, as M<(2+3)*4> for example.

X<Reverse Polish notation>, or X<RPN|d>, solves the problem in a
different way.  Instead of putting the operator symbols in between the
arguments that they operate on,  RPN puts the operators after their
arguments.  For example, instead of M<2+3> we write C<2 3 +>.  Instead
of M<(2+3)*4>, we write C<2 3 + 4 *>.  The C<+> follows C<2> and C<3>,
so the 2 and 3 are added; the C<*> says to multiply the two preceding
expressions, which are C<2 3 +> and C<4>.  To express M<2+(3*4)> in
RPN, we would write C<2 3 4 * +>.  The C<+> applies to the two
preceding arguments; the first of these is C<2> and the second is C<3
4 *>.  Because the operator always follows its arguments, such
expressions are said to be in X<postfix form|d>; this is to contrast
them with the usual form, where the operators are in between their
arguments, which is called X<infix form|d>.

It's easy to compute the value of an expression in RPN.  To do this,
we maintain a stack, and read the expression from left to right.  When
we see a number, we push it on the stack.  When we see an operator, we
pop the top two elements off the stack, operate on them, and push the
result back on the stack.  For example, to evaluate C<2 3 + 4 *>, we
first push 2 and then 3, and then when we see the C<+> we pop them off
and push back the sum, 5.  Then we push 4 on top of the 5, and then
the C<*> tells us to pop the 4 and the 5 and push back the final
answer, 20.  To evaluate C<2 3 4 * +> we push 2, then 3, then 4.  The
C<*> tells us to pop back the 3 and the 4 and push the product 12;
the C<+> tells us to pop the 12 and the 2 and push the sum, 14, which
is the final answer.

Here's a small calculator program that evaluates the RPN expression
supplied in its command-line argument.  

=listing rpn_ifelse

        my $result = evaluate($ARGV[0]);
        print "Result: $result\n";

        sub evaluate {
          my @stack;
          my ($expr) = @_;
          my @tokens = split /\s+/, $expr;
          for my $token (@tokens) {
            if ($token =~ /^\d+$/) {   # It's a number
              push @stack, $token;
            } elsif ($token eq '+') {
               push @stack, pop(@stack) + pop(@stack);
            } elsif ($token eq '-') {
               my $s = pop(@stack);
               push @stack, pop(@stack) - $s
            } elsif ($token eq '*') {
               push @stack, pop(@stack) * pop(@stack);
            } elsif ($token eq '/') {
               my $s = pop(@stack);
               push @stack, pop(@stack) / $s
            } else {
              die "Unrecognized token `$token'; aborting";
            }
           }
          return pop(@stack);
        }


=endlisting rpn_ifelse

=test rpn_ifelse

    open(my $null,">/dev/null");
    select($null);  # hide output in listing
    do 'rpn_ifelse';
    select(STDOUT);
    is(evaluate("3 3 +"), 6, "3 3 +");
    is(evaluate("5 3 -"), 2, "5 3 -");
    is(evaluate("10 2 * 3 4 +"), 7, "returns last thing on the stack");

=endtest rpn_ifelse

The function splits the argument on whitespace into X<tokens|d>, which
are the smallest meaningful portions of the input.  Then the function
loops over the tokens one at a time, from left to right.  If a token
matches C</^\d+$/>, then it is a number, so the function pushes it
onto the stack.  Otherwise, it's an operator, so the function pops two
values off the stack, operates on them, and pushes the result back
onto the stack.  The auxiliary C<$s> variable in the code for
subtraction is there because C<5 3 -> should yield 2, not -2.  If we
had used

               push @stack, pop(@stack) - pop(@stack);

then for C<5 3 -> the first C<pop> would pop the 3, the second would
pop the 5, and the result would have been -2.  There is similar code
in the division branch for the same reason.   For multiplication and
addition, the order of the operands doesn't matter.

When the function runs out of tokens, it pops the top value off the
stack; this is the final result.  This code ignores the possibility
that the stack might finish with several values; this would mean that
the argument contained more than one expression.  C<10 2 * 3 4 +>
leaves 20 and 7 on the stack, in that order.  It also ignores the
possibility that the stack might become empty.  For example C<2 *> and
C<2 3 + *> are invalid expressions, because in each, the C<*> has only
one argument instead of two.  In evaluating these, the function finds
itself doing a X<pop()|i> operation when the stack is empty.  It
should signal an error in that case, but I omitted the error handling
to keep the example small.

We can make the example simpler and more flexible by replacing the
large C<if-else> switch with a dispatch table:
          
=listing rpn_table

        my @stack;
        my $actions = {
          '+' => sub { push @stack, pop(@stack) + pop(@stack) },
          '*' => sub { push @stack, pop(@stack) * pop(@stack) },
          '-' => sub { my $s = pop(@stack); push @stack, pop(@stack) - $s },
          '/' => sub { my $s = pop(@stack); push @stack, pop(@stack) / $s },
          'NUMBER' => sub { push @stack, $_[0] },
          '_DEFAULT_' => sub { die "Unrecognized token `$_[0]'; aborting" }
        };

        my $result = evaluate($ARGV[0], $actions);
        print "Result: $result\n";

        sub evaluate {
          my ($expr, $actions) = @_;
          my @tokens = split /\s+/, $expr;
          for my $token (@tokens) {
            my $type;
            if ($token =~ /^\d+$/) {   # It's a number
              $type = 'NUMBER'; 
            }
  
            my $action = $actions->{$type} 
                      || $actions->{$token} 
                      || $actions->{_DEFAULT_};
            $action->($token, $type, $actions);
          }
          return pop(@stack);
        }
  
=endlisting rpn_table

=test rpn_table

     # copied all the code for simpler scoping

        my @stack;
        my $actions = {
          '+' => sub { push @stack, pop(@stack) + pop(@stack) },
          '*' => sub { push @stack, pop(@stack) * pop(@stack) },
          '-' => sub { my $s = pop(@stack); push @stack, pop(@stack) - $s },
          '/' => sub { my $s = pop(@stack); push @stack, pop(@stack) / $s },
          'NUMBER' => sub { push @stack, $_[0] },
          '_DEFAULT_' => sub { die "Unrecognized token `$_[0]'; aborting" },
          'sqrt' => sub { push @stack, sqrt(pop(@stack)) },
        };

        sub evaluate {
          my ($expr, $actions) = @_;
          my @tokens = split /\s+/, $expr;
          for my $token (@tokens) {
            my $type;
            if ($token =~ /^\d+$/) {   # It's a number
              $type = 'NUMBER'; 
            }
  
            my $action = $actions->{$type} 
                      || $actions->{$token} 
                      || $actions->{_DEFAULT_};
            $action->($token, $type, $actions);
          }
          return pop(@stack);
        }

    is(evaluate("3 3 +",$actions), 6, "3 3 +");
    is(evaluate("5 3 -",$actions), 2, "5 3 -");
    is(evaluate("5 3 *",$actions), 15, "5 3 *");
    is(evaluate("8 2 /",$actions), 4, "8 2 /");
    is(evaluate("10 2 * 3 4 +", $actions), 7, "returns last thing on the stack");
    is(evaluate("4 sqrt",$actions), 2, "sqrt(4)");
    eval { evaluate("your momma",$actions) };
    ok( $@ =~ /^Unrecognized token/, "die properly" );


=endtest rpn_table

The main driver, F<evaluate>, is now much smaller and more general.
It selects an action based on the token's `type', if it has one;
otherwise, the action is based on the value of the token itself, and
if there is no such action, a default action is used.  The F<evaluate>
function does a pattern-match on the token to try to determine a token
type, and if the token looks like a number, the selected type is
C<NUMBER>.  We can add a new operator by adding an entry to the
C<%actions> dispatch table:

        ...
        'sqrt' => sub { push @stack, sqrt(pop(@stack)) },
        ...

Again, because of the dispatch table construction, we can get a
different behavior from the evaluator by supplying a different
dispatch table.  Instead of reducing the expression to a number, the
evaluator will compile it into an X<abstract syntax tree|d> if we supply this
dispatch table:

        my $actions = {
          'NUMBER'    => sub { push @stack,   $_[0] },
          '_DEFAULT_' => sub { my $s = pop(@stack);
                               push @stack, 
                                 [ $_[0], pop(@stack), $s ]
                             },
        };

The result of compiling C<2 3 + 4 *> is the abstract syntax tree
C<[ '*', [ '+', 2, 3 ], 4 ]>, which we can also represent like this:

=startpicture ast-simple

                *
               / \
              /   \
             +     4
            / \
           /   \
          2     3

=endpicture ast-simple

This is the most useful internal form for an expression because all
the structure is represented directly.  An expression is either a
number, or has an operator and two operands; the two operands are also
expressions.  An abstract syntax tree (X<AST|d>) is either a number,
or a list of an operator and two other ASTs.  Once we have an AST,
it's easy to write a function to process it.  For example, here is a
function to convert an AST to a string:

=listing AST_to_string

        sub AST_to_string {
          my ($tree) = @_;
          if (ref $tree) {
            my ($op, $a1, $a2) = @$tree;
            my ($s1, $s2) = (AST_to_string($a1),
                             AST_to_string($a2));
            "($s1 $op $s2)";
          } else {
            $tree;
          }
        }

=endlisting AST_to_string

Given the tree above, the F<AST_to_string> function produces the
string C<"((2 + 3) * 4)">.  It first checks to see if the tree is
trivial; if it is not a reference, then it must be a number, and the
string version is just that number.  Otherwise, the string has three
parts: an operator symbol, which is stored in C<$op>, and two
arguments, which are ASTs.  The function calls itself recursively to
convert the two argument trees to strings C<$s1> and C<$s2>, and then
produces a new string which has C<$s1> and C<$s2> with the appropriate
operator symbol in between, surrounded by parentheses to avoid
ambiguity.  We have just written a system to convert postfix
expressions to infix expressions, because we can feed the original
postfix expression to F<evaluate> to generate an AST, and then give
the AST to F<AST_to_string> to generate an infix expression.

The F<AST_to_string> function is recursive because the definition of
an AST is recursive; the definition of ASTs is recursive because the
structure of an expression is recursive.  The structure of
F<AST_to_string> directly reflects the structure of an expression.

=test ast_to_string


        my $actions = {
          'NUMBER'    => sub { push @stack,   $_[0] },
          '_DEFAULT_' => sub { my $s = pop(@stack);
                               push @stack, 
                                 [ $_[0], pop(@stack), $s ]
                             },
        };

    # evaluate copied from above
       sub evaluate {
          my ($expr, $actions) = @_;
          my @tokens = split /\s+/, $expr;
          for my $token (@tokens) {
            my $type;
            if ($token =~ /^\d+$/) {   # It's a number
              $type = 'NUMBER'; 
            }
  
            my $action = $actions->{$type} 
                      || $actions->{$token} 
                      || $actions->{_DEFAULT_};
            $action->($token, $type, $actions);
          }
          return pop(@stack);
        }

    do 'AST_to_string';

    my $ast = evaluate("2 3 + 4 *",$actions);
    my $asts = AST_to_string($ast);
    is($asts,"((2 + 3) * 4)");

    $ast = evaluate("2",$actions);
    $asts = AST_to_string($ast);
    is($asts,"2","trivial");

=endtest ast_to_string
     
=note add chapter or section reference for pretty-printing of expressions

=subsection HTML Processing Revisited

In the previous chapter we saw F<walk_html>, a recursive HTML
processor.  The HTML processor got two functional arguments:
C<$textfunc>, a function to call for a section of untagged text, and
C<$elementfunc>, a function to call for an HTML element.  But `HTML
element' is vague, because there are many sorts of elements, and we
might want our function to do something different for each kind of
element.

We've seen several ways to accomplish this already.  The most
straightforward is for the user to simply put a giant C<if-else>
switch into C<$elementfunc>.  As we've already seen, that has some
disadvantages.  The user might like to supply a dispatch table to the
C<$elementfunc> instead.  The structure of such a dispatch table is easy to
see: the keys of the table will be tag names, and the values will be
actions performed for each kind of element.  Instead of supplying a single
C<$elementfunc> that knows how to deal with every possible element, the user
will supply a dispatch table which provides one action for each kind
of element, and also a generic C<$elementfunc> that dispatches the appropriate
action.

The C<$elementfunc> might get access to the dispatch table in any of several
ways.  The dispatch table might be hard-wired into the element function:

        sub elementfunc {
          my $table = { h1        => sub { shift; my $text = join '',  @_;
                                           print $text; return $text ;
                                         }
                        _DEFAULT_ => sub { shift; my $text = join '',  @_;
                                                        return $text ;
                      };
          my ($element) = @_;
          my $tag = $element->{_tag};
          my $action = $table->{$tag} || $table{_DEFAULT_};
          return $action->(@_);
        }

Alternatively, we could build dispatch table support directly into
F<walk_html>, so that instead of passing a single C<$elementfunc>, the
user actually passes the dispatch table directly to F<walk_html>.  In
that case, F<walk_html> would look something like this:

=listing walk_html_dispatch

        sub walk_html {
*         my ($html, $textfunc, $elementfunc_table) = @_;
          return $textfunc->($html) unless ref $html;   # It's a plain string

          my ($item, @results);
          for $item (@{$html->{_content}}) {
            push @results, walk_html($item, $textfunc, $elementfunc_table);
          }
*         my $tag = $html->{_tag};
*         my $elementfunc =  $elementfunc_table->{$tag} 
*                      || $elementfunc_table->{_DEFAULT_}
*                      || die "No function defined for tag `$tag'";
          return $elementfunc->($html, @results);
        }

=endlisting walk_html_dispatch


=test walk_html_dispatch

    do 'walk_html_dispatch';
    require 'htmlsample.pl';
    my $TEXT;
        walk_html($TREE,
                 # $textfunc
                  sub { my ($text) = @_; 
                        $TEXT .= $text; },
                  { _DEFAULT_ => sub {} },
                );

    like($TEXT, qr/^\s*What Junior Said Next But I don't want to go to bed now!\s*$/, "untagged text");

=endtest walk_html_dispatch

Yet another option is to change F<walk_html> to pass a user parameter
to the C<$textfunc> and C<$elementfunc>.  Then the user could have the
dispatch table passed to the C<$elementfunc> via the user parameter
mechanism:

=listing walk_html_userparam

        sub walk_html {
*         my ($html, $textfunc, $elementfunc, $userparam) = @_;
*         return $textfunc->($html, $userparam) unless ref $html;

          my ($item, @results);
          for $item (@{$html->{_content}}) {
*           push @results, walk_html($item, $textfunc, $elementfunc, $userparam);
          }
*         return $elementfunc->($html, $userparam, @results);
        }

=endlisting walk_html_userparam

Now it is up to the users to design their C<$elementfunc>s to process the
dispatch table appropriately.

One important and subtle point here: notice that we passed the user
parameter to the C<$textfunc> as well as to the C<$elementfunc>.  If
the user parameter is a tag dispatch table, it is probably not useful
to the C<$textfunc>.  Why did we pass it, then?  because it might not
be a tag dispatch table; it might be something else.  For example, the
user might have called F<walk_html> like this:

        walk_html($html_text, 

                  # $textfunc
                  sub { my ($text, $aref) = @_; 
                        push @$aref, $text },

                  # $elementfunc  does nothing
                  sub { },

                  # user parameter
                  \@text_array
                 );

Now F<walk_html> will walk the HTML tree and push all the untagged
plain text into the array C<@text_array>.  The user parameter is the
reference to C<@text_array>; it is passed to the C<$textfunc>, which
pushes the text onto the referred-to array.  The C<$elementfunc> doesn't
use the user parameter at all.  Since we, the authors of
F<walk_html>, don't know in advance which sort of user parameter
the user will require, we had better pass it to both the C<$textfunc> and
the C<$elementfunc>; a function which doesn't need the user parameter is
free to ignore it.


=test walk_html_userparam

    do 'walk_html_userparam';
    require 'htmlsample.pl';
    my $TEXT;
        walk_html($TREE,
                 # $textfunc
                  sub { my ($text, $ref) = @_; 
                        $$ref .= $text },
                  sub {},
                  \$TEXT,
                );

    like($TEXT, qr/^\s*What Junior Said Next But I don't want to go to bed now!\s*$/, "untagged text");

=endtest walk_html_userparam


=Stop


================================================================

Perhaps include:
=section State Tables  






After reading an input line, we try to remove a trailing backslash.
If there is one, we remove it, append the following line, and check
again for a new trailing backslash.  If we can't remove a trailing
backslash, it's because there isn't one, so we continue as before.

Now we can write mutli-line definitions in our configuration file:

        DEFINE INLCUDE  my $file = shift; \
                        unless (open INC, $file) {
                          warn "Couldn't open $file: $!; ignoring\n";
                          return ;
                        }
                        read


sets a global option C<$FAST> which has some effect on
the rest of the program.  The second C<DEFINE> directive defines a
C<SLOW> directive to undo the effectof C<FAST>.  

        DEFINE FAST     $FAST = 1
        DEFINE SLOW     $FAST = 0
        FAST

The first directive defines a new configuration file directive,
C<FAST>, which sets a global option C<$FAST> which has some effect on
the rest of the program.  The second C<DEFINE> directive defines a
C<SLOW> directive to undo the effectof C<FAST>.  The third directive
enables C<FAST> mode.

Directioves

        DEFINE INCLUDE     open 


With the current config file processor, we are limited to one-line
definitions, but it's easy to change that by changing the parser a
little bit.  We'll say that if a line ends in a backslash, it is
continued on the next line; many programming languages have similar
continuation rules.  The change is small:

=listing read_config_tablearg

        sub read_config {
          my ($filename, $actions) = @_;        
          open my($CF), $filename or return;  # Failure
          while (<$CF>) {
*           while (s/\\$//) {
*             $_ .= <$CF>;
*           }
            my ($directive, $rest) = split /\s+/, $_, 2;
            if (exists $actions->{$directive}) {
              $actions->{$directive}->($rest);
            } else {
              die "Unrecognized directive $directive on line $. of $filename; aborting";
            }
          }
          return 1;  # Success
        }

=endlisting read_config_tablearg


=Stop

* 20010518 Here's a great example of dispatch tables:  Your PPT
  'units' program. 

* 20010601 Example of dispatch tables: Pretty-printer whose lexer is
  tabular and is loaded depending on what programming language is to
  be printed.




