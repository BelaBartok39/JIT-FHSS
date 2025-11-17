%% Comparative Simulation: JIT-FHSS vs Traditional PRNG-FHSS
% Demonstrates security advantage of external entropy over PRNG
% Tests both systems against an intelligent adversary

clear; close all; clc;
addpath('src/');
rng('shuffle');

fprintf('=== JIT-FHSS vs Traditional FHSS Comparative Security Test ===\n\n');

%% Common Parameters
fprintf('Configuring simulation parameters...\n');

simDuration = 1000;         % Shorter simulation for comparison
timeStep = 0.1;
hopDuration = 1.0;
numFrequencies = 100;
frequencyBand = [2.0e9, 2.1e9];
altitude = 500;
groundStationLat = 0;
groundStationLon = 0;
bufferSize = 50;

% Jammer parameters
learningPeriod = 100;       % Jammer observes first 100 hops
jamBandwidth = 5;           % Can jam 5 adjacent frequencies

fprintf('  Simulation Duration: %d seconds\n', simDuration);
fprintf('  Adversary Learning Period: %d hops\n', learningPeriod);
fprintf('  Jammer Bandwidth: %d frequencies\n\n', jamBandwidth);

%% Scenario 1: JIT-FHSS (External Entropy) vs Intelligent Jammer
fprintf('========================================\n');
fprintf('SCENARIO 1: JIT-FHSS (External Entropy)\n');
fprintf('========================================\n\n');

% Initialize JIT-FHSS system
orbitModel1 = OrbitModel(altitude, 98, groundStationLat, groundStationLon);
centralSource = CentralSourceManager(3, numFrequencies, frequencyBand, 1000);
receiver_JIT = GroundReceiver(orbitModel1, bufferSize, hopDuration);

% Initialize jammer
jammer_JIT = IntelligentJammer(numFrequencies, frequencyBand, jamBandwidth);

% Pre-load patterns for JIT-FHSS
fprintf('Distributing patterns from central source...\n');
patterns_JIT = struct([]); % Initialize as empty struct array
for i = 1:200
    pattern = centralSource.generatePattern(0);
    if isempty(patterns_JIT)
        patterns_JIT = pattern;
    else
        patterns_JIT(end+1) = pattern;
    end
    receiver_JIT.patternBuffer.addPattern(pattern);
end

% Simulation loop
receiver_JIT.setTime(0);
successCount_JIT = 0;
jammedCount_JIT = 0;
totalHops = 0;

fprintf('Running simulation with intelligent jammer...\n');

for i = 1:simDuration
    currentTime = (i-1) * hopDuration;
    receiver_JIT.setTime(currentTime);

    % Check visibility (simplified - always visible for this test)
    visible = true;

    if visible
        totalHops = totalHops + 1;

        % Get current pattern
        if totalHops <= length(patterns_JIT)
            currentPattern = patterns_JIT(totalHops);
            currentFreq = currentPattern.frequency;

            % Jammer observes during learning period
            if totalHops <= learningPeriod
                jammer_JIT.observePattern(currentFreq, totalHops);

                % Attempt to learn seed after sufficient observations
                if totalHops == learningPeriod
                    fprintf('[JIT-FHSS] Jammer learning phase complete (%d observations)\n', learningPeriod);
                    success = jammer_JIT.learnPRNGSeed();
                    if ~success
                        fprintf('[JIT-FHSS] Jammer FAILED to learn pattern (external entropy!)\n');
                    end
                end
            else
                % Jammer attempts to predict and jam
                jammer_JIT.jamNextPattern(totalHops);

                % Check if current frequency is jammed
                isJammed = jammer_JIT.checkIfJammed(currentFreq);

                if isJammed
                    jammedCount_JIT = jammedCount_JIT + 1;
                else
                    successCount_JIT = successCount_JIT + 1;
                end
            end
        end
    end
end

% JIT-FHSS Results
jammerStats_JIT = jammer_JIT.getStatistics();
activeHops = totalHops - learningPeriod;

fprintf('\n=== JIT-FHSS Results ===\n');
fprintf('Total hops: %d\n', totalHops);
fprintf('Learning phase hops: %d\n', learningPeriod);
fprintf('Active jamming phase hops: %d\n', activeHops);
fprintf('Successful transmissions: %d\n', successCount_JIT);
fprintf('Jammed transmissions: %d\n', jammedCount_JIT);
fprintf('Success rate under attack: %.2f%%\n', (successCount_JIT/activeHops)*100);
fprintf('Jammer prediction accuracy: %.2f%%\n', jammerStats_JIT.predictionAccuracy*100);

%% Scenario 2: Traditional PRNG-FHSS vs Intelligent Jammer
fprintf('\n========================================\n');
fprintf('SCENARIO 2: Traditional PRNG-FHSS\n');
fprintf('========================================\n\n');

% Initialize traditional FHSS with PRNG
prngSeed = 12345;  % Fixed seed (realistic - often hardcoded in devices)
traditionalFHSS = TraditionalFHSS(numFrequencies, frequencyBand, prngSeed);

% Initialize jammer
jammer_PRNG = IntelligentJammer(numFrequencies, frequencyBand, jamBandwidth);

% Simulation loop
successCount_PRNG = 0;
jammedCount_PRNG = 0;
totalHops = 0;

fprintf('Running simulation with intelligent jammer...\n');

for i = 1:simDuration
    totalHops = totalHops + 1;

    % Generate pattern using PRNG
    pattern = traditionalFHSS.generatePattern(0);
    currentFreq = pattern.frequency;

    % Jammer observes during learning period
    if totalHops <= learningPeriod
        jammer_PRNG.observePattern(currentFreq, totalHops);

        % Attempt to learn seed after sufficient observations
        if totalHops == learningPeriod
            fprintf('[PRNG-FHSS] Jammer learning phase complete (%d observations)\n', learningPeriod);
            success = jammer_PRNG.learnPRNGSeed();
            if success
                fprintf('[PRNG-FHSS] Jammer SUCCESSFULLY learned PRNG seed!\n');
            else
                fprintf('[PRNG-FHSS] Jammer failed to learn seed\n');
            end
        end
    else
        % Jammer attempts to predict and jam
        jammer_PRNG.jamNextPattern(totalHops);

        % Check if current frequency is jammed
        isJammed = jammer_PRNG.checkIfJammed(currentFreq);

        if isJammed
            jammedCount_PRNG = jammedCount_PRNG + 1;
        else
            successCount_PRNG = successCount_PRNG + 1;
        end
    end
end

% PRNG-FHSS Results
jammerStats_PRNG = jammer_PRNG.getStatistics();
activeHops = totalHops - learningPeriod;

fprintf('\n=== Traditional PRNG-FHSS Results ===\n');
fprintf('Total hops: %d\n', totalHops);
fprintf('Learning phase hops: %d\n', learningPeriod);
fprintf('Active jamming phase hops: %d\n', activeHops);
fprintf('Successful transmissions: %d\n', successCount_PRNG);
fprintf('Jammed transmissions: %d\n', jammedCount_PRNG);
fprintf('Success rate under attack: %.2f%%\n', (successCount_PRNG/activeHops)*100);
fprintf('Jammer prediction accuracy: %.2f%%\n', jammerStats_PRNG.predictionAccuracy*100);

%% Comparison Summary
fprintf('\n========================================\n');
fprintf('COMPARATIVE RESULTS SUMMARY\n');
fprintf('========================================\n\n');

fprintf('Under Intelligent Jamming Attack:\n');
fprintf('  JIT-FHSS Success Rate:       %.2f%%\n', (successCount_JIT/activeHops)*100);
fprintf('  Traditional FHSS Success Rate: %.2f%%\n', (successCount_PRNG/activeHops)*100);
fprintf('\n');

improvement = ((successCount_JIT/activeHops) - (successCount_PRNG/activeHops)) * 100;
fprintf('  Security Improvement: %.2f percentage points\n', improvement);
fprintf('\n');

fprintf('Jammer Effectiveness:\n');
fprintf('  Against JIT-FHSS:       %.2f%% prediction accuracy\n', jammerStats_JIT.predictionAccuracy*100);
fprintf('  Against PRNG-FHSS:      %.2f%% prediction accuracy\n', jammerStats_PRNG.predictionAccuracy*100);
fprintf('\n');

fprintf('========================================\n');
fprintf('CONCLUSION:\n');
fprintf('========================================\n\n');

if improvement > 50
    fprintf('JIT-FHSS provides SIGNIFICANT security advantage over PRNG-based FHSS.\n');
    fprintf('External entropy makes pattern prediction infeasible for adversaries.\n');
    fprintf('PRNG-based FHSS is VULNERABLE to seed extraction and prediction attacks.\n');
elseif improvement > 20
    fprintf('JIT-FHSS provides MODERATE security advantage over PRNG-based FHSS.\n');
else
    fprintf('Both systems show similar performance under this attack scenario.\n');
end

fprintf('\nComparative simulation complete!\n');
