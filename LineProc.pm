# Written by Bradley Hauer (bmhauer@ualberta.ca)
# Made available as part of:
#   Bradley Hauer and Grzegorz Kondrak. 2016. Decoding Anagrammed Texts
#   Written in Unknown Language and Script. Accepted for publication in
#   Transactions of the Association for Computational Linguistics. 
# This code is made available under a Creative Commons Attribution-ShareAlike
# 4.0 International (CC BY-SA 4.0) liscence, so you can use it, modify it,
# and redistribute it however you want, as long as you mainain this liscence
# and give us (Bradley Hauer and Grzegorz Kondrak) credit.
# See the included LISCENCE file for more details (by using this software,
# you agree that you have read that liscence and agree to it.

use warnings;
use strict;

package LineProc;

sub Underscore {
  my $str = shift;
  chomp($str);
  $str = lc($str);
  $str =~ s/\s+/_/g;
  return $str;
}

sub LowercaseAndUnderscore {
  my $str = shift;
  chomp($str);
  $str = lc($str);
  $str =~ s/\s+/_/g;
  return $str;
}

sub LowercaseUnderscoreAndAlpha {
  my $str = shift;
  chomp($str);
  $str = lc($str);
  $str =~ s/\s+/_/g;
  my $remove = '[‐\^\,\.\'\"\;\:\-\(\)\!\[\]\<\>\?\&\#\‐1234567890\*\\\]';
  $str =~ s/$remove//g;
  return $str;
}

1;
