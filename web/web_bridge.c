#include "web_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gnubg-types.h"
#include "eval.h"

static int g_engine_initialized = 0;

/* New init accepts paths from the caller (e.g. JS). This avoids calling
 * BuildFilename()/util.c and pulling GLib helpers into the Wasm binary.
 * Pass NULL for either parameter if not available. */
void init_engine(const char *weights_path, const char *weights_bin) {
    if (g_engine_initialized)
        return;

    /* fNoBearoff = 1 to avoid requiring heavy bearoff DBs in the initial Wasm build. */
    EvalInitialise((char *)weights_path, (char *)weights_bin, 1, NULL);

    g_engine_initialized = 1;
    printf("Web Engine Initialized\n");
}

/* Convert the simple BoardState (26 ints) into an internal TanBoard.
 * The BoardState is documented in web_bridge.h as player-on-roll perspective
 * with indices: 0 = opponent's bar, 1-24 = points, 25 = player's bar.
 * TanBoard layout is an unsigned int anBoard[2][25] where index 0 is player
 * on-roll and index 1 is opponent (see gnubg-types.h). We must map
 * the incoming representation into that format. */
static void convert_boardstate_to_tanboard(const BoardState in, TanBoard out) {
    unsigned int i;

    /* Clear board */
    for (i = 0; i < 25; ++i) {
        out[0][i] = 0;
        out[1][i] = 0;
    }

    /* in[0] = opponent's bar (how many of opponent on bar). Map to out[1][24]
       Convention in gnubg: index 24 is the bar (off point 25). */
    out[1][24] = (unsigned int) (in[0] < 0 ? -in[0] : in[0]);

    /* points 1..24 are in[1]..in[24]. Positive values are player's checkers,
       negative for opponent. We need to fill out[0] (player) and out[1] (opp)
       with counts per point. Note: gnubg uses 0..23 for the 24 points and
       24 for the bar; our mapping uses point number-1 to index. */
    for (i = 1; i <= 24; ++i) {
        int v = in[i];
        if (v >= 0) {
            out[0][i - 1] = (unsigned int) v;
        } else {
            out[1][i - 1] = (unsigned int) (-v);
        }
    }

    /* in[25] = player's bar */
    out[0][24] = (unsigned int) (in[25] < 0 ? -in[25] : in[25]);
}

char* get_best_move(BoardState board, int dice[2]) {
    if (!g_engine_initialized)
        return NULL; /* require explicit init with weights path */

    /* Convert board */
    TanBoard anBoard;
    convert_boardstate_to_tanboard(board, anBoard);

    /* Setup cubeinfo: use a cubeless default (ciCubeless) but we make a local copy. */
    cubeinfo ci;
    memcpy(&ci, &ciCubeless, sizeof(ciCubeless));

    /* Use basic evaluation context (0 plies) */
    evalcontext ec;
    memcpy(&ec, &ecBasic, sizeof(ecBasic));

    /* Prepare output move buffer */
    int anMove[8];
    int nDice0 = dice[0];
    int nDice1 = dice[1];

    /* Ensure dice are in 1..6 range. If unrolled (0,0) caller should roll.
       FindBestMove expects dice values in 1..6 */
    if (nDice0 < 1 || nDice0 > 6 || nDice1 < 1 || nDice1 > 6) {
        /* invalid dice: return empty string */
        char *empty = (char*)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }

    (void)anMove; /* no move generation in this minimal Wasm build */

    /* Evaluate the position and return only evaluation metrics as JSON. */
    float arOutput[NUM_ROLLOUT_OUTPUTS];
    if (EvaluatePosition(NULL, (ConstTanBoard) anBoard, arOutput, &ci, &ec) < 0) {
        char *empty = (char*)malloc(1);
        if (empty) empty[0] = '\0';
        return empty;
    }

    float win = arOutput[OUTPUT_WIN];
    float gammon = arOutput[OUTPUT_WINGAMMON] + arOutput[OUTPUT_WINBACKGAMMON];
    float equity = Utility(arOutput, &ci);

    char smallbuf[128];
    int pos = snprintf(smallbuf, sizeof(smallbuf), "{\"move\":[],\"evaluation\":{\"win\":%.6f,\"gammon\":%.6f,\"equity\":%.6f}}", win, gammon, equity);
    if (pos < 0) pos = 0;
    size_t len = (size_t) pos + 1;
    char *ret = (char*) malloc(len);
    if (ret) memcpy(ret, smallbuf, len);
    return ret;
}
