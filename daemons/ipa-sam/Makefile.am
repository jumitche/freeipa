NULL =
LIBPDB_NAME = @LIBPDB_NAME@
SAMBA40EXTRA_LIBS = $(SAMBA40EXTRA_LIBPATH)	\
			-lsmbldap		\
			-l$(LIBPDB_NAME)			\
			-lsmbconf		\
			$(NULL)

KRB5_UTIL_DIR=../../util
ASN1_UTIL_DIR=../../asn1

AM_CPPFLAGS =						\
	-I.						\
	-I$(srcdir)					\
	-I$(ASN1_UTIL_DIR)				\
	-I/usr/include/samba-4.0			\
	-DPREFIX=\""$(prefix)"\" 			\
	-DBINDIR=\""$(bindir)"\"			\
	-DLIBDIR=\""$(libdir)"\" 			\
	-DLIBEXECDIR=\""$(libexecdir)"\"		\
	-DDATADIR=\""$(datadir)"\"			\
	-DLDAPIDIR=\""$(localstatedir)/run"\"		\
	-DHAVE_LDAP					\
	-I$(KRB5_UTIL_DIR)				\
	$(CRYPTO_CFLAGS)				\
	$(LDAP_CFLAGS)					\
	$(KRB5_CFLAGS)					\
	$(WARN_CFLAGS)					\
	$(TALLOC_CFLAGS)				\
	$(SAMBAUTIL_CFLAGS)				\
	$(NDR_CFLAGS)					\
	$(SSSIDMAP_CFLAGS)				\
	$(NULL)

plugindir = $(libdir)/samba/pdb
plugin_LTLIBRARIES = 		\
	ipasam.la		\
	$(NULL)

ipasam_la_SOURCES = 		\
	ipa_sam.c		\
	$(KRB5_UTIL_SRCS)	\
	$(NULL)

ipasam_la_LDFLAGS = 		\
	-avoid-version		\
	-module			\
	$(NULL)

ipasam_la_LIBADD = 		\
	$(CRYPTO_LIBS)		\
	$(LDAP_LIBS)		\
	$(KRB5_LIBS)		\
	$(TALLOC_LIBS)		\
	$(SAMBAUTIL_LIBS)	\
	$(NDR_LIBS)		\
	$(SAMBA40EXTRA_LIBS)	\
	$(SSSIDMAP_LIBS)	\
	$(ASN1_UTIL_DIR)/libipaasn1.la  \
	$(KRB5_UTIL_DIR)/libutil.la	\
	$(NULL)

EXTRA_DIST =			\
	README			\
	ipa_sam.h		\
	$(NULL)

MAINTAINERCLEANFILES =		\
	*~			\
	Makefile.in
