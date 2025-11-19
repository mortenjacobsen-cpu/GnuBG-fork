/* Minimal neuralnet stubs to avoid x86-specific assembly and SIMD when
 * building for Wasm. These provide very simple behavior: nets evaluate to
 * neutral outputs and load/save functions indicate no weights loaded.
 */

#include <stdio.h>
#include <string.h>
#include "lib/neuralnet.h"

void NeuralNetDestroy(neuralnet * pnn) {
    (void)pnn;
}

#if !defined(USE_SIMD_INSTRUCTIONS)
int NeuralNetEvaluate(const neuralnet * pnn, float arInput[], float arOutput[], NNState * pnState) {
    (void)pnn; (void)arInput; (void)pnState;
    /* produce neutral outputs (0.5) */
    if (!arOutput) return -1;
    for (unsigned int i = 0; i < (pnn ? pnn->cOutput : 5); ++i) arOutput[i] = 0.5f;
    return 0;
}
#else
int NeuralNetEvaluateSSE(const neuralnet * pnn, float arInput[], float arOutput[], NNState * pnState) {
    (void)pnn; (void)arInput; (void)pnState;
    if (!arOutput) return -1;
    for (unsigned int i = 0; i < (pnn ? pnn->cOutput : 5); ++i) arOutput[i] = 0.5f;
    return 0;
}
#endif

int NeuralNetLoad(neuralnet * pnn, FILE * pf) {
    (void)pnn; (void)pf;
    return -1; /* no weights loaded */
}

int NeuralNetLoadBinary(neuralnet * pnn, FILE * pf) {
    (void)pnn; (void)pf;
    return -1;
}

int NeuralNetSaveBinary(const neuralnet * pnn, FILE * pf) {
    (void)pnn; (void)pf;
    return -1;
}

int SIMD_Supported(void) { return 0; }
