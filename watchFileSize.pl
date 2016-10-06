#!/usr/bin/env perl
use warnings;
use strict;
use Getopt::Long;
use Term::ReadKey;
use Time::HiRes qw(time);
use POSIX qw/strftime/;
my @files             = ();
my @directories       = ();
my @whole_directories = ();
my $sleep             = 10;
my $timeout           = 0;
my $units             = "human_readable";
my @regex             = ();
my @dont_regex        = ();
my $recurse           = 0;
my $all               = 0;

#my $help;
GetOptions(
    "files=s{,}"           => \@files,
    "directories=s{,}"     => \@directories,
    "whole_dir=s{,}"       => \@whole_directories,
    "sleep=i"              => \$sleep,
    "units=s"              => \$units,
    "timeout=i"            => \$timeout,
    "match=s{,}"           => \@regex,
    "x|inverse_match=s{,}" => \@dont_regex,
    "recurse"              => \$recurse,
    "all"                  => \$all,
    "help|?"               => sub { usage() }
) or usage("Syntax error!\n");

#usage($help) if $help;
if ( not @files and not @directories and not @whole_directories ) {
    usage("Please provide at least one file or directory to monitor\n");
}
if ( $sleep < 1 ) {
    usage("Value for --sleep must be a whole number greater than 0.\n");
}
my @valid_units = qw (bytes KB MB GB TB human_readable);
my %conversion  = (
    bytes => 1,
    KB    => 1024,
    MB    => 1024 * 1024,
    GB    => 1024 * 1024 * 1024,
    TB    => 1024 * 1024 * 1024 * 1024
);

#find index of matching valid_unit array member so we can use exact value in
#conversion hash
my ($valid_index) = grep { $valid_units[$_] =~ /$units/i } 0 .. $#valid_units;
if ( not defined $valid_index ) {
    usage
    (
        "Unit value '$units' not recognised. Valid values are:\n"
        . join( "\n", @valid_units ) . "\n"
    );
}
else {
    $units = $valid_units[$valid_index]
      ;    #for readability we'll put the exact value in the $units variable
}

my %file_sizes               = map { $_ => 0 } @files, @whole_directories;
my %files_size_hasnt_changed = map { $_ => 0 } @files, @whole_directories;
my $identical_counter = 0;    #count no. cycles file sizes haven't changed
print STDERR "\n*Press 'q' to quit at any time.*\n";
ReadMode 3;
while (1) {

    foreach my $dir ( sort @directories ) {
        my @added_files = get_files_from_directory
        (
            directory   => $dir,
            match       => \@regex,
            dont_match  => \@dont_regex,
            recurse     => $recurse,
            hidden      => $all
        );
        foreach my $add (@added_files) {
            $file_sizes{$add}               ||= 0;
            $files_size_hasnt_changed{$add} ||= 0;
        }
        push( @files, @added_files )
          ;#add individually monitored files from directories to our @files hash
    }
    my $time = strftime "%a %b %e %Y: %H:%M:%S", localtime;
    print "\n[$time]\n";
    my %seen = ();
    @files = grep { !$seen{$_}++ } @files;    #remove duplicates
    foreach my $file (@files) {    #assess all our individually monitored files
        my $size = -s $file;
        if ( not defined $size ) {
            print "$file:\tdoesn't exist\n";
            if ( $file_sizes{$file} != 0 )
            {    #looks like file did exist before, so file size has changed
                $files_size_hasnt_changed{$file} = 0;
            }else {
                $files_size_hasnt_changed{$file} = 1;
            }
            $file_sizes{$file} = 0;
            next;
        }
        my $diff = $size - $file_sizes{$file};
        if ( not $diff ) {
            $files_size_hasnt_changed{$file} = 1;
        }else {
            $files_size_hasnt_changed{$file} = 0;
        }
        if ( exists $conversion{$units} )
        {    #any value except human_readable will be in %conversion hash
            my $conv_size = $size / $conversion{$units};
            print "$file:\t"
              ;    # don't use printf in case $file has special characters
            printf( "%.2f $units", $conv_size );
            if ( $diff and $file_sizes{$file} > 0 ) {

       #if size has changed and wasn't 0 (i.e. not first round) print difference
                my ( $diff_value, $diff_units ) = get_sensible_units($diff);
                printf( " (%.2f $diff_units in $sleep seconds)", $diff_value );
            }
        }else {
            my ( $sensible_size, $sensible_unit ) = get_sensible_units($size);
            print "$file:\t"
              ;    # don't use printf in case $file has special characters
            printf( "%.2f $sensible_unit", $sensible_size );

       #if size has changed and wasn't 0 (i.e. not first round) print difference
            if ( $diff and $file_sizes{$file} > 0 ) {
                my ( $diff_value, $diff_units ) = get_sensible_units($diff);
                printf( " (%.2f $diff_units in $sleep seconds)", $diff_value );
            }
        }
        print "\n";
        $file_sizes{$file} = $size;
    }
    foreach my $wdir ( sort @whole_directories )
    {    #asses all our whole directories
        my $wsize;
        my @added_files = get_files_from_directory(
            directory => $wdir,
            recurse   => 1,
            hidden    => 1
        );
        foreach my $add (@added_files) {
            $wsize += -s $add;
        }
        if ( not defined $wsize ) {
            if ( $file_sizes{$wdir} != 0 )
            {    #looks like file did exist before, so file size has changed
                $files_size_hasnt_changed{$wdir} = 0;
            }else {
                $files_size_hasnt_changed{$wdir} = 1;
            }
            $file_sizes{$wdir} = 0;
            next;
        }
        my $diff = $wsize - $file_sizes{$wdir};
        if ( not $diff ) {
            $files_size_hasnt_changed{$wdir} = 1;
        }else {
            $files_size_hasnt_changed{$wdir} = 0;
        }
        if ( exists $conversion{$units} )
        {    #any value except human_readable will be in %conversion hash
            my $conv_size = $wsize / $conversion{$units};
            print "$wdir:\t"
              ;    # don't use printf in case $wdir has special characters
            printf( "%.2f $units", $conv_size );
            if ( $diff and $file_sizes{$wdir} > 0 ) {

       #if size has changed and wasn't 0 (i.e. not first round) print difference
                my ( $diff_value, $diff_units ) = get_sensible_units($diff);
                printf( " (%.2f $diff_units in $sleep seconds)", $diff_value );
            }
        }else {
            my ( $sensible_size, $sensible_unit ) = get_sensible_units($wsize);
            print "$wdir:\t"
              ;    # don't use printf in case $wdir has special characters
            printf( "%.2f $sensible_unit", $sensible_size );

       #if size has changed and wasn't 0 (i.e. not first round) print difference
            if ( $diff and $file_sizes{$wdir} > 0 ) {
                my ( $diff_value, $diff_units ) = get_sensible_units($diff);
                printf( " (%.2f $diff_units in $sleep seconds)", $diff_value );
            }
        }
        print "\n";
        $file_sizes{$wdir} = $wsize;
    }

    if ($timeout) {
        foreach my $k ( keys %files_size_hasnt_changed ) {
            if ( $files_size_hasnt_changed{$k} == 0 ) {
                $identical_counter = 0;
                last;
            }
        }    #if we've got here then all are identical
        $identical_counter++;
        if ( $identical_counter >= $timeout ) {
            print
"\nAll file sizes have remained the same for $identical_counter cycles.\n";
            exit 0;
        }
    }

    #sleep $sleep;
    my $key = ReadKey($sleep);
    if ( defined $key ) {
        exit 0 if $key eq 'q';
    }
}

END {
    ReadMode 0;
    print STDERR "Exiting.\n";
}
################################################################################
sub usage {
    my ($msg) = @_;
    print STDERR "\n$msg\n" if $msg;
    print STDERR <<EOT

USAGE:  $0 -f [FILE(s)] [options] 
        $0 -d [DIR(s)]  [options] 

ARGUMENTS:

    -f,--files FILE(s)
         One or more files to monitor.

    -d,--directories
        One or more directories to monitor. All files in a given directory will 
        be monitored.

    -w,--whole_dir
        One or more directories to monitor giving a value for the whole
        directory rather than each file.

    -s,--sleep
        Sleep interval between updates in seconds. Default is 10.

    -u,--units
        Units to use for file sizes. Default is human_readable. Valid values are 
        bytes, 'KB', 'MB', 'GB', 'TB' and 'human_readable'.

    -t,--timeout
        Exit if the filesize remains identical for all files for this many sleep 
        intervals.

    -m,--match
        Perl style regular expression(s) that files must match. Only tested for 
        files found in directories, not for files specified by --files argument.

    -x,--inverse_match
        Perl style regular expression(s) that files must NOT match. Only tested
        for files found in directories, not for files specified by --files
        argument.

    -r,--recurse
        Recurse directories

    -a,--all
        Include hidden files and directories

    -h,-?,--help
        Show help message

INFO:

    While running press 'q' to exit program.

AUTHOR:
    
    David A. Parry

    https://github.com/gantzgraf/watchFileSize

EOT
    ;
    exit 1 if $msg;
    exit;
}

################################################################################
sub get_sensible_units {
#returns a two member list of size and units calculated from a value given in
#bytes - e.g. 10485700 would return 100 and MB
    my ($bytes) = @_;
    my %convert = (
        bytes => 1,
        KB    => 1024,
        MB    => 1024 * 1024,
        GB    => 1024 * 1024 * 1024,
        TB    => 1024 * 1024 * 1024 * 1024
    );
    foreach my $u (qw(bytes KB MB GB TB)) {
        my $temp_size = $bytes / $convert{$u};
        if ( 0 <= $temp_size and $temp_size <= 1023 ) {
            return ( $temp_size, $u );
        }elsif ( $u eq "TB" ){ #TB is the largest unit we'll use
            return ( $temp_size, $u );
        }
    }
}

################################################################################
sub get_files_from_directory {
#returns array of files matching regexes in regex array ref argument and 
#recurses if recurse argument is true and includes hidden files if hidden 
#argument is true
# arguments: directory, recurse, match, dont_match, hidden
    my (%args) = @_;
    $args{directory} =~ s/\/$//;    #remove trailing slash
    opendir( my $DIR, $args{directory} )
      || die "Can't read directory $args{directory}: $!\n";
    my @dir_files       = readdir($DIR);
    my @files_to_return = ();
  FILE: foreach my $d_file ( sort @dir_files ) {
        if ( exists $args{match} ) {
            if ( ref( $args{match} ) eq 'ARRAY' && @{ $args{match} } ) {
                my $matched = 0;
                foreach my $match ( @{ $args{match} } ) {
                    next if not defined $match;
                    $matched++ if $d_file =~ /$match/;
                }
                next FILE if not $matched;
            }
        }
        if ( exists $args{dont_match} ) {
            if ( ref( $args{dont_match} ) eq 'ARRAY' && @{ $args{dont_match} } )
            {
                foreach my $match ( @{ $args{dont_match} } ) {
                    next FILE if $d_file =~ /$match/;
                }
            }
        }
        unless ( $args{hidden} )
        {    #skip hidden files/directories unless $args{hidden} flag is true
            next FILE if $d_file =~ /^\.\w/;
        }
        if ( -f "$args{directory}/$d_file" ) {
            if ( $args{directory} =~ /^\.$/ )
            {    #remove ./ for files in current directory
                push( @files_to_return, "$d_file" );
            }
            else {
                $args{directory} =~ s/^\.//
                  if ( $args{directory} =~ /^\.\// )
                  ;    #remove ./ if we're recursing
                push( @files_to_return, "$args{directory}/$d_file" );
            }
        }
        elsif ( -d "$args{directory}/$d_file" ) {
            next
              if $d_file =~
              /\.$/;    #don't want to recurse the same directory! - skip ./
            my @temp_add = get_files_from_directory(
                directory => "$args{directory}/$d_file",
                match     => $args{match},
                recurse   => $args{recurse},
                hidden    => $args{hidden}
            ) if $args{recurse};
            push( @files_to_return, @temp_add );
        }
    }
    return @files_to_return;
}

