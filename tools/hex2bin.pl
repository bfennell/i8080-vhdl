# Copyright (c) 2018 Brendan Fennell <bfennell@skynet.ie>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

use strict;
use warnings;
use Getopt::Long;

my @values = ();
my $file = undef;
my $out = undef;

GetOptions ("file=s" => \$file,
            "out=s"  => \$out);

die ("usage: $0 -f FILE -o f\n") unless (defined $file && defined $out);

open (my $fin, $file) or die ("Error: failed to open '$file' : $!");
while (<$fin>) {
    if (/^(..)/) {
        push (@values, hex($1));
    } else {
        die ("Error: unknown format");
    }
}
close ($fin);

open (my $fout, '>:raw', $out);
map { print $fout chr($_) } @values;
close ($fout);
