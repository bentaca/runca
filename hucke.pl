use strict;
use warnings;
use Data::Dumper   qw(Dumper);
use File::Basename qw(fileparse dirname);
use Getopt::Long   qw(GetOptions);
use File::Spec     qw(catfile);
use Cwd            qw(cwd getcwd abs_path);

our $USAGE = "Usage: $0 -pkg <pkgs> -o <output.exe> file.ml \n";

my %Lib_exts = (
   ocamlc   => '.cma',
   ocamlopt => '.cmx',
);

my ( $packages_opt, $output_opt ) = ( "", "" );
my $quiet_opt;
GetOptions(
   'pkg=s'   => \$packages_opt,
   'quiet|q' => \$quiet_opt,
   'o=s'     => \$output_opt,
) or die $USAGE;

our $compiler = shift @ARGV;

die "Err: compiler either 'ocamlc' or 'ocamlopt'"
  unless ( $compiler =~ /ocamlc|ocamlopt/ );

my (@files) = grep { /[\w\-\_]+\.ml/ } @ARGV;
die "Err: invalid file input " unless (@files);
my $files_string = join( ' ', @files );

my $output;
if ($output_opt) {
   $output = $output_opt;
}
else {
   my $lastfile = abs_path( $files[$#files] );
   my ( $name, $dir, $ext ) = fileparse( $lastfile, '\..*' );
   if ( $dir =~ /(.+)[\\|\/]$/ ) { $dir = $1 }
   ;                             # remove a trailing \ or /
   my $cwd = getcwd;
   $output = ( $cwd eq $dir )    # only the exe name if in the same dir
     ? $name . '.exe'
     : File::Spec->catfile( $dir, $name . '.exe' );
}

my $libs_ocaml = qx($compiler -where);
chomp $libs_ocaml;

my $libs_root = dirname($libs_ocaml);

my (@packages) = split( /\,|\:/, $packages_opt ) if $packages_opt;

my %packages_paths = ();
foreach my $pkg_name (@packages) {
   my $pkg = $pkg_name . $Lib_exts{$compiler};

   my $path;
   foreach
     my $lib_dir ( File::Spec->catfile( $libs_root, $pkg_name ), $libs_ocaml )
   {
      my $_path = File::Spec->catfile( $lib_dir, $pkg );
      if ( -f $_path ) {
         die "Err: library '$pkg' occurs in in '$path' and in '$_path'"
           if $path;
         $path = $_path;
      }
   }
   if ($path) {
      $packages_paths{$pkg} = $path;
   }
   else {
      die "Err: library '$pkg' could not be found";
   }
}

my $packages_string = join( ' ', values %packages_paths );

print "$compiler $packages_string -o $output $files_string" unless ($quiet_opt);
qx($compiler $packages_string -o $output $files_string);

__END__

docs:
ocamlfind:
   ocamlfind ocamlc -linkpkg -package unix,uutf -o prog prog.ml

