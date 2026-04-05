/*
 * gnubg_gpu_host.cu - Host-side implementation of the GPU engine interface
 *
 * Bridges between C code and the CUDA kernels declared in gnubg_gpu.cuh.
 * All functions are exported with C linkage so that the CLI driver and
 * other plain-C translation units can call them directly.
 *
 * Copyright (C) 2024 the AUTHORS
 * License: GPL-3.0-or-later (same as gnubg)
 */

#include "gnubg_gpu.cuh"
#include "gnubg_gpu_host.h"

#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cmath>

/* --------------------------------------------------------------------
 * Helpers
 * -------------------------------------------------------------------- */

#define CUDA_CHECK(call)                                                     \
    do {                                                                     \
        cudaError_t err_ = (call);                                           \
        if (err_ != cudaSuccess) {                                           \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                    cudaGetErrorString(err_));                                \
            return -1;                                                       \
        }                                                                    \
    } while (0)

#define CUDA_CHECK_PTR(call)                                                 \
    do {                                                                     \
        cudaError_t err_ = (call);                                           \
        if (err_ != cudaSuccess) {                                           \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                    cudaGetErrorString(err_));                                \
            return NULL;                                                     \
        }                                                                    \
    } while (0)

#define CUDA_CHECK_VOID(call)                                                \
    do {                                                                     \
        cudaError_t err_ = (call);                                           \
        if (err_ != cudaSuccess) {                                           \
            fprintf(stderr, "CUDA error at %s:%d: %s\n", __FILE__, __LINE__, \
                    cudaGetErrorString(err_));                                \
            return;                                                          \
        }                                                                    \
    } while (0)

static const int THREADS_PER_BLOCK = 256;

/* --------------------------------------------------------------------
 * GPUContext - opaque struct hidden from C callers
 * -------------------------------------------------------------------- */

struct GPUContext {
    int deviceId;

    /* Host-side copy of the three nets (pointers inside are device pointers) */
    GPUNets h_nets;

    /* Device-side GPUNets struct (so kernels can dereference it) */
    GPUNets *d_nets;

    /* Device pointers to the raw weight arrays, kept so we can free them.
     * Order: contact, race, crashed.  Each net has 4 arrays. */
    float *d_weights[3][4];
};

/* --------------------------------------------------------------------
 * Helper: read a single neural net from the weight file
 *
 * Reads the header fields, allocates device memory, copies weights,
 * and fills in the GPUNeuralNet struct (whose pointer fields will be
 * device pointers) plus records the device pointers in devPtrs[4]
 * so that the caller can free them later.
 * -------------------------------------------------------------------- */

static int read_net(FILE *fp, GPUNeuralNet *nn, float *devPtrs[4])
{
    unsigned int cInput, cHidden, cOutput;
    int nTrained;
    float rBetaHidden, rBetaOutput;

    if (fread(&cInput,      sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&cHidden,     sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&cOutput,     sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&nTrained,    sizeof(int),          1, fp) != 1) return -1;
    if (fread(&rBetaHidden, sizeof(float),        1, fp) != 1) return -1;
    if (fread(&rBetaOutput, sizeof(float),        1, fp) != 1) return -1;

    nn->cInput      = cInput;
    nn->cHidden     = cHidden;
    nn->cOutput     = cOutput;
    nn->rBetaHidden = rBetaHidden;
    nn->rBetaOutput = rBetaOutput;

    size_t sizeHW = (size_t)cInput  * cHidden * sizeof(float);
    size_t sizeOW = (size_t)cHidden * cOutput * sizeof(float);
    size_t sizeHT = (size_t)cHidden * sizeof(float);
    size_t sizeOT = (size_t)cOutput * sizeof(float);

    /* Allocate temporary host buffers, read from file, copy to device */
    float *h_buf = (float *)malloc(sizeHW);  /* largest of the four */
    if (!h_buf) return -1;

    /* --- arHiddenWeight --- */
    if (fread(h_buf, sizeof(float), (size_t)cInput * cHidden, fp)
            != (size_t)cInput * cHidden) {
        free(h_buf); return -1;
    }
    if (cudaMalloc((void **)&devPtrs[0], sizeHW) != cudaSuccess) {
        free(h_buf); return -1;
    }
    if (cudaMemcpy(devPtrs[0], h_buf, sizeHW, cudaMemcpyHostToDevice)
            != cudaSuccess) {
        free(h_buf); return -1;
    }
    nn->arHiddenWeight = devPtrs[0];

    /* --- arOutputWeight --- */
    if (fread(h_buf, sizeof(float), (size_t)cHidden * cOutput, fp)
            != (size_t)cHidden * cOutput) {
        free(h_buf); return -1;
    }
    if (cudaMalloc((void **)&devPtrs[1], sizeOW) != cudaSuccess) {
        free(h_buf); return -1;
    }
    if (cudaMemcpy(devPtrs[1], h_buf, sizeOW, cudaMemcpyHostToDevice)
            != cudaSuccess) {
        free(h_buf); return -1;
    }
    nn->arOutputWeight = devPtrs[1];

    /* --- arHiddenThreshold --- */
    if (fread(h_buf, sizeof(float), cHidden, fp) != (size_t)cHidden) {
        free(h_buf); return -1;
    }
    if (cudaMalloc((void **)&devPtrs[2], sizeHT) != cudaSuccess) {
        free(h_buf); return -1;
    }
    if (cudaMemcpy(devPtrs[2], h_buf, sizeHT, cudaMemcpyHostToDevice)
            != cudaSuccess) {
        free(h_buf); return -1;
    }
    nn->arHiddenThreshold = devPtrs[2];

    /* --- arOutputThreshold --- */
    if (fread(h_buf, sizeof(float), cOutput, fp) != (size_t)cOutput) {
        free(h_buf); return -1;
    }
    if (cudaMalloc((void **)&devPtrs[3], sizeOT) != cudaSuccess) {
        free(h_buf); return -1;
    }
    if (cudaMemcpy(devPtrs[3], h_buf, sizeOT, cudaMemcpyHostToDevice)
            != cudaSuccess) {
        free(h_buf); return -1;
    }
    nn->arOutputThreshold = devPtrs[3];

    free(h_buf);
    return 0;
}

/* Helper: skip past one neural net in the weight file without loading it */
static int skip_net(FILE *fp)
{
    unsigned int cInput, cHidden, cOutput;
    int nTrained;
    float rBetaHidden, rBetaOutput;

    if (fread(&cInput,      sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&cHidden,     sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&cOutput,     sizeof(unsigned int), 1, fp) != 1) return -1;
    if (fread(&nTrained,    sizeof(int),          1, fp) != 1) return -1;
    if (fread(&rBetaHidden, sizeof(float),        1, fp) != 1) return -1;
    if (fread(&rBetaOutput, sizeof(float),        1, fp) != 1) return -1;

    size_t nFloats = (size_t)cInput * cHidden   /* arHiddenWeight */
                   + (size_t)cHidden * cOutput  /* arOutputWeight */
                   + cHidden                    /* arHiddenThreshold */
                   + cOutput;                   /* arOutputThreshold */

    if (fseek(fp, (long)(nFloats * sizeof(float)), SEEK_CUR) != 0)
        return -1;

    return 0;
}

/* ====================================================================
 * Public API implementations (extern "C")
 * ==================================================================== */

extern "C" {

/* ------------------------------------------------------------------ */
GPUContext *gpu_init(int deviceId)
{
    int deviceCount = 0;
    CUDA_CHECK_PTR(cudaGetDeviceCount(&deviceCount));

    if (deviceId < 0 || deviceId >= deviceCount) {
        fprintf(stderr, "gpu_init: invalid deviceId %d (have %d devices)\n",
                deviceId, deviceCount);
        return NULL;
    }

    CUDA_CHECK_PTR(cudaSetDevice(deviceId));

    cudaDeviceProp prop;
    CUDA_CHECK_PTR(cudaGetDeviceProperties(&prop, deviceId));

    fprintf(stderr, "GPU %d: %s  (compute %d.%d, %.0f MB global, %d SMs)\n",
            deviceId, prop.name, prop.major, prop.minor,
            (double)prop.totalGlobalMem / (1024.0 * 1024.0),
            prop.multiProcessorCount);

    GPUContext *ctx = (GPUContext *)calloc(1, sizeof(GPUContext));
    if (!ctx) {
        fprintf(stderr, "gpu_init: out of host memory\n");
        return NULL;
    }
    ctx->deviceId = deviceId;
    ctx->d_nets   = NULL;

    return ctx;
}

/* ------------------------------------------------------------------ */
int gpu_load_weights(GPUContext *ctx, const char *weightFile)
{
    if (!ctx || !weightFile) return -1;

    FILE *fp = fopen(weightFile, "rb");
    if (!fp) {
        fprintf(stderr, "gpu_load_weights: cannot open %s\n", weightFile);
        return -1;
    }

    /* Verify magic number */
    float magic;
    if (fread(&magic, sizeof(float), 1, fp) != 1) {
        fclose(fp); return -1;
    }
    if (fabsf(magic - 472.3782f) > 0.01f) {
        fprintf(stderr, "gpu_load_weights: bad magic %.4f (expected 472.3782)\n",
                magic);
        fclose(fp);
        return -1;
    }

    /* Verify version */
    float version;
    if (fread(&version, sizeof(float), 1, fp) != 1) {
        fclose(fp); return -1;
    }
    if (fabsf(version - 1.01f) > 0.01f) {
        fprintf(stderr, "gpu_load_weights: bad version %.2f (expected 1.01)\n",
                version);
        fclose(fp);
        return -1;
    }

    /* Read three main nets: contact, race, crashed */
    GPUNets h_nets;
    memset(&h_nets, 0, sizeof(h_nets));

    float *devPtrs[3][4];
    memset(devPtrs, 0, sizeof(devPtrs));

    if (read_net(fp, &h_nets.nnContact, devPtrs[0]) != 0) {
        fprintf(stderr, "gpu_load_weights: failed reading nnContact\n");
        fclose(fp); return -1;
    }
    fprintf(stderr, "  nnContact:  %u -> %u -> %u\n",
            h_nets.nnContact.cInput, h_nets.nnContact.cHidden,
            h_nets.nnContact.cOutput);

    if (read_net(fp, &h_nets.nnRace, devPtrs[1]) != 0) {
        fprintf(stderr, "gpu_load_weights: failed reading nnRace\n");
        fclose(fp); return -1;
    }
    fprintf(stderr, "  nnRace:     %u -> %u -> %u\n",
            h_nets.nnRace.cInput, h_nets.nnRace.cHidden,
            h_nets.nnRace.cOutput);

    if (read_net(fp, &h_nets.nnCrashed, devPtrs[2]) != 0) {
        fprintf(stderr, "gpu_load_weights: failed reading nnCrashed\n");
        fclose(fp); return -1;
    }
    fprintf(stderr, "  nnCrashed:  %u -> %u -> %u\n",
            h_nets.nnCrashed.cInput, h_nets.nnCrashed.cHidden,
            h_nets.nnCrashed.cOutput);

    /* Skip the 3 pruning nets */
    for (int i = 0; i < 3; i++) {
        if (skip_net(fp) != 0) {
            fprintf(stderr, "gpu_load_weights: failed skipping pruning net %d\n", i);
            fclose(fp); return -1;
        }
    }

    fclose(fp);

    /* Allocate GPUNets on device and copy the struct (with device pointers) */
    CUDA_CHECK(cudaMalloc((void **)&ctx->d_nets, sizeof(GPUNets)));
    CUDA_CHECK(cudaMemcpy(ctx->d_nets, &h_nets, sizeof(GPUNets),
                          cudaMemcpyHostToDevice));

    /* Save host copy and device weight pointers for cleanup */
    ctx->h_nets = h_nets;
    memcpy(ctx->d_weights, devPtrs, sizeof(devPtrs));

    fprintf(stderr, "gpu_load_weights: loaded 3 nets from %s\n", weightFile);
    return 0;
}

/* ------------------------------------------------------------------ */
int gpu_play_games(GPUContext *ctx, const HostGameConfig *config,
                   HostGameResult *results)
{
    if (!ctx || !config || !results) return -1;
    if (!ctx->d_nets) {
        fprintf(stderr, "gpu_play_games: weights not loaded\n");
        return -1;
    }

    unsigned int nGames = config->nGames;
    if (nGames == 0) return 0;

    /* Build device-side config */
    GPUGameConfig d_config;
    d_config.nGames    = nGames;
    d_config.maxTurns  = config->maxTurns;
    d_config.evalPlies = config->evalPlies;
    d_config.seed      = (unsigned long long)config->seed;

    /* Allocate device results */
    GPUGameResult *d_results = NULL;
    size_t resultBytes = (size_t)nGames * sizeof(GPUGameResult);
    CUDA_CHECK(cudaMalloc((void **)&d_results, resultBytes));

    /* Launch kernel */
    int blocks = ((int)nGames + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    kernel_play_games<<<blocks, THREADS_PER_BLOCK>>>(
        ctx->d_nets, d_results, d_config);

    CUDA_CHECK(cudaDeviceSynchronize());

    /* Copy results back */
    GPUGameResult *h_gpu_results = (GPUGameResult *)malloc(resultBytes);
    if (!h_gpu_results) {
        cudaFree(d_results);
        return -1;
    }
    CUDA_CHECK(cudaMemcpy(h_gpu_results, d_results, resultBytes,
                          cudaMemcpyDeviceToHost));
    cudaFree(d_results);

    /* Convert GPUGameResult -> HostGameResult */
    for (unsigned int i = 0; i < nGames; i++) {
        results[i].winner       = h_gpu_results[i].winner;
        results[i].winType      = h_gpu_results[i].winType;
        results[i].nTurns       = h_gpu_results[i].nTurns;
        results[i].finalScore[0] = h_gpu_results[i].finalScore[0];
        results[i].finalScore[1] = h_gpu_results[i].finalScore[1];
    }

    free(h_gpu_results);
    return 0;
}

/* ------------------------------------------------------------------ */
int gpu_play_games_stats(GPUContext *ctx, const HostGameConfig *config,
                         HostGameStats *stats)
{
    if (!ctx || !config || !stats) return -1;

    unsigned int nGames = config->nGames;
    if (nGames == 0) {
        memset(stats, 0, sizeof(HostGameStats));
        return 0;
    }

    HostGameResult *results =
        (HostGameResult *)malloc(nGames * sizeof(HostGameResult));
    if (!results) return -1;

    int rc = gpu_play_games(ctx, config, results);
    if (rc != 0) {
        free(results);
        return rc;
    }

    /* Aggregate */
    memset(stats, 0, sizeof(HostGameStats));
    stats->nGames = nGames;

    unsigned long long totalTurns = 0;

    for (unsigned int i = 0; i < nGames; i++) {
        if (results[i].winner == 0)
            stats->player0Wins++;
        else
            stats->player1Wins++;

        if (results[i].winType == 1)
            stats->gammons++;
        else if (results[i].winType == 2)
            stats->backgammons++;

        totalTurns += results[i].nTurns;
    }

    stats->avgTurns = (float)((double)totalTurns / (double)nGames);
    stats->player0WinRate = (float)stats->player0Wins / (float)nGames;

    /* Gammon/BG rates for player 0 (only count gammons/backgammons won by p0) */
    unsigned int p0Gammons = 0;
    unsigned int p0Backgammons = 0;
    for (unsigned int i = 0; i < nGames; i++) {
        if (results[i].winner == 0) {
            if (results[i].winType == 1) p0Gammons++;
            else if (results[i].winType == 2) p0Backgammons++;
        }
    }
    stats->player0GammonRate = (float)p0Gammons / (float)nGames;
    stats->player0BgRate     = (float)p0Backgammons / (float)nGames;

    free(results);
    return 0;
}

/* ------------------------------------------------------------------ */
int gpu_evaluate_positions(GPUContext *ctx,
                           const unsigned int (*boards)[2][25],
                           float *outputs,
                           int nPositions)
{
    if (!ctx || !boards || !outputs || nPositions <= 0) return -1;
    if (!ctx->d_nets) {
        fprintf(stderr, "gpu_evaluate_positions: weights not loaded\n");
        return -1;
    }

    size_t boardBytes  = (size_t)nPositions * sizeof(GPUBoard);
    size_t outputBytes = (size_t)nPositions * GPU_NUM_OUTPUTS * sizeof(float);

    /* Allocate device memory */
    GPUBoard *d_boards = NULL;
    float    *d_outputs = NULL;
    CUDA_CHECK(cudaMalloc((void **)&d_boards, boardBytes));
    CUDA_CHECK(cudaMalloc((void **)&d_outputs, outputBytes));

    /* Copy boards to device */
    CUDA_CHECK(cudaMemcpy(d_boards, boards, boardBytes,
                          cudaMemcpyHostToDevice));

    /* Launch kernel */
    int blocks = (nPositions + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    kernel_evaluate_positions<<<blocks, THREADS_PER_BLOCK>>>(
        ctx->d_nets, d_boards, d_outputs, nPositions);

    CUDA_CHECK(cudaDeviceSynchronize());

    /* Copy results back */
    CUDA_CHECK(cudaMemcpy(outputs, d_outputs, outputBytes,
                          cudaMemcpyDeviceToHost));

    cudaFree(d_boards);
    cudaFree(d_outputs);
    return 0;
}

/* ------------------------------------------------------------------ */
int gpu_find_best_moves(GPUContext *ctx,
                        const unsigned int (*boards)[2][25],
                        const int *dice,
                        HostAnalysisResult *results,
                        int nPositions)
{
    if (!ctx || !boards || !dice || !results || nPositions <= 0) return -1;
    if (!ctx->d_nets) {
        fprintf(stderr, "gpu_find_best_moves: weights not loaded\n");
        return -1;
    }

    size_t boardBytes  = (size_t)nPositions * sizeof(GPUBoard);
    size_t diceBytes   = (size_t)nPositions * 2 * sizeof(int);
    size_t resultBytes = (size_t)nPositions * sizeof(GPUAnalysisResult);

    /* Allocate device memory */
    GPUBoard          *d_boards  = NULL;
    int               *d_dice    = NULL;
    GPUAnalysisResult *d_results = NULL;

    CUDA_CHECK(cudaMalloc((void **)&d_boards,  boardBytes));
    CUDA_CHECK(cudaMalloc((void **)&d_dice,    diceBytes));
    CUDA_CHECK(cudaMalloc((void **)&d_results, resultBytes));

    /* Copy inputs to device */
    CUDA_CHECK(cudaMemcpy(d_boards, boards, boardBytes,
                          cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(d_dice, dice, diceBytes,
                          cudaMemcpyHostToDevice));

    /* Launch kernel */
    int blocks = (nPositions + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    kernel_find_best_moves<<<blocks, THREADS_PER_BLOCK>>>(
        ctx->d_nets, d_boards, d_dice, d_results, nPositions);

    CUDA_CHECK(cudaDeviceSynchronize());

    /* Copy results back to host */
    GPUAnalysisResult *h_gpu_results =
        (GPUAnalysisResult *)malloc(resultBytes);
    if (!h_gpu_results) {
        cudaFree(d_boards);
        cudaFree(d_dice);
        cudaFree(d_results);
        return -1;
    }
    CUDA_CHECK(cudaMemcpy(h_gpu_results, d_results, resultBytes,
                          cudaMemcpyDeviceToHost));

    /* Convert GPUAnalysisResult -> HostAnalysisResult */
    for (int i = 0; i < nPositions; i++) {
        for (int j = 0; j < GPU_NUM_OUTPUTS; j++)
            results[i].arOutput[j] = h_gpu_results[i].arOutput[j];
        for (int j = 0; j < 8; j++)
            results[i].bestMove[j] = h_gpu_results[i].bestMove[j];
        results[i].bestMoveEq = h_gpu_results[i].bestMoveEq;
        results[i].posClass   = h_gpu_results[i].posClass;
    }

    free(h_gpu_results);
    cudaFree(d_boards);
    cudaFree(d_dice);
    cudaFree(d_results);
    return 0;
}

/* ------------------------------------------------------------------ */
void gpu_destroy(GPUContext *ctx)
{
    if (!ctx) return;

    /* Free all device weight arrays (4 per net, 3 nets) */
    for (int net = 0; net < 3; net++) {
        for (int arr = 0; arr < 4; arr++) {
            if (ctx->d_weights[net][arr]) {
                cudaFree(ctx->d_weights[net][arr]);
                ctx->d_weights[net][arr] = NULL;
            }
        }
    }

    /* Free device GPUNets struct */
    if (ctx->d_nets) {
        cudaFree(ctx->d_nets);
        ctx->d_nets = NULL;
    }

    free(ctx);
}

/* ------------------------------------------------------------------ */
int gpu_get_device_count(void)
{
    int count = 0;
    cudaError_t err = cudaGetDeviceCount(&count);
    if (err != cudaSuccess) return 0;
    return count;
}

/* ------------------------------------------------------------------ */
const char *gpu_get_device_name(int deviceId)
{
    /* Use a static buffer - not thread-safe, but matches the simple API */
    static char nameBuf[256];

    int count = 0;
    if (cudaGetDeviceCount(&count) != cudaSuccess || deviceId < 0 ||
            deviceId >= count) {
        nameBuf[0] = '\0';
        return nameBuf;
    }

    cudaDeviceProp prop;
    if (cudaGetDeviceProperties(&prop, deviceId) != cudaSuccess) {
        nameBuf[0] = '\0';
        return nameBuf;
    }

    strncpy(nameBuf, prop.name, sizeof(nameBuf) - 1);
    nameBuf[sizeof(nameBuf) - 1] = '\0';
    return nameBuf;
}

} /* extern "C" */
