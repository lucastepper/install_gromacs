#%Module1.0 -*- tcl -*-
## gromacs modulefile
##


module-whatis "Adds GROMACS to your environment variables."
proc ModulesHelp { } {
  puts stderr "Add GROMACS $gromacsversion to your environment"
  puts stderr "Use the -nt option of mdrun to specify the number of threads."
}

# Get script path to know what version to load
variable path [file normalize [info script]]
# Split the path into components
set pathComponents [split $path "/"]
# Find the index of 'modulefiles'
set startIndex [lsearch $pathComponents "modulefiles"]
if {$startIndex != -1} {
    # Extract gromacs name
    set gromacsNameSplit [lrange $pathComponents [expr {$startIndex + 1}] end]
    set gromacsName [join $gromacsNameSplit "/"]
} else {
    puts stderr "Error while parsing name of module file."
}
set gromacsName [string map {"/gromacs" ""} $gromacsName]

set shell [module-info shell]

# Function to read CPU flags
proc get_cpu_flags {} {
    set cpuinfo [open "/proc/cpuinfo" r]
    set flags [read $cpuinfo]
    close $cpuinfo

    # Extract the flags line
    set flag_lines [regexp -all -inline {flags\s+:\s+.*} $flags]
    set cpu_flags ""

    foreach line $flag_lines {
        # Extract individual flags
        set flags_in_line [lindex [split $line ":"] 1]
        set flags_in_line [string trim $flags_in_line]
        set cpu_flags [concat $cpu_flags $flags_in_line]
    }

    return $cpu_flags
}

# Get CPU flags
set cpu_flags [get_cpu_flags]

# Determine the SIMD variable based on CPU flags, base is avx-256
if { [info exists ::env(SIMD)] } {
    set SIMD $::env(SIMD)
    puts stderr "Overwrite for SIMD: $SIMD"
} else {
  set SIMD "AVX_256"
  if {"avx512f" in $cpu_flags} {
      set SIMD "AVX_512"
  } elseif {"avx2" in $cpu_flags} {
      set SIMD "AVX2_256"
  } elseif {"avx" in $cpu_flags} {
      set SIMD "AVX_256"
  }
}

# Set correct root folder for module
if {[string first "plumed" $gromacsName] != -1} {
    set gromacsName [string map {"-plumed" ""} $gromacsName]
    set root /net/opt/gromacs-plumed/$gromacsName/$SIMD
    if { ![ is-loaded plumed/PLUMEDVERSION ] } {
        module load plumed/PLUMEDVERSION
    }
} else {
  set root /net/opt/gromacs/$gromacsName/$SIMD
}

# created via env2 -from sh -to modulecmd /net/opt/gromacs/single/$gromacsversion/bin/GMXRC.bash
setenv          GROMACS_DIR         $root
setenv          GMXBIN              $root/bin
setenv          GMXMAN              $root/share/man
setenv          GMXDATA             $root/share/gromacs
setenv          GMXLDLIB            $root/lib/x86_64-linux-gnu

prepend-path    PATH                $root/bin
prepend-path    LD_RUN_PATH         $root/lib
prepend-path    LD_LIBRARY_PATH     $root/lib/x86_64-linux-gnu:$root/lib
prepend-path    PKG_CONFIG_PATH     $root/lib/x86_64-linux-gnu/pkgconfig

if {[module-info mode load]} {
  puts stderr "Loading $gromacsName"
  puts stderr "Root: $root"
  if {$shell  == "bash"} {
    puts stdout "source $root/bin/GMXRC;"
    puts stdout "source $root/bin/gmx-completion-gmx.bash;"
    puts stdout "source $root/bin/gmx-completion-mdrun_mpi.bash;"
  }
}

if {[module-info mode remove]} {
  puts stderr "Removing GROMACS $gromacsName."
  if {$shell  == "bash"} {
    puts stdout "complete -r gmx;"
  }
}

