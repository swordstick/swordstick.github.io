#!/bin/bash
# Author: Robin Wen
# Date: 2015-1-10 15:47:08
# Desc: Auto push after add article.
# Update: Update Commit info at 2015-03-04 17:16:28

git add -A .
git commit -m "[Post] Add article."
git push origin master
