# IPA build system cannot cope with parallel build; disable parallel build
.NOTPARALLEL:

include VERSION

SUBDIRS=util asn1 daemons install ipapython ipalib
CLIENTDIRS=ipapython ipalib client util asn1
CLIENTPYDIRS=ipaclient ipaplatform
PYPKGDIRS=$(CLIENTPYDIRS) ipalib ipapython ipaserver ipatests

PRJ_PREFIX=freeipa

RPMBUILD ?= $(PWD)/rpmbuild
TARGET ?= master

IPA_NUM_VERSION ?= $(shell printf %d%02d%02d $(IPA_VERSION_MAJOR) $(IPA_VERSION_MINOR) $(IPA_VERSION_RELEASE))

# After updating the version in VERSION you should run the version-update
# target.

ifeq ($(IPA_VERSION_IS_GIT_SNAPSHOT),"yes")
DATESTR:=$(shell date -u +'%Y%m%d%H%M')
GIT_VERSION:=$(shell git show --pretty=format:"%h" --stat HEAD 2>/dev/null|head -1)
ifneq ($(GIT_VERSION),)
IPA_VERSION=$(IPA_VERSION_MAJOR).$(IPA_VERSION_MINOR).$(IPA_VERSION_RELEASE).$(DATESTR)GIT$(GIT_VERSION)
endif # in a git tree and git returned a version
endif # git

ifndef IPA_VERSION
ifdef IPA_VERSION_ALPHA_RELEASE
IPA_VERSION=$(IPA_VERSION_MAJOR).$(IPA_VERSION_MINOR).$(IPA_VERSION_RELEASE).alpha$(IPA_VERSION_ALPHA_RELEASE)
else
ifdef IPA_VERSION_BETA_RELEASE
IPA_VERSION=$(IPA_VERSION_MAJOR).$(IPA_VERSION_MINOR).$(IPA_VERSION_RELEASE).beta$(IPA_VERSION_BETA_RELEASE)
else
ifdef IPA_VERSION_RC_RELEASE
IPA_VERSION=$(IPA_VERSION_MAJOR).$(IPA_VERSION_MINOR).$(IPA_VERSION_RELEASE).rc$(IPA_VERSION_RC_RELEASE)
else
IPA_VERSION=$(IPA_VERSION_MAJOR).$(IPA_VERSION_MINOR).$(IPA_VERSION_RELEASE)
endif # rc
endif # beta
endif # alpha
endif # ipa_version

IPA_VENDOR_VERSION=$(IPA_VERSION)$(IPA_VENDOR_VERSION_SUFFIX)

TARBALL_PREFIX=freeipa-$(IPA_VERSION)
TARBALL=$(TARBALL_PREFIX).tar.gz

IPA_RPM_RELEASE=$(shell cat RELEASE)

LIBDIR ?= /usr/lib

DEVELOPER_MODE ?= 0
ifneq ($(DEVELOPER_MODE),0)
LINT_IGNORE_FAIL=true
else
LINT_IGNORE_FAIL=false
endif

PYTHON ?= $(shell rpm -E %__python || echo /usr/bin/python2)

CFLAGS := -g -O2 -Wall -Wextra -Wformat-security -Wno-unused-parameter -Wno-sign-compare -Wno-missing-field-initializers $(CFLAGS)
export CFLAGS

# Uncomment to increase Java stack size for Web UI build in case it fails
# because of stack overflow exception. Default should be OK for most platforms.
#JAVA_STACK_SIZE ?= 8m
#export JAVA_STACK_SIZE

all: bootstrap-autogen server tests
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done

# empty target to force executation
.PHONY=FORCE
FORCE:

client: bootstrap-autogen egg_info
	@for subdir in $(CLIENTDIRS); do \
		(cd $$subdir && $(MAKE) all) || exit 1; \
	done
	@for subdir in $(CLIENTPYDIRS); do \
		(cd $$subdir && $(PYTHON) setup.py build); \
	done

check: bootstrap-autogen server tests
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) check) || exit 1; \
	done

client-check: bootstrap-autogen
	@for subdir in $(CLIENTDIRS); do \
		(cd $$subdir && $(MAKE) check) || exit 1; \
	done

bootstrap-autogen: version-update
	@echo "Building IPA $(IPA_VERSION)"
	./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=$(LIBDIR)

install: all server-install tests-install client-install
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done

client-install: client client-dirs
	@for subdir in $(CLIENTDIRS); do \
		(cd $$subdir && $(MAKE) install) || exit 1; \
	done
	cd po && $(MAKE) install || exit 1;
	@for subdir in $(CLIENTPYDIRS); do \
		if [ "$(DESTDIR)" = "" ]; then \
			(cd $$subdir && $(PYTHON) setup.py install); \
		else \
			(cd $$subdir && $(PYTHON) setup.py install --root $(DESTDIR)); \
		fi \
	done

client-dirs:
	@if [ "$(DESTDIR)" != "" ] ; then \
		mkdir -p $(DESTDIR)/etc/ipa ; \
		mkdir -p $(DESTDIR)/var/lib/ipa-client/sysrestore ; \
	else \
		echo "DESTDIR was not set, please create /etc/ipa and /var/lib/ipa-client/sysrestore" ; \
		echo "Without those directories ipa-client-install will fail" ; \
	fi

pylint: bootstrap-autogen
	# find all python modules and executable python files outside modules for pylint check
	FILES=`find . \
		-type d -exec test -e '{}/__init__.py' \; -print -prune -o \
		-path '*/.*' -o \
		-path './dist/*' -o \
		-path './lextab.py' -o \
		-path './yacctab.py' -o \
		-name '*~' -o \
		-name \*.py -print -o \
		-type f -exec grep -qsm1 '^#!.*\bpython' '{}' \; -print`; \
	echo "Pylint is running, please wait ..."; \
	PYTHONPATH=. pylint --rcfile=pylintrc $(PYLINTFLAGS) $$FILES || $(LINT_IGNORE_FAIL)

po-validate:
	$(MAKE) -C po validate-src-strings || $(LINT_IGNORE_FAIL)

jslint:
	cd install/ui; jsl -nologo -nosummary -nofilelisting -conf jsl.conf || $(LINT_IGNORE_FAIL)

lint: apilint acilint pylint po-validate jslint

test:
	./make-test

release-update:
	if [ ! -e RELEASE ]; then echo 0 > RELEASE; fi

ipapython/version.py: ipapython/version.py.in FORCE
	sed -e s/__VERSION__/$(IPA_VERSION)/ $< > $@
	sed -i -e "s:__NUM_VERSION__:$(IPA_NUM_VERSION):" $@
	sed -i -e "s:__VENDOR_VERSION__:$(IPA_VENDOR_VERSION):" $@
	sed -i -e "s:__API_VERSION__:$(IPA_API_VERSION_MAJOR).$(IPA_API_VERSION_MINOR):" $@
	grep -Po '(?<=default: ).*' API.txt | sed -n -i -e "/__DEFAULT_PLUGINS__/!{p;b};r /dev/stdin" $@
	touch -r $< $@

ipasetup.py: ipasetup.py.in FORCE
	sed -e s/__VERSION__/$(IPA_VERSION)/ $< > $@

.PHONY: egg_info
egg_info: ipapython/version.py ipaplatform/__init__.py ipasetup.py
	for directory in $(PYPKGDIRS); do \
	    pushd $${directory} ; \
	    $(PYTHON) setup.py egg_info $(EXTRA_SETUP); \
	    popd ; \
	done

version-update: release-update ipapython/version.py ipasetup.py
	sed -e s/__VERSION__/$(IPA_VERSION)/ -e s/__RELEASE__/$(IPA_RPM_RELEASE)/ \
		freeipa.spec.in > freeipa.spec
	sed -e s/__VERSION__/$(IPA_VERSION)/ version.m4.in \
		> version.m4
	sed -e s/__NUM_VERSION__/$(IPA_NUM_VERSION)/ install/ui/src/libs/loader.js.in \
		> install/ui/src/libs/loader.js
	sed -i -e "s:__API_VERSION__:$(IPA_API_VERSION_MAJOR).$(IPA_API_VERSION_MINOR):" install/ui/src/libs/loader.js
	sed -e s/__VERSION__/$(IPA_VERSION)/ daemons/ipa-version.h.in \
		> daemons/ipa-version.h
	sed -i -e "s:__NUM_VERSION__:$(IPA_NUM_VERSION):" daemons/ipa-version.h
	sed -i -e "s:__DATA_VERSION__:$(IPA_DATA_VERSION):" daemons/ipa-version.h

	sed -e s/__VERSION__/$(IPA_VERSION)/ client/version.m4.in \
		> client/version.m4

apilint: bootstrap-autogen
	./makeapi --validate

acilint: bootstrap-autogen
	./makeaci --validate

server: version-update bootstrap-autogen egg_info
	cd ipaserver && $(PYTHON) setup.py build
	cd ipaplatform && $(PYTHON) setup.py build

server-install: server
	if [ "$(DESTDIR)" = "" ]; then \
		(cd ipaserver && $(PYTHON) setup.py install) || exit 1; \
		(cd ipaplatform && $(PYTHON) setup.py install) || exit 1; \
	else \
		(cd ipaserver && $(PYTHON) setup.py install --root $(DESTDIR)) || exit 1; \
		(cd ipaplatform && $(PYTHON) setup.py install --root $(DESTDIR)) || exit 1; \
	fi

tests: version-update bootstrap-autogen egg_info
	cd ipatests; $(PYTHON) setup.py build
	cd ipatests/man && $(MAKE) all

tests-install: tests
	if [ "$(DESTDIR)" = "" ]; then \
		cd ipatests; $(PYTHON) setup.py install; \
	else \
		cd ipatests; $(PYTHON) setup.py install --root $(DESTDIR); \
	fi
	cd ipatests/man && $(MAKE) install

archive:
	-mkdir -p dist
	git archive --format=tar --prefix=ipa/ $(TARGET) | (cd dist && tar xf -)

local-archive:
	-mkdir -p dist/$(TARBALL_PREFIX)
	rsync -a --exclude=dist --exclude=.git --exclude=/build --exclude=rpmbuild . dist/$(TARBALL_PREFIX)

archive-cleanup:
	rm -fr dist/freeipa

tarballs: local-archive
	-mkdir -p dist/sources
	# tar up clean sources
	cd dist/$(TARBALL_PREFIX); ./autogen.sh --prefix=/usr --sysconfdir=/etc --localstatedir=/var --libdir=$(LIBDIR)
	cd dist/$(TARBALL_PREFIX)/asn1; make distclean
	cd dist/$(TARBALL_PREFIX)/daemons; make distclean
	cd dist/$(TARBALL_PREFIX)/client; make distclean
	cd dist/$(TARBALL_PREFIX)/install; make distclean
	cd dist; tar cfz sources/$(TARBALL) $(TARBALL_PREFIX)
	rm -rf dist/$(TARBALL_PREFIX)

rpmroot:
	rm -rf $(RPMBUILD)
	mkdir -p $(RPMBUILD)/BUILD
	mkdir -p $(RPMBUILD)/RPMS
	mkdir -p $(RPMBUILD)/SOURCES
	mkdir -p $(RPMBUILD)/SPECS
	mkdir -p $(RPMBUILD)/SRPMS

rpmdistdir:
	mkdir -p dist/rpms
	mkdir -p dist/srpms

rpms: rpmroot rpmdistdir version-update lint tarballs
	cp dist/sources/$(TARBALL) $(RPMBUILD)/SOURCES/.
	rpmbuild --define "_topdir $(RPMBUILD)" -ba freeipa.spec
	cp $(RPMBUILD)/RPMS/*/$(PRJ_PREFIX)-*-$(IPA_VERSION)-*.rpm dist/rpms/
	cp $(RPMBUILD)/RPMS/*/python?-ipa*-$(IPA_VERSION)-*.rpm dist/rpms/
	cp $(RPMBUILD)/SRPMS/$(PRJ_PREFIX)-$(IPA_VERSION)-*.src.rpm dist/srpms/
	rm -rf $(RPMBUILD)

client-rpms: rpmroot rpmdistdir version-update lint tarballs
	cp dist/sources/$(TARBALL) $(RPMBUILD)/SOURCES/.
	rpmbuild --define "_topdir $(RPMBUILD)" --define "ONLY_CLIENT 1" -ba freeipa.spec
	cp $(RPMBUILD)/RPMS/*/$(PRJ_PREFIX)-*-$(IPA_VERSION)-*.rpm dist/rpms/
	cp $(RPMBUILD)/RPMS/*/python?-ipa*-$(IPA_VERSION)-*.rpm dist/rpms/
	cp $(RPMBUILD)/SRPMS/$(PRJ_PREFIX)-$(IPA_VERSION)-*.src.rpm dist/srpms/
	rm -rf $(RPMBUILD)

srpms: rpmroot rpmdistdir version-update lint tarballs
	cp dist/sources/$(TARBALL) $(RPMBUILD)/SOURCES/.
	rpmbuild --define "_topdir $(RPMBUILD)" -bs freeipa.spec
	cp $(RPMBUILD)/SRPMS/$(PRJ_PREFIX)-$(IPA_VERSION)-*.src.rpm dist/srpms/
	rm -rf $(RPMBUILD)


repodata:
	-createrepo -p dist

dist: version-update archive tarballs archive-cleanup rpms repodata

local-dist: bootstrap-autogen clean local-archive tarballs archive-cleanup rpms


clean: version-update
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done
	rm -rf ipasetup.py ipasetup.py?
	rm -f *~

distclean: version-update
	touch NEWS AUTHORS ChangeLog
	touch install/NEWS install/README install/AUTHORS install/ChangeLog
	@for subdir in $(SUBDIRS); do \
		(cd $$subdir && $(MAKE) $@) || exit 1; \
	done
	rm -fr $(RPMBUILD) dist build
	rm -f NEWS AUTHORS ChangeLog
	rm -f install/NEWS install/README install/AUTHORS install/ChangeLog

maintainer-clean: clean
	rm -fr $(RPMBUILD) dist build
	cd daemons && $(MAKE) maintainer-clean
	cd install && $(MAKE) maintainer-clean
	cd client && $(MAKE) maintainer-clean
	cd ipapython && $(MAKE) maintainer-clean
	rm -f version.m4
	rm -f freeipa.spec
