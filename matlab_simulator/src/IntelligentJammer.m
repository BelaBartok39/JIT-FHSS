classdef IntelligentJammer < handle
    % IntelligentJammer - Adversary that attempts to predict and jam FHSS patterns
    % Demonstrates vulnerability of PRNG-based FHSS vs security of JIT-FHSS

    properties
        numFrequencies          % Number of available frequencies
        frequencyBand           % [min_freq, max_freq] in Hz
        observedPatterns        % Patterns observed during learning phase
        learnedSeed             % PRNG seed learned from observation
        jammedFrequencies       % List of currently jammed frequencies
        jamBandwidth            % Number of simultaneous frequencies jammer can block
        successfulPredictions   % Count of correct predictions
        totalPredictions        % Total prediction attempts
        mode                    % 'learning' or 'jamming'
    end

    methods
        function obj = IntelligentJammer(numFrequencies, frequencyBand, jamBandwidth)
            % Constructor
            obj.numFrequencies = numFrequencies;
            obj.frequencyBand = frequencyBand;
            obj.jamBandwidth = jamBandwidth; % e.g., can jam 5 frequencies simultaneously
            obj.observedPatterns = [];
            obj.learnedSeed = [];
            obj.jammedFrequencies = [];
            obj.successfulPredictions = 0;
            obj.totalPredictions = 0;
            obj.mode = 'learning';
        end

        function observePattern(obj, frequency, sequenceNum)
            % Adversary observes a transmitted pattern
            % Collects data during learning phase

            pattern = struct();
            pattern.frequency = frequency;
            pattern.sequenceNumber = sequenceNum;
            pattern.freqIdx = obj.frequencyToIndex(frequency);

            obj.observedPatterns(end+1) = pattern;
        end

        function success = learnPRNGSeed(obj)
            % Attempt to reverse-engineer PRNG seed from observed patterns
            % This represents a realistic attack on PRNG-based FHSS

            success = false;

            if length(obj.observedPatterns) < 10
                % Need at least 10 observations
                return;
            end

            % Brute force search for seed (simplified - real attack more sophisticated)
            % Try seeds from 0 to 10000
            for testSeed = 0:10000
                match = true;

                % Check if this seed reproduces observed patterns
                for i = 1:min(10, length(obj.observedPatterns))
                    pattern = obj.observedPatterns(i);

                    % Predict what frequency this seed would generate
                    rng(testSeed + pattern.sequenceNumber - 1);
                    predictedIdx = randi(obj.numFrequencies);

                    if predictedIdx ~= pattern.freqIdx
                        match = false;
                        break;
                    end
                end

                if match
                    % Found the seed!
                    obj.learnedSeed = testSeed;
                    obj.mode = 'jamming';
                    success = true;
                    fprintf('[JAMMER] Learned PRNG seed: %d (from %d observations)\n', ...
                            testSeed, length(obj.observedPatterns));
                    return;
                end
            end
        end

        function jammedFreqs = jamNextPattern(obj, sequenceNum)
            % Predict next pattern and jam those frequencies
            % Returns list of jammed frequencies

            jammedFreqs = [];

            if strcmp(obj.mode, 'jamming') && ~isempty(obj.learnedSeed)
                % Predict the next frequency
                rng(obj.learnedSeed + sequenceNum - 1);
                predictedIdx = randi(obj.numFrequencies);
                predictedFreq = obj.indexToFrequency(predictedIdx);

                % Jam the predicted frequency and nearby channels
                jammedFreqs = obj.jamFrequencyBand(predictedFreq);

                obj.totalPredictions = obj.totalPredictions + 1;
            end

            obj.jammedFrequencies = jammedFreqs;
        end

        function jammedFreqs = jamFrequencyBand(obj, centerFreq)
            % Jam a band of frequencies centered on predicted frequency

            centerIdx = obj.frequencyToIndex(centerFreq);

            % Jam center frequency plus adjacent channels
            halfBand = floor(obj.jamBandwidth / 2);
            jammedFreqs = [];

            for offset = -halfBand:halfBand
                idx = centerIdx + offset;
                if idx >= 1 && idx <= obj.numFrequencies
                    jammedFreqs(end+1) = obj.indexToFrequency(idx);
                end
            end
        end

        function isJammed = checkIfJammed(obj, frequency)
            % Check if a given frequency is currently being jammed

            if isempty(obj.jammedFrequencies)
                isJammed = false;
                return;
            end

            % Check if frequency is in jammed list (with tolerance)
            tolerance = (obj.frequencyBand(2) - obj.frequencyBand(1)) / obj.numFrequencies / 2;
            isJammed = any(abs(obj.jammedFrequencies - frequency) < tolerance);

            if isJammed
                obj.successfulPredictions = obj.successfulPredictions + 1;
            end
        end

        function idx = frequencyToIndex(obj, freq)
            % Convert frequency to index
            freqStep = (obj.frequencyBand(2) - obj.frequencyBand(1)) / obj.numFrequencies;
            idx = round((freq - obj.frequencyBand(1)) / freqStep) + 1;
            idx = max(1, min(obj.numFrequencies, idx));
        end

        function freq = indexToFrequency(obj, idx)
            % Convert index to frequency
            freqStep = (obj.frequencyBand(2) - obj.frequencyBand(1)) / obj.numFrequencies;
            freq = obj.frequencyBand(1) + (idx - 1) * freqStep;
        end

        function stats = getStatistics(obj)
            % Get jammer performance statistics
            stats = struct();
            stats.mode = obj.mode;
            stats.observedPatterns = length(obj.observedPatterns);
            stats.learnedSeed = obj.learnedSeed;
            stats.successfulPredictions = obj.successfulPredictions;
            stats.totalPredictions = obj.totalPredictions;

            if obj.totalPredictions > 0
                stats.predictionAccuracy = obj.successfulPredictions / obj.totalPredictions;
            else
                stats.predictionAccuracy = 0;
            end
        end
    end
end
