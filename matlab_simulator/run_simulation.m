%% JIT-FHSS Simulation - Main Script
% Simulates Just-In-Time Frequency Hopping Spread Spectrum
% with external central source, satellite sender, and ground receiver

clear; close all; clc;

% Add source directory to path
addpath('src/');

fprintf('=== JIT-FHSS Simulation ===\n\n');

%% Simulation Parameters
fprintf('Configuring simulation parameters...\n');

% Time parameters
simDuration = 1000;         % Total simulation duration in seconds
timeStep = 0.1;             % Time step in seconds
hopDuration = 1.0;          % Frequency hop duration in seconds
timeVector = 0:timeStep:simDuration;

% Frequency parameters
numFrequencies = 100;       % Number of available frequencies
frequencyBand = [2.0e9, 2.1e9]; % 2.0-2.1 GHz (S-band)
centerFreq = mean(frequencyBand);

% Orbital parameters
altitude = 500;             % Satellite altitude in km (LEO)
inclination = 45;           % Orbital inclination in degrees
groundStationLat = 37.4;    % Ground station latitude (e.g., California)
groundStationLon = -122.1;  % Ground station longitude

% Central source parameters
numCentralSources = 3;      % Number of redundant central sources
cacheSize = 1000;           % Fallback cache size
bufferSize = 50;            % Pattern buffer size

% Simulation scenarios
jamCentralSource = true;    % Enable jamming scenario
jamStartTime = 400;         % When to start jamming
jamDuration = 200;          % How long jamming lasts

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

%% Pre-load Pattern Buffers
fprintf('Pre-loading pattern buffers...\n');
satellite.requestPatterns(centralSource, bufferSize);
receiver.requestPatterns(centralSource, bufferSize);
fprintf('  Satellite buffer: %d patterns\n', satellite.patternBuffer.getBufferLevel());
fprintf('  Receiver buffer: %d patterns\n', receiver.patternBuffer.getBufferLevel());
fprintf('\n');

%% Run Simulation
fprintf('Running simulation...\n');
fprintf('Progress: ');

numTimeSteps = length(timeVector);
progressUpdate = floor(numTimeSteps / 20);

% Metrics tracking
successfulTransmissions = 0;
totalTransmissions = 0;
cacheUsageCount = 0;
sourceFailovers = 0;

for i = 1:numTimeSteps
    currentTime = timeVector(i);

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
    if mod(i, 10) == 0
        if satellite.patternBuffer.getBufferLevel() < bufferSize * 0.3
            satellite.requestPatterns(centralSource, 10);
        end
        if receiver.patternBuffer.getBufferLevel() < bufferSize * 0.3
            receiver.requestPatterns(centralSource, 10);
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
if totalTransmissions > 0
    successRate = (successfulTransmissions / totalTransmissions) * 100;
    fprintf('  Success Rate: %.2f%%\n', successRate);
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
