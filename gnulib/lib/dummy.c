/* A dummy file, to prevent empty libraries from breaking builds.
   Copyright (C) 2004, 2007, 2009-2012 Free Software Foundation, Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <http://www.gnu.org/licenses/>.  */

/* Some systems, reportedly OpenBSD and Mac OS X, refuse to create
   libraries without any object files.  You might get an error like:

   > ar cru .libs/libgl.a
   > ar: no archive members specified

   Compiling this file, and adding its object file to the library, will
   prevent the library from being empty.  */

/* Some systems, such as Solaris with cc 5.0, refuse to work with libraries
   that don't export any symbol.  You might get an error like:

   > cc ... libgnu.a
   > ild: (bad file) garbled symbol table in archive ../gllib/libgnu.a

   Compiling this file, and adding its object file to the library, will
   prevent the library from exporting no symbols.  */

#ifdef __sun
/* This declaration ensures that the library will export at least 1 symbol.  */
int gl_dummy_symbol;
#else
/* This declaration is solely to ensure that after preprocessing
   this file is never empty.  */
typedef int dummy;
#endif
