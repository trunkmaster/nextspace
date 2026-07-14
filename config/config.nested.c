/* Used by `configure' to test GCC nested functions */
int main() 
{
  int a = 2;
  void nested(int b)
    {
      a += b;
    }
  void doit(void(*f)(int)) 
    {
      (*f)(4);
    }
  doit(nested);
  if (a != 6)
    exit(-1);
  exit(0);
}
