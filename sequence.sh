#!/bin/bash
# Extract SequenceTracer from a log and generate a plant uml sequence graph
# See https://jira.nuxeo.com/browse/NXP-11698 for more info
SEQ_IMG=/tmp/sequence.png
SEQ_LOG=/tmp/sequence.log
PLANT_VERSION=8033
PLANT=~/.m2/repository/net/sourceforge/plantuml/plantuml/$PLANT_VERSION/plantuml-$PLANT_VERSION.jar

if [ $# -eq 0 ]; then
  echo >&2 "Expecting a log file"
  exit 2
fi
if [ ! -f $1 ]; then
  echo >&2 "Invalid log file"
  exit 2
fi

set -e
if [ ! -f $PLANT ]; then
  echo "Downloading plantuml jar"
  mvn -DgroupId=net.sourceforge.plantuml -DartifactId=plantuml -Dversion=$PLANT_VERSION dependency:get  
fi
echo "Extracting sequence $LOG from log $1"
rm -f $SEQ_IMG $SEQ_LOG
grep "@@" $1 | sed -u "s/.*\@\@ //" | sed -e '1 i \@startuml' -e '$s@$@\n\@enduml@' > $SEQ_LOG 
java -jar $PLANT $SEQ_LOG
if [ -f $SEQ_IMG ]; then
  echo "Image created: $SEQ_IMG"
else
  echo >&2 "No image generated"
  exit 2
fi
if which eog >/dev/null; then
    eog $SEQ_IMG
fi
