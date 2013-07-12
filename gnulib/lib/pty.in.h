/* Substitute for and wrapper around <pty.h>.
   Copyright (C) 2010-2012 Free Software Foundation, Inc.

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, see <http://www.gnu.org/licenses/>.  */

#ifndef _@GUARD_PREFIX@_PTY_H

#if __GNUC__ >= 3
@PRAGMA_SYSTEM_HEADER@
#endif
@PRAGMA_COLUMNS@

/* The include_next requires a split double-inclusion guard.  */
#if @HAVE_PTY_H@
# @INCLUDE_NEXT@ @NEXT_PTY_H@
#endif

#ifndef _@GUARD_PREFIX@_PTY_H
#define _@GUARD_PREFIX@_PTY_H

/* Some platforms declare this in a different header than glibc.  */
#if @HAVE_UTIL_H@
# include <util.h>
#endif
#if @HAVE_LIBUTIL_H@
/* <sys/types.h> is a prerequisite of <libutil.h> on FreeBSD 8.0.  */
# include <sys/types.h>
# include <libutil.h>
#endif

/* Get 'struct termios' and 'struct winsize'.  */
#include <termios.h>
#if defined _AIX
# include <sys/ioctl.h>
#endif
/* Mingw lacks 'struct termios' and 'struct winsize', but a forward
   declaration of an opaque type is sufficient to allow compilation of
   a stub openpty().  */
struct termios;
struct winsize;

/* The definitions of _GL_FUNCDECL_RPL etc. are copied here.  */

/* The definition of _GL_WARN_ON_USE is copied here.  */


/* Declare overridden functions.  */

#if @GNULIB_FORKPTY@
/* Create pseudo tty master slave pair and set terminal attributes
   according to TERMP and WINP.  Fork a child process attached to the
   slave end.  Return a handle for the master end in *AMASTER, and
   return the name of the slave end in NAME.  */
# if @REPLACE_FORKPTY@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef forkpty
#   define forkpty rpl_forkpty
#  endif
_GL_FUNCDECL_RPL (forkpty, int,
                  (int *amaster, char *name,
                   struct termios const *termp, struct winsize const *winp));
_GL_CXXALIAS_RPL (forkpty, int,
                  (int *amaster, char *name,
                   struct termios const *termp, struct winsize const *winp));
# else
#  if !@HAVE_FORKPTY@
_GL_FUNCDECL_SYS (forkpty, int,
                  (int *amaster, char *name,
                   struct termios const *termp, struct winsize const *winp));
#  endif
_GL_CXXALIAS_SYS (forkpty, int,
                  (int *amaster, char *name,
                   struct termios const *termp, struct winsize const *winp));
# endif
_GL_CXXALIASWARN (forkpty);
#elif defined GNULIB_POSIXCHECK
# undef forkpty
# if HAVE_RAW_DECL_FORKPTY
_GL_WARN_ON_USE (forkpty, "forkpty is not declared consistently - "
                 "use gnulib module forkpty for portability");
# endif
#endif

#if @GNULIB_OPENPTY@
/* Create pseudo tty master slave pair and set terminal attributes
   according to TERMP and WINP.  Return handles for both ends in
   *AMASTER and *ASLAVE, and return the name of the slave end in NAME.  */
# if @REPLACE_OPENPTY@
#  if !(defined __cplusplus && defined GNULIB_NAMESPACE)
#   undef openpty
#   define openpty rpl_openpty
#  endif
_GL_FUNCDECL_RPL (openpty, int,
                  (int *amaster, int *aslave, char *name,
                   struct termios const *termp, struct winsize const *winp));
_GL_CXXALIAS_RPL (openpty, int,
                  (int *amaster, int *aslave, char *name,
                   struct termios const *termp, struct winsize const *winp));
# else
#  if !@HAVE_OPENPTY@
_GL_FUNCDECL_SYS (openpty, int,
                  (int *amaster, int *aslave, char *name,
                   struct termios const *termp, struct winsize const *winp));
#  endif
_GL_CXXALIAS_SYS (openpty, int,
                  (int *amaster, int *aslave, char *name,
                   struct termios const *termp, struct winsize const *winp));
# endif
_GL_CXXALIASWARN (openpty);
#elif defined GNULIB_POSIXCHECK
# undef openpty
# if HAVE_RAW_DECL_OPENPTY
_GL_WARN_ON_USE (openpty, "openpty is not declared consistently - "
                 "use gnulib module openpty for portability");
# endif
#endif


#endif /* _@GUARD_PREFIX@_PTY_H */
#endif /* _@GUARD_PREFIX@_PTY_H */
