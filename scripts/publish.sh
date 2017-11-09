#!/bin/sh


if ! (cat config.toml > /dev/null); then
    echo "Must run from repo root"
    exit 1
fi

if [[ $(git status -s) ]]
then
    echo "The working directory is dirty. Please commit any pending changes."
    exit 1;
fi

echo "Deleting old publication"
rm -rf public
mkdir public
git worktree prune
rm -rf .git/worktrees/public/

echo "Checking out gh-pages branch into public"
if ! git worktree add -B gh-pages public origin/gh-pages ; then
    echo "Failed to create worktree."
    exit 1
fi

echo "Removing existing files"
rm -rf public/*

echo "Generating site"
if ! hugo ; then
    echo "Build failed"
    exit 1
fi

echo "Updating gh-pages branch"
cd public && git add --all && git commit -m "Publishing to gh-pages (publish.sh)"

echo "Pushing to origin"
git push origin gh-pages
