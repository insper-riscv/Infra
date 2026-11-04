#!/usr/bin/env bash
# Prints the list of RISC-V library variants in the format of the GCC option
# --with-multilib-generator: <march>-<mabi>--, separated by semicolons. The GCC of docker/base/gcc
# is built with this list, and picolibc follows the variants that GCC reports.
#
# A variant is one choice on each axis below, with the ABIs that the choice allows:
#   base      I (32 registers) or E (16 registers)
#   multiply  none, Zmmul (multiply only) or M (multiply and divide)
#   float     none, F or F and D
#   A         without or with the atomic extension
#   C         without or with the compressed instructions
#   B         without or with the group Zba, Zbb and Zbs
# ilp32 is allowed for I with any float choice, ilp32f needs F and ilp32d needs D, and E allows
# only ilp32e, without D.
#
#   scripts/gcc-multilib.sh            prints the list
#   scripts/gcc-multilib.sh --count    prints how many variants it has
set -euo pipefail

variants=()
for base in i e; do
  for mul in "" _zmmul m; do
    for fp in "" f fd; do
      if [ "$base" = e ]; then
        [ "$fp" = fd ] && continue
        abis="ilp32e"
      else
        case "$fp" in
          "") abis="ilp32" ;;
          f) abis="ilp32 ilp32f" ;;
          fd) abis="ilp32 ilp32f ilp32d" ;;
        esac
      fi
      for a in "" a; do
        for c in "" c; do
          for b in "" _zba_zbb_zbs; do
            letter_m=""
            suffix_mul=""
            [ "$mul" = m ] && letter_m="m"
            [ "$mul" = _zmmul ] && suffix_mul="_zmmul"
            arch="rv32${base}${letter_m}${a}${fp}${c}${b}${suffix_mul}"
            for abi in $abis; do
              variants+=("${arch}-${abi}--")
            done
          done
        done
      done
    done
  done
done

if [ "${1:-}" = "--count" ]; then
  echo "${#variants[@]}"
else
  (IFS=';'; echo "${variants[*]}")
fi
