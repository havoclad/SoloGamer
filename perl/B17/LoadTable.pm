package B17::LoadTable;

use strict;

use File::Slurp;
use Mojo::JSON qw(decode_json encode_json);

sub loadTable {
  my $file = shift;

  my $f = read_file($file);
  my $p = decode_json($f);

  return $p;
}
1;
