# JIT-FHSS Simulator User Guide

## Overview

This MATLAB simulator implements a **Just-In-Time Frequency Hopping Spread Spectrum (JIT-FHSS)** communication system with:

- **External Central Source**: Distributes high-entropy frequency hopping patterns
- **Satellite Sender**: LEO satellite transmitting using FHSS
- **Ground Receiver**: Receives and decodes satellite transmissions
- **Redundancy & Failover**: Multiple central sources with automatic failover
- **Realistic Physics**: Orbital dynamics, Doppler effects, and propagation delays

## Quick Start

1. **Run the simulation**:
   ```matlab
   cd matlab_simulator
   run_simulation
   ```

2. **Analyze results**:
   ```matlab
   analyze_results
   ```

3. **View results**:
   - Plots: `results/jit_fhss_analysis.png`
   - Data: `results/simulation_results.mat`
   - Report: `results/simulation_report.txt`

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Central Source Manager                     │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌──────────────┐   │
│  │Source 1 │  │Source 2 │  │Source 3 │  │Fallback Cache│   │
│  │ (TRNG) │  │ (TRNG) │  │ (TRNG) │  │   (PRNG)     │   │
│  └────┬────┘  └────┬────┘  └────┬────┘  └──────┬───────┘   │
└───────┼────────────┼────────────┼───────────────┼───────────┘
        │            │            │               │
        │ Patterns   │ (Failover) │               │ (Last Resort)
        ▼            ▼            ▼               ▼
   ┌────────────┐                           ┌──────────────┐
   │  Satellite │◄──────────────────────────┤Ground Station│
   │   Sender   │      Data Transmission    │   Receiver   │
   │            │          (FHSS)           │              │
   │ - Orbit    ├──────────────────────────►│ - Tracking   │
   │ - Buffer   │   Doppler + Propagation   │ - Buffer     │
   │ - Hopping  │        Delay              │ - Decode     │
   └────────────┘                           └──────────────┘
```

## Key Concepts

### 1. Just-In-Time Pattern Distribution

**Traditional FHSS:**
- Uses pseudo-random number generator (PRNG) with pre-shared seed
- Limited entropy (patterns repeat)
- Vulnerable if seed is compromised

**JIT-FHSS:**
- Central source generates patterns using high-entropy source (TRNG simulation)
- Patterns distributed just-in-time to sender and receiver
- No predetermined pattern - cannot be predicted
- Higher security, greater entropy

### 2. Orbital Latency

**What is it?**
Orbital latency is the signal propagation delay between satellite and ground station.

**Key factors:**
- **Distance**: LEO satellites at 500 km altitude are about 500-2000 km from ground station
- **Speed of light**: Signals travel at ~300,000 km/s
- **Typical delays**: 1.7 ms (minimum) to 7 ms (maximum) for LEO

**Impact on JIT-FHSS:**
- Patterns must be buffered to account for transmission delay
- Sender and receiver need synchronized pattern buffers
- Pattern requests must be made ahead of time

**Simulator implementation:**
```matlab
% Calculate one-way propagation delay
range_km = 1500; % Distance to satellite
delay = (range_km * 1000) / (3e8); % ~5 ms
```

### 3. Doppler Effect

**What is it?**
When satellite and ground station move relative to each other, transmitted frequencies appear shifted.

**The physics:**
- **Approaching**: Frequency increases (blue shift)
- **Receding**: Frequency decreases (red shift)
- **Formula**: `f_received = f_transmitted × (1 + v_r/c)`
  - `v_r` = radial velocity (range rate)
  - `c` = speed of light

**Example:**
```
Satellite orbital velocity: 7.6 km/s
Radial velocity: ~4 km/s (maximum)
Carrier frequency: 2 GHz
Doppler shift: ±27 kHz
```

**Impact on FHSS:**
- Receiver must know which frequency to listen to
- Doppler shift can be larger than frequency hop spacing
- Must compensate using satellite position/velocity

**Simulator implementation:**
```matlab
% Transmit at 2.05 GHz
tx_freq = 2.05e9;
range_rate = 4.2; % km/s (approaching)

% Apply Doppler shift
doppler_shift = tx_freq * (range_rate * 1000) / 3e8;
rx_freq = tx_freq + doppler_shift; % 2050028000 Hz (+28 kHz)

% Receiver compensates
compensated_freq = rx_freq - doppler_shift; % Back to 2.05 GHz
```

### 4. Synchronization & Buffering

**Challenge:**
Sender and receiver must hop to same frequency at same time, despite:
- Propagation delays
- Pattern distribution latency
- Clock offsets

**Solution:**
- **Pattern sequence numbers**: Order patterns explicitly
- **Pre-buffering**: Load multiple patterns ahead of time
- **Minimum buffer threshold**: Request more patterns when running low
- **Clock synchronization**: Account for time offsets

**Buffer management:**
```matlab
bufferSize = 50;          % Hold 50 patterns
hopDuration = 1.0;        % 1 second per hop
bufferThreshold = 10;     % Request more when <10 remain

% This provides 50 seconds of operation before needing new patterns
```

### 5. Redundancy & Failover

**Multiple Central Sources:**
- Simulate 3 independent central sources
- If one is jammed or fails, automatically switch to next
- Transparent to sender/receiver

**Fallback Cache:**
- Last resort if all central sources fail
- Uses PRNG-generated patterns (lower entropy)
- Maintains communication during severe interference

**Jamming scenario in simulator:**
```matlab
% At t=400s, jam primary source
centralSource.jamSource(1);
% System automatically fails over to Source 2

% At t=600s, restore
centralSource.restoreSource(1);
```

## Simulation Parameters

### Time Parameters
```matlab
simDuration = 1000;      % Total simulation time (seconds)
timeStep = 0.1;          % Simulation time step (seconds)
hopDuration = 1.0;       % Time per frequency hop (seconds)
```

### Frequency Parameters
```matlab
numFrequencies = 100;              % Number of available channels
frequencyBand = [2.0e9, 2.1e9];   % 2.0-2.1 GHz (S-band)
```

### Orbital Parameters
```matlab
altitude = 500;              % Satellite altitude (km) - LEO
inclination = 45;            % Orbital inclination (degrees)
groundStationLat = 37.4;     % Ground station latitude
groundStationLon = -122.1;   % Ground station longitude
```

### System Parameters
```matlab
numCentralSources = 3;       % Redundant sources
cacheSize = 1000;            % Fallback cache size
bufferSize = 50;             % Pattern buffer size
```

## Understanding the Results

### Plots Generated

1. **Frequency Hopping Pattern**
   - Shows frequency vs time
   - Should appear random (high entropy)
   - Uses full frequency band

2. **Doppler Shift**
   - Shows how Doppler varies over orbit
   - Maximum when satellite passes overhead
   - Zero when satellite is at horizon

3. **Satellite Range**
   - Distance from satellite to ground station
   - Minimum at closest approach
   - Affects propagation delay

4. **Range Rate (Radial Velocity)**
   - Rate of change of distance
   - Negative = approaching, Positive = receding
   - Zero at closest approach (overhead pass)
   - Determines Doppler shift

5. **Reception Success**
   - Shows successful vs failed receptions
   - Should be nearly 100% success
   - Failures indicate synchronization issues

6. **Frequency Error**
   - Error after Doppler compensation
   - Should be small (< 1 kHz)
   - Large errors cause reception failures

### Metrics

**Success Rate**: Percentage of correctly received transmissions
- Target: >99%
- Lower values indicate sync problems or buffer issues

**Doppler Shift Range**: Maximum frequency shift due to motion
- Typical: ±20-30 kHz at 2 GHz for LEO
- Must be compensated at receiver

**Frequency Utilization**: Percentage of available frequencies used
- High values indicate good entropy
- Low values might indicate pattern issues

## Customization

### Change Orbital Parameters

```matlab
% Higher altitude satellite (longer orbital period)
altitude = 1000;  % km

% Polar orbit
inclination = 90;  % degrees

% Different ground station
groundStationLat = 0;    % Equator
groundStationLon = 0;    % Prime meridian
```

### Adjust FHSS Parameters

```matlab
% More frequencies (higher entropy, but narrower channels)
numFrequencies = 200;

% Faster hopping (more challenging synchronization)
hopDuration = 0.5;  % 2 hops per second

% Larger buffer (more resilience to source interruptions)
bufferSize = 100;
```

### Test Different Scenarios

```matlab
% Enable/disable jamming
jamCentralSource = true;
jamStartTime = 400;      % When jamming starts (seconds)
jamDuration = 200;       % How long jamming lasts (seconds)

% Jam multiple sources
centralSource.jamSource(1);
centralSource.jamSource(2);
% Now only Source 3 is available

% High interference environment
centralSource.setJamProbability(0.01);  % 1% chance per time step
```

## Troubleshooting

### Low Success Rate (<90%)

**Possible causes:**
1. Buffer size too small - increase `bufferSize`
2. Hop duration too short - increase `hopDuration`
3. Too many sources jammed - reduce jamming

### "Buffer empty" warnings

**Solution:**
- Increase `bufferSize`
- Reduce `hopDuration`
- Request patterns more frequently

### Unrealistic Doppler shifts

**Check:**
- Orbital velocity should be 7-8 km/s for LEO
- Range rate should be less than orbital velocity
- Doppler at 2 GHz should be ±30 kHz max

## Advanced Topics

### Adding Noise/Interference

Modify `GroundReceiver.m` to add channel noise:

```matlab
% In receive() method
SNR_dB = 10;  % Signal-to-noise ratio
noise = randn() * 10^(-SNR_dB/20);
receivedFreq = receivedFreq + noise;
```

### Multiple Satellites

Create multiple `SatelliteSender` instances with different orbits:

```matlab
orbit1 = OrbitModel(500, 45, groundLat, groundLon);
orbit2 = OrbitModel(600, 60, groundLat, groundLon);
sat1 = SatelliteSender(orbit1, bufferSize, hopDuration);
sat2 = SatelliteSender(orbit2, bufferSize, hopDuration);
```

### Real-time Visualization

Add live plotting in main simulation loop:

```matlab
figure;
for i = 1:numTimeSteps
    % ... simulation code ...

    % Update plot
    plot(satellite.transmitLog(end).time, ...
         satellite.transmitLog(end).transmitFreq, 'b.');
    drawnow;
end
```

## References

- Frequency Hopping Spread Spectrum (FHSS): IEEE 802.11
- Doppler Effect in Satellite Communications: ITU-R recommendations
- LEO Satellite Dynamics: Fundamentals of Astrodynamics (Bate, Mueller, White)

## Support

For questions or issues with the simulator:
1. Check this user guide
2. Review code comments in `src/` directory
3. Examine example results in `results/` directory
