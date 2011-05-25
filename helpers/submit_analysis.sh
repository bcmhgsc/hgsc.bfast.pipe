#! /bin/sh

if [ $5 == "MP" ] || [ $5 == "PE" ]; then
  type=-m
else
  type=""
fi

/stornext/snfs5/next-gen/software/bin/ruby19 /stornext/snfs5/next-gen/solid/hgsc.solid.pipeline/hgsc.bfast.pipe/bin/analysis_driver.rb -a sea_create -r $1 --rg_sm $2 --rg_lb $3 -c $4 $type -f $6 | /bin/sh 
