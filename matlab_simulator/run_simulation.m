%% JIT-FHSS Simulation - Main Script
% Simulates Just-In-Time Frequency Hopping Spread Spectrum
% with external central source, satellite sender, and ground receiver

clear; close all; clc;

% Add source directory to path
addpath('src/');

% Initialize random number generator with time-based seed
% This ensures each simulation run produces different results
rng('shuffle');

fprintf('=== JIT-FHSS Simulation ===\n\n');

%% Simulation Parameters
fprintf('Configuring simulation parameters...\n');

% Time parameters
simDuration = 6000;         % Total simulation duration in seconds (full orbit)
timeStep = 0.1;             % Time step in seconds
hopDuration = 1.0;          % Frequency hop duration in seconds
timeVector = 0:timeStep:simDuration;

% Frequency parameters
numFrequencies = 100;       % Number of available frequencies
frequencyBand = [2.0e9, 2.1e9]; % 2.0-2.1 GHz (S-band)
centerFreq = mean(frequencyBand);

% Orbital parameters
altitude = 500;             % Satellite altitude in km (LEO)
inclination = 98;           % Orbital inclination in degrees (sun-synchronous polar orbit)
groundStationLat = 0;       % Ground station latitude (equator - guaranteed visibility)
groundStationLon = 0;       % Ground station longitude (prime meridian)

% Central source parameters
numCentralSources = 3;      % Number of redundant central sources
cacheSize = 1000;           % Fallback cache size
bufferSize = 50;            % Pattern buffer size

% Simulation scenarios
jamCentralSource = true;    % Enable jamming scenario
jamStartTime = 2400;        % When to start jamming (40% through simulation)
jamDuration = 1200;         % How long jamming lasts (20% of simulation)

fprintf('  Simulation Duration: %d seconds\n', simDuration);
fprintf('  Frequency Band: %.1f - %.1f MHz\n', frequencyBand(1)/1e6, frequencyBand(2)/1e6);
fprintf('  Satellite Altitude: %d km\n', altitude);
fprintf('  Central Sources: %d (with redundancy)\n', numCentralSources);
fprintf('\n');

%% Initialize Components
fprintf('Initializing simulation components...\n');

% Central source manager
centralSource = CentralSourceManager(numCentralSources, numFrequencies, ...
                                     frequencyBand, cacheSize);

% Orbital model
orbitModel = OrbitModel(altitude, inclination, groundStationLat, groundStationLon);
fprintf('  Orbital Period: %.1f minutes\n', orbitModel.orbitalPeriod/60);
fprintf('  Orbital Velocity: %.2f km/s\n', orbitModel.getOrbitalVelocity());

% Satellite sender
satellite = SatelliteSender(orbitModel, bufferSize, hopDuration);

% Ground receiver (shares same orbital model for tracking)
receiver = GroundReceiver(orbitModel, bufferSize, hopDuration);

% Doppler model for analysis
dopplerModel = DopplerModel();

fprintf('\n');

%% Find Visibility Window
fprintf('Finding satellite visibility window...\n');
timeOffset = 0;
maxSearchTime = orbitModel.orbitalPeriod * 2; % Search up to 2 orbits
found = false;

for t_search = 0:10:maxSearchTime
    [range, ~] = orbitModel.getRangeToGroundStation(t_search);
    elevation = orbitModel.getElevationAngle(t_search);
    if orbitModel.isVisible(t_search, 5) % 5 degree minimum elevation
        timeOffset = t_search;
        found = true;
        fprintf('  First visibility at t=%.1f s\n', t_search);
        fprintf('  Range: %.1f km, Elevation: %.1f degrees\n', range, elevation);
        break;
    end
end

if ~found
    warning('No visibility window found! Check orbital parameters and ground station location.');
    fprintf('  Continuing simulation anyway (may have no transmissions)...\n');
end

fprintf('\n');

%% Pre-load Pattern Buffers
fprintf('Pre-loading pattern buffers...\n');
% Generate patterns once and give SAME patterns to both sender and receiver
for i = 1:bufferSize
    pattern = centralSource.generatePattern(0);  % Initial time = 0
    satellite.patternBuffer.addPattern(pattern);
    receiver.patternBuffer.addPattern(pattern);
end
fprintf('  Satellite buffer: %d patterns\n', satellite.patternBuffer.getBufferLevel());
fprintf('  Receiver buffer: %d patterns\n', receiver.patternBuffer.getBufferLevel());
fprintf('\n');

%% Run Simulation
fprintf('Running simulation...\n');
fprintf('Starting from time offset: %.1f seconds\n', timeOffset);
fprintf('Progress: ');

numTimeSteps = length(timeVector);
progressUpdate = floor(numTimeSteps / 20);

% Metrics tracking
successfulTransmissions = 0;
totalTransmissions = 0;
cacheUsageCount = 0;
sourceFailovers = 0;

for i = 1:numTimeSteps
    currentTime = timeVector(i) + timeOffset; % Apply time offset for visibility

    % Update time for all components
    satellite.setTime(currentTime);
    receiver.setTime(currentTime);

    % Implement jamming scenario
    if jamCentralSource && currentTime >= jamStartTime && currentTime < (jamStartTime + jamDuration)
        if currentTime == jamStartTime
            fprintf('\n[!] JAMMING EVENT: Central Source 1 jammed at t=%.1fs\n', currentTime);
            centralSource.jamSource(1);
            sourceFailovers = sourceFailovers + 1;
        end
    elseif jamCentralSource && currentTime >= (jamStartTime + jamDuration)
        if currentTime == (jamStartTime + jamDuration)
            fprintf('[*] Central Source 1 restored at t=%.1fs\n', currentTime);
            centralSource.restoreSource(1);
        end
    end

    % Periodically request new patterns if buffer is low
    % IMPORTANT: Both sender and receiver must get THE SAME patterns for sync
    if mod(i, 10) == 0
        needPatterns = (satellite.patternBuffer.getBufferLevel() < bufferSize * 0.3) || ...
                      (receiver.patternBuffer.getBufferLevel() < bufferSize * 0.3);

        if needPatterns
            % Generate patterns once and distribute to both
            numNewPatterns = 10;
            for j = 1:numNewPatterns
                pattern = centralSource.generatePattern(currentTime);

                % Add same pattern to both buffers
                satellite.patternBuffer.addPattern(pattern);
                receiver.patternBuffer.addPattern(pattern);
            end
        end
    end

    % Check if satellite is visible to ground station
    if orbitModel.isVisible(currentTime, 5) % 5 degree minimum elevation
        % Transmit data symbol
        dataSymbol = randi([0, 255]); % Random data byte
        satellite.transmit(dataSymbol);

        % Get transmitted signal parameters
        [range, rangeRate] = orbitModel.getRangeToGroundStation(currentTime);

        if ~isempty(satellite.transmitLog)
            lastTransmit = satellite.transmitLog(end);

            % Receiver attempts to decode
            transmittedSignal = struct();
            transmittedSignal.receivedFreq = lastTransmit.receivedFreq;
            transmittedSignal.dataSymbol = dataSymbol;
            transmittedSignal.range = range;
            transmittedSignal.rangeRate = rangeRate;

            [success, ~] = receiver.receive(transmittedSignal);

            if success
                successfulTransmissions = successfulTransmissions + 1;
            end
            totalTransmissions = totalTransmissions + 1;
        end
    end

    % Progress indicator
    if mod(i, progressUpdate) == 0
        fprintf('.');
    end
end

fprintf(' Done!\n\n');

%% Collect Results
fprintf('=== Simulation Results ===\n\n');

% Overall statistics
fprintf('Performance Metrics:\n');
fprintf('  Total Transmissions: %d\n', totalTransmissions);
fprintf('  Successful Receptions: %d\n', successfulTransmissions);
successRate = 0; % Initialize
if totalTransmissions > 0
    successRate = (successfulTransmissions / totalTransmissions) * 100;
    fprintf('  Success Rate: %.2f%%\n', successRate);
else
    fprintf('  Success Rate: N/A (no transmissions - satellite not visible)\n');
end
fprintf('\n');

% Analyze failure reasons from new models
receiverLog = receiver.getReceiveLog();
if ~isempty(receiverLog)
    fprintf('Failure Analysis (New Models):\n');

    % Count failures by reason
    lowSNR = sum(strcmp({receiverLog.failureReason}, 'Low SNR'));
    clockDrift = sum(strcmp({receiverLog.failureReason}, 'Clock drift'));
    freqMismatch = sum(strcmp({receiverLog.failureReason}, 'Freq mismatch'));

    fprintf('  Low SNR failures: %d\n', lowSNR);
    fprintf('  Clock drift failures: %d\n', clockDrift);
    fprintf('  Frequency mismatch failures: %d\n', freqMismatch);

    % SNR statistics
    snrValues = [receiverLog.snr_dB];
    fprintf('  SNR range: %.2f to %.2f dB (mean: %.2f dB)\n', ...
            min(snrValues), max(snrValues), mean(snrValues));

    % Clock error statistics
    clockErrors = [receiverLog.clockError];
    fprintf('  Clock error range: %.3e to %.3e s\n', ...
            min(abs(clockErrors)), max(abs(clockErrors)));
end
fprintf('\n');

% Central source statistics
sourceStatus = centralSource.getStatus();
fprintf('Central Source Statistics:\n');
fprintf('  Active Sources: %d/%d\n', sourceStatus.activeSources, numCentralSources);
fprintf('  Total Patterns Generated: %d\n', sourceStatus.sequenceNumber);
fprintf('  Source Failovers: %d\n', sourceFailovers);
fprintf('\n');

% Satellite statistics
satStatus = satellite.getStatus();
fprintf('Satellite Statistics:\n');
fprintf('  Final Position Range: %.1f km\n', satStatus.range);
fprintf('  Final Range Rate: %.3f km/s\n', satStatus.rangeRate);
fprintf('  Transmissions Logged: %d\n', length(satellite.transmitLog));
fprintf('\n');

% Receiver statistics
recvStatus = receiver.getStatus();
fprintf('Receiver Statistics:\n');
fprintf('  Receptions Logged: %d\n', length(receiver.receiveLog));
fprintf('  Sync Errors: %d\n', recvStatus.syncErrors);
fprintf('  Final Success Rate: %.2f%%\n', receiver.getSuccessRate() * 100);
fprintf('\n');

%% Save Results
fprintf('Saving results...\n');

% Ensure results directory exists
if ~exist('results', 'dir')
    mkdir('results');
end

results = struct();
results.parameters = struct('simDuration', simDuration, ...
                            'timeStep', timeStep, ...
                            'hopDuration', hopDuration, ...
                            'numFrequencies', numFrequencies, ...
                            'frequencyBand', frequencyBand, ...
                            'altitude', altitude, ...
                            'numCentralSources', numCentralSources);
results.satelliteLog = satellite.getTransmitLog();
results.receiverLog = receiver.getReceiveLog();
results.successRate = successRate;
results.totalTransmissions = totalTransmissions;
results.successfulTransmissions = successfulTransmissions;

save('results/simulation_results.mat', 'results');
fprintf('Results saved to: results/simulation_results.mat\n\n');

fprintf('=== Simulation Complete ===\n');
fprintf('Run analyze_results.m to generate plots and detailed analysis.\n');
