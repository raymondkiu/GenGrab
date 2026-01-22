#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# GenGrab: Download bacterial genomes from public databases with metadata
# This program automatically renames all genome assemblies with strain names,
# host, country and isolation source, and related metadata.
#
# Options:
# -s  Species name (required)
# -g  Genome assembly level (optional, default = ALL)
# -n  Number of genomes to download (optional, default = all)
# -d  Database: RefSeq or GenBank (default = RefSeq)
# -r  Randomise: whether to randomise the order of genome downloading (default=no)
###############################################################################
# Author: Raymond Kiu r.k.o.kiu@bham.ac.uk
# Version: 2026.1
# Thank you for using GenGrab!
# Note: Use this at your own risk, did not test this on MacOS.
###############################################################################
usage() {
  echo ""
  echo "GenGrab: Download bacterial genomes from public databases with metadata"
  echo ""
  echo "USAGE:" 
  echo "  $0 -s \"Genus species\" [-g \"assembly_level\"] [-n NUM_GENOMES] [-d DATABASE]"
  echo "OPTIONS:"
  echo "  -s  Species name (required), e.g., \"Enterococcus faecalis\""
  echo "  -g  Genome assembly level (optional, default=ALL)"
  echo "         Options: Complete Genome, Chromosome, Scaffold, Contig, etc."
  echo "  -n  Number of genomes to download (optional, default=all)"
  echo "  -r  Randomise the genome download order (yes or no, default=no)"
  echo "  -d  Database to use: RefSeq or GenBank (optional, default=RefSeq)"
  echo ""
  echo "  e.g. $0 -s "Bifidobacterium bifidum" -n 200 -d RefSeq"
  echo ""
  echo "AUTHOR:"
  echo "  Raymond Kiu r.k.o.kiu@bham.ac.uk"
  echo "VERSION:"
  echo "  2026.1"
  echo ""
exit 1
}
SPECIES=""
GENOME_LEVEL="ALL"
NUM_GENOMES=${NUM_GENOMES:-0}  # default to 0 = all
DATABASE="RefSeq"
RANDOMIZE="no"   # default = no

while getopts ":s:g:n:d:r:" opt; do
  case $opt in
    s) SPECIES="$OPTARG" ;;
    g) GENOME_LEVEL="$OPTARG" ;;
    n) NUM_GENOMES="$OPTARG" ;;
    d) DATABASE="$OPTARG" ;;
    r) RANDOMIZE="$OPTARG" ;;
    *) usage ;;  
esac
done

[[ -z "$SPECIES" ]] && usage

# -----------------------------
# Check if xmllint is installed
# -----------------------------
if ! command -v xmllint &>/dev/null; then
    echo "[ERROR] 'xmllint' is required for metadata extraction (Step 7) but was not found."
    echo "Install it: Debian/Ubuntu: sudo apt-get install libxml2-utils"
    echo "RedHat/CentOS/Fedora: sudo yum install libxml2"
    exit 1
fi

# Step 1: set URLs based on database
if [[ "$DATABASE" == "RefSeq" ]]; then
    SUMMARY_URL="https://ftp.ncbi.nlm.nih.gov/genomes/refseq/bacteria/assembly_summary.txt"
elif [[ "$DATABASE" == "GenBank" ]]; then
    SUMMARY_URL="https://ftp.ncbi.nlm.nih.gov/genomes/genbank/bacteria/assembly_summary.txt"
else
    echo "[ERROR] Database must be RefSeq or GenBank"
    exit 1
fi
echo "[1/10] URLs of $DATABASE set up"

###############################################################################
# Step 2: Prepare directories
###############################################################################
SAFE_SPECIES=$(echo "$SPECIES" | tr ' ' '_')
BASE_DIR="${SAFE_SPECIES}_${DATABASE}"
GENOME_DIR="${BASE_DIR}/genomes"
META_DIR="${BASE_DIR}/metadata"

if [[ -d "$BASE_DIR" ]]; then
  echo "[ERROR] Directory $BASE_DIR already exists. Aborting to avoid overwrite."
  exit 1
fi

mkdir -p "$GENOME_DIR" "$META_DIR"

echo "[2/10] Directories set up"
###############################################################################
# Step 3: Download assembly summary
###############################################################################
SUMMARY_FILE="${META_DIR}/assembly_summary.txt"
echo "[3/10] Downloading assembly summary for $DATABASE..."
wget -q -O "$SUMMARY_FILE" "$SUMMARY_URL"
echo "[3/10] Assembly summary for $DATABASE downloaded"
###############################################################################
# Step 4: Filter assemblies
###############################################################################
echo "[4/10] Filtering assemblies for: $SPECIES"

if [[ "$GENOME_LEVEL" == "ALL" ]]; then
    # ALL genome levels
    awk -F '\t' -v species="$SPECIES" '
        NR>1 && $8==species && $20!="na" && $9!="" && $9!="na" {
            OFS="\t"; print $20,$9,$12
        }
    ' "$SUMMARY_FILE" > "${META_DIR}/ftp_paths.txt"

    # Full metadata for reference
    awk -F '\t' -v species="$SPECIES" '
        NR==1 || ($8==species && $9!="" && $9!="na") {print}
    ' "$SUMMARY_FILE" > "${META_DIR}/${SAFE_SPECIES}_metadata.tsv"

else
    # Specific genome level
    awk -F '\t' -v species="$SPECIES" -v level="$GENOME_LEVEL" '
        NR>1 && $8==species && $12==level && $20!="na" && $9!="" && $9!="na" {
            OFS="\t"; print $20,$9,$12
        }
    ' "$SUMMARY_FILE" > "${META_DIR}/ftp_paths.txt"

    awk -F '\t' -v species="$SPECIES" -v level="$GENOME_LEVEL" '
        NR==1 || ($8==species && $12==level && $9!="" && $9!="na") {print}
    ' "$SUMMARY_FILE" > "${META_DIR}/${SAFE_SPECIES}_metadata.tsv"
fi
echo "[4/10] Filtering done"
###############################################################################
# Step 5: Limit and optionally randomize genomes
###############################################################################
echo "[5/10] Getting a list of genome assemblies to download..."
FTP_FILE="${META_DIR}/ftp_paths.txt"
LIMITED_FILE="${META_DIR}/ftp_paths_limited.txt"

# Ensure file exists and is not empty
if [[ ! -s "$FTP_FILE" ]]; then
    echo "[ERROR] No genomes found to download. Check species name and genome level."
    exit 1
fi

# Normalize line endings (remove CR from Windows files)
tr -d '\r' < "$FTP_FILE" > "${FTP_FILE}.clean"
mv "${FTP_FILE}.clean" "$FTP_FILE"

# Count available genomes
LINES=$(wc -l < "$FTP_FILE")

# Limit number of genomes if requested
if [[ "$NUM_GENOMES" -gt 0 ]]; then
    # Ensure NUM_GENOMES <= available lines
    if [[ "$NUM_GENOMES" -gt "$LINES" ]]; then
        echo "[WARN] Requested $NUM_GENOMES genomes but only $LINES available. Selecting all."
        NUM_GENOMES=$LINES
    fi

    if [[ "$RANDOMIZE" == "yes" ]]; then
        echo "[INFO] Randomizing genomes before selecting $NUM_GENOMES"

        # Safe shuffle: break pipeline to avoid pipefail issues
        TMP_SHUF="${META_DIR}/ftp_paths_shuf.txt"
        shuf "$FTP_FILE" > "$TMP_SHUF"
        head -n "$NUM_GENOMES" "$TMP_SHUF" > "$LIMITED_FILE"
        rm -f "$TMP_SHUF"

    else
        echo "[INFO] Selecting first $NUM_GENOMES genomes (no randomization)"
        head -n "$NUM_GENOMES" "$FTP_FILE" > "$LIMITED_FILE"
    fi

    # Safety check
    if [[ ! -s "$LIMITED_FILE" ]]; then
        echo "[ERROR] No genomes selected after limiting/randomization."
        exit 1
    fi

    # Replace original FTP file with limited/randomized subset
    mv "$LIMITED_FILE" "$FTP_FILE"
fi

# Count final genomes
COUNT=$(wc -l < "$FTP_FILE")
echo "[5/10] Found $COUNT assemblies to download with valid strain names"

###############################################################################
# Step 6: Download genomes
###############################################################################
echo "[6/10] Downloading genome FASTA files..."
i=0
while IFS=$'\t' read -r ftp strain biosample; do
    # trim leading/trailing spaces
    ftp=$(echo "$ftp" | xargs)
    strain=$(echo "$strain" | xargs)
    biosample=$(echo "$biosample" | xargs)

    # skip invalid lines
    [[ -z "$ftp" || -z "$strain" || "$strain" == "na" || -z "$biosample" || "$biosample" == "na" ]] && continue

    i=$((i+1))
    # clean strain
    strain_clean=$(echo "$strain" | sed 's/^strain=//')
    SAFE_STRAIN=$(echo "$strain_clean" | tr -d "'" | tr -d '"' | tr ' /,()' '____' | tr -s '_')

    NEW_NAME="${SAFE_SPECIES}_${SAFE_STRAIN}.fna"
    DEST_FILE="${GENOME_DIR}/${NEW_NAME}"

    base=$(basename "$ftp")
    file="${base}_genomic.fna.gz"
    url=${ftp/ftp:/https:}/$file

    echo "($i/$COUNT genomes) Downloading and processing: $NEW_NAME"

    if wget -q -c -O "${GENOME_DIR}/${file}" "$url"; then
        gunzip -f "${GENOME_DIR}/${file}" || { echo "[WARN] Failed to gunzip $file"; continue; }
        mv "${GENOME_DIR}/${file%.gz}" "$DEST_FILE"
    else
        echo "[WARN] Failed to download $url"
        continue
    fi
done < "${META_DIR}/ftp_paths.txt"

DOWNLOAD_COUNT=$(ls -1 "$GENOME_DIR"/*.fna 2>/dev/null | wc -l)
if [[ "$DOWNLOAD_COUNT" -eq 0 ]]; then
    echo "[ERROR] No genomes downloaded for species: $SPECIES"
    rm -rf "$GENOME_DIR" "$META_DIR"
    exit 1
else
    echo "[6/10] Successfully downloaded $DOWNLOAD_COUNT genomes."
fi

###############################################################################
# Step 7: Clean filenames
###############################################################################
echo "[7/10] Cleaning FASTA filenames..."
for f in "$GENOME_DIR"/*.fna; do
    cleanname=$(basename "$f" | tr -d "'")
    [[ "$cleanname" != "$(basename "$f")" ]] && mv "$f" "$GENOME_DIR/$cleanname"
done
echo "[7/10] Done."
###############################################################################
# Step 8: Fetch host, isolation_source, country for downloaded genomes
###############################################################################
echo "[8/10] Extracting metadata:host, isolation_source, country..."
META_FILE="${META_DIR}/${SAFE_SPECIES}_metadata_with_source.tsv"
CACHE_DIR="${META_DIR}/.biosample_cache"
mkdir -p "$CACHE_DIR"

fetch_biosample_xml() {
    local biosample="$1"
    local cache_file="$CACHE_DIR/${biosample}.xml"
    [[ -s "$cache_file" ]] && { cat "$cache_file"; return; }
    local url="https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=biosample&id=${biosample}&retmode=xml"
    [[ -n "${NCBI_API_KEY:-}" ]] && url="${url}&api_key=${NCBI_API_KEY}"
    curl -sS --retry 3 --retry-delay 2 "$url" -o "$cache_file"
    sleep 0.34
    cat "$cache_file"
}

extract_attr() {
    local xml="$1"
    local xpath="$2"
    echo "$xml" | xmllint --xpath "$xpath" - 2>/dev/null | sed 's/^[ \t]*//;s/[ \t]*$//' || true
}

# Header
echo -e "$(head -1 "${META_DIR}/${SAFE_SPECIES}_metadata.tsv")\thost\tisolation_source\tcountry" > "$META_FILE"

# Iterate over downloaded genomes only
for f in "$GENOME_DIR"/*.fna; do
    fname=$(basename "$f" .fna)
    match=$(awk -F'\t' -v fname="$fname" -v species="$SAFE_SPECIES" '
    NR>1 {
        strain = ($9 != "" ? $9 : "NA")
        gsub(/^strain=/,"",strain)
        safe_strain = species"_"strain
        gsub(/[ \/,\x27()]+/,"_",safe_strain)
        if (fname == safe_strain) { print; exit }
    }' "${META_DIR}/${SAFE_SPECIES}_metadata.tsv")
    [[ -z "$match" ]] && { echo "[WARN] No metadata for $fname"; continue; }
    assembly=$(echo "$match" | cut -f1)
    project=$(echo "$match" | cut -f2)
    biosample=$(echo "$match" | cut -f3)
    rest=$(echo "$match" | cut -f4-)
    [[ -z "$biosample" || "$biosample" == "na" ]] && continue
    printf "[INFO] Fetching metadata for BioSample: %s\n" "$biosample"
    xml=$(fetch_biosample_xml "$biosample")
    host=$(extract_attr "$xml" "string(//Attribute[contains(translate(@attribute_name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'host')])")
    isolation=$(extract_attr "$xml" "string(//Attribute[contains(translate(@attribute_name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'isolation')])")
    country=$(extract_attr "$xml" "string(//Attribute[contains(translate(@attribute_name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'country') or contains(translate(@attribute_name,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'),'geo')])")
    host="${host:-NA}"
    isolation="${isolation:-NA}"
    country="${country:-NA}"
    echo -e "${assembly}\t${project}\t${biosample}\t${rest}\t${host}\t${isolation}\t${country}" >> "$META_FILE"
done
echo "[8/10] Done."
###############################################################################
# Step 9: Create final metadata file with only desired columns
###############################################################################
echo "[9/10] Generate final metadata file."

META_FINAL="${META_DIR}/${SAFE_SPECIES}_metadata_final.tsv"

# Get actual header from the second line of assembly_summary.txt
HEADER_LINE=$(head -2 "$SUMMARY_FILE" | tail -1)
# We split header by tab and pick the required columns
awk -F'\t' -v OFS='\t' -v header="$HEADER_LINE" '
BEGIN {
    # print selected header columns + host/isolation/country
    print "assembly_accession","bioproject","biosample","refseq_category","taxid","organism_name","infraspecific_name","assembly_level","host","isolation_source","country","ftp_path","asm_submitter"
}
NR>1 {
    # Extract only columns: 1,2,3,6,7,8,9,12,39,40,41,20,17
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $1,$2,$3,$6,$7,$8,$9,$12,$39,$40,$41,$20,$17
}' "$META_FILE" > "$META_FINAL"

echo "[9/10] Final metadata saved to: $META_FINAL"
###############################################################################
# Step 10: Cleaning up
###############################################################################
echo "[10/10] Cleaning up..."

files=(
  "${META_DIR}/${SAFE_SPECIES}_metadata.tsv"
  "${META_DIR}/${SAFE_SPECIES}_metadata_with_source.tsv"
  "${META_DIR}/ftp_paths.txt"
  "${META_DIR}/assembly_summary.txt"
)

for file in "${files[@]}"; do
  if [[ -e "$file" ]]; then
    rm "$file"
    echo "[INFO] $file removed"
  else
    echo "[INFO] $file not found, skipping"
  fi
done

# Step 11: summary

echo "[10/10] Done."
echo "Genomes directory : $GENOME_DIR"
echo "Metadata directory: $META_DIR"
echo "Metadata tsv saved to: $META_FINAL"
echo "Thank you for using GenGrab! Have a good day!"
echo ""
