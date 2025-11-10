classdef GroundReceiver < handle
    % GroundReceiver - Ground station receiver for JIT-FHSS
    % Receives patterns from central source and decodes satellite transmissions

    properties
        patternBuffer       % PatternBuffer instance
        dopplerModel        % DopplerModel instance
        orbitModel          % OrbitModel instance (for tracking satellite)
        currentTime         % Current simulation time
        antennaGain         % Receive antenna gain in dBi
        noiseFigure         % Receiver noise figure in dB
        currentFrequency    % Current expected frequency
        hopDuration         % Duration of each frequency hop in seconds
        lastHopTime         % Time of last frequency hop
        receiveLog          % Log of received signals
        syncError           % Synchronization error in seconds
    end

    methods
        function obj = GroundReceiver(orbitModel, bufferSize, hopDuration)
            % Constructor
            obj.orbitModel = orbitModel;
            obj.patternBuffer = PatternBuffer(bufferSize, floor(bufferSize * 0.2));
            obj.dopplerModel = DopplerModel();
            obj.currentTime = 0;
            obj.antennaGain = 25; % dBi (larger ground antenna)
            obj.noiseFigure = 3; % dB
            obj.hopDuration = hopDuration;
            obj.lastHopTime = 0;
            obj.currentFrequency = 0;
            obj.receiveLog = [];
            obj.syncError = 0;
        end

        function requestPatterns(obj, centralSource, numPatterns)
            % Request patterns from central source to fill buffer
            % Ground receiver has low-latency connection to central source

            for i = 1:numPatterns
                % Get pattern from central source
                pattern = centralSource.generatePattern(obj.currentTime);

                % Minimal delay for ground-based communication
                pattern.timestamp = pattern.timestamp + 0.001; % 1 ms delay

                % Add to buffer
                obj.patternBuffer.addPattern(pattern);
            end
        end

        function [success, decodedSymbol] = receive(obj, transmittedSignal)
            % Receive and decode transmitted signal
            % transmittedSignal: struct with frequency, data, time, range, rangeRate

            success = false;
            decodedSymbol = [];

            % Check if time to hop to next frequency
            if obj.currentTime - obj.lastHopTime >= obj.hopDuration
                obj.hopToNextFrequency();
            end

            % Get expected frequency with Doppler compensation
            expectedFreq = obj.currentFrequency;
            [~, rangeRate] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);

            % Compensate for Doppler shift
            compensatedFreq = obj.dopplerModel.compensateDoppler(...
                transmittedSignal.receivedFreq, rangeRate, expectedFreq);

            % Check if received frequency matches expected (with tolerance)
            freqError = abs(compensatedFreq - expectedFreq);
            freqTolerance = expectedFreq * 0.01; % 1% tolerance

            if freqError < freqTolerance
                % Successfully decoded
                success = true;
                decodedSymbol = transmittedSignal.dataSymbol;
            else
                % Frequency mismatch - synchronization error
                success = false;
                obj.syncError = obj.syncError + 1;
            end

            % Log reception
            logEntry = struct();
            logEntry.time = obj.currentTime;
            logEntry.expectedFreq = expectedFreq;
            logEntry.receivedFreq = transmittedSignal.receivedFreq;
            logEntry.compensatedFreq = compensatedFreq;
            logEntry.freqError = freqError;
            logEntry.success = success;
            logEntry.range = transmittedSignal.range;
            logEntry.rangeRate = transmittedSignal.rangeRate;

            if success
                logEntry.decodedSymbol = decodedSymbol;
            end

            if isempty(obj.receiveLog)
                obj.receiveLog = logEntry;
            else
                obj.receiveLog(end+1) = logEntry;
            end
        end

        function hopToNextFrequency(obj)
            % Hop to next expected frequency from pattern buffer
            pattern = obj.patternBuffer.getNextPattern(obj.currentTime);

            if ~isempty(pattern)
                obj.currentFrequency = pattern.frequency;
                obj.lastHopTime = obj.currentTime;

                % Clear old patterns from buffer
                if obj.patternBuffer.getBufferLevel() < obj.patternBuffer.bufferThreshold
                    obj.patternBuffer.clearOldPatterns();
                end
            else
                warning('No pattern available for frequency hop at receiver');
            end
        end

        function updateTime(obj, deltaT)
            % Update simulation time
            obj.currentTime = obj.currentTime + deltaT;
        end

        function setTime(obj, t)
            % Set absolute simulation time
            obj.currentTime = t;
        end

        function status = getStatus(obj)
            % Get current status
            status = struct();
            status.currentTime = obj.currentTime;
            status.currentFrequency = obj.currentFrequency;
            status.bufferLevel = obj.patternBuffer.getBufferLevel();
            status.syncErrors = obj.syncError;
            [range, rangeRate] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);
            status.range = range;
            status.rangeRate = rangeRate;
        end

        function log = getReceiveLog(obj)
            % Get reception log
            log = obj.receiveLog;
        end

        function clearLog(obj)
            % Clear reception log
            obj.receiveLog = [];
        end

        function successRate = getSuccessRate(obj)
            % Calculate reception success rate
            if isempty(obj.receiveLog)
                successRate = 0;
            else
                successRate = sum([obj.receiveLog.success]) / length(obj.receiveLog);
            end
        end
    end
end
