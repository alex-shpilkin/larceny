/* Rts/Sys/bdw.h
 * Larceny Run-time system -- statistics gathering for Boehm GC (experimental)
 *
 * $Id: bdw.h,v 1.1.1.1 1998/11/19 21:51:45 lth Exp $
 *
 * This file is to be included from Rts/bdw-gc/alloc.c as the last of
 * the include files; use the line
 *
 *     #include "../Sys/bdw.h"
 *
 * to include it.  It overrides two macros that in our use of the collector
 * are defined to be empty anyway.
 */

#undef STOP_WORLD
#undef START_WORLD

void bdw_before_gc( void );
void bdw_after_gc( void );

#define STOP_WORLD()   bdw_before_gc()
#define START_WORLD()  bdw_after_gc()

/* eof */
