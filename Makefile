TOPDIR := $(shell pwd)
PREFIX := $(TOPDIR)/install
LCBSOURCE := $(shell find lcb -name "*.[ch]*")
PHPSOURCE := $(shell find php -name "*.[ch]*")
NODESOURCE:= $(shell find node -name "*.[ch]*")
RUBYCLIENTSOURCE:= $(shell find ruby/client -name "*.rb" -or -name "*.[ch]")
VACUUMSOURCE := $(shell find demo/vacuum -name "*.[ch]*")

all: lcb/libcouchbase.la \
     php/modules/couchbase.so \
     node/build/Release/couchbase.node \
     demo/vacuum/vacuum \
     ruby

nodejs: node/build/Release/couchbase.node

php: php/modules/couchbase.so

libcouchbase: lcb/libcouchbase.la

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
	(cd node; CXXFLAGS="-Wall -pedantic -Wextra" CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib -Wl,-rpath,$(PREFIX)/lib" node-waf configure)

node/build/Release/couchbase.node: lcb/libcouchbase.la\
                                   node/.lock-wscript \
                                   $(NODESOURCE)
	(cd node; $(MAKE))

# To build ruby, you need ruby interpreter with rubygems and bundler gem
# installed. To verify you have all these tools run these commands:
#
#   $ ruby --version || echo "missing ruby. http://ruby-lang.org"
#   $ gem --version || echo "missing rubygems. http://rubygems.org"
#   $ bundle --version || echo "missing gem bundler. http://gembundler.com"
#
# All these commands should printout their versions.
ruby: ruby-client

ruby-client: lcb/libcouchbase.la ruby/client/.timestamp

ruby/client/.timestamp: ruby/client/Gemfile.lock $(RUBYCLIENTSOURCE)
	(cd ruby/client; bundle exec rake compile with_libcouchbase_dir=$(PREFIX) && touch .timestamp)

ruby/client/Gemfile.lock: ruby/client/Gemfile
	(cd ruby/client; bundle install)

#
# Demo programs
#
demo/vacuum/vacuum: lcb/libcouchbase.la $(VACUUM_SRC)
	(cd demo/vacuum; $(MAKE) CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib -Wl,-rpath,$(PREFIX)/lib")

clean:
	repo forall -c 'git clean -dfxq'
	rm -rf install
