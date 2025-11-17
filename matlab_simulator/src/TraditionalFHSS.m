classdef TraditionalFHSS < handle
    % TraditionalFHSS - Conventional FHSS using PRNG for pattern generation
    % For comparison with JIT-FHSS external entropy approach

    properties
        numFrequencies      % Number of available frequencies
        frequencyBand       % [min_freq, max_freq] in Hz
        prngSeed            % PRNG seed (deterministic)
        patternSequence     % Current sequence number
    end

    methods
        function obj = TraditionalFHSS(numFrequencies, frequencyBand, seed)
            % Constructor
            obj.numFrequencies = numFrequencies;
            obj.frequencyBand = frequencyBand;
            obj.prngSeed = seed;
            obj.patternSequence = 0;
        end

        function pattern = generatePattern(obj, ~)
            % Generate pattern using PRNG (timestamp ignored - deterministic)
            % This is how traditional FHSS works

            % Increment sequence
            obj.patternSequence = obj.patternSequence + 1;

            % Set PRNG state based on seed and sequence
            % This makes it DETERMINISTIC and PREDICTABLE
            rng(obj.prngSeed + obj.patternSequence - 1);

            % Generate frequency index
            freqIdx = randi(obj.numFrequencies);

            % Create pattern
            pattern = struct();
            pattern.frequency = obj.indexToFrequency(freqIdx);
            pattern.sequenceNumber = obj.patternSequence;
            pattern.sourceId = 0; % PRNG-based
            pattern.fromCache = false;
            pattern.timestamp = 0;
        end

        function freq = indexToFrequency(obj, idx)
            % Convert frequency index to actual frequency in Hz
            freqStep = (obj.frequencyBand(2) - obj.frequencyBand(1)) / obj.numFrequencies;
            freq = obj.frequencyBand(1) + (idx - 1) * freqStep;
        end

        function predictedFreq = predictPattern(obj, sequenceNum, knownSeed)
            % Adversary function: Predict future pattern given known seed
            % This demonstrates the vulnerability of PRNG-based FHSS

            % Set PRNG state (adversary knows the algorithm and seed)
            rng(knownSeed + sequenceNum - 1);

            % Predict the frequency
            freqIdx = randi(obj.numFrequencies);
            predictedFreq = obj.indexToFrequency(freqIdx);
        end
    end
end
