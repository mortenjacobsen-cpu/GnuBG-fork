/*
 * gnubg_gpu.cuh - CUDA device-side header for GNU Backgammon GPU port
 *
 * Defines GPU-compatible data structures, constants, and device function
 * declarations for running the gnubg engine entirely on GPU.
 *
 * Copyright (C) 2024 the AUTHORS
 * License: GPL-3.0-or-later (same as gnubg)
 */

#ifndef GNUBG_GPU_CUH
#define GNUBG_GPU_CUH

#include <cuda_runtime.h>
#include <curand_kernel.h>

/* ======================================================================
 * Constants - mirroring eval.h / eval.c
 * ====================================================================== */

/* Neural net output indices */
#define GPU_NUM_OUTPUTS         5
#define GPU_OUTPUT_WIN          0
#define GPU_OUTPUT_WINGAMMON    1
#define GPU_OUTPUT_WINBACKGAMMON 2
#define GPU_OUTPUT_LOSEGAMMON   3
#define GPU_OUTPUT_LOSEBACKGAMMON 4

/* Activation function parameters */
#define GPU_BETA_HIDDEN  0.1f
#define GPU_BETA_OUTPUT  1.0f

/* Board dimensions */
#define GPU_NUM_POINTS   25  /* 0-23 = points, 24 = bar */
#define GPU_NUM_CHECKERS 15

/* Input dimensions */
#define GPU_MINPPERPOINT       4
#define GPU_MORE_INPUTS        25  /* Contact-specific features per side */
#define GPU_NUM_INPUTS         ((GPU_NUM_POINTS * GPU_MINPPERPOINT + GPU_MORE_INPUTS) * 2)  /* 250 */
#define GPU_HALF_RACE_INPUTS   107
#define GPU_NUM_RACE_INPUTS    (GPU_HALF_RACE_INPUTS * 2)  /* 214 */
#define GPU_NUM_PRUNING_INPUTS (GPU_NUM_POINTS * GPU_MINPPERPOINT * 2)  /* 200 */

/* Race input offsets */
#define GPU_RI_OFF     92
#define GPU_RI_NCROSS  106

/* Contact input feature offsets */
#define GPU_I_OFF1           0
#define GPU_I_OFF2           1
#define GPU_I_OFF3           2
#define GPU_I_BREAK_CONTACT  3
#define GPU_I_BACK_CHEQUER   4
#define GPU_I_BACK_ANCHOR    5
#define GPU_I_FORWARD_ANCHOR 6
#define GPU_I_PIPLOSS        7
#define GPU_I_P1             8
#define GPU_I_P2             9
#define GPU_I_BACKESCAPES    10
#define GPU_I_ACONTAIN       11
#define GPU_I_ACONTAIN2      12
#define GPU_I_CONTAIN        13
#define GPU_I_CONTAIN2       14
#define GPU_I_MOBILITY       15
#define GPU_I_MOMENT2        16
#define GPU_I_ENTER          17
#define GPU_I_ENTER2         18
#define GPU_I_TIMING         19
#define GPU_I_BACKBONE       20
#define GPU_I_BACKG          21
#define GPU_I_BACKG1         22
#define GPU_I_FREEPIP        23
#define GPU_I_BACKRESCAPES   24

/* Move generation limits */
#define GPU_MAX_MOVES  3060

/* Maximum hidden layer size we support */
#define GPU_MAX_HIDDEN 256

/* Maximum number of inputs across all net types */
#define GPU_MAX_INPUTS 250

/* ======================================================================
 * Position classification
 * ====================================================================== */

enum GPUPositionClass {
    GPU_CLASS_OVER = 0,
    GPU_CLASS_RACE,
    GPU_CLASS_CRASHED,
    GPU_CLASS_CONTACT
};

/* ======================================================================
 * Data structures
 * ====================================================================== */

/* Board representation: anBoard[side][point] = number of checkers */
typedef unsigned int GPUBoard[2][GPU_NUM_POINTS];

/* Compact move representation: up to 4 sub-moves, each (src, dst) */
struct GPUMove {
    int anMove[8];     /* src0,dst0, src1,dst1, ... ; -1 = unused */
    unsigned int cMoves;
    unsigned int cPips;
    float arEval[GPU_NUM_OUTPUTS];
    float rScore;
};

/* Move list for a single position */
struct GPUMoveList {
    unsigned int cMoves;
    unsigned int cMaxMoves;
    unsigned int cMaxPips;
};

/* Neural network weights - stored in GPU global memory */
struct GPUNeuralNet {
    unsigned int cInput;
    unsigned int cHidden;
    unsigned int cOutput;
    float rBetaHidden;
    float rBetaOutput;
    float *arHiddenWeight;    /* [cInput * cHidden] */
    float *arOutputWeight;    /* [cHidden * cOutput] */
    float *arHiddenThreshold; /* [cHidden] */
    float *arOutputThreshold; /* [cOutput] */
};

/* All neural nets needed for evaluation */
struct GPUNets {
    GPUNeuralNet nnContact;
    GPUNeuralNet nnRace;
    GPUNeuralNet nnCrashed;
};

/* Result of a single completed game */
struct GPUGameResult {
    int winner;              /* 0 or 1 */
    int winType;             /* 0=normal, 1=gammon, 2=backgammon */
    unsigned int nTurns;     /* total number of turns played */
    int finalScore[2];       /* points won by each side (0 or points) */
};

/* Configuration for parallel game execution */
struct GPUGameConfig {
    unsigned int nGames;          /* number of games to play in parallel */
    unsigned int maxTurns;        /* safety limit on turns per game */
    unsigned int evalPlies;       /* 0 = 0-ply (direct eval), 1+ = deeper */
    unsigned long long seed;      /* RNG seed */
};

/* Per-position analysis result */
struct GPUAnalysisResult {
    float arOutput[GPU_NUM_OUTPUTS];
    int bestMove[8];
    float bestMoveEq;
    int posClass;
};

/* ======================================================================
 * Sigmoid lookup table (device constant memory)
 * ====================================================================== */

/* e[k] = exp(k/10) / 10, matching sigmoid.h */
__device__ __constant__ float gpu_sigmoid_e[101] = {
    0.10000000000000001f, 0.11051709180756478f, 0.12214027581601698f,
    0.13498588075760032f, 0.14918246976412702f, 0.16487212707001281f,
    0.18221188003905089f, 0.20137527074704767f, 0.22255409284924679f,
    0.245960311115695f,   0.27182818284590454f, 0.30041660239464335f,
    0.33201169227365473f, 0.36692966676192446f, 0.40551999668446748f,
    0.44816890703380646f, 0.49530324243951152f, 0.54739473917271997f,
    0.60496474644129461f, 0.66858944422792688f, 0.73890560989306509f,
    0.81661699125676512f, 0.90250134994341225f, 0.99741824548147184f,
    1.1023176380641602f,  1.2182493960703473f,  1.3463738035001691f,
    1.4879731724872838f,  1.6444646771097049f,  1.817414536944306f,
    2.0085536923187668f,  2.2197951281441637f,  2.4532530197109352f,
    2.7112638920657881f,  2.9964100047397011f,  3.3115451958692312f,
    3.6598234443677988f,  4.0447304360067395f,  4.4701184493300818f,
    4.9402449105530168f,  5.4598150033144233f,  6.034028759736195f,
    6.6686331040925158f,  7.3699793699595784f,  8.1450868664968148f,
    9.0017131300521811f,  9.9484315641933776f,  10.994717245212353f,
    12.151041751873485f,  13.428977968493552f,  14.841315910257659f,
    16.402190729990171f,  18.127224187515122f,  20.033680997479166f,
    22.140641620418716f,  24.469193226422039f,  27.042640742615255f,
    29.886740096706028f,  33.029955990964865f,  36.503746786532886f,
    40.34287934927351f,   44.585777008251675f,  49.274904109325632f,
    54.457191012592901f,  60.184503787208222f,  66.514163304436181f,
    73.509518924197266f,  81.24058251675433f,   89.784729165041753f,
    99.227471560502622f,  109.66331584284585f,  121.19670744925763f,
    133.9430764394418f,   148.02999275845451f,  163.59844299959269f,
    180.80424144560632f,  199.81958951041173f,  220.83479918872089f,
    244.06019776244983f,  269.72823282685101f,  298.09579870417281f,
    329.44680752838406f,  364.09503073323521f,  402.38723938223131f,
    444.7066747699858f,   491.47688402991344f,  543.16595913629783f,
    600.29122172610175f,  663.42440062778894f,  733.19735391559948f,
    810.3083927575384f,   895.52927034825075f,  989.71290587439091f,
    1093.8019208165192f,  1208.8380730216988f,  1335.9726829661872f,
    1476.4781565577266f,  1631.7607198015421f,  1803.3744927828525f,
    1993.0370438230298f,  1993.0370438230298f
};

/* Input encoding lookup tables (device constant memory) */
__device__ __constant__ float gpu_inpvec[16][4] = {
    {0.0f, 0.0f, 0.0f, 0.0f},  /* 0 checkers */
    {1.0f, 0.0f, 0.0f, 0.0f},  /* 1 */
    {0.0f, 1.0f, 0.0f, 0.0f},  /* 2 */
    {0.0f, 0.0f, 1.0f, 0.0f},  /* 3 */
    {0.0f, 0.0f, 1.0f, 0.5f},  /* 4 */
    {0.0f, 0.0f, 1.0f, 1.0f},  /* 5 */
    {0.0f, 0.0f, 1.0f, 1.5f},  /* 6 */
    {0.0f, 0.0f, 1.0f, 2.0f},  /* 7 */
    {0.0f, 0.0f, 1.0f, 2.5f},  /* 8 */
    {0.0f, 0.0f, 1.0f, 3.0f},  /* 9 */
    {0.0f, 0.0f, 1.0f, 3.5f},  /* 10 */
    {0.0f, 0.0f, 1.0f, 4.0f},  /* 11 */
    {0.0f, 0.0f, 1.0f, 4.5f},  /* 12 */
    {0.0f, 0.0f, 1.0f, 5.0f},  /* 13 */
    {0.0f, 0.0f, 1.0f, 5.5f},  /* 14 */
    {0.0f, 0.0f, 1.0f, 6.0f}   /* 15 */
};

/* Bar encoding (cumulative) */
__device__ __constant__ float gpu_inpvecb[16][4] = {
    {0.0f, 0.0f, 0.0f, 0.0f},
    {1.0f, 0.0f, 0.0f, 0.0f},
    {1.0f, 1.0f, 0.0f, 0.0f},
    {1.0f, 1.0f, 1.0f, 0.0f},
    {1.0f, 1.0f, 1.0f, 0.5f},
    {1.0f, 1.0f, 1.0f, 1.0f},
    {1.0f, 1.0f, 1.0f, 1.5f},
    {1.0f, 1.0f, 1.0f, 2.0f},
    {1.0f, 1.0f, 1.0f, 2.5f},
    {1.0f, 1.0f, 1.0f, 3.0f},
    {1.0f, 1.0f, 1.0f, 3.5f},
    {1.0f, 1.0f, 1.0f, 4.0f},
    {1.0f, 1.0f, 1.0f, 4.5f},
    {1.0f, 1.0f, 1.0f, 5.0f},
    {1.0f, 1.0f, 1.0f, 5.5f},
    {1.0f, 1.0f, 1.0f, 6.0f}
};

/* 21 possible dice rolls: 6 doubles + 15 non-doubles */
__device__ __constant__ int gpu_aaRoll[21][2] = {
    {1,1}, {2,2}, {3,3}, {4,4}, {5,5}, {6,6},  /* doubles */
    {1,2}, {1,3}, {1,4}, {1,5}, {1,6},
    {2,3}, {2,4}, {2,5}, {2,6},
    {3,4}, {3,5}, {3,6},
    {4,5}, {4,6},
    {5,6}
};

/* ======================================================================
 * Device function declarations
 * ====================================================================== */

/* Sigmoid approximation matching gnubg's lookup table */
__device__ float gpu_sigmoid(float xin);

/* Neural network forward pass */
__device__ void gpu_nn_evaluate(
    const GPUNeuralNet *pnn,
    const float *arInput,
    float *arOutput);

/* Board to NN input conversion */
__device__ void gpu_base_inputs(const GPUBoard board, float *arInput);
__device__ void gpu_calc_race_inputs(const GPUBoard board, float *arInput);
__device__ void gpu_calc_contact_inputs(const GPUBoard board, float *arInput);
__device__ void gpu_calc_crashed_inputs(const GPUBoard board, float *arInput);

/* Position classification */
__device__ GPUPositionClass gpu_classify_position(const GPUBoard board);

/* Full position evaluation */
__device__ void gpu_evaluate_position(
    const GPUNets *nets,
    const GPUBoard board,
    float *arOutput);

/* Move generation and application */
__device__ int gpu_apply_sub_move(GPUBoard board, int iSrc, int nRoll);
__device__ void gpu_apply_move(GPUBoard board, const int anMove[8]);
__device__ int gpu_legal_move(const GPUBoard board, int iSrc, int nPips);
__device__ int gpu_generate_moves(
    const GPUBoard board,
    GPUMove *moves,
    int n0, int n1);

/* Find best move by evaluating all legal moves */
__device__ int gpu_find_best_move(
    const GPUNets *nets,
    const GPUBoard board,
    int n0, int n1,
    int bestMove[8]);

/* Swap board perspective between players */
__device__ void gpu_swap_sides(GPUBoard board);

/* ======================================================================
 * Kernel declarations
 * ====================================================================== */

/* Play N complete games in parallel, one game per thread */
__global__ void kernel_play_games(
    const GPUNets *nets,
    GPUGameResult *results,
    GPUGameConfig config);

/* Evaluate N positions in parallel */
__global__ void kernel_evaluate_positions(
    const GPUNets *nets,
    const GPUBoard *boards,
    float *outputs,   /* [nPositions * GPU_NUM_OUTPUTS] */
    int nPositions);

/* Find best move for N positions in parallel */
__global__ void kernel_find_best_moves(
    const GPUNets *nets,
    const GPUBoard *boards,
    const int *dice,  /* [nPositions * 2] */
    GPUAnalysisResult *results,
    int nPositions);

#endif /* GNUBG_GPU_CUH */
