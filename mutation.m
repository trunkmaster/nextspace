#include <stdio.h>
#include <stdlib.h>
#include "objc/runtime.h"

// This function is exported as a weak symbol to enable GNUstep or some other
// framework to replace it trivially
OBJC_PUBLIC
void __attribute__((weak)) objc_enumerationMutation(id obj)
{
	fprintf(stderr, "Mutation occurred during enumeration.");
	abort();
}

