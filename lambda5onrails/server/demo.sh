#!/bin/sh

./server5 @MLton max-heap 128m -- -codepath ../lambdac/demos/ -tdb "db-demo.txt" -port 7777
