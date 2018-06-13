#!/bin/bash
# Author: Robin Wen
# Date: 2015-1-1 08:49:08
# Desc: Auto push after update the repo.
# Update: Update Commit info at 2015-03-04 17:17:10
# Update: Test Git Config at 2015-03-07 09:32:09.
# Update: Optimize display.

git add -A .
git commit -m "[Post] Update article."
git push origin master
