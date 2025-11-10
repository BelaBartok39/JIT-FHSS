classdef CentralSourceManager < handle
    % CentralSourceManager - Manages multiple redundant central sources for JIT-FHSS
    % Provides high-entropy frequency hopping patterns with failover capability

    properties
        numSources          % Number of redundant central sources
        sourcesActive       % Array indicating which sources are active
        currentSourceIdx    % Index of currently active source
        patternCache        % Fallback cache of predetermined patterns
        cacheSize           % Size of fallback cache
        numFrequencies      % Number of available frequencies
        frequencyBand       % [min_freq, max_freq] in Hz
        patternSequence     % Sequence number for ordering
        jammed              % Boolean array indicating jammed sources
        jamProbability      % Probability of source jamming per time step
    end

    methods
        function obj = CentralSourceManager(numSources, numFrequencies, frequencyBand, cacheSize)
            % Constructor
            obj.numSources = numSources;
            obj.numFrequencies = numFrequencies;
            obj.frequencyBand = frequencyBand;
            obj.cacheSize = cacheSize;
            obj.sourcesActive = true(numSources, 1);
            obj.currentSourceIdx = 1;
            obj.patternSequence = 0;
            obj.jammed = false(numSources, 1);
            obj.jamProbability = 0.001; % Default 0.1% chance per time step

            % Initialize fallback cache with predetermined patterns
            obj.initializeFallbackCache();
        end

        function initializeFallbackCache(obj)
            % Initialize fallback cache with PRNG-based patterns
            rng(12345); % Fixed seed for reproducible fallback
            obj.patternCache = struct();
            obj.patternCache.frequencies = zeros(obj.cacheSize, 1);
            obj.patternCache.timestamps = zeros(obj.cacheSize, 1);
            obj.patternCache.sequenceNumbers = (1:obj.cacheSize)';

            % Generate predetermined frequency pattern
            freqIndices = randi(obj.numFrequencies, obj.cacheSize, 1);
            obj.patternCache.frequencies = obj.indexToFrequency(freqIndices);
        end

        function freq = indexToFrequency(obj, idx)
            % Convert frequency index to actual frequency in Hz
            freqStep = (obj.frequencyBand(2) - obj.frequencyBand(1)) / obj.numFrequencies;
            freq = obj.frequencyBand(1) + (idx - 1) * freqStep;
        end

        function pattern = generatePattern(obj, timestamp)
            % Generate high-entropy frequency hopping pattern
            % Try current source first, failover if necessary

            pattern = struct();

            % Check for jamming (random interference)
            obj.updateJammingStatus();

            % Find active source
            sourceFound = false;
            attempts = 0;

            while ~sourceFound && attempts < obj.numSources
                if obj.sourcesActive(obj.currentSourceIdx) && ~obj.jammed(obj.currentSourceIdx)
                    % Current source is available
                    sourceFound = true;
                else
                    % Failover to next source
                    obj.failoverToNextSource();
                    attempts = attempts + 1;
                end
            end

            if sourceFound
                % Generate pattern using active source
                obj.patternSequence = obj.patternSequence + 1;

                % Use high-entropy random generation (simulating TRNG)
                freqIdx = randi(obj.numFrequencies);
                pattern.frequency = obj.indexToFrequency(freqIdx);
                pattern.timestamp = timestamp;
                pattern.sequenceNumber = obj.patternSequence;
                pattern.sourceId = obj.currentSourceIdx;
                pattern.fromCache = false;
            else
                % All sources failed - use fallback cache
                cacheIdx = mod(obj.patternSequence, obj.cacheSize) + 1;
                pattern.frequency = obj.patternCache.frequencies(cacheIdx);
                pattern.timestamp = timestamp;
                pattern.sequenceNumber = obj.patternSequence;
                pattern.sourceId = -1; % Indicates cache usage
                pattern.fromCache = true;
                obj.patternSequence = obj.patternSequence + 1;

                warning('All central sources unavailable - using fallback cache');
            end
        end

        function updateJammingStatus(obj)
            % Simulate random jamming events
            for i = 1:obj.numSources
                if rand() < obj.jamProbability
                    obj.jammed(i) = true;
                    obj.sourcesActive(i) = false;
                elseif obj.jammed(i) && rand() < 0.1 % 10% chance of recovery
                    obj.jammed(i) = false;
                    obj.sourcesActive(i) = true;
                end
            end
        end

        function failoverToNextSource(obj)
            % Switch to next available redundant source
            obj.currentSourceIdx = mod(obj.currentSourceIdx, obj.numSources) + 1;
        end

        function setJamProbability(obj, prob)
            % Set jamming probability
            obj.jamProbability = prob;
        end

        function jamSource(obj, sourceIdx)
            % Manually jam a specific source (for testing)
            if sourceIdx >= 1 && sourceIdx <= obj.numSources
                obj.jammed(sourceIdx) = true;
                obj.sourcesActive(sourceIdx) = false;
            end
        end

        function restoreSource(obj, sourceIdx)
            % Restore a jammed source
            if sourceIdx >= 1 && sourceIdx <= obj.numSources
                obj.jammed(sourceIdx) = false;
                obj.sourcesActive(sourceIdx) = true;
            end
        end

        function status = getStatus(obj)
            % Get current status of all sources
            status = struct();
            status.activeSources = sum(obj.sourcesActive);
            status.jammedSources = sum(obj.jammed);
            status.currentSource = obj.currentSourceIdx;
            status.sequenceNumber = obj.patternSequence;
        end
    end
end
