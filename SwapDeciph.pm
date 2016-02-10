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
use LineProc;

package SwapDeciph;

binmode STDOUT, ':utf8';

my $swap_count = 0;

sub TopSwapDeciph {
  my ($counts_c, $counts_p, $restarts, $skip_heuristic, $iterations, $factor, $num_bigrams) = @_;
  print $num_bigrams ? "[TOP SWAP DECIPH]\t" : "[ALL SWAP DECIPH]\t";
  srand(19901020);
  $restarts = 0 unless $restarts;
  $factor = 1 unless $factor;
  
  # Get frequency orders, and remove unwanted characters.
  my @order_c = sort {$counts_c->[1]{$b} <=> $counts_c->[1]{$a}} keys(%{$counts_c->[1]});
  for (my $i = 0; $i < @order_c; $i++) {
    if ($order_c[$i] eq '_' || $order_c[$i] =~ /\s/ || $order_c[$i] eq '‐') {
      splice(@order_c, $i, 1);
    }
  }
  my @order_p = sort {$counts_p->[1]{$b} <=> $counts_p->[1]{$a}} keys(%{$counts_p->[1]});
  for (my $i = 0; $i < @order_p; $i++) {
    if ($order_p[$i] eq '_' || $order_p[$i] =~ /\s/ || $order_p[$i] eq '‐') {
      splice(@order_p, $i, 1);
    }
  }
  
  # Apply the alphabet size heuristic.
  my $min_alph_size = @order_c <= @order_p ? scalar(@order_c) : scalar(@order_p);
  if ($skip_heuristic && ( @order_p*1.5 < @order_c  ||  @order_p*0.25 > @order_c )) {
    return ({},-inf,-1);
  }
  
  # Pad the plaintext alphabet with dashes, as needed.
  if (@order_p < @order_c) {
    $counts_p->[1]{'-'} = 1;
    $counts_p->[0]++;
  }
  while (@order_p < @order_c) {
    push @order_p, '-';    
  }
  
  # Compute the probabilities of all bigrams.
  my $probs_p = {};
  foreach my $p1 (keys %{$counts_p->[1]}) {
    foreach my $p2 (keys %{$counts_p->[1]}) {
      no warnings 'uninitialized';
      $probs_p->{$p1}{$p2} = log(0.9 *
                                 $counts_p->[2]{$p1}{$p2} / 
                                 $counts_p->[1]{$p1}
                                 +
                                 0.1 *
                                 $counts_p->[1]{$p2} /
                                 $counts_p->[0]
                                );
      die if $probs_p->{$p1}{$p2} > 0;
    }
  }
  
  # Get frequency mapping key and evaluate it; this is our default key.
  my %key = ('_' => '_');
  for (my $i = 0; $i < @order_c; $i++) {
    $key{$order_c[$i]} = $order_p[$i];
  }
  my %bestkey = %key;
  my $bestscore = GetDeciphScoreKey(\%bestkey, $counts_c, $probs_p);
  my $bestiter = -1;


  # Perform an initial run and random restarts.
  foreach my $iter (0..$restarts) {
    if ($iter > 0) {
      # All iterations except 0 are random restarts.
      @order_p = Scramble(@order_p);
    }
        
    # Initialize the key we will optimize this iteration.
    my %iterkey = ('_' => '_');
    for (my $i = 0; $i < @order_c; $i++) {
      $iterkey{$order_c[$i]} = $order_p[$i];
    }
    my $iterscore = GetDeciphScoreKey(\%iterkey, $counts_c, $probs_p);
    
    
    # Take some number of steps "uphill".
    my $steps = $iterations ? $iterations : $factor*$min_alph_size;
    for (1..$steps) {  
    
      my %bestnewkey = ();
      my $bestnewscore = -inf;
      my %seen = ();
    
      if ($num_bigrams) {
        # Rank the bigrams in the decipherment.
        my %bigrams_in_decipherment = ();    
        foreach my $c1 (keys(%{$counts_c->[2]})) {
          next if $c1 eq '_';
          my $d1 = $iterkey{$c1};
          foreach my $c2 (keys(%{$counts_c->[2]{$c1}})) {
            next if $c2 eq '_';
            my $d2 = $iterkey{$c2};
            die unless $d2;
            $bigrams_in_decipherment{$c1.$c2} = $counts_p->[2]{$d1}{$d2} || 0;
          }
        }
        my @sorted_bigrams = sort 
          {$bigrams_in_decipherment{$a} <=> $bigrams_in_decipherment{$b}} 
          keys(%bigrams_in_decipherment);
          
        
        # Find the letters we need to swap.
        my %needtoswap = ();
        for (my $i = 0; $i < $num_bigrams && $i < @sorted_bigrams; $i++) {
          $needtoswap{substr($sorted_bigrams[$i],0,1)} = 1;
          $needtoswap{substr($sorted_bigrams[$i],1,1)} = 1;
        }
        
        
        # Swap all letters we %needtoswap with all other letters,
        # and find the best resulting key.
        for (my $i = 0; $i < @order_c; $i++) {
          my $c1 = $order_c[$i];
          next unless $needtoswap{$c1};
          next if $c1 eq '_';
          
          for (my $j = 0; $j < @order_c; $j++) {
            my $c2 = $order_c[$j];
            next if ($needtoswap{$c2} && $j <= $i);
            next if $c2 eq '_';
            
            my %newkey = %iterkey;
            ($newkey{$c1},$newkey{$c2}) = ($newkey{$c2},$newkey{$c1});
            my $newscore = 
              GetSwapScore(\%newkey, $counts_c, $probs_p, $iterscore, $c1, $c2);
            if ($newscore > $bestnewscore) {
              %bestnewkey = %newkey;
              $bestnewscore = $newscore;
            }
          }
        }
      }
      else {
        # Swap all letters with all other letters,
        # and find the best resulting key.
        for (my $i = 0; $i < @order_c-1; $i++) {
          my $c1 = $order_c[$i];
          next if $c1 eq '_';
          
          for (my $j = $i+1; $j < @order_c; $j++) {
            my $c2 = $order_c[$j];
            next if $c2 eq '_';
            
            my %newkey = %iterkey;
            ($newkey{$c1},$newkey{$c2}) = ($newkey{$c2},$newkey{$c1});
            my $newscore = 
              GetSwapScore(\%newkey, $counts_c, $probs_p, $iterscore, $c1, $c2);
            if ($newscore > $bestnewscore) {
              %bestnewkey = %newkey;
              $bestnewscore = $newscore;
            }
          }
        }
      }
      
      # Choose which step to take, and set up for the next iteration.
      if ($bestnewscore > $iterscore) {
        %iterkey = %bestnewkey;
        $iterscore = $bestnewscore;
      }
      else {
        last;
      }
    } # end of step
    
    if ($iterscore > $bestscore) {
      %bestkey = %iterkey;
      $bestscore = $iterscore;
      $bestiter = $iter;
    }
  } # end of iteration  
  
  return (\%bestkey,$bestscore,$bestiter);
}

sub GetDeciphScoreKey {
  my ($key, $counts_c, $probs_p, $s1, $s2) = @_;
  
  my $prob = 0;
  foreach my $c1 (keys(%{$counts_c->[2]})) {
    my $d1 = $key->{$c1};
    foreach my $c2 (keys(%{$counts_c->[2]{$c1}})) {
      my $d2 = $key->{$c2};
      no warnings 'uninitialized';
      $prob += $probs_p->{$d1}{$d2} * $counts_c->[2]{$c1}{$c2};
    }
  }
  return $prob;
}

sub GetSwapScore {
  my ($key, $counts_c, $probs_p, $prob, $s1, $s2) = @_;
  # prob is the score before the swap
  # s1 and s2 are the ciphertext letters that were swapped.
  my $t1 = $key->{$s1};
  my $t2 = $key->{$s2};
  
  foreach my $c (keys %$key) {
    next if ($c eq $s1 || $c eq $s2);
    my $p = $key->{$c};    
    no warnings 'uninitialized';    
    $prob += ( ($probs_p->{$p}{$t1}) * ($counts_c->[2]{$c}{$s1} - $counts_c->[2]{$c}{$s2}) );
    $prob += ( ($probs_p->{$p}{$t2}) * ($counts_c->[2]{$c}{$s2} - $counts_c->[2]{$c}{$s1}) );
    $prob += ( ($probs_p->{$t1}{$p}) * ($counts_c->[2]{$s1}{$c} - $counts_c->[2]{$s2}{$c}) );
    $prob += ( ($probs_p->{$t2}{$p}) * ($counts_c->[2]{$s2}{$c} - $counts_c->[2]{$s1}{$c}) );
  }
  
  no warnings 'uninitialized';  
  $prob += ( ($probs_p->{$t1}{$t1}) * ($counts_c->[2]{$s1}{$s1} - $counts_c->[2]{$s2}{$s2}) );
  $prob += ( ($probs_p->{$t2}{$t2}) * ($counts_c->[2]{$s2}{$s2} - $counts_c->[2]{$s1}{$s1}) );
  $prob += ( ($probs_p->{$t1}{$t2}) * ($counts_c->[2]{$s1}{$s2} - $counts_c->[2]{$s2}{$s1}) );
  $prob += ( ($probs_p->{$t2}{$t1}) * ($counts_c->[2]{$s2}{$s1} - $counts_c->[2]{$s1}{$s2}) );
  
  return $prob;
}







sub SwapDeciph {
  my ($counts_c, $counts_p, $restarts, $skip_heuristic, $iterations, $factor) = @_;
  $restarts = 0 unless $restarts;
  $factor = 10 unless $factor;
  my @order_c = sort {$counts_c->[1]{$b} <=> $counts_c->[1]{$a}} keys(%{$counts_c->[1]});
  for (my $i = 0; $i < @order_c; $i++) {
    if ($order_c[$i] eq '_' || $order_c[$i] =~ /\s/ || $order_c[$i] eq '‐') {
      splice(@order_c, $i, 1);
    }
  }
  my @order_p = sort {$counts_p->[1]{$b} <=> $counts_p->[1]{$a}} keys(%{$counts_p->[1]});
  for (my $i = 0; $i < @order_p; $i++) {
    if ($order_p[$i] eq '_' || $order_p[$i] =~ /\s/ || $order_p[$i] eq '‐') {
      splice(@order_p, $i, 1);
    }
  }
  
  my $min_alph_size = @order_c <= @order_p ? scalar(@order_c) : scalar(@order_p);
  if ($skip_heuristic && abs(scalar(@order_c) - scalar(@order_p)) > $min_alph_size) {
    # Fail.
    return ({},-inf);
  }
  
  if (@order_p < @order_c) {
    $counts_p->[1]{'-'} = 1;
    $counts_p->[0]++;
  }
  while (@order_p < @order_c) {
    push @order_p, '-';    
  }
  
  my $best_max = GetDeciphScore(\@order_c, \@order_p, $counts_c, $counts_p);
  my @best_order_p = @order_p;
  foreach my $i (0..$restarts) {
    if ($i > 0) {
      @order_p = Scramble(@order_p);
    }
    my $max = GetDeciphScore(\@order_c, \@order_p, $counts_c, $counts_p);
    
    # Make swaps in the plaintext order
    #my $local_iters = $iterations ? $iterations : 10*@order_p;
    my $local_iters = $iterations ? $iterations : $factor*@order_p;
    for (1..$local_iters) {
      my $argmini;
      my $argminj;
      
      for (my $i = 0; $i < @order_p-1; $i++) {
        next if $order_p[$i] eq '_';
        for (my $j = $i+1; $j < @order_p; $j++) {
          next if $order_p[$j] eq '_';
          my @order_p_swap = @order_p;        
          ($order_p_swap[$i],$order_p_swap[$j]) = ($order_p_swap[$j],$order_p_swap[$i]);        
          my $swap_score = GetDeciphScore(\@order_c, \@order_p_swap, $counts_c, $counts_p);
          
          if ($swap_score > $max) {
            $max = $swap_score;
            $argmini = $i;
            $argminj = $j;
            die if $max > 0;
          }
        }
      }
      
      last unless defined($argmini) && defined($argminj);
      ($order_p[$argmini],$order_p[$argminj]) = ($order_p[$argminj],$order_p[$argmini]);
    }
    if ($max > $best_max) {
      $best_max = $max;
      @best_order_p = @order_p
    }
  }
  @order_p = @best_order_p;
  
  #print "\n>>> @order_c\n>>> @order_p\n>>> $max\n\n";
  my %key = ();
  for (my $i = 0; $i < @order_c; $i++) {
    $key{$order_c[$i]} = $order_p[$i];
  }
  return (\%key,$best_max);
}


sub SwapDeciphRedux {
  my ($counts_c, $counts_p, $restarts, $skip_heuristic) = @_;
  $restarts = 0 unless $restarts;
  my @order_c = sort {$counts_c->[1]{$b} <=> $counts_c->[1]{$a}} keys(%{$counts_c->[1]});
  for (my $i = 0; $i < @order_c; $i++) {
    if ($order_c[$i] eq '_' || $order_c[$i] =~ /\s/ || $order_c[$i] eq '‐') {
      splice(@order_c, $i, 1);
    }
  }
  my @order_p = sort {$counts_p->[1]{$b} <=> $counts_p->[1]{$a}} keys(%{$counts_p->[1]});
  for (my $i = 0; $i < @order_p; $i++) {
    if ($order_p[$i] eq '_' || $order_p[$i] =~ /\s/ || $order_p[$i] eq '‐') {
      splice(@order_p, $i, 1);
    }
  }
  
  my $min_alph_size = @order_c <= @order_p ? scalar(@order_c) : scalar(@order_p);
  if ($skip_heuristic && abs(scalar(@order_c) - scalar(@order_p)) > $min_alph_size) {
    # Fail.
    return ({},-inf);
  }
  
  if (@order_p < @order_c) {
    $counts_p->[1]{'-'} = 1;
    $counts_p->[0]++;
  }
  while (@order_p < @order_c) {
    push @order_p, '-';    
  }
  
  # Get current key.
  my %key = ('_' => '_');
  for (my $i = 0; $i < @order_c; $i++) {
    $key{$order_c[$i]} = $order_p[$i];
  }

  # Evaluate the key.
  my %bestkey = %key;
  my $bestscore = GetDeciphScoreKey(\%bestkey, $counts_c, $counts_p);

  # Perform an initial run and random restarts.
  foreach my $iter (0..$restarts) {
    if ($iter > 0) {
      @order_p = Scramble(@order_p);
    }
        
    # Initialize the key we will optimize this iteration.
    my %iterkey = ('_' => '_');
    for (my $i = 0; $i < @order_c; $i++) {
      $iterkey{$order_c[$i]} = $order_p[$i];
    }
    my $iterscore = GetDeciphScoreKey(\%iterkey, $counts_c, $counts_p);
    
    # Take some number of steps "uphill".
    foreach my $step (1..(10*@order_p)) {
      print ">>>>$iter:$step\n";
      print ">>>>Current key ($iterscore): ";
      foreach my $k (sort keys %iterkey) {
        print "($k => $iterkey{$k}),";
      }
      print "\n";
        
      # Make the needed swaps.
      my %bestnewkey = ();
      my $bestnewscore = -inf;
      foreach my $c1 (@order_c) {
        foreach my $c2 (@order_c) {
          next if $c2 eq '_';
          next if $c1 eq $c2;
          my %newkey = %iterkey;
          ($newkey{$c1},$newkey{$c2}) = ($newkey{$c2},$newkey{$c1});
          my $newscore = GetDeciphScoreKey(\%newkey, $counts_c, $counts_p);
          if ($newscore > $bestnewscore) {
            %bestnewkey = %newkey;
            $bestnewscore = $newscore;
          }
        }
      }
      
      # Choose which step to take, and set up for the next iteration.
      if ($bestnewscore > $iterscore) {
        %iterkey = %bestnewkey;
        $iterscore = $bestnewscore;
      }
      else {
        last;
      }
    } # end of step
    
    if ($iterscore > $bestscore) {
      %bestkey = %iterkey;
      $bestscore = $iterscore;
    }
  } # end of iteration  
  
  return (\%bestkey,$bestscore);
}



sub OracleDeciph {
  my ($counts_c, $counts_p, $restarts, $skip_heuristic) = @_;
  $restarts = 0 unless $restarts;
  my @order_c = sort {$counts_c->[1]{$b} <=> $counts_c->[1]{$a}} keys(%{$counts_c->[1]});
  for (my $i = 0; $i < @order_c; $i++) {
    if ($order_c[$i] eq '_' || $order_c[$i] =~ /\s/ || $order_c[$i] eq '‐') {
      splice(@order_c, $i, 1);
    }
  }
  my $oracle_score = GetDeciphScore(\@order_c, \@order_c, $counts_c, $counts_p);
    
  my %key = ();
  for (my $i = 0; $i < @order_c; $i++) {
    $key{$order_c[$i]} = $order_c[$i];
  }
  return (\%key,$oracle_score);
}



sub Scramble {
  my @l = @_;
  for (my $i = 0; $i < @l; $i++) {
    my $j = int(rand(@l)); 
    ($l[$i], $l[$j]) = ($l[$j], $l[$i]);
  }
  for (my $i = 0; $i < @l; $i++) {
    my $j = int(rand(@l)); 
    ($l[$i], $l[$j]) = ($l[$j], $l[$i]);
  }
  for (my $i = 0; $i < @l; $i++) {
    my $j = int(rand(@l)); 
    ($l[$i], $l[$j]) = ($l[$j], $l[$i]);
  }
  return @l;
}


sub GetDeciphScore {
  my ($order_c, $order_p, $counts_c, $counts_p) = @_;
  my %key = ('_' => '_');
  for (my $i = 0; $i < @$order_c; $i++) {
    $key{$order_c->[$i]} = $order_p->[$i];
  }
  my $prob = 0;
  foreach my $c1 (sort keys(%{$counts_c->[2]})) {
    foreach my $c2 (sort keys(%{$counts_c->[2]{$c1}})) {
      if (!$key{$c1} || !$key{$c2}) {
        #print "|$c1|$c2|\n";
        next;
      }
      no warnings 'uninitialized';
      if (!$counts_p->[1]{$key{$c1}}) {
        #print "***$c1,$key{$c1}***\n";
        $counts_p->[1]{$key{$c1}} = 1;
      }
      if (!$counts_p->[1]{$key{$c2}}) {
        $counts_p->[1]{$key{$c2}} = 1;
      }
      my $logprob = log(0.999 *
                        $counts_p->[2]{$key{$c1}}{$key{$c2}} / 
                        $counts_p->[1]{$key{$c1}}
                        +
                        0.001 *
                        $counts_p->[1]{$key{$c2}} /
                        $counts_p->[0]
                       );                        
      $prob += $logprob * $counts_c->[2]{$c1}{$c2};      
    }
  }
  #print "@$order_c\n@$order_p\n$prob\n\n";
  return $prob;
}





sub GetDeciphScoreP {
  my ($deciph, $counts_p) = @_;
  my $prob = 0;
  for (my $i = 1; $i < length($deciph); $i++) {
    my $p2 = substr($deciph,$i,1);
    my $p1 = substr($deciph,$i-1,1);
    no warnings 'uninitialized';
    if (!$counts_p->[1]{$p1}) {
      #print "***$p1***\n";
      next;
    }
    if (!$counts_p->[1]{$p2}) {
      $counts_p->[1]{$p2} = 1;
    }
    my $logprob = log(0.999 *
                      $counts_p->[2]{$p1}{$p2} / 
                      $counts_p->[1]{$p1}
                      +
                      0.001 *
                      $counts_p->[1]{$p2} /
                      $counts_p->[0]
                     );                        
    $prob += $logprob;      
  }
  return $prob;
}


sub GetBigramCountsFromFile {
  my ($file,$clean) = @_;
  my @counts = (0,{},{});
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  binmode FILE, ':utf8';
  while (<FILE>) {
    chomp;
    my $line = $clean->($_);
    next unless $line;
    my @chars = split //, $line;
    no warnings 'uninitialized';
    $counts[0]++;
    $counts[1]->{$chars[0]}++;
    for (my $i = 1; $i < @chars; $i++) {
      $counts[0]++;
      $counts[1]->{$chars[$i]}++;
      $counts[2]->{$chars[$i-1]}{$chars[$i]}++;
    }
  }
  close FILE || die $!;
  return @counts;
}


sub GetBigramCountsFromString {
  my ($str,$clean) = @_;
  my @counts = (0,{},{});
  $str = $clean->($str);
  next unless $str;
  my @chars = split //, $str;
  no warnings 'uninitialized';
  $counts[0]++;
  $counts[1]->{$chars[0]}++;
  for (my $i = 1; $i < @chars; $i++) {
    $counts[0]++;
    $counts[1]->{$chars[$i]}++;
    $counts[2]->{$chars[$i-1]}{$chars[$i]}++;
  }
  return @counts;
}


sub GetBigramCountsFromFileWithBoundaries {
  my ($file,$clean) = @_;
  my @counts = (0,{},{});
  open FILE, '< :encoding(UTF-8)', $file || die $!;
  binmode FILE, ':utf8';
  while (<FILE>) {
    chomp;
    my $line = $clean->($_);
    next unless $line;
    my @chars = split //, $line;
    no warnings 'uninitialized';
    $counts[0]++;
    $counts[1]->{'<s>'}++;
    $counts[0]++;
    $counts[1]->{$chars[0]}++;
    $counts[2]->{$chars[0]}{'<s>'}++;
    for (my $i = 1; $i < @chars; $i++) {
      $counts[0]++;
      $counts[1]->{$chars[$i]}++;
      $counts[2]->{$chars[$i-1]}{$chars[$i]}++;
    }
    $counts[0]++;
    $counts[1]->{'<\s>'}++;
    $counts[2]->{'<\s>'}{$chars[-1]}++;
  }
  close FILE || die $!;
  return @counts;
}


sub GetBigramCountsFromStringWithBoundaries {
  my ($str,$clean) = @_;
  my @counts = (0,{},{});
  $str = $clean->($str);
  next unless $str;
  my @chars = split //, $str;
  no warnings 'uninitialized';
  $counts[0]++;
  $counts[1]->{'<s>'}++;
  $counts[0]++;
  $counts[1]->{$chars[0]}++;
  $counts[2]->{$chars[0]}{'<s>'}++;
  for (my $i = 1; $i < @chars; $i++) {
    $counts[0]++;
    $counts[1]->{$chars[$i]}++;
    $counts[2]->{$chars[$i-1]}{$chars[$i]}++;
  }
  $counts[0]++;
  $counts[1]->{'<\s>'}++;
  $counts[2]->{'<\s>'}{$chars[-1]}++;
  return @counts;
}

1;
