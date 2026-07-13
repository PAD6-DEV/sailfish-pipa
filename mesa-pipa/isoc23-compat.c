/* Compat shims for Ubuntu 24.04+ toolchain headers that rewrite strto*
 * to __isoc23_* while linking against Sailfish OS glibc 2.30.
 * Signatures match glibc redirects; behaviour is the classic strto*.
 */
#include <inttypes.h>
#include <stdlib.h>

long __isoc23_strtol(const char *nptr, char **endptr, int base)
{
  return strtol(nptr, endptr, base);
}

unsigned long __isoc23_strtoul(const char *nptr, char **endptr, int base)
{
  return strtoul(nptr, endptr, base);
}

long long __isoc23_strtoll(const char *nptr, char **endptr, int base)
{
  return strtoll(nptr, endptr, base);
}

unsigned long long __isoc23_strtoull(const char *nptr, char **endptr, int base)
{
  return strtoull(nptr, endptr, base);
}

intmax_t __isoc23_strtoimax(const char *nptr, char **endptr, int base)
{
  return strtoimax(nptr, endptr, base);
}

uintmax_t __isoc23_strtoumax(const char *nptr, char **endptr, int base)
{
  return strtoumax(nptr, endptr, base);
}
