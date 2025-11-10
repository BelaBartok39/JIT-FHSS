classdef PatternBuffer < handle
    % PatternBuffer - Manages pattern buffering and synchronization
    % Uses packet ordering and timing to maintain sync between sender/receiver

    properties
        bufferSize          % Maximum number of patterns to buffer
        patterns            % Array of pattern structs
        currentIndex        % Current pattern index being used
        lastSequenceNumber  % Last received sequence number
        clockOffset         % Clock offset for synchronization
        bufferThreshold     % Minimum buffer level before warning
    end

    methods
        function obj = PatternBuffer(bufferSize, bufferThreshold)
            % Constructor
            obj.bufferSize = bufferSize;
            obj.bufferThreshold = bufferThreshold;
            obj.patterns = [];
            obj.currentIndex = 0;
            obj.lastSequenceNumber = -1;
            obj.clockOffset = 0;
        end

        function success = addPattern(obj, pattern)
            % Add pattern to buffer (received from central source)
            success = false;

            % Check for duplicate or out-of-order pattern
            if pattern.sequenceNumber <= obj.lastSequenceNumber
                warning('Duplicate or out-of-order pattern received: %d (last: %d)', ...
                    pattern.sequenceNumber, obj.lastSequenceNumber);
                return;
            end

            % Add to buffer
            if isempty(obj.patterns)
                obj.patterns = pattern;
            else
                obj.patterns(end+1) = pattern;
            end

            % Sort by sequence number to handle any out-of-order arrivals
            if length(obj.patterns) > 1
                [~, sortIdx] = sort([obj.patterns.sequenceNumber]);
                obj.patterns = obj.patterns(sortIdx);
            end

            % Trim buffer if it exceeds size
            if length(obj.patterns) > obj.bufferSize
                obj.patterns = obj.patterns(end-obj.bufferSize+1:end);
            end

            obj.lastSequenceNumber = pattern.sequenceNumber;
            success = true;
        end

        function pattern = getNextPattern(obj, currentTime)
            % Get next pattern to use based on current time and sequence
            pattern = [];

            if isempty(obj.patterns)
                warning('Buffer empty - no patterns available');
                return;
            end

            % Find pattern with timestamp closest to current time
            % that hasn't been used yet
            obj.currentIndex = obj.currentIndex + 1;

            if obj.currentIndex <= length(obj.patterns)
                pattern = obj.patterns(obj.currentIndex);
            else
                % Reached end of buffer
                warning('Buffer exhausted - need more patterns from central source');
                obj.currentIndex = length(obj.patterns);
                pattern = obj.patterns(end);
            end

            % Check buffer level
            remainingPatterns = length(obj.patterns) - obj.currentIndex;
            if remainingPatterns < obj.bufferThreshold
                warning('Buffer running low: %d patterns remaining', remainingPatterns);
            end
        end

        function clearOldPatterns(obj)
            % Remove patterns that have already been used
            if obj.currentIndex > 0 && ~isempty(obj.patterns)
                if obj.currentIndex >= length(obj.patterns)
                    obj.patterns = [];
                    obj.currentIndex = 0;
                else
                    obj.patterns = obj.patterns(obj.currentIndex+1:end);
                    obj.currentIndex = 0;
                end
            end
        end

        function setClockOffset(obj, offset)
            % Set clock offset for synchronization
            obj.clockOffset = offset;
        end

        function level = getBufferLevel(obj)
            % Get current buffer level
            level = length(obj.patterns) - obj.currentIndex;
        end

        function status = getStatus(obj)
            % Get buffer status
            status = struct();
            status.totalPatterns = length(obj.patterns);
            status.currentIndex = obj.currentIndex;
            status.remainingPatterns = length(obj.patterns) - obj.currentIndex;
            status.lastSequenceNumber = obj.lastSequenceNumber;
            status.clockOffset = obj.clockOffset;
        end

        function reset(obj)
            % Reset buffer
            obj.patterns = [];
            obj.currentIndex = 0;
        end
    end
end
