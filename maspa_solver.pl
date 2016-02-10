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
#use lib '../Modules';
use Getopt::Long;
use Time::HiRes qw( clock );
use sort 'stable';
no warnings 'recursion';
use open qw/:std :utf8/;

use ReadLM;
use JMSmoothing;
use FreqAnalysis;
#use PScore;
use Utils;
#use NoSpace;

binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

# Record current time.
my $start = time();
my $cpu_start = clock();

# Configure output for no delay (just in case).
$| = 1;

# Fix Trigram LMs
my $ngramorder = 3;

# Get options.
my $configfile = 'preproc2.en.config';
my $nospace = 0;
my $verbose = 0;
my $maxit = 10;
my $beamsize = 10;
my $patternlimit = 20;

GetOptions(
  "c=s" => \$configfile,
#  "n"   => \$nospace,
  "v"   => \$verbose,
  "m=i" => \$maxit,
  "b=i" => \$beamsize,
  "p=i" => \$patternlimit,
);


# Read the config file.
my ($wordlm1_file, $wordlm2_file, $wordlm3_file);
my ($charlm1_file, $charlm2_file, $charlm3_file); 
my ($wl1, $wl2, $wl3);
my ($cl1, $cl2, $cl3);
my $x; # Character lm coefficient.
my $ngramlist;
my $order;

open CONFIG, '<', $configfile || die $!;
my $cfgcount = 0; # Keep track of how many lines the cfg file contains.
while (<CONFIG>) {
  chomp;
  my ($var,$val) = split /\t+/;
  next unless $var && defined($val);
  #print "$var\n";
  
     if ($var eq 'wordlm1')   {$wordlm1_file = $val; $cfgcount++} #1
  elsif ($var eq 'wordlm2')   {$wordlm2_file = $val; $cfgcount++} #2
  elsif ($var eq 'wordlm3')   {$wordlm3_file = $val; $cfgcount++} #3
  elsif ($var eq 'charlm1')   {$charlm1_file = $val; $cfgcount++} #4
  elsif ($var eq 'charlm2')   {$charlm2_file = $val; $cfgcount++} #5
  elsif ($var eq 'charlm3')   {$charlm3_file = $val; $cfgcount++} #6
  elsif ($var eq 'wlambda1')  {$wl1 = $val; $cfgcount++} #7
  elsif ($var eq 'wlambda2')  {$wl2 = $val; $cfgcount++} #8
  elsif ($var eq 'wlambda3')  {$wl3 = $val; $cfgcount++} #9
  elsif ($var eq 'clambda1')  {$cl1 = $val; $cfgcount++} #10
  elsif ($var eq 'clambda2')  {$cl2 = $val; $cfgcount++} #11
  elsif ($var eq 'clambda3')  {$cl3 = $val; $cfgcount++} #12
  elsif ($var eq 'charcoeff') {$x = $val; $cfgcount++} #13
  elsif ($var eq 'ngramlist') {$ngramlist = $val; $cfgcount++} #14
  elsif ($var eq 'order')     {$order = $val; $cfgcount++} #15
}
close CONFIG || die $!;
if ($cfgcount < 15) {
  # Something was missing...
  die "Deficient config file -- only $cfgcount lines read.\n";
}


Message("Starting run at", `date`);
Message(
  "\nCharacter LMs: $charlm1_file, $charlm2_file, $charlm3_file",
  "\nWord      LMs: $wordlm1_file, $wordlm2_file, $wordlm3_file",
  "\nCharacter LM coefficinet: $x",
  "\nnglist\t$ngramlist",
  
  #"\nCiphers without spaces: $nospace",
  "\nMaximum iterations: $maxit",
  "\nMaximum beam size: $beamsize",
  "\nN-grams per pattern: $patternlimit",
  "\n",
);


# Declare cipher and plaintext alphabets...
Message("Starting up...");
my @P = split(/\s+/, $order);
my @C;
my $symcount_ptext = {};
for (my $i = 0; $i < @P; $i++) {
  $symcount_ptext->{$P[$i]} = scalar(@P)-$i;
}

# Read Language Models:
Message("Reading language models.");
my $charlm1 = {};
ReadLM::ReadUnigramLM($charlm1_file, $charlm1);
my $charlm2 = {};
ReadLM::ReadBigramLM($charlm2_file, $charlm2);
my $charlm3 = {};
ReadLM::ReadTrigramLM($charlm3_file, $charlm3);
my $wordlm1 = {};
ReadLM::ReadUnigramLM($wordlm1_file, $wordlm1);
my $wordlm2 = {};
ReadLM::ReadBigramLM($wordlm2_file, $wordlm2) unless $wordlm2_file eq 'NULL';
my $wordlm3 = {};
ReadLM::ReadTrigramLM($wordlm3_file, $wordlm3) unless $wordlm3_file eq 'NULL';

# Read ngram list
Message("Processing n-gram list.");
my $grams_with_pattern = [0,{},{},{}];
my $is_word = {};
my $maxlen = 0;
Utils::ReadPList($ngramlist,$grams_with_pattern,$is_word,\$maxlen,$nospace);

# Ready to go!
my $memory = {};

# Record current time.
Message("Ready to go! Timer resetting.");
$start = time();
$cpu_start = clock();
my $global_iteration_count;

while (<>) {
  chomp;
  my $ctext = $_;
  Message("Solving [$ctext].");
  my $solution;
  
  # Find the ciphertext's repetition pattern.
  my $charpattern = Utils::APattern_wlpc($ctext);
  Message("Ciphertext has character A-Pattern [$charpattern]");
  
  my $input_score = JMSmoothing::ProbCharWord(
      $charpattern, $charlm1, $charlm2, $charlm3, $wordlm1, $wordlm2, $wordlm3,
      $cl1, $cl2, $cl3, $wl1, $wl2, $wl3, $x
    );
  #print "INPUT SCORE: $input_score\n";
  
  my $p = Utils::Pattern($charpattern);
  Message("Ciphertext has general A-Pattern [$p]");  
  if ($memory->{$p}) {
    # Seen this pattern before, we already have a solution.
    Message("Solved from memory.");
    $solution = $memory->{$p};
  } else {
    # A new pattern, let's solve it! 
       
    # Get an initial key.
    @C = FreqAnalysis::GetSortedAlphabet(\$p);
    Message("Alphabets: P[@P] C[@C]\n");
    my $root = FreqAnalysis::GetFreqKey(\@P, \@C);
    
    # Tell the user what the initaial key is.
    Utils::PrintKey($root,\@C) if $verbose;
    
    # Now run Beam Search!
    my $key = BeamSearch($p, $root, $maxit, $beamsize, $ngramorder); # Get key
    
    # Tell the user what the initaial key is.
    Utils::PrintKey($key,\@C) if $verbose;
    
    $solution = Utils::Decipher($p,$key, @C); # Get solution
    $memory->{$p} = $solution; # Store solution
  }
  
  Message("Done!");
  
  # Cipher solved (we hope).
  print $verbose ? "SOLUTION:\t$solution\n" : "$solution\n";  
}


sub BeamSearch {
  my ($ctext, $root, $maxit, $beamsize, $n) = @_;
  my $best = $root;
  my @beam = ($root);
  my %score = ();
  $score{$root} = -inf; 
  
  Message("Starting search...");
  
  # Count the frequencies of individual characters.
  my $symcount = {};
  Utils::SymbolCounts($symcount,$ctext);
  
  # Search for $maxit iterations...
  Message("Ready to search!");
  for (my $i = 1; $i <= $maxit; $i++) {
    $global_iteration_count = $i;
    last if @beam == 0;
    Message("Iteration $i starting.");
    my @newbeam = GetNewBeam($ctext, $beamsize, \%score, $n, \$best, $symcount, @beam);
    @beam = @newbeam;
    Message("Iteration $i complete.");
  }  
  
  return $best;
}


sub GetNewBeam {
  my ($ctext, $beamsize, $score, $n, $best, $symcount_ctext, @oldbeam) = @_;
  my @newbeam = ();
  my %seen = ();
  my $bestdec = Utils::Decipher($ctext,$$best, @C);
  
  # Gather new keys and their respective decipherments.
  # The structure of %newkeyhash is a bit confusing:
  #   keys are decipherments of the ctext
  #   values are the decipherment keys that generate them
  my %newkeyhash = ();
  foreach my $key (@oldbeam) {
    # Expand each key in the beam.
    if (!$nospace) {
      GetSuccessors($ctext,$key,\%newkeyhash,$n,$score,\%seen,$symcount_ctext);
    } else {
      GetSuccessorsNoSpace($ctext,$key,\%newkeyhash,$n,$score,\%seen);
    }
  }
  
  # Now that we've collected the new keys, let's score them.
  my %newdeciphermentscores = ();
  foreach my $dtext (sort keys %newkeyhash) {
    $newdeciphermentscores{$dtext} = JMSmoothing::ProbCharWord(
      $dtext, $charlm1, $charlm2, $charlm3, $wordlm1, $wordlm2, $wordlm3,
      $cl1, $cl2, $cl3, $wl1, $wl2, $wl3, $x
    )
  }
  #PScore::PScoreBatch([keys(%newkeyhash)],\%newdeciphermentscores,$P,$x,$wordlmlm, $charlmlm, $nospace);
  
  # Now processes the data.
  foreach my $d (sort keys %newkeyhash) {
    my $newdeciph = $d;
    my $new_key = $newkeyhash{$newdeciph};
    my $new_score = $newdeciphermentscores{$newdeciph};
    die "Error 4! No deciph" unless $newdeciph;
    die "Error 4! [$newdeciph], No new key" unless $new_key;
    die "Error 4! [$newdeciph], No score" unless $new_score;
    $score->{$new_key} = $new_score;
    die "Error 5! (this shouldn't be possible) [$$best]" unless $score->{$$best};
    
    if ($score->{$new_key} > $score->{$$best}) {
    #if ( Utils::BetterThan($newdeciph,$bestdec,$new_key,$$best,$is_word,$score) ) {
      $$best = $new_key;
      $bestdec = $newdeciph;
      Message("Best guess: ($bestdec) ($score->{$new_key})");
    }
    
    Insert($new_key, $score, \@newbeam);
    while (@newbeam > $beamsize) {
      pop @newbeam;
    }       
  }
  
  return @newbeam;
}


sub GetSuccessors {
  my ($ctext, $key, $newkeyhash, $n, $score, $seen, $symcount_ctext) = @_;

  # decipher
  my $dtext = Utils::Decipher($ctext,$key, @C); 
  my @cwords = split /\s+/, $ctext;
  my @dwords = split /\s+/, $dtext;
  
  # Go through all ngram orders.
  for (my $k = 1; $k <= $n && $k <= @cwords; $k++) {
    my $m = $k-1;
    
    # Check all k-grams
    foreach (my $i = $m; $i < @cwords; $i++) {
      my $cw = join(' ', @cwords[$i-$m .. $i]);
      my $dw = join(' ', @dwords[$i-$m .. $i]);
      
      my $pattern_cw = Utils::APattern($cw);
      my $pattern_cw_pc = Utils::APattern_pc($cw);
      next unless $grams_with_pattern->[$k]->{$pattern_cw};
      
      my @sorted;
      
      if ($global_iteration_count <= ($maxit/2)) {
        #Message("Candidates chosen by score alone.");
        @sorted = @{$grams_with_pattern->[$k]->{$pattern_cw}};
      }
      else {
        #Message("Candidates chosen by score and similarity.");
        my %simhash = ();
        foreach (@{$grams_with_pattern->[$k]->{$pattern_cw}}) {
          $simhash{$_} = Utils::SimAlph($_,$dw)
        }
        @sorted = sort {$simhash{$b} <=> $simhash{$a}}
                    @{$grams_with_pattern->[$k]->{$pattern_cw}};
      }
      
      my @candidates;
      if (@sorted > $patternlimit) {
        @candidates = @sorted[0..($patternlimit-1)];
      } else {
        @candidates = @sorted;
      }
                       
   
      foreach my $match (@candidates) {
        next if $match eq $dw;
        
        #print "Suggest [$match] for [$cw] with pattern [$pattern_cw], currently [$dw]\n";
        
        # Propose a new key. 
        my $new_key = Assume($pattern_cw_pc, $match, $key, $symcount_ctext);
        next if $score->{$new_key};
        next if $seen->{"$new_key"};
        $seen->{"$new_key"} = 1;          
           
        my $newdeciph = Utils::Decipher($ctext,$new_key, @C);
        $newdeciph = Utils::APattern_wlpc($newdeciph);
        $newkeyhash->{$newdeciph} = $new_key;
        
        #print "Suggestion leads to '$newdeciph' ($new_key)\n";
        
      }
    }
  }
}


sub GetSuccessorsNoSpace {
  my ($ctext, $key, $newkeyhash,$n,$score,$seen) = @_;

  # decipher
  my $dtext = Utils::Decipher($ctext,$key, @C); 
  my @cwords = split /\s+/, $ctext;
  my @dwords = split /\s+/, $dtext;
  
  # All ngrams are of order 1.
  my $k = 1;
  my $m = 0;
  
  # Check all substrings
  for (my $sta = 0; $sta < length($ctext)-1; $sta++) {
    for (my $len = 2; ($len <= $maxlen) && ($len <= length($ctext)+$sta); $len++) {
      my $cw = substr($ctext,$sta,$len);
      my $dw = substr($dtext,$sta,$len);
      
      my $pattern_cw = Utils::APattern_wl($cw);
      next unless $grams_with_pattern->[$k]->{$pattern_cw};
      
      my %simhash = ();
      foreach (@{$grams_with_pattern->[$k]->{$pattern_cw}}) {
        $simhash{$_} = Utils::Sim($_,$dw)
      }
      
      my @sorted = sort {$simhash{$b} <=> $simhash{$a}}
                       @{$grams_with_pattern->[$k]->{$pattern_cw}};

      my @candidates;
      if (@sorted > $patternlimit) {
        @candidates = @sorted[0..($patternlimit-1)];
      } else {
        @candidates = @sorted;
      }
                       
   
      foreach my $match (@candidates) {
        next if $match eq $dw;
        
        # Propose a new key. 
        my $new_key = Assume($cw, $match, $key);
        next if $score->{$new_key};
        next if $seen->{"$new_key"};
        $seen->{"$new_key"} = 1;          
           
        my $newdeciph = NoSpace::FindWords(Utils::Decipher($ctext,$new_key, @C), $is_word, $maxlen);
        $newkeyhash->{$newdeciph} = $new_key
        
      }
    }
  }
}


sub Assume {
  my ($cw, $suggest, $key, $symcount_ctext) = @_;
  #print "\tA: [$cw] [$suggest] [$key]\n";
  
  my %encrypt = ();
  my %decrypt = ();
  for (0..(scalar(@C)-1)) {
    my $c = $C[$_];
    my $p = substr($key, $_, 1);
    $encrypt{$p} = $c;
    $decrypt{$c} = $p;
  }
  
  my @cw_words = split(/\s+/, $cw);
  my @dw_words = split(/\s+/, $suggest);
  my $numwords = scalar(@cw_words);
  die "Error 9\n" if @cw_words != @dw_words;
  
  my $symcount_cw = {};
  Utils::SymbolCounts($symcount_cw, $cw);
  my $symcount_dw = {};
  Utils::SymbolCounts($symcount_dw, $suggest);
  
  my @cw_sorted = keys (%$symcount_cw);
  @cw_sorted = sort {$symcount_ctext->{$b} <=> $symcount_ctext->{$a}} @cw_sorted;
  my @dw_sorted = keys (%$symcount_dw);
  @dw_sorted = sort {$symcount_ptext->{$b} <=> $symcount_ptext->{$a}} @dw_sorted;
  die "Error 10\n" if @cw_sorted != @dw_sorted;
  
  $symcount_cw = [];
  $symcount_dw = [];
  for (my $i = @cw_words-1; $i >= 0; $i--) {
    $symcount_cw->[$i] = {};
    $symcount_dw->[$i] = {};
    Utils::SymbolCounts($symcount_cw->[$i], $cw_words[$i]);
    Utils::SymbolCounts($symcount_dw->[$i], $dw_words[$i]);
    no warnings 'uninitialized';
    @cw_sorted = sort {$symcount_cw->[$i]{$b} <=> $symcount_cw->[$i]{$a}} @cw_sorted;
    @dw_sorted = sort {$symcount_dw->[$i]{$b} <=> $symcount_dw->[$i]{$a}} @dw_sorted;
  }
 
  for (my $i = 0; $i < @cw_sorted; $i++) {
    my $c1 = $cw_sorted[$i];
    my $p1 = $dw_sorted[$i];
    next if $c1 =~ /\s/;
    next if $p1 =~ /\s/;    
    next if $decrypt{$c1} eq $p1;
    
    # Want c1 to decipher as p1... what does c1 decipher as now?    
    my $p2 = $decrypt{$c1};
    die "Assumption error: $c1 not encrypted!\n" unless $p2;
    
    # And what, if anything, does p1 get enciphered as now?
    if ($encrypt{$p1}) {
      my $c2 = $encrypt{$p1};
      
      $decrypt{$c1} = $p1;
      $encrypt{$p1} = $c1;
      
      $decrypt{$c2} = $p2;
      $encrypt{$p2} = $c2;
    } else {
      # No; p1 was not encrypted before, p2 won't be now.
      $decrypt{$c1} = $p1;
      $encrypt{$p1} = $c1;
      
      delete($encrypt{$p2});
    }
  }
  
  # New guess at the encryption key.
  my $newkey = '';
  foreach my $l (@C) {
    $newkey .= $decrypt{$l};
  }
  
  return $newkey;
}


sub Insert {
  # Given $item and a score hash $score,
  # insert $item into the given pre-sorted $list
  # such that $list remains sorted.
  
  my ($item, $score, $list) = @_;
  
  for (my $i = 0; $i < @$list; $i++) {
    if ($score->{$item} > $score->{$list->[$i]}) {
      splice(@$list,$i,0,$item);
      return;
    }
  }
  
  push(@$list, $item);
  return;
}


sub Message {
  printf("%d / %.3f : %s\n", time() - $start, clock()-$cpu_start, "@_") if $verbose;
}
