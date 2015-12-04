CFLAGS=-I../../include -O0 -g
LDADD=-lpthread
PROGRAM=stresstest
SOURCES=main.c ../timer.c ../user.c ../kevent.c ../read.c ../vnode.c ../test.c

all: $(PROGRAM)

$(PROGRAM): $(SOURCES)
	$(CC) -o $(PROGRAM) $(CFLAGS) $(SOURCES) ../../libkqueue.a $(LDADD)

check: $(PROGRAM)
	@echo "ERROR: The stresstest is currently not usable" ; false
	rm -f core 2>/dev/null
	ulimit -c 999999 ; ./$(PROGRAM) || true
	if [ -f core ] ; then gdb ./$(PROGRAM) core ; fi

valgrind: $(PROGRAM)
	valgrind --tool=memcheck --leak-check=full --show-reachable=yes \
	         --num-callers=20 --track-fds=yes ./$(PROGRAM)

clean:
	rm -f $(PROGRAM) core tags *.o

edit:
	ctags $(SOURCES)
	$(EDITOR) $(SOURCES)

distclean: clean
	rm -f $(PROGRAM) 
