# Makfile for BSD make(1) for FreeBSD 11.1 environment
# $yfId$
#PYTHON  =	/usr/local/bin/python3.7m
#CYTHON  =      /usr/local/bin/cython-3.7
#CFLAGS	+=	-I/usr/local/include/apr-1 -I/usr/local/include/subversion-1 \
#		-I/usr/local/include/python3.7m
#LDFLAGS +=	-L/usr/local/lib
PYTHON  ?=	python
CYTHON  ?=      ${PYTHON} `which cython`
PYTHONCONFIG?=  $(PYTHON)-config
PYCFLAGS ?=     `$(PYTHONCONFIG) --includes`
PYLIBS	?=	`$(PYTHONCONFIG) --libs`
#SVNCFLAGS ?=    `pkg-config --cflags libsvn_subr`
SVNCFLAGS =	-I/usr/local/include -I/usr/local/include/apr-1 \
		-I/usr/local/include/subversion-1
SVNLIBS	  =	-L/usr/local/lib -lz -lmagic -lintl -llz4 -lutf8proc \
		-laprutil-1 -lexpat -lapr-1 -lcrypt -lpthread


COBJS    = vclib/svn/_svn.c vclib/svn/_svn_fs.c

all: vclib/svn/_svn.so vclib/svn/_svn_fs.so

.SUFFIXES: .pyx .pxd .so

.pyx.c:
	$(CYTHON) $(CYTHONFLAGS) $<

# genelic rule, but never used
.c.so:
	$(CC) $(CFLAGS) -fPIC -I/usr/local/include/python2.7 \
	    -shared -pthread \
	    -Wl,-rpath,/usr/lib:/usr/local/lib \
	    -fstack-protector $(LDFLAGS) $< $(LIBS) -o $@

vclib/svn/_svn.c: vclib/svn/_svn.pyx vclib/svn/_svn.pxd vclib/svn/_svn_api.pxd

vclib/svn/_svn.so: vclib/svn/_svn.c
	$(CC) -fPIC $(CFLAGS) $(PYCFLAGS) $(SVNCFLAGS) \
	    -shared -pthread -fstack-protector $(LDFLAGS) $< \
	    $(PYLIBS) $(SVNLIBS) -lsvn_subr-1 -o $@

vclib/svn/_svn_fs.c: vclib/svn/_svn_fs.pyx vclib/svn/_svn_fs.pxd \
			vclib/svn/_svn.pxd vclib/svn/_svn_api.pxd

vclib/svn/_svn_fs.so: vclib/svn/_svn_fs.c
	$(CC) -fPIC $(CFLAGS) $(APRCFLAGS) $(PYCFLAGS) $(SVNCFLAGS) \
	    -shared -pthread -fstack-protector $(LDFLAGS) $< \
	    $(PYLIBS) $(SVNLIBS) -lsvn_subr-1 -lsvn_fs-1 -o $@

cleanobj::
	-rm ${COBJS} *.o

clean::
	-rm ${COBJS} vclib/svn/*.o vclib/svn/*.so
