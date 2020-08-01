#!/usr/bin/env sh
elm make src/TodoList.elm --output=build/main.js
cp -r static/* build
