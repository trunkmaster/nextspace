/* A program for testing if the compiler is using non-fragile-ivars.
 * Fails to build or returns 1 if the feature is not availale.
 */

int
main()
{
#ifndef __has_feature
#define __has_feature(x) 0
#endif
return __has_feature(objc_nonfragile_abi) ? 0 : 1;
}

