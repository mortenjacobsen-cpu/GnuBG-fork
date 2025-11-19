/* Lightweight stubs used for the Wasm/web build to avoid pulling
 * in desktop GUI or complex multithreading logic.  These provide
 * small, safe no-op implementations for functions referenced by
 * some engine source files so we can link a minimal evaluation
 * runtime for Emscripten.
 *
 * The goal is to satisfy the linker only; behaviour is intentionally
 * minimal and should be replaced with proper implementations if
 * needed later in the web environment.
 */

#include <stddef.h>

/* Provide common GLib-ish aliases if headers are not pulled in. */
#ifndef gboolean
typedef int gboolean;
#endif
#ifndef gpointer
typedef void *gpointer;
#endif
#ifndef FALSE
#define FALSE 0
#endif
#ifndef TRUE
#define TRUE 1
#endif

/* Autosave-related symbol used by multithread/misc code. */
int nAutoSaveTime = 0;

/* No-op process events (desktop GUI loop replacement). */
void ProcessEvents(void) {}

/* Autosave stub used as timer callback in some builds. */
gboolean save_autosave(gpointer UNUSED(unused)) { (void)unused; return FALSE; }

/* Minimal thread API stubs (we don't use threads in the initial Wasm build). */
void MT_CloseThreads(void) { }
void MT_StartThreads(void) { }
void MT_SetNumThreads(unsigned int UNUSED(n)) { (void)n; }

/* Signature matches multithread.h: MT_WaitForTasks(callback, callbackTime, autosave) */
int MT_WaitForTasks(int (*UNUSED(pCallback))(void *), int UNUSED(callbackTime), int UNUSED(autosave)) {
    (void)pCallback; (void)callbackTime; (void)autosave;
    return 0;
}

/* Time helper used by some code paths; return zero for determinism. */
double get_time(void) { return 0.0; }

/* Minimal ProcessEvents alias for some code paths. */
void ProcessEventsIdle(void) { }

/* Some GUI/desktop code references ChangeGame/get_current_moverecord/msBoard;
 * we do not implement game state management in the web stubs. If the build
 * complains about these symbols later, we can add minimal placeholders.
 */

/* End of stubs.c */
