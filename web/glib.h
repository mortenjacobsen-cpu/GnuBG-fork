/* Minimal glib.h replacement for a reduced GNUBG build targeting Wasm.
 * This header provides the small subset of GLib types, macros and
 * function prototypes used by the engine when compiling without full
 * GLib. It pairs with web/glib_stubs.c which provides implementations.
 */

#ifndef WEB_GLIB_H
#define WEB_GLIB_H

#include <stddef.h>
#include <time.h>
#include <alloca.h>

typedef int gboolean;
typedef void *gpointer;
typedef size_t gsize;
typedef char gchar;

#define GLIB_CHECK_VERSION(a,b,c) 0

/* Basic boolean values */
#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

/* Minimal threading-related forward declarations used in headers */
typedef struct _GCond GCond;
typedef struct _GMutex GMutex;
typedef void *GPrivate;

/* Common helpers/macro shims */
#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))

/* Function prototypes provided by web/glib_stubs.c */
extern char *g_build_filename(const char *first, ...);
extern void *g_private_get(void *key);
extern int g_atomic_int_get(const int *p);
extern int g_atomic_int_add(int *p, int val);
extern int g_atomic_int_exchange_and_add(int *p, int val);
#ifndef g_alloca
#define g_alloca(sz) alloca(sz)
#endif

/* Minimal forward declarations for GLib types used in headers */
typedef struct _GMappedFile GMappedFile;
typedef struct _GError GError;

typedef struct _GString {
    char *str;
    size_t len;
} GString;

typedef struct _GList {
    gpointer data;
    struct _GList *next;
    struct _GList *prev;
} GList;

/* Memory */
extern void *g_malloc(size_t size);
extern void *g_malloc0(size_t size);
extern void g_free(void *ptr);
extern void *g_memdup(const void *mem, size_t size);
extern void *g_memdup2(const void *mem, size_t size);
extern char *g_strdup(const char *s);
extern char *g_strdup_printf(const char *fmt, ...);

/* Strings */
extern GString *g_string_new(const char *init);
extern char *g_string_free(GString *gs, gboolean free_segment);
extern GString *g_string_append(GString *gs, const char *str);

/* Lists */
extern GList *g_list_prepend(GList *list, gpointer data);
extern GList *g_list_first(GList *list);
extern GList *g_list_next(GList *list);
extern void g_list_free(GList *list);
extern void g_list_free_full(GList *list, void (*free_func)(gpointer));

/* Print/err */
extern void g_print(const char *fmt, ...);
extern void g_printerr(const char *fmt, ...);

/* Assertions */
extern void g_assertion_message(const char *domain, const char *file, int line, const char *message);
extern void g_assert_not_reached(void);

#define g_assert(expr) ((expr) ? (void)0 : (g_assertion_message(NULL,__FILE__,__LINE__,#expr), g_assert_not_reached()))

/* Convenience macros used in the codebase */
#define g_new(type, count) ((type *) g_malloc(sizeof(type) * (count)))
#define g_new0(type, count) ((type *) g_malloc0(sizeof(type) * (count)))

#endif /* WEB_GLIB_H */
