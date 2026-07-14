/*
 * Check to see if we can open the kernel memory. 
 */
#include <stdio.h>
#include <kvm.h>
#include <fcntl.h>
#include <sys/param.h>
#include <sys/sysctl.h>
int main()
{
  kvm_t *kptr = NULL;

  /* open the kernel */
  kptr = kvm_open(NULL, "/dev/null", NULL, O_RDONLY, "NSProcessInfo");
  return (kptr != NULL) ? 0 : 1;
}
