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
use Getopt::Long;
#use lib './alphagram_solver';
use open qw/:std :utf8/;

use Viterbi;
use ReadLM;
use Utils;
use Alphagram;

binmode STDIN,  ':utf8';
binmode STDOUT, ':utf8';

STDOUT->autoflush(1);

my $testing_file = '';
my $training_file = @ARGV ? shift : 'preproc2.en';
my $devoweled = 0;

my $delint  = `cat $training_file.alp.delint`;
chomp($delint);
my $l3 = 0.4;
my $l2 = 0.3;
my $l1 = 0.3;
foreach my $line (split /\n+/, $delint) {
  if ($line =~ /^lambda 3:.*(\d\.\d+)$/) {$l3 = $1;}
  elsif ($line =~ /^lambda 2:.*(\d\.\d+)$/) {$l2 = $1;}
  elsif ($line =~ /^lambda 1:.*(\d\.\d+)$/) {$l1 = $1;}
}


######
# STEP 1: LOAD
######

#print ">>> Test file is $testing_file.\n";
#print ">>> Lambdas set to (3:$l3) (2:$l2) (1:$l1).\n";
#print ">>> Starting up... ";

# Read language models.
my $A1 = {};
ReadLM::ReadUnigramLM("$training_file.alp.unk.lm1", $A1);
my $A2 = {};
ReadLM::ReadBigramLM("$training_file.alp.unk.lm2", $A2);
my $A3 = {};
ReadLM::ReadTrigramLM("$training_file.alp.unk.lm3", $A3);

# Read emission potentials.
my $B = {};
Utils::ReadHashOfLists("$training_file.alp.unk.alp", $B);

# Set word list.
my $Q = [sort keys %{$A1}];

# Set up a word-to-number bijection.
my %w2n = ();
foreach my $i (0 .. scalar(@$Q)-1) {
  $w2n{$Q->[$i]} = $i;
}  

# Identify removed words.
my $one_counts = {};
Utils::ReadHash("$training_file.alp.1co", $one_counts);

#print "Ready!\n\n";


######
# STEP 2: TEST
######

my $tokens = 0;
my $correct_tokens = 0;
my $sentences = 0;
my $correct_sentences = 0;

#open TEST, '<', $testing_file || die $!;
while (<>) {
  chomp;
  my $emissions = Alphagram::alphagram_sentence($_);
  next unless $emissions;
  my @elist = split /\s+/, $emissions;
  
  
  # Take unknowns out.
  my @unknown = ();
  for (my $i = 0; $i < @elist; $i++) {
    if (!$B->{$elist[$i]}) {
      #print "    replacing unknown alphagram $elist[$i]\n";
      $unknown[$i] = $elist[$i];
      $elist[$i] = '<>u';
    } else {
      $unknown[$i] = 0;
    }
  }
  
  
  # SOLVE!
  my $O = [@elist];
  my $soln = Viterbi::DecodeAlphagramsTrigram( $A1, $A2, $A3, $B, $O, $Q, $l1, $l2, $l3, \%w2n );
  
  
  # Put unknowns back in.
  my @vlist = split /\s+/, $soln;
  for (my $i = 0; $i < @elist; $i++) {
    if ($unknown[$i]) {
      if ($one_counts->{$unknown[$i]}) {
        # We know this one!
        #print "    unknown alphagram $unknown[$i] recovered\n";
        $vlist[$i] = $one_counts->{$unknown[$i]};
      }
      else {
        # We don't know it, just guess...
        $vlist[$i] = $unknown[$i];
      }
    }
  }
  $soln = join(' ', @vlist);
  
  
  # Evaluate at the sentence level.
  #print "I: $emissions\nC: $states\nO: $soln\n";
  #$sentences++;
  #if ($soln eq $states) {
  #  $correct_sentences++;
  #  print "+ $sentences ";
  #}
  #else {
  #  print "- $sentences ";
  #}
  
  print "$soln\n";
    
    
  # Evaluate at the word level.
  #my @slist = split /\s+/, $states;
  #for (my $i = 0; $i < @slist; $i++) {
  #  $tokens++;
  #  if ($vlist[$i] eq $slist[$i]) {
  #    $correct_tokens++;
  #  }
  #}
  
  
  # Keep a running total.
  #printf "%d/%d %1.4f\t%s\n\n", $correct_tokens, $tokens, $correct_tokens/$tokens, `date`;
}
#close TEST || die $!;


# Print evaluation.
#print
#  "WORDS CORRECT      $correct_tokens / $tokens ",
#    sprintf("%1.4f\n",  $correct_tokens/$tokens),
#  "SENTENCES CORRECT  $correct_sentences / $sentences ", 
#    sprintf("%1.4f\n",  $correct_sentences/$sentences),
#  "\n";

