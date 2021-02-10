dir1=~/fastq_trim
dir2=~/bam
dir3=~/flagstat
dir5=~/bam_realn
dir6=~/vcf

##### trimmomatic 0.36
java -jar trimmomatic-0.36.jar PE -threads 4 -phred33 "$dir"/"$name"_1.fastq.gz "$dir"/"$name"_2.fastq.gz "$dir"/"$name"_1_paired.fastq.gz "$dir"/"$name"_1_unpaired.fastq.gz "$dir"/"$name"_2_paired.fastq.gz "$dir"/"$name"_2_unpaired.fastq.gz ILLUMINACLIP:/Trimmomatic-0.36/adapters/TruSeq3-PE-2.fa:2:30:10 LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

##### samtools 1.7
samtools faidx Gmax_275_v2.0.softmasked.fa

##### bwa 0.7.17
## bwa index
bwa index -p Gmax_275_v2.0 Gmax_275_v2.0.softmasked.fa
## bwa aln
bwa aln -t 8 Gmax_275_v2.0 "$dir1"/"$name"_1_paired.fastq.gz > "$dir1"/"$name"_1_paired.sai
bwa aln -t 8 Gmax_275_v2.0 "$dir1"/"$name"_2_paired.fastq.gz > "$dir1"/"$name"_2_paired.sai

## bwa sampe
bwa sampe Gmax_275_v2.0 "$dir1"/"$name"_1_paired.sai "$dir1"/"$name"_2_paired.sai "$dir1"/"$name"_1_paired.fastq.gz "$dir1"/"$name"_2_paired.fastq.gz | samtools view -bS - | samtools sort -T tempsam"$name" -@8 -o "$dir2"/"$name".sorted.bam

## sort bam index
samtools index "$dir2"/"$name".sorted.bam

## samtools flagstat
samtools flagstat "$dir2"/"$name".sorted.bam > "$dir3"/"$name".txt

##### picard 2.18.3
## FixMate information / picard-tools
java -Xmx4g -jar picard.jar FixMateInformation I="$dir2"/"$name".sorted.bam O="$dir5"/"$name".fxmt.bam SO=coordinate CREATE_INDEX=TRUE VALIDATION_STRINGENCY=SILENT

## Mark duplicate reads
java -Xmx4g -jar picard.jar MarkDuplicates I="$dir5"/"$name".fxmt.bam O="$dir5"/"$name".mkdup.bam M="$dir5"/"$name".metrics.txt CREATE_INDEX=TRUE REMOVE_DUPLICATES=true VALIDATION_STRINGENCY=SILENT

## Add or replace read groups
java -Xmx4g -jar picard.jar AddOrReplaceReadGroups I="$dir5"/"$name".mkdup.bam O="$dir5"/"$name".addrep.bam RGPL=illumina RGLB=lib1 RGPU=unit1 RGSM="$name" RGID="$name" CREATE_INDEX=TRUE VALIDATION_STRINGENCY=SILENT

### create dict file
java -Xmx4g -jar picard.jar CreateSequenceDictionary REFERENCE=Gmax_275_v2.0.softmasked.fa OUTPUT=Gmax_275_v2.0.softmasked.dict

rm "$dir5"/"$name".fxmt.bam
rm "$dir5"/"$name".fxmt.bai
rm "$dir5"/"$name".mkdup.bam
rm "$dir5"/"$name".mkdup.bai
rm "$dir5"/"$name".metrics.txt

##### GATK 4.0.4.0
#HaplotypeCaller
gatk --java-options "-Xmx4g" HaplotypeCaller -R Gmax_275_v2.0.softmasked.fa -I "$dir5"/"$name".addrep.bam -O "$dir6"/"$name".g.vcf.gz -ERC GVCF

#GenomicsDBImport
gatk --java-options "-Xmx16g" GenomicsDBImport -V A.g.vcf.gz -V B.g.vcf.gz -V C.g.vcf.gz --genomicsdb-workspace-path database_"$Chr" --intervals "$Chr"

#GenotypeGVCFs
gatk GenotypeGVCFs -R Gmax_275_v2.0.softmasked.fa -V gendb://database_"$Chr" -G StandardAnnotation --new-qual -O Gm_"$Chr".vcf.gz