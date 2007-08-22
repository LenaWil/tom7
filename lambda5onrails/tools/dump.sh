#!/bin/sh

cat `find ../server -name "*.sml" | grep -v .cm` `find ../lambdac -name "*.sml" | grep -v .cm` > dump.txt
