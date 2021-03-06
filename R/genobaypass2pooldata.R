#' Convert BayPass read count and haploid pool size input files into a pooldata object
#' @param genobaypass.file The name (or a path) of the BayPass read count file (see the BayPass manual \url{http://www1.montpellier.inra.fr/CBGP/software/baypass/})
#' @param poolsize.file The name (or a path) of the BayPass (haploid) pool size file (see the BayPass manual \url{http://www1.montpellier.inra.fr/CBGP/software/baypass/})
#' @param poolnames A character vector with the names of pool
#' @param min.cov.per.pool Minimal allowed read count (per pool). If at least one pool is not covered by at least min.cov.perpool reads, the position is discarded
#' @param max.cov.per.pool Maximal allowed read count (per pool). If at least one pool is covered by more than min.cov.perpool reads, the position is discarded
#' @param min.maf Minimal allowed Minor Allele Frequency (computed from the ratio overal read counts for the reference allele over the read coverage)
#' @param nlines.per.readblock Number of Lines read simultaneously. Should be adapted to the available RAM.
#' @return A pooldata object containing 7 elements:
#' \enumerate{
#' \item "refallele.readcount": a matrix with nsnp rows and npools columns containing read counts for the reference allele (chosen arbitrarily) in each pool
#' \item "readcoverage": a matrix with nsnp rows and npools columns containing read coverage in each pool
#' \item "snp.info": a matrix with nsnp rows and four columns containing respectively the contig (or chromosome) name (1st column) and position (2nd column) of the SNP; the allele in the reference assembly (3rd column); the allele taken as reference in the refallele matrix.readcount matrix (4th column); and the alternative allele (5th column)
#' \item "poolsizes": a vector of length npools containing the haploid pool sizes
#' \item "poolnames": a vector of length npools containing the names of the pools
#' \item "nsnp": a scalar corresponding to the number of SNPs
#' \item "npools": a scalar corresponding to the number of pools
#' }
#' @examples
#'  make.example.files(writing.dir=tempdir())
#'  pooldata=popsync2pooldata(sync.file=paste0(tempdir(),"/ex.sync.gz"),poolsizes=rep(50,15))
#'  pooldata2genobaypass(pooldata=pooldata,writing.dir=tempdir())
#'  pooldata=genobaypass2pooldata(genobaypass.file=paste0(tempdir(),"/genobaypass"),
#'                                poolsize.file=paste0(tempdir(),"/poolsize"))
#' @export
genobaypass2pooldata<-function(genobaypass.file="",poolsize.file="",poolnames=NA,min.cov.per.pool=-1,max.cov.per.pool=1e6,min.maf=-1,nlines.per.readblock=1000000){
if(nchar(genobaypass.file)==0){stop("ERROR: Please provide the name of the read count data file (in BayPass format)")}
if(nchar(poolsize.file)==0){stop("ERROR: Please provide the name of the file containing haploid pool sizes (in BayPass format)")}
poolsizes=as.numeric(read.table(file(poolsize.file))[1,])

file.con=file(genobaypass.file,open="r") 
##
tmp.data=scan(file=file.con,nlines = 1,what="character",quiet=TRUE)
npools=length(tmp.data)/2
if(npools!=length(poolsizes)){stop("The number of pools in the Pool sizes file (number of elements of the first line) is not the same as the one in the Read count file (half the number of columns). Check both input files are in a valid BayPass format")}
close(file.con)
if(sum(is.na(poolnames))>0){
  poolnames=paste0("Pool",1:npools)
}else{
  poolnames=as.character(poolnames)
  if(length(poolnames)!=npools){stop("ERROR: The number of pools derived form the BayPass input files is different from the length of vector of pool names")}
}
###
file.con=file(genobaypass.file,open="r")
continue.reading=TRUE
nlines.read=0
time1=proc.time()
pos.all2=(1:npools)*2 ; pos.all1=pos.all2-1
while(continue.reading){
 tmp.data=matrix(as.numeric(scan(file=file.con,nlines = nlines.per.readblock,what="character",quiet=TRUE)),ncol=2*npools,byrow=T)  
 if(length(tmp.data)<nlines.per.readblock){continue.reading=FALSE}
 npos=nrow(tmp.data)
 if(npos>1){
  tmp.Y=tmp.data[,pos.all1] ; tmp.N=tmp.Y+tmp.data[,pos.all2]
  rm(tmp.data)
  ##filtres sur couverture et maf
  tmp.maf=0.5-abs(0.5-rowSums(tmp.Y)/rowSums(tmp.N))
  dum.sel=(rowSums(tmp.N>=min.cov.per.pool)==npools) & (rowSums(tmp.N<=max.cov.per.pool)==npools) & (tmp.maf>min.maf)
  tmp.Y=tmp.Y[dum.sel,] ; tmp.N=tmp.N[dum.sel,] 
  if(nlines.read==0){
   data.Y=tmp.Y ; data.N=tmp.N
  }else{
   data.Y=rbind(data.Y,tmp.Y) ; data.N=rbind(data.N,tmp.N)
 }
 nlines.read=nlines.read+npos
 cat(nlines.read/1000000,"millions lines processed in",round((proc.time()-time1)[1]/60,2)," min.; ",nrow(data.Y),"SNPs found\n")
}
}
close(file.con)

res<-new("pooldata")
res@npools=npools
res@nsnp=nrow(data.Y)
res@refallele.readcount=data.Y
rm(data.Y)
res@readcoverage=data.N
rm(data.N)
#res@snp.info=snpdet
#rm(snpdet)
res@poolsizes=poolsizes
res@poolnames=poolnames

cat("Data consists of",res@nsnp,"SNPs for",res@npools,"Pools\n")
return(res)
}
