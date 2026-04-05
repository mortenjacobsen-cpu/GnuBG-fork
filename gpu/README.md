# gnubg GPU Engine

CUDA port of the GNU Backgammon evaluation engine for massively parallel game
play and position analysis.

## Architecture

```
gpu_main.c          CLI driver (play, bench, eval, info commands)
    |
gnubg_gpu_host.h/cu Host-side API: weight loading, kernel launch, memory management
    |
gnubg_gpu.cu        CUDA kernels: NN evaluation, move generation, game simulation
    |
gnubg_gpu.cuh       Shared header: data structures, constants, device function declarations
```

### Design

Each CUDA thread runs one complete backgammon game independently:

- **No inter-thread communication** during gameplay
- **No shared memory** needed between games (embarrassingly parallel)
- **No evaluation cache** (each game follows its own trajectory; cache hit rate would be negligible)
- Neural network weights in **GPU global memory** (L2 cached; too large for constant memory)
- Board state and scratch arrays in **thread-local memory** (register + L1 cache)
- RNG via **curand** per-thread state

### Neural Networks

Uses the same 3 neural networks as CPU gnubg:

| Network | Inputs | Purpose |
|---------|--------|---------|
| nnContact | 250 | Contact positions (checkers interacting) |
| nnRace | 214 | Race positions (no contact) |
| nnCrashed | 250 | Crashed positions (few checkers, contact) |

Each is a 2-layer feedforward net producing 5 outputs:
P(win), P(win gammon), P(win backgammon), P(lose gammon), P(lose backgammon)

## Building

### Prerequisites

- NVIDIA CUDA Toolkit >= 10.0
- GPU with compute capability >= 3.5 (Kepler or newer)
- gnubg.wd weight file (from a gnubg installation)

### Build

```bash
cd gpu/
make GPU_ARCH=sm_70    # Adjust for your GPU architecture
```

Common GPU architectures:
- `sm_50` - Maxwell (GTX 900 series)
- `sm_60` - Pascal (GTX 1000 series)
- `sm_70` - Volta (V100)
- `sm_75` - Turing (RTX 2000 series)
- `sm_80` - Ampere (RTX 3000, A100)
- `sm_86` - Ampere (RTX 3000 laptop)
- `sm_89` - Ada Lovelace (RTX 4000 series)
- `sm_90` - Hopper (H100)

### Usage

```bash
# Show GPU info
./gnubg-gpu info

# Play 10,000 games in parallel
./gnubg-gpu play -n 10000 -w /path/to/gnubg.wd

# Play with verbose output
./gnubg-gpu play -n 1000 -w /path/to/gnubg.wd -v

# Benchmark at various scales
./gnubg-gpu bench -n 50000 -w /path/to/gnubg.wd

# Specific GPU and seed
./gnubg-gpu play -n 10000 -w gnubg.wd -d 0 -s 42
```

### Finding gnubg.wd

The weight file is typically at:
- Linux: `/usr/share/gnubg/gnubg.wd` or `~/.gnubg/gnubg.wd`
- macOS: `/usr/local/share/gnubg/gnubg.wd`
- Or in the gnubg source tree after building

## Performance Expectations

On a modern GPU (RTX 3090 / A100 class):
- **1,000 games**: ~10ms (100K games/sec)
- **10,000 games**: ~50ms (200K games/sec)
- **100,000 games**: ~300ms (300K games/sec)

Actual performance depends on average game length (~50-80 turns) and position
complexity (contact positions are more expensive than race positions).

## Limitations

- **0-ply evaluation only**: Each position is evaluated directly by the neural
  net without lookahead search. This is equivalent to gnubg's "Expert" level.
  Multi-ply search on GPU is a future enhancement.
- **No bearoff databases**: Late-game bearoff positions use the race neural
  net instead of exact databases. This slightly affects endgame accuracy.
- **Simplified contact features**: Some complex tactical features (detailed hit
  probability analysis) use simplified approximations on GPU.
- **No cube decisions**: Games are played without the doubling cube.
- **Standard backgammon only**: No hypergammon or nackgammon variants.

## License

GPL-3.0-or-later (same as gnubg)
