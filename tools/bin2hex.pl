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

#-----------------------------------------------------------
#-- 0000-1fff : 8k ROM
#-----------------------------------------------------------

my $size  = (1024*8);
my @ascii = ();
my $index = 0;
my $file  = undef;
my $off   = undef;

GetOptions ("bin=s" => \$file,
            "off=i" => \$off);

die ("usage: $0 -b FILE -o OFFSET\n") unless (defined $off && defined $file);

# fill before offset
while ($index < ($off - 1)) {
    $ascii[$index++] = "00";
}

# slurp in binary
open (my $f, $file) or die ("Error: failed to open '$file' : $!");
binmode $f;
my $binary = do { local $/; <$f> };
close ($f);

# convert to ascii
map{ $ascii[$index++] = sprintf ('%02x', $_) } unpack 'C*', $binary;


# fill after offset
while ($index < $size) {
    $ascii[$index++] = "00";
}

# dump to console
foreach my $byte (@ascii) {
    print "$byte\n";
}
