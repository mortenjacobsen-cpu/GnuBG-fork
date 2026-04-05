/*
 * gnubg_gpu.cu - CUDA kernel implementations for GNU Backgammon GPU port
 *
 * Implements neural network evaluation, move generation, position
 * classification, and full game simulation on GPU.
 *
 * Copyright (C) 2024 the AUTHORS
 * License: GPL-3.0-or-later (same as gnubg)
 */

#include "gnubg_gpu.cuh"

/* ======================================================================
 * Sigmoid approximation (matches lib/sigmoid.h)
 * ====================================================================== */

__device__ float gpu_sigmoid(float xin) {
    if (xin >= 0.0f) {
        if (xin < 10.0f) {
            float x1 = 10.0f * xin;
            int i = (int)x1;
            return 1.0f / (1.0f + gpu_sigmoid_e[i] * ((float)(10 - i) + x1));
        } else {
            return 1.0f / 19931.370438230298f;
        }
    } else {
        if (xin > -10.0f) {
            float x1 = -10.0f * xin;
            int i = (int)x1;
            return 1.0f - 1.0f / (1.0f + gpu_sigmoid_e[i] * ((float)(10 - i) + x1));
        } else {
            return 19930.370438230298f / 19931.370438230298f;
        }
    }
}

/* ======================================================================
 * Neural network forward pass (matches lib/neuralnet.c Evaluate())
 * ====================================================================== */

__device__ void gpu_nn_evaluate(
    const GPUNeuralNet *pnn,
    const float *arInput,
    float *arOutput)
{
    float ar[GPU_MAX_HIDDEN];
    unsigned int cHidden = pnn->cHidden;
    unsigned int cInput = pnn->cInput;
    unsigned int cOutput = pnn->cOutput;
    unsigned int i, j;

    /* Initialize hidden layer with thresholds (biases) */
    for (i = 0; i < cHidden; i++)
        ar[i] = pnn->arHiddenThreshold[i];

    /* Accumulate weighted inputs */
    const float *prWeight = pnn->arHiddenWeight;
    for (i = 0; i < cInput; i++) {
        float ari = arInput[i];
        if (ari == 0.0f) {
            prWeight += cHidden;
        } else if (ari == 1.0f) {
            for (j = 0; j < cHidden; j++)
                ar[j] += prWeight[j];
            prWeight += cHidden;
        } else {
            for (j = 0; j < cHidden; j++)
                ar[j] += prWeight[j] * ari;
            prWeight += cHidden;
        }
    }

    /* Apply sigmoid to hidden layer */
    for (i = 0; i < cHidden; i++)
        ar[i] = gpu_sigmoid(-pnn->rBetaHidden * ar[i]);

    /* Compute output layer */
    const float *prOutWeight = pnn->arOutputWeight;
    for (i = 0; i < cOutput; i++) {
        float r = pnn->arOutputThreshold[i];
        for (j = 0; j < cHidden; j++)
            r += ar[j] * prOutWeight[j];
        prOutWeight += cHidden;  /* NOT cOutput - weights are [cOutput][cHidden] */
        arOutput[i] = gpu_sigmoid(-pnn->rBetaOutput * r);
    }
}

/* ======================================================================
 * Board to NN input conversion
 * ====================================================================== */

__device__ void gpu_base_inputs(const GPUBoard board, float *arInput) {
    int side, i;
    for (side = 0; side < 2; side++) {
        float *afInput = arInput + side * 25 * 4;
        /* Points 0-23 */
        for (i = 0; i < 24; i++) {
            unsigned int nc = board[side][i];
            if (nc < 16) {
                afInput[i*4 + 0] = gpu_inpvec[nc][0];
                afInput[i*4 + 1] = gpu_inpvec[nc][1];
                afInput[i*4 + 2] = gpu_inpvec[nc][2];
                afInput[i*4 + 3] = gpu_inpvec[nc][3];
            } else {
                afInput[i*4 + 0] = 0.0f;
                afInput[i*4 + 1] = 0.0f;
                afInput[i*4 + 2] = 1.0f;
                afInput[i*4 + 3] = (float)(nc - 3) / 2.0f;
            }
        }
        /* Bar (point 24) */
        {
            unsigned int nc = board[side][24];
            if (nc < 16) {
                afInput[24*4 + 0] = gpu_inpvecb[nc][0];
                afInput[24*4 + 1] = gpu_inpvecb[nc][1];
                afInput[24*4 + 2] = gpu_inpvecb[nc][2];
                afInput[24*4 + 3] = gpu_inpvecb[nc][3];
            } else {
                afInput[24*4 + 0] = 1.0f;
                afInput[24*4 + 1] = 1.0f;
                afInput[24*4 + 2] = 1.0f;
                afInput[24*4 + 3] = (float)(nc - 3) / 2.0f;
            }
        }
    }
}

__device__ void gpu_calc_race_inputs(const GPUBoard board, float *inputs) {
    unsigned int side;
    for (side = 0; side < 2; side++) {
        unsigned int i, k;
        const unsigned int *b = board[side];
        float *af = inputs + side * GPU_HALF_RACE_INPUTS;
        unsigned int menOff = 15;

        /* Points 0-22: 4 inputs each = 92 inputs */
        for (i = 0; i < 23; i++) {
            unsigned int nc = b[i];
            menOff -= nc;
            k = i * 4;
            af[k]   = (nc == 1) ? 1.0f : 0.0f;
            af[k+1] = (nc == 2) ? 1.0f : 0.0f;
            af[k+2] = (nc >= 3) ? 1.0f : 0.0f;
            af[k+3] = (nc > 3)  ? (float)(nc - 3) / 2.0f : 0.0f;
        }

        /* Men off: 14 one-hot inputs */
        for (k = 0; k < 14; k++)
            af[GPU_RI_OFF + k] = (menOff == (k + 1)) ? 1.0f : 0.0f;

        /* Crossover count */
        {
            unsigned int nCross = 0;
            for (k = 1; k < 4; k++)
                for (i = 6*k; i < 6*k + 6; i++)
                    if (b[i])
                        nCross += b[i] * k;
            af[GPU_RI_NCROSS] = (float)nCross / 10.0f;
        }
    }
}

/* Simplified contact half-inputs (key tactical features) */
__device__ static void gpu_calc_half_inputs(
    const unsigned int anBoard[25],
    const unsigned int anBoardOpp[25],
    float *afInput)
{
    int i, j, nOppBack, n;

    /* Break contact */
    {
        int np = 0;
        for (nOppBack = 24; nOppBack >= 0; --nOppBack)
            if (anBoardOpp[nOppBack]) break;
        nOppBack = 23 - nOppBack;

        for (i = nOppBack + 1; i < 25; i++)
            if (anBoard[i])
                np += (i + 1 - nOppBack) * anBoard[i];
        afInput[GPU_I_BREAK_CONTACT] = (float)np / (15 + 152.0f);
    }

    /* Free pip */
    {
        unsigned int p = 0;
        for (i = 0; i < nOppBack; i++)
            if (anBoard[i])
                p += (i + 1) * anBoard[i];
        afInput[GPU_I_FREEPIP] = (float)p / 100.0f;
    }

    /* Timing (simplified) */
    {
        int t = 0, no = 0;
        int m = (nOppBack >= 11) ? nOppBack : 11;

        t += 24 * anBoard[24];
        no += anBoard[24];

        for (i = 23; i > m; --i) {
            if (anBoard[i] && anBoard[i] != 2) {
                int ns = (anBoard[i] > 2) ? (anBoard[i] - 2) : 1;
                no += ns;
                t += i * ns;
            }
        }
        for (; i >= 6; --i) {
            if (anBoard[i]) {
                no += anBoard[i];
                t += i * anBoard[i];
            }
        }
        for (i = 5; i >= 0; --i) {
            if (anBoard[i] > 2) {
                t += i * (anBoard[i] - 2);
                no += (anBoard[i] - 2);
            } else if (anBoard[i] < 2) {
                int nm = 2 - anBoard[i];
                if (no >= nm) {
                    t -= i * nm;
                    no -= nm;
                }
            }
        }
        afInput[GPU_I_TIMING] = (float)t / 100.0f;
    }

    /* Back chequer and anchors */
    {
        int nBack;
        for (nBack = 24; nBack >= 0; --nBack)
            if (anBoard[nBack]) break;
        afInput[GPU_I_BACK_CHEQUER] = (float)nBack / 24.0f;

        /* Back anchor */
        for (i = ((nBack == 24) ? 23 : nBack); i >= 0; --i)
            if (anBoard[i] >= 2) break;
        afInput[GPU_I_BACK_ANCHOR] = (float)i / 24.0f;

        /* Forward anchor */
        n = 0;
        for (j = 18; j <= i; ++j) {
            if (anBoard[j] >= 2) { n = 24 - j; break; }
        }
        if (n == 0) {
            for (j = 17; j >= 12; --j)
                if (anBoard[j] >= 2) { n = 24 - j; break; }
        }
        afInput[GPU_I_FORWARD_ANCHOR] = (n == 0) ? 2.0f : (float)n / 6.0f;
    }

    /* Simplified pip loss, hit probabilities, escapes, containment */
    /* These use complex precomputed tables on CPU; use approximations on GPU */
    afInput[GPU_I_PIPLOSS] = 0.0f;
    afInput[GPU_I_P1] = 0.0f;
    afInput[GPU_I_P2] = 0.0f;
    afInput[GPU_I_BACKESCAPES] = 0.0f;
    afInput[GPU_I_BACKRESCAPES] = 0.0f;
    afInput[GPU_I_ACONTAIN] = 0.0f;
    afInput[GPU_I_ACONTAIN2] = 0.0f;
    afInput[GPU_I_CONTAIN] = 0.0f;
    afInput[GPU_I_CONTAIN2] = 0.0f;
    afInput[GPU_I_MOBILITY] = 0.0f;

    /* Moment */
    {
        int total = 0, count = 0;
        for (i = 0; i < 25; i++) {
            if (anBoard[i]) { count += anBoard[i]; total += i * anBoard[i]; }
        }
        int avg = (count > 0) ? (total + count - 1) / count : 0;
        int k_val = 0, j_count = 0;
        for (i = avg + 1; i < 25; i++) {
            if (anBoard[i]) {
                j_count += anBoard[i];
                k_val += anBoard[i] * (i - avg) * (i - avg);
            }
        }
        if (j_count) k_val = (k_val + j_count - 1) / j_count;
        afInput[GPU_I_MOMENT2] = (float)k_val / 400.0f;
    }

    /* Enter (bar penalty) */
    if (anBoard[24] > 0) {
        int loss = 0;
        for (i = 0; i < 6; ++i)
            if (anBoardOpp[i] > 1)
                loss += 4 * (i + 1);
        afInput[GPU_I_ENTER] = (float)loss / (36.0f * (49.0f / 6.0f));
    } else {
        afInput[GPU_I_ENTER] = 0.0f;
    }

    /* Enter2 */
    {
        n = 0;
        for (i = 0; i < 6; i++)
            n += (anBoardOpp[i] > 1) ? 1 : 0;
        afInput[GPU_I_ENTER2] = (float)(36 - (n - 6) * (n - 6)) / 36.0f;
    }

    /* Backbone (simplified) */
    {
        int pa = -1, w = 0, tot = 0;
        const int ac[23] = {
            11, 11, 11, 11, 11, 11, 11,
            6, 5, 4, 3, 2,
            0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
        };
        for (int np = 23; np > 0; --np) {
            if (anBoard[np] >= 2) {
                if (pa == -1) { pa = np; continue; }
                int d = pa - np;
                if (d < 23) { w += ac[d] * anBoard[pa]; tot += anBoard[pa]; }
            }
        }
        afInput[GPU_I_BACKBONE] = (tot > 0) ? 1.0f - ((float)w / ((float)tot * 11.0f)) : 0.0f;
    }

    /* Back game indicators */
    {
        unsigned int nAc = 0;
        for (i = 18; i < 24; ++i)
            if (anBoard[i] > 1) ++nAc;

        afInput[GPU_I_BACKG] = 0.0f;
        afInput[GPU_I_BACKG1] = 0.0f;

        if (nAc >= 1) {
            unsigned int tot = 0;
            for (i = 18; i < 25; ++i) tot += anBoard[i];
            if (nAc > 1) {
                afInput[GPU_I_BACKG] = (float)(tot - 3) / 4.0f;
            } else {
                afInput[GPU_I_BACKG1] = (float)tot / 8.0f;
            }
        }
    }
}

/* Men-off encoding for non-crashed positions */
__device__ static void gpu_menoff_non_crashed(const unsigned int *anBoard, float *afInput) {
    int menOff = 15, i;
    for (i = 0; i < 25; ++i) menOff -= anBoard[i];

    if (menOff <= 2) {
        afInput[0] = menOff ? (float)menOff / 3.0f : 0.0f;
        afInput[1] = 0.0f; afInput[2] = 0.0f;
    } else if (menOff <= 5) {
        afInput[0] = 1.0f;
        afInput[1] = (float)(menOff - 3) / 3.0f;
        afInput[2] = 0.0f;
    } else {
        afInput[0] = 1.0f; afInput[1] = 1.0f;
        afInput[2] = (float)(menOff - 6) / 3.0f;
    }
}

/* Men-off encoding for crashed positions */
__device__ static void gpu_menoff_all(const unsigned int *anBoard, float *afInput) {
    int menOff = 15, i;
    for (i = 0; i < 25; i++) menOff -= anBoard[i];

    if (menOff <= 5) {
        afInput[0] = menOff ? (float)menOff / 5.0f : 0.0f;
        afInput[1] = 0.0f; afInput[2] = 0.0f;
    } else if (menOff <= 10) {
        afInput[0] = 1.0f;
        afInput[1] = (float)(menOff - 5) / 5.0f;
        afInput[2] = 0.0f;
    } else {
        afInput[0] = 1.0f; afInput[1] = 1.0f;
        afInput[2] = ((float)menOff - 10) / 5.0f;
    }
}

__device__ void gpu_calc_contact_inputs(const GPUBoard board, float *arInput) {
    gpu_base_inputs(board, arInput);

    /* Side 0 features: board[0] is "own", board[1] is "opponent" */
    float *b = arInput + GPU_MINPPERPOINT * 25 * 2;
    gpu_menoff_non_crashed(board[0], b + GPU_I_OFF1);
    gpu_calc_half_inputs(board[0], board[1], b);

    /* Side 1 features: board[1] is "own", board[0] is "opponent" */
    b = arInput + (GPU_MINPPERPOINT * 25 * 2 + GPU_MORE_INPUTS);
    gpu_menoff_non_crashed(board[1], b + GPU_I_OFF1);
    gpu_calc_half_inputs(board[1], board[0], b);
}

__device__ void gpu_calc_crashed_inputs(const GPUBoard board, float *arInput) {
    gpu_base_inputs(board, arInput);

    /* Side 0 features: board[0] is "own", board[1] is "opponent" */
    float *b = arInput + GPU_MINPPERPOINT * 25 * 2;
    gpu_menoff_all(board[0], b + GPU_I_OFF1);
    gpu_calc_half_inputs(board[0], board[1], b);

    /* Side 1 features: board[1] is "own", board[0] is "opponent" */
    b = arInput + (GPU_MINPPERPOINT * 25 * 2 + GPU_MORE_INPUTS);
    gpu_menoff_all(board[1], b + GPU_I_OFF1);
    gpu_calc_half_inputs(board[1], board[0], b);
}

/* ======================================================================
 * Position classification (matches eval.c ClassifyPosition)
 * ====================================================================== */

__device__ GPUPositionClass gpu_classify_position(const GPUBoard board) {
    int nOppBack, nBack;

    for (nOppBack = 24; nOppBack >= 0; --nOppBack)
        if (board[0][nOppBack]) break;

    for (nBack = 24; nBack >= 0; --nBack)
        if (board[1][nBack]) break;

    if (nBack < 0 || nOppBack < 0)
        return GPU_CLASS_OVER;

    if (nBack + nOppBack > 22) {
        /* Contact position - check for crashed */
        unsigned int N = 6;
        for (int side = 0; side < 2; ++side) {
            unsigned int tot = 0;
            for (int i = 0; i < 25; ++i)
                tot += board[side][i];

            if (tot <= N)
                return GPU_CLASS_CRASHED;
            if (board[side][0] > 1) {
                if (tot <= N + board[side][0])
                    return GPU_CLASS_CRASHED;
                if ((1 + tot - (board[side][0] + board[side][1])) <= N && board[side][1] > 1)
                    return GPU_CLASS_CRASHED;
            } else {
                if (board[side][1] > 1 && tot <= N + (board[side][1] - 1))
                    return GPU_CLASS_CRASHED;
            }
        }
        return GPU_CLASS_CONTACT;
    }

    /* No contact - race (no bearoff databases on GPU) */
    return GPU_CLASS_RACE;
}

/* ======================================================================
 * Full position evaluation
 * ====================================================================== */

__device__ static void gpu_eval_over(const GPUBoard board, float *arOutput) {
    int i;
    int n = 15;  /* standard backgammon */

    /* Check if player 0 (opponent of player on roll) has no pieces */
    int hasP0 = 0;
    for (i = 0; i < 25; i++)
        if (board[0][i]) { hasP0 = 1; break; }

    if (!hasP0) {
        /* Player 0 has no pieces; player 1 has lost */
        arOutput[GPU_OUTPUT_WIN] = 0.0f;
        arOutput[GPU_OUTPUT_WINGAMMON] = 0.0f;
        arOutput[GPU_OUTPUT_WINBACKGAMMON] = 0.0f;

        int c = 0;
        for (i = 0; i < 25; i++) c += board[1][i];

        if (c == n) {
            arOutput[GPU_OUTPUT_LOSEGAMMON] = 1.0f;
            for (i = 18; i < 25; i++) {
                if (board[1][i]) {
                    arOutput[GPU_OUTPUT_LOSEBACKGAMMON] = 1.0f;
                    return;
                }
            }
            arOutput[GPU_OUTPUT_LOSEBACKGAMMON] = 0.0f;
        } else {
            arOutput[GPU_OUTPUT_LOSEGAMMON] = 0.0f;
            arOutput[GPU_OUTPUT_LOSEBACKGAMMON] = 0.0f;
        }
        return;
    }

    /* Check if player 1 (player on roll) has no pieces */
    int hasP1 = 0;
    for (i = 0; i < 25; i++)
        if (board[1][i]) { hasP1 = 1; break; }

    if (!hasP1) {
        /* Player 1 wins */
        arOutput[GPU_OUTPUT_WIN] = 1.0f;
        arOutput[GPU_OUTPUT_LOSEGAMMON] = 0.0f;
        arOutput[GPU_OUTPUT_LOSEBACKGAMMON] = 0.0f;

        int c = 0;
        for (i = 0; i < 25; i++) c += board[0][i];

        if (c == n) {
            arOutput[GPU_OUTPUT_WINGAMMON] = 1.0f;
            for (i = 18; i < 25; i++) {
                if (board[0][i]) {
                    arOutput[GPU_OUTPUT_WINBACKGAMMON] = 1.0f;
                    return;
                }
            }
            arOutput[GPU_OUTPUT_WINBACKGAMMON] = 0.0f;
        } else {
            arOutput[GPU_OUTPUT_WINGAMMON] = 0.0f;
            arOutput[GPU_OUTPUT_WINBACKGAMMON] = 0.0f;
        }
    }
}

__device__ void gpu_evaluate_position(
    const GPUNets *nets,
    const GPUBoard board,
    float *arOutput)
{
    GPUPositionClass pc = gpu_classify_position(board);

    switch (pc) {
    case GPU_CLASS_OVER:
        gpu_eval_over(board, arOutput);
        break;
    case GPU_CLASS_RACE: {
        float arInput[GPU_NUM_RACE_INPUTS];
        gpu_calc_race_inputs(board, arInput);
        gpu_nn_evaluate(&nets->nnRace, arInput, arOutput);
        break;
    }
    case GPU_CLASS_CRASHED: {
        float arInput[GPU_NUM_INPUTS];
        gpu_calc_crashed_inputs(board, arInput);
        gpu_nn_evaluate(&nets->nnCrashed, arInput, arOutput);
        break;
    }
    case GPU_CLASS_CONTACT: {
        float arInput[GPU_NUM_INPUTS];
        gpu_calc_contact_inputs(board, arInput);
        gpu_nn_evaluate(&nets->nnContact, arInput, arOutput);
        break;
    }
    }

    /* Sanity checks */
    if (arOutput[GPU_OUTPUT_WIN] < 0.0f) arOutput[GPU_OUTPUT_WIN] = 0.0f;
    if (arOutput[GPU_OUTPUT_WIN] > 1.0f) arOutput[GPU_OUTPUT_WIN] = 1.0f;
    if (arOutput[GPU_OUTPUT_WINGAMMON] > arOutput[GPU_OUTPUT_WIN])
        arOutput[GPU_OUTPUT_WINGAMMON] = arOutput[GPU_OUTPUT_WIN];
    if (arOutput[GPU_OUTPUT_WINBACKGAMMON] > arOutput[GPU_OUTPUT_WINGAMMON])
        arOutput[GPU_OUTPUT_WINBACKGAMMON] = arOutput[GPU_OUTPUT_WINGAMMON];

    float lose = 1.0f - arOutput[GPU_OUTPUT_WIN];
    if (arOutput[GPU_OUTPUT_LOSEGAMMON] > lose)
        arOutput[GPU_OUTPUT_LOSEGAMMON] = lose;
    if (arOutput[GPU_OUTPUT_LOSEBACKGAMMON] > arOutput[GPU_OUTPUT_LOSEGAMMON])
        arOutput[GPU_OUTPUT_LOSEBACKGAMMON] = arOutput[GPU_OUTPUT_LOSEGAMMON];
}

/* ======================================================================
 * Move generation and application (matches eval.c)
 * ====================================================================== */

__device__ int gpu_apply_sub_move(GPUBoard board, int iSrc, int nRoll) {
    int iDest = iSrc - nRoll;

    if (iSrc < 0 || iSrc > 24 || board[1][iSrc] < 1)
        return -1;

    board[1][iSrc]--;

    if (iDest < 0)
        return 0;  /* Bearing off */

    if (board[0][23 - iDest] > 1)
        return -1;  /* Blocked */

    if (board[0][23 - iDest] == 1) {
        /* Hit: capture opponent's blot, place our checker */
        board[1][iDest] = 1;
        board[0][23 - iDest] = 0;
        board[0][24]++;
    } else {
        board[1][iDest]++;
    }
    return 0;
}

__device__ void gpu_apply_move(GPUBoard board, const int anMove[8]) {
    for (int i = 0; i < 8 && anMove[i] >= 0; i += 2) {
        int iSrc = anMove[i];
        int nRoll = anMove[i] - anMove[i+1];
        gpu_apply_sub_move(board, iSrc, nRoll);
    }
}

__device__ int gpu_legal_move(const GPUBoard board, int iSrc, int nPips) {
    int iDest = iSrc - nPips;

    if (iDest >= 0)
        return (board[0][23 - iDest] < 2) ? 1 : 0;

    /* Bearing off */
    int nBack;
    for (nBack = 24; nBack > 0; nBack--)
        if (board[1][nBack] > 0) break;

    return (nBack <= 5 && (iSrc == nBack || iDest == -1)) ? 1 : 0;
}

/* Position key for deduplication (simplified hash) */
__device__ static unsigned int gpu_position_hash(const GPUBoard board) {
    unsigned int h = 0;
    for (int i = 0; i < 25; i++) {
        h = h * 31 + board[0][i];
        h = h * 31 + board[1][i];
    }
    return h;
}

/* Max moves we store per thread */
#define GPU_MOVE_BUF_SIZE 256

/* Iterative move generation using explicit stack */
struct MoveGenState {
    GPUBoard board;
    int anMoves[8];
    int depth;
    int iPip;
    int cPip;
};

__device__ int gpu_generate_moves(
    const GPUBoard board,
    GPUMove *moves,
    int n0, int n1)
{
    int anRoll[4];
    anRoll[0] = n0;
    anRoll[1] = n1;
    anRoll[2] = anRoll[3] = (n0 == n1) ? n0 : 0;

    int nMoves = 0;
    unsigned int cMaxMoves = 0, cMaxPips = 0;

    /* Hash table for deduplication (simple linear probe) */
    unsigned int seen[GPU_MOVE_BUF_SIZE];
    for (int i = 0; i < GPU_MOVE_BUF_SIZE; i++) seen[i] = 0xFFFFFFFF;

    /* Try both dice orderings for non-doubles */
    int nPass = (n0 == n1) ? 1 : 2;

    for (int pass = 0; pass < nPass; pass++) {
        if (pass == 1) {
            /* Swap dice */
            int tmp = anRoll[0]; anRoll[0] = anRoll[1]; anRoll[1] = tmp;
        }

        /* Use iterative DFS with explicit stack */
        MoveGenState stack[64];  /* enough for branching at each depth */
        int sp = 0;

        /* Push initial state */
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 25; j++)
                stack[0].board[i][j] = board[i][j];
        for (int i = 0; i < 8; i++) stack[0].anMoves[i] = -1;
        stack[0].depth = 0;
        stack[0].iPip = 23;
        stack[0].cPip = 0;
        sp = 1;

        while (sp > 0 && nMoves < GPU_MOVE_BUF_SIZE) {
            sp--;
            MoveGenState &cur = stack[sp];

            if (cur.depth > 3 || !anRoll[cur.depth]) {
                /* Leaf: save this move if it's maximal */
                if (cur.depth > 0) {
                    if (cur.depth < (int)cMaxMoves || cur.cPip < (int)cMaxPips) continue;
                    if (cur.depth > (int)cMaxMoves || cur.cPip > (int)cMaxPips) {
                        nMoves = 0; cMaxMoves = cur.depth; cMaxPips = cur.cPip;
                    }

                    /* Dedup by position hash */
                    unsigned int h = gpu_position_hash(cur.board);
                    int slot = h % GPU_MOVE_BUF_SIZE;
                    int dup = 0;
                    for (int probe = 0; probe < 8; probe++) {
                        int idx = (slot + probe) % GPU_MOVE_BUF_SIZE;
                        if (seen[idx] == h) { dup = 1; break; }
                        if (seen[idx] == 0xFFFFFFFF) { seen[idx] = h; break; }
                    }
                    if (dup) continue;

                    if (nMoves < GPU_MOVE_BUF_SIZE) {
                        for (int i = 0; i < 8; i++)
                            moves[nMoves].anMove[i] = cur.anMoves[i];
                        moves[nMoves].cMoves = cur.depth;
                        moves[nMoves].cPips = cur.cPip;
                        moves[nMoves].rScore = 0.0f;
                        nMoves++;
                    }
                }
                continue;
            }

            int fUsed = 0;

            /* On bar */
            if (cur.board[1][24]) {
                if (cur.board[0][anRoll[cur.depth] - 1] < 2) {
                    if (sp < 64) {
                        MoveGenState &next = stack[sp];
                        for (int i = 0; i < 2; i++)
                            for (int j = 0; j < 25; j++)
                                next.board[i][j] = cur.board[i][j];
                        for (int i = 0; i < 8; i++)
                            next.anMoves[i] = cur.anMoves[i];

                        next.anMoves[cur.depth * 2] = 24;
                        next.anMoves[cur.depth * 2 + 1] = 24 - anRoll[cur.depth];
                        gpu_apply_sub_move(next.board, 24, anRoll[cur.depth]);

                        next.depth = cur.depth + 1;
                        next.iPip = 23;
                        next.cPip = cur.cPip + anRoll[cur.depth];
                        sp++;
                    }
                }
                /* If on bar, can only enter */
                if (!fUsed && cur.depth == 0) {
                    /* No legal move from bar - record empty */
                }
                continue;
            }

            /* Not on bar */
            for (int i = cur.iPip; i >= 0 && sp < 64 && nMoves < GPU_MOVE_BUF_SIZE; i--) {
                if (cur.board[1][i] && gpu_legal_move(cur.board, i, anRoll[cur.depth])) {
                    MoveGenState &next = stack[sp];
                    for (int ii = 0; ii < 2; ii++)
                        for (int jj = 0; jj < 25; jj++)
                            next.board[ii][jj] = cur.board[ii][jj];
                    for (int ii = 0; ii < 8; ii++)
                        next.anMoves[ii] = cur.anMoves[ii];

                    next.anMoves[cur.depth * 2] = i;
                    next.anMoves[cur.depth * 2 + 1] = i - anRoll[cur.depth];
                    gpu_apply_sub_move(next.board, i, anRoll[cur.depth]);

                    next.depth = cur.depth + 1;
                    next.iPip = (anRoll[0] == anRoll[1]) ? i : 23;
                    next.cPip = cur.cPip + anRoll[cur.depth];
                    sp++;
                    fUsed = 1;
                }
            }

            if (!fUsed && cur.depth > 0) {
                /* Can't use more dice - save current state as a leaf */
                if (cur.depth >= (int)cMaxMoves && cur.cPip >= (int)cMaxPips) {
                    if (cur.depth > (int)cMaxMoves || cur.cPip > (int)cMaxPips) {
                        nMoves = 0; cMaxMoves = cur.depth; cMaxPips = cur.cPip;
                    }
                    unsigned int h = gpu_position_hash(cur.board);
                    int slot = h % GPU_MOVE_BUF_SIZE;
                    int dup = 0;
                    for (int probe = 0; probe < 8; probe++) {
                        int idx = (slot + probe) % GPU_MOVE_BUF_SIZE;
                        if (seen[idx] == h) { dup = 1; break; }
                        if (seen[idx] == 0xFFFFFFFF) { seen[idx] = h; break; }
                    }
                    if (!dup && nMoves < GPU_MOVE_BUF_SIZE) {
                        for (int ii = 0; ii < 8; ii++)
                            moves[nMoves].anMove[ii] = cur.anMoves[ii];
                        moves[nMoves].cMoves = cur.depth;
                        moves[nMoves].cPips = cur.cPip;
                        moves[nMoves].rScore = 0.0f;
                        nMoves++;
                    }
                }
            }
        }
    }

    return nMoves;
}

/* ======================================================================
 * Swap sides (switch which player is on roll)
 * ====================================================================== */

__device__ void gpu_swap_sides(GPUBoard board) {
    unsigned int temp[25];
    int i;

    /* Mirror and swap: board[0][i] <-> board[1][23-i] for points,
       bar stays as bar but swaps sides */
    for (i = 0; i < 24; i++)
        temp[i] = board[0][i];
    temp[24] = board[0][24];

    for (i = 0; i < 24; i++)
        board[0][i] = board[1][23 - i];
    board[0][24] = board[1][24];

    for (i = 0; i < 24; i++)
        board[1][i] = temp[23 - i];
    board[1][24] = temp[24];
}

/* ======================================================================
 * Find best move
 * ====================================================================== */

__device__ int gpu_find_best_move(
    const GPUNets *nets,
    const GPUBoard board,
    int n0, int n1,
    int bestMove[8])
{
    GPUMove moveBuf[GPU_MOVE_BUF_SIZE];
    int nMoves = gpu_generate_moves(board, moveBuf, n0, n1);

    if (nMoves == 0) {
        for (int i = 0; i < 8; i++) bestMove[i] = -1;
        return 0;
    }

    if (nMoves == 1) {
        for (int i = 0; i < 8; i++) bestMove[i] = moveBuf[0].anMove[i];
        return 1;
    }

    float bestScore = -1e30f;
    int bestIdx = 0;

    for (int m = 0; m < nMoves; m++) {
        /* Apply move to a copy of the board */
        GPUBoard boardCopy;
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 25; j++)
                boardCopy[i][j] = board[i][j];

        gpu_apply_move(boardCopy, moveBuf[m].anMove);

        /* Swap sides to evaluate from opponent's perspective */
        gpu_swap_sides(boardCopy);

        /* Evaluate */
        float arOutput[GPU_NUM_OUTPUTS];
        gpu_evaluate_position(nets, boardCopy, arOutput);

        /* Score from our perspective (negate opponent's equity) */
        /* Opponent's equity = P(win) - P(lose) + gammon bonuses */
        float oppEq = arOutput[GPU_OUTPUT_WIN]
                     - (1.0f - arOutput[GPU_OUTPUT_WIN])
                     + arOutput[GPU_OUTPUT_WINGAMMON]
                     + arOutput[GPU_OUTPUT_WINBACKGAMMON]
                     - arOutput[GPU_OUTPUT_LOSEGAMMON]
                     - arOutput[GPU_OUTPUT_LOSEBACKGAMMON];
        float score = -oppEq;

        if (score > bestScore) {
            bestScore = score;
            bestIdx = m;
        }
    }

    for (int i = 0; i < 8; i++)
        bestMove[i] = moveBuf[bestIdx].anMove[i];

    return nMoves;
}

/* ======================================================================
 * Game simulation kernel
 * ====================================================================== */

/* Standard backgammon starting position */
__device__ static void gpu_init_board(GPUBoard board) {
    for (int i = 0; i < 2; i++)
        for (int j = 0; j < 25; j++)
            board[i][j] = 0;

    /* Standard starting position for each player:
     * 2 on point 23 (24-point), 5 on point 12 (13-point),
     * 3 on point 7 (8-point), 5 on point 5 (6-point)
     * Note: point numbering is from the player's perspective */
    board[0][23] = 2; board[0][12] = 5; board[0][7] = 3; board[0][5] = 5;
    board[1][23] = 2; board[1][12] = 5; board[1][7] = 3; board[1][5] = 5;
}

__global__ void kernel_play_games(
    const GPUNets *nets,
    GPUGameResult *results,
    GPUGameConfig config)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if ((unsigned int)tid >= config.nGames)
        return;

    /* Initialize RNG */
    curandState rng;
    curand_init(config.seed, (unsigned long long)tid, 0, &rng);

    /* Initialize board */
    GPUBoard board;
    gpu_init_board(board);

    unsigned int nTurns = 0;
    int currentPlayer = 0;  /* Track which original player is on roll */
    int gameOver = 0;

    /* Opening roll: both players roll, higher goes first */
    {
        int d0, d1;
        do {
            d0 = (curand(&rng) % 6) + 1;
            d1 = (curand(&rng) % 6) + 1;
        } while (d0 == d1);

        if (d1 > d0) {
            /* Player 1 goes first */
            gpu_swap_sides(board);
            currentPlayer = 1;
            int tmp = d0; d0 = d1; d1 = tmp;
        }

        /* Play opening move */
        int bestMove[8];
        gpu_find_best_move(nets, board, d0, d1, bestMove);
        gpu_apply_move(board, bestMove);
        nTurns++;

        if (gpu_classify_position(board) == GPU_CLASS_OVER)
            gameOver = 1;
    }

    /* Main game loop */
    while (!gameOver && nTurns < config.maxTurns) {
        gpu_swap_sides(board);
        currentPlayer = 1 - currentPlayer;

        int d0 = (curand(&rng) % 6) + 1;
        int d1 = (curand(&rng) % 6) + 1;

        int bestMove[8];
        gpu_find_best_move(nets, board, d0, d1, bestMove);
        gpu_apply_move(board, bestMove);
        nTurns++;

        if (gpu_classify_position(board) == GPU_CLASS_OVER)
            gameOver = 1;
    }

    /* Determine result */
    GPUGameResult result;
    result.nTurns = nTurns;

    /* Check who won: player 1 (on roll) has no pieces = they won */
    int p1pieces = 0, p0pieces = 0;
    for (int i = 0; i < 25; i++) {
        p1pieces += board[1][i];
        p0pieces += board[0][i];
    }

    int winner, winType;
    if (p1pieces == 0) {
        /* Current player (player 1 in board repr) won */
        winner = currentPlayer;
        /* Check for gammon/backgammon */
        if (p0pieces == 15) {
            int hasBG = 0;
            for (int i = 18; i < 25; i++)
                if (board[0][i]) { hasBG = 1; break; }
            winType = hasBG ? 2 : 1;
        } else {
            winType = 0;
        }
    } else if (p0pieces == 0) {
        /* Opponent won */
        winner = 1 - currentPlayer;
        if (p1pieces == 15) {
            int hasBG = 0;
            for (int i = 18; i < 25; i++)
                if (board[1][i]) { hasBG = 1; break; }
            winType = hasBG ? 2 : 1;
        } else {
            winType = 0;
        }
    } else {
        /* Game didn't finish (maxTurns reached) */
        winner = 0;
        winType = 0;
    }

    result.winner = winner;
    result.winType = winType;
    int points = (winType == 2) ? 3 : (winType == 1) ? 2 : 1;
    result.finalScore[winner] = points;
    result.finalScore[1 - winner] = 0;

    results[tid] = result;
}

/* ======================================================================
 * Batch evaluation kernels
 * ====================================================================== */

__global__ void kernel_evaluate_positions(
    const GPUNets *nets,
    const GPUBoard *boards,
    float *outputs,
    int nPositions)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= nPositions) return;

    gpu_evaluate_position(nets, boards[tid], outputs + tid * GPU_NUM_OUTPUTS);
}

__global__ void kernel_find_best_moves(
    const GPUNets *nets,
    const GPUBoard *boards,
    const int *dice,
    GPUAnalysisResult *results,
    int nPositions)
{
    int tid = blockIdx.x * blockDim.x + threadIdx.x;
    if (tid >= nPositions) return;

    float arOutput[GPU_NUM_OUTPUTS];
    gpu_evaluate_position(nets, boards[tid], arOutput);

    for (int i = 0; i < GPU_NUM_OUTPUTS; i++)
        results[tid].arOutput[i] = arOutput[i];

    results[tid].posClass = (int)gpu_classify_position(boards[tid]);

    int bestMove[8];
    gpu_find_best_move(nets, boards[tid], dice[tid*2], dice[tid*2+1], bestMove);
    for (int i = 0; i < 8; i++)
        results[tid].bestMove[i] = bestMove[i];

    /* Compute equity */
    results[tid].bestMoveEq = arOutput[GPU_OUTPUT_WIN]
                             - (1.0f - arOutput[GPU_OUTPUT_WIN])
                             + arOutput[GPU_OUTPUT_WINGAMMON]
                             + arOutput[GPU_OUTPUT_WINBACKGAMMON]
                             - arOutput[GPU_OUTPUT_LOSEGAMMON]
                             - arOutput[GPU_OUTPUT_LOSEBACKGAMMON];
}
