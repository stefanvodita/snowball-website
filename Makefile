# Makefile for building snowball.

JAVADOC=javadoc
JAVAC=jikes
JAVA=java
CC=gcc
RM=rm -f

CFLAGS=-Wall -Wmissing-prototypes -Wmissing-declarations # -Werror

SHELL=/bin/sh
MAKE=make
.SUFFIXES:
.SUFFIXES: .c .h .o .sbl
srcdir=.

languages = danish dutch english french german italian norwegian \
	    porter portuguese russian spanish swedish finnish

snowball_SOURCES = $(srcdir)/p/space.c \
		   $(srcdir)/p/sort.c \
		   $(srcdir)/p/tokeniser.c \
		   $(srcdir)/p/analyser.c \
		   $(srcdir)/p/generator.c \
		   $(srcdir)/p/generator_java.c \
		   $(srcdir)/p/driver.c
snowball_HEADERS = $(srcdir)/p/header.h
snowball_OBJECTS = ./p/space.o \
		   ./p/sort.o \
		   ./p/tokeniser.o \
		   ./p/analyser.o \
		   ./p/generator.o \
		   ./p/generator_java.o \
		   ./p/driver.o

all: $(addprefix lang_, $(languages)) libs snowball_java.tgz #snowball.jar javaoutput

javaoutput: $(addsuffix /output_java.txt, $(languages))

java_SOURCES = net/sf/snowball/Among.java \
               net/sf/snowball/SnowballProgram.java \
               net/sf/snowball/TestApp.java
java_OBJECTS = net/sf/snowball/Among.class \
               net/sf/snowball/SnowballProgram.class \
               net/sf/snowball/TestApp.class
javastemmer_SOURCES = $(addsuffix Stemmer.java, $(addprefix net/sf/snowball/ext/, $(languages)))
javastemmer_OBJECTS = $(addsuffix Stemmer.class, $(addprefix net/sf/snowball/ext/, $(languages)))

snowball.jar: $(java_OBJECTS) $(javastemmer_OBJECTS)
	rm -rf $@
	jar -cvf $@ $(java_OBJECTS) $(javastemmer_OBJECTS)

snowball_java.tgz: $(java_SOURCES) $(javastemmer_SOURCES)
	rm -rf $@
	tar zcvf $@ $(java_SOURCES) $(javastemmer_SOURCES)

javadocs: $(java_SOURCES) $(javastemmer_SOURCES)
	mkdir -p javadocs
	rm -rf javadocs/*
	$(JAVADOC) \
	    -d javadocs \
	    -windowtitle Snowball \
	    net.sf.snowball \
	    net.sf.snowball.ext

lang_%: %/stem.c %/stemmer %/output.txt %/tarball.tgz
	@true

libs: libstemmer/libstemmer.o

LIBSTEMMER_XTRA = libstemmer/modules.c
LIBSTEMMER_SRCS = libstemmer/libstemmer.h \
		libstemmer/wrapper.c \
		q/api.c \
		q/api.h \
		q/utilities.c \
		q/header.h
libpkg: \
		$(addsuffix /stem.c, $(languages)) \
		$(addsuffix /stem.h, $(languages)) \
		$(LIBSTEMMER_SRCS)
	@echo "Building $@";
	@rm -fr libpkg;
	@mkdir -p libpkg;
	@mkdir -p libpkg/libstemmer;
	@echo "" > libpkg/MANIFEST;
	@echo "LIBSTEMMER_SRCS= \\" > libpkg/Makefile_inc.am;
	@for file in $(LIBSTEMMER_SRCS); do \
	  cp $${file} libpkg/libstemmer/; \
	  echo "\$$(STEMMER_DIR)$${file} \\" | sed 's|)q/|)libstemmer/|g' >> libpkg/Makefile_inc.am; \
	  echo "$${file}" | sed 's|q/|libstemmer/|g' >> libpkg/MANIFEST; \
	done;
	@for lang in $(languages); do \
	  mkdir -p libpkg/$${lang}; \
	  cp $${lang}/stem.{c,h} libpkg/$${lang} ; \
	  echo "\$$(STEMMER_DIR)$${lang}/stem.c \\" >> libpkg/Makefile_inc.am; \
	  echo "\$$(STEMMER_DIR)$${lang}/stem.h \\" >> libpkg/Makefile_inc.am; \
	  echo "$${lang}/stem.c" >> libpkg/MANIFEST; \
	  echo "$${lang}/stem.h" >> libpkg/MANIFEST; \
	done;
	@echo "\$$(DUMMY_BLANK_VARIABLE_TO_HELP_AUTOMAKE)" >> libpkg/Makefile_inc.am;
	@echo "LIBSTEMMER_XTRA= \\" >> libpkg/Makefile_inc.am;
	@for file in $(LIBSTEMMER_XTRA); do \
	  cp $${file} libpkg/libstemmer/; \
	  echo "\$$(STEMMER_DIR)$${file} \\" >> libpkg/Makefile_inc.am; \
	  echo "$${file}" >> libpkg/MANIFEST; \
	done;
	@echo "\$$(DUMMY_BLANK_VARIABLE_TO_HELP_AUTOMAKE)" >> libpkg/Makefile_inc.am;

libstemmer/libstemmer.o: $(addsuffix /stem.o, $(languages)) \
	                 libstemmer/wrapper.o \
			 q/api.o \
			 q/utilities.o
	libtool --tag=CXX --mode=link $(CC) $(CFLAGS) -O4 -o $@ -I q/ $^

libstemmer/wrapper.o: libstemmer/wrapper.c libstemmer/modules.c q/api.h
	$(CC) $(CFLAGS) -O4 -c -o $@ -I q/ $<

libstemmer/modules.c: Makefile
	@f=libstemmer/modules.c; \
	echo "Making $$f"; \
	echo "" > $$f; \
	for lang in $(languages); do \
	  echo "#include \"../$${lang}/stem.h\"" >> $$f; \
	done; \
	echo "" >> $$f; \
	echo "struct stemmer_modules {" >> $$f; \
	echo "  const char * name;" >> $$f; \
	echo "  struct SN_env * (*create)(void);" >> $$f; \
	echo "  void (*close)(struct SN_env *);" >> $$f; \
	echo "  int (*stem)(struct SN_env *);" >> $$f; \
	echo "} modules[] = {" >> $$f; \
	for lang in $(languages); do \
	  echo "  {\"$${lang}\", $${lang}_create_env, $${lang}_close_env, $${lang}_stem}, " >> $$f; \
	done; \
	echo "  {0,0,0,0}" >> $$f; \
	echo "};" >> $$f;

clean:
	@for lang in $(languages); do \
	  echo "Cleaning $${lang}/"; \
	  $(RM) $${lang}/stem.[ch] \
	        $${lang}/tarball.tgz \
	        $${lang}/output.txt \
	        $${lang}/.timestamp-output.txt \
	        $${lang}/stemmer \
	        $${lang}/*.o; \
	done
	@echo "Cleaning p/"
	@$(RM) p/*.o
	@echo "Cleaning q/"
	@$(RM) q/*.o
	@echo "Cleaning libstemmer/"
	@$(RM) libstemmer/*.o libstemmer/modules.c
	@echo "Cleaning libpkg/"
	@$(RM) libpkg/*.o libpkg/modules.c
	@echo "Cleaning net/sf/snowball/"
	@$(RM) net/sf/snowball/*.class net/sf/snowball/ext/*

%/tarball.tgz: %/stem.sbl %/stem.c %/stem.h %/voc.txt %/output.txt %/stemmer.html
	@echo "Making $@"
	@tar zcf $@ $^

%/output.txt: %/.timestamp-output.txt
	@if test ! -f $@; then $(RM) $<; $(MAKE) $<; else :; fi
%/.timestamp-output.txt: %/voc.txt %/stemmer
	@l=`echo "$<" | sed 's!\(.*\)/voc.txt$$!\1!;s!^.*/!!'`; \
	echo "Generating $${l}/output.txt"; \
	$(RM) $@; \
	echo timestamp > $@.tmp 2>/dev/null; \
	$${l}/stemmer $< -o $${l}/output.txt.tmp; \
	if cmp -s $${l}/output.txt.tmp $${l}/output.txt 2>/dev/null; then \
	  echo "$${l}/output.txt is unchanged"; \
	  $(RM) $${l}/output.txt.tmp; \
	else \
	  mv $${l}/output.txt.tmp $${l}/output.txt; \
	fi; \
	mv $@.tmp $@;

net/sf/snowball/ext/%Stemmer.java: %/stem.sbl snowball
	@mkdir -p net/sf/snowball/ext
	@l=`echo "$<" | sed 's!\(.*\)/stem.sbl$$!\1!;s!^.*/!!'`; \
	echo ./snowball $< -j -o net/sf/snowball/ext/$${l}Stemmer -n $${l}Stemmer; \
	./snowball $< -j -o net/sf/snowball/ext/$${l}Stemmer -n $${l}Stemmer; \

%/output_java.txt: %/stem.sbl %/voc.txt snowball net/sf/snowball/TestApp.class
	l=`echo "$<" | sed 's!\(.*\)/stem.sbl$$!\1!;s!^.*/!!'`; \
	${MAKE} net/sf/snowball/ext/$${l}Stemmer.java; \
	echo $(JAVAC) net/sf/snowball/ext/$${l}Stemmer.java; \
	$(JAVAC) net/sf/snowball/ext/$${l}Stemmer.java; \
	echo $(JAVA) net/sf/snowball/TestApp $${l} $${l}/voc.txt -o $${l}/output_java.txt; \
	$(JAVA) net/sf/snowball/TestApp $${l} $${l}/voc.txt -o $${l}/output_java.txt;

%.class: %.java
	$(JAVAC) $<


# Rule for building a stemmer program for a given language
BUILD_STEMMER=$(CC) $(CFLAGS) -O4 -o $@ -I $$l/ -I q/ $^ \
	      -Dcreate_env=$${l}_create_env \
	      -Dclose_env=$${l}_close_env \
	      -Dstem=$${l}_stem
%/stemmer: %/stem.o q/api.o q/utilities.o q/driver.c
	@l=`echo "$@" | sed 's!\(.*\)/stemmer$$!\1!;s!^.*/!!'`; \
	echo $(BUILD_STEMMER); \
	$(BUILD_STEMMER)

# Rule for building the snowball to C converter
snowball: $(snowball_OBJECTS) $(snowball_HEADERS)
	$(CC) $(CFLAGS) -O4 -o $@ $(snowball_OBJECTS)

.c.o:
	$(CC) $(CFLAGS) -O4 -c -o $@ $<
%/stem.o: %/stem.c %/stem.h
	$(CC) $(CFLAGS) -O4 -c -o $@ -I q/ $<

# Rules for building the stem.c and stem.h for each language
# The nasty sed expressions are used to extract the bits of the filename
# into the correct from.
%/stem.c %/stem.h: %/stem.sbl snowball
	@l=`echo "$<" | sed 's!\(.*\)/stem.sbl$$!\1!;s!^.*/!!'`; \
	echo ./snowball $< -o $${l}/stem -eprefix $${l}_; \
	./snowball $< -o $${l}/stem -eprefix $${l}_


.PHONY: all lang_% clean libs
.PRECIOUS: %.o
.PRECIOUS: %/stem.c %/stem.h \
	   %/stemmer \
	   %/output.txt \
	   %/output_java.txt \
	   %/tarball.tgz \
	   %/.timestamp-output.txt
