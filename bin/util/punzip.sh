#!/bin/bash
#
# Usage:
#
#   punzip.sh http://www.whitehouse.gov/files/disclosures/visitors/WhiteHouse-WAVES-Key-1209.txt
#   (produces WhiteHouse-WAVES-Key-1209.txt and WhiteHouse-WAVES-Key-1209.txt.pml.ttl)
#

usage_message="usage: `basename $0` .zip [.zip ...]" 
if [ $# -lt 1 ]; then
   echo $usage_message 
   exit 1
fi

CSV2RDF4LOD_HOME=${CSV2RDF4LOD_HOME:?"not set; source csv2rdf4lod/source-me.sh"}


# TODO: reimplement this using perl and its unzip module

# bash-3.2$ unzip -l state_combined_ak.zip
# Archive:  state_combined_ak.zip
#   Length     Date   Time    Name
#  --------    ----   ----    ----
#    995758  06-17-10 22:46   AK_ALTERNATIVE_NAME_FILE.CSV
#   1428574  06-17-10 22:47   AK_CONTACT_FILE.CSV
#   2234225  06-17-10 22:46   AK_ENVIRONMENTAL_INTEREST_FILE.CSV
#   3249731  06-17-10 22:46   AK_FACILITY_FILE.CSV
#   1342920  06-17-10 22:47   AK_MAILING_ADDRESS_FILE.CSV
#    312308  06-17-10 22:46   AK_NAICS_FILE.CSV
#   1841847  06-17-10 22:46   AK_ORGANIZATION_FILE.CSV
#    748588  06-17-10 22:46   AK_SIC_FILE.CSV
#    368039  06-17-10 22:47   AK_SUPP_INTEREST_FILE.CSV
#    286881  04-20-10 13:25   Facility State File Documentation 0401 2010.pdf
#  --------                   -------
#  12808871                   10 files

ZIP_LIST_HEADER_LENGTH=3
ZIP_LIST_FOOTER_LENGTH=2

logID=`java edu.rpi.tw.string.NameFactory`
while [ $# -gt 0 ]; do

   zip="$1"
   if [ ! -e $zip ]; then
      echo "$zip does not exist"
      shift
      continue
   fi

   unzipper="unzip"
   if [[ $zip =~ (\.gz$) ]]; then # NOTE: alternative: ${zip#*.} == "gz"
      unzipper="gunzip"
   fi 

   # md5 this script
   # TODO: md5.sh $0
   unzipperPath=`which $unzipper`
   myMD5=""
   unzipMD5=""
   if [ `which md5` ]; then
      # md5 outputs:
      # MD5 (punzip.sh) = ecc71834c2b7d73f9616fb00adade0a4
         myMD5="`md5 $0               | perl -pe 's/^.* = //'`"
      unzipMD5="`md5 $unzipperPath    | perl -pe 's/^.* = //'`"
   elif [ `which md5sum` ]; then
         myMD5="`md5sum $0            | perl -pe 's/\s.*//'`"
      unzipMD5="`md5sum $unzipperPath | perl -pe 's/\s.*//'`"
   else
      echo "`basename $0`: can not find md5 to md5 this script."
   fi
      myMD5=`${CSV2RDF4LOD_HOME}/bin/util/md5.sh  $0`
   unzipMD5="`${CSV2RDF4LOD_HOME}/bin/util/md5.sh $unzipperPath`"
   #echo "punzip.sh's md5: $myMD5"
   #echo "$unzipper's md5: $unzipMD5 ($unzipperPath)"
   
   echo
   echo ---------------------------------- punzip ---------------------------------------

   if [ `man stat | grep 't timefmt' | wc -l` -gt 0 ]; then
      # mac version
      zipModDateTime=`stat -t "%Y-%m-%dT%H:%M:%S%z" $zip | awk '{gsub(/"/,"");print $9}' | sed 's/^\(.*\)\(..\)$/\1:\2/'`
   elif [ `man stat | grep '%y     Time of last modification' | wc -l` -gt 0 ]; then
      # some other unix version
      zipModDateTime=`stat -c "%y" $zip | sed -e 's/ /T/' -e 's/\..* / /' -e 's/ //' -e 's/\(..\)$/:\1/'`
   fi

   #usageDateTime=`date +%Y-%m-%dT%H:%M:%S%z | sed 's/^\(.*\)\(..\)$/\1:\2/'`
   usageDateTime=`dateInXSDDateTime.sh`

   if [ $unzipper == "unzip" ]; then
      listLength=`unzip -l "$zip" | wc -l`
      let tailParam="$listLength-$ZIP_LIST_HEADER_LENGTH"
      let numFiles="$listLength-5"

      # NOTE: the line below ACTUALLY uncompresses the file(s)
      files=`unzip -l "$zip" | tail -$tailParam | head -$numFiles | awk -v zip="$zip" -f $CSV2RDF4LOD_HOME/bin/util/punzip.awk`
   elif [ $unzipper == "gunzip" ]; then
      files=${zip%.*}
   else
      echo "WARNING: no files processed b/c "
      files=""
   fi

   for file in $files #`unzip -l "$zip" | tail -$tailParam | head -$numFiles | awk -v zip="$zip" -f $CSV2RDF4LOD_HOME/bin/util/punzip.awk`
   do
      if [ $unzipper == "gunzip" ]; then
         gunzip -c $zip > $file
      fi

      echo $file came from $zip
      requestID=`java edu.rpi.tw.string.NameFactory`
      extractedFileMD5=`md5.sh $file`

      # Relative paths.
      fileURI="<$file>"
      sourceUsage="<sourceUsage$requestID>"
      nodeSet="<nodeSet$requestID>"
      zipNodeSet="<nodeSet${requestID}_zip_antecedent>"

      echo "@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> ."                   > $file.pml.ttl
      echo "@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> ."                      >> $file.pml.ttl
      echo "@prefix dcterms: <http://purl.org/dc/terms/> ."                              >> $file.pml.ttl
      echo "@prefix nfo:     <http://www.semanticdesktop.org/ontologies/nfo/#> ."        >> $file.pml.ttl
      echo "@prefix pmlp:    <http://inference-web.org/2.0/pml-provenance.owl#> ."       >> $file.pml.ttl
      echo "@prefix pmlj:    <http://inference-web.org/2.0/pml-justification.owl#> ."    >> $file.pml.ttl
      echo "@prefix conv:    <http://purl.org/twc/vocab/conversion/> ."                  >> $file.pml.ttl
      echo "@prefix foaf:    <http://xmlns.com/foaf/0.1/> ."                             >> $file.pml.ttl
      echo "@prefix sioc:    <http://rdfs.org/sioc/ns#> ."                               >> $file.pml.ttl
      echo "@prefix oboro:      <http://obofoundry.org/ro/ro.owl#> ."                    >> $file.pml.ttl
      echo "@prefix oprov:      <http://openprovenance.org/ontology#> ."                 >> $file.pml.ttl
      echo "@prefix hartigprov: <http://purl.org/net/provenance/ns#> ."                  >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      $CSV2RDF4LOD_HOME/bin/util/user-account.sh                                         >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo $fileURI                                                                      >> $file.pml.ttl
      echo "   a pmlp:Information;"                                                      >> $file.pml.ttl
      echo "   pmlp:hasReferenceSourceUsage $sourceUsage;"                               >> $file.pml.ttl
      #echo "   nfo:hasHash <md5_$extractedFileMD5>;"                                     >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      $CSV2RDF4LOD_HOME/bin/util/nfo-filehash.sh "$file"                                 >> $file.pml.ttl
      #echo "<md5_$extractedFileMD5>"                                                     >> $file.pml.ttl
      #echo "   a nfo:FileHash; "                                                         >> $file.pml.ttl
      #echo "   nfo:hashAlgorithm \"md5\";"                                               >> $file.pml.ttl
      #echo "   nfo:hasHash \"$extractedFileMD5\";"                                       >> $file.pml.ttl
      #echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "$sourceUsage"                                                                >> $file.pml.ttl
      echo "   a pmlp:SourceUsage;"                                                      >> $file.pml.ttl
      echo "   pmlp:hasSource        <$zip>;"                                            >> $file.pml.ttl
      echo "   pmlp:hasUsageDateTime \"$usageDateTime\"^^xsd:dateTime;"                  >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "<$zip>"                                                                      >> $file.pml.ttl
      echo "   a pmlp:Source;"                                                           >> $file.pml.ttl
      if [ ${#zipModDateTime} -gt 0 ]; then
      echo "   pmlp:hasModificationDateTime \"$zipModDateTime\"^^xsd:dateTime;"          >> $file.pml.ttl
      fi
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo $nodeSet                                                                      >> $file.pml.ttl
      echo "   a pmlj:NodeSet;"                                                          >> $file.pml.ttl
      echo "   pmlj:hasConclusion $fileURI;"                                             >> $file.pml.ttl
      echo "   pmlj:isConsequentOf ["                                                    >> $file.pml.ttl
      echo "      a pmlj:InferenceStep;"                                                 >> $file.pml.ttl
      echo "      pmlj:hasIndex 0;"                                                      >> $file.pml.ttl
      echo "      pmlj:hasAntecedentList ( $zipNodeSet );"                               >> $file.pml.ttl
      echo "      pmlj:hasSourceUsage     $sourceUsage;"                                 >> $file.pml.ttl
      echo "      pmlj:hasInferenceEngine conv:unzip_sh_md5_$myMD5;"                     >> $file.pml.ttl
      echo "      pmlj:hasInferenceRule   conv:spaceless_unzip;"                         >> $file.pml.ttl
      echo "      oboro:has_agent          `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;">> $file.pml.ttl
      echo "      hartigprov:involvedActor `$CSV2RDF4LOD_HOME/bin/util/user-account.sh --cite`;">> $file.pml.ttl
      echo "   ];"                                                                       >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo $zipNodeSet                                                                   >> $file.pml.ttl
      echo "   a pmlj:NodeSet;"                                                          >> $file.pml.ttl
      echo "   pmlj:hasConclusion <$zip>;"                                               >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "conv:unzip_sh_md5_$myMD5"                                                    >> $file.pml.ttl
      echo "   a pmlp:InferenceEngine, conv:Unzip_sh;"                                   >> $file.pml.ttl
      echo "   dcterms:identifier \"md5_$myMD5\";"                                       >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "conv:Unzip_sh rdfs:subClassOf pmlp:InferenceEngine ."                        >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "conv:unzip_md5_$myMD5"                                                       >> $file.pml.ttl
      echo "   a pmlp:InferenceEngine, conv:Unzip;"                                      >> $file.pml.ttl
      echo "   dcterms:identifier \"md5_$unzipMD5\";"                                    >> $file.pml.ttl
      echo "   nfo:hasHash <md5_$unzipMD5>;"                                             >> $file.pml.ttl
      echo "   dcterms:description \"\"\"`$unzipper --version 2>&1`\"\"\";"              >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "<md5_$unzipMD5>"                                                             >> $file.pml.ttl
      echo "   a nfo:FileHash; "                                                         >> $file.pml.ttl
      echo "   nfo:hashAlgorithm \"md5\";"                                               >> $file.pml.ttl
      echo "   nfo:hasHash \"$unzipMD5\";"                                               >> $file.pml.ttl
      echo "."                                                                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
      echo "conv:Unzip rdfs:subClassOf pmlp:InferenceEngine ."                           >> $file.pml.ttl
      echo                                                                               >> $file.pml.ttl
   done
   echo --------------------------------------------------------------------------------
   shift
done
