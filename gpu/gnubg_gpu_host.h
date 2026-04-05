/*
 * gnubg_gpu_host.h - Host-side C API for GNU Backgammon GPU engine
 *
 * This header provides the interface that C code (CLI driver, etc.) uses
 * to interact with the GPU evaluation engine.  All CUDA details are hidden
 * behind the opaque GPUContext handle.
 *
 * Copyright (C) 2024 the AUTHORS
 * License: GPL-3.0-or-later (same as gnubg)
 */

#ifndef GNUBG_GPU_HOST_H
#define GNUBG_GPU_HOST_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle to GPU context (holds device pointers to nets, etc.) */
typedef struct GPUContext GPUContext;

/* Game result - must match GPUGameResult in .cuh */
typedef struct {
    int winner;
    int winType;       /* 0=normal, 1=gammon, 2=backgammon */
    unsigned int nTurns;
    int finalScore[2];
} HostGameResult;

/* Game config */
typedef struct {
    unsigned int nGames;
    unsigned int maxTurns;
    unsigned int evalPlies;
    uint64_t seed;
} HostGameConfig;

/* Analysis result for a single position */
typedef struct {
    float arOutput[5];  /* WIN, WINGAMMON, WINBG, LOSEGAMMON, LOSEBG */
    int bestMove[8];
    float bestMoveEq;
    int posClass;
} HostAnalysisResult;

/* Aggregate statistics from a batch of games */
typedef struct {
    unsigned int nGames;
    unsigned int player0Wins;
    unsigned int player1Wins;
    unsigned int gammons;
    unsigned int backgammons;
    float avgTurns;
    float player0WinRate;
    float player0GammonRate;
    float player0BgRate;
} HostGameStats;

/* Initialize GPU context: select device, allocate memory */
GPUContext *gpu_init(int deviceId);

/* Load neural network weights from gnubg binary weight file.
 * The weight file is gnubg.wd - the binary format has a magic float (472.3782),
 * version float (1.01), then 6 neural nets in order:
 * nnContact, nnRace, nnCrashed, nnpContact, nnpRace, nnpCrashed
 * Each net: cInput(uint), cHidden(uint), cOutput(uint), nTrained(int),
 *           rBetaHidden(float), rBetaOutput(float),
 *           arHiddenWeight[cInput*cHidden], arOutputWeight[cHidden*cOutput],
 *           arHiddenThreshold[cHidden], arOutputThreshold[cOutput]
 * We only need the first 3 nets (contact, race, crashed).
 */
int gpu_load_weights(GPUContext *ctx, const char *weightFile);

/* Play nGames complete games in parallel on GPU.
 * Results array must be pre-allocated with nGames entries.
 * Returns 0 on success. */
int gpu_play_games(GPUContext *ctx, const HostGameConfig *config,
                   HostGameResult *results);

/* Convenience: play games and return aggregate statistics */
int gpu_play_games_stats(GPUContext *ctx, const HostGameConfig *config,
                         HostGameStats *stats);

/* Evaluate N positions in parallel.
 * boards: array of N boards, each unsigned int[2][25]
 * outputs: array of N*5 floats (5 outputs per position)
 * Returns 0 on success. */
int gpu_evaluate_positions(GPUContext *ctx,
                           const unsigned int (*boards)[2][25],
                           float *outputs,
                           int nPositions);

/* Find best move for N positions in parallel.
 * boards: array of N boards
 * dice: array of N*2 ints (die1, die2 for each position)
 * results: array of N HostAnalysisResult structs
 * Returns 0 on success. */
int gpu_find_best_moves(GPUContext *ctx,
                        const unsigned int (*boards)[2][25],
                        const int *dice,
                        HostAnalysisResult *results,
                        int nPositions);

/* Free GPU context and all device memory */
void gpu_destroy(GPUContext *ctx);

/* Query GPU info */
int gpu_get_device_count(void);
const char *gpu_get_device_name(int deviceId);

#ifdef __cplusplus
}
#endif

#endif /* GNUBG_GPU_HOST_H */
