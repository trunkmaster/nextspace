test-lite: test-lite.c kqlite.c lite.h
	gcc -D_GNU_SOURCE=1 -g -O0 -std=c99 -Wall -Werror -o test-lite test-lite.c kqlite.c

#TODO:
test-dispatch: test-dispatch.c lite.h
	gcc -D_GNU_SOURCE=1 -g -O0 -std=c99 -Wall -Werror -fopenmp -o test-dispatch  kqlite.c test-dispatch.c dispatch.c

check: test-lite
	./test-lite

clean:
	rm -f test-lite *.o
