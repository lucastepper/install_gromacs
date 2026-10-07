#%Module1.0
## Module file generated on |TIMESTAMP|

module-whatis "GROMACS is a molecular dynamics package primarily designed for simulations of proteins, lipids and nucleic acids. It was originally developed in the Biophysical Chemistry department of University of Groningen, and is now maintained by contributors in universities and research centers across the world."

proc ModulesHelp { } {
    puts stderr "Name   : gromacs"
    puts stderr "Version: |VERSION|"
    puts stderr ""
    puts stderr "GROMACS is a molecular dynamics package primarily designed for"
    puts stderr "simulations of proteins, lipids and nucleic acids. It was originally"
    puts stderr "developed in the Biophysical Chemistry department of University of"
    puts stderr "Groningen, and is now maintained by contributors in universities and"
    puts stderr "research centers across the world. GROMACS is one of the fastest and"
    puts stderr "most popular software packages available and can run on CPUs as well as"
    puts stderr "GPUs. It is free, open source released under the GNU Lesser General"
    puts stderr "Public License. Before the version 4.6, GROMACS was released under the"
    puts stderr "GNU General Public License."
}

proc hasCpuFlag {cpuinfo flag} {
  # Normalize whitespace so a flag can be matched as a complete token even
  # though /proc/cpuinfo wraps long flag lists across lines.
  set normalized [regsub -all {\s+} $cpuinfo { }]
  return [expr {[string first " $flag " " $normalized "] >= 0}]
}

# getArchHash selects the ARCH and HASH of an installed Spack GROMACS module
# compatible with the current CPU, so its paths can be loaded below.
proc getArchHash {} {
  set fd [open "/proc/cpuinfo" "r"]
  set cpuinfo [read $fd]
  close $fd

  # AMD identifies Zen 2 EPYC (Rome) as family 23, model 48 through 63.
  if {[regexp {vendor_id[[:space:]]*:[[:space:]]*AuthenticAMD} $cpuinfo] && \
      [regexp {cpu family[[:space:]]*:[[:space:]]*23([^0-9]|$)} $cpuinfo] && \
      [regexp {model[[:space:]]*:[[:space:]]*(4[89]|5[0-9]|6[0-3])([^0-9]|$)} $cpuinfo]} {
    set gromacsPath "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/|ARCH4|/gromacs-|VERSION|-|HASH4|/bin"
    if {[file isdirectory $gromacsPath]} {
      return [list "|ARCH4|" "|HASH4|"]
    }
  }

  # x86-64-v4 requires all five AVX-512 baseline extensions.
  if {[hasCpuFlag $cpuinfo avx512f] && \
      [hasCpuFlag $cpuinfo avx512cd] && \
      [hasCpuFlag $cpuinfo avx512dq] && \
      [hasCpuFlag $cpuinfo avx512bw] && \
      [hasCpuFlag $cpuinfo avx512vl]} {
    set gromacsPath "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/|ARCH3|/gromacs-|VERSION|-|HASH3|/bin"
    if {[file isdirectory $gromacsPath]} {
      return [list "|ARCH3|" "|HASH3|"]
    }
  }

  # AVX2 is the baseline required by the Haswell build.
  if {[hasCpuFlag $cpuinfo avx2]} {
    set gromacsPath "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/|ARCH2|/gromacs-|VERSION|-|HASH2|/bin"
    if {[file isdirectory $gromacsPath]} {
      return [list "|ARCH2|" "|HASH2|"]
    }
  }

  # Ivy Bridge is the final fallback, but it must also be installed.
  set gromacsPath "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/|ARCH1|/gromacs-|VERSION|-|HASH1|/bin"
  if {[file isdirectory $gromacsPath]} {
    return [list "|ARCH1|" "|HASH1|"]
  }

  puts stderr "No compatible installed Spack GROMACS build was found for this CPU."
  exit 1
}

set result [getArchHash]
set ARCH [lindex $result 0]
set HASH [lindex $result 1]

prepend-path --delim ":" PATH "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/$ARCH/gromacs-|VERSION|-$HASH/bin"
prepend-path --delim ":" MANPATH "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/$ARCH/gromacs-|VERSION|-$HASH/share/man"
prepend-path --delim ":" PKG_CONFIG_PATH "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/$ARCH/gromacs-|VERSION|-$HASH/lib/pkgconfig"
prepend-path --delim ":" CMAKE_PREFIX_PATH "/net/opt/spack_ag_netz/spack_|DEBIANNAME|/opt/spack/$ARCH/gromacs-|VERSION|-$HASH/."
