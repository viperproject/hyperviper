#!/bin/bash

cd silicon 
ln -s ../silver silver
cd ..
cd silver-sif-extension
ln -s ../silver silver
cd ..
cd commutativity-plugin
ln -s ../silver silver
ln -s ../silver-sif-extension silver-sif-extension
cd ..
cd commutativity-plugin-test
ln -s ../silver silver
ln -s ../silicon silicon
ln -s ../silver-sif-extension silver-sif-extension
ln -s ../commutativity-plugin commutativity-plugin

