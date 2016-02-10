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
use Alphagram;

package Viterbi;

sub DecodeAlphagrams {
  # J&M page 147

  my ($A1, $A2, $B, $O, $Q, $lambda, $w2n) = @_;
  # $A1: Unigram language model.
  #      $A1->{$w2} := p($w2)
  # $A2: Bigram language model.
  #      $A2->{$w1}{$w2} := p( $w2 | $w1 )
  # $B: List of possible words (states) for an alphagram (emission).
  #     @{$B->{$a1}} := list of words that generate $a1.
  # $O: Array of T alphagrams (emissions), to be decoded.
  # $Q: List of N words (states)
  # $lambda: normalized weighting of the bigram lm.
  
  # Handle trivial case.
  return '' if scalar(@$O) == 0;
  
  # Get length and state count.
  my $T = scalar(@$O); # Number of observations.
  my $N = scalar(@$Q)-1; # Number of words.
  
  # Start indices from 1, just for readability.
  unshift @$O, '';
  
  # Declare arrays.
  my $viterbi = [];
  my $backpointer = [];
  
  
  # Initialization.
  foreach my $s_word (sort @{$B->{$O->[1]}}) {
    my $s = $w2n->{$s_word};
    $viterbi->[$s][1] = A('<s>', $s_word, $A1, $A2, $lambda);
  }
  
  
  # Recursion.
  foreach my $t (2 .. $T) {
    foreach my $s_word (@{$B->{$O->[$t]}}) {       
      my $max = -inf;
      my $argmax = 0;      
      
      foreach my $sprime_word (sort @{$B->{$O->[$t-1]}}) {
        my $sprime = $w2n->{$sprime_word};        
        my $value  = $viterbi->[$sprime][$t-1] * A($sprime_word, $s_word, $A1, $A2, $lambda);
        ($max, $argmax) = ($value, $sprime) if ($value > $max);        
      }

      my $s = $w2n->{$s_word};
      $viterbi->[$s][$t] = $max;
      $backpointer->[$s][$t] = $argmax;
    }
  }
  
  
  # Termination;
  my $max = -inf;
  my $argmax = 0;
  for my $s_word (sort @{$B->{$O->[-1]}}) {
    my $s = $w2n->{$s_word};    
    my $value = $viterbi->[$s][$T] * A( $s_word, '<\s>', $A1, $A2, $lambda);
    ($max, $argmax) = ($value, $s) if ($value > $max);
  }
  $viterbi->[$N+1][$T] = $max;
  $backpointer->[$N+1][$T] = $argmax;

  
  # Backtrace
  my @path = ();  
  my $j = $backpointer->[$N+1][$T];
  push @path, $j;  
  for (my $i = $T; $i > 0; $i--) {
    push @path, $backpointer->[$j][$i];
    $j = $backpointer->[$j][$i];
  }
  pop @path;
  
  
  # Replace numbers with words.
  for (my $i = 0; $i < @path; $i++) {
    $path[$i] = $Q->[$path[$i]];
  }
  
  
  # Return.
  return join ' ', reverse(@path);
}


sub A {
  my ($w1, $w2, $A1, $A2, $lambda) = @_;
  my $bigram_prob = $A2->{$w1}{$w2} ? $A2->{$w1}{$w2} : 0;
  my $unigram_prob = $A1->{$w2} ? $A1->{$w2} : 0;
  my $prob = ($lambda * $bigram_prob) + ((1-$lambda) * $unigram_prob);
  return $prob;
}



sub DecodeAlphagramsTrigram {
  # J&M page 147

  my ($A1, $A2, $A3, $B, $O, $Q, $l1, $l2, $l3, $w2n) = @_;
  # $A1: Unigram language model.
  #      $A1->{$w2} := p($w2)
  # $A2: Bigram language model.
  #      $A2->{$w1}{$w2} := p( $w2 | $w1 )
  # $B: List of possible words (states) for an alphagram (emission).
  #     @{$B->{$a1}} := list of words that generate $a1.
  # $O: Array of T alphagrams (emissions), to be decoded.
  # $Q: List of N words (states)
  # $lambda: normalized weighting of the bigram lm.
  
  # Handle trivial case.
  return '' if scalar(@$O) == 0;
  return DecodeAlphagrams($A1, $A2, $B, $O, $Q, ($l3+$l2), $w2n) if scalar(@$O) == 1;
  
  # Get length and state count.
  my $T = scalar(@$O); # Number of observations.
  
  # Start indices from 1, just for readability.
  unshift @$O, '';
  
  # Declare arrays
  my $viterbi = [];
  my $backpointer = [];


  # Initialize
  foreach my $r_word (@{$B->{$O->[1]}}) {
    my $r = $w2n->{$r_word};
    foreach my $s_word (@{$B->{$O->[2]}}) {
      my $s = $w2n->{$s_word};      
      $viterbi->[2][$r][$s] = A3('<s>', '<s>', $r_word, $A1, $A2, $A3, $l1, $l2, $l3)
                            * A3('<s>', $r_word, $s_word, $A1, $A2, $A3, $l1, $l2, $l3);
      $backpointer->[2][$r][$s] = 0;
    }
  }
  
  
  # Recursion.
  foreach my $t (3 .. $T) {
    foreach my $r_word (@{$B->{$O->[$t-1]}}) {
      my $r = $w2n->{$r_word};
      foreach my $s_word (@{$B->{$O->[$t]}}) {
        my $s = $w2n->{$s_word};
        
        my $max = -inf;
        my $argmax = 0;      
        
        foreach my $q_word (sort @{$B->{$O->[$t-2]}}) {
          my $q = $w2n->{$q_word};
          my $prior = $viterbi->[$t-1][$q][$r] ? $viterbi->[$t-1][$q][$r] : 0;
          my $value = $prior * A3($q_word, $r_word, $s_word, $A1, $A2, $A3, $l1, $l2, $l3);
          ($max, $argmax) = ($value, $q) if ($value > $max);        
        }

        $max *= 1000;
        #print "$t\t$r\t$s\t$max\n";

        $viterbi->[$t][$r][$s] = $max;
        $backpointer->[$t][$r][$s] = $argmax;
      }
    }
  }
  
  
  # Terminate
  my $max = -inf;
  my $best_r;
  my $best_s;
  foreach my $r_word (@{$B->{$O->[$T-1]}}) {
    my $r = $w2n->{$r_word};
    foreach my $s_word (@{$B->{$O->[$T]}}) {
      my $s = $w2n->{$s_word};
      my $prior = $viterbi->[$T][$r][$s] ? $viterbi->[$T][$r][$s] : 0;
      my $value = $prior * A3($r_word, $s_word, '<\s>', $A1, $A2, $A3, $l1, $l2, $l3)
                         * A3($s_word, '<\s>', '<\s>', $A1, $A2, $A3, $l1, $l2, $l3);
      ($max, $best_r, $best_s) = ($value, $r, $s) if ($value > $max);
    }
  }
  
  
  # Backtrace
  my @path = ();
  $path[$T] = $best_s; 
  $path[$T-1] = $best_r;
   
  for (my $i = $T-2; $i > 0; $i--) {
    die "No backpointer [$i][$path[$i+1]][$path[$i+2]]\n" 
      unless defined $backpointer->[$i+2][$path[$i+1]][$path[$i+2]];
    $path[$i] = $backpointer->[$i+2][$path[$i+1]][$path[$i+2]];
  }
  
  shift @path;
  
  
  # Replace numbers with words.
  for (my $i = 0; $i < @path; $i++) {
    $path[$i] = $Q->[$path[$i]];
  }  
  
  # Return.
  return join ' ', @path;
}


sub A3 {
  my ($w1, $w2, $w3, $A1, $A2, $A3, $l1, $l2, $l3) = @_;
  #if (abs(1 - ($l1 + $l2 + $l3)) > 0.001) {
  #  die "Lambda's not normalized!";
  #}
  my $trigram_prob = $A3->{$w1}{$w2}{$w3} ? $A3->{$w1}{$w2}{$w3} : 0;
  my $bigram_prob  = $A2->{$w2}{$w3} ? $A2->{$w2}{$w3} : 0;
  my $unigram_prob = $A1->{$w3} ? $A1->{$w3} : 0;
  my $prob = ($l3 * $trigram_prob) + ($l2 * $bigram_prob) + ($l1 * $unigram_prob);
  return $prob;
}

1;
