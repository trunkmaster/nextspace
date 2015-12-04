CFLAGS=`pkg-config --cflags libkqueue`
LDADD=`pkg-config --libs libkqueue` -ldispatch

all: disptest

disptest: main.o
	$(CC) -o disptest $(CFLAGS) main.c $(LDADD)

check: disptest
	./disptest

clean:
	rm -f *.o

distclean: clean
	rm -f disptest 
