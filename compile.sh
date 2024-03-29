#!/usr/bin/env sh
if [[ -d build ]]; then
  rm -rf build
fi;
mkdir build
if [ -n "${STAGING+set}" ]; then 
  echo "Staging Build";
  cp src/May/Urls.elm src/May/ProdUrls.elm
  cp src/May/StageUrls.elm src/May/Urls.elm
  elm make src/TodoList.elm --output=build/main.js
  cp src/May/Urls.elm src/May/StageUrls.elm
  cp src/May/ProdUrls.elm src/May/Urls.elm
  cp -r static/* build
else 
  echo "Prod Build";
  elm make src/TodoList.elm --output=build/main.js
  cp -r static/* build
fi;
