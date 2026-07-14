#if ((defined(_WIN32) || defined(__CYGWIN__)) && defined(__i386__)) || defined(__APPLE__)
#define CDECL(symbol) _##symbol
#else
#define CDECL(symbol) symbol
#endif

#if __ELF__
#define TYPE_DIRECTIVE(symbol, symboltype) .type symbol, symboltype
#else
#define TYPE_DIRECTIVE(symbol, symboltype)
#endif

#if defined(_MSC_VER) && defined(__i386__)
#define STRINGIFY(a) #a
#define EXPORT_SYMBOL(symbol) .ascii  " " STRINGIFY(/EXPORT:_##symbol)
#else
#define EXPORT_SYMBOL(symbol) .ascii  " /EXPORT:" #symbol
#endif
