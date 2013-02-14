# This Makefile written especially for ruby.xml manifest

TOPDIR := $(shell pwd)
PREFIX := $(TOPDIR)/install
LCBSOURCE := $(shell find libcouchbase -name "*.[ch]*")
RUBYSOURCE:= $(shell find client -name "*.rb" -o -name "*.[ch]")
RBENVDIR:= $(HOME)/.rbenv
RBENVPLUGINSDIR:= $(RBENVDIR)/plugins
PATH:= $(RBENVDIR)/bin:$(RBENVDIR)/shims:$(PATH)
RUBIES:= \
	$(RBENVDIR)/versions/1.8.7-p371-dbg/.done \
	$(RBENVDIR)/versions/1.9.2-p320-dbg/.done \
	$(RBENVDIR)/versions/1.9.3-p362-dbg/.done
#     $(RBENVDIR)/versions/2.0.0-rc1-dbg/.done

all: check

install-rubies:$(RBENVDIR)/.bundler-done

check: libcouchbase $(RBENVDIR)/.bundler-done client.bundled
	(cd client; rbenv each -v bundle exec rake clean compile with_libcouchbase_dir=$(PREFIX) test)

client.bundled: client/Gemfile
	(cd client; rbenv each -v bundle install --no-color)
	touch $@

libcouchbase: $(PREFIX)/lib/libcouchbase.so

$(PREFIX)/lib/libcouchbase.so: libcouchbase/libcouchbase.la
	(cd libcouchbase; $(MAKE) install)

libcouchbase/libcouchbase.la: libcouchbase/Makefile $(LCBSOURCE)
	(cd libcouchbase; $(MAKE) all)

libcouchbase/Makefile: libcouchbase/configure
	(cd libcouchbase; ./configure --prefix=$(PREFIX) --enable-werror --enable-warnings --enable-debug)

libcouchbase/configure: libcouchbase/configure.ac
	(cd libcouchbase; ./config/autorun.sh)

$(RBENVDIR)/.bundler-done: $(RUBIES)
	rbenv each -v gem install bundler
	rbenv rehash
	touch $@

$(RUBIES): $(RBENVPLUGINSDIR)/ruby-build/.done  $(RBENVPLUGINSDIR)/rbenv-each/.done
	rm -rf $(subst /.done,,$@)
	rbenv install $(subst $(RBENVDIR)/versions/,,$(subst /.done,,$@))
	touch $@

$(RBENVPLUGINSDIR)/ruby-build/.done: $(RBENVDIR)/.done
	rm -rf $(RBENVPLUGINSDIR)/ruby-build
	git clone git://github.com/avsej/ruby-build.git $(RBENVPLUGINSDIR)/ruby-build
	touch $@

$(RBENVPLUGINSDIR)/rbenv-each/.done: $(RBENVDIR)/.done
	rm -rf $(RBENVPLUGINSDIR)/rbenv-each
	git clone git://github.com/avsej/rbenv-each.git $(RBENVPLUGINSDIR)/rbenv-each
	touch $@

$(RBENVDIR)/.done:
	rm -rf $(RBENVDIR)
	git clone git://github.com/sstephenson/rbenv.git $(RBENVDIR)
	touch $@

clean:
	repo forall -c 'git clean -dfxq'
	rm -rf install

client/lib/couchbase_ext.so: client.bundled $(RUBYSOURCE) $(PREFIX)/lib/libcouchbase.so
	(cd client; bundle exec rake compile with_libcouchbase_dir=$(PREFIX))

console: client/lib/couchbase_ext.so
	(cd client; bundle exec rake console)

.PHONY: all check install-rubies clean console
