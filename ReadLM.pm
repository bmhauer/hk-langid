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

package ReadLM;

sub ReadWordList {
  # Takes a filename and a hash.
  my ($file, $words) = @_;
  
  open WORDS, '<:encoding(UTF-8)', $file || die $!;
  while (<WORDS>) {
    chomp;
    my ($word, @other) = split /\t+/;
    $words->{$word} = 1;
  }
  close WORDS || die $!;
}


sub ReadUnigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<:encoding(UTF-8)', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $p) = split /\t+/;
    $lm->{$w1} = $p;
  }
  close LM || die $!;
}


sub ReadBigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<:encoding(UTF-8)', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $w2, $p) = split /\t+/;
    $lm->{$w1}{$w2} = $p;
  }
  close LM || die $!;
}


sub ReadTrigramLM {
  my ($file, $lm) = @_;
  
  open LM, '<:encoding(UTF-8)', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w1, $w2, $w3, $p) = split /\t+/;
    $lm->{$w1}{$w2}{$w3} = $p;
  }
  close LM || die $!;
}


sub ReadProbs {
  my ($file, $lm) = @_;
  
  open LM, '<:encoding(UTF-8)', $file || die $!;
  while (<LM>) {
    chomp;
    my ($w, $p) = split /\t+/;
    $lm->{$w} = $p;
  }
  close LM || die $!;
}


1;
