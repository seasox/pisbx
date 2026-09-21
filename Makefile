INSTALLDIR?=/usr/local/bin

all:
	docker build -t pi-sandbox -f Dockerfile.pi .

${INSTALLDIR}/pisbx: pisbx.sh
	install -m 0755 pisbx.sh ${INSTALLDIR}/pisbx

install: all ${INSTALLDIR}/pisbx

