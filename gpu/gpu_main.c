/*
 * gpu_main.c - Standalone CLI driver for gnubg GPU engine
 *
 * Provides two main modes:
 *   1. Parallel game play: Run thousands of complete backgammon games on GPU
 *   2. Batch position analysis: Evaluate or find best moves for many positions
 *
 * Usage:
 *   gnubg-gpu play -n 10000 -w gnubg.wd [-s seed] [-d device] [-t maxturns]
 *   gnubg-gpu eval -w gnubg.wd -p positions.txt [-d device]
 *   gnubg-gpu bench -n 10000 -w gnubg.wd [-d device]
 *
 * Copyright (C) 2024 the AUTHORS
 * License: GPL-3.0-or-later (same as gnubg)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <getopt.h>

#include "gnubg_gpu_host.h"

static void print_usage(const char *prog) {
    fprintf(stderr,
        "Usage: %s <command> [options]\n"
        "\n"
        "Commands:\n"
        "  play    Play N complete games in parallel on GPU\n"
        "  bench   Benchmark GPU performance with N games\n"
        "  eval    Evaluate positions from a file\n"
        "  info    Show GPU device information\n"
        "\n"
        "Common options:\n"
        "  -w, --weights FILE   Path to gnubg.wd weight file (required)\n"
        "  -n, --games N        Number of games to play (default: 1000)\n"
        "  -d, --device ID      CUDA device ID (default: 0)\n"
        "  -s, --seed SEED      RNG seed (default: time-based)\n"
        "  -t, --max-turns N    Max turns per game safety limit (default: 1000)\n"
        "  -v, --verbose        Verbose output\n"
        "  -h, --help           Show this help\n"
        "\n"
        "Examples:\n"
        "  %s play -n 10000 -w /path/to/gnubg.wd\n"
        "  %s bench -n 50000 -w /path/to/gnubg.wd\n"
        "  %s info\n",
        prog, prog, prog, prog);
}

static void print_game_stats(const HostGameStats *stats) {
    printf("=== Game Results ===\n");
    printf("Games played:       %u\n", stats->nGames);
    printf("Player 0 wins:      %u (%.2f%%)\n",
           stats->player0Wins, stats->player0WinRate * 100.0f);
    printf("Player 1 wins:      %u (%.2f%%)\n",
           stats->player1Wins,
           (1.0f - stats->player0WinRate) * 100.0f);
    printf("Gammons:            %u (%.2f%%)\n",
           stats->gammons, stats->player0GammonRate * 100.0f);
    printf("Backgammons:        %u (%.2f%%)\n",
           stats->backgammons, stats->player0BgRate * 100.0f);
    printf("Avg turns/game:     %.1f\n", stats->avgTurns);
}

static void print_detailed_results(const HostGameResult *results,
                                   unsigned int nGames, int maxPrint) {
    unsigned int i;
    unsigned int limit = (maxPrint > 0 && (unsigned int)maxPrint < nGames)
                         ? (unsigned int)maxPrint : nGames;

    printf("\n=== Detailed Results (first %u of %u) ===\n", limit, nGames);
    printf("%-8s %-8s %-12s %-8s\n", "Game", "Winner", "Type", "Turns");
    printf("%-8s %-8s %-12s %-8s\n", "----", "------", "----", "-----");

    for (i = 0; i < limit; i++) {
        const char *winType;
        switch (results[i].winType) {
        case 0: winType = "Normal"; break;
        case 1: winType = "Gammon"; break;
        case 2: winType = "Backgammon"; break;
        default: winType = "Unknown"; break;
        }
        printf("%-8u %-8d %-12s %-8u\n",
               i + 1, results[i].winner, winType, results[i].nTurns);
    }
}

/* Distribution of game lengths */
static void print_length_distribution(const HostGameResult *results,
                                      unsigned int nGames) {
    unsigned int buckets[20] = {0};  /* 0-9, 10-19, ..., 180-189, 190+ */
    unsigned int i;
    unsigned int maxBucket = 0;

    for (i = 0; i < nGames; i++) {
        unsigned int bucket = results[i].nTurns / 10;
        if (bucket >= 19) bucket = 19;
        buckets[bucket]++;
        if (buckets[bucket] > maxBucket)
            maxBucket = buckets[bucket];
    }

    printf("\n=== Game Length Distribution ===\n");
    for (i = 0; i < 20; i++) {
        if (buckets[i] == 0 && i > 0 && buckets[i-1] == 0)
            continue;
        int barLen = (maxBucket > 0) ? (buckets[i] * 50 / maxBucket) : 0;
        if (i < 19)
            printf("%3u-%3u turns: %6u |", i*10, i*10+9, buckets[i]);
        else
            printf("  190+ turns: %6u |", buckets[i]);
        int j;
        for (j = 0; j < barLen; j++) putchar('#');
        putchar('\n');
    }
}

/* Win type distribution by points scored */
static void print_points_distribution(const HostGameResult *results,
                                      unsigned int nGames) {
    unsigned int normal = 0, gammon = 0, bg = 0;
    unsigned int i;
    double totalPoints[2] = {0, 0};

    for (i = 0; i < nGames; i++) {
        switch (results[i].winType) {
        case 0: normal++; break;
        case 1: gammon++; break;
        case 2: bg++; break;
        }
        totalPoints[0] += results[i].finalScore[0];
        totalPoints[1] += results[i].finalScore[1];
    }

    printf("\n=== Points Distribution ===\n");
    printf("Normal wins:    %u (%.1f%%)\n", normal, 100.0*normal/nGames);
    printf("Gammon wins:    %u (%.1f%%)\n", gammon, 100.0*gammon/nGames);
    printf("Backgammon wins:%u (%.1f%%)\n", bg, 100.0*bg/nGames);
    printf("Avg points/game P0: %.3f\n", totalPoints[0] / nGames);
    printf("Avg points/game P1: %.3f\n", totalPoints[1] / nGames);
}

static int cmd_info(void) {
    int count = gpu_get_device_count();
    int i;

    if (count <= 0) {
        fprintf(stderr, "No CUDA-capable GPU devices found.\n");
        return 1;
    }

    printf("Found %d CUDA device(s):\n\n", count);
    for (i = 0; i < count; i++) {
        const char *name = gpu_get_device_name(i);
        printf("  Device %d: %s\n", i, name ? name : "Unknown");
    }
    printf("\n");
    return 0;
}

static int cmd_play(const char *weightFile, unsigned int nGames,
                    int deviceId, uint64_t seed, unsigned int maxTurns,
                    int verbose) {
    GPUContext *ctx;
    HostGameConfig config;
    HostGameResult *results;
    HostGameStats stats;
    struct timespec t_start, t_end;
    double elapsed;

    printf("Initializing GPU (device %d)...\n", deviceId);
    ctx = gpu_init(deviceId);
    if (!ctx) {
        fprintf(stderr, "Failed to initialize GPU.\n");
        return 1;
    }

    printf("Loading weights from %s...\n", weightFile);
    if (gpu_load_weights(ctx, weightFile) != 0) {
        fprintf(stderr, "Failed to load weights.\n");
        gpu_destroy(ctx);
        return 1;
    }

    results = (HostGameResult *)calloc(nGames, sizeof(HostGameResult));
    if (!results) {
        fprintf(stderr, "Failed to allocate results array.\n");
        gpu_destroy(ctx);
        return 1;
    }

    config.nGames = nGames;
    config.maxTurns = maxTurns;
    config.evalPlies = 0;  /* 0-ply for now */
    config.seed = seed;

    printf("Playing %u games on GPU...\n", nGames);

    clock_gettime(CLOCK_MONOTONIC, &t_start);

    if (gpu_play_games(ctx, &config, results) != 0) {
        fprintf(stderr, "GPU game execution failed.\n");
        free(results);
        gpu_destroy(ctx);
        return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &t_end);

    elapsed = (t_end.tv_sec - t_start.tv_sec) +
              (t_end.tv_nsec - t_start.tv_nsec) / 1e9;

    /* Compute aggregate stats */
    memset(&stats, 0, sizeof(stats));
    stats.nGames = nGames;
    {
        unsigned int i;
        unsigned long totalTurns = 0;
        for (i = 0; i < nGames; i++) {
            if (results[i].winner == 0)
                stats.player0Wins++;
            else
                stats.player1Wins++;
            if (results[i].winType >= 1) stats.gammons++;
            if (results[i].winType >= 2) stats.backgammons++;
            totalTurns += results[i].nTurns;
        }
        stats.avgTurns = (float)totalTurns / nGames;
        stats.player0WinRate = (float)stats.player0Wins / nGames;
        stats.player0GammonRate = (float)stats.gammons / nGames;
        stats.player0BgRate = (float)stats.backgammons / nGames;
    }

    printf("\n");
    print_game_stats(&stats);

    printf("\n=== Performance ===\n");
    printf("Wall time:          %.3f seconds\n", elapsed);
    printf("Games/second:       %.0f\n", nGames / elapsed);
    printf("Avg time/game:      %.3f ms\n", elapsed * 1000.0 / nGames);

    if (verbose) {
        print_detailed_results(results, nGames, 20);
        print_length_distribution(results, nGames);
        print_points_distribution(results, nGames);
    } else {
        print_length_distribution(results, nGames);
    }

    free(results);
    gpu_destroy(ctx);
    return 0;
}

static int cmd_bench(const char *weightFile, unsigned int nGames,
                     int deviceId, uint64_t seed) {
    GPUContext *ctx;
    HostGameConfig config;
    HostGameResult *results;
    struct timespec t_start, t_end;
    double elapsed;
    unsigned int warmup = 100;
    int pass;

    printf("=== gnubg GPU Benchmark ===\n\n");

    ctx = gpu_init(deviceId);
    if (!ctx) { fprintf(stderr, "GPU init failed.\n"); return 1; }

    if (gpu_load_weights(ctx, weightFile) != 0) {
        fprintf(stderr, "Weight load failed.\n");
        gpu_destroy(ctx);
        return 1;
    }

    results = (HostGameResult *)calloc(nGames, sizeof(HostGameResult));
    if (!results) { gpu_destroy(ctx); return 1; }

    config.maxTurns = 1000;
    config.evalPlies = 0;
    config.seed = seed;

    /* Warmup pass */
    printf("Warmup: %u games...\n", warmup);
    config.nGames = warmup;
    gpu_play_games(ctx, &config, results);

    /* Benchmark passes at different scales */
    unsigned int scales[] = {100, 1000, 10000, nGames};
    int nScales = 4;

    printf("\n%-12s %-12s %-15s %-12s\n",
           "Games", "Time (s)", "Games/sec", "ms/game");
    printf("%-12s %-12s %-15s %-12s\n",
           "-----", "--------", "---------", "-------");

    for (pass = 0; pass < nScales; pass++) {
        if (scales[pass] > nGames && pass < nScales - 1)
            continue;

        config.nGames = scales[pass];
        config.seed = seed + pass + 1;

        clock_gettime(CLOCK_MONOTONIC, &t_start);
        gpu_play_games(ctx, &config, results);
        clock_gettime(CLOCK_MONOTONIC, &t_end);

        elapsed = (t_end.tv_sec - t_start.tv_sec) +
                  (t_end.tv_nsec - t_start.tv_nsec) / 1e9;

        printf("%-12u %-12.4f %-15.0f %-12.4f\n",
               scales[pass], elapsed,
               scales[pass] / elapsed,
               elapsed * 1000.0 / scales[pass]);
    }

    free(results);
    gpu_destroy(ctx);
    printf("\nBenchmark complete.\n");
    return 0;
}

int main(int argc, char *argv[]) {
    const char *weightFile = NULL;
    unsigned int nGames = 1000;
    int deviceId = 0;
    uint64_t seed = 0;
    unsigned int maxTurns = 1000;
    int verbose = 0;

    static struct option long_options[] = {
        {"weights",    required_argument, 0, 'w'},
        {"games",      required_argument, 0, 'n'},
        {"device",     required_argument, 0, 'd'},
        {"seed",       required_argument, 0, 's'},
        {"max-turns",  required_argument, 0, 't'},
        {"verbose",    no_argument,       0, 'v'},
        {"help",       no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };

    if (argc < 2) {
        print_usage(argv[0]);
        return 1;
    }

    /* First arg is the command */
    const char *command = argv[1];

    /* Parse remaining options */
    optind = 2;
    int opt;
    while ((opt = getopt_long(argc, argv, "w:n:d:s:t:vh", long_options, NULL)) != -1) {
        switch (opt) {
        case 'w': weightFile = optarg; break;
        case 'n': nGames = (unsigned int)atoi(optarg); break;
        case 'd': deviceId = atoi(optarg); break;
        case 's': seed = (uint64_t)strtoull(optarg, NULL, 10); break;
        case 't': maxTurns = (unsigned int)atoi(optarg); break;
        case 'v': verbose = 1; break;
        case 'h': print_usage(argv[0]); return 0;
        default:  print_usage(argv[0]); return 1;
        }
    }

    /* Default seed from time */
    if (seed == 0) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        seed = (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
    }

    if (strcmp(command, "info") == 0) {
        return cmd_info();
    }

    if (!weightFile) {
        fprintf(stderr, "Error: --weights (-w) is required.\n\n");
        print_usage(argv[0]);
        return 1;
    }

    if (strcmp(command, "play") == 0) {
        return cmd_play(weightFile, nGames, deviceId, seed, maxTurns, verbose);
    } else if (strcmp(command, "bench") == 0) {
        return cmd_bench(weightFile, nGames, deviceId, seed);
    } else if (strcmp(command, "eval") == 0) {
        fprintf(stderr, "Position evaluation mode not yet implemented.\n");
        fprintf(stderr, "Usage: Provide positions via stdin, one per line.\n");
        return 1;
    } else {
        fprintf(stderr, "Unknown command: %s\n\n", command);
        print_usage(argv[0]);
        return 1;
    }
}
