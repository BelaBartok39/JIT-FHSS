# JIT-FHSS Code Breakdown - Easy Technical Guide

## Overview

This document explains how the JIT-FHSS simulator works in plain language, breaking down each component and showing how they interact to create a working satellite communication system.

---

## Table of Contents

1. [System Architecture](#system-architecture)
2. [Core Components](#core-components)
3. [How the Simulation Works](#how-the-simulation-works)
4. [Key Concepts Explained](#key-concepts-explained)
5. [Code Walkthrough](#code-walkthrough)

---

## System Architecture

Think of the JIT-FHSS system like a radio communication setup, but smarter:

```
┌─────────────────────────────────────┐
│     Central Source Manager          │  ← The "Pattern Generator"
│  Generates random frequency patterns │     (Like a DJ choosing songs)
└──────────────┬──────────────────────┘
               │
               ├──► Pattern #1: 2.045 GHz
               ├──► Pattern #2: 2.089 GHz
               ├──► Pattern #3: 2.012 GHz
               │     (and so on...)
               │
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌─────────────┐   ┌─────────────┐
│  Satellite  │   │   Ground    │
│   Sender    │   │  Receiver   │
│             │   │             │
│ "Transmit   │   │ "Listen on  │
│  on freq X" │   │  freq X"    │
└──────┬──────┘   └──────┬──────┘
       │                 │
       └────► Signal ────┘
        (with Doppler shift)
```

**The Big Idea**: Instead of using a predictable pattern, a central source tells both the satellite and ground station which frequency to use. They hop together, staying synchronized.

---

## Core Components

### 1. CentralSourceManager (`src/CentralSourceManager.m`)

**What it does**: Generates random frequency patterns for FHSS.

**Think of it as**: A lottery machine that picks random frequency numbers. Each number is a frequency the satellite will transmit on.

**Key features**:
- **Multiple sources**: Has 3 independent "lottery machines" for redundancy
- **Failover**: If one machine breaks (gets jammed), automatically switches to another
- **Fallback cache**: Has pre-generated backup patterns if all sources fail
- **Sequence numbers**: Each pattern gets a unique ID so sender/receiver stay in sync

**Simple example**:
```matlab
% Create manager with 3 sources, 100 frequencies, 2.0-2.1 GHz band
manager = CentralSourceManager(3, 100, [2e9, 2.1e9], 1000);

% Generate a pattern
pattern = manager.generatePattern(currentTime);
% Returns: pattern.frequency = 2,045,123,456 Hz
%         pattern.sequenceNumber = 1
%         pattern.sourceId = 1
```

**How it works internally**:
1. Check if current source is working
2. If not, switch to next source
3. Generate random frequency from the band
4. Assign sequence number
5. Return pattern to caller

---

### 2. PatternBuffer (`src/PatternBuffer.m`)

**What it does**: Stores patterns in a queue for later use.

**Think of it as**: A playlist that holds the next 50 songs (frequencies) to play.

**Why needed**:
- Satellite and ground station can't request patterns instantly (there's delay)
- Need to pre-load patterns to avoid gaps in transmission
- Both sender and receiver need the SAME playlist

**Key features**:
- **Size limit**: Holds up to 50 patterns
- **Sequence ordering**: Automatically sorts patterns by sequence number (handles out-of-order delivery)
- **Low-level warning**: Alerts when buffer drops below 10 patterns
- **Auto-cleanup**: Removes old patterns to save memory

**Simple example**:
```matlab
% Create buffer for 50 patterns, warn when <10 remain
buffer = PatternBuffer(50, 10);

% Add patterns
buffer.addPattern(pattern1);  % Sequence #1
buffer.addPattern(pattern2);  % Sequence #2

% Get next pattern to use
currentPattern = buffer.getNextPattern(currentTime);
% Returns pattern #1, moves to pattern #2 for next call
```

**Buffer states**:
```
Full:     [■■■■■■■■■■■■■■■■■■■■] 50/50 patterns
Healthy:  [■■■■■■■■■■■□□□□□□□□□] 15/50 patterns
Low:      [■■■■■■■■■□□□□□□□□□□□] 9/50 patterns ⚠️ WARNING!
Empty:    [□□□□□□□□□□□□□□□□□□□□] 0/50 patterns ❌ ERROR!
```

---

### 3. OrbitModel (`src/OrbitModel.m`)

**What it does**: Simulates a satellite orbiting Earth.

**Think of it as**: A clock that tells you where the satellite is at any moment in time.

**Key calculations**:

#### Orbital Period (How long one orbit takes)
```
Period = 2π × √(radius³ / μ)

For 500 km altitude:
- radius = 6371 + 500 = 6871 km
- μ = 398,600 km³/s² (Earth's gravity constant)
- Period = 94.5 minutes
```

#### Orbital Velocity (How fast it moves)
```
Velocity = √(μ / radius)

For 500 km altitude:
- Velocity = 7.62 km/s (27,432 km/h!)
```

#### Position at Time T
The satellite moves in a circle (simplified model):

```matlab
% Angle in orbit (0° to 360°, repeats each orbit)
theta = (2π / Period) × time

% Position in 3D space
x = radius × cos(theta)
y = radius × sin(theta) × cos(inclination)
z = radius × sin(theta) × sin(inclination)
```

#### Visibility Check
Is the satellite above the horizon from the ground station?

```matlab
% Calculate elevation angle
elevation = 90° - angle_between(range_vector, vertical)

% Visible if above 5° (horizon + atmospheric effects)
visible = (elevation >= 5°)
```

**Example**:
```matlab
% Create orbit model
orbit = OrbitModel(500, 98, 0, 0);
% altitude=500km, inclination=98°, equator location

% Where is satellite at t=100 seconds?
[position, velocity] = orbit.getSatelliteState(100);

% How far from ground station?
[range, rangeRate] = orbit.getRangeToGroundStation(100);
% range = 1500 km (distance)
% rangeRate = -3.2 km/s (approaching, negative means getting closer)

% Can ground station see it?
visible = orbit.isVisible(100, 5);  % true if elevation > 5°
```

---

### 4. DopplerModel (`src/DopplerModel.m`)

**What it does**: Calculates how satellite motion changes the signal frequency.

**Think of it as**: Like how a police siren sounds higher-pitched when approaching, lower when moving away.

**The Physics**:

When satellite moves toward ground station:
```
Frequency increases (blue shift)
f_received > f_transmitted
```

When satellite moves away:
```
Frequency decreases (red shift)
f_received < f_transmitted
```

**The Formula**:
```
Doppler Shift = f_transmitted × (velocity / speed_of_light)

Example:
- Transmitted: 2.05 GHz
- Satellite approaching at 4 km/s
- Doppler shift = 2.05 GHz × (4000 m/s / 300,000,000 m/s)
                = 2.05 GHz × 0.0000133
                = 27,300 Hz = 27.3 kHz

Received frequency = 2.05 GHz + 27.3 kHz = 2,050,027,300 Hz
```

**Why this matters for FHSS**:

If we're supposed to transmit at 2.05 GHz, but the receiver hears 2,050,027,300 Hz due to Doppler, it won't know which frequency we're using! The Doppler shift (27 kHz) is larger than the frequency spacing between channels (1 MHz / 100 = 10 kHz).

**Solution**: Receiver must compensate:
```matlab
% Receiver knows:
% 1. Expected transmit frequency (from pattern)
% 2. Satellite velocity (from tracking)

% Calculate expected Doppler
expectedDoppler = calculateDopplerShift(expectedFreq, velocity);

% Remove it from received signal
actualFreq = receivedFreq - expectedDoppler;

% Now compare with expected
if abs(actualFreq - expectedFreq) < tolerance
    decode_success();
else
    sync_error();
end
```

**Code example**:
```matlab
doppler = DopplerModel();

% Satellite approaching at 4 km/s, transmitting at 2.05 GHz
shift = doppler.calculateDopplerShift(2.05e9, 4.0);
% Returns: 27,300 Hz

% Apply Doppler (what receiver actually hears)
receivedFreq = doppler.applyDopplerShift(2.05e9, 4.0);
% Returns: 2,050,027,300 Hz

% Compensate at receiver (remove Doppler)
compensated = doppler.compensateDoppler(receivedFreq, 4.0, 2.05e9);
% Returns: 2,050,000,000 Hz (back to original!)
```

---

### 5. SatelliteSender (`src/SatelliteSender.m`)

**What it does**: The satellite's radio transmitter.

**Think of it as**: A walkie-talkie that automatically changes channels every second.

**Main responsibilities**:

1. **Store patterns** in buffer
2. **Hop frequencies** every 1 second
3. **Transmit data** on current frequency
4. **Log everything** for analysis

**How frequency hopping works**:
```
Time:     0s    1s    2s    3s    4s    5s
          │     │     │     │     │     │
Freq:   2.04  2.09  2.01  2.06  2.03  2.08 GHz
Data:    [A]   [B]   [C]   [D]   [E]   [F]
          ↓     ↓     ↓     ↓     ↓     ↓
       Hop!  Hop!  Hop!  Hop!  Hop!  Hop!
```

**Code flow**:
```matlab
% Every time step (0.1 seconds)
satellite.transmit(data);

Inside transmit():
├─ Check: Has 1 second passed since last hop?
│  ├─ Yes? → Get next pattern from buffer
│  │         Switch to new frequency
│  └─ No?  → Keep using current frequency
│
├─ Get satellite velocity (for Doppler)
├─ Transmit data byte
└─ Log: time, freq, Doppler shift, range, etc.
```

**Example**:
```matlab
% Create satellite sender
satellite = SatelliteSender(orbitModel, 50, 1.0);
% buffer size=50, hop every 1.0 seconds

% Fill buffer with patterns
for i = 1:50
    pattern = centralSource.generatePattern(0);
    satellite.patternBuffer.addPattern(pattern);
end

% Transmit data
satellite.transmit(65);  % Send byte value 65 ('A')

% What happened internally:
% 1. Checked if need to hop (every 1 second)
% 2. If yes: got next pattern, switched frequency
% 3. Calculated current Doppler shift
% 4. "Transmitted" data on current frequency
% 5. Logged: time, transmit freq, received freq (with Doppler), range, etc.
```

---

### 6. GroundReceiver (`src/GroundReceiver.m`)

**What it does**: The ground station's radio receiver.

**Think of it as**: A walkie-talkie that changes to the same channels as the satellite.

**Main responsibilities**:

1. **Store patterns** (same ones as satellite!)
2. **Hop frequencies** to match satellite
3. **Compensate for Doppler**
4. **Decode data** if frequency matches

**How reception works**:
```
Satellite transmits at 2.05 GHz
       ↓
Doppler shifts it to 2.050027 GHz (due to satellite motion)
       ↓
Ground station receives 2.050027 GHz
       ↓
Receiver knows: "I expect 2.05 GHz, satellite approaching at 4 km/s"
       ↓
Calculates: Expected Doppler = +27 kHz
       ↓
Compensates: 2.050027 GHz - 27 kHz = 2.05 GHz ✓
       ↓
Compares with expected frequency
       ↓
Match? → Decode success!
No match? → Sync error
```

**Code flow**:
```matlab
receiver.receive(transmittedSignal);

Inside receive():
├─ Check: Has 1 second passed since last hop?
│  └─ Yes? → Get next pattern (same as satellite!)
│
├─ Get expected frequency from pattern
├─ Get satellite velocity (for Doppler compensation)
│
├─ Calculate expected Doppler shift
├─ Remove Doppler from received signal
│
├─ Compare compensated freq with expected
│  ├─ Match (within tolerance)? → Success! ✓
│  └─ No match? → Sync error ✗
│
└─ Log: time, frequencies, error, success/fail
```

**Example**:
```matlab
% Create ground receiver
receiver = GroundReceiver(orbitModel, 50, 1.0);

% Fill with SAME patterns as satellite
for i = 1:50
    pattern = centralSource.generatePattern(0);
    receiver.patternBuffer.addPattern(pattern);
end

% Receive transmitted signal
transmittedSignal = struct();
transmittedSignal.receivedFreq = 2050027300;  % With Doppler
transmittedSignal.dataSymbol = 65;            % Data being sent
transmittedSignal.range = 1500;               % km
transmittedSignal.rangeRate = 4.0;            % km/s approaching

[success, decodedData] = receiver.receive(transmittedSignal);
% success = true (frequencies match after Doppler compensation)
% decodedData = 65 ('A')
```

---

## How the Simulation Works

### Initialization Phase

```matlab
1. Create Central Source Manager
   └─ 3 redundant sources ready
   └─ Fallback cache initialized

2. Create Orbital Model
   └─ Satellite at 500 km altitude
   └─ 98° inclination (polar orbit)
   └─ Ground station at equator (0°N, 0°E)
   └─ Orbital period: 94.5 minutes

3. Create Satellite Sender
   └─ Pattern buffer (holds 50 patterns)
   └─ Hop duration: 1 second

4. Create Ground Receiver
   └─ Pattern buffer (holds 50 patterns)
   └─ Same hop duration: 1 second

5. Find Visibility Window
   └─ Scan orbit to find when satellite is above horizon
   └─ Start simulation at that time

6. Pre-load Pattern Buffers
   ├─ Generate 50 patterns from central source
   ├─ Give SAME patterns to both satellite and receiver
   └─ Both now have identical pattern sequences!
```

### Main Simulation Loop

The simulation runs for 6000 seconds (100 minutes), stepping every 0.1 seconds:

```matlab
For each time step (60,000 iterations):

├─ Update current time
│
├─ Check jamming scenario
│  ├─ At t=2400s: Jam source #1
│  └─ At t=3600s: Restore source #1
│
├─ Check buffer levels
│  └─ If low (<30%):
│      ├─ Generate 10 new patterns
│      ├─ Add to satellite buffer
│      └─ Add to receiver buffer (SAME patterns!)
│
├─ Check satellite visibility
│  └─ If visible (elevation > 5°):
│      │
│      ├─ TRANSMIT:
│      │  ├─ Generate random data byte
│      │  ├─ Satellite hops if needed
│      │  ├─ Transmit on current frequency
│      │  ├─ Apply Doppler shift
│      │  └─ Log transmission
│      │
│      └─ RECEIVE:
│         ├─ Receiver hops if needed (synced!)
│         ├─ Get Doppler-shifted signal
│         ├─ Compensate for Doppler
│         ├─ Compare with expected frequency
│         ├─ Decode if match
│         └─ Log reception (success/fail)
│
└─ Update progress indicator
```

### Results Collection Phase

```matlab
After simulation completes:

├─ Count transmissions: 8,280
├─ Count successful receptions: 8,270
├─ Calculate success rate: 99.88%
│
├─ Collect logs:
│  ├─ Satellite transmission log (8,280 entries)
│  └─ Receiver reception log (8,280 entries)
│
├─ Save to results/simulation_results.mat
│
└─ Display summary statistics
```

---

## Key Concepts Explained

### 1. Why Sender and Receiver Must Share Patterns

**WRONG approach** (what we had initially):
```matlab
% Satellite requests patterns
satellite.requestPatterns(centralSource, 50);
% Gets: patterns 1-50

% Receiver requests patterns
receiver.requestPatterns(centralSource, 50);
% Gets: patterns 51-100

RESULT: They hop to DIFFERENT frequencies!
Success rate: 37% ❌
```

**CORRECT approach** (current implementation):
```matlab
% Generate patterns ONCE
for i = 1:50
    pattern = centralSource.generatePattern(0);

    % Give SAME pattern to both
    satellite.patternBuffer.addPattern(pattern);
    receiver.patternBuffer.addPattern(pattern);
end

RESULT: They hop to SAME frequencies!
Success rate: 99.88% ✓
```

### 2. Why Doppler Compensation is Critical

**Without compensation**:
```
Satellite transmits: 2.050000000 GHz (pattern #42)
Doppler shift: +27,300 Hz
Receiver hears: 2.050027300 GHz

Receiver expects: 2.050000000 GHz (pattern #42)
Received: 2.050027300 GHz
Error: 27,300 Hz → FAIL! ❌

The 27 kHz error is larger than channel spacing (10 kHz)!
```

**With compensation**:
```
Satellite transmits: 2.050000000 GHz
Doppler shift: +27,300 Hz
Receiver hears: 2.050027300 GHz

Receiver calculates expected Doppler: +27,300 Hz
Compensates: 2.050027300 - 0.000027300 = 2.050000000 GHz
Compares with expected: 2.050000000 GHz
Error: 0 Hz → SUCCESS! ✓
```

### 3. Why Polar Orbit at Equator

**Problem with 45° inclination + California**:
```
Orbital plane doesn't intersect California's latitude
Maximum elevation: -29° (always below horizon!)
Visibility: NEVER ❌
```

**Solution with 98° inclination + Equator**:
```
Polar orbit crosses equator twice per orbit
Ground station at 0°N, 0°E
Satellite passes directly overhead
Maximum elevation: 90° (zenith!)
Visibility: GUARANTEED ✓
```

### 4. Buffer Management Strategy

**Why we need buffers**:
- Can't request patterns instantly (would cause delays)
- Need continuous stream for frequency hopping
- Must handle communication delays

**Buffer refill logic**:
```
Initial: 50 patterns loaded
↓
Consumption: 1 pattern per second
↓
After 50 seconds: Buffer empty!
↓
Refill trigger: When < 15 patterns (30%)
Action: Request 10 new patterns
↓
New level: ~19 patterns
↓
Repeat every 10 seconds
↓
Buffer oscillates between 9-19 patterns
(This causes the warnings you see!)
```

**Why warnings appear**:
```
Time:     50s    51s    52s    53s    ...    60s    61s
Buffer:    9  →  19  →  18  →  17  →  ... →  10  →   9
           ⚠️                                        ⚠️
         WARN!                                    WARN!

Pattern used every second
Refill every 10 seconds
Buffer keeps hitting threshold → Many warnings
```

---

## Code Walkthrough

### Main Simulation Script (`run_simulation.m`)

Let's walk through the entire simulation step by step:

#### Step 1: Parameters Setup
```matlab
% How long to simulate
simDuration = 6000;  % 100 minutes
timeStep = 0.1;      % Update 10 times per second
hopDuration = 1.0;   % Change frequency every 1 second

% Radio parameters
numFrequencies = 100;  % 100 channels
frequencyBand = [2.0e9, 2.1e9];  % 2.0-2.1 GHz (100 MHz bandwidth)
% Each channel is 1 MHz wide

% Satellite orbit
altitude = 500;      % km above Earth
inclination = 98;    % Polar orbit (passes over poles)
groundStationLat = 0;   groundStationLon = 0;  % Equator

% System configuration
numCentralSources = 3;  % Redundancy
bufferSize = 50;        // Hold 50 patterns (50 seconds worth)
```

**Why these values?**
- 6000 seconds ensures full orbital pass
- 0.1s time step is fine enough for smooth simulation
- 1.0s hop duration is typical for tactical FHSS
- 2.0-2.1 GHz is S-band (satellite communications)
- 98° inclination is sun-synchronous polar orbit (used by Earth observation satellites)
- Equator location guarantees visibility

#### Step 2: Create Components
```matlab
% Pattern generator
centralSource = CentralSourceManager(3, 100, [2e9, 2.1e9], 1000);

% Satellite physics
orbitModel = OrbitModel(500, 98, 0, 0);
% Result: Period = 94.5 minutes, Velocity = 7.62 km/s

% Transmitter
satellite = SatelliteSender(orbitModel, 50, 1.0);

% Receiver
receiver = GroundReceiver(orbitModel, 50, 1.0);
```

#### Step 3: Find When Satellite is Visible
```matlab
for t_search = 0:10:maxSearchTime
    elevation = orbitModel.getElevationAngle(t_search);
    if elevation >= 5°
        timeOffset = t_search;
        found = true;
        break;
    end
end
```

**What this does**: Scans through time to find when satellite first appears above horizon. In our case, satellite starts at zenith (directly overhead), so `timeOffset = 0`.

#### Step 4: Pre-load Identical Patterns
```matlab
for i = 1:bufferSize
    % Generate ONE pattern
    pattern = centralSource.generatePattern(0);

    % Give to BOTH satellite and receiver
    satellite.patternBuffer.addPattern(pattern);
    receiver.patternBuffer.addPattern(pattern);
end
```

**Critical**: This ensures perfect synchronization. Both have patterns 1-50 in same order.

#### Step 5: Main Loop
```matlab
for i = 1:numTimeSteps  % 60,000 iterations
    currentTime = timeVector(i);  % 0.0, 0.1, 0.2, ... 6000.0

    satellite.setTime(currentTime);
    receiver.setTime(currentTime);

    % Jamming scenario
    if currentTime == 2400
        centralSource.jamSource(1);  % Disable source #1
    end

    % Refill buffers if needed
    if mod(i, 10) == 0  % Every second
        if bufferLevel < 30%
            for j = 1:10
                pattern = centralSource.generatePattern(currentTime);
                satellite.patternBuffer.addPattern(pattern);
                receiver.patternBuffer.addPattern(pattern);
            end
        end
    end

    % If satellite visible, transmit and receive
    if orbitModel.isVisible(currentTime, 5)
        data = randi([0, 255]);  % Random byte

        satellite.transmit(data);

        % Get what was transmitted
        lastTx = satellite.transmitLog(end);

        % Build received signal
        rxSignal.receivedFreq = lastTx.receivedFreq;  % With Doppler
        rxSignal.dataSymbol = data;
        rxSignal.range = lastTx.range;
        rxSignal.rangeRate = lastTx.rangeRate;

        % Try to receive
        [success, decoded] = receiver.receive(rxSignal);

        if success
            successfulTransmissions++;
        end
        totalTransmissions++;
    end
end
```

**What happens each iteration**:
1. Update time (0.0 → 0.1 → 0.2 → ... → 6000.0 seconds)
2. Tell all components current time
3. Handle jamming if we're at t=2400s
4. Every second, check if buffers need refilling
5. If satellite is visible:
   - Generate random data byte
   - Satellite transmits (hops if needed, applies Doppler)
   - Receiver attempts to decode (hops if needed, compensates Doppler)
   - Count success/failure

#### Step 6: Results
```matlab
successRate = (successfulTransmissions / totalTransmissions) * 100;
% Result: 99.88%

save('results/simulation_results.mat', 'results');
```

---

### Analysis Script (`analyze_results.m`)

This script loads the saved data and creates visualizations:

```matlab
% Load data
load('results/simulation_results.mat');
satelliteLog = results.satelliteLog;  % 8,280 entries
receiverLog = results.receiverLog;    // 8,280 entries

% Extract time series
times = [satelliteLog.time];
txFreqs = [satelliteLog.transmitFreq];
rxFreqs = [satelliteLog.receivedFreq];
dopplerShifts = [satelliteLog.dopplerShift];
ranges = [satelliteLog.range];
rangeRates = [satelliteLog.rangeRate];

% Plot 1: Frequency hopping pattern
plot(times, txFreqs/1e6);
% Shows random hopping: 2000-2100 MHz

% Plot 2: Doppler shift over time
plot(times, dopplerShifts/1e3);
// Shows ±49 kHz variation as satellite passes

% Plot 3: Range to satellite
plot(times, ranges);
// Shows 500-2077 km as satellite moves

% Plot 4: Range rate (radial velocity)
plot(times, rangeRates);
// Shows ±7 km/s, crosses zero at closest approach

% Plot 5: Reception success timeline
successTimes = times([receiverLog.success]);
plot(successTimes, ones(size(successTimes)));
// Shows 99.88% successful (green dots)

% Plot 6: Frequency error after compensation
freqErrors = [receiverLog.freqError];
plot(times, freqErrors);
// Shows ~0 kHz error (perfect compensation!)
```

---

## Summary

### What We Built

A complete satellite communication simulator that demonstrates:

1. **Just-In-Time pattern distribution** from central source to endpoints
2. **High-entropy frequency hopping** (random, unpredictable patterns)
3. **Doppler shift compensation** for moving satellite
4. **Automatic failover** when sources are jammed
5. **Buffer management** for continuous operation
6. **Realistic orbital mechanics** with visibility calculations

### Key Results

- **Success Rate**: 99.88% (8,270 of 8,280 transmissions decoded)
- **Doppler Compensation**: Perfect (0 Hz average frequency error)
- **Source Resilience**: Handled jamming transparently (1 failover)
- **Frequency Utilization**: 100% (used all available channels)

### Why It Works

The simulation succeeds because:

1. **Synchronized patterns**: Sender and receiver share identical pattern sequences
2. **Doppler compensation**: Receiver removes predictable frequency shifts
3. **Buffer pre-loading**: No gaps in pattern availability
4. **Redundant sources**: System continues when primary source fails
5. **Realistic physics**: Proper orbital mechanics and signal propagation

This proves that Just-In-Time FHSS with external central sources is a viable approach for secure satellite communications!

---

## Next Steps for Learning

To better understand the code:

1. **Run `test_visibility.m`** - See how orbital geometry affects visibility
2. **Modify parameters** in `run_simulation.m`:
   - Change `hopDuration` to 0.5s (faster hopping)
   - Change `altitude` to 1000 km (higher orbit, longer period)
   - Change `jamProbability` to 0.05 (more aggressive jamming)
3. **Add print statements** to see what's happening:
   ```matlab
   fprintf('Hopping to %.3f MHz\n', pattern.frequency/1e6);
   ```
4. **Study the logs**:
   ```matlab
   load('results/simulation_results.mat');
   results.satelliteLog(1)  % First transmission
   results.receiverLog(1)   % First reception
   ```

The code is designed to be modular and extensible - each component can be modified independently!
