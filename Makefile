# INSTALLDIR is passed through to install.sh when set on the command line
# (make install INSTALLDIR=/some/bin); otherwise install.sh picks the default.
export INSTALLDIR

.PHONY: all install refresh

all:
	docker build -t pi-sandbox -f Dockerfile.pi .

# Same code path as the curl|bash installer; install.sh detects this checkout
# and uses the local files instead of downloading.
install:
	sh ./install.sh

# Rebuild the image without cache to pick up new pi releases
# (plain builds reuse the cached npm layer).
refresh:
	docker build --pull --no-cache -t pi-sandbox -f Dockerfile.pi .
