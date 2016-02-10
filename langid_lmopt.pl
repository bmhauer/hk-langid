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
use SwapDeciph;

srand(19901020);

binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

$| = 1;

my $ctext = '';
my $ptext = '';
my $report = 0;
my $restarts = 0;
my $oldfiles = 0;
my $dslcc = 0;
my $special = 0;
my $noskip = 0;
my $oracle = 0;
my $iterations = 0;
my $factor = 10;
my $best_ngrams = 0;

GetOptions(
  'c=s'    => \$ctext,
  'p=s'    => \$ptext,
  'r=i'    => \$restarts,
  'o'      => \$oldfiles,
  'dsl'    => \$dslcc,
  's'      => \$special,
  'n'      => \$noskip,
  'oracle' => \$oracle,
  'i'      => \$iterations,
  'f=i'      => \$factor,
  'b=i'      => \$best_ngrams,
);

# Make lists of ctext and ptext files.
my @ctexts = glob "$ctext";
my @ptexts = glob "$ptext";

# Evaluation totals.
my $total = 0;
my $correct = 0;
my $mean_recip_rank = 0;
my $total_cpu_time = 0;

print "Starting language identification (program version: 15-07-03).\n";
print "Restarts: $restarts\n";
print "Greedy search iterations constant: $iterations\n";
print "Greedy search iterations factor: $factor\n";
print "Limit swaps to best ngrams: $best_ngrams\n";
print "Old files: $oldfiles\n";
print "Special: $special\n";
print "DSLCC files? $dslcc\n";
print "Decipherment oracle online? $oracle\n";
print "Ciphertext file(s): $ctext (@ctexts)\n\n";
print "Plaintext file(s): $ptext (@ptexts)\n\n";
print "\n---\n\n";

# Get counts from each file.
my %ctext_counts = ();
foreach my $file (@ctexts) {
  my @counts_c;
  if ($special) {
    @counts_c = SwapDeciph::GetBigramCountsFromFile(
      $file,\&LineProc::Underscore);
  }
  else {
    @counts_c = SwapDeciph::GetBigramCountsFromFile(
      $file,\&LineProc::LowercaseUnderscoreAndAlpha);
  }
  $ctext_counts{$file} = \@counts_c;
} 
my %ptext_counts = ();
foreach my $file (@ptexts) {
  my @counts_p = 
    SwapDeciph::GetBigramCountsFromFile($file,\&LineProc::LowercaseUnderscoreAndAlpha);
  $ptext_counts{$file} = \@counts_p;
} 



# Process each ctext file.
foreach my $ctext_file (@ctexts) {
  my $time_ctext_start = clock();
  print ">START CTEXT: $ctext_file\t",`date`;

  # Language stored in file name for evaluation purposes.
  my $clang = 'UNK';
  if ($dslcc) {
    if ($ctext_file =~ /(..)$/) {$clang = $1;}
  }
  elsif (!$oldfiles) {
    if ($ctext_file =~ /udhr-([^\/]+)\.txt.*/) {$clang = $1;}
  }
  else {
    if ($ctext_file =~ /output_(.+)\.txt/) {$clang = $1;}
  }
  
  # Keep track of the best language.
  my $max = -inf;
  my $argmin = '';
  my $iter = -1;
  
  # Keep track of the score each ptext language gets.
  my %ptext_score = ();
  
  # Compare each plaintext to the ciphertext.
  foreach my $ptext_file (@ptexts) {
    my $t = `date`;
    chomp($t);
    print ">START PTEXT: '$ptext_file' at $t\t";
  
    # Language stored in file name for identification purposes.
    my $plang = 'UNK';
    if ($dslcc) {
      if ($ptext_file =~ /(..)$/) {$plang = $1;}
    }
    elsif (!$oldfiles) {
      if ($ptext_file =~ /udhr-([^\/]+)\.txt.*/) {$plang = $1;}
    }
    else {
      if ($ptext_file =~ /output_(.+)\.txt/) {$plang = $1;}
    }

    # Decipher.
    my $time_ptext_start = clock();
    my ($key,$score,$bestiter);
    
    if ($oracle) {
      ($key,$score) = SwapDeciph::OracleDeciph(
        $ctext_counts{$ctext_file},$ptext_counts{$ptext_file},$restarts,1-$noskip,$iterations,$factor);
    }
    #elsif ($best_ngrams) {
    else {
      ($key,$score,$bestiter) = SwapDeciph::TopSwapDeciph(
        $ctext_counts{$ctext_file},$ptext_counts{$ptext_file},
        $restarts,1-$noskip,$iterations,$factor,$best_ngrams);
    }
    #else {
    #  ($key,$score) = SwapDeciph::SwapDeciph(
    #    $ctext_counts{$ctext_file},$ptext_counts{$ptext_file},$restarts,1-$noskip,$iterations,$factor);
    #}
    if ($score > 0) {
      # Something went wrong...
      print "x\n";
      print ">>> Got a score of $score... that shouldn't be possible.\n";
      next;
    }
    
    if (!$noskip && $score == -inf && scalar(keys(%$key)) == 0) {
      print "\n>>> Skipping $ptext_file due to extreme alphabet size mismatch.\n";
      next;
    }
    $ptext_score{$plang} = $score;
    my $time_ptext_end = clock();    
    printf "%1.4f\t", $time_ptext_end-$time_ptext_start;
    
    # Compare score.
    print "$score";
    if ($score > $max) {
      print "\t*";
      $max = $score;
      $argmin = $plang;
      $iter = $bestiter;
    }
    print "\n";
  }  
  my $time_ctext_end = clock();
  
  # Evaluate and report.
  $total++;
  if ($clang eq $argmin) {
    $correct++;
  }
  my @ptexts_by_score = sort {$ptext_score{$b} <=> $ptext_score{$a}} keys %ptext_score;
  my $rank = scalar(@ptexts);
  for (my $i = 0; $i < @ptexts_by_score; $i++) {
    if ($ptexts_by_score[$i] eq $clang) {
      $rank = $i+1;
      last;
    }
  }
  $total_cpu_time += $time_ctext_end-$time_ctext_start;
  printf "RESULT:\t%s\t%s\t%1.4f\t%d\t%d\t%1.4f\t%1.4f\t$iter\n",
    $clang, $argmin, $max, $clang eq $argmin, $rank, 1/$rank, $time_ctext_end-$time_ctext_start;
  $mean_recip_rank += 1/$rank;
}

# Report evaluation results.
unless ($report || !$total) {
  printf "\nCIPHERS: %d\tCORRECT: %d\tACCURACY: %1.4f\tMEAN RECIPROCAL RANK: %1.4f\tMEAN CPU TIME: %1.4f\n", 
    $total, $correct, $correct/$total, $mean_recip_rank/$total, $total_cpu_time/$total;
}
