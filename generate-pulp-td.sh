#!/usr/bin/env bash
# Generate LLVM TableGen instruction definitions for Snitch/PULP custom extensions.
#
# Reads the extension list from riscv-opcodes/pulp-llvm-extensions.txt,
# drives the riscv-opcodes submodule to produce inst.<extname>.td files and csr.td,
# copies instruction files into the RISCV Target directory, and appends only
# previously undefined CSRs to RISCVSystemOperands.td.
set -euo pipefail

RISCV_OPCODES_DIR="${PWD}/riscv-opcodes"
OPCODES_FILE="${RISCV_OPCODES_DIR}/pulp-llvm-extensions.txt"

RISCV_TARGET_DIR="${PWD}/llvm/lib/Target/RISCV"
RISCV_INSTR_INFO="${RISCV_TARGET_DIR}/RISCVInstrInfo.td"
RISCV_FEATURES="${RISCV_TARGET_DIR}/RISCVFeatures.td"
RISCV_SYSTEM_OPERANDS="${RISCV_TARGET_DIR}/RISCVSystemOperands.td"
RISCV_DISASSEMBLER="${RISCV_TARGET_DIR}/Disassembler/RISCVDisassembler.cpp"

RISCV_INSTR_INFO_ANCHOR='include "RISCVInstrInfoXCV.td"'  # Insert after anchor
RISCV_FEATURES_ANCHOR='// Ventana Extensions'              # Insert before anchor
RISCV_DISASSEMBLER_ANCHOR='    {DecoderTableXSMT32, XSMTGroup, "SpacemiT extensions"},'  # Insert after anchor

# Read extension list, ignoring blank lines and comments.
mapfile -t OPCODES < <(grep -v '^\s*#' "${OPCODES_FILE}" | grep -v '^\s*$')

if [[ ${#OPCODES[@]} -eq 0 ]]; then
    echo "Error: no opcodes found in ${OPCODES_FILE}" >&2
    exit 1
fi

# Run riscv_opcodes in a temporary directory so intermediate files
# don't pollute the source tree.
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

(
    cd "${WORKDIR}"
    uv run --project "${RISCV_OPCODES_DIR}" \
        python -m riscv_opcodes -llvm --warn-overlap \
        --csr rv_xpulp --csr rv_xventaglio "${OPCODES[@]}"
)

# Move generated instruction .td files into the RISCV target directory.
INCLUDES=()
EXT_NAMES=()
for td in "${WORKDIR}"/inst.*.td; do
    [[ -e "${td}" ]] || continue
    ext="${td##*/inst.}"          # e.g. "ssr.td"
    ext="${ext%.td}"              # e.g. "ssr"
    dest="${RISCV_TARGET_DIR}/RISCVInstrInfoX${ext}.td"
    mv "${td}" "${dest}"
    echo "Generated instruction table for X${ext} at ${dest#${PWD}/}"
    INCLUDES+=("${dest##*/}")
    EXT_NAMES+=("${ext}")
done

# Insert include directives in RISCVInstrInfo.td if not already present.
for filename in "${INCLUDES[@]}"; do
    line="include \"${filename}\""
    if ! grep -qF "${line}" "${RISCV_INSTR_INFO}"; then
        sed -i "\|${RISCV_INSTR_INFO_ANCHOR}|a ${line}" "${RISCV_INSTR_INFO}"

        lineno="$(grep -nF "${line}" "${RISCV_INSTR_INFO}" | head -n1 | cut -d: -f1)"
        ext="${filename#RISCVInstrInfoX}"
        ext="${ext%.td}"

        echo "Included instruction table for X${ext} at line ${lineno} in ${RISCV_INSTR_INFO#${PWD}/}"
    fi
done


# Move generated feature .td file into the RISCV target directory.
# Insert include directive in RISCVFeatures.td if not already present.
GENERATED_FEATURE_TD="${WORKDIR}/feature.td"
if [[ -f "${GENERATED_FEATURE_TD}" ]]; then
    RISCV_FEATURES_FRAGMENT="${RISCV_TARGET_DIR}/RISCVFeaturesXpulp.td"
    RISCV_FEATURES_INCLUDE='include "RISCVFeaturesXpulp.td"'

    mv "${GENERATED_FEATURE_TD}" "${RISCV_FEATURES_FRAGMENT}"
    echo "Generated feature table at ${RISCV_FEATURES_FRAGMENT#${PWD}/}"

    if ! grep -qF "${RISCV_FEATURES_INCLUDE}" "${RISCV_FEATURES}"; then
        sed -i "\|${RISCV_FEATURES_ANCHOR}|i ${RISCV_FEATURES_INCLUDE}" "${RISCV_FEATURES}"

        lineno="$(grep -nF "${RISCV_FEATURES_INCLUDE}" "${RISCV_FEATURES}" | head -n1 | cut -d: -f1)"
        echo "Included feature table at line ${lineno} in ${RISCV_FEATURES#${PWD}/}"
    fi
fi

# Convert an extension name like "sflt_b" to CamelCase "XsfltB" matching
# llvm_utils.py's _ext_to_camel("x" + ext_name).
_ext_to_camel() {
    local input="x${1}"
    echo "${input}" | python3 -c "
import re, sys
s = sys.stdin.read().strip()
parts = [p for p in re.split(r'[^0-9A-Za-z]+', s) if p]
print(''.join(p[0].upper() + p[1:] for p in parts))
"
}

# Insert disassembler decode entries in RISCVDisassembler.cpp if not already present.
# Entries are added to the DecoderList32 array, before the Standard Extensions section.
for ((idx = ${#EXT_NAMES[@]} - 1; idx >= 0; idx--)); do
    ext="${EXT_NAMES[idx]}"
    xext="$(_ext_to_camel "${ext}")"
    feature_name="FeatureVendor${xext}"
    line="    {DecoderTable${ext}32, {RISCV::${feature_name}}, \"PULP X${ext} extensions\"},"

    if grep -qF "${line}" "${RISCV_DISASSEMBLER}"; then
        continue
    fi

    sed -i "\|${RISCV_DISASSEMBLER_ANCHOR}|a\\
${line}
" "${RISCV_DISASSEMBLER}"

    lineno="$(grep -nF "${line}" "${RISCV_DISASSEMBLER}" | head -n1 | cut -d: -f1)"
    echo "Inserted disassembler entry for X${ext} at line ${lineno} in ${RISCV_DISASSEMBLER#${PWD}/}"
done

# Append only undefined generated CSRs to RISCVSystemOperands.td.
GENERATED_CSR_TD="${WORKDIR}/csr.td"

if [[ -f "${GENERATED_CSR_TD}" ]]; then
    CSR_APPEND_TMP="${WORKDIR}/undefined-csrs.td"
    : > "${CSR_APPEND_TMP}"

    while IFS= read -r line; do
        # Match generated lines of the form:
        #   def SysReg_FOO : SysReg<"foo", 0x123>;
        # Also accepts anonymous defs:
        #   def : SysReg<"foo", 0x123>;
        if [[ "${line}" =~ SysReg\<\"([^\"]+)\"[[:space:]]*,[[:space:]]*(0x[0-9A-Fa-f]+)\> ]]; then
            csr_name="${BASH_REMATCH[1]}"
            csr_encoding="${BASH_REMATCH[2]}"

            # Skip if LLVM already defines this CSR mnemonic as a primary name,
            # alternate name, or deprecated name.
            if grep -qE "SysReg<\"${csr_name}\"[[:space:]]*," "${RISCV_SYSTEM_OPERANDS}" ||
               grep -qE "AltName[[:space:]]*=[[:space:]]*\"${csr_name}\"" "${RISCV_SYSTEM_OPERANDS}" ||
               grep -qE "DeprecatedName[[:space:]]*=[[:space:]]*\"${csr_name}\"" "${RISCV_SYSTEM_OPERANDS}"; then
                continue
            fi

            # Remove any upstream entry that occupies the same encoding, so PULP
            # names are the unambiguous canonical names for those addresses.
            if grep -qE "SysReg<\"[^\"]+\"[[:space:]]*,[[:space:]]*${csr_encoding}\>" "${RISCV_SYSTEM_OPERANDS}"; then
                conflict="$(grep -oE "\"[^\"]+\"[[:space:]]*,[[:space:]]*${csr_encoding}" "${RISCV_SYSTEM_OPERANDS}" | head -1 | awk -F'"' '{print $2}')"
                sed -i "\|SysReg<\"${conflict}\"[[:space:]]*,[[:space:]]*${csr_encoding}\>|d" "${RISCV_SYSTEM_OPERANDS}"
                echo "Removed conflicting upstream CSR '${conflict}' at ${csr_encoding} in favour of '${csr_name}'"
            fi

            echo "${line}" >> "${CSR_APPEND_TMP}"
        fi
    done < "${GENERATED_CSR_TD}"

    if [[ -s "${CSR_APPEND_TMP}" ]]; then
        {
            echo ""
            echo "//===----------------------------------------------------------------------===//"
            echo "// Generated custom CSRs from riscv-opcodes"
            echo "//===----------------------------------------------------------------------===//"
            echo ""
            cat "${CSR_APPEND_TMP}"
        } >> "${RISCV_SYSTEM_OPERANDS}"

        echo "Appended $(wc -l < "${CSR_APPEND_TMP}") undefined CSR definitions to ${RISCV_SYSTEM_OPERANDS#${PWD}/}"
    fi
fi
