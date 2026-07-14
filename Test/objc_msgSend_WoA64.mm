#include <string.h>
#include <assert.h>
#include "../objc/runtime.h"
#include "../objc/hooks.h"

// Pass and return for type size <= 8 bytes.
struct S1 {
  int a[2];
};

// Pass and return hfa <= 8 bytes
struct F1 {
  float a[2];
};

// Pass and return type size <= 16 bytes
struct S2 {
  int a[4];
};

// Pass and return for type size > 16 bytes.
struct S3 {
  int a[5];
};

// Pass and return aggregate (of size < 16 bytes) with non-trivial destructor.
// Sret and inreg: Returned in x0
struct S4 {
  int a[3];
  ~S4();
};
S4::~S4() {
}

// Pass and return an object with a user-provided constructor (passed directly,
// returned indirectly)
struct S5 {
  S5();
  int x;
};
S5::S5() {
  x = 42;
}

Class TestCls;
#ifdef __has_attribute
#if __has_attribute(objc_root_class)
__attribute__((objc_root_class))
#endif
#endif
@interface MsgTest { id isa; } @end
@implementation MsgTest 
+ (S1) smallS1 {
  assert(TestCls == self);
  assert(strcmp("smallS1", sel_getName(_cmd)) == 0);

  S1 x;
  x.a[0] = 0;
  x.a[1] = 1;
  return x;
  
}
+ (F1) smallF1 {
  assert(TestCls == self);
  assert(strcmp("smallF1", sel_getName(_cmd)) == 0);

  F1 x;
  x.a[0] = 0.2f;
  x.a[1] = 0.5f;
  return x;
}
+ (S2) smallS2 {
  assert(TestCls == self);
  assert(strcmp("smallS2", sel_getName(_cmd)) == 0);

  S2 x;
  for (int i = 0; i < 4; i++) {
    x.a[i] = i;
  }
  return x;
}
+ (S3) stretS3 {
  assert(TestCls == self);
  assert(strcmp("stretS3", sel_getName(_cmd)) == 0);

  S3 x;
  for (int i = 0; i < 5; i++) {
    x.a[i] = i;
  }
  return x;
}
+ (S4) stretInRegS4 {
  assert(TestCls == self);
  assert(strcmp("stretInRegS4", sel_getName(_cmd)) == 0);

  S4 x;
  for (int i = 0; i < 3; i++) {
    x.a[i] = i;
  }
  return x;
}
+ (S5) stretInRegS5 {
  assert(TestCls == self);
  assert(strcmp("stretInRegS5", sel_getName(_cmd)) == 0);

  return S5();
}
@end

int main(int argc, char *argv[]) {
  #ifdef __GNUSTEP_MSGSEND__
	TestCls = objc_getClass("MsgTest");

  // Returned in x0
  S1 ret = ((S1(*)(id, SEL))objc_msgSend)(TestCls, @selector(smallS1));
  assert(ret.a[0] == 0);
  assert(ret.a[1] == 1);

  F1 retF1 = ((F1(*)(id, SEL))objc_msgSend)(TestCls, @selector(smallF1));
  assert(retF1.a[0] == 0.2f);
  assert(retF1.a[1] == 0.5f);

  // Returned in x0 and x1
  S2 ret2 = ((S2(*)(id, SEL))objc_msgSend)(TestCls, @selector(smallS2));
  for (int i = 0; i < 4; i++) {
    assert(ret2.a[i] == i);
  }

  // Indirect result register x8 used
  S3 ret3 = ((S3(*)(id, SEL))objc_msgSend_stret)(TestCls, @selector(stretS3));
  for (int i = 0; i < 5; i++) {
    assert(ret3.a[i] == i);
  }
  
  // Stret with inreg. Returned in x0.
  S4 ret4 = ((S4(*)(id, SEL))objc_msgSend_stret2)(TestCls, @selector(stretInRegS4));
  for (int i = 0; i < 3; i++) {
    assert(ret4.a[i] == i);
  }
  
  // Stret with inreg. Returned in x0.
  S5 ret5 = ((S5(*)(id, SEL))objc_msgSend_stret2)(TestCls, @selector(stretInRegS5));
  assert(ret5.x == 42);
  
  return 0;
  #endif // __GNUSTEP_MSGSEND__
  return 77;
}
