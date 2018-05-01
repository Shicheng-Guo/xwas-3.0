#!/usr/bin/perl

use Getopt::Std ;
use File::Basename ;

### process flags
# -w poplist is compute eigenvectors using populations in poplist, then project
# -y poplistplot is use populations in poplistplot for plot
# -z badsnpfile is use badsnpname: badsnpfile in call to smartpca
my @flaglist = ("i","a","b","k","o","p","e","l","m","q","t","s","w","y","z","d","g");
$x = @ARGV;
for($n=0; $n<$x; $n++)
{
  foreach $flag (@flaglist) 
  {
    if($ARGV[$n] eq "-$flag") { $specified{$flag} = 1; }
  }
}
foreach $flag ("i","a","b","o","p","e","l")
{
  unless($specified{$flag}) { die("OOPS -$flag flag not specified"); }
}
getopts('i:a:b:k:o:p:e:l:m:t:s:w:y:z:q:d:g:',\%opts);
$i = $opts{"i"}; 
$a = $opts{"a"}; 
$b = $opts{"b"}; 
$k = 10; if($specified{"k"}) { $k = $opts{"k"}; }
$o = $opts{"o"}; 
$q = 0; if($specified{"q"}) { $q = $opts{"q"}; }
$p = $opts{"p"}; 
$e = $opts{"e"}; 
$l = $opts{"l"}; 
$m = 5; if($specified{"m"}) { $m = $opts{"m"}; }
$t = 10; if($specified{"t"}) { $t = $opts{"t"}; }
$s = 6.0; if($specified{"s"}) { $s = $opts{"s"}; }
if($specified{"w"}) { $w = $opts{"w"}; }
if($specified{"y"}) { $y = $opts{"y"}; }
if($specified{"z"}) { $z = $opts{"z"}; }
if($specified{"d"}) { $d = $opts{"d"}; }
if($specified{"g"}) { $g = $opts{"g"}; }

### run smartpca
$parfile = "$o.par"; 
$evec = "$o.evec";
open(PARFILE,">$parfile") || die("OOPS couldn't open file $parfile for writing");
print PARFILE ("genotypename: $i\n");
print PARFILE ("snpname: $a\n");
print PARFILE ("indivname: $b\n");
print PARFILE ("evecoutname: $evec\n");
print PARFILE ("evaloutname: $e\n");
print PARFILE ("altnormstyle: NO\n");
print PARFILE ("numoutevec: $k\n");
print PARFILE ("numoutlieriter: $m\n");
print PARFILE ("numoutlierevec: $t\n");
print PARFILE ("outliersigmathresh: $s\n");
print PARFILE ("qtmode: $q\n");
if($specified{"w"}) { print PARFILE ("poplistname: $w\n"); }
if($specified{"z"}) { print PARFILE ("badsnpname: $z\n"); }
if($specified{"d"}) { print PARFILE ("snpweightoutname: $d\n");}
if($specified{"g"}) { print PARFILE ("noxdata: $g\n"); }
close(PARFILE);
$command = "./smartpca";          # MUST put bin directory in path
$command .= " -p $parfile >$l";
print("$command\n");
system("$command");

# Added by Lauren, catch if smartpca fails
if ($? != 0) {
    exit ($? >> 8);
}

#make string of populations for ploteig
$popstring = "";
open(EVEC,$evec) || die("OOPS couldn't open file $evec for reading");
while($line = <EVEC>)
{
  chomp($line);
  my @array = split(/[\t ]+/,$line);
  $x = @array;
  if($array[1] =~ /eigvals/) { next; } # eigvals header line
  $pop = $array[$x-1];
  if($popfound{$pop}) { next; }
  $popstring = $popstring . "$pop:";
  $popfound{$pop} = 1;
}
close(EVEC);
chop($popstring); # remove last ":"

if($specified{"y"}) 
{
  ### make string of populations for ploteig based on -y flag input
  $popstring = "";
  open(Y,$y) || die("COF");
  while($line = <Y>)
  {
    chomp($line);
    $popstring .= "$line:";
  }
  chop($popstring);
}

### translate .evec file to .pca file expected by eigenstrat program
### Note: .evec file does not contain entries for outliers 
###       .pca  file does contain entries (set to all 0.0) for outliers
$command = "evec2pca.perl $k $evec $b $o";
print("$command\n");
system("$command");

### If labels are Case and Control only, compute correlations between
### Case/Control status and each eigenvector.  Append to logfile.
if(($popstring eq "Case:Control") || ($popstring eq "Control:Case"))
{
  open(LOG,">>$l") || die("OOPS couldn't open file $l for appending");
  print LOG ("\n");
  for($x=0; $x<$k; $x++) # compute correlation for evec $x
  {
    open(EVEC,$evec) || die("OOPS couldn't open file $evec for reading");
    $sum1=0; $sumx=0; $sumxx=0; $sumy=0; $sumyy=0; $sumxy=0;
    $line = <EVEC>; chomp($line); # eigvals line
    while($line = <EVEC>)
    {
      chomp($line);
      my @array = split(/[\t ]+/,$line);
      $this = $array[2+$x];
      $sumy += $this;
      $sumyy += $this*$this;
      $sum1 += 1;
      if($line =~ /Case/) # Case is 1, Control is 0
      {
        $sumx += 1;
        $sumxx += 1;
        $sumxy += $this;
      }
    }
    close(EVEC);
    $meanx = $sumx/$sum1;
    $meany = $sumy/$sum1;
    if($sum1 == 0) { next; }
    $sdevx = sqrt($sumxx/$sum1 - $meanx*$meanx);
    $sdevy = sqrt($sumyy/$sum1 - $meany*$meany);
    if($sdevx * $sdevy == 0) { next; }
    $corr = ($sumxy/$sum1) / ($sdevx*$sdevy);
    $x1 = $x+1;
    printf LOG ("Correlation between eigenvector $x1 (of $k) and Case/Control status is %.03f\n",$corr);
  }
  close(LOG);
}
