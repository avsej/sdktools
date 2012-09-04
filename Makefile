TOPDIR := $(shell pwd)
PREFIX := $(TOPDIR)/install
LCBSOURCE := $(shell find lcb -name "*.[ch]*")
PHPSOURCE := $(shell find php -name "*.[ch]*")
NODESOURCE:= $(shell find node -name "*.[ch]*")

all: lcb/libcouchbase.la \
     php/modules/couchbase.so \
     node/build/Release/couchbase.node

lcb/configure: lcb/configure.ac
	(cd lcb; ./config/autorun.sh)

lcb/Makefile: lcb/configure
	(cd lcb; ./configure --prefix=$(PREFIX) --enable-werror --enable-warnings --enable-debug )

lcb/libcouchbase.la: lcb/Makefile $(LCBSOURCE)
	(cd lcb; $(MAKE) all check install)

php/configure: php/config.m4
	(cd php; phpize)

php/Makefile: php/configure
	(cd php; ./configure --with-couchbase=$(PREFIX))

php/tests/couchbase.local.inc: tools/couchbase.local.inc
	cp tools/couchbase.local.inc php/tests/couchbase.local.inc

php/modules/couchbase.so: lcb/libcouchbase.la \
                          php/Makefile \
                          php/tests/couchbase.local.inc \
                          $(PHPSOURCE)
	(cd php; $(MAKE))

node/.lock-wscript: node/wscript
	(cd node; CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib -Wl,-rpath,$(PREFIX)/lib" node-waf configure)

node/build/Release/couchbase.node: node/.lock-wscript $(NODESOURCE)
	(cd node; $(MAKE))

clean:
	repo forall -c 'git clean -dfxq'
	rm -rf install
