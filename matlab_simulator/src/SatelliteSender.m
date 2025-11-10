classdef SatelliteSender < handle
    % SatelliteSender - Satellite transmitter with orbital dynamics
    % Transmits data using JIT-FHSS with patterns from central source

    properties
        orbitModel          % OrbitModel instance
        patternBuffer       % PatternBuffer instance
        dopplerModel        % DopplerModel instance
        currentTime         % Current simulation time
        transmitPower       % Transmit power in dBm
        antennaGain         % Antenna gain in dBi
        currentFrequency    % Current hopping frequency
        hopDuration         % Duration of each frequency hop in seconds
        lastHopTime         % Time of last frequency hop
        transmitLog         % Log of transmissions
    end

    methods
        function obj = SatelliteSender(orbitModel, bufferSize, hopDuration)
            % Constructor
            obj.orbitModel = orbitModel;
            obj.patternBuffer = PatternBuffer(bufferSize, floor(bufferSize * 0.2));
            obj.dopplerModel = DopplerModel();
            obj.currentTime = 0;
            obj.transmitPower = 40; % dBm (10 watts)
            obj.antennaGain = 12; % dBi
            obj.hopDuration = hopDuration;
            obj.lastHopTime = 0;
            obj.currentFrequency = 0;
            obj.transmitLog = [];
        end

        function requestPatterns(obj, centralSource, numPatterns)
            % Request patterns from central source to fill buffer
            % Simulates downlink from ground-based central source to satellite

            for i = 1:numPatterns
                % Get pattern from central source
                pattern = centralSource.generatePattern(obj.currentTime);

                % Account for uplink delay
                [range, ~] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);
                uplinkDelay = obj.dopplerModel.calculatePropagationDelay(range);

                % Pattern arrives with delay
                pattern.timestamp = pattern.timestamp + uplinkDelay;

                % Add to buffer
                obj.patternBuffer.addPattern(pattern);
            end
        end

        function transmit(obj, dataSymbol)
            % Transmit data symbol using current frequency
            % Check if time to hop to next frequency
            if obj.currentTime - obj.lastHopTime >= obj.hopDuration
                obj.hopToNextFrequency();
            end

            % Get current state
            [range, rangeRate] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);

            % Apply Doppler shift to transmitted frequency
            transmittedFreq = obj.currentFrequency;
            receivedFreq = obj.dopplerModel.applyDopplerShift(transmittedFreq, rangeRate);

            % Log transmission
            logEntry = struct();
            logEntry.time = obj.currentTime;
            logEntry.transmitFreq = transmittedFreq;
            logEntry.receivedFreq = receivedFreq;
            logEntry.dopplerShift = receivedFreq - transmittedFreq;
            logEntry.range = range;
            logEntry.rangeRate = rangeRate;
            logEntry.dataSymbol = dataSymbol;

            if isempty(obj.transmitLog)
                obj.transmitLog = logEntry;
            else
                obj.transmitLog(end+1) = logEntry;
            end
        end

        function hopToNextFrequency(obj)
            % Hop to next frequency from pattern buffer
            pattern = obj.patternBuffer.getNextPattern(obj.currentTime);

            if ~isempty(pattern)
                obj.currentFrequency = pattern.frequency;
                obj.lastHopTime = obj.currentTime;

                % Clear old patterns from buffer
                if obj.patternBuffer.getBufferLevel() < obj.patternBuffer.bufferThreshold
                    obj.patternBuffer.clearOldPatterns();
                end
            else
                warning('No pattern available for frequency hop');
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

        function [pos, vel] = getState(obj)
            % Get current satellite position and velocity
            [pos, vel] = obj.orbitModel.getSatelliteState(obj.currentTime);
        end

        function status = getStatus(obj)
            % Get current status
            status = struct();
            status.currentTime = obj.currentTime;
            status.currentFrequency = obj.currentFrequency;
            status.bufferLevel = obj.patternBuffer.getBufferLevel();
            [range, rangeRate] = obj.orbitModel.getRangeToGroundStation(obj.currentTime);
            status.range = range;
            status.rangeRate = rangeRate;
            status.visible = obj.orbitModel.isVisible(obj.currentTime, 5);
        end

        function log = getTransmitLog(obj)
            % Get transmission log
            log = obj.transmitLog;
        end

        function clearLog(obj)
            % Clear transmission log
            obj.transmitLog = [];
        end
    end
end
