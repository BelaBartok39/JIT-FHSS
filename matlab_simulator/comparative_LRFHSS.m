%% LR-FHSS Comparative Security Test: PRNG vs External Entropy
% Tests Long Range FHSS (LoRaWAN satellite standard)
% with both traditional PRNG and JIT-FHSS external entropy

clear; close all; clc;
addpath('src/');
rng('shuffle');

fprintf('=== LR-FHSS Security Comparison: PRNG vs External Entropy ===\n\n');

%% LR-FHSS Parameters
fprintf('Configuring LR-FHSS parameters (LoRaWAN satellite standard)...\n');

% LR-FHSS specific parameters
baseFrequency = 2.0e9;      % 2 GHz S-band
lrBandwidth = 137e3;        % 137 kHz per LoRaWAN spec
numChannels = 8;            % 8-channel grid (typical)

% Simulation parameters
simDuration = 1000;
learningPeriod = 100;
jamBandwidth = 2;           % Jammer can jam 2 adjacent channels

% PRNG seed for traditional approach
prngSeed = 54321;

fprintf('  Base Frequency: %.1f MHz\n', baseFrequency/1e6);
fprintf('  Channel Bandwidth: %.1f kHz (LR-FHSS)\n', lrBandwidth/1e3);
fprintf('  Number of Channels: %d\n', numChannels);
fprintf('  Jammer Bandwidth: %d channels\n\n', jamBandwidth);

%% Create LR-FHSS Modulator
lrfhss = LRFHSS_Modulator(baseFrequency, lrBandwidth, numChannels);
stats = lrfhss.getModulationStats();

fprintf('LR-FHSS Modulation Characteristics:\n');
fprintf('  Spreading Factor: %d\n', stats.spreadingFactor);
fprintf('  Processing Gain: %.1f dB\n', stats.processingGain_dB);
fprintf('  Coding Gain: %.1f dB (FEC)\n', stats.codingGain_dB);
fprintf('  Total Gain: %.1f dB\n', stats.totalGain_dB);
fprintf('  SNR Threshold: %.1f dB (effective: %.1f dB raw)\n\n', ...
        stats.snrThreshold_dB, stats.effectiveThreshold_dB);

%% SCENARIO 1: LR-FHSS with PRNG (Traditional - VULNERABLE)
fprintf('========================================\n');
fprintf('SCENARIO 1: LR-FHSS with PRNG\n');
fprintf('========================================\n\n');

% Initialize jammer
jammer_PRNG = IntelligentJammer(numChannels, [1, numChannels], jamBandwidth);

% Storage for observations
transmitted_PRNG = struct([]);
successCount_PRNG = 0;
jammedCount_PRNG = 0;

fprintf('Running LR-FHSS with PRNG-based channel hopping...\n');

for hop = 1:simDuration
    % PRNG-based channel selection (DETERMINISTIC)
    channelIdx = lrfhss.selectChannel_PRNG(hop, prngSeed);

    % Get frequency for this channel
    frequency = lrfhss.hoppingGrid(channelIdx);

    % Store transmission
    tx = struct();
    tx.hop = hop;
    tx.channelIdx = channelIdx;
    tx.frequency = frequency;

    if isempty(transmitted_PRNG)
        transmitted_PRNG = tx;
    else
        transmitted_PRNG(end+1) = tx;
    end

    % Jammer observes during learning period
    if hop <= learningPeriod
        % Jammer observes which channel (not frequency, but channel index)
        jammer_PRNG.observePattern(channelIdx, hop);

        if hop == learningPeriod
            fprintf('[LR-FHSS PRNG] Jammer learning phase complete (%d observations)\n', learningPeriod);
            % Try to learn the PRNG seed
            success = jammer_PRNG.learnPRNGSeed();
            if success
                fprintf('[LR-FHSS PRNG] Jammer SUCCESSFULLY learned seed!\n');
            else
                fprintf('[LR-FHSS PRNG] Jammer failed to learn seed\n');
            end
        end
    else
        % Jammer attempts prediction
        jammer_PRNG.jamNextPattern(hop);

        % Check if jammed (channel-based, not frequency-based)
        isJammed = jammer_PRNG.checkIfJammed(channelIdx);

        if isJammed
            jammedCount_PRNG = jammedCount_PRNG + 1;
        else
            successCount_PRNG = successCount_PRNG + 1;
        end
    end
end

jammerStats_PRNG = jammer_PRNG.getStatistics();
activeHops_PRNG = simDuration - learningPeriod;

fprintf('\n=== LR-FHSS with PRNG Results ===\n');
fprintf('Total hops: %d\n', simDuration);
fprintf('Learning phase: %d hops\n', learningPeriod);
fprintf('Active jamming: %d hops\n', activeHops_PRNG);
fprintf('Successful transmissions: %d\n', successCount_PRNG);
fprintf('Jammed transmissions: %d\n', jammedCount_PRNG);
fprintf('Success rate: %.2f%%\n', (successCount_PRNG/activeHops_PRNG)*100);
fprintf('Jammer prediction accuracy: %.2f%%\n\n', jammerStats_PRNG.predictionAccuracy*100);

%% SCENARIO 2: LR-FHSS with External Entropy (JIT-FHSS - SECURE)
fprintf('========================================\n');
fprintf('SCENARIO 2: LR-FHSS with External Entropy\n');
fprintf('========================================\n\n');

% Initialize external entropy source (simulating TRNG)
centralSource = CentralSourceManager(3, 100, [baseFrequency, baseFrequency + lrBandwidth*numChannels], 1000);

% Initialize jammer
jammer_External = IntelligentJammer(numChannels, [1, numChannels], jamBandwidth);

% Storage
transmitted_External = struct([]);
successCount_External = 0;
jammedCount_External = 0;

fprintf('Running LR-FHSS with external entropy channel hopping...\n');

for hop = 1:simDuration
    % Generate external entropy (TRNG simulation)
    entropyPattern = centralSource.generatePattern(0);
    % Extract random value and map to channel
    externalEntropy = round(entropyPattern.frequency / 1e6); % Use frequency as entropy source

    % External entropy-based channel selection (NON-DETERMINISTIC)
    channelIdx = lrfhss.selectChannel_External(externalEntropy);

    % Get frequency for this channel
    frequency = lrfhss.hoppingGrid(channelIdx);

    % Store transmission
    tx = struct();
    tx.hop = hop;
    tx.channelIdx = channelIdx;
    tx.frequency = frequency;

    if isempty(transmitted_External)
        transmitted_External = tx;
    else
        transmitted_External(end+1) = tx;
    end

    % Jammer observes during learning period
    if hop <= learningPeriod
        jammer_External.observePattern(channelIdx, hop);

        if hop == learningPeriod
            fprintf('[LR-FHSS External] Jammer learning phase complete (%d observations)\n', learningPeriod);
            success = jammer_External.learnPRNGSeed();
            if ~success
                fprintf('[LR-FHSS External] Jammer FAILED to learn pattern (external entropy!)\n');
            else
                fprintf('[LR-FHSS External] Jammer found pattern (unexpected!)\n');
            end
        end
    else
        % Jammer attempts prediction
        jammer_External.jamNextPattern(hop);

        % Check if jammed
        isJammed = jammer_External.checkIfJammed(channelIdx);

        if isJammed
            jammedCount_External = jammedCount_External + 1;
        else
            successCount_External = successCount_External + 1;
        end
    end
end

jammerStats_External = jammer_External.getStatistics();
activeHops_External = simDuration - learningPeriod;

fprintf('\n=== LR-FHSS with External Entropy Results ===\n');
fprintf('Total hops: %d\n', simDuration);
fprintf('Learning phase: %d hops\n', learningPeriod);
fprintf('Active jamming: %d hops\n', activeHops_External);
fprintf('Successful transmissions: %d\n', successCount_External);
fprintf('Jammed transmissions: %d\n', jammedCount_External);
fprintf('Success rate: %.2f%%\n', (successCount_External/activeHops_External)*100);
fprintf('Jammer prediction accuracy: %.2f%%\n\n', jammerStats_External.predictionAccuracy*100);

%% Comparative Analysis
fprintf('========================================\n');
fprintf('LR-FHSS COMPARATIVE RESULTS\n');
fprintf('========================================\n\n');

fprintf('Success Rate Under Jamming Attack:\n');
fprintf('  LR-FHSS + PRNG:            %.2f%%\n', (successCount_PRNG/activeHops_PRNG)*100);
fprintf('  LR-FHSS + External Entropy: %.2f%%\n', (successCount_External/activeHops_External)*100);
fprintf('\n');

improvement = ((successCount_External/activeHops_External) - (successCount_PRNG/activeHops_PRNG)) * 100;
fprintf('  Security Improvement: %.2f percentage points\n\n', improvement);

fprintf('Jammer Prediction Accuracy:\n');
fprintf('  Against PRNG:          %.2f%% (seed extraction successful)\n', jammerStats_PRNG.predictionAccuracy*100);
fprintf('  Against External Entropy: %.2f%% (random chance only)\n\n', jammerStats_External.predictionAccuracy*100);

fprintf('========================================\n');
fprintf('CONCLUSION\n');
fprintf('========================================\n\n');

if improvement > 50
    fprintf('✓ LR-FHSS with EXTERNAL ENTROPY provides SIGNIFICANT security advantage.\n');
    fprintf('✓ Advanced modulation (CSS) does NOT protect against PRNG prediction.\n');
    fprintf('✓ External entropy is ESSENTIAL even with modern LR-FHSS.\n');
    fprintf('✗ LR-FHSS with PRNG remains VULNERABLE to intelligent jamming.\n\n');

    fprintf('Key Insight:\n');
    fprintf('  LR-FHSS improves SNR performance (%.1f dB gain from CSS+FEC)\n', stats.totalGain_dB);
    fprintf('  BUT does NOT solve the pattern prediction vulnerability!\n');
    fprintf('  Only external entropy (JIT-FHSS) prevents prediction attacks.\n');
else
    fprintf('Both approaches show similar performance under this attack scenario.\n');
end

fprintf('\nLR-FHSS comparative simulation complete!\n');
