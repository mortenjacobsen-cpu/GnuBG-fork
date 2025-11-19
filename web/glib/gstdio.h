#ifndef WEB_GLIB_GSTDIO_H
#define WEB_GLIB_GSTDIO_H

/* Minimal gstdio replacement that maps common glib file helpers to stdio */

#include <stdio.h>

#define g_fopen fopen
#define g_fclose fclose
#define g_fread fread
#define g_fwrite fwrite
#define g_remove remove
#define g_rename rename

#endif /* WEB_GLIB_GSTDIO_H */
