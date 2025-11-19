#ifndef WEB_GLIB_OBJECT_H
#define WEB_GLIB_OBJECT_H

/* Minimal stub of glib-object to satisfy GNUBG includes when building a
 * reduced engine; these do not implement GObject functionality but provide
 * enough declarations for compilation. */

typedef struct _GObject GObject;
typedef unsigned long GType;

typedef struct {
    GType g_type;
} GTypeInstance;

#define G_OBJECT(obj) (obj)

#endif /* WEB_GLIB_OBJECT_H */
