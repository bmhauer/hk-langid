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
binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

use Alphagram;

package Utils;

sub Pattern {
  my @patternalphabet = qw/a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9 + -/;
  my $word = shift;
  my $pos = 0;
  my %tr = ();
  $tr{' '} = ' ';
  for (my $i = 0; $i < length($word); $i++) {
    next if $tr{substr($word,$i,1)};
    $tr{substr($word,$i,1)} = $patternalphabet[$pos];
    $pos++;
  }
  return ReplaceString($word,\%tr);
}


sub APattern {
  my $ngram = shift;
  
  my $count = [];
  
  my @words = split /\s+/, $ngram;
  for (my $i = 0; $i < @words; $i++) {
    foreach my $c (split //, $words[$i]) {
      $count->[$i]{$c} = $count->[$i]{$c} ? $count->[$i]{$c}+1 : 1;
    }
  }
  
  my @new_words = ();
  for (my $i = 0; $i < @words; $i++) {
    my @chars_in_order = split //, $words[$i];
    for (my $j = scalar(@words)-1; $j >= 0; $j--) {
      no warnings 'uninitialized';
      @chars_in_order = sort {$count->[$j]{$b} <=> $count->[$j]{$a}} @chars_in_order; 
    }
    $new_words[$i] = join '', @chars_in_order;
  }  
  
  return Pattern(join(' ', @new_words));
}


sub APattern_wl {
  # preserve characters
  my $ngram = shift;
  
  my $count = [];
  
  my @words = split /\s+/, $ngram;
  for (my $i = 0; $i < @words; $i++) {
    foreach my $c (split //, $words[$i]) {
      $count->[$i]{$c} = $count->[$i]{$c} ? $count->[$i]{$c}+1 : 1;
    }
  }
  
  my @new_words = ();
  for (my $i = 0; $i < @words; $i++) {
    my %chars = ();
    for (split //, $words[$i]) {
      $chars{$_} = $count->[$i]{$_};
    }
    my $new_word = '';
    foreach my $c (sort {$chars{$b} <=> $chars{$a}} keys %chars) {
      $new_word .= $c x $chars{$c};
    }
    push @new_words, Pattern($new_word) if $new_word;
  }
    
  return join(' ', @new_words);
}


sub APattern_pc {
  my $ngram = shift;
  
  my $count = [];
  
  my @words = split /\s+/, $ngram;
  for (my $i = 0; $i < @words; $i++) {
    foreach my $c (split //, $words[$i]) {
      $count->[$i]{$c} = $count->[$i]{$c} ? $count->[$i]{$c}+1 : 1;
    }
  }
  
  my @new_words = ();
  for (my $i = 0; $i < @words; $i++) {
    my @chars_in_order = sort(split //, $words[$i]);
    for (my $j = scalar(@words)-1; $j >= 0; $j--) {
      no warnings 'uninitialized';
      @chars_in_order = sort {$count->[$j]{$b} <=> $count->[$j]{$a}} @chars_in_order; 
    }
    $new_words[$i] = join '', @chars_in_order;
  }  
  
  return join(' ', @new_words);
}


sub APattern_wlpc {
  # preserve characters
  my $ngram = shift;
  
  my $count = [];
  
  my @words = split /\s+/, $ngram;
  for (my $i = 0; $i < @words; $i++) {
    foreach my $c (split //, $words[$i]) {
      $count->[$i]{$c} = $count->[$i]{$c} ? $count->[$i]{$c}+1 : 1;
    }
  }
  
  my @new_words = ();
  for (my $i = 0; $i < @words; $i++) {
    my %chars = ();
    for (split //, $words[$i]) {
      $chars{$_} = $count->[$i]{$_};
    }
    my $new_word = '';
    foreach my $c (sort {$chars{$b} <=> $chars{$a}} sort(keys(%chars))) {
      $new_word .= $c x $chars{$c};
    }
    push @new_words, $new_word if $new_word;
  }  
  
  return join(' ', @new_words);
}


sub SymbolCounts {
  my ($counts, $string) = @_;
  foreach my $c (split //, $string) {
    next if $c eq ' ';
    $counts->{$c} = $counts->{$c} ? $counts->{$c}+1 : 1;
  }
}


sub ReplaceString {
  my ($text, $hash) = @_;
  my $string = '';
  foreach my $c (split //, $text) {
    if ($hash->{$c}) {
      $string .= $hash->{$c};
    } else {
      $string .= $c;
    }
  }
  return $string;  
}


sub ReadPList {
  my ($file,$gwp,$word,$maxlen,$nospace) = @_;
  
  open FILE, '<:encoding(UTF-8)', $file || die $!;  
  while (<FILE>) {
    chomp;
    s/\s+$//g;
    
    if ($nospace) {
      s/ //g;
    }
    
    my ($order,$pattern,@ngrams) = split /\t+/;
    
    if ($order == 1) {
      foreach my $ngram (@ngrams) {      
        $word->{$ngram} = 1;
      }
    }

    if ($nospace) {
      $order = 1;
    }
    
    if ($order == 1) {
      foreach my $ngram (@ngrams) {      
        if (length($ngram) > $$maxlen) {
          $$maxlen = length($ngram);
        }
      }
    }
    
    if ($gwp->[$order]->{$pattern}) {
      push @{$gwp->[$order]->{$pattern}}, @ngrams;
    } else {
      @{$gwp->[$order]->{$pattern}} = @ngrams;
    }
  }
  close FILE || die $!;
}


sub PrintKey {
  my ($key,$C) = @_;
  
  my %tr = ();    
  for (my $i = 0; $i < @$C; $i++) {
    $tr{$C->[$i]} = substr($key,$i,1);
  }
  
  foreach my $c (sort @$C) {
    print $c;
  }
  print "\n";
  foreach my $c (sort @$C) {
    print $tr{$c};
  }
  print "\n\n";
}


sub Sim {
  my ($x, $y) = @_;
  my $com = 0;
  for (my $i = 0; $i < length($x); $i++) {
    $com++ if substr($x,$i,1) eq substr($y,$i,1);
  }
  return $com/length($x);
}

sub SimAlph {
  my ($x, $y) = @_;
  my $xcounts = {};
  SymbolCounts($xcounts, $x);
  my $ycounts = {};
  SymbolCounts($ycounts, $y);
  my $combined_counts = {};
  SymbolCounts($combined_counts, "$x $y");
  
  my $manhattan_norm = 0;
  foreach my $k (keys %$combined_counts) {
    no warnings 'uninitialized';
    $manhattan_norm += abs($xcounts->{$k} - $ycounts->{$k});
  }
  
  return ($manhattan_norm * -1);
}


sub Decipher {
  my ($ctext, $key, @C) = @_;
  
  my %tr = ();    
  for (my $i = 0; $i < @C; $i++) {
    $tr{$C[$i]} = substr($key,$i,1);
  }
  
  return ReplaceString($ctext,\%tr);
}

sub GetFirstField {
  my ($file, $list) = @_;
  open FILE, '<:encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    my ($one, @rest) = split /\t+/;
    next unless $one;
    push @$list, $one;
  }
  close FILE || die $!;
}

sub GetSecondField {
  my ($file, $list) = @_;
  open FILE, '<:encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    my ($one, $two, @rest) = split /\t+/;
    next unless $two;
    push @$list, $two;
  }
  close FILE || die $!;
}

sub ReadHash {
  my ($file, $hash) = @_;
  open FILE, '<:encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    my ($key, $value) = split /\t+/;
    $hash->{$key} = $value;
  }
  close FILE || die $!;
}

sub ReadHashOfLists {
  my ($file, $hash) = @_;
  open FILE, '<:encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    my ($key, @values) = split /\t+/;
    next unless $key;
    $hash->{$key} = [@values];
  }
  close FILE || die $!;
}

1;
