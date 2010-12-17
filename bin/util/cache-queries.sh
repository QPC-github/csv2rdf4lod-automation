#!/bin/sh

outputTypes="sparql xml"

if [ $# -lt 1 ]; then
   echo "usage: `basename $0` <endpoint> [-p {output,format}] [-o {sparql,gvds,xml,exhibit,csv}+] [-q a.sparql b.sparql ...]*"
   echo "    execute SPARQL queries against an endpoint requesting the given output formats"
   echo "            -p : the URL parameter name used to request a different output/format."
   echo "    default -p : output"
   echo "            -o : the URL parameter value(s) to request."
   echo "    default -o : $outputTypes"
   echo "    default -q : *.sparql *.rq"
   exit 1
fi

# http://dbpedia.org/sparql
# format = 
# "text/html"                       HTML
# "application/vnd.ms-excel"        Spreadsheet
# "application/sparql-results+xml"  XML
# "application/sparql-results+json" JSON           &format=application%2Frdf%2Bxml
# "application/javascript"          Javascript
# "text/plain"                      NTriples
# "application/rdf+xml"             RDF/XML
# "text/csv"                        CSV

endpoint="http://logd.tw.rpi.edu/sparql"
endpoint="http://dbpedia.org/sparql"
endpoint="$1"
shift

outputVarName="output"
if [ ${1:-'.'} == "-p" ]; then
   shift
   outputVarName="$1"
   shift
fi

if [ ${1:-'.'} == "-o" ]; then
   shift
   outputTypes=""
   while [ ${1:-'.'} != "-q" -a $# -gt 0 ]; do
      outputTypes="$outputTypes $1"
      shift
   done
fi

queryFiles=""
if [ $# -gt 0 -a "$1" == "-q" ]; then
   shift
   while [ $# -gt 0 ]; do
      queryFiles="$queryFiles $1"
      shift 
   done
else
   for sparql in `ls *.sparql *.rq 2> /dev/null`; do
      queryFiles="$queryFiles $sparql"
   done
fi

if [ ! -d results ]; then
   mkdir results
fi

for sparql in $queryFiles; do
   echo $sparql
   for output in $outputTypes; do
      printf "  $output"
      query=`        cat  $sparql | perl -e 'use URI::Escape; @userinput = <STDIN>; foreach (@userinput) { print uri_escape($_); }'`
      escapedOutput=`echo $output | perl -e 'use URI::Escape; @userinput = <STDIN>; foreach (@userinput) { print uri_escape($_); }'`
      url=$endpoint"?query="$query"&"$outputVarName"="$escapedOutput 
      #echo $url

      resultsFile=results/$sparql.`echo $output | tr '/+-' '_'`
      curl "$url" > $resultsFile 2> /dev/null

      requestID=`java edu.rpi.tw.string.NameFactory`
      requestDate=`dateInXSDDateTime.sh`
      echo "@prefix rdfs:    <http://www.w3.org/2000/01/rdf-schema#> ."                   > $resultsFile.pml.ttl
      echo "@prefix xsd:     <http://www.w3.org/2001/XMLSchema#> ."                      >> $resultsFile.pml.ttl
      echo "@prefix foaf:    <http://xmlns.com/foaf/0.1/> ."                             >> $resultsFile.pml.ttl
      echo "@prefix dcterms: <http://purl.org/dc/terms/> ."                              >> $resultsFile.pml.ttl
      echo "@prefix sioc:    <http://rdfs.org/sioc/ns#> ."                               >> $resultsFile.pml.ttl
      echo "@prefix pmlp:    <http://inference-web.org/2.0/pml-provenance.owl#> ."       >> $resultsFile.pml.ttl
      echo "@prefix pmlb:    <http://inference-web.org/2.b/pml-provenance.owl#> ."       >> $resultsFile.pml.ttl
      echo "@prefix pmlj:    <http://inference-web.org/2.0/pml-justification.owl#> ."    >> $resultsFile.pml.ttl
      echo "@prefix conv:    <http://purl.org/twc/vocab/conversion/> ."                  >> $resultsFile.pml.ttl
      echo                                                                               >> $resultsFile.pml.ttl
      echo "<$sparql.$output>"                                                           >> $resultsFile.pml.ttl
      echo "   a pmlp:Information;"                                                      >> $resultsFile.pml.ttl
      echo "   pmlp:hasModificationDateTime \"$requestDate\"^^xsd:dateTime;"             >> $resultsFile.pml.ttl
      echo "   pmlp:hasReferenceSourceUsage <sourceusage$requestID>;"                    >> $resultsFile.pml.ttl
      echo "."                                                                           >> $resultsFile.pml.ttl
      echo                                                                               >> $resultsFile.pml.ttl
      echo "<sourceusage$requestID>"                                                     >> $resultsFile.pml.ttl
      echo "   a pmlp:SourceUsage;"                                                      >> $resultsFile.pml.ttl
      echo "   pmlp:hasSource        <$endpoint>;"                                       >> $resultsFile.pml.ttl
      echo "   pmlp:hasUsageDateTime \"$requestDate\"^^xsd:dateTime;"                    >> $resultsFile.pml.ttl
      echo "."                                                                           >> $resultsFile.pml.ttl
      echo                                                                               >> $resultsFile.pml.ttl
      echo "<nodeset$requestID>"                                                         >> $resultsFile.pml.ttl
      echo "   a pmlj:NodeSet;"                                                          >> $resultsFile.pml.ttl
      echo "   pmlj:hasConclusion <$sparql.$output>;"                                    >> $resultsFile.pml.ttl
      echo "   pmlj:isConsequentOf ["                                                    >> $resultsFile.pml.ttl
      echo "      a pmlj:InferenceStep;"                                                 >> $resultsFile.pml.ttl
      echo "      pmlj:hasIndex 0;"                                                      >> $resultsFile.pml.ttl
      echo "      pmlj:hasAntecedentList ("                                              >> $resultsFile.pml.ttl
      echo "         [ a pmlj:NodeSet; pmlp:hasConclusion <query$requestID> ]"           >> $resultsFile.pml.ttl
      echo "         [ a pmlj:NodeSet; pmlp:hasConclusion ["                             >> $resultsFile.pml.ttl
      echo "               a pmlb:AttributeValuePair;"                                   >> $resultsFile.pml.ttl
      echo "               pmlb:attribute \"output\"; pmlb:value \"$output\""            >> $resultsFile.pml.ttl
      echo "             ]"                                                              >> $resultsFile.pml.ttl
      echo "         ]"                                                                  >> $resultsFile.pml.ttl
      echo "      );"                                                                    >> $resultsFile.pml.ttl
      #echo "      pmlj:hasSourceUsage     $sourceUsage;"                                >> $resultsFile.pml.ttl
      #echo "      pmlj:hasInferenceEngine <$engine_name$requestID>;"                     >> $resultsFile.pml.ttl
      #echo "      pmlj:hasInferenceRule   conv:${engine_name}_Method;"                   >> $resultsFile.pml.ttl
      echo "   ];"                                                                       >> $resultsFile.pml.ttl
      echo "."                                                                           >> $resultsFile.pml.ttl
      echo ""                                                                            >> $resultsFile.pml.ttl
      echo "<query$requestID>"                                                           >> $resultsFile.pml.ttl
      echo "   a pmlb:AttributeValuePair;"                                               >> $resultsFile.pml.ttl
      echo "   pmlb:attribute \"query\";"                                                >> $resultsFile.pml.ttl
      echo "   pmlb:value     \"\"\"`cat $sparql`\"\"\";"                                >> $resultsFile.pml.ttl
      echo "."                                                                           >> $resultsFile.pml.ttl

   done
   echo ""
done 
