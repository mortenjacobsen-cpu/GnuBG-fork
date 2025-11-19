/* Minimal GLib stubs to satisfy linking when building a reduced GNUBG core
 * These are intentionally small, not thread-safe, and only implement the
 * subset of GLib helpers commonly used by the engine sources we compile for
 * Wasm. If the linker reports additional missing symbols, we'll extend
 * this file iteratively.
 */

#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <stdint.h>
#include <glib.h>

void *g_malloc(size_t size) {
    void *p = malloc(size);
    if (!p) {
        fprintf(stderr, "g_malloc(%zu) failed\n", size);
        abort();
    }
    return p;
}

void *g_malloc0(size_t size) {
    void *p = calloc(1, size);
    if (!p) {
        fprintf(stderr, "g_malloc0(%zu) failed\n", size);
        abort();
    }
    return p;
}

void g_free(void *ptr) {
    free(ptr);
}

void *g_memdup(const void *mem, size_t size) {
    void *p = malloc(size);
    if (!p) return NULL;
    memcpy(p, mem, size);
    return p;
}

void *g_memdup2(const void *mem, size_t size) {
    return g_memdup(mem, size);
}

char *g_strdup(const char *s) {
    if (!s) return NULL;
    char *d = strdup(s);
    if (!d) {
        fprintf(stderr, "g_strdup failed\n");
        abort();
    }
    return d;
}

char *g_strdup_printf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int needed = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    if (needed < 0) return NULL;
    char *buf = malloc((size_t)needed + 1);
    if (!buf) return NULL;
    va_start(ap, fmt);
    vsnprintf(buf, (size_t)needed + 1, fmt, ap);
    va_end(ap);
    return buf;
}

void g_print(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stdout, fmt, ap);
    va_end(ap);
}

void g_printerr(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
}

void g_assertion_message(const char *domain, const char *file, int line, const char *message) {
    fprintf(stderr, "Assertion failed (%s:%d): %s\n", file, line, message ? message : "(null)");
    abort();
}

void g_assert_not_reached(void) {
    fprintf(stderr, "g_assert_not_reached() hit\n");
    abort();
}

GString *g_string_new(const char *init) {
    GString *gs = (GString *) g_malloc(sizeof(GString));
    if (init) {
        gs->len = strlen(init);
        gs->str = (char *) g_malloc(gs->len + 1);
        memcpy(gs->str, init, gs->len + 1);
    } else {
        gs->len = 0;
        gs->str = (char *) g_malloc(1);
        gs->str[0] = '\0';
    }
    return gs;
}

char *g_string_free(GString *gs, gboolean free_segment) {
    char *ret = NULL;
    if (!gs) return NULL;
    if (free_segment) {
        g_free(gs->str);
    }
    g_free(gs);
    return ret;
}

GString *g_string_append(GString *gs, const char *str) {
    if (!gs) return NULL;
    size_t add = str ? strlen(str) : 0;
    size_t newlen = gs->len + add;
    gs->str = (char *) realloc(gs->str, newlen + 1);
    if (add)
        memcpy(gs->str + gs->len, str, add);
    gs->str[newlen] = '\0';
    gs->len = newlen;
    return gs;
}

GList *g_list_prepend(GList *list, gpointer data) {
    GList *n = (GList *) g_malloc(sizeof(GList));
    n->data = data;
    n->prev = NULL;
    n->next = list;
    if (list) list->prev = n;
    return n;
}

GList *g_list_first(GList *list) {
    GList *p = list;
    while (p && p->prev) p = p->prev;
    return p;
}

GList *g_list_next(GList *list) {
    if (!list) return NULL;
    return list->next;
}

void g_list_free(GList *list) {
    GList *p = g_list_first(list);
    while (p) {
        GList *next = p->next;
        g_free(p);
        p = next;
    }
}

void g_list_free_full(GList *list, void (*free_func)(gpointer)) {
    GList *p = g_list_first(list);
    while (p) {
        GList *next = p->next;
        if (free_func && p->data) free_func(p->data);
        g_free(p);
        p = next;
    }
}

/* simple wrapper helpers sometimes used in code */

char *g_build_filename(const char *first, ...) {
    /* concatenate components with '/' */
    if (!first) return NULL;
    size_t len = strlen(first) + 1;
    va_list ap;
    va_start(ap, first);
    const char *part;
    while ((part = va_arg(ap, const char *)) != NULL) {
        len += strlen(part) + 1; /* '/' or '\0' */
    }
    va_end(ap);

    char *out = (char *) g_malloc(len);
    out[0] = '\0';
    strcat(out, first);
    va_start(ap, first);
    while ((part = va_arg(ap, const char *)) != NULL) {
        strcat(out, "/");
        strcat(out, part);
    }
    va_end(ap);
    return out;
}

void *g_private_get(void *key) {
    (void)key;
    return NULL;
}

int g_atomic_int_get(const int *p) {
    if (!p) return 0;
    return *p;
}

int g_atomic_int_add(int *p, int val) {
    if (!p) return val;
    *p += val;
    return *p;
}

int g_atomic_int_exchange_and_add(int *p, int val) {
    if (!p) return 0;
    int old = *p;
    *p += val;
    return old;
}

