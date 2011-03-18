#!/bin/bash

picardPath="/stornext/snfs5/next-gen/software/picard-tools/current"

samJarName=`ls $picardPath"/"sam-*.jar`
picardJarName=`ls $picardPath"/"picard-*.jar`

echo "SAM Jar : "$samJarName
echo "Picard Jar : "$picardJarName

echo "Compiling project"
javac -classpath $samJarName":"$picardJarName *.java

echo "Generating Manifest file"
manifestFile=`pwd`"/AddRgToBAMManifest.txt"

echo -e "Class-Path: "$samJarName" "$picardJarName"\nMain-Class: Driver\n" > $manifestFile

echo "Building Jar file"

jar cvfm AddRGToBam.jar $manifestFile *.class
