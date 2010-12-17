#!/bin/sh
#
# Usage:
#
#   pcurl.sh http://www.whitehouse.gov/files/disclosures/visitors/WhiteHouse-WAVES-Key-1209.txt
#   (produces WhiteHouse-WAVES-Key-1209.txt and WhiteHouse-WAVES-Key-1209.txt.pml.ttl)
#
#   pcurl.sh <url> -n is semi-deprecated
#   pcurl.sh <url> -e can be used to append an extension to a url that does not have one.

usage_message="usage: `basename $0` -I url [-n name] [-e extension]     [url [-n name] [-e extension]] ..." 

if [ $# -lt 1 ]; then
   echo $usage_message 
   exit 1
fi

downloadFile="true"
if [ $1 == "-I" ]; then
   downloadFile="."
   shift 
fi

curlPath=`which curl`
curlMD5="md5_`md5.sh $curlPath`"

# md5 this script
pcurlMD5=""
if [ `which md5` ]; then
   # md5 outputs:
   # MD5 (pcurl.sh) = ecc71834c2b7d73f9616fb00adade0a4
   pcurlMD5=`md5 $0 | perl -pe 's/^.* = //'`
elif [ `which md5sum` ]; then
   pcurlMD5=`md5sum $0 | perl -pe 's/\s.*//'`
else
   echo "`basename $0`: can not find md5 to md5 this script."
fi


alias rname="java edu.rpi.tw.string.NameFactory"
logID=`rname`
while [ $# -gt 0 ]; do
   echo
   echo ---------------------------------- pcurl ---------------------------------------
   url="$1"

   #echo url $url
   urlBaseName=`basename $url`
   #echo url basename $urlBaseName
   flag=$2
   #echo flag $flag
   if [ $# -ge 3 -a ${flag:=""} == "-n" ]; then
      echo -n $3
      localName="$3"
      shift 2
   else
      localName=$urlBaseName
   fi
   #echo localName $localName

   flag=$2
   #echo flag $flag
   if [ $# -ge 3 -a ${flag:=""} == "-e" ]; then
      echo -e $3
      extension=".$3"
      shift 2
   else
      extension=""
   fi
   #echo extension $extension


   echo getting last mod xsddatetime
   urlINFO=`curl -I $url`
   urlModDateTime=`urldate.sh -field Last-Modified: -format dateTime $url`
   #echo "url modification date:  $urlModDateTime"

   echo getting redirect name
   redirectedURL=`filename-v3.pl $url`
   redirectedURLINFO=`curl -I $redirectedURL`
   redirectedModDate=`urldate.sh -field Last-Modified: -format dateTime $redirectedURL`

   echo getting last mod
   documentVersion=`urldate.sh -field Last-Modified: $url`
   #echo "mod date: $documentVersion"
   if [ ${#documentVersion} -le 3 ]; then
      documentVersion="undated"
      echo "version: $documentVersion"
   fi

   file=`basename $redirectedURL`$extension
   #file=${localName}-$documentVersion${extension}

   if [ ! -e $file -a ${#documentVersion} -gt 0 ]; then 
      requestID=`rname`
      usageDateTime=`date +%Y-%m-%dT%H:%M:%S%z | sed 's/^\(.*\)\(..\)$/\1:\2/'`

      echo "$url (mod $urlModDateTime)"
      echo "$redirectedURL (mod $redirectedModDate) to $file (@ $usageDateTime)"
      # TODO: curl -H "Accept: application/rdf+xml, */*; q=0.1", but 406
      # http://dowhatimean.net/2008/03/what-is-your-rdf-browsers-accept-header
      prefRDF="" #"-H 'Accept: application/rdf+xml, */*; q=0.1'"
      #echo curl $prefRDF -L $url 
      if [ ${downloadFile:-"."} == "true" ]; then
         curl -L $url > $file
         downloadedFileMD5=`md5.sh $file`
      fi

      Eurl=`echo $url | awk '{gsub(/\//,"\\\\/");print}'`  # Escaped URL

      # Relative paths.
      sourceUsage="sourceUsage$requestID"
      nodeSet="nodeSet$requestID"

      echo
      echo "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."                         > $file.pml.ttl
      echo "@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> ."                            >> $file.pml.ttl
      echo "@prefix dcterms: <http://purl.org/dc/terms/> ."                                 >> $file.pml.ttl
      echo "@prefix pmlp: <http://inference-web.org/2.0/pml-provenance.owl#> ."             >> $file.pml.ttl
      echo "@prefix pmlj: <http://inference-web.org/2.0/pml-justification.owl#> ."          >> $file.pml.ttl
      echo "@prefix irw:  <http://www.ontologydesignpatterns.org/ont/web/irw.owl#> ."       >> $file.pml.ttl
      echo "@prefix nfo: <http://www.semanticdesktop.org/ontologies/nfo/#> ."               >> $file.pml.ttl
      echo "@prefix conv: <http://purl.org/twc/vocab/conversion/> ."                        >> $file.pml.ttl
      echo "@prefix httphead: <http://inference-web.org/registry/MPR/HTTP_1_1_HEAD.owl#> ." >> $file.pml.ttl
      echo "@prefix httpget:  <http://inference-web.org/registry/MPR/HTTP_1_1_GET.owl#> ."  >> $file.pml.ttl
      echo                                                                                  >> $file.pml.ttl
      echo "<$url>"                                                                         >> $file.pml.ttl
      echo "   a pmlp:Source;"                                                              >> $file.pml.ttl
         if [ $redirectedURL != $url ]; then
            if [ ${#urlModDateTime} -gt 3 ]; then
               echo "   pmlp:hasModificationDateTime \"$urlModDateTime\"^^xsd:dateTime;"   >> $file.pml.ttl
            fi
            echo "   irw:redirectsTo <$redirectedURL>;"                                    >> $file.pml.ttl
         fi
      echo "."                                                                             >> $file.pml.ttl
      echo                                                                                 >> $file.pml.ttl
      echo "<$redirectedURL>"                                                              >> $file.pml.ttl
      echo "   a pmlp:Source;"                                                             >> $file.pml.ttl
         if [ ${#redirectedModDate} -gt 3 ]; then
            echo "   pmlp:hasModificationDateTime \"$redirectedModDate\"^^xsd:dateTime;"   >> $file.pml.ttl
         fi
      echo "."                                                                             >> $file.pml.ttl
      echo                                                                                 >> $file.pml.ttl
      if [ ${downloadFile:-"."} == "true" ]; then
         echo "<$file>"                                                                    >> $file.pml.ttl
         echo "   a pmlp:Information;"                                                     >> $file.pml.ttl
         echo "   pmlp:hasReferenceSourceUsage <${sourceUsage}_content>;"                  >> $file.pml.ttl
         echo "   nfo:hasHash <md5_$downloadedFileMD5>;"                                   >> $file.pml.ttl
         echo "."                                                                          >> $file.pml.ttl
         echo ""                                                                           >> $file.pml.ttl
         echo "<md5_$downloadedFileMD5>"                                                   >> $file.pml.ttl
         echo "   a nfo:FileHash; "                                                        >> $file.pml.ttl
         echo "   nfo:hashAlgorithm \"md5\";"                                              >> $file.pml.ttl
         echo "   nfo:hasHash \"$downloadedFileMD5\";"                                     >> $file.pml.ttl
         echo "."                                                                          >> $file.pml.ttl
         echo                                                                              >> $file.pml.ttl
         echo "<${nodeSet}_content>"                                                       >> $file.pml.ttl
         echo "   a pmlj:NodeSet;"                                                         >> $file.pml.ttl
         echo "   pmlj:hasConclusion <$file>;"                                             >> $file.pml.ttl
         echo "   pmlj:isConsequentOf ["                                                   >> $file.pml.ttl
         echo "      a pmlj:InferenceStep;"                                                >> $file.pml.ttl
         echo "      pmlj:hasIndex 0;"                                                     >> $file.pml.ttl
         echo "      pmlj:hasAntecedentList ();"                                           >> $file.pml.ttl
         echo "      pmlj:hasSourceUsage     <${sourceUsage}_content>;"                    >> $file.pml.ttl
         echo "      pmlj:hasInferenceEngine conv:curl_$curlMD5;"                          >> $file.pml.ttl
         echo "      pmlj:hasInferenceRule   httpget:HTTP_1_1_GET;"                        >> $file.pml.ttl
         echo "   ];"                                                                      >> $file.pml.ttl
         echo "."                                                                          >> $file.pml.ttl
         echo                                                                              >> $file.pml.ttl
         echo "<${sourceUsage}_content>"                                                   >> $file.pml.ttl
         echo "   a pmlp:SourceUsage;"                                                     >> $file.pml.ttl
         echo "   pmlp:hasSource        <$redirectedURL>;"                                 >> $file.pml.ttl
         echo "   pmlp:hasUsageDateTime \"$usageDateTime\"^^xsd:dateTime;"                 >> $file.pml.ttl
         echo "."                                                                          >> $file.pml.ttl
      fi
      echo " "                                                                             >> $file.pml.ttl
      echo "<info${requestID}_url_header>"                                                 >> $file.pml.ttl
      echo "   a pmlp:Information, conv:HTTPHeader;"                                       >> $file.pml.ttl
      echo "   pmlp:hasRawString \"\"\"$urlINFO\"\"\";"                                    >> $file.pml.ttl
      echo "   pmlp:hasReferenceSourceUsage <${sourceUsage}_url_header>;"                  >> $file.pml.ttl
      echo "."                                                                             >> $file.pml.ttl
      echo " "                                                                             >> $file.pml.ttl
      echo "<${nodeSet}_url_header>"                                                       >> $file.pml.ttl
      echo "   a pmlj:NodeSet;"                                                            >> $file.pml.ttl
      echo "   pmlj:hasConclusion <info${requestID}_url_header>;"                          >> $file.pml.ttl
      echo "   pmlj:isConsequentOf ["                                                      >> $file.pml.ttl
      echo "      a pmlj:InferenceStep;"                                                   >> $file.pml.ttl
      echo "      pmlj:hasIndex 0;"                                                        >> $file.pml.ttl
      echo "      pmlj:hasAntecedentList ();"                                              >> $file.pml.ttl
      echo "      pmlj:hasSourceUsage     <${sourceUsage}_url_header>;"                    >> $file.pml.ttl
      echo "      pmlj:hasInferenceEngine conv:curl_$curlMD5;"                             >> $file.pml.ttl
      echo "      pmlj:hasInferenceRule   httphead:HTTP_1_1_HEAD;"                         >> $file.pml.ttl
      echo "   ];"                                                                         >> $file.pml.ttl
      echo "."                                                                             >> $file.pml.ttl
      echo                                                                                 >> $file.pml.ttl
      echo "<${sourceUsage}_url_header>"                                                   >> $file.pml.ttl
      echo "   a pmlp:SourceUsage;"                                                        >> $file.pml.ttl
      echo "   pmlp:hasSource        <$url>;"                                              >> $file.pml.ttl
      echo "   pmlp:hasUsageDateTime \"$usageDateTime\"^^xsd:dateTime;"                    >> $file.pml.ttl
      echo "."                                                                             >> $file.pml.ttl
      echo                                                                                 >> $file.pml.ttl
         if [ $redirectedURL != $url ]; then
            echo "<info${requestID}_redirected_url_header>"                                >> $file.pml.ttl
            echo "   a pmlp:Information, conv:HTTPHeader;"                                 >> $file.pml.ttl
            echo "   pmlp:hasRawString \"\"\"$redirectedURLINFO\"\"\";"                    >> $file.pml.ttl
            echo "   pmlp:hasReferenceSourceUsage <${sourceUsage}_redirected_url_header>;" >> $file.pml.ttl
            echo "."                                                                       >> $file.pml.ttl
            echo                                                                           >> $file.pml.ttl
            echo "<${nodeSet}_redirected_url_header>"                                      >> $file.pml.ttl
            echo "   a pmlj:NodeSet;"                                                      >> $file.pml.ttl
            echo "   pmlj:hasConclusion <info${requestID}_redirected_url_header>;"         >> $file.pml.ttl
            echo "   pmlj:isConsequentOf ["                                                >> $file.pml.ttl
            echo "      a pmlj:InferenceStep;"                                             >> $file.pml.ttl
            echo "      pmlj:hasIndex 0;"                                                  >> $file.pml.ttl
            echo "      pmlj:hasAntecedentList ();"                                        >> $file.pml.ttl
            echo "      pmlj:hasSourceUsage     <${sourceUsage}_redirected_url_header>;"   >> $file.pml.ttl
            echo "      pmlj:hasInferenceEngine conv:curl_$curlMD5;"                       >> $file.pml.ttl
            echo "      pmlj:hasInferenceRule   httphead:HTTP_1_1_HEAD;"                   >> $file.pml.ttl
            echo "   ];"                                                                   >> $file.pml.ttl
            echo "."                                                                       >> $file.pml.ttl
            echo                                                                           >> $file.pml.ttl
            echo "<${sourceUsage}_redirected_url_header>"                                  >> $file.pml.ttl
            echo "   a pmlp:SourceUsage;"                                                  >> $file.pml.ttl
            echo "   pmlp:hasSource        <$redirectedURL>;"                              >> $file.pml.ttl
            echo "   pmlp:hasUsageDateTime \"$usageDateTime\"^^xsd:dateTime;"              >> $file.pml.ttl
            echo "."                                                                       >> $file.pml.ttl
         fi
      echo                                                                                 >> $file.pml.ttl
      echo "conv:curl_$curlMD5"                                                            >> $file.pml.ttl
      echo "   a pmlp:InferenceEngine, conv:Curl;"                                        >> $file.pml.ttl
      echo "   dcterms:identifier \"$curlMD5\";"                                           >> $file.pml.ttl
      echo "   dcterms:description \"\"\"`curl --version`\"\"\";"                         >> $file.pml.ttl
      echo "."                                                                             >> $file.pml.ttl
      echo                                                                                 >> $file.pml.ttl
      echo "conv:Curl rdfs:subClassOf pmlp:InferenceEngine ."                              >> $file.pml.ttl
   elif [ ! -e $file ]; then
      echo "could not obtain dataset version."
   else 
      echo "$file already exists."
   fi
   echo --------------------------------------------------------------------------------
   shift
done
