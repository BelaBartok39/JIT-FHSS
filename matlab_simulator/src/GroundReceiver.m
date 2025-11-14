classdef GroundReceiver < handle
    % GroundReceiver - Ground station receiver for JIT-FHSS
    % Receives patterns from central source and decodes satellite transmissions

    properties
        patternBuffer       % PatternBuffer instance
        dopplerModel        % DopplerModel instance
        orbitModel          % OrbitModel instance (for tracking satellite)
        clockModel          % ClockModel for timing drift
        linkBudget          % LinkBudgetModel for SNR calculation
        currentTime         % Current simulation time
        antennaGain         % Receive antenna gain in dBi
        noiseFigure         % Receiver noise figure in dB
        currentFrequency    % Current expected frequency
        hopDuration         % Duration of each frequency hop in seconds
        lastHopTime         % Time of last frequency hop
        receiveLog          % Log of received signals
        syncError           % Synchronization error in seconds
        snrThreshold        % Minimum SNR for successful decoding (dB)
    end

    methods
        function obj = GroundReceiver(orbitModel, bufferSize, hopDuration)
            % Constructor
            obj.orbitModel = orbitModel;
            obj.patternBuffer = PatternBuffer(bufferSize, floor(bufferSize * 0.2));
            obj.dopplerModel = DopplerModel();
            obj.clockModel = ClockModel('ground');
            obj.currentTime = 0;
            obj.antennaGain = 25; % dBi (larger ground antenna)
            obj.noiseFigure = 3; % dB
            obj.hopDuration = hopDuration;
            obj.lastHopTime = 0;
            obj.currentFrequency = 0;
            obj.receiveLog = [];
            obj.syncError = 0;
            obj.snrThreshold = 8.0; % Minimum 8 dB SNR for FHSS decoding

            % Initialize link budget model
            % Parameters: frequency, txPower, txGain, rxGain, systemTemp, bandwidth
            obj.linkBudget = LinkBudgetModel(...
                2.0e9, ...      % 2 GHz (S-band)
                10, ...         % 10 dBW transmit power (10W)
                15, ...         % 15 dBi satellite antenna gain
                obj.antennaGain, ... % 25 dBi ground antenna gain
                290, ...        % 290K system temperature (room temp + receiver noise)
                1e6);           % 1 MHz bandwidth (FHSS channel width)
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

            % Get current range and elevation for link budget
            [range, rangeRate] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);
            elevation = obj.orbitModel.getElevationAngle(obj.currentTime);

            % Calculate SNR including atmospheric effects
            [snr_dB, linkComponents] = obj.linkBudget.calculateSNR(range, elevation);

            % Get clock error for timing synchronization
            clockError = obj.clockModel.getClockError(obj.currentTime);

            % Debug output on first reception
            persistent firstReception;
            if isempty(firstReception)
                firstReception = true;
                fprintf('[DEBUG] First reception: SNR=%.2f dB, clockError=%.3e s, range=%.1f km\n', ...
                        snr_dB, clockError, range);
            end

            % Check if time to hop to next frequency (including clock error)
            timeSinceHop = obj.currentTime - obj.lastHopTime + clockError;
            if timeSinceHop >= obj.hopDuration
                obj.hopToNextFrequency();
            end

            % Initialize frequency variables for logging
            expectedFreq = obj.currentFrequency;
            compensatedFreq = obj.dopplerModel.compensateDoppler(...
                transmittedSignal.receivedFreq, rangeRate, expectedFreq);
            freqError = abs(compensatedFreq - expectedFreq);
            freqTolerance = expectedFreq * 0.01; % 1% tolerance

            % Check SNR threshold - signal must be strong enough to decode
            if snr_dB < obj.snrThreshold
                % Signal too weak - cannot decode
                success = false;
                failureReason = 'Low SNR';
            else
                % SNR sufficient - check frequency synchronization

                % Timing synchronization error due to clock drift
                % Large clock errors cause hop timing mismatch
                if abs(clockError) > obj.hopDuration * 0.1
                    % Clock drift > 10% of hop duration causes sync loss
                    success = false;
                    failureReason = 'Clock drift';
                    obj.syncError = obj.syncError + 1;
                elseif freqError < freqTolerance
                    % Successfully decoded
                    success = true;
                    decodedSymbol = transmittedSignal.dataSymbol;
                    failureReason = '';
                else
                    % Frequency mismatch - synchronization error
                    success = false;
                    failureReason = 'Freq mismatch';
                    obj.syncError = obj.syncError + 1;
                end
            end

            % Log reception with all new parameters
            logEntry = struct();
            logEntry.time = obj.currentTime;
            logEntry.expectedFreq = expectedFreq;
            logEntry.receivedFreq = transmittedSignal.receivedFreq;
            logEntry.compensatedFreq = compensatedFreq;
            logEntry.freqError = freqError;
            logEntry.success = success;
            logEntry.range = transmittedSignal.range;
            logEntry.rangeRate = transmittedSignal.rangeRate;
            logEntry.snr_dB = snr_dB;
            logEntry.elevation = elevation;
            logEntry.clockError = clockError;
            logEntry.failureReason = failureReason;

            % Link budget components for analysis
            logEntry.pathLoss_dB = linkComponents.fspl_dB;
            logEntry.atmLoss_dB = linkComponents.atm_dB;
            logEntry.ionoLoss_dB = linkComponents.iono_dB;
            logEntry.rainLoss_dB = linkComponents.rain_dB;

            % Always include decodedSymbol field for consistent structure
            if success
                logEntry.decodedSymbol = decodedSymbol;
            else
                logEntry.decodedSymbol = NaN;
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
