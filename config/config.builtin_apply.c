/*
  Copyright (C) 2005 Free Software Foundation

  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.
*/
typedef void(*apply_t)(void);	/* function pointer */
typedef union {
  char *arg_ptr;
  char arg_regs[sizeof (char*)];
} *arglist_t;			/* argument frame */

double ret_double3(int i, int j)
{
  static double d = 1.23456;
  return d;
}

double ret_double2(int i, int j)
{
  double d = 0.0 + i + j;
  return d;
}

double ret_double(int i, int j)
{
  arglist_t argframe;
  int stack_argsize;
  int reg_argsize;
  void *ret;
  void *(*imp)();
  
  imp = ret_double3;
  /* void *args = __builtin_apply_args(); */
  stack_argsize = 0;
  reg_argsize = 8;
  argframe = (arglist_t) alloca(sizeof(char*) + reg_argsize);
  if (stack_argsize)
    argframe->arg_ptr = alloca(stack_argsize);
  else
    argframe->arg_ptr = 0;

  ret = __builtin_apply(imp, argframe, 0);
  __builtin_return(ret);
}

int main()
{
  double d;

  d = ret_double3(2, 3);
  printf("got %f\n", d);
  d = ret_double(2, 3);
  printf("got %f\n", d);
  exit(0);
}
