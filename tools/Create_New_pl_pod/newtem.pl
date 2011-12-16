#!perl

use strict;
use warnings;
use 5.010;

use autodie;
use List::MoreUtils qw<mesh>;

open (FILE,'<', 'D:\data\CD4-H3K9ac.bed');

my @num = (1 .. 22, 'x', 'y');
my @fh = map { "CHR$_" } @num;
my @file = map { lc($_) } @fh;
my %file_fh = mesh @file, @fh;
while (my ($file, $fh) = each %file_fh) {
    eval("open($fh, '>', \$file);");
}

while(my $line = <FILE>) {
    $line =~ s/([+-])$/0\t$1/;
    my($file) = split /\t/, $line;
    eval("say $file_fh{$file} \$line");
}
close FILE;

# 日期：Fri Oct 14 20:56:03 2011
# 作者: 宋志泉 songzhiquan@hotmail.com

# ------------------------------------
# 文件运行结束标志
print "...Program Runnig Over...\n";
# vim:tw=78:ts=8:ft=perl:norl:

