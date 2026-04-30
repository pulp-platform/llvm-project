#!/usr/bin/env bash
# Generate LLVM TableGen instruction definitions for Snitch/PULP custom extensions.
#
# Reads the extension list from riscv-opcodes/pulp-extensions.txt,
# drives the riscv-opcodes submodule to produce inst.<extname>.td files and csr.td,
# copies instruction files into the RISCV Target directory, and appends only
# previously undefined CSRs to RISCVSystemOperands.td.
set -euo pipefail

RISCV_OPCODES_DIR="${PWD}/riscv-opcodes"
OPCODES_FILE="${RISCV_OPCODES_DIR}/pulp-extensions.txt"

RISCV_TARGET_DIR="${PWD}/llvm/lib/Target/RISCV"
RISCV_INSTR_INFO="${RISCV_TARGET_DIR}/RISCVInstrInfo.td"
RISCV_FEATURES="${RISCV_TARGET_DIR}/RISCVFeatures.td"
RISCV_SYSTEM_OPERANDS="${RISCV_TARGET_DIR}/RISCVSystemOperands.td"
RISCV_ISA_INFO="${PWD}/llvm/lib/Support/RISCVISAInfo.cpp"
RISCV_DISASSEMBLER="${RISCV_TARGET_DIR}/Disassembler/RISCVDisassembler.cpp"

RISCV_INSTR_INFO_ANCHOR='include "RISCVInstrInfoXCV.td"'  # Insert after anchor
RISCV_FEATURES_ANCHOR='// Ventana Extenions'              # Insert before anchor
RISCV_ISA_INFO_ANCHOR='{"xventanacondops", {1, 0}},'      # Insert after anchor
RISCV_DISASSEMBLER_ANCHOR='"CORE-V Immediate Branching custom opcode table");'  # Insert after anchor

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
        python -m riscv_opcodes -llvm --warn-overlap "${OPCODES[@]}"
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

# Append custom extension names to RISCVISAInfo.cpp if not already present.
for ((idx = ${#EXT_NAMES[@]} - 1; idx >= 0; idx--)); do
    ext="x${EXT_NAMES[idx]}"
    line="    {\"${ext}\", {1, 0}},"
    pattern="^[[:space:]]*\\{\"${ext}\", \\{1, 0\\}\\},$"

    if grep -qE "${pattern}" "${RISCV_ISA_INFO}"; then
        continue
    fi

    sed -i "\|${RISCV_ISA_INFO_ANCHOR}|a ${line}" "${RISCV_ISA_INFO}"

    lineno="$(grep -nE "${pattern}" "${RISCV_ISA_INFO}" | head -n1 | cut -d: -f1)"
    echo "Inserted ISA extension ${ext} at line ${lineno} in ${RISCV_ISA_INFO#${PWD}/}"
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

# Insert disassembler decode hooks in RISCVDisassembler.cpp if not already present.
for ((idx = ${#EXT_NAMES[@]} - 1; idx >= 0; idx--)); do
    ext="${EXT_NAMES[idx]}"
    xext="X${ext}"
    feature_name="FeatureVendor${xext^}"
    line1="    TRY_TO_DECODE_FEATURE(RISCV::${feature_name}, DecoderTable${ext}32,"
    line2="                          \"PULP X${ext} custom opcode table\");"

    if grep -qF "${line1}" "${RISCV_DISASSEMBLER}"; then
        continue
    fi

    sed -i "\|${RISCV_DISASSEMBLER_ANCHOR}|a\\
${line2}
" "${RISCV_DISASSEMBLER}"
    sed -i "\|${RISCV_DISASSEMBLER_ANCHOR}|a\\
${line1}
" "${RISCV_DISASSEMBLER}"

    lineno="$(grep -nF "${line1}" "${RISCV_DISASSEMBLER}" | head -n1 | cut -d: -f1)"
    echo "Inserted disassembler hook for X${ext} at line ${lineno} in ${RISCV_DISASSEMBLER#${PWD}/}"
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

            # Skip if LLVM already defines this CSR mnemonic as primary name,
            # alternate name, or deprecated name.
            if grep -qE "SysReg<\"${csr_name}\"[[:space:]]*," "${RISCV_SYSTEM_OPERANDS}" ||
               grep -qE "AltName[[:space:]]*=[[:space:]]*\"${csr_name}\"" "${RISCV_SYSTEM_OPERANDS}" ||
               grep -qE "DeprecatedName[[:space:]]*=[[:space:]]*\"${csr_name}\"" "${RISCV_SYSTEM_OPERANDS}"; then
                continue
            fi

            # Also skip if the encoding already exists with another name.
            # SysRegsList uses Encoding as primary key, so duplicate encodings
            # would break TableGen generation.
            if grep -qE "SysReg<\"[^\"]+\"[[:space:]]*,[[:space:]]*${csr_encoding}\>" "${RISCV_SYSTEM_OPERANDS}"; then
                echo "Skipped CSR ${csr_name} at ${csr_encoding}: encoding already exists"
                continue
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
