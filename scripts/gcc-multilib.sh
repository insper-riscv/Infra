#!/usr/bin/env bash
# Prints the list of RISC-V library variants in the format of the GCC option
# --with-multilib-generator: <march>-<mabi>--, separated by semicolons. The GCC of docker/base/gcc
# is built with this list, and picolibc follows the variants that GCC reports.
#
# A variant is one choice on each axis below, with the ABIs that the choice allows:
#   width     32 bits (RV32) or 64 bits (RV64)
#   base      I (32 registers) or E (16 registers)
#   multiply  none, Zmmul (multiply only) or M (multiply and divide)
#   float     none, F or F and D
#   A         without or with the atomic extension
#   C         without or with the compressed instructions
#   B         without or with the group Zba, Zbb and Zbs
# For RV32 the ABIs are ilp32, ilp32f, ilp32d and ilp32e, and for RV64 they are lp64, lp64f, lp64d
# and lp64e. The plain ABI is allowed for I with any float choice, the f ABI needs F and the d ABI
# needs D, and E allows only the e ABI, without D.
#
#   scripts/gcc-multilib.sh                  prints the list of both widths (RV32 first, then RV64)
#   scripts/gcc-multilib.sh --width 32|64    prints the list of one width
#   scripts/gcc-multilib.sh --count          prints how many variants the list has
#   scripts/gcc-multilib.sh --width 64 --count
set -euo pipefail

widths="32 64"
count=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --count) count=true; shift ;;
    --width)
      [ "$#" -ge 2 ] || { echo "--width needs 32 or 64" >&2; exit 2; }
      case "$2" in
        32|64) widths="$2" ;;
        *) echo "--width needs 32 or 64, not '$2'" >&2; exit 2 ;;
      esac
      shift 2 ;;
    *) echo "usage: $0 [--width 32|64] [--count]" >&2; exit 2 ;;
  esac
done

variants=()
for width in $widths; do
  for base in i e; do
    for mul in "" _zmmul m; do
      for fp in "" f fd; do
        if [ "$width" = 32 ]; then p=ilp32; else p=lp64; fi
        if [ "$base" = e ]; then
          [ "$fp" = fd ] && continue
          abis="${p}e"
        else
          case "$fp" in
            "") abis="$p" ;;
            f) abis="$p ${p}f" ;;
            fd) abis="$p ${p}f ${p}d" ;;
          esac
        fi
        for a in "" a; do
          for c in "" c; do
            for b in "" _zba_zbb_zbs; do
              letter_m=""
              suffix_mul=""
              [ "$mul" = m ] && letter_m="m"
              [ "$mul" = _zmmul ] && suffix_mul="_zmmul"
              arch="rv${width}${base}${letter_m}${a}${fp}${c}${b}${suffix_mul}"
              for abi in $abis; do
                variants+=("${arch}-${abi}--")
              done
            done
          done
        done
      done
    done
  done
done

if [ "$count" = true ]; then
  echo "${#variants[@]}"
else
  (IFS=';'; echo "${variants[*]}")
fi
