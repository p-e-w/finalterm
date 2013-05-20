# Run this script in order to generate a Debian package
#
# Ensure that the version number below is correct
#
# The directory within which the finalterm is contained
# should have the name finalterm-x.xx, where the x's are
# the version number.
#
# A corresponding version number entry must exist at the
# top of debian/changelog and the email signature name
# within that file should correspond exactly with your
# GPG key.
#
#!/bin/bash

APP=finalterm
VERSION=0.10

# ensure that recent version of vala is available
#sudo add-apt-repository ppa:vala-team

# clean
rm -f ${APP} \#* \.#* debian/*.log debian/*.substvars debian/files
rm -rf debian/deb.* debian/${APP} build obj-*
rm -f ../${APP}*.deb ../${APP}*.changes ../${APP}*.asc ../${APP}*.dsc

# Create a source archive
tar -cvzf ../${APP}_${VERSION}.orig.tar.gz ../${APP}-${VERSION} --exclude=.git --exclude=build

# Build the package
fakeroot dpkg-buildpackage -F
