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

use lib '../Modules';
use warnings;
use strict;

no warnings 'recursion';

package NoSpace;

sub FindWords {
  my ($str, $is_word, $max_word_length) = @_;
  return $str if !$str;
  return $str if $is_word->{$str};
  return $str if $str !~ /\S/;
  
  for (my $length = $max_word_length; $length > 0; $length--) {
    for (my $offset = 0; $offset+$length-1 < length($str); $offset++) {    
      my $w = substr($str,$offset,$length);
      next unless $is_word->{$w};
      
      if ($offset == 0) {
        my $ret = "$w " . (FindWords(substr($str,$length), $is_word, $max_word_length));
        $ret =~ s/\s+/ /g;
        return $ret;
      } elsif ($offset + $length == length($str)) {
        my $ret = (FindWords(substr($str,0,$offset), $is_word, $max_word_length)) . " $w";
        $ret =~ s/\s+/ /g;
        return $ret;
      } else {
        my $ret = (FindWords(substr($str,0,$offset), $is_word, $max_word_length)) . " $w " . (FindWords(substr($str,$offset+$length), $is_word, $max_word_length));
        $ret =~ s/\s+/ /g;
        return $ret;
      }
    }
  }
  
  return $str;
}


1;
