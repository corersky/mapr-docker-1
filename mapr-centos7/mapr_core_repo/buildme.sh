#!/bin/bash
. ../version.sh

# Unlike other images, mapr_repo images are expected to be unchanged
# for a given tag (version).  
# IF THIS IS NOT TRUE, BE SURE TO REMOVE THE EXISTING REPO IMAGE 
# BEFORE BUILDING.
# Check for the exisiting repo image and exit if it already exists
# rather than copying all the files to public_html and rebuilding!

docker inspect --type=image $(basename $(pwd)):${MAPR_CORE_VER} > /dev/null 2>&1  && echo "$(basename $(pwd)):${MAPR_CORE_VER} already exists.  Skipping repo build."

if [[ ! -d ./public_html ]]; then
  ./get_packages.sh $MAPR_CORE_VER
elif [[ ! -d ./public_html/releases/v$MAPR_CORE_VER ]]; then
  rm -rf ./public_html
  ./get_packages.sh $MAPR_CORE_VER
fi
#time docker build -t mapr_core_repo:$MAPR_CORE_VER .
time docker build -t $(basename $(pwd)):${MAPR_CORE_VER} .

#rm -rf ./public_html  # Optionally clean up after building image to save disk space
                        # But subsequent builds will re-download tgz

# Sample:
#   docker run -d -p 8080:80 --name mapr_core_repo -h mapr_core_repo.mapr.local mapr_core_repo:5.2.0
