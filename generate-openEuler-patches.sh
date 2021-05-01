#!/bin/bash
# This script breaks down openEuler kernel code into patches on top of the 
# mainline kernel, for use in SUSE kernel-source package
# How to use:
# - git clone https://gitee.com/openeuler/kernel.git
# - cd kernel
# - git remote add mainline https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
# - git pull -a -r
# - run this script in the kernel repo dir (not this kernel-source repo)

# Author: Kai Liu <kai.liu@suse.com>

# The upstream base version
UVER=v5.10
# The openEuler version
OVER=openEuler-21.03
# The dir to save the created patches, relative to this script
PATCHDIR=patches.openEuler

# The series file name
SERIES=series.openeuler

# Generate the patches
git format-patch $UVER..$OVER -o $PATCHDIR \
	--add-header="Patch-mainline: <placeholder>" \
	--no-numbered --no-renames --signoff

# The Git-commit header
sed -i -E -e '1s|^From ([0-9a-z]{40}) (.*)|Git-commit: \1|' $PATCHDIR/*.patch

for f in $PATCHDIR/*.patch; do
	# The line "commit xxxx" means it's from an upstream commit
	COMMIT=$(grep -m 1 -E "^commit [0-9a-z]{40}" "$f" | cut -d' ' -f2)

	if [ -n "$COMMIT" ]; then # The commit has upstream commit info
		# First upstream release tag that contains this commit
		FIRST=$(git tag --sort=creatordate --contains $COMMIT | head -1)

		# Patch header
		sed -i -E -e "s|^Patch-mainline: .*|Patch-mainline: $FIRST\nReferences: $OVER|" "$f"
	else # It's some openEuler specific commit (could also be picked from upstream but it has no info to indicate that
		# First tag that contains this commit
		COMMIT=$(grep -m 1 "^Git-commit: .*" "$f" | cut -d':' -f2)

		# Patch header
		FIRST=$(git tag --sort=creatordate --contains $COMMIT | head -1)
		sed -i -E -e "s|^Patch-mainline: .*|Patch-mainline: Queued in openEuler repo, version $FIRST\nReferences: $OVER\nGit-repo: https://gitee.com/openeuler/kernel.git|" "$f"
	fi

	# Rename the patch
	NEWF=$PATCHDIR/$(basename "$f" | sed -E -e "s|([0-9]*)-(.*)|\1-$FIRST-\2|")
	mv "$f" "$NEWF"
	echo "$NEWF" >> $SERIES
	echo "Found first tag $FIRST for commit $COMMIT for $f"
done
