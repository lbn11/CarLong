// musl workaround: raise default pthread stack size for Flutter engine threads.
// musl defaults to 128KB per thread; deep Flutter widget trees overflow it.
// Build: clang -shared -fPIC -O2 -o stackfix.so stackfix.c -ldl
// Use:   LD_PRELOAD=./stackfix.so ./merge_fleet
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef STACKFIX_SIZE
#define STACKFIX_SIZE (8 * 1024 * 1024)
#endif

int pthread_create(pthread_t *t, const pthread_attr_t *attr,
                   void *(*fn)(void *), void *arg) {
  static int (*real)(pthread_t *, const pthread_attr_t *, void *(*)(void *),
                     void *);
  if (!real) real = dlsym(RTLD_NEXT, "pthread_create");

  pthread_attr_t mod;
  const pthread_attr_t *use = attr;
  size_t ss = 0;
  int had = attr && pthread_attr_getstacksize(attr, &ss) == 0 && ss > 0;
  if (had && ss >= STACKFIX_SIZE) {
    return real(t, attr, fn, arg); // already big enough
  }
  if (attr) {
    memcpy(&mod, attr, sizeof(mod));
  } else {
    pthread_attr_init(&mod);
  }
  pthread_attr_setstacksize(&mod, STACKFIX_SIZE);
  use = &mod;
  int r = real(t, use, fn, arg);
  if (getenv("STACKFIX_DEBUG")) {
    fprintf(stderr, "[stackfix] create: attr_ss=%zu -> %d\n", had ? ss : 0, r);
  }
  return r;
}
