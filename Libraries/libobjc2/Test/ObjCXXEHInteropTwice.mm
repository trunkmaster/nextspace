#import "Test.h"

#import "stdio.h"


void excerciseExceptionCXX(Test *e) {
  @try {
    printf("Raising Test\n");
    @throw e;
  } @catch (Test *localException) {
    printf("Caught\n");
  }
}

int main(void)
{
  Test *e = [Test new];
  excerciseExceptionCXX(e);
  excerciseExceptionCXX(e);
  [e release];
}

