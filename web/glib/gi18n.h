#ifndef WEB_GLIB_GI18N_H
#define WEB_GLIB_GI18N_H

/* Minimal gi18n.h replacement: no-op translation macros for builds without
 * gettext. This header is a tiny stand-in so source files that include
 * <glib/gi18n.h> can compile.
 */

#ifndef _
#define _(x) (x)
#endif

#ifndef N_
#define N_(x) (x)
#endif

#endif /* WEB_GLIB_GI18N_H */
