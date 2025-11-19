#ifndef GNUBG_WEB_BRIDGE_H
#define GNUBG_WEB_BRIDGE_H

/*
 * The board state from the player-on-roll's perspective.
 * Index 0: opponent's bar
 * Index 1-24: points on the board
 * Index 25: player's bar
 *
 * Values are positive for the player's checkers and negative for the opponent's.
 */
typedef int BoardState[26];

/**
 * Initializes the GNU Backgammon engine.
 * This function must be called once before any other engine functions.
 */
/**
 * Initializes the GNU Backgammon engine using the provided weights files.
 *
 * @param weights_path Path to the textual weights file (e.g. "gnubg.weights").
 *                     If NULL, the engine will attempt to use the binary
 *                     weights file specified by `weights_bin`.
 * @param weights_bin  Path to the binary weights file (e.g. "gnubg.wd").
 *                     May be NULL if not available.
 */
void init_engine(const char *weights_path, const char *weights_bin);

/**
 * Gets the best move from the current board state and dice roll.
 *
 * @param board The current board state.
 * @param dice An array of two integers representing the dice roll.
 * @return A string representing the best move in GNU Backgammon notation.
 *         The caller is responsible for freeing this string.
 */
char* get_best_move(BoardState board, int dice[2]);

#endif // GNUBG_WEB_BRIDGE_H
