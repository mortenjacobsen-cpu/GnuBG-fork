## 1. Template and Framework Selection

The project will be bootstrapped using the official **Vercel Next.js 15 starter template with TypeScript and Tailwind CSS**. This template will be initialized via Vercel's dashboard to ensure seamless GitHub integration and automated CI/CD from day one.

*   **Rationale:** We are specifying **Next.js 15** as it is the current stable, Long-Term Support (LTS) version. This provides the longest possible support window for security and maintenance updates, ensuring the project starts on a modern, future-proof foundation and avoids immediate technical debt. The template is optimized for the intended deployment platform (Vercel) and includes first-class support for our core technologies.

### Progressive Web App (PWA) Capability

A core architectural requirement is that the application must be a **Progressive Web App**, enabling full offline functionality.

*   **Implementation:** We will use the `next-pwa` library to manage the generation and configuration of the Service Worker and Web App Manifest.
*   **User Benefit:** This will allow users to load the application instantly, even without an internet connection, and use all features that do not require a network request (e.g., uploading and analyzing a local `.xg` file). This is a critical feature for users at tournaments or in areas with poor connectivity.

### Change Log

| Date | Version | Description | Author |
| :--- | :--- | :--- | :--- |
| 2025-10-10 | 1.0 | Initial Architecture Draft | Winston |
| 2025-10-10 | 1.1 | Updated Next.js version to 15 for long-term support. | Winston |
| 2025-10-24 | 2.0 | Completed all sections and incorporated review feedback. | Winston |

```
### Development Strategy: PoC to MVP

This architecture document describes the complete Minimum Viable Product (MVP). However, development will follow the phased approach outlined in the PRD to mitigate risk:

1.  **Proof of Concept (PoC) Phase:** The initial focus will be on implementing and rigorously testing the core logic layer (`src/lib/parser/`) and foundational UI components (`src/components/board/`). This phase validates the most complex technical challenges before investing in full UI polish.
2.  **MVP Integration Phase:** Once the PoC is validated, development will proceed to integrate this functional core into the polished, responsive UI defined in this document, completing all features required for the public launch.

---

## 2. Frontend Tech Stack

This table outlines the specific libraries and tools that will be used to build the application. Exact versions will be pinned in `package.json` during project initialization.

| Category | Technology | Purpose & Rationale |
| :--- | :--- | :--- |
| **Framework** | Next.js 15 | The core application framework. Chosen for its performance, Vercel optimization, and future-proof architecture. |
| **Language** | TypeScript | Provides static typing to improve code quality and maintainability, which is critical for agent-based development. |
| **Styling** | Tailwind CSS | A utility-first CSS framework that enables rapid development of custom, responsive designs like our "cool retro" theme. |
| **State Management**| Zustand | A lightweight, simple, and powerful state management library. Chosen over Context for its minimal boilerplate and better performance. |
| **PWA** | `next-pwa` | The standard library for adding Progressive Web App capabilities (offline support) to a Next.js application. |
| **Unit/Integration Testing** | Vitest & React Testing Library| A modern, fast test runner (Vitest) paired with the standard library for testing React components in a user-centric way. |
| **E2E Testing** | Playwright | A modern end-to-end testing framework. Chosen for its speed, reliability, and excellent cross-browser support. |
| **Linting** | ESLint & Prettier | The industry-standard combination for enforcing consistent code style and catching common errors. |
| **UI Components** | Shadcn UI | A collection of reusable components built on Radix UI, providing accessible primitives with full styling control. |
| **Icons** | Lucide Icons | A clean, consistent, and highly customizable SVG icon library that works well with Tailwind CSS. |

---

## 3. Project Structure

The project will follow the standard Next.js 15 App Router structure. The `src` directory will be used to keep application code separate from configuration files.

```plaintext
/
├── .github/              # CI/CD workflows (e.g., Vercel deployment)
├── .vscode/              # VS Code editor settings
├── public/               # Static assets (images, fonts, etc.)
├── src/
│   ├── app/              # Next.js App Router pages and layouts
│   │   ├── (main)/         # Main application route group
│   │   │   ├── layout.tsx  # Main layout with navigation
│   │   │   └── page.tsx    # Root component that renders Upload/Viewer/Summary
│   │   ├── layout.tsx      # Root layout (fonts, metadata)
│   │   └── globals.css   # Global styles and Tailwind directives
│   ├── components/
│   │   ├── board/        # The core Backgammon Board component and its children
│   │   ├── logs/         # Components for the Game Log and Move Log
│   │   ├── navigation/   # The persistent navigation bar/header
│   │   ├── screens/      # The three main screen components
│   │   │   ├── UploadScreen.tsx
│   │   │   ├── ViewerScreen.tsx
│   │   │   └── SummaryScreen.tsx
│   │   └── ui/           # Components from Shadcn UI (e.g., button, dialog)
│   ├── lib/
│   │   ├── parser/       # Core logic for parsing .xg and XGID files
│   │   └── state-machine/# Logic for the backgammon turn cycle
│   ├── stores/
│   │   └── appStore.ts   # Zustand store for global UI state
│   ├── styles/
│   │   └── retro-theme.css # CSS variables for our custom theme
│   └── types/
│       └── match.ts      # TypeScript type definitions for match data, etc.
├── tests/
│   ├── unit/
│   │   ├── lib/
│   │   └── stores/
│   ├── components/
│   │   ├── ui/
│   │   └── screens/
│   ├── e2e/
│   │   └── specs/
│   └── fixtures/
├── .eslintrc.json        # ESLint config
├── next.config.mjs       # Next.js config (with PWA)
├── package.json          # Dependencies
├── playwright.config.ts  # Playwright E2E test config
├── tailwind.config.ts    # Tailwind CSS config
├── tsconfig.json         # TypeScript config
└── vitest.config.ts      # Vitest unit/integration test config
```

---

## 4. Component Standards

All React components will be created as function components using TypeScript, adhering to the patterns below.

### Component Template (`.tsx`)

This template should be used for all new components. It includes props typing, proper component structure, and follows React best practices.

```typescript
// src/components/example/ExampleComponent.tsx

import React from 'react';
import { cn } from '@/lib/utils';

// 1. Define Props with TypeScript interface and JSDoc comments
interface ExampleComponentProps {
  /** The main text or title to display within the component. */
  title: string;
}

// 2. Type props directly on the function signature
const ExampleComponent = ({ title }: ExampleComponentProps) => {
  // 3. Return JSX using semantic HTML and the 'cn' utility for classes
  return (
    <div
      className={cn(
        'p-4 rounded-lg', // Base styles
        'min-h-touch min-w-touch', // Mobile-friendly tap target
        'transition-transform active:scale-95' // Mobile press feedback
      )}
    >
      <span className="text-lg font-bold">{title}</span>
    </div>
  );
};

// 4. Export the component as the default export
export default ExampleComponent;
`````

### Naming Conventions

*   **Component Files:** `PascalCase.tsx` (e.g., `MatchViewer.tsx`).
*   **Component Name:** Must match the filename (`PascalCase`).
*   **Props Interface:** `{ComponentName}Props` (e.g., `MatchViewerProps`).
*   **Folders:** `kebab-case` for multi-word folders (e.g., `game-log/`).
*   **Screen Components:** Use the `Screen` suffix for clarity (e.g., `UploadScreen.tsx`).

---

## 5. State Management

Global UI state will be managed using a single Zustand store. This store will handle application-wide states, such as the active screen and whether a match is loaded. Component-level state should still use React's built-in `useState` or `useReducer` where appropriate.

### Store Structure (`appStore.ts`)

The global store will be defined in `src/stores/appStore.ts`. The following template is mandatory and includes middleware for **development debugging (`devtools`)** and a placeholder for **PWA persistence (`persist`)**.

```typescript
// src/stores/appStore.ts

import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';
import type { MatchData } from '@/types/match'; 

// 1. Define the interface for the store's state
interface AppState {
  activeScreen: 'upload' | 'viewer' | 'summary';
  isMatchLoaded: boolean;
  matchData: MatchData | null;
}

// 2. Define the interface for the store's actions
interface AppActions {
  setActiveScreen: (screen: AppState['activeScreen']) => void;
  loadNewMatch: (data: MatchData) => void;
  returnToUpload: () => void;
}

// 3. Define the complete store type for reusability
type AppStore = AppState & AppActions;

// 4. Create the Zustand store with middleware
export const useAppStore = create<AppStore>()(
  // The devtools middleware enhances debugging in development
  devtools(
    // The persist middleware can be enabled for PWA offline state saving
    // persist(
      (set) => ({
        // 5. Initial State
        activeScreen: 'upload',
        isMatchLoaded: false,
		matchData: null,

        // 6. Actions to update the state
        setActiveScreen: (screen) => set({ activeScreen: screen }),
        
        // 7. Composed actions for common workflows
	    loadNewMatch: (data) => 
		  set({
		    isMatchLoaded: true,
		    activeScreen: 'viewer',
		    matchData: data,
		  }),
	  
	    returnToUpload: () =>
		  set({
		    isMatchLoaded: false,
		    activeScreen: 'upload',
		    matchData: null, 
		  }),
	  }),
      {
        name: 'backgammon-toolbox-storage', // Name for the persisted storage
      }
    // )
  )
);
```

### Usage Pattern in a Component

To use the store, import the `useAppStore` hook. **For performance, components should use selectors to subscribe only to the specific state slices they need.** This prevents unnecessary re-renders.

```typescript
// Example of optimized usage in a component
import { useAppStore } from '@/stores/appStore';

const NavigationComponent = () => {
  // Good: Select only the state you need. This component will only re-render
  // when `isMatchLoaded` or `activeScreen` changes.
  const isMatchLoaded = useAppStore((state) => state.isMatchLoaded);
  const activeScreen = useAppStore((state) => state.activeScreen);
  
  // Get the action function. Actions don't cause re-renders.
  const setActiveScreen = useAppStore((state) => state.setActiveScreen);

  return (
    <nav>
      {/* ... */}
      <button
        onClick={() => setActiveScreen('viewer')}
        disabled={!isMatchLoaded}
      >
        Viewer
      </button>
    </nav>
  );
};
```

---

## 6. API Integration (Parser & Logic Layer)

### Overview

There is no external network API for the MVP. However, we architect the application with a **clean separation between the UI Layer (React components) and the Logic Layer (parsing and game state logic)**. This internal API contract is the most critical architectural decision for long-term maintainability.

---

### Architectural Constraints

#### File Format Complexity

The `.xg` file format presents significant parsing challenges:

1.  **Multi-Layer Structure**: `.xg` files use the RichGameFormat wrapper (DirectX format) containing a ZLIB-compressed archive
2.  **Binary Format**: Core data is stored as fixed-size binary records (2560 bytes each) with strict memory alignment rules
3.  **Little-Endian Encoding**: All multi-byte values use little-endian byte order
4.  **Multiple Data Streams**: The compressed archive contains 4 files:
    *   `temp.xg` - Full game data (TSaveRec records)
    *   `temp.xgi` - Quick access header/footer
    *   `temp.xgr` - Rollout analysis data
    *   `temp.xgc` - Comments (RTF format)

#### Required Dependencies

*   **pako.js**: Client-side ZLIB decompression library (added to Tech Stack)
*   **DataView API**: For precise binary data parsing with byte-level control

#### Parsing Strategy

The parser must:
1.  Strip the RichGameFormat header (validate magic number `RGMH`)
2.  Decompress the ZLIB payload using pako.js
3.  Parse binary records from the decompressed `temp.xg` using `DataView`
4.  Transform the flat record sequence into a hierarchical `MatchData` structure

**Critical Principle**: All parsing complexity is absorbed in the Logic Layer. The UI receives a clean, hierarchical object and never deals with binary formats or flat record sequences.

---

### Data Contract: The MatchData Interface

This is the **unshakable contract** between the parser and all UI components. Any parser implementation (current or future) must output data in this exact shape.

```typescript
// src/types/match.ts

/**
 * Board position from the player-on-roll's perspective.
 * Index 0: opponent's bar
 * Index 1-24: points (1 = player's 1-point, 24 = opponent's 1-point)  
 * Index 25: player's bar
 * 
 * Values: 0 = empty, positive = player's checkers, negative = opponent's checkers
 */
export type BoardPosition = number[];  // Length 26, values -15 to +15

/** Game variations supported by XG format */
export type GameVariation = 
  | 'Backgammon'      // 0
  | 'Nackgammon'      // 1
  | 'Hypergammon'     // 2
  | 'Longgammon';     // 3

/** How a game ended */
export type GameTermination = 
  | 'Drop'                // 0
  | 'Single'              // 1
  | 'Gammon'              // 2
  | 'Backgammon'          // 3
  | 'ResignSingle'        // 100
  | 'ResignGammon'        // 101
  | 'ResignBackgammon'    // 102
  | 'Settled';            // 1000+

/** Analysis level (maps to XG's PLAYERLEVEL TABLE) */
export type AnalyzeLevel = number;  // 0-7 for ply, 12=3-ply-red, 100=rollout, 1000+=XGRoller

/** Single move candidate from analysis */
export interface MoveCandidate {
  notation: string;           // Human-readable move (e.g., "8/5 6/5")
  position: BoardPosition;    // Resulting board position
  equity: number;             // Normalized equity
  winProbs: {                 // Win probabilities breakdown
    loseBg: number;
    loseG: number;
    loseS: number;
    winS: number;
    winG: number;
    winBg: number;
  };
  rank: number;               // 1-based rank (1 = best move)
  analyzeLevel?: AnalyzeLevel;
}

/** Checker play analysis data */
export interface MoveAnalysis {
  candidates: MoveCandidate[];  // Up to 32 candidates
  playedMoveIndex: number;      // Index into candidates of actual move
  error?: number;               // Error in equity (-1000 = not analyzed)
  luck?: number;                // Luck factor of the roll
  analyzeLevel?: AnalyzeLevel;
  rolloutIndex?: number;        // Reference to rollout data (future use)
}

/** Cube decision analysis */
export interface CubeAnalysis {
  noDoubleEquity: number;       // Equity if no double
  doubleTakeEquity: number;     // Equity if double/take
  doubleDropEquity: number;     // Equity if double/drop (always -1)
  shouldDouble: boolean;        // Correct cube decision
  shouldTake: boolean;          // Correct take/drop decision (if doubled)
  cubeError?: number;            // Error in doubling decision (-1000 = not analyzed)
  takeError?: number;            // Error in take/drop decision
  analyzeLevel?: AnalyzeLevel;
}

/** A single event in a game: either a checker play or cube action */
export type GameEvent = 
  | {
      type: 'move';
      player: 'player1' | 'player2';
      dice: [number, number];
      moveNotation: string;         // e.g., "24/23 13/11"
      positionBefore: BoardPosition;
      positionAfter: BoardPosition;
      cubeValue: number;            // Current cube value (1, 2, 4, 8, ...)
      analysis?: MoveAnalysis;      // May be absent if not analyzed
      flagged?: boolean;            // User flagged for review
      comment?: string;             // User comment (from temp.xgc)
      edited?: boolean;             // Position was manually edited
    }
  | {
      type: 'cube';
      player: 'player1' | 'player2';
      action: 'double' | 'take' | 'drop' | 'beaver' | 'raccoon';
      position: BoardPosition;      // Position when action occurred
      cubeValueBefore: number;
      cubeValueAfter: number;
      analysis?: CubeAnalysis;      // May be absent if not analyzed
      flagged?: boolean;
      comment?: string;
      edited?: boolean;
    };

/** A single game within a match */
export interface Game {
  gameNumber: number;               // 1-based game number
  initialScore: { 
    player1: number; 
    player2: number; 
  };
  crawfordGame: boolean;            // Is this the Crawford game?
  autoDoubles: number;              // # of automatic doubles (affects displayed cube)
  events: GameEvent[];              // Chronological sequence of moves and cube actions
  result: {
    winner: 'player1' | 'player2';
    pointsWon: number;
    termination: GameTermination;
    finalScore: { 
      player1: number; 
      player2: number; 
    };
    resignError?: number;           // Error in resignation decision (if applicable)
    acceptError?: number;           // Error in accepting resignation
  };
  headerComment?: string;           // Comment at game start
  footerComment?: string;           // Comment at game end
}

/** Complete match data - the definitive contract */
export interface MatchData {
  header: {
    // Player information
    player1: string;
    player2: string;
    player1Elo?: number;
    player2Elo?: number;
    
    // Match configuration
    matchLength: number;            // 99999 = unlimited (money game)
    variation: GameVariation;
    
    // Rules in effect
    crawford: boolean;
    jacoby: boolean;
    beaver: boolean;
    autoDouble: boolean;
    cubeLimit?: number;             // Maximum cube value (optional)
    
    // Match metadata
    event?: string;                 // Tournament/event name
    location?: string;
    round?: string;
    date: Date;
    
    // Additional context
    siteId?: number;                // Online site (see XG SITE ID table)
    gameMode?: number;              // Game mode (see XG GAMEMODE table)
    transcribed?: boolean;          // Was this transcribed from physical play?
    transcriber?: string;
    
    // Money game details
    isMoneyGame?: boolean;
    stake?: {
      win: number;
      lose: number;
      currency: number;             // Currency code (see XG CURRENCY table)
    };
    
    // Internal
    fileVersion: number;            // XG file version (for compatibility checks)
    gameId: number;                 // Internal game identifier
  };
  
  games: Game[];                    // Chronological sequence of all games
  
  footer: {
    finalScore: { 
      player1: number; 
      player2: number; 
    };
    winner: 'player1' | 'player2';
    player1EloAfter?: number;       // Final Elo ratings (if tracked)
    player2EloAfter?: number;
    endDate: Date;
  };
  
  // UI state (not from file - managed by viewer)
  currentGameIndex?: number;
  currentEventIndex?: number;
}
```

---

### Parser Error Handling

All parsing operations return a discriminated union for robust error handling:

```typescript
// src/types/parser.ts

export type ParserErrorCode = 
  // File-level errors
  | 'INVALID_FILE_TYPE'
  | 'FILE_TOO_LARGE'
  | 'FILE_UNREADABLE'
  
  // RichGameFormat header errors
  | 'INVALID_MAGIC_NUMBER'        // First 4 bytes are not 'RGMH'
  | 'CORRUPTED_HEADER'            // Header structure is damaged
  
  // ZLIB decompression errors
  | 'DECOMPRESSION_FAILED'        // pako.js could not decompress
  | 'MISSING_XG_FILE'             // temp.xg not found in archive
  
  // Binary parsing errors
  | 'INVALID_FILE_VERSION'        // Version > 40 (unsupported)
  | 'INVALID_MAGIC_NUMBER_XG'     // 'DMLI' magic not found in match header
  | 'CORRUPTED_RECORD'            // Binary record structure invalid
  | 'UNEXPECTED_EOF'              // File truncated
  
  // Logical validation errors
  | 'MISSING_MATCH_HEADER'        // No tsHeaderMatch record found
  | 'MISSING_MATCH_FOOTER'        // No tsFooterMatch record found
  | 'INVALID_GAME_SEQUENCE'       // Games out of order or incomplete
  | 'INVALID_POSITION'            // Illegal checker count or placement
  
  // Generic fallback
  | 'PARSE_FAILED';               // Unknown parsing error

export interface ParserError {
  code: ParserErrorCode;
  message: string;                // Developer-facing message
  userMessage?: string;           // User-friendly explanation
  details?: unknown;              // Debug context (not shown to users)
}

export type ParseResult = 
  | { success: true; data: MatchData }
  | { success: false; error: ParserError };
```

---

### Parser Service (Facade Pattern)

The UI interacts exclusively through this service interface. Internal parsing complexity is completely hidden.

```typescript
// src/lib/parser/parserService.ts

import { MatchData, ParseResult } from '@/types';

/**
 * Parser service - the facade for all file parsing operations.
 * UI components use this service, never calling low-level parsing functions directly.
 */
export const ParserService = {
  /**
   * Parses a complete .xg match file.
   * 
   * @param file - The .xg file from a file input element
   * @returns Promise resolving to success with MatchData or failure with ParserError
   */
  parseXgFile: async (file: File): Promise<ParseResult> => {
    try {
      // 1. Validate file type and size
      if (!file.name.toLowerCase().endsWith('.xg')) {
        return {
          success: false,
          error: {
            code: 'INVALID_FILE_TYPE',
            message: 'File must have .xg extension',
            userMessage: 'Please select a valid .xg match file.',
          },
        };
      }

      if (file.size > 10 * 1024 * 1024) {  // 10MB limit
        return {
          success: false,
          error: {
            code: 'FILE_TOO_LARGE',
            message: 'File exceeds 10MB limit',
            userMessage: 'This file is too large. XG files are typically under 1MB.',
          },
        };
      }

      // 2. Read file as ArrayBuffer
      const arrayBuffer = await file.arrayBuffer();

      // 3. Internal parsing pipeline (implementation details hidden):
      // const matchData = await _parseXgBinary(arrayBuffer);

      // Placeholder for now
      const matchData: MatchData = { /* ... placeholder data ... */ };

      return { success: true, data: matchData };
    } catch (e) {
      return {
        success: false,
        error: {
          code: 'PARSE_FAILED',
          message: e instanceof Error ? e.message : 'Unknown parsing error',
          userMessage: 'Unable to parse this file. It may be corrupted or an unsupported version.',
          details: e,
        },
      };
    }
  },

  /**
   * Parses a single XGID string (future implementation).
   */
  parseXgidString: (xgid: string): ParseResult => {
    // Future implementation
    return {
      success: false,
      error: {
        code: 'PARSE_FAILED',
        message: 'XGID parsing not yet implemented',
        userMessage: 'XGID support coming soon.',
      },
    };
  },
};
```

---

### Logic Layer Organization

All non-UI logic resides in `src/lib/`:

```
src/lib/
├── parser/
│   ├── parserService.ts       # Public facade
│   ├── xgBinaryParser.ts      # Binary parsing implementation (private)
│   ├── richGameFormat.ts      # RGMH header handling (private)
│   ├── recordParser.ts        # TSaveRec parsing (private)
│   └── utils/                 # Parsing utilities (private)
├── state-machine/             # Future: game state logic
└── analysis/                  # Future: PR calculations, statistics
```

---

## 7. Styling Guidelines

### Styling Approach

Our styling strategy combines **Tailwind CSS** for utility-first development with centralized theming via **CSS Custom Properties**. This provides rapid development while ensuring our "cool retro" visual identity remains consistent and maintainable.

**Key Principles:**
*   All theme values (colors, fonts, spacing) are defined in `src/styles/retro-theme.css`.
*   Components must use semantic Tailwind classes (`bg-primary`), never hard-coded values (`bg-[#e7a854]`).
*   The architecture is mobile-first, with built-in support for touch targets and safe areas.
*   The HSL color format is used exclusively to enable Tailwind's opacity modifiers (e.g., `bg-primary/50`).

---

### Global Theme Variables (`retro-theme.css`)

This file is the single source of truth for our visual identity. It must be imported in the root layout (`src/app/layout.tsx`) to apply the theme globally.

```css
/* src/styles/retro-theme.css */

@layer base {
  :root {
    /* ===== BASE COLOR PALETTE (HSL values, no hsl() wrapper) ===== */
    --color-board-felt: 180 30% 32%;        /* #3e6868 */
    --color-point-odd: 35 37% 64%;          /* #c1ab85 */
    --color-point-even: 5 49% 54%;          /* #c94e44 */
    --color-accent: 35 73% 62%;             /* #e7a854 */
    --color-success: 120 21% 45%;           /* #5a8a5a */
    --color-error: 5 49% 54%;               /* #c7584a */
    --color-text-neutral: 35 23% 77%;       /* #d1c7b7 */

    /* ===== SEMANTIC THEME VARIABLES ===== */
    --background: var(--color-board-felt);
    --foreground: var(--color-text-neutral);
    
    --primary: var(--color-accent);
    --primary-foreground: var(--color-board-felt);
    
    --card: 45 14% 12%;
    --card-foreground: var(--color-text-neutral);
    
    --destructive: var(--color-error);
    --destructive-foreground: var(--color-text-neutral);
    
    --success: var(--color-success);
    --success-foreground: var(--color-text-neutral);
    
    --border: 45 14% 25%;
    --input: 45 14% 25%;
    --ring: var(--color-accent);

    /* ===== LAYOUT ===== */
    --radius: 0.5rem;
    
    /* Mobile Touch Targets (iOS/Android minimum) */
    --touch-target-min: 44px;
    
    /* Safe Area Insets (for device notches/home indicators) */
    --safe-top: env(safe-area-inset-top);
    --safe-bottom: env(safe-area-inset-bottom);
    --safe-left: env(safe-area-inset-left);
    --safe-right: env(safe-area-inset-right);

    /* ===== TYPOGRAPHY ===== */
    --font-base: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    --font-mono: 'SF Mono', 'Courier New', monospace;
    
    /* Fluid Typography (scales between mobile and desktop) */
    --text-xs: clamp(0.75rem, 0.7rem + 0.25vw, 0.875rem);
    --text-sm: clamp(0.875rem, 0.8rem + 0.375vw, 1rem);
    --text-base: clamp(1rem, 0.9rem + 0.5vw, 1.125rem);
    --text-lg: clamp(1.125rem, 1rem + 0.625vw, 1.25rem);
    --text-xl: clamp(1.25rem, 1.1rem + 0.75vw, 1.5rem);

    /* ===== ANIMATIONS ===== */
    --duration-fast: 150ms;
    --duration-base: 250ms;
    --duration-slow: 350ms;
    
    --ease-out: cubic-bezier(0.0, 0, 0.2, 1);
    --ease-spring: cubic-bezier(0.68, -0.55, 0.265, 1.55);
  }
  
  /* 
    FUTURE: Dark mode support
    Implement by overriding color variables in a .dark class. Example:
    
    .dark {
      --color-board-felt: 180 30% 15%;
      --color-text-neutral: 35 23% 90%;
      --card: 45 14% 8%;
      /* ... etc. ... */
    }
  */
}

@layer base {
  * {
    @apply border-border;
  }
  
  body {
    @apply bg-background text-foreground;
    font-family: var(--font-base);
    font-size: var(--text-base);
    
    /* Prevent font size adjustment on landscape iOS */
    -webkit-text-size-adjust: 100%;
    
    /* Enable smooth font rendering */
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }
  
  /* Respect user motion preferences for accessibility */
  @media (prefers-reduced-motion: reduce) {
    *,
    *::before,
    *::after {
      animation-duration: 0.01ms !important;
      animation-iteration-count: 1 !important;
      transition-duration: 0.01ms !important;
      scroll-behavior: auto !important;
    }
  }
}
```

---

### Tailwind Configuration (`tailwind.config.ts`)

This configuration maps our CSS variables to Tailwind's utility classes, making the theme system available throughout the application.

```typescript
// tailwind.config.ts
import type { Config } from 'tailwindcss';

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Semantic theme colors (with hsl wrapper for opacity support)
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        success: {
          DEFAULT: 'hsl(var(--success))',
          foreground: 'hsl(var(--success-foreground))',
        },
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))',
        },
        
        // Board-specific colors
        'point-odd': 'hsl(var(--color-point-odd))',
        'point-even': 'hsl(var(--color-point-even))',
      },
      
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      
      fontFamily: {
        sans: ['var(--font-base)'],
        mono: ['var(--font-mono)'],
      },
      
      fontSize: {
        xs: 'var(--text-xs)',
        sm: 'var(--text-sm)',
        base: 'var(--text-base)',
        lg: 'var(--text-lg)',
        xl: 'var(--text-xl)',
      },
      
      spacing: {
        'touch': 'var(--touch-target-min)',
        'safe-top': 'var(--safe-top)',
        'safe-bottom': 'var(--safe-bottom)',
        'safe-left': 'var(--safe-left)',
        'safe-right': 'var(--safe-right)',
      },
      
      minHeight: {
        'touch': 'var(--touch-target-min)',
      },
      
      minWidth: {
        'touch': 'var(--touch-target-min)',
      },
      
      transitionDuration: {
        fast: 'var(--duration-fast)',
        base: 'var(--duration-base)',
        slow: 'var(--duration-slow)',
      },
      
      transitionTimingFunction: {
        'ease-out': 'var(--ease-out)',
        'spring': 'var(--ease-spring)',
      },
    },
  },
  plugins: [],
};

export default config;
```

---

### Usage in Components and Mobile-First Best Practices

Developers will use the semantic, theme-aware utilities.

1.  **Always use `min-h-touch` and `min-w-touch` for interactive elements** to ensure they are easily tappable.
2.  **Apply safe area padding to fixed or full-bleed elements** to avoid device notches and home indicators.
3.  **Use fluid typography and semantic colors** as demonstrated in the configuration.
4.  **Test on actual devices** to validate the mobile experience.

```typescript
// ✅ GOOD: Semantic, theme-aware, and mobile-first
const ThemedButton = ({ children }: { children: React.ReactNode }) => {
  return (
    <button className="
      bg-primary text-primary-foreground
      flex items-center justify-center
      min-h-touch px-4 rounded-md
      transition-transform duration-fast active:scale-95
    ">
      {children}
    </button>
  );
};

// Apply safe area padding to a fixed header
const Header = () => {
  return (
    <header className="fixed top-0 left-0 right-0 h-16 bg-card/80 backdrop-blur-sm
                       pl-safe-left pr-safe-right pt-safe-top">
      {/* ... header content ... */}
    </header>
  );
};

// ❌ BAD: Hard-coded colors and sizes
const BadButton = () => {
  return <button className="bg-[#e7a854] h-[36px]">Bad</button>;
};
```

---

## 8. Testing Requirements

### Testing Philosophy

Our testing strategy is guided by the **Testing Trophy** philosophy, which prioritizes tests that provide the most confidence for the least effort. We will have a strong foundation of fast **unit tests** for pure logic, a comprehensive suite of **component tests** to validate our UI's behavior, and a small, focused set of **E2E tests** for critical user journeys.

This approach ensures rapid feedback during development and high confidence in the application's stability.

### Tools & Configuration

*   **Unit & Component Tests:** **Vitest** with **React Testing Library (RTL)**. Configuration in `vitest.config.ts`.
*   **End-to-End Tests:** **Playwright**. Configuration in `playwright.config.ts`.
*   **CI Enforcement:** The CI/CD pipeline will be configured to block pull requests that do not meet the minimum coverage thresholds.

### Test Organization

All tests will reside in the root `tests/` directory, organized by type. This clean separation simplifies configuration and prevents test code from polluting the application source.

```plaintext
/tests/
├── unit/                      # Pure TypeScript/JavaScript logic tests (no React/DOM)
│   ├── lib/
│   │   ├── parser/
│   │   │   ├── parserService.test.ts
│   │   │   └── performance.test.ts
│   │   └── utils/
│   └── stores/
│       └── appStore.test.ts
│
├── components/                # All React component tests (using RTL)
│   ├── ui/
│   │   └── Button.test.tsx
│   └── screens/
│       └── UploadScreen.test.tsx
│
├── e2e/                       # Playwright end-to-end user journey tests
│   └── specs/
│       ├── upload-flow.spec.ts
│       └── viewer-navigation.spec.ts
│
├── fixtures/                  # Test data files
│   ├── valid-match.xg
│   ├── corrupted.xg
│   └── README.md
│
└── utils/                     # Reusable test helpers
    └── testUtils.tsx
```

### Coverage Requirements

*   **`src/lib/` (Logic Layer): Minimum 80% coverage** ✅ **ENFORCED in CI**
    *   Parser functions and error paths must be exhaustively tested.
*   **`src/stores/` (State Management): Minimum 90% coverage** ✅ **ENFORCED in CI**
    *   All actions and state transitions must be verified.
*   **`src/components/` (UI Layer): Target 60% coverage** ⚠️ **MONITORED**
    *   Focus on user interactions and behavior, not implementation details. Snapshot tests are discouraged.

### Parser Service Testing Standards

The `ParserService` is the most critical logic component and requires comprehensive testing using real file fixtures.

**Parser Test Template (Vitest):**

```typescript
// tests/unit/lib/parser/parserService.test.ts

import { describe, it, expect, beforeAll } from 'vitest';
import { ParserService } from '@/lib/parser/parserService';
import { readFileSync } from 'fs';
import { join } from 'path';

describe('ParserService', () => {
  let validXgFile: File;

  beforeAll(() => {
    const validBuffer = readFileSync(join(__dirname, '../../../fixtures/valid-match.xg'));
    validXgFile = new File([validBuffer], 'valid.xg', { type: 'application/octet-stream' });
  });

  it('should successfully parse a valid .xg file', async () => {
    const result = await ParserService.parseXgFile(validXgFile);

    expect(result.success).toBe(true);
    if (result.success) {
      expect(result.data.header.player1).toBe('Expected Player 1'); // Based on fixture
    }
  });

  it('should reject files larger than 10MB', async () => {
    const largeFile = new File([new ArrayBuffer(11 * 1024 * 1024)], 'huge.xg');
    const result = await ParserService.parseXgFile(largeFile);

    expect(result.success).toBe(false);
    if (!result.success) expect(result.error.code).toBe('FILE_TOO_LARGE');
  });
});
```

### Store Testing Standards

Zustand stores must be tested in isolation to verify state transitions.

**Store Test Template (Vitest + RTL):**

```typescript
// tests/unit/stores/appStore.test.ts

import { renderHook, act } from '@testing-library/react';
import { describe, it, expect, beforeEach } from 'vitest';
import { useAppStore } from '@/stores/appStore';

describe('appStore', () => {
  beforeEach(() => {
    // Reset store to initial state before each test
    act(() => {
      useAppStore.setState(useAppStore.getInitialState());
    });
  });

  it('should correctly initialize with default state', () => {
    const { result } = renderHook(() => useAppStore());
    expect(result.current.activeScreen).toBe('upload');
    expect(result.current.isMatchLoaded).toBe(false);
  });

  it('loadNewMatch action should correctly update state', () => {
    const { result } = renderHook(() => useAppStore());
    act(() => result.current.loadNewMatch());
    expect(result.current.isMatchLoaded).toBe(true);
    expect(result.current.activeScreen).toBe('viewer');
  });
});
```

### Component Test Standards

Component tests verify that the UI behaves as expected from a user's perspective.

**Component Test Template (Vitest + RTL):**

```typescript
// tests/components/screens/UploadScreen.test.tsx

import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ParserService } from '@/lib/parser/parserService';
import { useAppStore } from '@/stores/appStore';
import UploadScreen from '@/components/screens/UploadScreen';

vi.mock('@/lib/parser/parserService');

describe('UploadScreen Component', () => {
  it('should navigate to viewer screen after a successful upload', async () => {
    vi.mocked(ParserService.parseXgFile).mockResolvedValue({ success: true, data: {} as any });
    
    render(<UploadScreen />);
    
    const fileInput = screen.getByLabelText(/upload an \.xg file/i);
    const mockFile = new File(['content'], 'match.xg', { type: 'application/octet-stream' });

    await userEvent.upload(fileInput, mockFile);

    await waitFor(() => {
      expect(useAppStore.getState().activeScreen).toBe('viewer');
    });
  });
});
```

### End-to-End (E2E) Test Standards

E2E tests validate critical, multi-step user journeys. They should cover both happy paths and key error conditions.

**E2E Test Template (Playwright):**

```typescript
// tests/e2e/specs/upload-flow.spec.ts

import { test, expect } from '@playwright/test';

test.describe('File Upload Flow', () => {
  test('happy path: should upload a valid file and navigate to the viewer', async ({ page }) => {
    await page.goto('/');
    
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles('./tests/fixtures/valid-match.xg');
    
    await expect(page.getByTestId('backgammon-board')).toBeVisible({ timeout: 5000 });
  });

  test('error path: should show an error for a corrupted file', async ({ page }) => {
    await page.goto('/');
    
    const fileInput = page.locator('input[type="file"]');
    await fileInput.setInputFiles('./tests/fixtures/corrupted.xg');
    
    await expect(page.getByText(/corrupted/i)).toBeVisible({ timeout: 5000 });
    await expect(page.getByTestId('backgammon-board')).not.toBeVisible();
  });
});
```

### Performance Testing

Basic performance smoke tests will be included for critical operations to prevent regressions.

**Performance Test Template (Vitest):**

```typescript
// tests/unit/lib/parser/performance.test.ts

import { describe, it, expect } from 'vitest';
import { ParserService } from '@/lib/parser/parserService';
// ... fixture loading ...

describe('Parser Performance', () => {
  it('should parse a typical match file in under 1 second', async () => {
    const file = /* load valid-match.xg fixture */;
    const startTime = performance.now();
    const result = await ParserService.parseXgFile(file);
    const duration = performance.now() - startTime;

    expect(result.success).toBe(true);
    expect(duration).toBeLessThan(1000); // 1 second threshold
  }, 5000); // 5 second test timeout
});
```

---

## 9. Environment Configuration

### Overview

This application will use Next.js's built-in support for environment variables to manage configuration across different environments (local, preview, production). This allows us to change settings without modifying the codebase.

**Key Principles:**
*   Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser.
*   Variables without the prefix are server-side only (not applicable for our client-side MVP, but a standard to follow).
*   **All boolean environment variables** (e.g., `NEXT_PWA_DISABLED`) will be explicitly set in each environment to avoid ambiguity.

### File Management

We will use a `.env.local` file for local development. This file is **not** committed to version control and is listed in `.gitignore` to protect sensitive information and local overrides.

### Required Environment Variables

| Variable Name | Example Value | Purpose |
| :--- | :--- | :--- |
| **`NEXT_PUBLIC_APP_URL`** | `http://localhost:3000` | The canonical URL of the application. Used for metadata and PWA manifest configuration. |
| **`NEXT_PWA_DISABLED`** | `true` | Controls the `next-pwa` library. **Set to `true` in local development** to prevent the service worker from interfering with hot-reloading. |
| **`NEXT_PUBLIC_LOG_LEVEL`** | `debug` | Sets the verbosity of client-side logging. Use `debug` for development and `warn` or `error` for production. |
| **`NEXT_PUBLIC_API_BASE_URL`** | `''` | **Future Use:** Placeholder for a backend API. Defining it now ensures a clean integration path for future features. |
| **`NEXT_PUBLIC_ANALYTICS_ID`**| `G-XXXXXXXXXX` | **Optional:** ID for an analytics service like Google Analytics or Vercel Analytics. |

### Example `.env.local` File

Developers will create this file in the project root for their local environment.

```env
# .env.local - For local development ONLY. Do not commit.

# The URL of your local development server
NEXT_PUBLIC_APP_URL=http://localhost:3000

# Explicitly disable PWA service worker in dev for a better hot-reloading experience
NEXT_PWA_DISABLED=true

# Set log level to be verbose during development
NEXT_PUBLIC_LOG_LEVEL=debug

# No backend API for the MVP
NEXT_PUBLIC_API_BASE_URL=

# Optional: Add your personal analytics ID for testing if needed
# NEXT_PUBLIC_ANALYTICS_ID=
```

### Deployment Environment Configuration (Vercel)

For deployments, variables will be configured in the **Project Settings > Environment Variables** section of the Vercel dashboard, with specific values for each environment.

*   **Production Environment:**
    *   `NEXT_PUBLIC_APP_URL` will be set to the production domain (e.g., `https://www.backgammon-toolbox.com`).
    *   `NEXT_PWA_DISABLED` will be explicitly set to `false`.
    *   `NEXT_PUBLIC_LOG_LEVEL` will be set to `warn`.
    *   `NEXT_PUBLIC_ANALYTICS_ID` will be set to the production tracking ID.

*   **Preview Environment:**
    *   For preview deployments (e.g., from pull requests), environment variables will be configured in Vercel’s Preview environment. This allows testing with staging services and different analytics IDs without affecting production data. For example, `NEXT_PUBLIC_APP_URL` will be the Vercel-generated preview URL.

---

Excellent. Let's complete the architecture wit## 10. Frontend Developer Standards

This section provides a summary of all critical standards and conventions. It is a mandatory guide for all development, both human and AI-driven.

### Critical Coding Rules

1.  **TypeScript is Mandatory:** All new files must be `.ts` or `.tsx`. Use strict typing for all props, state, and functions. The `MatchData` interface from `src/types/` is the **unshakable contract** for all match-related data.

2.  **Component Structure:** All React components **MUST** follow the template defined in **Section 4**. This includes a `Props` interface, JSDoc comments, the `cn` utility for classes, and default exports.

3.  **Styling:**
    *   **NEVER** use hard-coded colors, spacing, or font sizes (e.g., `bg-[#c94e44]`, `h-[47px]`).
    *   **ALWAYS** use the semantic, theme-aware Tailwind utility classes defined in `tailwind.config.ts` (e.g., `bg-primary`, `text-foreground`, `min-h-touch`).
    *   All interactive elements (buttons, links) **MUST** have a `min-h-touch` and `min-w-touch` to ensure mobile usability.

4.  **State Management:**
    *   For state that is local to a single component, use React's built-in `useState` or `useReducer`.
    *   For global state (`activeScreen`, `isMatchLoaded`), **MUST** use the `useAppStore` hook.
    *   When accessing the store, **ALWAYS** use selectors to subscribe only to the specific state slices needed to prevent unnecessary re-renders (e.g., `useAppStore(state => state.activeScreen)`).

5.  **Parsing Logic Isolation:**
    *   UI components (`src/components/`) **MUST NOT** contain any file reading or binary parsing logic.
    *   All file parsing **MUST** be delegated exclusively to the `ParserService` located in `src/lib/parser/`.
    *   Components interact with the parser via the `ParseResult` discriminated union and **MUST** handle both the `success` and `error` cases gracefully.

6.  **Testing:**
    *   Every new UI component in `src/components/` **MUST** have a corresponding test file in `/tests/components/`.
    *   All new logic in `src/lib/` **MUST** have corresponding unit tests in `/tests/unit/lib/`.
    *   Tests must follow the patterns defined in **Section 8**, using Vitest and React Testing Library.

7.  **Accessibility:**
    *   Use semantic HTML elements wherever possible (`<button>`, `<nav>`, `<h1>`, etc.).
    *   All interactive elements must have an accessible label. For icon-only buttons, use an `aria-label`.

### Quick Reference

#### **Common Commands**

| Command | Description |
| :--- | :--- |
| `npm run dev` | Starts the local development server. |
| `npm run build` | Creates a production-ready build of the application. |
| `npm test` | Runs all unit and component tests via Vitest. |
| `npm run test:e2e`| Runs all end-to-end tests via Playwright. |

#### **File Naming Conventions**

| File Type | Convention | Example |
| :--- | :--- | :--- |
| Component | `PascalCase.tsx` | `BoardPoint.tsx` |
| Store | `camelCaseStore.ts` | `appStore.ts` |
| Service | `camelCaseService.ts` | `parserService.ts` |
| Type Definitions| `camelCase.ts` | `match.ts` |
| Unit/Component Test| `filename.test.tsx` | `Button.test.tsx` |
| E2E Test | `feature.spec.ts` | `upload-flow.spec.ts`|

#### **Key Import Patterns**

```typescript
// For combining Tailwind classes
import { cn } from '@/lib/utils';

// For accessing the global state
import { useAppStore } from '@/stores/appStore';

// For all file parsing operations
import { ParserService } from '@/lib/parser/parserService';

// For core data types
import type { MatchData, ParseResult } from '@/types/match';
```

---
