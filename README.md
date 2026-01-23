# GenomeFetch
<img src="https://github.com/raymondkiu/GenomeFetch/blob/85f9259023fc0694138f2779bd279c7dea0a6ffc/Files/GenomeFetchLogo.png" alt="GenomeFetch logo" width="300"/>
GenomeFetch: a fast, user-friendly bacterial genome aasembly retrieval tool for RefSeq and GenBank.
<br>This user-friendly genome retrievel tool is written in Bash and should run in most Linux OS, not tested in MacOS though. It is engineered to download bacterial genome assemblies from RefSeq or GenBank together with important metadata such as isolation source, country, host and related ftp for downloading, as well as assembly assession, bioproject and biosample etc. All downloaded genome assemblies (fasta) will be renamed according to genus, species and strain names. All in one. It will save you time and efforts! You can also randomise the download order as well. No complex installation needed just copy/download the script and there you go! 

## Usage
GenomeFetch has not been tested to download viral/eukaryotic genome assemblies although in theory it should work the same.
```
GenomeFetch: a fast, user-friendly bacterial genome aasembly retrieval tool for RefSeq and GenBank

USAGE:
  $ ./GenomeFetch.sh -s "Genus species" [-g "assembly_level"] [-n NUM_GENOMES] [-d DATABASE]
OPTIONS:
  -s  Species name (required), e.g., "Enterococcus faecalis"
  -g  Genome assembly level (optional, default=ALL)
         Options: Complete Genome, Chromosome, Scaffold, Contig, etc.
  -n  Number of genomes to download (optional, default=all)
  -r  Randomise the genome download order (yes or no, default=no)
  -d  Database to use: RefSeq or GenBank (optional, default=RefSeq)

  e.g. ./GenomeFetch.sh -s Bifidobacterium bifidum -n 200 -d RefSeq

AUTHOR:
  Raymond Kiu r.k.o.kiu@bham.ac.uk
VERSION:
  2026.1
```
For example,
```
$ ./GenomeFetch.sh -s "Bifidobacterium longum" -n 4 -r yes -d RefSeq
[1/10] URLs of RefSeq set up
[2/10] Directories set up
[3/10] Downloading assembly summary for RefSeq...
[3/10] Assembly summary for RefSeq downloaded
[4/10] Filtering assemblies for: Bifidobacterium longum
[4/10] Filtering done
[5/10] Getting a list of genome assemblies to download...
[INFO] Randomizing genomes before selecting 4
[5/10] Found 4 assemblies to download with valid strain names
[6/10] Downloading genome FASTA files...
(1/4 genomes) Downloading and processing: Bifidobacterium_longum_DS15_3.fna
(2/4 genomes) Downloading and processing: Bifidobacterium_longum_RTP31015st2_H2_RTP31015_201113.fna
(3/4 genomes) Downloading and processing: Bifidobacterium_longum_MSK.13.10.fna
(4/4 genomes) Downloading and processing: Bifidobacterium_longum_LTBL16.fna
[6/10] Successfully downloaded 4 genomes.
[7/10] Cleaning FASTA filenames...
[7/10] Done.
[8/10] Extracting metadata:host, isolation_source, country...
[INFO] Fetching metadata for BioSample: SAMN06464097
[INFO] Fetching metadata for BioSample: SAMN10473362
[INFO] Fetching metadata for BioSample: SAMN19731861
[INFO] Fetching metadata for BioSample: SAMN41371914
[8/10] Done.
[9/10] Generate final metadata file.
[9/10] Final metadata saved to: Bifidobacterium_longum_RefSeq/metadata/Bifidobacterium_longum_metadata_final.tsv
[10/10] Cleaning up...
[INFO] Bifidobacterium_longum_RefSeq/metadata/Bifidobacterium_longum_metadata.tsv removed
[INFO] Bifidobacterium_longum_RefSeq/metadata/Bifidobacterium_longum_metadata_with_source.tsv removed
[INFO] Bifidobacterium_longum_RefSeq/metadata/ftp_paths.txt removed
[INFO] Bifidobacterium_longum_RefSeq/metadata/assembly_summary.txt removed
[10/10] Done.
Genomes directory : Bifidobacterium_longum_RefSeq/genomes
Metadata directory: Bifidobacterium_longum_RefSeq/metadata
Metadata tsv saved to: Bifidobacterium_longum_RefSeq/metadata/Bifidobacterium_longum_metadata_final.tsv
Thank you for using GenomeFetch! Have a good day!
```
For the metadata, you shall see:
```
assembly_accession      bioproject      biosample       refseq_category taxid   organism_name   infraspecific_name      assembly_level  host    isolation_source        country ftp_path        asm_submitter
GCF_003094855.1 PRJNA224116     SAMN06464097    216816  216816  Bifidobacterium longum  strain=DS15_3   Contig  Homo sapiens    Commercial dietary supplements  USA:MD  https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/094/855/GCF_003094855.1_ASM309485v1    USFDA
GCF_009728915.1 PRJNA224116     SAMN10473362    216816  216816  Bifidobacterium longum  strain=LTBL16   Complete Genome Homo sapiens    NA      China: GuangXi  https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/009/728/915/GCF_009728915.1_ASM972891v1    GuangXi University
GCF_019131655.1 PRJNA224116     SAMN19731861    216816  216816  Bifidobacterium longum  strain=MSK.13.10        Contig  Homo sapiens    NA      USA:New York    https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/019/131/655/GCF_019131655.1_ASM1913165v1   University of Chicago
GCF_039753935.1 PRJNA224116     SAMN41371914    216816  216816  Bifidobacterium longum  strain=RTP31015st2_H2_RTP31015_201113   Scaffold        Homo sapiens    NA      USA: New York   https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/039/753/935/GCF_039753935.1_ASM3975393v1   Icahn School of Medicine at Mount Sinai
```
## Issues
Please report any issues to the [issues page](https://github.com/raymondkiu/GenomeFetch/issues).

## Citation
If you use GenomeFetch for results in your publication, please cite:
* Kiu R, *GenomeFetch: a fast, user-friendly bacterial genome aasembly retrieval tool for RefSeq and GenBank*, **GitHub** `https://github.com/raymondkiu/GenomeFetch`

## License
GenomeFetch is a free software licensed under [GPLv3](https://github.com/raymondkiu/GenomeFetch/blob/master/LICENSE)

## Author
Raymond Kiu | r.k.o.kiu@bham.ac.uk
