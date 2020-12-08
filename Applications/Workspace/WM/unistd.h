/* Fix problematic unistd.h on CentOS 7 */
#pragma push_macro("__block")
#undef __block
#define __block my__block
#include_next <unistd.h>
#pragma pop_macro("__block")
