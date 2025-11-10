# Just-In-Time Frequency Hopping Spread Spectrum (JIT-FHSS)

A MATLAB simulator for Just-In-Time Frequency Hopping Spread Spectrum (JIT-FHSS) communication between satellites and ground stations using external central sources for pattern distribution.

## Overview

Traditional Frequency Hopping Spread Spectrum (FHSS) systems use pseudo-random number generators (PRNG) with pre-shared seeds to determine hopping patterns. While functional, this approach has limitations:

- **Limited Entropy**: Patterns are deterministic and eventually repeat
- **Security Risk**: If the seed is compromised, patterns can be predicted
- **Static Patterns**: Cannot adapt to changing conditions

**JIT-FHSS** addresses these limitations by:

1. **External Pattern Generation**: Central sources generate high-entropy patterns using true random number generation (TRNG simulation)
2. **Just-In-Time Distribution**: Patterns are distributed to transmitter and receiver shortly before use
3. **Redundancy**: Multiple central sources provide failover capability
4. **Dynamic Adaptation**: Patterns can be adjusted based on interference or spectrum availability

## Features

- ✅ **External Central Source Manager** with redundancy and automatic failover
- ✅ **Satellite Communication Model** with realistic orbital dynamics (LEO)
- ✅ **Doppler Effect Modeling** with automatic compensation
- ✅ **Pattern Buffering** with synchronization between sender and receiver
- ✅ **Propagation Delay** modeling for realistic timing
- ✅ **Jamming Scenarios** to test resilience
- ✅ **Fallback Cache** for last-resort operation
- ✅ **Comprehensive Analysis** with visualization tools

## System Architecture

```
┌──────────────────────────────────┐
│   Central Source Manager         │
│  ┌────────┐ ┌────────┐ ┌──────┐ │
│  │Source 1│ │Source 2│ │Source3│ │
│  │ (TRNG)│ │ (TRNG)│ │ (TRNG)│ │
│  └───┬────┘ └───┬────┘ └───┬───┘ │
│      └──────────┴─────────┬┘     │
│            Patterns       │      │
│      ┌────────────────────┘      │
│      │   ┌─────────────────┐     │
│      │   │  Fallback Cache │     │
│      │   │     (PRNG)      │     │
│      │   └─────────────────┘     │
└──────┼───────────────────────────┘
       │ Pattern Distribution
       │
   ┌───▼────────┐         ┌──────────────┐
   │ Satellite  │◄───────►│Ground Station│
   │  Sender    │  Data   │   Receiver   │
   │            │  (FHSS) │              │
   │ • Orbit    │         │ • Tracking   │
   │ • Doppler  ├────────►│ • Doppler    │
   │ • Buffer   │         │ • Buffer     │
   └────────────┘         └──────────────┘
```

## Quick Start

### Prerequisites

- MATLAB R2018b or later
- No additional toolboxes required

### Installation

```bash
git clone https://github.com/yourusername/JIT-FHSS.git
cd JIT-FHSS/matlab_simulator
```

### Running the Simulation

```matlab
% Open MATLAB and navigate to the simulator directory
cd matlab_simulator

% Run the main simulation
run_simulation

% Analyze results
analyze_results
```

### Output

The simulator generates:
- `results/simulation_results.mat` - Complete simulation data
- `results/jit_fhss_analysis.png` - Visualization plots
- `results/simulation_report.txt` - Summary report

## Key Concepts

### 1. Orbital Latency

**Orbital latency** is the signal propagation delay between a satellite and ground station:

- **LEO satellites** (500 km altitude): ~1.7 to 7 ms delay
- Depends on satellite range (distance to ground station)
- Calculated as: `delay = range / speed_of_light`

**Impact**: Patterns must be buffered and distributed ahead of time to account for this delay.

### 2. Doppler Effect

When a satellite moves relative to a ground station, the frequency of transmitted signals appears shifted:

- **Approaching satellite**: Frequency increases (blue shift)
- **Receding satellite**: Frequency decreases (red shift)
- **Formula**: `f_received = f_transmitted × (1 + v_radial/c)`

**For LEO satellites at 2 GHz:**
- Orbital velocity: ~7.6 km/s
- Maximum range rate: ~4 km/s
- **Doppler shift: ±27 kHz**

**Impact**: Receiver must compensate for Doppler shift to correctly decode the frequency-hopped signal. This requires knowing the satellite's position and velocity.

### 3. Synchronization

For FHSS to work, transmitter and receiver must:
1. **Know the same hopping pattern** (solved by central source distribution)
2. **Hop at the same time** (solved by buffering and sequence numbers)
3. **Account for Doppler** (solved by tracking and compensation)

The simulator implements:
- **Pattern buffers** with sequence numbers for ordering
- **Pre-loading** patterns to handle distribution delays
- **Buffer monitoring** to request more patterns before running out

## Simulation Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| Simulation Duration | 1000 s | Total simulation time |
| Time Step | 0.1 s | Update rate |
| Hop Duration | 1.0 s | Time per frequency |
| Frequency Band | 2.0-2.1 GHz | S-band |
| Num Frequencies | 100 | Available channels |
| Satellite Altitude | 500 km | LEO orbit |
| Orbital Inclination | 45° | Orbit angle |
| Central Sources | 3 | Redundant sources |
| Buffer Size | 50 | Patterns buffered |

## Results

### Example Output

```
=== JIT-FHSS Simulation Results ===

Performance Metrics:
  Total Transmissions: 8421
  Successful Receptions: 8418
  Success Rate: 99.96%

Central Source Statistics:
  Active Sources: 3/3
  Total Patterns Generated: 1247
  Source Failovers: 1

Doppler Effect Analysis:
  Maximum Doppler Shift: 27.3 kHz
  Mean Absolute Doppler: 14.8 kHz

Communication Performance:
  Mean Frequency Error: 0.15 kHz
  Max Frequency Error: 2.34 kHz
```

### Visualization

The analyzer generates 6 plots:
1. **Frequency Hopping Pattern** - Shows random hopping behavior
2. **Doppler Shift** - Varies as satellite passes overhead
3. **Satellite Range** - Distance to ground station
4. **Range Rate** - Radial velocity (determines Doppler)
5. **Reception Success** - Visual timeline of successful decoding
6. **Frequency Error** - Accuracy of Doppler compensation

## Documentation

- **[User Guide](matlab_simulator/docs/USER_GUIDE.md)** - Complete usage instructions and customization
- **[Technical Details](matlab_simulator/docs/TECHNICAL_DETAILS.md)** - Implementation details and algorithms

## Project Structure

```
JIT-FHSS/
├── README.md                       # This file
└── matlab_simulator/
    ├── run_simulation.m            # Main simulation script
    ├── analyze_results.m           # Results analysis and visualization
    ├── src/                        # Source code
    │   ├── CentralSourceManager.m  # Pattern generation with redundancy
    │   ├── PatternBuffer.m         # Buffering and synchronization
    │   ├── OrbitModel.m            # Satellite orbital mechanics
    │   ├── DopplerModel.m          # Doppler shift calculation
    │   ├── SatelliteSender.m       # Satellite transmitter
    │   └── GroundReceiver.m        # Ground station receiver
    ├── docs/                       # Documentation
    │   ├── USER_GUIDE.md           # User guide
    │   └── TECHNICAL_DETAILS.md    # Technical documentation
    └── results/                    # Output directory
        ├── simulation_results.mat
        ├── jit_fhss_analysis.png
        └── simulation_report.txt
```

## Use Cases

### 1. Satellite Communications
- LEO satellite networks
- High-security tactical communications
- Anti-jamming systems

### 2. Research & Development
- FHSS algorithm testing
- Doppler compensation validation
- Synchronization protocol development

### 3. Education
- Satellite communication systems
- Spread spectrum techniques
- Orbital mechanics and Doppler effects

## Customization Examples

### Test Jamming Resilience

```matlab
% Enable aggressive jamming
jamCentralSource = true;
centralSource.setJamProbability(0.05);  % 5% chance per time step

% Jam multiple sources
centralSource.jamSource(1);
centralSource.jamSource(2);
```

### Change Orbital Parameters

```matlab
% Geostationary orbit (36,000 km)
altitude = 36000;
inclination = 0;

% Note: Doppler will be much smaller, but propagation delay ~240 ms
```

### Faster Frequency Hopping

```matlab
hopDuration = 0.1;  % 10 hops per second
bufferSize = 100;   % Need larger buffer for faster hopping
```

## Future Enhancements

- [ ] Elliptical orbit support
- [ ] Multiple satellite constellation
- [ ] Adaptive hopping (avoid jammed frequencies)
- [ ] Channel noise modeling (AWGN)
- [ ] Real-time visualization
- [ ] Hardware-in-the-loop testing

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

MIT License - see LICENSE file for details

## Acknowledgments

- Orbital mechanics based on simplified Kepler equations
- Doppler calculations use classical electromagnetic wave theory
- FHSS concepts from IEEE 802.11 and tactical radio systems

## Contact

For questions or collaboration:
- Create an issue on GitHub
- Email: [your-email]

---

**Note**: This is a simulation for research and educational purposes. Real-world implementations require additional considerations including:
- Regulatory compliance (frequency allocation)
- Hardware limitations
- Atmospheric effects
- Link budget analysis
- Error correction coding
- Security protocols
