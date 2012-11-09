TOPDIR := $(shell pwd)
PREFIX := $(TOPDIR)/install
LCBSOURCE := $(shell find lcb -name "*.[ch]*")
PHPSOURCE := $(shell find php -name "*.[ch]*")
NODESOURCE:= $(shell find node -name "*.[ch]*")
RUBYCLIENTSOURCE:= $(shell find ruby/client -name "*.rb" -o -name "*.[ch]")
VACUUMSOURCE := $(shell find demo/vacuum -name "*.[ch]*")
PLUGINLESSSTEP1SOURCE := $(shell find demo/pluginless/step1 -name "*.[ch]*")
PLUGINLESSSTEP2SOURCE := $(shell find demo/pluginless/step2 -name "*.[ch]*")
NGINXSOURCE := $(shell find nginx -name "*.[ch]*")
NGINXMODULESOURCE := $(shell find nginx-module -name "*.[ch]*")

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

node/tests/config.json: tools/config.json
	cp tools/config.json node/tests/config.json

node/.lock-wscript: node/wscript node/tests/config.json
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

# nginx server with couchbase module
nginx-module: nginx/objs/nginx

nginx/objs/nginx: lcb/libcouchbase.la nginx/objs/Makefile $(NGINXSOURCE) $(NGINXMODULESOURCE)
	(cd nginx; $(MAKE) install)

nginx/objs/Makefile: nginx/auto/configure nginx-module/config
	(cd nginx; ./auto/configure --prefix=$(PREFIX) --with-debug --add-module=$(TOPDIR)/nginx-module)

#
# Demo programs
#
demo/vacuum/vacuum: lcb/libcouchbase.la $(VACUUMSOURCE)
	(cd demo/vacuum; $(MAKE) CPPFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib -Wl,-rpath,$(PREFIX)/lib")

demo/pluginless: demo/pluginless/step1/server demo/pluginless/step2/server

demo/pluginless/step1/configure: demo/pluginless/step1/configure.ac
	(cd demo/pluginless/step1; ./autogen.sh)

demo/pluginless/step1/Makefile: demo/pluginless/step1/configure demo/pluginless/step1/Makefile.am
	(cd demo/pluginless/step1; ./configure --prefix=$(PREFIX))

demo/pluginless/step1/server: demo/pluginless/step1/Makefile $(PLUGINLESSSTEP1SOURCE)
	(cd demo/pluginless/step1; $(MAKE))

demo/pluginless/step2/configure: lcb/libcouchbase.la demo/pluginless/step2/configure.ac
	(cd demo/pluginless/step2; ./autogen.sh)

demo/pluginless/step2/Makefile: demo/pluginless/step2/configure demo/pluginless/step2/Makefile.am
	(cd demo/pluginless/step2; ./configure --prefix=$(PREFIX))

demo/pluginless/step2/server: demo/pluginless/step2/Makefile $(PLUGINLESSSTEP2SOURCE)
	(cd demo/pluginless/step2; $(MAKE))

clean:
	repo forall -c 'git clean -dfxq'
	rm -rf install
