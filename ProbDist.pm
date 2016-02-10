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
use utf8;

package ProbDist;

#my %orderedpattern2number = get_ordered_patterns(10);

sub unigram {
  # Return a discrete probability distribution of the non-whitespace symbols
  # in a given string, sorted into decreasing order.
  my ($file,$remove) = @_;
  $remove = '' unless $remove;
  my %count = ();
  
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    s/\s//g;
    for (my $i = 0; $i < length($_); $i++) {
      no warnings 'uninitialized';
      $count{substr($_,$i,1)}++;
    }
  }
  close FILE || die $!;
  
  my @dist = normalize(sort {$b <=> $a} values(%count));
  return \@dist;
}


sub unigramwordtype {
  # Return a discrete probability distribution of the non-whitespace symbols
  # in a given string, sorted into decreasing order. Consider each word type
  # only once.
  my ($file,$remove) = @_;
  $remove = '' unless $remove;
  my %count = ();
  
  my %seen = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    foreach my $w (split /\s+/) {
      next if $seen{$w};
      $seen{$w} = 1;
      $w = lc($w) if $remove;
      $w =~ s/$remove//g if $remove;
      $w =~ s/\s//g;
      for (my $i = 0; $i < length($w); $i++) {
        no warnings 'uninitialized';
        $count{substr($w,$i,1)}++;
      }
    }
  }
  close FILE || die $!;
  
  my @dist = normalize(sort {$b <=> $a} values(%count));
  return \@dist;
}


sub wordlength {
  # Get the word pattern distribution for a file.
  my ($file,$remove,$threshold) = @_;
  $threshold = 0 unless $threshold;
  $remove = '' unless $remove;
  
  #my @distribution = ();
  my %distribution = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    foreach my $word (split /\s+/) {
      no warnings 'uninitialized';
      $distribution{length($word)}++;
    }
  }
  close FILE || die $!;
  
  foreach my $k (keys %distribution) {
    if ($distribution{$k} < $threshold) {
      delete($distribution{$k});
    }
  }
  %distribution = normalize_hash(%distribution);
  return \%distribution;
}


sub wordtypelength {
  # Get the word pattern distribution for a file.
  my ($file,$remove,$threshold) = @_;
  $threshold = 0 unless $threshold;
  $remove = '' unless $remove;
  
  #my @distribution = ();
  my %distribution = ();
  my %seen = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    foreach my $word (split /\s+/) {
      next if $seen{$word};
      $seen{$word} = 1;
      no warnings 'uninitialized';
      $distribution{length($word)}++;
    }
  }
  close FILE || die $!;
  
  foreach my $k (keys %distribution) {
    if ($distribution{$k} < $threshold) {
      delete($distribution{$k});
    }
  }
  %distribution = normalize_hash(%distribution);
  return \%distribution;
}


sub wordpattern {
  # Get the word pattern distribution for a file.
  my ($file,$remove,$threshold) = @_;
  $threshold = 0 unless $threshold;
  $remove = '' unless $remove;
  
  #my @distribution = ();
  my %distribution = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    foreach my $word (split /\s+/) {
      next if length($word) > 50;
      no warnings 'uninitialized';
      $distribution{get_word_pattern($word)}++;
    }
  }
  close FILE || die $!;
  
  foreach my $k (keys %distribution) {
    if ($distribution{$k} < $threshold) {
      delete($distribution{$k});
    }
  }
  %distribution = normalize_hash(%distribution);
  return \%distribution;
}


sub wordtypepattern {
  # Get the word pattern distribution for a file.
  my ($file,$remove) = @_;
  $remove = '' unless $remove;
  
  #my @distribution = ();
  my %distribution = ();
  my %seen = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    foreach my $word (split /\s+/) {
      next if $seen{$word};
      $seen{$word} = 1;
      next if length($word) > 50;
      no warnings 'uninitialized';
      $distribution{get_word_pattern($word)}++;
    }
  }
  close FILE || die $!;
  
  %distribution = normalize_hash(%distribution);
  return \%distribution;
}


sub get_word_pattern {
  my $word = shift;
  my %typecount = ();
  foreach my $c (split //, $word) {
    $typecount{$c} = $typecount{$c} ? $typecount{$c}+1 : 1;
  }
  my @counts = sort {$b <=> $a} values(%typecount);
  return join(',',@counts);
}


sub orderedwordpattern {
  # Get the word pattern distribution for a file.
  my ($file,$remove) = @_;
  $remove = '' unless $remove;
  
  #my @distribution = ();
  my %distribution = ();
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  while (<FILE>) {
    chomp;
    $_ = lc($_) if $remove;
    s/$remove//g if $remove;
    foreach my $word (split /\s+/) {
      next if length($word) > 50;
      no warnings 'uninitialized';
      $distribution{get_ordered_word_pattern($word)}++;
    }
  }
  close FILE || die $!;
  
  %distribution = normalize_hash(%distribution);
  return \%distribution;
}


sub get_ordered_word_pattern {
  my $word = shift;
  my $next_num = 1;
  my @pattern_numbers = ();
  my %chr2num = ();
  
  foreach my $c (split //, $word) {
    unless ($chr2num{$c}) {
      $chr2num{$c} = $next_num;
      $next_num++; 
    }
    push @pattern_numbers, $chr2num{$c};
  }
  return join(',',@pattern_numbers);
}


sub wp2num {
  my @wp = split /\D/, shift;
  my @prime = qw/2 3 5 7 11 13 17 19 23 29 31 37 41 43 47 53 59 61 67 71 73 79 83 89 97 101 103 107 109 113 127 131 137 139 149 151 157 163 167 173 179 181 191 193 197 199 211 223 227 229/;
  #my $num = 0;
  my $num = 1;
  for (my $i = 0; $i < @wp; $i++) {
    #$num += $prime[$i] ** $wp[$i];
    $num *= $prime[$i] ** $wp[$i];
  }
  return $num;
}


sub bhattacharyya_dist {
  # Compute the Bhattacharyya distance between P and Q.
  my ($P, $Q) = @_;
  
  my $dist = 0;
  for (my $i = 0; $i < scalar(@$P) && $i < scalar(@$Q); $i++) {
    no warnings 'uninitialized';
    $dist += sqrt($P->[$i] * $Q->[$i]);
  }
  
  return $dist != 0 ? (-1 * log($dist)) : 'inf';
}


sub bhattacharyya_dist_hash {
  # Compute the Bhattacharyya distance between P and Q.
  my ($P, $Q) = @_;
  
  # Get a hash %R that contains all the keys of P and Q
  my %R = ();
  foreach my $k (sort keys %$P) {
    $R{$k} = 1;
  }
  foreach my $k (sort keys %$Q) {
    $R{$k} = 1;
  }
  
  my $distance = 0;
  foreach my $k (sort keys %R) {
    no warnings 'uninitialized';
    $distance += sqrt($P->{$k} * $Q->{$k});
  }
  
  return $distance != 0 ? (-1 * log($distance)) : 'inf';
}



sub jaskiewicz_dist {
  my ($P, $Q) = @_;
  my @P = sort {$b <=> $a} (@$P);
  my @Q = sort {$b <=> $a} (@$Q);
  my $a = 0.96;
  
  my $dist = 0;
  for (my $i = 0; $i < scalar(@P) && $i < scalar(@Q); $i++) {
    no warnings 'uninitialized';
    $dist += (($a ** ($i+1)) * abs($P[$i] - $Q[$i]));
  }
  
  return $dist;
}


sub jaskiewicz_dist_hash {
  my ($P, $Q) = @_;
  
  # Get a hash %R that contains all the keys of P and Q
  my %R = ();
  foreach my $k (sort keys %$P) {
    $R{$k} = 1;
  }
  foreach my $k (sort keys %$Q) {
    $R{$k} = 1;
  }
  
  my $distance = 0;
  foreach my $k (sort keys %R) {
    no warnings 'uninitialized';
    $distance += abs($P->{$k} - $Q->{$k});
  }
  
  return $distance;
}



sub normalize {
  my @list = @_;
  my $sum = 0;
  no warnings 'uninitialized';
  foreach my $e (@list) {$sum += $e;}
  foreach my $e (@list) {$e /= $sum;}
  return @list;
}

sub normalize_hash {
  my %hash = @_;
  my $sum = 0;
  foreach my $k (keys %hash) {$sum += $hash{$k};}
  foreach my $k (keys %hash) {$hash{$k} /= $sum;}
  return %hash;
}

#sub addzeros {
#  my ($P, $Q) = @_;
#  while (@$P < @$Q) {
#    push @$P, 0;
#  }
#  while (@$Q < @$P) {
#    push @$Q, 0;
#  }
#}

#sub unigram_order {
#  # Return a discrete probability distribution of the non-whitespace symbols
#  # in a given file, sorted into decreasing order.
#  my ($file,$remove) = @_;  
#  my %count = ();
#  my $sum = 0;
#  
#  open FILE, '< :encoding(UTF-8)', $file || die $!;
#  while (<FILE>) {
#    chomp;
#    $_ = lc($_);
#    s/$remove//g;
#    foreach my $c (split //, $_) {
#      next if $c =~ /\s/;
#      $count{$c} = $count{$c} ? $count{$c}+1 : 1;
#      $sum++;
#    }
#  }
#  close FILE || die $!;
#  
#  return sort {$count{$b} <=> $count{$a}} (keys(%count));
#}


#sub unigram_order_space {
#  # Return a discrete probability distribution of the non-whitespace symbols
#  # in a given file, sorted into decreasing order.
#  my $file = shift;  
#  my %count = ();
#  my $sum = 0;
#  
#  open FILE, '< :encoding(UTF-8)', $file || die $!;
#  while (<FILE>) {
#    chomp;
#    $_ = lc($_);
#    s/$remove//g;
#    
#    foreach my $c (split //, $_) {
#      $c = '_' if $c =~ /\s/;
#      $count{$c} = $count{$c} ? $count{$c}+1 : 1;
#      $sum++;
#    }
#  }
#  close FILE || die $!;
#  
#  return sort {$count{$b} <=> $count{$a}} (keys(%count));
#}


#sub unigram_order_str {
#  # Return a discrete probability distribution of the non-whitespace symbols
#  # in a given string, sorted into decreasing order.
#  my $str = shift;  
#  my %count = ();
#  my $sum = 0;
#  
#  $str =~ s/$remove//g;;
#  
#  foreach my $c (split //, $_) {
#    next if $c =~ /\s/;
#    $count{$c} = $count{$c} ? $count{$c}+1 : 1;
#    $sum++;
#  }
#  
#  return sort {$count{$b} <=> $count{$a}} (keys(%count));
#}


#sub char_cooccurrences {
#  my $file = shift;
#  my $count = {};
#  
#  open FILE, '< :encoding(UTF-8)', $file || die $!;
#  while (<FILE>) {
#    chomp;
#    $_ = lc($_);
#    s/$remove//g;
#    foreach my $w (split /\s+/, $_) {
#      my @chars = split //, $w;
#      for (my $i = 0; $i < @chars; $i++) {
#        for (my $j = 0; $j < @chars; $j++) {
#          next if $i == $j;
#          $count->{$chars[$i]}{$chars[$j]} = $count->{$chars[$i]}{$chars[$j]} ? $count->{$chars[$i]}{$chars[$j]}+1 : 1;
#        }
#      }
#    }
#  }
#  close FILE || die $!;
#  
#  return $count;
#}


#sub char_cooccurrences_unique {
#  my $file = shift;
#  my $count = {};
#  
#  open FILE, '< :encoding(UTF-8)', $file || die $!;
#  while (<FILE>) {
#    chomp;
#    $_ = lc($_);
#    s/$remove//g;
#    foreach my $w (split /\s+/, $_) {
#      my @chars = split //, $w;
#      my %seen = ();
#      for (my $i = 0; $i < @chars-1; $i++) {
#        for (my $j = $i+1; $j < @chars; $j++) {
#          next if $seen{"$chars[$i]"."$chars[$j]"};
#          $count->{$chars[$i]}{$chars[$j]} = $count->{$chars[$i]}{$chars[$j]} ? $count->{$chars[$i]}{$chars[$j]}+1 : 1;
#          $count->{$chars[$j]}{$chars[$i]} = $count->{$chars[$i]}{$chars[$j]};
#          $seen{"$chars[$i]"."$chars[$j]"} = 1;
#          $seen{"$chars[$j]"."$chars[$i]"} = 1;
#        }
#      }
#    }
#  }
#  close FILE || die $!;
#  
#  return $count;
#}


#sub get_type_counts {
#  # Get all possible type counts for a given length.
#  # Essentially, we are looking for all ways of writing
#  # $n as a sum of positive integers, in non-decreasing
#  # order.
#  # The optional parameter $f sets the minimum size of each term.
#  
#  my ($n,$f) = @_;
#  $f = 1 unless $f;
#  
#  return ()  if $n < $f;
#  return ($n) if $n == $f;
#  return ()  if $n == 0;
#  return (1) if $n == 1;
#      
#  my @typecounts = ();
#  foreach my $m ($f .. $n-1) {
#    my @rectc = get_type_counts($n-$m,$m);
#    foreach my $tc (@rectc) {
#      push @typecounts, "$m,$tc";
#    }
#  }
#  push @typecounts, $n;
#  
#  return @typecounts;
#}


#sub unigram_prob_copiale {
#  # Return a discrete probability distribution of the non-whitespace symbols
#  # in a given string, sorted into decreasing order.
#  my $file = shift;  
#  my %count = ();
#  my $sum = 0;
#  
#  open FILE, '< :encoding(UTF-8)', $file || die $!;
#  while (<FILE>) {
#    chomp;
#    next if /^#/;
#    $_ = lc($_);
#    #s/[\,\.\'\"\;\:\-\(\)]//g;
#    foreach my $c (split /\s+/, $_) {
#      next if $c =~ /\s/;
#      $count{$c} = $count{$c} ? $count{$c}+1 : 1;
#      $sum++;
#    }
#  }
#  close FILE || die $!;
#  
#  foreach my $k (keys(%count)) {
#    $count{$k} /= $sum;
#    #print "$count{$k}\t$k\t<<<\n";
#  }
#  return %count;
#}


# sub type_token_prob {
#   # Description goes here.
#   my ($file,$maxlen) = @_;  
#   my $length = [];
#   $maxlen = 0 unless $maxlen;
#   
#   open FILE, '< :encoding(UTF-8)', $file || die $!;
#   while (<FILE>) {
#     chomp;
#     $_ = lc($_);
#     s/$remove//g;
#     foreach my $word (split /\s+/) {
#       my $tokens = length($word);
#       $maxlen = $tokens > $maxlen ? $tokens : $maxlen;
#       my $types = num_char_types($word);
#       $length->[$tokens][$types]++;
#     }
#   }
#   close FILE || die $!;
#   
#   my @distribution = ();
#   foreach my $l (1 .. $maxlen) {
#     foreach my $t (1 .. $l) {
#       if ($length->[$l] && $length->[$l][$t]) {
#         push @distribution, $length->[$l][$t];
#       }
#       else {
#         push @distribution, 0;
#       }
#     }
#   }
#   @distribution = normalize(@distribution);
#   
#   return @distribution;
# }
# 
# 
# sub char_cooccurrences_prob {
#   my $file = shift;
#   my $count = char_cooccurrences($file);
#   my %flatcount = ();
#   
#   my $sum = 0;
#   foreach my $m (keys %{$count}) {
#     foreach my $n (keys %{$count->{$m}}) {
#       $flatcount{"$m\t$n"} = $count->{$m}{$n};
#       $sum += $flatcount{"$m\t$n"};
#     }
#   }
#   
#   foreach my $m (keys %{$count}) {
#     foreach my $n (keys %{$count->{$m}}) {
#       $flatcount{"$m\t$n"} /= $sum;
#     }
#   }
#   
#   return %flatcount;
# }

#sub num_char_types {
#  my ($word) = @_;
#  my %type = ();
#  foreach my $c (split //, $word) {
#    $type{$c} = 1;
#  }
#  return scalar(keys(%type));
#}


1;
