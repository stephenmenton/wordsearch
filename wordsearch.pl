#!/usr/bin/env perl
use strict;
use File::Basename qw(basename dirname);
use Getopt::Std 'getopts';
use POSIX 'floor';

=begin LICENSE
Copyright [2017] [Stephen F. Menton <aquaone@gmail.com>]

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
=end LICENSE
=cut

# global TODO
# better commenting
# audit internal syntax
# dictionary locations by distro (or first hit)
# flexible output formats (position, counts, etc)
# verbosity, progress
# further optimize

my $script_name=basename $0;
my $script_version='1.4.4';

# parse args
&help    && exit 1 if !$ARGV[0];
&help    && exit 0 if $ARGV[0] =~ /^--?(h(elp)?|\?)$/;
&version && exit 0 if $ARGV[0] =~ /^--?(v(er(sion)?)?)$/;

my %opts;
getopts('c:d:f:l:w:', \%opts);

# min count
my $min_count = $opts{c} || 1;
validate_int(\$min_count, 'count');

# dictionary
my $dictionary_file = $opts{d} || '/usr/share/dict/words';
validate_file(\$dictionary_file, 'dictionary');

# wordsearch file
die "ERROR: no wordsearch file\n" if !$opts{f};
my $wordsearch_file = $opts{f};
validate_file(\$wordsearch_file, 'file');

# min length
my $min_length = $opts{l} || 3;
validate_int(\$min_length, 'length');

# directions
my %ways;
if($opts{w}) {
  foreach my $way (split /,/, $opts{w}) {
    ($way=lc $way) =~ s/^\s+|s+$//g;
    die "ERROR: invalid way ${way}\n" if $way !~ /^([lr]|[ud][lr]?)$/;
    $ways{$way}++;
  }
} else {
  foreach my $way (qw(ul u ur l r dl d dr)) { $ways{$way}++; }
}

# usage
sub help {
  print <<EOF;
Usage: ${script_name} -f FILENAME [OPTIONS]
Searches for words in a file like a wordsearch puzzle
Required:
  -f FILENAME    file containing wordsearch content
Optional:
  -c COUNT       minimum count per word (default is 1)
  -d DICTIONARY  dictionary file to use
  -l LENGTH      minimum word length (default is 3)
  -w WAYS        comma delimited way(s) to search
                 supported values: ul, u, ur, l, r, dl, d, dr
                 e.g. -w "ul, ur, dl, dr"

Report bugs to <aquaone\@gmail.com>
EOF
}

# version info
sub version { print "${script_name} ${script_version}\n"; }

# file validations
sub validate_file() {
  my $file=$_[0] || die "ERROR: invalid call to validate_file\n";
  my $desc=$_[1];
  if(! -e $$file) {
    warn sprintf "WARNING: %s%s does not exist\n", $desc ? "${desc} " : '', $$file if ! -e $$file;
    # find a glob match
    my $file_dir=dirname $$file;
    my $file_base=basename $$file;
    die "ERROR:   and ${file_dir} does not exist\n" if ! -e $file_dir;
    opendir(FILE_DIR, $file_dir) or die "ERROR: unable to open dir ${file_dir}: $!\n";
    my @files=grep(/$file_base/, readdir(FILE_DIR));
    closedir(FILE_DIR);
    die "ERROR:   and no glob matches found\n" if !scalar @files;
    $$file="${file_dir}/" . $files[0]; 
    warn "WARNING:   $${file} will be used\n";
  }
  die sprintf "ERROR: %s%s is not a file\n",       $desc ? "${desc} " : '', $$file if ! -f $$file;
  die sprintf "ERROR: %s%s is unreadable\n",       $desc ? "${desc} " : '', $$file if ! -r $$file;
}

# numeric validations
sub validate_int() {
  my $number=$_[0] || die "ERROR: invalid call to validate_int\n";
  my $desc=$_[1];
  if($$number =~ /^\.\d+$/) {
    warn sprintf "WARNING: %s%s is sub-zero float, forcing 1\n", $desc ? "${desc} " : '', $$number;
    $$number=1;
  } elsif($$number =~ /^\d+\.\d+$/) {
    my $floor=floor $$number; #perfopt
    warn sprintf "WARNING: %s%s is float, forcing $floor\n",     $desc ? "${desc} " : '', $$number;
    $$number=$floor;
  }
  die sprintf("ERROR: %s%s is scientific, not an integer\n",     $desc ? "${desc} " : '', $$number) if $$number =~ /^\d+e\+?\d+$/;
  die sprintf("ERROR: %s%s is not an integer\n",                 $desc ? "${desc} " : '', $$number) if $$number !~ /^\d+$/;
}

# main

# build dictionary hash
my %dictionary;
open(DICTIONARY_FILE, $dictionary_file) or die "ERROR: failure opening dictionary ${dictionary_file}: $!\n";
while(my $word=<DICTIONARY_FILE>) {
  chomp($word=lc $word);
  $dictionary{$word}++ if(length $word >= $min_length);
}

# build found words
open(FILE, $wordsearch_file) or die "ERROR: failure opening file ${wordsearch_file}: $!\n";
# read file into array
my @puzzle_array;
while(my $line=<FILE>) {
  chomp $line;
  push @puzzle_array, [split //, $line];
}
# create found words hash of arrays of hashes
# TODO should be one-liner via hash slice, not loop, forgot syntax
my(%puzzle_words, %xo, %yo);
foreach my $way (qw(ul l dl)) { $xo{$way}=-1; };
foreach my $way (qw(u d))     { $xo{$way}=0;  };
foreach my $way (qw(ur r dr)) { $xo{$way}=1;  };
foreach my $way (qw(ul u ur)) { $yo{$way}=-1; };
foreach my $way (qw(l r))     { $yo{$way}=0;  };
foreach my $way (qw(dl d dr)) { $yo{$way}=1;  };

my $height=scalar @puzzle_array; #perfopt
for(my $y=0; $y < $height; $y++) {
  my $width=scalar @{$puzzle_array[$y]}; #perfopt
  for(my $x=0; $x < $width; $x++) {
    foreach my $way (keys(%ways)) {
      my($xl, $yl, $string)=($x, $y, '');
      while($xl >= 0 && $yl >= 0 && defined $puzzle_array[$yl][$xl]) {
        $string .= $puzzle_array[$yl][$xl];
        if(exists $dictionary{$string}) {
          $puzzle_words{$string}=() if !exists $puzzle_words{$string};
          push @{$puzzle_words{$string}}, { 'x' => $x, 'y' => $y, 'way' => $way };
        }
        $xl += $xo{$way};
        $yl += $yo{$way};
      }
    }
  }
}

printf "%d %d+ words (searching %s)", scalar keys %puzzle_words, $min_length, join(', ', sort keys %ways);
foreach my $word (sort keys %puzzle_words) {
  my $count=scalar @{$puzzle_words{$word}};
  printf ", $word%s", $count > 1 ? " (${count})" : '' if $count >= $min_count;
}
print "\n";

__END__
