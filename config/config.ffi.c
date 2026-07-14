#include <stdio.h>
#include <stdlib.h>
#include <ffi.h>


typedef struct cls_struct_combined {
  float a;
  float b;
  float c;
  float d;
} cls_struct_combined;

void cls_struct_combined_fn(struct cls_struct_combined arg)
{
  if (arg.a != 4 || arg.b != 5 || arg.c != 1 || arg.d != 8)
    {
      printf("cls_struct_combined_fn() GOT %g %g %g %g,  EXPECTED 4 5 1 8\n",
	arg.a, arg.b, arg.c, arg.d);
      fflush(stdout);
      abort();
    }
}

static void
cls_struct_combined_gn(ffi_cif* cif, void* resp, void** args, void* userdata)
{
  struct cls_struct_combined a0;

  a0 = *(struct cls_struct_combined*)(args[0]);

  cls_struct_combined_fn(a0);
}


int main (void)
{
  ffi_cif cif;
  void *code;
  ffi_closure *pcl = ffi_closure_alloc(sizeof(ffi_closure), &code);
  ffi_type* cls_struct_fields0[5];
  ffi_type cls_struct_type0;
  ffi_type* dbl_arg_types[5];
  struct cls_struct_combined g_dbl = {4.0, 5.0, 1.0, 8.0};
  int result;

  cls_struct_type0.size = 0;
  cls_struct_type0.alignment = 0;
  cls_struct_type0.type = FFI_TYPE_STRUCT;
  cls_struct_type0.elements = cls_struct_fields0;

  cls_struct_fields0[0] = &ffi_type_float;
  cls_struct_fields0[1] = &ffi_type_float;
  cls_struct_fields0[2] = &ffi_type_float;
  cls_struct_fields0[3] = &ffi_type_float;
  cls_struct_fields0[4] = NULL;

  dbl_arg_types[0] = &cls_struct_type0;
  dbl_arg_types[1] = NULL;

  result = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 1, &ffi_type_void,
    dbl_arg_types);
  if (result != FFI_OK)
    {
      printf("ffi_prep_cif() GOT %d,  EXPECTED %d\n", result, FFI_OK);
      fflush(stdout);
      abort();
    }

  result = ffi_prep_closure_loc(pcl, &cif, cls_struct_combined_gn, NULL, code);
  if (result != FFI_OK)
    {
      printf("ffi_prep_closure_loc() GOT %d,  EXPECTED %d\n", result, FFI_OK);
      fflush(stdout);
      abort();
    }

  ((void(*)(cls_struct_combined)) (code))(g_dbl);
  exit(0);
}
