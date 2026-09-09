# 📊 JaneStreet-lite

[![Language: OCaml](https://shields.io)](https://ocaml.org)
[![Build System: Dune](https://shields.io)](https://dune.build)
[![License: MIT](https://shields.io)](LICENSE)

A high-frequency trading (HFT) infrastructure prototype and backtesting environment built entirely from scratch in **OCaml**. 

This repository replicates the core architectural layers of an institutional market maker—featuring a deterministic continuous double-auction order book, an atomic pre-trade risk engine, real-time arbitrage detection, and a historical tick simulator. By leveraging OCaml's strong type system and functional paradigms, the architecture minimizes runtime garbage collection overhead and guarantees strict execution invariants.

---

## 🏗️ System Architecture

The pipeline is organized into decoupled functional layers, ensuring that data flows deterministically from raw market tick events to order execution:

```text
  [ Historical Ticks (.csv) ] 
              │
              ▼
    ┌──────────────────┐
    │  Backtester Loop │
    └─────────┬────────┘
              │ (Tick Feed)
              ▼
    ┌──────────────────┐       ┌──────────────────┐
    │    Order Book    ├──────►│ Arbitrage Engine │
    └─────────┬────────┘       └─────────┬────────┘
              │                          │ (Signals)
              ▼                          ▼
    ┌──────────────────┐       ┌──────────────────┐
    │   Risk Manager   │◄──────┤  Trading System  │
    └──────────────────┘       └──────────────────┘
```

1. **`order_book.ml` (The Core Matcher):** Implements a high-throughput limit order book (LOB). It manages bid/ask queues using functional immutable data structures to ensure deterministic price-time priority execution without side-effect mutations.
2. **`risk_manager.ml` (Pre-Trade Validation):** Acts as the atomic gatekeeper of the network. It screens every trade signal against strict position boundaries, maximum drawdown limits, and fat-finger checks *before* orders hit the book.
3. **`arbitrage.ml` & `trading_system.ml` (The Alpha Layer):** Evaluates real-time price loops across simulated order routing paths to capture cross-market latency anomalies.
4. **`backtester.ml`:** A high-speed backtesting engine that ingests historical tick datasets (`btc_historical_ticks.csv`), processes them chronologically, and outputs complete execution summaries.
5. **`hardware_signal.ml` & `compile_hardware.ml`:** High-level software models designed to simulate hardware boundary interactions (e.g., kernel bypass/FPGA boundaries) to minimize execution paths.

---

## ⚡ Technical Highlights

* **Functional Invariance:** Leverages OCaml’s algebraic data types (ADTs) and exhaustive pattern matching to ensure unexpected market state mutations are caught completely at compile time.
* **Deterministic Matching:** Designed explicitly to eliminate hidden memory allocation spikes inside core matching loops, preventing random garbage collection pauses during critical trade execution windows.
* **Atomic Fail-Safe Operations:** The pre-trade risk engine is structured to fail-shut. If any risk metric is breached, order execution drops instantly, preventing catastrophic cascading losses.

---

## 🚀 Getting Started

### Prerequisites

Ensure you have OCaml and the `dune` build utility installed:

```bash
# Using opam (OCaml Package Manager)
opam switch create 5.1.0
opam install dune
```

### Building the Project

Compile the workspace using the Dune build system:

```bash
dune build
```

### Running the Backtester

To stream historical data files through the execution framework, execute the following command:

```bash
dune exec bin/trading_system.exe -- --backtest btc_historical_ticks.csv
```

### Running Tests

Execute the automated validation suite to audit order matching and risk compliance invariants:

```bash
dune test
```

---

## 📝 Performance Telemetry & Logs

When running the system, automated execution logs are piped to `audit_executions.txt`. This file maintains a transparent, timestamped history of all bids, offers, matched trades, risk rejections, and arbitrage events captured across historical backtests.

---
