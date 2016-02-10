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
use Time::HiRes qw( clock );
use Getopt::Long;
use ProbDist;


binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

$| = 1;

my $ctext = '';
my $ptext = '';
my $distrib   = 'unigram';
my $special = 0;
my $specialptext = 0;
my $threshold = 0;
my $jaskiewicz = 0;
my $oldfiles = 0;
my $dslcc = 0;
my $verbose = 0;
my $flex = 0;

GetOptions(
  'c=s' => \$ctext,
  'p=s' => \$ptext,
  'd=s' => \$distrib,
  's'   => \$special,
  'r'   => \$specialptext,
  't=i' => \$threshold,
  'j'   => \$jaskiewicz,
  'o'   => \$oldfiles,
  'dsl' => \$dslcc,
  'v'   => \$verbose,
  'f'   => \$flex,
);

die "Need ctext and ptext files!" unless $ctext && $ptext;

# Make lists of ctext and ptext files.
my @ctexts = glob "$ctext";
my @ptexts = glob "$ptext";

# Allow special characters?
my $remove_ptext = '[\^\,\.\'\"\;\:\-\(\)\!\[\]\<\>\?\&\#\‐1234567890\*\\\]';
my $remove_ctext = $remove_ptext;
$remove_ptext = '' if $specialptext;
$remove_ctext = '' if $special;

# Evaluation totals.
my $total = 0;
my $correct = 0;
my $mean_recip_rank = 0;

print "Starting language identification.\n";
print "Ciphertext file(s): $ctext (@ctexts)\n\n";
print "Plaintext file(s): $ptext (@ptexts)\n\n";
print "Distribution: $distrib\n";
print "DSLCC files? $dslcc\n";
print "\n---\n\n";


# Hash of lists of previously computed distributions.
# Format $repchar_mem->{FILE}[MAXLEN] == [NEWMAXLEN,DISTRIBUTION]
my %dist_mem = ();

my $time_start = clock();
foreach my $file (@ctexts) {
  if ($distrib eq 'unigram') {
    my $dist = ProbDist::unigram($file,$remove_ctext);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'typeunigram') {
    my $dist = ProbDist::unigramwordtype($file,$remove_ctext);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'length') {
    my $dist = ProbDist::wordlength($file,$remove_ctext,$threshold);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'typelength') {
    my $dist = ProbDist::wordtypelength($file,$remove_ctext,$threshold);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'pattern') {
    my $dist = ProbDist::wordpattern($file,$remove_ctext,$threshold);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'typepattern') {
    my $dist = ProbDist::wordtypepattern($file,$remove_ctext);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'p-equiv') {
    my $dist = ProbDist::orderedwordpattern($file,$remove_ctext);
    $dist_mem{$file} = $dist;
  }
  else {
    die "Invalid distribution specification.\n";
  }
}
foreach my $file (@ptexts) {
  if ($distrib eq 'unigram') {
    my $dist = ProbDist::unigram($file,$remove_ptext);
    $dist_mem{$file} = $dist;
  } 
  elsif ($distrib eq 'typeunigram') {
    my $dist = ProbDist::unigramwordtype($file,$remove_ptext);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'length') {
    my $dist = ProbDist::wordlength($file,$remove_ptext,$threshold);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'typelength') {
    my $dist = ProbDist::wordtypelength($file,$remove_ptext,$threshold);
    $dist_mem{$file} = $dist;
  } 
  elsif ($distrib eq 'pattern') {
    my $dist = ProbDist::wordpattern($file,$remove_ptext,$threshold);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'typepattern') {
    my $dist = ProbDist::wordtypepattern($file,$remove_ptext);
    $dist_mem{$file} = $dist;
  }
  elsif ($distrib eq 'p-equiv') {
    my $dist = ProbDist::orderedwordpattern($file,$remove_ptext);
    $dist_mem{$file} = $dist;
  }
  else {
    die "Invalid distribution specification.\n";
  }
}


foreach my $ctext_file (@ctexts) {
  # Language stored in file name for evaluation purposes.
  my $clang = 'UNK';
  if ($dslcc) {
    if ($ctext_file =~ /(..)$/) {$clang = $1;}
  }
  elsif (!$oldfiles && $ctext_file =~ /udhr-([^\/]+)\.txt.*/) {
    $clang = $1;
  }
  elsif ($ctext_file =~ /output_(.+)\.txt/) {
    $clang = $1;
  }
  elsif ($ctext_file =~ /wikipedia_data3\/(..)\./) {
    print "$ctext_file\t";
    my $l = $1;
    $clang = 'bul' if $l eq 'bg';
    $clang = 'deu' if $l eq 'de';
    $clang = 'ell' if $l eq 'el';
    $clang = 'eng' if $l eq 'en';
    $clang = 'spa' if $l eq 'es';
  }
  else {
    $clang = $ctext_file;
  }
  
  # These variables store the nearest distribution, and its distance.
  my $min = 'inf';
  my $argmin = '';
  
  # Keep track of the score each ptext language gets.
  my %ptext_score = ();
  
  # Compare each plaintext to the ciphertext.
  foreach my $ptext_file (@ptexts) {
  
    # Language stored in file name for identification purposes.
    my $plang = 'UNK';
    if ($dslcc) {
      if ($ptext_file =~ /(..)$/) {$plang = $1;}
    }
    elsif (!$oldfiles && $ptext_file =~ /udhr-([^\/]+)\.txt.*/) {
      $plang = $1;
    }
    elsif ($ptext_file =~ /output_(.+)\.txt/) {
      $plang = $1;
    }
    else {
      $plang = $ptext_file;
    }
    
    # Measure distance between distributions.
    my $distance;
    if (ref($dist_mem{$ctext_file}) eq 'ARRAY') {
      if (!$jaskiewicz) {
       $distance = ProbDist::bhattacharyya_dist($dist_mem{$ctext_file}, $dist_mem{$ptext_file});
      } else {
       $distance = ProbDist::jaskiewicz_dist($dist_mem{$ctext_file}, $dist_mem{$ptext_file});
      }
    }
    elsif (ref($dist_mem{$ctext_file}) eq 'HASH') {
      if (!$jaskiewicz) {
       $distance = ProbDist::bhattacharyya_dist_hash($dist_mem{$ctext_file}, $dist_mem{$ptext_file});
      } else {
       $distance = ProbDist::jaskiewicz_dist_hash($dist_mem{$ctext_file}, $dist_mem{$ptext_file});
      }
    }
    $ptext_score{$plang} = $distance;
    
    # Report.
    printf("%1.4f\t$ctext_file\t$ptext_file\n", $distance) if $verbose;
    
    # Compare distance.
    if ($distance < $min) {
      $min = $distance;
      $argmin = $plang;
    }    
  }
  
  # Evaluate and report.
  $total++;
  if ($clang eq $argmin) {
    $correct++;
  }
  elsif ($flex && ( substr($clang,0,3) eq substr($argmin,0,3) )) {
    $correct++;
    $clang = $argmin;
  }
  my @ptexts_by_score = sort {$ptext_score{$a} <=> $ptext_score{$b}} keys %ptext_score;
  my $rank = scalar(@ptexts_by_score);
  my $rankstring = '';
  for (my $i = 0; $i < @ptexts_by_score; $i++) {
    my $j = $i+1;
    $rankstring .= "\tRANK $j:\t$ptexts_by_score[$i]\t$ptext_score{$ptexts_by_score[$i]}\n";
    if ($ptexts_by_score[$i] eq $clang || ($flex && ( substr($clang,0,3) eq substr($ptexts_by_score[$i],0,3) ))) {
      $rank = $i+1;
      last;
    }
  }
  printf "RESULT:\t%s\t%s\t%1.4f\t%d\t%d\t%1.4f\n",
    $clang, $argmin, $min, $clang eq $argmin, $rank, 1/$rank;
  print "$rankstring";
  $mean_recip_rank += 1/$rank;
}
my $time_end = clock();

printf "\nCIPHERS: %d\tCORRECT: %d\tACCURACY: %1.4f\tMEAN RECIPROCAL RANK: %1.4f\tMEAN CPU TIME: %1.4f\n", $total, $correct, $correct/$total, $mean_recip_rank/$total, ,($time_end-$time_start)/$total;


