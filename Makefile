-include deps/node/config.mk

BUILDTYPE ?= Release
PYTHON ?= python

# BUILDTYPE=Debug builds both release and debug builds. If you want to compile
# just the debug build, run `make -C out BUILDTYPE=Debug` instead.
ifeq ($(BUILDTYPE),Release)
all: out/Makefile node
else
all: out/Makefile node node_g
endif

# The .PHONY is needed to ensure that we recursively use the out/Makefile
# to check for changes.
.PHONY: node node_g

node: deps/node/config.gypi
	$(MAKE) -C out BUILDTYPE=Release
	ln -fs out/Release/node node

node_g: deps/node/config.gypi
	$(MAKE) -C out BUILDTYPE=Debug
	ln -fs out/Debug/node node_g

deps/node/config.gypi: configure
	./configure

out/Debug/node:
	$(MAKE) -C out BUILDTYPE=Debug

out/Makefile: deps/node/common.gypi deps/node/deps/uv/uv.gyp deps/node/deps/http_parser/http_parser.gyp deps/node/deps/zlib/zlib.gyp deps/node/deps/v8/build/common.gypi deps/node/deps/v8/tools/gyp/v8.gyp node.gyp deps/node/config.gypi
	tools/gyp_node -f make

install: all
	out/Release/node tools/installer.js install

uninstall:
	out/Release/node tools/installer.js uninstall

clean:
	-rm -rf out/Makefile node node_g out/$(BUILDTYPE)/node
	-find out/ -name '*.o' -o -name '*.a' | xargs rm -rf

distclean:
	-rm -rf out
	-rm -f deps/node/config.gypi
	-rm -f deps/node/config.mk

test: all
	$(PYTHON) tools/test.py --mode=release simple message
	PYTHONPATH=tools/closure_linter/ $(PYTHON) tools/closure_linter/closure_linter/gjslint.py --unix_mode --strict --nojsdoc -r lib/ -r src/ --exclude_files lib/punycode.js

test-http1: all
	$(PYTHON) tools/test.py --mode=release --use-http1 simple message

test-valgrind: all
	$(PYTHON) tools/test.py --mode=release --valgrind simple message

test-all: all
	python tools/test.py --mode=debug,release
	$(MAKE) test-npm

test-all-http1: all
	$(PYTHON) tools/test.py --mode=debug,release --use-http1

test-all-valgrind: all
	$(PYTHON) tools/test.py --mode=debug,release --valgrind

test-release: all
	$(PYTHON) tools/test.py --mode=release

test-debug: all
	$(PYTHON) tools/test.py --mode=debug

test-message: all
	$(PYTHON) tools/test.py message

test-simple: all
	$(PYTHON) tools/test.py simple

test-pummel: all
	$(PYTHON) tools/test.py pummel

test-internet: all
	$(PYTHON) tools/test.py internet

test-npm: node
	./node deps/npm/test/run.js

test-npm-publish: node
	npm_package_config_publishtest=true ./node deps/npm/test/run.js

apidoc_sources = $(wildcard doc/api/*.markdown)
apidocs = $(addprefix out/,$(apidoc_sources:.markdown=.html)) \
          $(addprefix out/,$(apidoc_sources:.markdown=.json))

apidoc_dirs = out/doc out/doc/api/ out/doc/api/assets out/doc/about out/doc/community out/doc/logos out/doc/images

apiassets = $(subst api_assets,api/assets,$(addprefix out/,$(wildcard doc/api_assets/*)))

doc_images = $(addprefix out/,$(wildcard doc/images/* doc/*.jpg doc/*.png))

website_files = \
	out/doc/index.html    \
	out/doc/v0.4_announcement.html   \
	out/doc/cla.html      \
	out/doc/sh_main.js    \
	out/doc/sh_javascript.min.js \
	out/doc/sh_vim-dark.css \
	out/doc/sh.css \
	out/doc/favicon.ico   \
	out/doc/pipe.css \
	out/doc/about/index.html \
	out/doc/community/index.html \
	out/doc/logos/index.html \
	$(doc_images)

doc: program $(apidoc_dirs) $(website_files) $(apiassets) $(apidocs) tools/doc/

$(apidoc_dirs):
	mkdir -p $@

out/doc/api/assets/%: doc/api_assets/% out/doc/api/assets/
	cp $< $@

out/doc/%.html: doc/%.html
	cat $< | sed -e 's|__VERSION__|'$(VERSION)'|g' > $@

out/doc/%: doc/%
	cp -r $< $@

out/doc/api/%.json: doc/api/%.markdown
	out/Release/node tools/doc/generate.js --format=json $< > $@

out/doc/api/%.html: doc/api/%.markdown
	out/Release/node tools/doc/generate.js --format=html --template=doc/template.html $< > $@

website-upload: doc
	rsync -r out/doc/ node@nodejs.org:~/web/nodejs.org/

docopen: out/doc/api/all.html
	-google-chrome out/doc/api/all.html

docclean:
	-rm -rf out/doc

VERSION=v$(shell $(PYTHON) deps/node/tools/getnodeversion.py)
TARNAME=node-$(VERSION)
TARBALL=$(TARNAME).tar.gz
PKG=out/$(TARNAME).pkg
packagemaker=/Developer/Applications/Utilities/PackageMaker.app/Contents/MacOS/PackageMaker

dist: doc $(TARBALL) $(PKG)

PKGDIR=out/dist-osx

pkg: $(PKG)

$(PKG):
	rm -rf $(PKGDIR)
	rm -rf out/deps out/Release
	./configure --prefix=$(PKGDIR)/32/usr/local --without-snapshot --dest-cpu=ia32
	$(MAKE) install
	rm -rf out/deps out/Release
	./configure --prefix=$(PKGDIR)/usr/local --without-snapshot --dest-cpu=x64
	$(MAKE) install
	lipo $(PKGDIR)/32/usr/local/bin/node \
		$(PKGDIR)/usr/local/bin/node \
		-output $(PKGDIR)/usr/local/bin/node-universal \
		-create
	mv $(PKGDIR)/usr/local/bin/node-universal $(PKGDIR)/usr/local/bin/node
	rm -rf $(PKGDIR)/32
	$(packagemaker) \
		--id "org.nodejs.NodeJS-$(VERSION)" \
		--doc tools/osx-pkg.pmdoc \
		--out $(PKG)

$(TARBALL): node out/doc
	@if [ $(shell ./node --version) = "$(VERSION)" ]; then \
		exit 0; \
	else \
	  echo "" >&2 ; \
		echo "$(shell ./node --version) doesn't match $(VERSION)." >&2 ; \
	  echo "Did you remember to update src/node_version.cc?" >&2 ; \
	  echo "" >&2 ; \
		exit 1 ; \
	fi
	git archive --format=tar --prefix=$(TARNAME)/ HEAD | tar xf -
	mkdir -p $(TARNAME)/doc
	cp doc/node.1 $(TARNAME)/doc/node.1
	cp -r out/doc/api $(TARNAME)/doc/api
	rm -rf $(TARNAME)/deps/v8/test # too big
	rm -rf $(TARNAME)/doc/images # too big
	tar -cf $(TARNAME).tar $(TARNAME)
	rm -rf $(TARNAME)
	gzip -f -9 $(TARNAME).tar

dist-upload: $(TARBALL) $(PKG)
	ssh node@nodejs.org mkdir -p web/nodejs.org/dist/$(VERSION)
	scp $(TARBALL) node@nodejs.org:~/web/nodejs.org/dist/$(VERSION)/$(TARBALL)
	scp $(PKG) node@nodejs.org:~/web/nodejs.org/dist/$(VERSION)/$(TARNAME).pkg

bench:
	 benchmark/http_simple_bench.sh

bench-idle:
	./node benchmark/idle_server.js &
	sleep 1
	./node benchmark/idle_clients.js &

jslint:
	PYTHONPATH=tools/closure_linter/ $(PYTHON) tools/closure_linter/closure_linter/gjslint.py --unix_mode --strict --nojsdoc -r lib/ -r src/ -r test/ --exclude_files lib/punycode.js

cpplint:
	@$(PYTHON) tools/cpplint.py $(wildcard src/*.cc src/*.h src/*.c)

lint: jslint cpplint

.PHONY: lint cpplint jslint bench clean docopen docclean doc dist distclean check uninstall install install-includes install-bin all program staticlib dynamiclib test test-all website-upload pkg