
extern void (*_objc_unexpected_exception)(id);

int main (void)
{
  _objc_unexpected_exception = 0;
  return 0;
}
