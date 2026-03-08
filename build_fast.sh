#!/bin/bash
mix deps.get --only prod

# Release
MIX_ENV=prod mix release
if [ $? -eq 0 ]; then
  # Only when mix release is successful
  build_date=$(date +%Y%m%d_%H%M)
  build_name=_build_modai_api_$build_date.tar.gz
  tar -czvf $build_name _build
  echo "Built & compressed into: $build_name"
fi
