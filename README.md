# watchFileSize
Utility for monitoring the size of files on the commandline

##USAGE  
    ./watchFileSize.pl -f [FILE(s)] [options] 
    ./watchFileSize.pl -d [DIR(s)]  [options] 

##ARGUMENTS

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

##INFO

While running press 'q' to exit program.

##AUTHOR
    
David A. Parry

https://github.com/gantzgraf/watchFileSize
