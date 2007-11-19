#!/bin/sh

cat `find ../server -name "*.sml" | grep -v .cm` `find ../ml5pgh -name "*.sml" | grep -v .cm` > dump.txt
