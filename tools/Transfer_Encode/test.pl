#!perl

use strict;
use warnings;

# 设定精度要求
my $ignore_min_value = 0.0000001;

$a = 10/3 - (1/3) * 10;
print $a;
if ( (10/3 - ((1/3)*10)) < $ignore_min_value) {
    print "success!";
}
else {
    print "failure!";
}

