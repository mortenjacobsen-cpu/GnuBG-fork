#include <stdio.h>
#include "web_bridge.h"

int main() {
    printf("Testing GNU Backgammon Web Bridge...\n");

    // Initialize the engine
    init_engine();

    // Define a sample board state (starting position)
    BoardState board = {
        0,  // Opponent's bar
        -2, 0, 0, 0, 0, 5, 0, 3, 0, 0, 0, -5, // Points 1-12
        5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2,  // Points 13-24
        0   // Player's bar
    };

    // Define a sample dice roll
    int dice[2] = {6, 1};

    // Get the best move
    char* best_move = get_best_move(board, dice);

    if (best_move) {
        printf("Best move received: %s\n", best_move);
        // In a real application, we would call free(best_move)
        // but for this simple test, we'll skip it.
    } else {
        printf("Failed to get best move.\n");
    }

    printf("Test complete.\n");
    return 0;
}
